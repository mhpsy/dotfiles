#!/bin/bash
# Rofi script mode: Quick directory launcher
# Config: ~/.config/rofi/quickdirs.json
# Format: [{"path": "~/some/dir", "name": "Display Name"}, ...]

CONFIG="$HOME/.config/rofi/quickdirs.json"
FILE_MANAGER="dolphin"

if [ -z "$@" ]; then
    # First call: show directory list
    python3 -c "
import json, os
with open(os.path.expanduser('$CONFIG')) as f:
    dirs = json.load(f)
for d in dirs:
    path = os.path.expanduser(d['path'])
    name = d.get('name', os.path.basename(path))
    print(f'{name}  ({path})')
"
else
    selected="$@"
    path=$(echo "$selected" | grep -oP '\(.*\)' | tr -d '()')

    if [ -n "$path" ] && [ -d "$path" ]; then
        coproc ( $FILE_MANAGER "$path" > /dev/null 2>&1 )
        # Exit rofi
        exit 0
    fi

    # If not matched, re-show list so rofi doesn't go blank
    exec "$0"
fi
