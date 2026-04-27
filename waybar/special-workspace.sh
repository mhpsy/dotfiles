#!/usr/bin/env bash
set -euo pipefail

workspace="$(
    hyprctl monitors -j \
        | jq -r '.[] | select(.focused) | .specialWorkspace.name // ""' \
        | head -n 1
)"

case "$workspace" in
    special:drawer)
        printf '{"text":"DRAWER","class":"drawer","tooltip":"Special workspace: drawer"}\n'
        ;;
    special:chat)
        printf '{"text":"CHAT","class":"chat","tooltip":"Special workspace: chat"}\n'
        ;;
    special:entertainment)
        printf '{"text":"FUN","class":"entertainment","tooltip":"Special workspace: entertainment"}\n'
        ;;
    *)
        printf '{"text":"","class":"hidden","tooltip":""}\n'
        ;;
esac
