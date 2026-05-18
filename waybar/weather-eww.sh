#!/usr/bin/env bash
# Waybar 天气灵动岛数据脚本 — 读 weather.sh 的共享缓存,输出 eww 结构化 JSON。
# 不主动联网(联网由 waybar 侧 weather.sh 周期触发)。
# See docs/superpowers/specs/2026-05-18-weather-dynamic-island-design.md
set -u
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="/tmp/waybar-openmeteo.json"
CITY="深圳宝安"

# 导入 weather.sh 纯函数供后续任务使用(r / wmo_text / wmo_icon / wind_dir_cn),不跑其 main
WEATHER_LIB_ONLY=1 source "$SELF_DIR/weather.sh"

# WMO code -> 氛围动效分类
wmo_cond() {
    case "$1" in
        0|1|2) printf 'clear' ;;
        3)     printf 'clouds' ;;
        45|48) printf 'fog' ;;
        51|53|55|56|57|61|63|65|66|67|80|81|82) printf 'rain' ;;
        71|73|75|77|85|86) printf 'snow' ;;
        95|96|99) printf 'thunder' ;;
        *) printf 'clouds' ;;
    esac
}

# 仅导入函数供测试
if [ "${WEATHER_EWW_LIB_ONLY:-}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi

if [ ! -f "$CACHE" ]; then
    jq -cn --arg c "$CITY" '{ok:false, city:$c, msg:"天气数据不可用"}'
    exit 0
fi

g() { jq -r "$1 // \"--\"" "$CACHE" 2>/dev/null; }

is_day=$(g '.current.is_day'); [ "$is_day" = "--" ] && is_day=1
cur_code=$(g '.current.weather_code')
temp=$(r "$(g '.current.temperature_2m')")
feel=$(r "$(g '.current.apparent_temperature')")
hum=$(g '.current.relative_humidity_2m')
pres=$(r "$(g '.current.pressure_msl')")
wspd=$(r "$(g '.current.wind_speed_10m')")
wdeg_raw=$(g '.current.wind_direction_10m'); [ "$wdeg_raw" = "--" ] && wdeg_raw=0
wdeg=$(r "$wdeg_raw")
icon=$(wmo_icon "$cur_code" "$is_day")
desc=$(wmo_text "$cur_code")
wdir=$(wind_dir_cn "$wdeg_raw")
cond=$(wmo_cond "$cur_code")

now_key=$(date +%Y-%m-%dT%H:00)
hidx=$(jq -r --arg t "$now_key" '(.hourly.time | index($t)) // 0' "$CACHE" 2>/dev/null)
[ -z "$hidx" ] || [ "$hidx" = "null" ] && hidx=0
vis_m=$(jq -r --argjson i "$hidx" '.hourly.visibility[$i] // empty' "$CACHE" 2>/dev/null)
if [ -n "$vis_m" ]; then vis=$(awk -v m="$vis_m" 'BEGIN{printf "%.1f", m/1000}'); else vis="--"; fi

sr=$(g '.daily.sunrise[0]'); ss=$(g '.daily.sunset[0]')
[ "$sr" != "--" ] && sr="${sr:11:5}"
[ "$ss" != "--" ] && ss="${ss:11:5}"
uv=$(r "$(g '.daily.uv_index_max[0]')")
pop=$(g '.daily.precipitation_probability_max[0]')
psum=$(jq -r '.daily.precipitation_sum[0] // empty' "$CACHE" 2>/dev/null)
if [ -n "$psum" ]; then psum=$(awk -v x="$psum" 'BEGIN{printf "%.1f", x}'); else psum="--"; fi

hourly_json='[]'
mapfile -t h_time < <(jq -r --argjson i "$hidx" '.hourly.time[$i:$i+6][]?'         "$CACHE" 2>/dev/null)
mapfile -t h_temp < <(jq -r --argjson i "$hidx" '.hourly.temperature_2m[$i:$i+6][]?' "$CACHE" 2>/dev/null)
mapfile -t h_code < <(jq -r --argjson i "$hidx" '.hourly.weather_code[$i:$i+6][]?'   "$CACHE" 2>/dev/null)
for k in "${!h_time[@]}"; do
    hh="${h_time[$k]:11:2}"; hh=$((10#${hh:-0}))
    ht=$(r "${h_temp[$k]:-}")
    hi=$(wmo_icon "${h_code[$k]:-x}" "$is_day")
    hourly_json=$(jq -c --arg t "${hh}时" --arg i "$hi" --arg d "$ht" \
        '. + [{time:$t, icon:$i, temp:$d}]' <<<"$hourly_json")
done

labels=(今天 明天 后天)
daily_json='[]'
for i in 0 1 2; do
    dc=$(jq -r ".daily.weather_code[$i] // \"x\""           "$CACHE" 2>/dev/null)
    dmax=$(r "$(jq -r ".daily.temperature_2m_max[$i] // \"--\"" "$CACHE" 2>/dev/null)")
    dmin=$(r "$(jq -r ".daily.temperature_2m_min[$i] // \"--\"" "$CACHE" 2>/dev/null)")
    di=$(wmo_icon "$dc" 1)
    dd=$(wmo_text "$dc")
    daily_json=$(jq -c --arg l "${labels[$i]}" --arg i "$di" --arg mn "$dmin" --arg mx "$dmax" --arg d "$dd" \
        '. + [{label:$l, icon:$i, min:$mn, max:$mx, desc:$d}]' <<<"$daily_json")
done

jq -cn \
  --arg city "$CITY" --arg icon "$icon" --arg temp "$temp" --arg desc "$desc" --arg feel "$feel" \
  --arg hum "$hum" --arg wdir "$wdir" --arg wspd "$wspd" --arg pres "$pres" --arg vis "$vis" \
  --arg wdeg "$wdeg" --arg uv "$uv" --arg sr "$sr" --arg ss "$ss" --arg pop "$pop" --arg psum "$psum" \
  --arg cond "$cond" --argjson hourly "$hourly_json" --argjson daily "$daily_json" '
{ ok:true, city:$city,
  current:{ icon:$icon, temp:$temp, desc:$desc, feel:$feel, humidity:$hum,
            wind_dir:$wdir, wind_speed:$wspd, pressure:$pres, visibility:$vis,
            wind_deg:$wdeg, uv:$uv, sunrise:$sr, sunset:$ss, pop:$pop, precip:$psum,
            cond:$cond },
  hourly:$hourly, daily:$daily }'
