#!/usr/bin/env bash
# Dump bluetooth state for BluetoothData.qml.
#
# Battery info comes from UPower first (what waybar uses — many headsets
# / mice expose battery via UPower's BLE GATT integration but NOT via
# bluetoothctl's "Battery Percentage" field, which is often 0/missing).
# bluetoothctl is the fallback.
#
# Format (one record per line):
#   __POWER__ {yes|no}
#   <mac>|<alias>|<battery-int-or-empty>
set -u

powered=$(bluetoothctl show 2>/dev/null | awk '/Powered/{print $2; exit}')
echo "__POWER__ ${powered:-no}"

# Build a MAC -> percentage map from UPower's enumeration.
# UPower exposes BT batteries as devices with the device's MAC in their
# `serial` field. The path prefix varies (headset_dev_, keyboard_dev_, etc).
declare -A upmap
while read -r path; do
    [ -z "$path" ] && continue
    case "$path" in *DisplayDevice) continue ;; esac
    info=$(upower -i "$path" 2>/dev/null)
    # Use sed to strip only the leading "  serial:" / "  percentage:" prefix,
    # not split on every colon (MAC addresses contain colons too — awk -F:
    # would only return the first MAC byte).
    serial=$(printf '%s' "$info" | grep -m1 -E '^\s*serial:' | sed -E 's/^\s*serial:\s*//')
    pct=$(printf '%s' "$info"    | grep -m1 -E '^\s*percentage:' | sed -E 's/^\s*percentage:\s*//' | tr -d ' %')
    [ -z "$serial" ] && continue
    [ -z "$pct" ] && continue
    # Normalize MAC to upper-case so lookup is case-insensitive.
    key=$(printf '%s' "$serial" | tr 'a-f' 'A-F')
    upmap[$key]=$pct
done < <(upower -e 2>/dev/null)

for mac in $(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}'); do
    info=$(bluetoothctl info "$mac" 2>/dev/null)
    name=$(printf '%s' "$info" | awk -F': ' '/Alias:/{print $2; exit}')
    macKey=$(printf '%s' "$mac" | tr 'a-f' 'A-F')
    bat="${upmap[$macKey]:-}"
    if [ -z "$bat" ]; then
        bat=$(printf '%s' "$info" | awk -F': ' '/Battery Percentage/{print $2; exit}' | grep -oE '[0-9]+' | head -1)
    fi
    echo "${mac}|${name:-Unknown}|${bat:-}"
done
