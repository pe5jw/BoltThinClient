# Usage Guide — BoltThinClient

This guide walks you through installing a BoltSDR remote node on a Dell Wyse 3040
(or any x86-64 machine with at least 2 GB RAM and 8 GB storage).

---

## Before you begin

You need:

1. **A fresh DietPi or Debian 12 Bookworm install** (minimal, no desktop)  
   → [dietpi.com](https://dietpi.com) or [debian.org](https://www.debian.org/distrib/netinst)

2. **A Tailscale account** (free) and an auth key  
   → [tailscale.com](https://tailscale.com)

3. **The hostname of your BoltSDR server** as registered in bolt-tunnel  
   (the value you used for `--hostname` on the server side, default: `bolttunnel-server`)

---

## Step 1 — Get a Tailscale auth key

1. Go to [login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys)
2. Click **Generate auth key**
3. Enable **Reusable** and **Ephemeral**
4. Copy the key — it starts with `tskey-auth-...`

Keep this key safe. It is the only secret the installer needs.

---

## Step 2 — Download the installer

On the target machine, open a terminal (or SSH in) and run:

```bash
curl -fsSL https://raw.githubusercontent.com/pe5jw/BoltThinClient/main/install.sh \
     -o install.sh
```

---

## Step 3 — Configure the installer

Open the script in a text editor:

```bash
nano install.sh
```

Fill in the variables at the top of the file:

```bash
TUNNEL_AUTH_KEY="tskey-auth-..."      # ← paste your Tailscale auth key here
TUNNEL_SERVER="bolttunnel-server"     # ← hostname of your BoltSDR server in the tailnet
TUNNEL_HOSTNAME="bolttunnel-client"   # ← name this device will use in the tailnet
```

The other variables can be left at their defaults:

| Variable | Default | What it does |
|----------|---------|-------------|
| `TUNNEL_PORT` | `7780` | Port the tunnel connects to on the server |
| `TUNNEL_LISTEN` | `:7781` | Local port forwarded to the SDR server |
| `TUNNEL_GUI` | `127.0.0.1:8080` | bolt-tunnel local web GUI |
| `BOLTTUNNEL_VERSION` | `v1.1.0` | bolt-tunnel release to download |
| `NODE_HOSTNAME` | `boltsdr-node` | mDNS hostname — reachable as `boltsdr-node.local` |
| `KIOSK_USER` | `boldsdr` | Linux user created for the kiosk session |
| `INSTALL_DIR` | `/opt/boldsdr` | Installation directory |

Save and close (`Ctrl+O`, `Enter`, `Ctrl+X` in nano).

---

## Step 4 — Run the installer

```bash
sudo bash install.sh
```

The script runs 8 steps and takes a few minutes (mostly downloading packages and
running `npm install` for Electron). It prints progress as it goes.

If it stops with an error, read the message — most likely causes:
- `TUNNEL_AUTH_KEY` is empty → fill it in and re-run
- No internet → check your ethernet cable / DHCP
- Package download failed → run `sudo apt-get update` first and retry

---

## Step 5 — Adjust the BoltSDR URL (if needed)

The installer creates a default config that connects to `http://127.0.0.1:6443`
(bolt-tunnel forwards this to your SDR server). If your server uses a different
port, edit the config before rebooting:

```bash
nano /opt/boltsdr/Bolt-multiwindow/config.json
```

Change the `url` field:

```json
{
  "windows": [
    {
      "url": "http://127.0.0.1:6443"
    }
  ]
}
```

---

## Step 6 — Reboot

```bash
sudo reboot
```

After reboot the node will:

1. Connect to the tailnet via bolt-tunnel (before the display starts)
2. Log in automatically as the kiosk user
3. Start Openbox + Bolt-multiwindow in full-screen kiosk mode

---

## Connecting from your SDR server

Make sure your bolt-tunnel **server** is running and listening. The thin client
will appear in your tailnet under the hostname you set in `TUNNEL_HOSTNAME`.

The Bolt-multiwindow window opens `http://127.0.0.1:6443`, which bolt-tunnel
forwards to port `6443` on your server — the standard BoltSDR web interface port.

---

## Managing the node

| Task | Command |
|------|---------|
| SSH into the node | `ssh boldsdr@boltsdr-node.local` |
| Check tunnel status | `sudo systemctl status bolttunnel` |
| View tunnel logs | `sudo journalctl -u bolttunnel -f` |
| Restart tunnel | `sudo systemctl restart bolttunnel` |
| Edit kiosk config | `nano /opt/boldsdr/Bolt-multiwindow/config.json` |
| Restart kiosk | Log out / reboot |
| bolt-tunnel web GUI | `http://127.0.0.1:8080` (on the node itself) |

---

## Re-running the installer

The installer is **idempotent** — safe to run again. It will:
- Pull the latest Bolt-multiwindow code (`git pull`)
- Skip downloading bolt-tunnel if the binary already exists
- Not overwrite `config.json` if it already exists
- Recreate the systemd service and udev rules

Useful for updating after a new Bolt-multiwindow release.

---

## Updating bolt-tunnel

Change `BOLTTUNNEL_VERSION` at the top of `install.sh` to the new version tag,
delete the old binary, then re-run:

```bash
rm /opt/boldsdr/bolttunnel/bolttunnel-client-linux-amd64
sudo bash install.sh
```

---

## Troubleshooting

**Kiosk screen stays black after boot**  
Check the Xorg log: `cat /tmp/xorg-kiosk.log`

**Bolt-multiwindow shows "connection refused"**  
The tunnel is not up yet. Check: `sudo systemctl status bolttunnel`  
If the service failed, check: `sudo journalctl -u bolttunnel -n 50`

**No audio from USB device**  
Make sure the device is plugged in. Check Pipewire: `pw-cli list-objects | grep Audio`  
The udev rules give audio group access automatically on plug-in.

**MIDI controller not recognized**  
Check: `aconnect -l`  
The udev rules in `/etc/udev/rules.d/99-midi.rules` apply on next plug-in.

**SSH not working (`boltsdr-node.local` not found)**  
mDNS may not be available on the network. Use the IP address instead:  
Check the router's DHCP table, or connect a monitor and run `ip addr`.
