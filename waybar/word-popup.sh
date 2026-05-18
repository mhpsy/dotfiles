#!/usr/bin/env bash
# eww 弹窗数据源：当前词富信息 + 今日 10 词。复用 words-lib 选词与缓存。
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WL_QUIET=1
. "$DIR/words-lib.sh"

wl_select   # 设 WL_IDX/WL_SEL/WL_WORD/WL_POS/WL_MEANING；前置失败静默退出

ph=""; ex=""
if [ -r "$WORDS_CACHE_FILE" ]; then
  ph=$(jq -r --arg w "$WL_WORD" '.words[$w].phonetic    // ""' "$WORDS_CACHE_FILE" 2>/dev/null)
  ex=$(jq -r --arg w "$WL_WORD" '.words[$w].examples[0] // ""' "$WORDS_CACHE_FILE" 2>/dev/null)
fi
pos_json=$(jq -nc --arg p "$WL_POS" '($p|select(length>0)|split(" & "))//[]')

today="[]"
for i in "${WL_IDX[@]}"; do
  w=$(wl_word_at "$i"); m=$(wl_meaning_at "$i")
  cur=$([ "$i" = "$WL_SEL" ] && echo true || echo false)
  today=$(jq -c --arg w "$w" --arg m "$m" --argjson c "$cur" \
    '. + [{word:$w,meaning:$m,current:$c}]' <<<"$today")
done

jq -nc \
  --arg w "$WL_WORD" --argjson pos "$pos_json" --arg ph "$ph" \
  --arg m "$WL_MEANING" --arg ex "$ex" --argjson today "$today" \
  '{current:{word:$w,pos:$pos,phonetic:$ph,meaning:$m,example:$ex},today:$today}'
