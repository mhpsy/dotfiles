#!/usr/bin/env bash
# eww 弹窗数据源：当前词富信息 + 今日 N 词。复用 words-lib 选词与缓存。
# 性能：整个 today/current 用一次 jq 构建（早期版本每行 fork jq，~37 进程 → 现 ~3）。
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WL_QUIET=1
. "$DIR/words-lib.sh"

wl_select   # 设 WL_IDX[] / WL_SEL / WL_WORD / WL_POS / WL_MEANING；前置失败静默退出

# WL_IDX 数组 → JSON（纯 bash，不 fork）
idx_json="[$(IFS=,; echo "${WL_IDX[*]}")]"
# 词性字符串 "v. & n." → JSON 数组（与旧实现一致）
pos_json=$(jq -nc --arg p "$WL_POS" '($p|select(length>0)|split(" & "))//[]')

# 缓存可读则带进来，否则空对象（cache 缺失时 phonetic/example 退化为 ""）
cache='{"words":{}}'
[ -r "$WORDS_CACHE_FILE" ] && cache=$(cat "$WORDS_CACHE_FILE" 2>/dev/null) && \
  case "$cache" in '') cache='{"words":{}}';; esac

# 一次 jq 组装：current{} + today[]（today 按 WL_IDX 顺序，idx=列表位置）
jq -nc \
  --slurpfile wl "$WORDLIST_FILE" \
  --argjson idx "$idx_json" \
  --argjson sel "$WL_SEL" \
  --argjson pos "$pos_json" \
  --argjson cache "$cache" \
  '
  ($wl[0].words) as $W
  | ($cache.words // {}) as $C
  | ($W[$sel].word) as $cw
  | {
      current: {
        word:      $cw,
        pos:       $pos,
        phonetic: ($C[$cw].phonetic    // ""),
        meaning:  ($W[$sel].meaning),
        example:  ($C[$cw].examples[0] // "")
      },
      today: [ $idx | to_entries[] | {
        word:    $W[.value].word,
        meaning: $W[.value].meaning,
        current: (.value == $sel),
        idx:     .key
      } ]
    }'
