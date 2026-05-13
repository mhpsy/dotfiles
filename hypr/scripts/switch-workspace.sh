#!/bin/bash
target=$1
special=$(hyprctl monitors -j | jq -r '.[] | select(.specialWorkspace.name != "") | .specialWorkspace.name' | head -1)
if [ -n "$special" ]; then
    hyprctl dispatch togglespecialworkspace "${special#special:}"
fi
hyprctl dispatch workspace "$target"
