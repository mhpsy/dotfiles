#!/usr/bin/env bash
# Waybar date module: emits short date with Chinese 周X label.

set -euo pipefail

days=(日 一 二 三 四 五 六)
short=$(date '+%m-%d')
zh="周${days[$(date +%w)]}"
full=$(date '+%Y-%m-%d %A')

printf '{"text":"%s %s","tooltip":"%s"}\n' "$short" "$zh" "$full"
