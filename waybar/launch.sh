#!/usr/bin/env bash

# Ensure user-local bins (rofi-bluetooth, splayer-ctl, etc.) are in PATH.
# Hyprland's exec-once launches this without a login shell, so ~/.local/bin
# would otherwise be missing from waybar's env.
export PATH="$HOME/.local/bin:$PATH"

killall waybar 2>/dev/null
sleep 1
dbus-send --session --print-reply --dest=org.kde.kded6 /kded org.kde.kded6.loadModule string:statusnotifierwatcher > /dev/null 2>&1
waybar -c ~/.config/waybar/config.jsonc -s ~/.config/waybar/style.css &
