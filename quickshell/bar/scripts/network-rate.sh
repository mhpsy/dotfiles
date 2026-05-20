#!/usr/bin/env bash
# Dump current rx/tx byte counters for the connected NM interface.
# Output: <rx-bytes> <tx-bytes>
set -u
if=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: '$3=="connected" {print $1; exit}')
if [ -z "$if" ]; then
    echo "0 0"
    exit 0
fi
rx=$(cat "/sys/class/net/$if/statistics/rx_bytes" 2>/dev/null)
tx=$(cat "/sys/class/net/$if/statistics/tx_bytes" 2>/dev/null)
echo "${rx:-0} ${tx:-0}"
