#!/usr/bin/env bash
# Per-button daemon for waybar special-workspace toggle buttons.
# Args: drawer | chat | entertainment
# Emits one JSON line per state change to stdout (waybar custom JSON module).

set -euo pipefail

name="${1:-}"

# Font Awesome 7 codepoints (matches waybar font stack: "Font Awesome 7 Free")
case "$name" in
    drawer)        icon=$'\uf120'; label="DEV"  ;;   # fa-terminal
    chat)          icon=$'\uf086'; label="CHAT" ;;   # fa-comments
    entertainment) icon=$'\uf518'; label="DOCS" ;;   # fa-book-open
    *)
        printf '{"text":"?","class":"error","tooltip":"unknown name: %s"}\n' "$name"
        exit 64
        ;;
esac

emit_error() {
    printf '{"text":"!","class":"error","tooltip":"%s"}\n' "$1"
}

# Locate Hyprland socket2 (newer: $XDG_RUNTIME_DIR/hypr/$HIS, older: /tmp/hypr/$HIS)
sock="${XDG_RUNTIME_DIR:-/tmp}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"
[[ -S "$sock" ]] || sock="/tmp/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"
if [[ ! -S "$sock" ]]; then
    emit_error "hypr socket not found"
    exit 1
fi
if ! command -v socat >/dev/null; then
    emit_error "socat not installed"
    exit 1
fi

last=""
emit() {
    local active="$1" out
    if [[ "$active" == "true" ]]; then
        out=$(printf '{"text":"%s %s","class":"active","tooltip":"Toggle %s (active)"}' \
              "$icon" "$label" "$name")
    else
        out=$(printf '{"text":"%s","class":"inactive","tooltip":"Toggle %s"}' \
              "$icon" "$name")
    fi
    if [[ "$out" != "$last" ]]; then
        last="$out"
        printf '%s\n' "$out"
    fi
}

is_active() {
    hyprctl monitors -j 2>/dev/null \
      | jq -r --arg n "special:$name" \
          '[.[] | .specialWorkspace.name] | any(. == $n) | tostring' \
      2>/dev/null \
      || echo false
}

emit "$(is_active)"

# Tail socket2; re-emit on activespecial events.
socat -U - "UNIX-CONNECT:$sock" | while IFS= read -r line; do
    case "$line" in
        activespecial\>\>*|activespecialv2\>\>*)
            emit "$(is_active)"
            ;;
    esac
done
emit_error "socket disconnected"
