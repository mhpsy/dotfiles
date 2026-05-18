#!/usr/bin/env bash
# weather-eww.sh tests: 纯函数单元 + 离线夹具渲染。
set -u
SCRIPT="$HOME/.config/waybar/weather-eww.sh"
fail=0
assert_eq() { # $1=actual $2=expected $3=label
    if [ "$1" = "$2" ]; then printf 'PASS  %s\n' "$3"
    else printf 'FAIL  %s\n        got=[%s]\n        exp=[%s]\n' "$3" "$1" "$2"; fail=1; fi
}

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

rm -f "$CACHE"
exit $fail
