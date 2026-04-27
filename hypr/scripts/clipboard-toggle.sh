#!/usr/bin/env bash
set -euo pipefail

if pgrep -f '[r]ofi.*rofi-clipboard' >/dev/null; then
    pkill -f '[r]ofi.*rofi-clipboard'
    exit 0
fi

selection="$(cliphist list | rofi -normal-window -window-title rofi-clipboard -dmenu -p "Clipboard")" || exit 0
printf '%s\n' "$selection" | cliphist decode | wl-copy
