#!/usr/bin/env bash

# Ensure user-local bins (rofi-bluetooth, splayer-ctl, etc.) are in PATH.
# Hyprland's exec-once launches this without a login shell, so ~/.local/bin
# would otherwise be missing from waybar's env.
export PATH="$HOME/.local/bin:$PATH"

LOCK_FILE="/tmp/waybar-launch.lock"

# Prevent duplicate launches (e.g. exec-once race with uwsm session init)
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    exit 0
fi

killall waybar 2>/dev/null
sleep 1
dbus-send --session --print-reply --dest=org.kde.kded6 /kded org.kde.kded6.loadModule string:statusnotifierwatcher > /dev/null 2>&1
waybar -c ~/.config/waybar/config.jsonc -s ~/.config/waybar/style.css &

# Hold the lock until waybar is up, then release
sleep 2
