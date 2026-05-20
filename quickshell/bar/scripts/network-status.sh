#!/usr/bin/env bash
# Dump network status for NetworkData.qml.
# Output: <type>|<ifname>|<ipv4>|<wifi-signal>
# Empty type when disconnected.
set -u

row=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: '$3=="connected" {print; exit}')
if [ -z "$row" ]; then
    echo "|||"
    exit 0
fi

dev=$(echo "$row" | cut -d: -f1)
type=$(echo "$row" | cut -d: -f2)
ip=$(ip -4 -o addr show "$dev" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)
sig=""
if [ "$type" = "wifi" ]; then
    sig=$(nmcli -t -f IN-USE,SIGNAL device wifi list 2>/dev/null | awk -F: '$1=="*" {print $2; exit}')
fi
echo "${type}|${dev}|${ip:-}|${sig:-0}"
