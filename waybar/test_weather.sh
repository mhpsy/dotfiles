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

# ---- fixture: offline render ----
CACHE="/tmp/waybar-openmeteo.json"
# dynamically build hourly times including the current hour so hidx=0 deterministically
mapfile -t T < <(for o in 0 1 2 3 4 5; do date -d "+$o hour" +%Y-%m-%dT%H:00; done)
fixture=$(jq -n \
  --arg t0 "${T[0]}" --arg t1 "${T[1]}" --arg t2 "${T[2]}" \
  --arg t3 "${T[3]}" --arg t4 "${T[4]}" --arg t5 "${T[5]}" \
  --arg sr "$(date +%Y-%m-%d)T06:12" --arg ss "$(date +%Y-%m-%d)T18:54" '
{
  current:{ temperature_2m:26.4, relative_humidity_2m:65,
            apparent_temperature:28.1, is_day:1, weather_code:0,
            pressure_msl:1013.2, wind_speed_10m:12.3, wind_direction_10m:135 },
  hourly:{ time:[$t0,$t1,$t2,$t3,$t4,$t5],
           temperature_2m:[26,27,27,26,24,23],
           weather_code:[0,2,2,61,61,3],
           visibility:[24000,23000,22000,20000,18000,17000],
           precipitation_probability:[10,20,30,40,30,20] },
  daily:{ weather_code:[0,2,61],
          temperature_2m_max:[28.2,27.1,25.4],
          temperature_2m_min:[22.0,21.3,20.1],
          sunrise:[$sr,$sr,$sr], sunset:[$ss,$ss,$ss],
          uv_index_max:[8.1,7.0,5.5],
          precipitation_probability_max:[30,40,60],
          precipitation_sum:[0.2,1.0,3.4] }
}')
printf '%s' "$fixture" > "$CACHE"
touch "$CACHE"   # mtime=now -> script treats cache fresh, skips curl

out=$(bash "$SCRIPT")
if echo "$out" | jq -e . >/dev/null 2>&1; then
    echo "PASS  output is valid JSON"
else
    echo "FAIL  output is not valid JSON: $out"; fail=1
fi

txt=$(echo "$out" | jq -r '.text')
tip=$(echo "$out" | jq -r '.tooltip')

assert_eq "$txt" "<span size='large'>$(printf '\uf185')</span> 26°C"  "text=icon span + temp"
assert_contains "$tip" "深圳宝安"          "tooltip has city"
assert_contains "$tip" "26°C"              "tooltip has current temp (rounded)"
assert_contains "$tip" "体感 28°C"         "tooltip has feels-like"
assert_contains "$tip" "东南 12 km/h"      "tooltip has wind dir+speed"
assert_contains "$tip" "风向 135°"         "tooltip has raw wind angle"
assert_contains "$tip" "能见度 24.0 km"    "tooltip has visibility"
assert_contains "$tip" "日出 06:12"        "tooltip has sunrise"
assert_contains "$tip" "日落 18:54"        "tooltip has sunset"
assert_contains "$tip" "UV 8"              "tooltip has UV"
assert_contains "$tip" "降水 30% (0.2mm)"  "tooltip has precip prob/amount"
assert_contains "$tip" "逐时"              "tooltip has hourly section"
assert_contains "$tip" "今天"              "tooltip has 3-day forecast"
assert_contains "$tip" "后天  20° ~ 25°C  小雨" "tooltip 3rd-day line correct"

rm -f "$CACHE"
exit $fail
