#!/usr/bin/env bash
# Waybar reboot-pending indicator.
# Shows an icon when the running kernel's modules directory has been
# removed by a pacman upgrade — the canonical "needs reboot" signal on Arch.

set -euo pipefail

icon=$''  # FA 7 codepoint U+F2F1 (renders as red pin in current font stack)
running="$(uname -r)"

if [[ -d "/usr/lib/modules/$running" ]]; then
    printf '{"text":"","tooltip":"","class":"ok"}\n'
    exit 0
fi

installed="$(pacman -Q linux 2>/dev/null | awk '{print $2}')"
printf '{"text":"%s","tooltip":"Reboot pending\\nRunning: %s\\nInstalled: %s","class":"pending"}\n' \
    "$icon" "$running" "$installed"
