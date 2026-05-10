#!/bin/bash
# Called by waypaper post_command after wallpaper change
# Usage: wallpaper-post.sh <wallpaper_path>

# waypaper subprocesses inherit a minimal PATH (no ~/.local/bin),
# so matugen / cargo bins must be added explicitly.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

WALLPAPER="$1"

if [ -z "$WALLPAPER" ]; then
    # Fallback: read from waypaper config
    WALLPAPER=$(grep "^wallpaper" ~/.config/waypaper/config.ini | cut -d'=' -f2 | xargs)
    WALLPAPER="${WALLPAPER/#\~/$HOME}"
fi

if [ -f "$WALLPAPER" ]; then
    # --prefer is matugen >= 2.5 only; older versions reject it
    prefer_arg=()
    if matugen image --help 2>&1 | grep -q -- '--prefer'; then
        prefer_arg=(--prefer=saturation)
    fi
    matugen image "$WALLPAPER" "${prefer_arg[@]}"
    ~/.config/waybar/launch.sh
fi
