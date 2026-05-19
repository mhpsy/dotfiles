#!/usr/bin/env bash
# waybar custom/weather on-click: open+reveal / unreveal+close the weather island.
# Model A: the window only exists while shown -> no persistent layer-shell
# surface, so it never blocks clicks in the top-left when collapsed.
set -u
C="$HOME/.config/waybar/eww"
command -v eww >/dev/null 2>&1 || exit 0
eww --config "$C" ping >/dev/null 2>&1 || eww --config "$C" daemon >/dev/null 2>&1
if eww --config "$C" active-windows 2>/dev/null | grep -q 'weather-island'; then
  eww --config "$C" update wisland_open=false >/dev/null 2>&1
  sleep 0.35
  eww --config "$C" close weather-island >/dev/null 2>&1
else
  eww --config "$C" open weather-island >/dev/null 2>&1
  eww --config "$C" update wisland_open=true >/dev/null 2>&1
fi
