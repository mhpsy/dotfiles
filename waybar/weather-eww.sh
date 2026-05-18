#!/usr/bin/env bash
# Waybar 天气灵动岛数据脚本 — 读 weather.sh 的共享缓存,输出 eww 结构化 JSON。
# 不主动联网(联网由 waybar 侧 weather.sh 周期触发)。
# See docs/superpowers/specs/2026-05-18-weather-dynamic-island-design.md
set -u
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="/tmp/waybar-openmeteo.json"
CITY="深圳宝安"

# 导入 weather.sh 纯函数(r / wmo_text / wmo_icon / wind_dir_cn),不跑其 main
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

jq -cn --arg c "$CITY" '{ok:true, city:$c}'
