#!/usr/bin/env bash
#
# (Re)launch waybar.
#
# Use this for COLD START (e.g. hypr exec-once) or a manual full restart.
# For colour/style refresh after a wallpaper change, prefer an in-place
# reload via `pkill -SIGUSR2 waybar` (set up as a matugen post_hook):
# it is lighter and avoids kill+respawn flicker.
#
# An earlier flock-based dedupe was removed: long-lived waybar children
# (special-workspace.sh, socat) inherited the lock fd and held it
# forever, blocking subsequent legitimate restarts.

# Hypr's exec-once launches without a login shell, so user-local bins
# (rofi-bluetooth, splayer-ctl, ...) need an explicit PATH entry.
export PATH="$HOME/.local/bin:$PATH"

# Terminate any running instance, then poll until it's really gone
# (waybar typically exits within ~200ms of SIGTERM).
killall -q waybar
for _ in {1..40}; do
    pgrep -x waybar >/dev/null || break
    sleep 0.05
done

# Best-effort: load StatusNotifierWatcher so tray icons appear.
dbus-send --session --print-reply \
    --dest=org.kde.kded6 /kded \
    org.kde.kded6.loadModule string:statusnotifierwatcher \
    >/dev/null 2>&1

# Detach via setsid so waybar survives caller exit and inherits no
# unwanted file descriptors.
setsid -f waybar \
    -c "$HOME/.config/waybar/config.jsonc" \
    -s "$HOME/.config/waybar/style.css"
