#!/usr/bin/env bash
# Read system uptime in seconds (integer). Used by ClockCard.
awk '{printf "%d", $1}' /proc/uptime
