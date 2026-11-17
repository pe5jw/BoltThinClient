#!/usr/bin/env python3
import subprocess
import os
import urllib.request
import gi
gi.require_version("Gtk", "3.0")
gi.require_version("AyatanaAppIndicator3", "0.1")
from gi.repository import Gtk, AyatanaAppIndicator3 as AppIndicator3, GLib

ICON_DIR        = os.path.dirname(os.path.abspath(__file__))
ICON_ACTIVE     = os.path.join(ICON_DIR, "icon_active.png")      # groen  — tunnel verbonden
ICON_CONNECTING = os.path.join(ICON_DIR, "icon_connecting.png")  # oranje — service draait, tunnel nog bezig
ICON_INACTIVE   = os.path.join(ICON_DIR, "icon_inactive.png")    # rood   — service gestopt
MONITOR_URL     = "http://127.0.0.1:8080/"
CHECK_INTERVAL_SECONDS = 5


def is_service_active():
    try:
        result = subprocess.run(
            ["systemctl", "is-active", "bolttunnel"],
            capture_output=True, text=True, timeout=3
        )
        return result.stdout.strip() == "active"
    except Exception:
        return False


def is_tunnel_connected():
    """Tunnel is echt actief als de monitor pagina bereikbaar is."""
    try:
        urllib.request.urlopen(MONITOR_URL, timeout=2)
        return True
    except Exception:
        return False


def get_status():
    """Geeft terug: 'active', 'connecting' of 'inactive'"""
    if not is_service_active():
        return "inactive"
    if is_tunnel_connected():
        return "active"
    return "connecting"


def build_menu(indicator):
    menu = Gtk.Menu()
    item_status = Gtk.MenuItem(label="Checking...")
    item_status.set_sensitive(False)
    menu.append(item_status)
    menu.append(Gtk.SeparatorMenuItem())
    item_start = Gtk.MenuItem(label="Start BoltTunnel")
    item_start.connect("activate", lambda _: run_service("start", indicator, item_status))
    menu.append(item_start)
    item_stop = Gtk.MenuItem(label="Stop BoltTunnel")
    item_stop.connect("activate", lambda _: run_service("stop", indicator, item_status))
    menu.append(item_stop)
    menu.append(Gtk.SeparatorMenuItem())
    item_monitor = Gtk.MenuItem(label="Verbindingsmonitor")
    item_monitor.connect("activate", lambda _: subprocess.Popen(["xdg-open", MONITOR_URL]))
    menu.append(item_monitor)
    menu.append(Gtk.SeparatorMenuItem())
    item_quit = Gtk.MenuItem(label="Quit indicator")
    item_quit.connect("activate", lambda _: Gtk.main_quit())
    menu.append(item_quit)
    menu.show_all()
    indicator._status_item = item_status
    return menu


def run_service(action, indicator, status_item):
    subprocess.run(["sudo", "systemctl", action, "bolttunnel"])
    update_indicator(indicator)


def update_indicator(indicator):
    status = get_status()
    if status == "active":
        icon  = ICON_ACTIVE
        label = "BoltTunnel: verbonden"
    elif status == "connecting":
        icon  = ICON_CONNECTING
        label = "BoltTunnel: verbinding maken..."
    else:
        icon  = ICON_INACTIVE
        label = "BoltTunnel: gestopt"

    indicator.set_icon_full(icon, label)
    if hasattr(indicator, "_status_item"):
        indicator._status_item.set_label(label)
    return True


def main():
    indicator = AppIndicator3.Indicator.new(
        "bolttunnel-tray",
        ICON_INACTIVE,
        AppIndicator3.IndicatorCategory.SYSTEM_SERVICES,
    )
    indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
    indicator.set_menu(build_menu(indicator))
    update_indicator(indicator)
    GLib.timeout_add_seconds(CHECK_INTERVAL_SECONDS, update_indicator, indicator)
    Gtk.main()


if __name__ == "__main__":
    main()
