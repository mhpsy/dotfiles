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
                printf ''   # clear day (nf-weather-day_sunny)
            else
                printf ''   # clear night (nf-weather-night_clear)
            fi
            ;;
        1|2)
            if [ "$day" = "1" ]; then
                printf ''   # partly cloudy day (nf-weather-day_cloudy)
            else
                printf ''   # partly cloudy night (nf-weather-night_partly_cloudy)
            fi
            ;;
        3)
            printf ''       # overcast / cloud (nf-weather-cloud)
            ;;
        45|48)
            printf ''       # fog (nf-weather-fog)
            ;;
        51|53|55|56|57|61|80)
            printf ''       # light rain / drizzle (nf-weather-rain)
            ;;
        63|65|66|67|81|82)
            printf ''       # heavy rain (nf-weather-rain_wind)
            ;;
        71|73|75|77|85|86)
            printf ''       # snow (nf-weather-snow)
            ;;
        95|96|99)
            printf ''       # thunder (nf-weather-thunderstorm)
            ;;
        *)
            printf ''       # default cloud fallback (nf-fa-cloud)
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
