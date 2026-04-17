#!/usr/bin/env bash

SAVE_DIR="$HOME/Screenshots"
mkdir -p "$SAVE_DIR"
FILENAME="screenshot_$(date +%Y%m%d_%H%M%S).png"
FILEPATH="$SAVE_DIR/$FILENAME"

case "$1" in
    --copy)
        # Select area, copy to clipboard only
        region=$(slurp -b "#00000080" -c "#888888ff" -w 1) || exit 0
        grim -g "$region" - | wl-copy
        notify-send -a "Screenshot" -i camera-photo-symbolic "Copied to clipboard"
        ;;
    --full)
        # Full screen, save to file and copy to clipboard
        grim "$FILEPATH"
        wl-copy < "$FILEPATH"
        notify-send -a "Screenshot" -i camera-photo-symbolic "Screenshot saved" "$FILEPATH"
        ;;
    *)
        echo "Usage: $0 --copy | --full"
        ;;
esac
