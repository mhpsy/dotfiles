#!/bin/sh
# Toggle the Quickshell weather card open-state file. Missing/non-"1" => treat
# as currently closed, so this opens it (writes "1"). on-click target of the
# waybar custom/weather module.
f=/tmp/qs-weather-open
if [ "$(cat "$f" 2>/dev/null)" = "1" ]; then
    printf 0 > "$f"
else
    printf 1 > "$f"
fi
