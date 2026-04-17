#!/usr/bin/env bash
# Waybar brightness control for external monitors via ddcutil
# Usage: brightness.sh [get|up|down|set N]

STEP=5
CACHE_FILE="/tmp/waybar-brightness-cache"
CACHE_TTL=10  # seconds

get_brightness() {
    # Use cache if fresh enough
    if [[ -f "$CACHE_FILE" ]]; then
        local age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE") ))
        if (( age < CACHE_TTL )); then
            cat "$CACHE_FILE"
            return
        fi
    fi
    local val
    val=$(ddcutil getvcp 10 --brief 2>/dev/null | awk '{print $4}')
    if [[ -n "$val" ]]; then
        echo "$val" > "$CACHE_FILE"
        echo "$val"
    else
        # fallback to cache even if stale
        [[ -f "$CACHE_FILE" ]] && cat "$CACHE_FILE" || echo "50"
    fi
}

set_brightness() {
    local val=$1
    (( val < 0 )) && val=0
    (( val > 100 )) && val=100
    ddcutil setvcp 10 "$val" --noverify 2>/dev/null &
    echo "$val" > "$CACHE_FILE"
}

output_json() {
    local val
    val=$(get_brightness)
    local class="brightness"
    (( val <= 20 )) && class="low"
    (( val >= 80 )) && class="high"
    printf '{"text":"%d%%","tooltip":"Brightness: %d%%\\nScroll to adjust","class":"%s","percentage":%d}\n' \
        "$val" "$val" "$class" "$val"
}

case "${1:-get}" in
    get)
        output_json
        ;;
    up)
        cur=$(get_brightness)
        set_brightness $(( cur + STEP ))
        output_json
        ;;
    down)
        cur=$(get_brightness)
        set_brightness $(( cur - STEP ))
        output_json
        ;;
    set)
        set_brightness "${2:-50}"
        output_json
        ;;
esac
