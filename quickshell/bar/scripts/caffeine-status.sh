#!/usr/bin/env bash
# Dump caffeine state for CaffeineData.qml.
#
# Format:
#   __KEEP_AWAKE__ {true|false}
#   __INHIBITOR__ <who>|<what>|<why>
#   ... (one __INHIBITOR__ line per active idle inhibitor) ...
set -u

if pgrep -x hypridle >/dev/null 2>&1; then
    echo "__KEEP_AWAKE__ false"
else
    echo "__KEEP_AWAKE__ true"
fi

# systemd-inhibit lists all active inhibitors (idle, sleep, shutdown).
# We only show ones that block idle — those are what keep the screen on.
systemd-inhibit --no-legend --no-pager 2>/dev/null | while IFS=$'\t' read -r who uid user pid comm what why mode; do
    case "$what" in
        *idle*) echo "__INHIBITOR__ ${who:-?}|${what:-idle}|${why:-}" ;;
    esac
done
