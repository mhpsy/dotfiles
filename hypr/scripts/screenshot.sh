#!/usr/bin/env bash

SAVE_DIR="$HOME/Screenshots"
mkdir -p "$SAVE_DIR"
FILENAME="screenshot_$(date +%Y%m%d_%H%M%S).png"
FILEPATH="$SAVE_DIR/$FILENAME"

# Keep the original slurp styling when grimblast invokes slurp
export SLURP_ARGS='-b #00000080 -c #888888ff -w 1'

case "$1" in
    --copy)
        # Freeze the screen (preserves hover/tooltips), then select area → clipboard
        grimblast --notify --freeze copy area
        ;;
    --full)
        # Full screen, save to file and copy to clipboard
        grim "$FILEPATH"
        wl-copy < "$FILEPATH"
        notify-send -a "Screenshot" -i camera-photo-symbolic "Screenshot saved" "$FILEPATH"
        ;;
    --edit)
        # Freeze + select area, then annotate in satty
        TMP="$(mktemp --suffix=.png)"
        trap 'rm -f "$TMP"' EXIT
        GRIMBLAST_EDITOR="satty --output-filename $FILEPATH --early-exit --copy-command wl-copy --filename" \
            grimblast --freeze edit area "$TMP"
        ;;
    *)
        echo "Usage: $0 --copy | --full | --edit"
        ;;
esac
