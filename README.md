# BoltThinClient

[![Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/pe5jw)

Installer for a **BoltSDR remote node** on a Dell Wyse 3040 (or any x86-64 Linux thin client).

The node acts as a plug-and-play SDR client: plug in ethernet → everything starts automatically.

## What gets installed

| Component | Source | Purpose |
|-----------|--------|---------|
| [Bolt-multiwindow](https://github.com/pe5jw/Bolt-multiwindow) | git clone + npm | Electron kiosk — loads the BoltSDR web interface |
| [bolt-tunnel](https://github.com/pe5jw/bolt-tunnel) | GitHub release | Tailscale VPN tunnel to the SDR server |
| Pipewire | apt | Audio I/O, 48 kHz low latency |
| ALSA + udev | apt | USB MIDI controller support |
| Openbox + X11 | apt | Minimal kiosk display server |

## Requirements

- Dell Wyse 3040 (or any x86-64 PC), min. 2 GB RAM, 8 GB storage
- **[DietPi](https://dietpi.com)** (Native PC — UEFI image) or Debian 12 Bookworm minimal
- Ethernet connection (DHCP)
- A [Tailscale](https://tailscale.com) account (free) and auth key

> **DietPi image note:** The Wyse 3040 boots UEFI only — no Legacy/CSM mode.  
> Download the **Native PC (UEFI)** image and flash with Rufus (GPT + UEFI non-CSM).

## Installation

### 1. Create a Tailscale auth key

Go to [login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys)  
→ **Generate auth key** → Reusable ✓, Ephemeral ✓  
→ Copy the key — it starts with `tskey-auth-...`

### 2. Download and configure the script

```bash
curl -fsSL https://raw.githubusercontent.com/pe5jw/BoltThinClient/main/install.sh -o install.sh
nano install.sh   # Fill in TUNNEL_AUTH_KEY and TUNNEL_SERVER at the top
```

### 3. Run the installer

```bash
chmod +x install.sh
sudo ./install.sh
```

### 4. Adjust the BoltSDR URL (optional)

After installation the Bolt-multiwindow config is at:
```
/opt/boldsdr/Bolt-multiwindow/config.json
```

Update the `url` to match your BoltSDR server address (default: `http://127.0.0.1:6443` via the tunnel).

### 5. Reboot

```bash
sudo reboot
```

The node starts automatically in kiosk mode.

## After installation

| What | How |
|------|-----|
| SSH access | `ssh boldsdr@boltsdr-node.local` |
| BoltTunnel status | `http://boltsdr-node.local:8080` (browser on same network) |
| Edit config | `nano /opt/boldsdr/Bolt-multiwindow/config.json` |
| Service status | `sudo systemctl status bolttunnel` |
| Logs | `sudo journalctl -u bolttunnel -f` |

## Configuration variables

At the top of `install.sh`:

| Variable | Default | Description |
|----------|---------|-------------|
| `TUNNEL_AUTH_KEY` | *(empty — required)* | Tailscale auth key |
| `TUNNEL_SERVER` | `bolttunnel-server` | Hostname of the SDR server in the tailnet |
| `TUNNEL_HOSTNAME` | `bolttunnel-client` | Name of this device in the tailnet |
| `BOLTTUNNEL_VERSION` | `v1.1.0` | bolt-tunnel release version |
| `NODE_HOSTNAME` | `boltsdr-node` | mDNS name (`.local`) |
| `KIOSK_USER` | `boldsdr` | Linux user for the kiosk session |

## Architecture

```
[Wyse 3040 — BoltThinClient]          [Home PC — BoltSDR server]
  Bolt-multiwindow (Electron)
    ↓ http via tunnel
  bolttunnel-client  ←── WireGuard/Tailscale ───→  bolttunnel-server
    localhost:6443                                   localhost:6443 (BoltSDR)
```

## More details

See [USAGE.md](USAGE.md) for a full step-by-step guide including troubleshooting.

## License

MIT
