#!/usr/bin/env bash
# Waybar brightness control.
# Prefers brightnessctl (internal backlight); falls back to ddcutil (external DDC/CI).
# Usage: brightness.sh [get|up|down|set N]

STEP=5

have_brightnessctl() { command -v brightnessctl >/dev/null 2>&1 && [[ -n $(ls /sys/class/backlight 2>/dev/null) ]]; }
have_ddcutil() { command -v ddcutil >/dev/null 2>&1; }

get_brightness() {
    if have_brightnessctl; then
        local cur max
        cur=$(brightnessctl g 2>/dev/null)
        max=$(brightnessctl m 2>/dev/null)
        (( max > 0 )) && echo $(( cur * 100 / max )) || echo 50
    elif have_ddcutil; then
        ddcutil getvcp 10 --brief 2>/dev/null | awk '{print $4}'
    else
        echo 50
    fi
}

set_brightness() {
    local val=$1
    (( val < 1 )) && val=1
    (( val > 100 )) && val=100
    if have_brightnessctl; then
        brightnessctl s "${val}%" >/dev/null 2>&1
    elif have_ddcutil; then
        ddcutil setvcp 10 "$val" --noverify 2>/dev/null &
    fi
}

output_json() {
    local val class="brightness"
    val=$(get_brightness)
    (( val <= 20 )) && class="low"
    (( val >= 80 )) && class="high"
    printf '{"text":"%d%%","tooltip":"Brightness: %d%%\\nScroll to adjust","class":"%s","percentage":%d}\n' \
        "$val" "$val" "$class" "$val"
}

case "${1:-get}" in
    get)  output_json ;;
    up)   cur=$(get_brightness); set_brightness $(( cur + STEP )); output_json ;;
    down) cur=$(get_brightness); set_brightness $(( cur - STEP )); output_json ;;
    set)  set_brightness "${2:-50}"; output_json ;;
esac
