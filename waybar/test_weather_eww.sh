#!/usr/bin/env bash
# weather-eww.sh tests: 纯函数单元 + 离线夹具渲染。
set -u
SCRIPT="$HOME/.config/waybar/weather-eww.sh"
fail=0
assert_eq() { # $1=actual $2=expected $3=label
    if [ "$1" = "$2" ]; then printf 'PASS  %s\n' "$3"
    else printf 'FAIL  %s\n        got=[%s]\n        exp=[%s]\n' "$3" "$1" "$2"; fail=1; fi
}

# ---- 单元:纯函数 ----
WEATHER_EWW_LIB_ONLY=1 source "$SCRIPT"
assert_eq "$(wmo_cond 0)"   "clear"   "cond 0 clear"
assert_eq "$(wmo_cond 2)"   "clear"   "cond 2 clear"
assert_eq "$(wmo_cond 3)"   "clouds"  "cond 3 clouds"
assert_eq "$(wmo_cond 48)"  "fog"     "cond 48 fog"
assert_eq "$(wmo_cond 61)"  "rain"    "cond 61 rain"
assert_eq "$(wmo_cond 82)"  "rain"    "cond 82 rain"
assert_eq "$(wmo_cond 75)"  "snow"    "cond 75 snow"
assert_eq "$(wmo_cond 95)"  "thunder" "cond 95 thunder"
assert_eq "$(wmo_cond 999)" "clouds"  "cond unknown fallback"
echo "--- unit section end ---"

# ---- 夹具:离线渲染(LIB_ONLY 模式下 weather-eww.sh 不联网;touch 仅与 test_weather.sh 保持一致) ----
CACHE="/tmp/waybar-openmeteo.json"
mapfile -t T < <(for o in 0 1 2 3 4 5; do date -d "+$o hour" +%Y-%m-%dT%H:00; done)
fixture=$(jq -n \
  --arg t0 "${T[0]}" --arg t1 "${T[1]}" --arg t2 "${T[2]}" \
  --arg t3 "${T[3]}" --arg t4 "${T[4]}" --arg t5 "${T[5]}" \
  --arg sr "$(date +%Y-%m-%d)T06:12" --arg ss "$(date +%Y-%m-%d)T18:54" '
{ current:{ temperature_2m:26.4, relative_humidity_2m:65,
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
          precipitation_sum:[0.2,1.0,3.4] } }')
printf '%s' "$fixture" > "$CACHE"; touch "$CACHE"

out=$(bash "$SCRIPT")
if echo "$out" | jq -e . >/dev/null 2>&1; then echo "PASS  output is valid JSON"
else echo "FAIL  output is not valid JSON: $out"; fail=1; fi
assert_eq "$(echo "$out" | jq -r '.ok')"   "true"     "ok=true with cache"
assert_eq "$(echo "$out" | jq -r '.city')" "深圳宝安" "city correct"
assert_eq "$(echo "$out" | jq -r '.current.temp')"       "26"   "current.temp rounded"
assert_eq "$(echo "$out" | jq -r '.current.feel')"       "28"   "current.feel rounded"
assert_eq "$(echo "$out" | jq -r '.current.desc')"       "晴"   "current.desc"
assert_eq "$(echo "$out" | jq -r '.current.cond')"       "clear" "current.cond"
assert_eq "$(echo "$out" | jq -r '.current.humidity')"   "65"   "current.humidity"
assert_eq "$(echo "$out" | jq -r '.current.wind_dir')"   "东南" "current.wind_dir"
assert_eq "$(echo "$out" | jq -r '.current.wind_speed')" "12"   "current.wind_speed"
assert_eq "$(echo "$out" | jq -r '.current.pressure')"   "1013" "current.pressure"
assert_eq "$(echo "$out" | jq -r '.current.visibility')" "24.0" "current.visibility"
assert_eq "$(echo "$out" | jq -r '.current.wind_deg')"   "135"  "current.wind_deg"
assert_eq "$(echo "$out" | jq -r '.current.uv')"         "8"    "current.uv"
assert_eq "$(echo "$out" | jq -r '.current.sunrise')"    "06:12" "current.sunrise"
assert_eq "$(echo "$out" | jq -r '.current.sunset')"     "18:54" "current.sunset"
assert_eq "$(echo "$out" | jq -r '.current.pop')"        "30"   "current.pop"
assert_eq "$(echo "$out" | jq -r '.current.precip')"     "0.2"  "current.precip"
assert_eq "$(echo "$out" | jq -r '.current.icon')" "$(printf '\xef\x86\x85')" "current.icon clear-day glyph"

assert_eq "$(echo "$out" | jq -r '.hourly | length')"        "6"     "hourly has 6"
assert_eq "$(echo "$out" | jq -r '.hourly[0].temp')"         "26"    "hourly[0].temp"
assert_eq "$(echo "$out" | jq -r '.hourly[3].temp')"         "26"    "hourly[3].temp"
assert_eq "$(echo "$out" | jq -r '.hourly[0].icon')" "$(printf '\xef\x86\x85')" "hourly[0] clear glyph"
assert_eq "$(echo "$out" | jq -r '.hourly[0].time' | grep -c 时)" "1" "hourly time has 时"
assert_eq "$(echo "$out" | jq -r '.daily | length')"         "3"     "daily has 3"
assert_eq "$(echo "$out" | jq -r '.daily[0].label')"         "今天"  "daily[0].label"
assert_eq "$(echo "$out" | jq -r '.daily[2].label')"         "后天"  "daily[2].label"
assert_eq "$(echo "$out" | jq -r '.daily[0].max')"           "28"    "daily[0].max rounded"
assert_eq "$(echo "$out" | jq -r '.daily[0].min')"           "22"    "daily[0].min rounded"
assert_eq "$(echo "$out" | jq -r '.daily[2].desc')"          "小雨"  "daily[2].desc (code 61)"

rm -f "$CACHE"
exit $fail
