#!/usr/bin/env bash
# waybar custom/quotes on-click：开/关灵动岛（翻转 eww word_reveal）。
set -u
C="$HOME/.config/eww"
command -v eww >/dev/null 2>&1 || exit 0
eww --config "$C" ping >/dev/null 2>&1 || eww --config "$C" daemon >/dev/null 2>&1
eww --config "$C" windows 2>/dev/null | grep -qx 'daily-word' \
  || eww --config "$C" open daily-word >/dev/null 2>&1
cur=$(eww --config "$C" get word_reveal 2>/dev/null)
[ "$cur" = "true" ] && nv=false || nv=true
eww --config "$C" update word_reveal=$nv >/dev/null 2>&1
