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
    matugen image "$WALLPAPER" --prefer=saturation 2>/dev/null
    ~/.config/waybar/launch.sh
fi
