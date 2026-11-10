#!/usr/bin/env bash
# =============================================================================
# BoltSDR Remote Node — Installer
# Dell Wyse 3040 / DietPi of Debian Bookworm x86-64
#
# Installeert:
#   - Bolt-multiwindow  (Electron, via git clone + npm install)
#   - bolttunnel-client (Go binary, via GitHub release download)
#   - Audio: Pipewire/ALSA, lage latency
#   - MIDI: udev regels (@julusian/midi zit in Bolt-multiwindow)
#   - Kiosk autostart via LXDE autostart (.config/autostart/)
#
# Gebruik:
#   curl -fsSL https://raw.githubusercontent.com/pe5jw/BoltThinClient/main/install.sh | sudo bash
# of:
#   sudo bash install.sh
#
# ─── Vul onderstaande waarden in vóór gebruik ────────────────────────────────
TUNNEL_AUTH_KEY=""                       # tskey-auth-... van login.tailscale.com/admin/settings/keys
TUNNEL_SERVER="bolttunnel-server"        # Hostname van de BoltTunnel server (jouw thuis-PC in tailnet)
TUNNEL_HOSTNAME="bolttunnel-client"      # Naam van dit apparaat in het tailnet
TUNNEL_PORT="7780"
TUNNEL_LISTEN=":7781"
TUNNEL_GUI="127.0.0.1:8080"

BOLTTUNNEL_VERSION="v1.1.0"
NODE_HOSTNAME="boltsdr-node"
KIOSK_USER="boltsdr"
INSTALL_DIR="/opt/boltsdr"
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()   { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()     { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()    { echo -e "${RED}[FOUT]${NC}  $*" >&2; exit 1; }
header() { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════${NC}";
           echo -e "${BOLD}${CYAN}  $*${NC}";
           echo -e "${BOLD}${CYAN}══════════════════════════════════════${NC}"; }

header "BoltSDR Remote Node Installer"

[[ $EUID -ne 0 ]] && die "Draai dit script als root:  sudo bash $0"

if [[ -z "$TUNNEL_AUTH_KEY" ]]; then
    echo -e "${YELLOW}"
    echo "  ┌─────────────────────────────────────────────────────────┐"
    echo "  │  TUNNEL_AUTH_KEY is niet ingesteld!                     │"
    echo "  │                                                         │"
    echo "  │  Maak een Tailscale auth key aan op:                    │"
    echo "  │  https://login.tailscale.com/admin/settings/keys        │"
    echo "  │  (Reusable=aan, Ephemeral=aan)                          │"
    echo "  │                                                         │"
    echo "  │  Stel TUNNEL_AUTH_KEY in bovenaan dit script en herstart│"
    echo "  └─────────────────────────────────────────────────────────┘"
    echo -e "${NC}"
    die "Gestopt — TUNNEL_AUTH_KEY vereist"
fi

# ── Stap 1: Systeem update ────────────────────────────────────────────────────
header "Stap 1/8 — Systeem bijwerken"
apt-get update -qq
apt-get upgrade -y -qq
ok "Systeem bijgewerkt"

# ── Stap 2: Packages ─────────────────────────────────────────────────────────
header "Stap 2/8 — Packages installeren"

PACKAGES=(
    curl wget git unzip
    nodejs npm
    xorg xinit openbox x11-xserver-utils unclutter
    pipewire pipewire-pulse pipewire-alsa wireplumber alsa-utils
    alsa-seq-utils a2jmidid
    avahi-daemon libnss-mdns
    jq htop
)

apt-get install -y -qq "${PACKAGES[@]}" 2>/dev/null || {
    for pkg in "${PACKAGES[@]}"; do
        apt-get install -y -qq "$pkg" 2>/dev/null || warn "  Overgeslagen: $pkg"
    done
}

NODE_VER=$(node --version 2>/dev/null | tr -d 'v' | cut -d. -f1 || echo "0")
if [[ "$NODE_VER" -lt 18 ]]; then
    info "Node.js $NODE_VER te oud — installeer Node.js 20 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y -qq nodejs
fi
ok "Node.js $(node --version) — packages geïnstalleerd"

# ── Stap 3: Hostnaam & mDNS ──────────────────────────────────────────────────
header "Stap 3/8 — Hostnaam & mDNS"
hostnamectl set-hostname "$NODE_HOSTNAME"
systemctl enable --now avahi-daemon
ok "${NODE_HOSTNAME}.local"

# ── Stap 4: Kiosk gebruiker ──────────────────────────────────────────────────
header "Stap 4/8 — Kiosk gebruiker"

if ! id "$KIOSK_USER" &>/dev/null; then
    useradd -m -s /bin/bash -G audio,video,input,plugdev,dialout,render "$KIOSK_USER"
    # Standaard wachtwoord instellen (zelfde als gebruikersnaam)
    echo "${KIOSK_USER}:${KIOSK_USER}" | chpasswd
    ok "Gebruiker '$KIOSK_USER' aangemaakt (wachtwoord: $KIOSK_USER)"
else
    usermod -aG audio,video,input,plugdev,dialout,render "$KIOSK_USER" 2>/dev/null || true
    info "Gebruiker '$KIOSK_USER' bestaat al"
fi

KIOSK_HOME=$(getent passwd "$KIOSK_USER" | cut -d: -f6)

mkdir -p /etc/systemd/system/getty@tty1.service.d/
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${KIOSK_USER} --noclear %I \$TERM
EOF
loginctl enable-linger "$KIOSK_USER"

# Passwordless sudo voor bolttunnel service beheer
cat > /etc/sudoers.d/bolttunnel <<EOF
${KIOSK_USER} ALL=(ALL) NOPASSWD: /bin/systemctl start bolttunnel, /bin/systemctl stop bolttunnel, /bin/systemctl restart bolttunnel
EOF
chmod 440 /etc/sudoers.d/bolttunnel
ok "Autologin TTY1 → $KIOSK_USER (sudo bolttunnel zonder wachtwoord)"

# ── Stap 5: Bolt-multiwindow ─────────────────────────────────────────────────
header "Stap 5/8 — Bolt-multiwindow"

mkdir -p "$INSTALL_DIR"
BMWIN_DIR="$INSTALL_DIR/Bolt-multiwindow"

if [[ -d "$BMWIN_DIR/.git" ]]; then
    info "Updaten..."
    git -C "$BMWIN_DIR" pull --ff-only
else
    git clone https://github.com/pe5jw/Bolt-multiwindow.git "$BMWIN_DIR"
fi

sudo -u "$KIOSK_USER" npm install --prefix "$BMWIN_DIR" --omit=dev 2>&1 \
    | grep -E "^(added|warn|error)" || true

if [[ ! -f "$BMWIN_DIR/config.json" ]]; then
    cat > "$BMWIN_DIR/config.json" <<'EOF'
{
  "windows": [
    {
      "id": "boltsdr",
      "title": "BoltSDR Remote",
      "url": "http://127.0.0.1:6443",
      "width": 1920,
      "height": 1080,
      "x": 0,
      "y": 0,
      "resizable": false
    }
  ],
  "midi": { "enabled": true },
  "toolbar": { "height": 36, "alwaysVisible": true }
}
EOF
    ok "config.json aangemaakt (BoltSDR poort 6443)"
fi
ok "Bolt-multiwindow klaar"

# ── Stap 6: BoltTunnel ───────────────────────────────────────────────────────
header "Stap 6/8 — BoltTunnel client"

TUNNEL_DIR="$INSTALL_DIR/bolttunnel"
TUNNEL_BIN="$TUNNEL_DIR/bolttunnel-client-linux-amd64"
mkdir -p "$TUNNEL_DIR"

if [[ ! -f "$TUNNEL_BIN" ]]; then
    RELEASE_URL="https://github.com/pe5jw/bolt-tunnel/releases/download/${BOLTTUNNEL_VERSION}/bolttunnel-linux-amd64.zip"
    curl -fsSL "$RELEASE_URL" -o /tmp/bolttunnel.zip \
        || die "Download mislukt: $RELEASE_URL"
    unzip -o /tmp/bolttunnel.zip -d "$TUNNEL_DIR"
    rm /tmp/bolttunnel.zip
    FOUND=$(find "$TUNNEL_DIR" -name "bolttunnel-client*linux*amd64*" -type f | head -1)
    [[ -n "$FOUND" && "$FOUND" != "$TUNNEL_BIN" ]] && mv "$FOUND" "$TUNNEL_BIN"
    chmod +x "$TUNNEL_BIN"
fi
ok "BoltTunnel binary aanwezig"

TUNNEL_ENV="$TUNNEL_DIR/bolttunnel.env"
cat > "$TUNNEL_ENV" <<EOF
TS_AUTHKEY=${TUNNEL_AUTH_KEY}
EOF
chmod 600 "$TUNNEL_ENV"

cat > /etc/systemd/system/bolttunnel.service <<EOF
[Unit]
Description=BoltTunnel Tailscale client
After=network-online.target
Wants=network-online.target

[Service]
User=${KIOSK_USER}
EnvironmentFile=${TUNNEL_ENV}
ExecStart=${TUNNEL_BIN} \\
    --hostname ${TUNNEL_HOSTNAME} \\
    --server   ${TUNNEL_SERVER} \\
    --port     ${TUNNEL_PORT} \\
    --listen   ${TUNNEL_LISTEN} \\
    --gui      ${TUNNEL_GUI} \\
    --nowindow
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable bolttunnel
ok "bolttunnel.service ingeschakeld"

# ── Stap 7: Audio & MIDI ─────────────────────────────────────────────────────
header "Stap 7/8 — Audio & MIDI"

mkdir -p "$KIOSK_HOME/.config/pipewire/pipewire.conf.d"
cat > "$KIOSK_HOME/.config/pipewire/pipewire.conf.d/boltsdr.conf" <<'EOF'
context.properties = {
    default.clock.rate        = 48000
    default.clock.quantum     = 256
    default.clock.min-quantum = 64
    default.clock.max-quantum = 1024
}
EOF

cat > /etc/udev/rules.d/99-midi.rules <<'EOF'
SUBSYSTEM=="sound",  GROUP="audio", MODE="0664"
KERNEL=="midi*",     GROUP="audio", MODE="0664"
KERNEL=="snd/midi*", GROUP="audio", MODE="0664"
EOF
udevadm control --reload-rules
ok "Audio (Pipewire 48kHz/256q) + MIDI udev"

# ── Stap 8: Kiosk autostart + bureaublad snelkoppelingen ─────────────────────
header "Stap 8/8 — Kiosk autostart (LXDE) + snelkoppelingen"

# LXDE autostart — start Bolt-multiwindow automatisch bij inloggen
mkdir -p "$KIOSK_HOME/.config/autostart"

cat > "$KIOSK_HOME/.config/autostart/bolt-multiwindow.desktop" <<EOF
[Desktop Entry]
Name=Bolt MultiWindow
Comment=BoltSDR remote client
Exec=bash ${INSTALL_DIR}/Bolt-multiwindow/start.sh
Terminal=false
Type=Application
Categories=AudioVideo;
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF

# Bureaublad snelkoppelingen
mkdir -p "$KIOSK_HOME/Desktop"

# 1. Bolt-multiwindow starten
cat > "$KIOSK_HOME/Desktop/bolt-multiwindow.desktop" <<EOF
[Desktop Entry]
Name=Bolt MultiWindow
Comment=BoltSDR remote client
Exec=bash ${INSTALL_DIR}/Bolt-multiwindow/start.sh
Icon=${INSTALL_DIR}/Bolt-multiwindow/assets/icon.png
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Video;
StartupNotify=true
EOF

# 2. BoltTunnel starten
cat > "$KIOSK_HOME/Desktop/bolttunnel-start.desktop" <<EOF
[Desktop Entry]
Name=BoltTunnel — Start
Comment=Start de VPN tunnel naar de BoltSDR server
Exec=pkexec systemctl start bolttunnel
Icon=network-vpn
Terminal=false
Type=Application
Categories=Network;
StartupNotify=false
EOF

# 3. BoltTunnel stoppen
cat > "$KIOSK_HOME/Desktop/bolttunnel-stop.desktop" <<EOF
[Desktop Entry]
Name=BoltTunnel — Stop
Comment=Stop de VPN tunnel
Exec=pkexec systemctl stop bolttunnel
Icon=network-offline
Terminal=false
Type=Application
Categories=Network;
StartupNotify=false
EOF

# Markeer .desktop bestanden als vertrouwd (uitvoerbaar) voor LXDE/PCManFM
chmod +x "$KIOSK_HOME/Desktop/"*.desktop

chown -R "$KIOSK_USER:$KIOSK_USER" "$KIOSK_HOME"
chown -R "$KIOSK_USER:$KIOSK_USER" "$INSTALL_DIR"
ok "Kiosk autostart + 3 bureaublad snelkoppelingen aangemaakt"

# ── Klaar ─────────────────────────────────────────────────────────────────────
header "Installatie voltooid!"
echo -e "${GREEN}"
echo "  ✓ Bolt-multiwindow   →  $INSTALL_DIR/Bolt-multiwindow"
echo "  ✓ BoltTunnel client  →  $TUNNEL_BIN"
echo "  ✓ Audio (Pipewire 48kHz) + MIDI udev"
echo "  ✓ LXDE autostart → Bolt-multiwindow kiosk
  ✓ Bureaublad snelkoppelingen: Bolt-multiwindow, BoltTunnel start/stop"
echo "  ✓ bolttunnel.service (start bij opstarten)"
echo ""
echo -e "${YELLOW}  Controleer na installatie:"
echo "  1. BoltMultiwindow URL:  $INSTALL_DIR/Bolt-multiwindow/config.json"
echo "  2. BoltTunnel server:    $TUNNEL_SERVER"
echo ""
echo -e "${CYAN}  sudo reboot${NC}"
echo ""
echo -e "${GREEN}  Na reboot:"
echo "  → SSH:            ssh ${KIOSK_USER}@${NODE_HOSTNAME}.local"
echo "  → Tunnel GUI:     http://${NODE_HOSTNAME}.local:8080${NC}"
