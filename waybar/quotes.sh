#!/usr/bin/env bash
# Waybar 每日单词：本地词库日期种子确定性抽 10，按 epoch 每 10 秒轮换一个。
# 选词逻辑见 words-lib.sh。
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/words-lib.sh"

wl_select   # 设 WL_IDX/WL_SEL/WL_WORD/WL_MEANING；前置失败则已空输出退出

nl=$'\n'
tip="今日单词"
for i in "${WL_IDX[@]}"; do
  tip="$tip$nl$(wl_word_at "$i")  $(wl_meaning_at "$i")"
done

jq -nc --arg t "$WL_WORD $WL_MEANING" --arg tip "$tip" '{text:$t, tooltip:$tip}'
