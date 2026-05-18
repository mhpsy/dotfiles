#!/usr/bin/env bash
# Waybar 每日单词：日期种子确定性抽 10，每 10 秒轮换。
# 选词见 words-lib.sh；tooltip 顶部用 ~/.cache/waybar/words.json 富信息。
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/words-lib.sh"

wl_select   # 设 WL_IDX/WL_SEL/WL_WORD/WL_MEANING；前置失败则已空输出退出

# 记录当前显示词，供 on-click 精确朗读（避免点击跨轮换边界取到不同词）
mkdir -p "$(dirname "$WORDS_STATE_FILE")" 2>/dev/null
if _sf_tmp=$(mktemp "${WORDS_STATE_FILE}.XXXXXX" 2>/dev/null); then
  printf '%s\t%s' "$WL_WORD" "$WL_MEANING" > "$_sf_tmp" && mv -f "$_sf_tmp" "$WORDS_STATE_FILE" || rm -f "$_sf_tmp"
fi

# 后台懒触发预取：缓存缺失或非今日 seed（WORDS_NO_PREFETCH=1 跳过）
cache_seed=""
[ -r "$WORDS_CACHE_FILE" ] && \
  cache_seed=$(jq -r '.seed // ""' "$WORDS_CACHE_FILE" 2>/dev/null)
if [ -z "${WORDS_NO_PREFETCH:-}" ] && [ "$cache_seed" != "$SEED" ]; then
  mkdir -p "$(dirname "$WORDS_LOCK_FILE")" 2>/dev/null
  setsid flock -n "$WORDS_LOCK_FILE" "$DIR/words-cache.sh" >/dev/null 2>&1 &
fi

# 当前词富信息（缓存就绪时）
ph=""; ex=""
if [ -r "$WORDS_CACHE_FILE" ]; then
  ph=$(jq -r --arg w "$WL_WORD" '.words[$w].phonetic // ""' "$WORDS_CACHE_FILE" 2>/dev/null)
  ex=$(jq -r --arg w "$WL_WORD" '.words[$w].examples[0] // ""' "$WORDS_CACHE_FILE" 2>/dev/null)
fi

# bar text：词 + 词性 + 释义，拼回旧视觉（空词性不留双空格）
parts="$WL_WORD"
[ -n "${WL_POS:-}" ] && parts="$parts $WL_POS"
parts="$parts $WL_MEANING"
jq -nc --arg t "$parts" '{text:$t}'
