#!/bin/bash
# Waybar package updates module

pacman_count=$(checkupdates 2>/dev/null | wc -l)
aur_count=$(yay -Qua 2>/dev/null | wc -l)
total=$((pacman_count + aur_count))

if [[ $total -eq 0 ]]; then
    printf '{"text":"0","tooltip":"All packages up to date","class":"up-to-date"}\n'
else
    tooltip="Pacman: ${pacman_count}\nAUR: ${aur_count}"
    printf '{"text":"%s","tooltip":"%s","class":"has-updates"}\n' "$total" "$tooltip"
fi
