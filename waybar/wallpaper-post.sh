#!/bin/bash
# Hook invoked by waypaper after a wallpaper change.
# Responsibility: regenerate matugen colours; per-app reload is done by
# matugen's own post_hooks (see ~/.config/matugen/config.toml).
#
# Usage: wallpaper-post.sh <wallpaper_path>
set -u

LOG=/tmp/waypaper-post.log

# waypaper invokes this with a minimal PATH (~/.local/bin is NOT in it),
# so matugen and other user-local binaries must be added explicitly.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

WALLPAPER="${1:-}"
if [[ -z "$WALLPAPER" ]]; then
    # Fallback: read current wallpaper from waypaper's config
    WALLPAPER=$(awk -F= '/^wallpaper[[:space:]]*=/ {sub(/^[[:space:]]+/,"",$2); print $2; exit}' \
        ~/.config/waypaper/config.ini)
    WALLPAPER="${WALLPAPER/#\~/$HOME}"
fi

{
    printf '\n--- %s ---\n' "$(date -Iseconds)"
    printf 'wallpaper=%q\n' "$WALLPAPER"

    if [[ ! -f "$WALLPAPER" ]]; then
        printf 'ERROR: wallpaper file not found, aborting\n'
        exit 1
    fi

    if ! command -v matugen >/dev/null; then
        printf 'ERROR: matugen not on PATH=%s\n' "$PATH"
        exit 1
    fi

    # --prefer is matugen >= 2.5 only; older versions reject it.
    prefer_arg=()
    if matugen image --help 2>&1 | grep -q -- '--prefer'; then
        prefer_arg=(--prefer=saturation)
    fi

    matugen image "$WALLPAPER" "${prefer_arg[@]}"
    printf 'matugen exit=%d\n' "$?"
} >>"$LOG" 2>&1
