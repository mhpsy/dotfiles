#!/usr/bin/env bash

killall waybar 2>/dev/null
sleep 1
dbus-send --session --print-reply --dest=org.kde.kded6 /kded org.kde.kded6.loadModule string:statusnotifierwatcher > /dev/null 2>&1
waybar -c ~/.config/waybar/config.jsonc -s ~/.config/waybar/style.css &
