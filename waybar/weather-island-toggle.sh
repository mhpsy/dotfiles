#!/usr/bin/env bash
# waybar custom/weather on-click:开/关天气灵动岛(翻转 eww wisland_open)。
set -u
C="$HOME/.config/waybar/eww"
command -v eww >/dev/null 2>&1 || exit 0
eww --config "$C" ping >/dev/null 2>&1 || eww --config "$C" daemon >/dev/null 2>&1
eww --config "$C" active-windows 2>/dev/null | grep -q 'weather-island' \
  || eww --config "$C" open weather-island >/dev/null 2>&1
cur=$(eww --config "$C" get wisland_open 2>/dev/null)
[ "$cur" = "true" ] && nv=false || nv=true
eww --config "$C" update wisland_open=$nv >/dev/null 2>&1
