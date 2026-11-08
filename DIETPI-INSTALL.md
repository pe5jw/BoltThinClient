# DietPi Installation Guide — Dell Wyse 3040

This guide covers installing DietPi with LXDE desktop on a Dell Wyse 3040,
ready for the BoltThinClient installer.

---

## What you need

- Dell Wyse 3040 thin client
- USB stick (4 GB or larger)
- PC to flash the USB stick
- Keyboard + monitor (only needed during install)
- Ethernet cable (DHCP)
- **Rufus** (Windows) → [rufus.ie](https://rufus.ie)
- **DietPi UEFI image** → [dietpi.com/#download](https://dietpi.com/#download)

---

## Step 1 — Download DietPi

1. Go to [dietpi.com/#download](https://dietpi.com/#download)
2. Select **Native PC**
3. Download the **UEFI** image — filename looks like:  
   `DietPi_NativePC-UEFI-x86_64-Bookworm.img.xz`

> ⚠️ The Wyse 3040 has **no Legacy/CSM boot mode** — only UEFI works.  
> Do not use the BIOS image.

---

## Step 2 — Flash the USB stick with Rufus

1. Open **Rufus**
2. Select your USB stick under **Device**
3. Click **SELECT** and open the DietPi `.img.xz` file
4. Set the following options:
   - **Partition scheme:** GPT
   - **Target system:** UEFI (non-CSM)
5. Click **START** → OK to confirm
6. Wait until done, then close Rufus

---

## Step 3 — BIOS settings on the Wyse 3040

1. Plug the USB stick into the Wyse 3040
2. Power on and press **F2** repeatedly to enter the BIOS
3. Check / change these settings:

| Setting | Value |
|---------|-------|
| **Boot mode** | UEFI |
| **Secure Boot** | Disabled |
| **AC Recovery** | Power On *(important — node must restart after power loss)* |
| **USB Boot** | Enabled |

4. Press **F10** to save and exit

---

## Step 4 — Boot from USB and install DietPi

1. Power on, press **F12** for the boot menu
2. Select your USB stick (shows as UEFI: ...)
3. DietPi boots to a text installer — wait for it to load

**On first boot DietPi will ask a few questions:**

- **Language / locale:** choose your preference
- **Timezone:** set your timezone
- **Password:** set a root password — write it down!
- **SSH:** leave enabled (default) — you will need this later

Let the first-run setup complete. It will reboot automatically.

---

## Step 5 — Connect via SSH

After reboot the node is reachable on your network. Find the IP on your router,
or use the hostname if mDNS works:

```bash
ssh root@192.168.x.x
```

or

```bash
ssh root@DietPi.local
```

---

## Step 6 — Install LXDE desktop

Once logged in via SSH:

```bash
dietpi-software
```

Navigate to:  
**Browse Software → Desktop → LXDE**

Select it with **Space**, then press **Enter** to install.

Or install directly from the command line:

```bash
dietpi-software install 23
```

> Software ID 23 = LXDE in DietPi.

This takes a few minutes. After installation, reboot:

```bash
reboot
```

---

## Step 7 — Verify LXDE starts

After reboot, connect a monitor and keyboard to the Wyse 3040.
LXDE should start automatically and show a desktop.

If you see only a black screen:

- Wait 30 seconds — the first LXDE boot can be slow
- Try a **DisplayPort cable** instead of a DP→VGA adapter
  (the Wyse 3040 has known issues with DP→VGA converters)
- If using the machine headless (no monitor), use a **DisplayPort dummy plug**

---

## Step 8 — Run the BoltThinClient installer

Now follow the [USAGE.md](USAGE.md) guide to install Bolt-multiwindow
and bolt-tunnel on this machine.

Quick start:

```bash
curl -fsSL https://raw.githubusercontent.com/pe5jw/BoltThinClient/main/install.sh \
     -o install.sh
nano install.sh   # fill in TUNNEL_AUTH_KEY and TUNNEL_SERVER
chmod +x install.sh
sudo ./install.sh
```

---

## Known issues on the Wyse 3040

| Problem | Solution |
|---------|----------|
| Black screen after reboot | Set AC Recovery → Power On in BIOS |
| Blank screen, no display | Use a native DisplayPort cable or DP dummy plug |
| Shutdown/reboot hangs | Add `blacklist dw_dmac` to `/etc/modprobe.d/blacklist.conf` |
| Screen goes off after sleep | Add `intel_idle.max_cstate=1` to kernel params in `/etc/default/grub` |
| Cannot boot from USB | Check BIOS: Secure Boot = Disabled, USB Boot = Enabled |

