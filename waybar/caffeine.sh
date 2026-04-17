#!/usr/bin/env bash
# Waybar caffeine module: toggles hypridle on/off to prevent screen from sleeping.
# Usage: caffeine.sh [get|toggle]

get_state() {
  if pgrep -x hypridle >/dev/null 2>&1; then
    # hypridle running -> idle allowed -> caffeine OFF
    printf '{"text":"\uf0eb","tooltip":"Screen idle allowed\\nClick to keep screen awake","class":"inactive"}\n'
  else
    # hypridle stopped -> idle prevented -> caffeine ON
    printf '{"text":"\uf0eb","tooltip":"Keep-awake is active\\nClick to allow idle","class":"active"}\n'
  fi
}

toggle() {
  if pgrep -x hypridle >/dev/null 2>&1; then
    pkill -x hypridle
  else
    hyprctl dispatch exec hypridle >/dev/null 2>&1
  fi
  # notify waybar to refresh immediately
  pkill -RTMIN+8 waybar 2>/dev/null
}

case "${1:-get}" in
  toggle) toggle ;;
  get|*)  get_state ;;
esac
