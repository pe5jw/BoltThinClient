# BoltThinClient

Installer voor een **BoltSDR remote node** op een Dell Wyse 3040 (of vergelijkbare thin client / x86-64 Linux machine).

De node fungeert als plug-and-play SDR client: ethernet insteken → alles start automatisch.

## Wat er geïnstalleerd wordt

| Component | Bron | Functie |
|-----------|------|---------|
| [Bolt-multiwindow](https://github.com/pe5jw/Bolt-multiwindow) | git clone + npm | Electron kiosk — laadt de BoltSDR webinterface |
| [bolt-tunnel](https://github.com/pe5jw/bolt-tunnel) | GitHub release | Tailscale VPN tunnel naar de SDR server |
| Pipewire | apt | Audio I/O, 48kHz lage latency |
| ALSA + udev | apt | USB MIDI controller support |
| Openbox + X11 | apt | Minimale kiosk display server |

## Vereisten

- Dell Wyse 3040 (of andere x86-64 PC), min. 2 GB RAM, 8 GB opslag
- **[DietPi](https://dietpi.com)** of Debian 12 Bookworm (minimal install)
- Ethernet verbinding (DHCP)
- Een [Tailscale](https://tailscale.com) account (gratis) en auth key

## Installatie

### 1. Auth key aanmaken

Ga naar [login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys)  
→ **Generate auth key** → Reusable ✓, Ephemeral ✓  
→ Kopieer de key (begint met `tskey-auth-...`)

### 2. Script downloaden en configureren

```bash
curl -fsSL https://raw.githubusercontent.com/pe5jw/BoltThinClient/main/install.sh -o install.sh
nano install.sh   # Vul TUNNEL_AUTH_KEY en TUNNEL_SERVER in bovenaan
```

Of direct uitvoeren (vereist vooraf de auth key in de environment variable):

```bash
curl -fsSL https://raw.githubusercontent.com/pe5jw/BoltThinClient/main/install.sh | sudo bash
```

### 3. Installeren

```bash
sudo bash install.sh
```

### 4. Config aanpassen (optioneel)

Na installatie staat de BoltMultiwindow config in:
```
/opt/boltsdr/Bolt-multiwindow/config.json
```

Pas de `url` aan naar het webadres van jouw BoltSDR server (standaard: `http://127.0.0.1:6443` via de tunnel).

### 5. Rebooten

```bash
sudo reboot
```

De node start automatisch op als kiosk.

## Na installatie

| Wat | Hoe |
|-----|-----|
| SSH toegang | `ssh boltsdr@boltsdr-node.local` |
| BoltTunnel status | `http://boltsdr-node.local:8080` (in browser op zelfde netwerk) |
| Config aanpassen | `nano /opt/boltsdr/Bolt-multiwindow/config.json` |
| Service status | `sudo systemctl status bolttunnel` |
| Logs | `sudo journalctl -u bolttunnel -f` |

## Configuratie variabelen

Bovenaan `install.sh`:

| Variabele | Standaard | Omschrijving |
|-----------|-----------|-------------|
| `TUNNEL_AUTH_KEY` | *(leeg — vereist)* | Tailscale auth key |
| `TUNNEL_SERVER` | `bolttunnel-server` | Hostname SDR server in tailnet |
| `TUNNEL_HOSTNAME` | `bolttunnel-client` | Naam van dit apparaat in tailnet |
| `BOLTTUNNEL_VERSION` | `v1.1.0` | bolt-tunnel release versie |
| `NODE_HOSTNAME` | `boltsdr-node` | mDNS naam (`.local`) |
| `KIOSK_USER` | `boltsdr` | Linux gebruiker voor kiosk sessie |

## Architectuur

```
[Wyse 3040 — BoltThinClient]          [Thuis-PC — BoltSDR server]
  Bolt-multiwindow (Electron)
    ↓ http via tunnel
  bolttunnel-client  ←── WireGuard/Tailscale ───→  bolttunnel-server
    localhost:6443                                    localhost:6443 (BoltSDR)
```

## Licentie

MIT
