#!/usr/bin/env bash
# weather.sh tests: pure-function unit tests + fixture render test.
set -u
SCRIPT="$HOME/.config/waybar/weather.sh"
fail=0
assert_eq() { # $1=actual $2=expected $3=label
    if [ "$1" = "$2" ]; then
        printf 'PASS  %s\n' "$3"
    else
        printf 'FAIL  %s\n        got=[%s]\n        exp=[%s]\n' "$3" "$1" "$2"
        fail=1
    fi
}
assert_contains() { # $1=haystack $2=needle $3=label
    case "$1" in
        *"$2"*) printf 'PASS  %s\n' "$3" ;;
        *) printf 'FAIL  %s (missing: %s)\n' "$3" "$2"; fail=1 ;;
    esac
}

# ---- unit: pure functions ----
WEATHER_LIB_ONLY=1 source "$SCRIPT"

assert_eq "$(wmo_text 0)"   "晴"               "wmo_text 0"
assert_eq "$(wmo_text 2)"   "多云"             "wmo_text 2"
assert_eq "$(wmo_text 55)"  "大毛毛雨"         "wmo_text 55"
assert_eq "$(wmo_text 95)"  "雷阵雨"           "wmo_text 95"
assert_eq "$(wmo_text 999)" "未知"             "wmo_text unknown fallback"

assert_eq "$(wmo_icon 0 1)"   "$(printf '\uf185')" "wmo_icon clear-day"
assert_eq "$(wmo_icon 0 0)"   "$(printf '\uf186')" "wmo_icon clear-night"
assert_eq "$(wmo_icon 2 0)"   "$(printf '\uf6c3')" "wmo_icon partly-night"
assert_eq "$(wmo_icon 65 1)"  "$(printf '\uf740')" "wmo_icon heavy-rain"
assert_eq "$(wmo_icon 95 1)"  "$(printf '\uf76c')" "wmo_icon thunder"
assert_eq "$(wmo_icon 999 1)" "$(printf '\uf0c2')" "wmo_icon unknown fallback"

assert_eq "$(wind_dir_cn 0)"   "北"   "wind 0deg"
assert_eq "$(wind_dir_cn 90)"  "东"   "wind 90deg"
assert_eq "$(wind_dir_cn 135)" "东南" "wind 135deg"
assert_eq "$(wind_dir_cn 350)" "北"   "wind 350deg wrap"

assert_eq "$(r 26.4)"  "26"  "r round down"
assert_eq "$(r 27.6)"  "28"  "r round up"
assert_eq "$(r null)"  "--"  "r non-numeric fallback"
assert_eq "$(r '')"    "--"  "r empty fallback"

echo "--- unit test section end ---"
exit $fail
