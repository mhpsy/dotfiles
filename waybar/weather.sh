#!/usr/bin/env bash
# Waybar weather — Open-Meteo (free, no API key).
# bar shows weather icon; tooltip: current / hourly 6h / 3-day + sunrise/sunset/UV/precip/pressure/visibility.
# See docs/superpowers/specs/2026-05-18-weather-open-meteo-design.md
set -u

CACHE="/tmp/waybar-openmeteo.json"
CACHE_AGE=900
LAT="22.57"
LON="113.85"
CITY="深圳宝安"

API="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}\
&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,pressure_msl,wind_speed_10m,wind_direction_10m\
&hourly=temperature_2m,weather_code,visibility,precipitation_probability\
&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max,precipitation_sum\
&timezone=Asia/Shanghai&forecast_days=3"

# ---- pure functions (unit-test covered) ----

# Round to integer via awk; non-numeric -> "--"
r() {
    awk -v x="${1:-}" 'BEGIN{
        if (x ~ /^-?[0-9]+(\.[0-9]+)?$/) printf "%.0f", x;
        else print "--";
    }'
}

# WMO weather code -> Chinese description
wmo_text() {
    case "$1" in
        0)  printf '晴' ;;
        1)  printf '晴间多云' ;;
        2)  printf '多云' ;;
        3)  printf '阴' ;;
        45) printf '雾' ;;
        48) printf '雾凇' ;;
        51) printf '小毛毛雨' ;;
        53) printf '毛毛雨' ;;
        55) printf '大毛毛雨' ;;
        56) printf '冻毛毛雨' ;;
        57) printf '强冻毛毛雨' ;;
        61) printf '小雨' ;;
        63) printf '中雨' ;;
        65) printf '大雨' ;;
        66) printf '冻雨' ;;
        67) printf '强冻雨' ;;
        71) printf '小雪' ;;
        73) printf '中雪' ;;
        75) printf '大雪' ;;
        77) printf '米雪' ;;
        80) printf '小阵雨' ;;
        81) printf '阵雨' ;;
        82) printf '强阵雨' ;;
        85) printf '小阵雪' ;;
        86) printf '阵雪' ;;
        95) printf '雷阵雨' ;;
        96) printf '雷阵雨伴小冰雹' ;;
        99) printf '雷阵雨伴冰雹' ;;
        *)  printf '未知' ;;
    esac
}

# WMO code + is_day(1/0) -> Nerd Font glyph (via printf '\uXXXX')
wmo_icon() {
    local code="$1" day="${2:-1}"
    case "$code" in
        0)
            if [ "$day" = "1" ]; then
                printf '\uf185'   # clear day (nf-fa-sun_o)
            else
                printf '\uf186'   # clear night (nf-fa-moon_o)
            fi
            ;;
        1|2)
            if [ "$day" = "1" ]; then
                printf '\uf6c4'   # partly cloudy day (nf-weather-day_cloudy)
            else
                printf '\uf6c3'   # partly cloudy night (nf-weather-night_cloudy)
            fi
            ;;
        3)
            printf '\uf0c2'       # overcast / cloud (nf-fa-cloud)
            ;;
        45|48)
            printf '\uf75f'       # fog (nf-weather-fog)
            ;;
        51|53|55|56|57|61|80)
            printf '\uf73d'       # light rain / drizzle (nf-weather-rain)
            ;;
        63|65|66|67|81|82)
            printf '\uf740'       # heavy rain (nf-weather-showers)
            ;;
        71|73|75|77|85|86)
            printf '\uf2dc'       # snow (nf-fa-snowflake_o)
            ;;
        95|96|99)
            printf '\uf76c'       # thunder (nf-weather-thunderstorm)
            ;;
        *)
            printf '\uf0c2'       # default cloud fallback (nf-fa-cloud)
            ;;
    esac
}

# Wind direction in degrees -> Chinese 16-point compass
wind_dir_cn() {
    local deg="${1:-0}" idx
    local names=(北 北东北 东北 东东北 东 东东南 东南 南东南 \
                 南 南西南 西南 西西南 西 西西北 西北 北西北)
    idx=$(awk -v d="$deg" 'BEGIN{ printf "%d", (int(d/22.5+0.5))%16 }')
    printf '%s' "${names[$idx]}"
}

# ---- allow sourcing functions only (for tests), skip main ----
if [ "${WEATHER_LIB_ONLY:-}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi

# ---- fetch (only if cache stale/missing; atomic write, failure won't poison good cache) ----
need_fetch=1
if [ -f "$CACHE" ] && [ $(( $(date +%s) - $(stat -c %Y "$CACHE") )) -le "$CACHE_AGE" ]; then
    need_fetch=0
fi
if [ "$need_fetch" = "1" ]; then
    tmp=$(mktemp /tmp/waybar-openmeteo.XXXXXX)
    if curl -sf --compressed --connect-timeout 10 "$API" -o "$tmp" 2>/dev/null \
       && jq -e '.current.temperature_2m != null' "$tmp" >/dev/null 2>&1; then
        mv -f "$tmp" "$CACHE"
    else
        rm -f "$tmp"
    fi
fi

if [ ! -f "$CACHE" ]; then
    echo '{"text":"","tooltip":"Weather unavailable"}'
    exit 0
fi

# ---- scalars; missing -> "--" ----
g() { jq -r "$1 // \"--\"" "$CACHE" 2>/dev/null; }

is_day=$(g '.current.is_day')
[ "$is_day" = "--" ] && is_day=1
cur_code=$(g '.current.weather_code')
cur_temp=$(r "$(g '.current.temperature_2m')")
cur_feel=$(r "$(g '.current.apparent_temperature')")
cur_hum=$(g '.current.relative_humidity_2m')
cur_pres=$(r "$(g '.current.pressure_msl')")
cur_wspd=$(r "$(g '.current.wind_speed_10m')")
cur_wdeg_raw=$(g '.current.wind_direction_10m')
cur_wdeg=$(r "$cur_wdeg_raw")
[ "$cur_wdeg_raw" = "--" ] && cur_wdeg_raw=0

icon=$(wmo_icon "$cur_code" "$is_day")
desc=$(wmo_text "$cur_code")
wdir=$(wind_dir_cn "$cur_wdeg_raw")

# current hour -> hourly index (fallback 0)
now_key=$(date +%Y-%m-%dT%H:00)
hidx=$(jq -r --arg t "$now_key" '(.hourly.time | index($t)) // 0' "$CACHE" 2>/dev/null)
[ -z "$hidx" ] || [ "$hidx" = "null" ] && hidx=0

vis_m=$(jq -r --argjson i "$hidx" '.hourly.visibility[$i] // empty' "$CACHE" 2>/dev/null)
if [ -n "$vis_m" ]; then
    vis_km=$(awk -v m="$vis_m" 'BEGIN{ printf "%.1f", m/1000 }')
else
    vis_km="--"
fi

sr=$(g '.daily.sunrise[0]')
ss=$(g '.daily.sunset[0]')
[ "$sr" != "--" ] && sr="${sr:11:5}"
[ "$ss" != "--" ] && ss="${ss:11:5}"
uv=$(r "$(g '.daily.uv_index_max[0]')")
pop=$(g '.daily.precipitation_probability_max[0]')
psum=$(jq -r '.daily.precipitation_sum[0] // empty' "$CACHE" 2>/dev/null)
if [ -n "$psum" ]; then
    psum=$(awk -v x="$psum" 'BEGIN{ printf "%.1f", x }')
else
    psum="--"
fi

# hourly next 6 hours
mapfile -t h_time < <(jq -r --argjson i "$hidx" '.hourly.time[$i:$i+6][]?'         "$CACHE" 2>/dev/null)
mapfile -t h_temp < <(jq -r --argjson i "$hidx" '.hourly.temperature_2m[$i:$i+6][]?' "$CACHE" 2>/dev/null)
mapfile -t h_code < <(jq -r --argjson i "$hidx" '.hourly.weather_code[$i:$i+6][]?'   "$CACHE" 2>/dev/null)
hourly_line="逐时 "
for k in "${!h_time[@]}"; do
    hh="${h_time[$k]:11:2}"
    hh=$((10#${hh:-0}))
    ht=$(r "${h_temp[$k]:-}")
    hi=$(wmo_icon "${h_code[$k]:-x}" "$is_day")
    hourly_line+=" ${hh}时 ${ht}°${hi} "
done

# 3-day forecast
days=(今天 明天 后天)
forecast=""
for i in 0 1 2; do
    d_code=$(jq -r ".daily.weather_code[$i] // \"x\""        "$CACHE" 2>/dev/null)
    d_max=$(r "$(jq -r ".daily.temperature_2m_max[$i] // \"--\"" "$CACHE" 2>/dev/null)")
    d_min=$(r "$(jq -r ".daily.temperature_2m_min[$i] // \"--\"" "$CACHE" 2>/dev/null)")
    d_icon=$(wmo_icon "$d_code" 1)
    d_desc=$(wmo_text "$d_code")
    forecast+=$'\n'"${d_icon}  ${days[$i]}  ${d_min}° ~ ${d_max}°C  ${d_desc}"
done

# ---- assemble tooltip (real newlines, jq encodes to valid JSON) ----
sep="─────────────────────"
tooltip="<b>${CITY}  ${cur_temp}°C  ${desc}</b>"
tooltip+=$'\n'"体感 ${cur_feel}°C  |  湿度 ${cur_hum}%  |  ${wdir} ${cur_wspd} km/h"
tooltip+=$'\n'"气压 ${cur_pres} hPa  |  能见度 ${vis_km} km  |  风向 ${cur_wdeg}°"
tooltip+=$'\n'"日出 ${sr}  ·  日落 ${ss}  |  UV ${uv}  降水 ${pop}% (${psum}mm)"
tooltip+=$'\n'"${sep}"
tooltip+=$'\n'"${hourly_line}"
tooltip+=$'\n'"${sep}"
tooltip+="${forecast}"

jq -cn --arg x "$icon" --arg t "$tooltip" '{text:$x, tooltip:$t}'
