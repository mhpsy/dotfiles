#!/bin/bash
# Called by waypaper post_command after wallpaper change
# Usage: wallpaper-post.sh <wallpaper_path>

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
