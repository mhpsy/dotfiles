#!/usr/bin/env bash
# Dump bluetooth state for BluetoothData.qml.
# Output format (one record per line):
#   __POWER__ {yes|no}
#   <mac>|<alias>|<battery-int-or-empty>   (repeated per connected device)
set -u

powered=$(bluetoothctl show 2>/dev/null | awk '/Powered/{print $2; exit}')
echo "__POWER__ ${powered:-no}"

for mac in $(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}'); do
    info=$(bluetoothctl info "$mac" 2>/dev/null)
    name=$(echo "$info" | awk -F': ' '/Alias:/{print $2; exit}')
    bat=$(echo "$info" | awk -F': ' '/Battery Percentage/{print $2; exit}' | grep -oE '[0-9]+' | head -1)
    echo "${mac}|${name:-Unknown}|${bat:-}"
done
