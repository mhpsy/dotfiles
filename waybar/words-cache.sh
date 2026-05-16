#!/usr/bin/env bash
# 预取今日 10 词的音标/音频/释义/例句，原子写入 WORDS_CACHE_FILE。幂等。
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WL_QUIET=1
. "$DIR/words-lib.sh"

command -v jq >/dev/null 2>&1 || exit 0

wl_select   # 需要 WL_IDX；前置失败则静默退出

mkdir -p "$(dirname "$WORDS_CACHE_FILE")" 2>/dev/null

# 已是今日且 10 词齐全 → 跳过
if [ -r "$WORDS_CACHE_FILE" ]; then
  cur_seed=$(jq -r '.seed // ""' "$WORDS_CACHE_FILE" 2>/dev/null)
  have=$(jq -r '.words | length' "$WORDS_CACHE_FILE" 2>/dev/null || echo 0)
  if [ "$cur_seed" = "$SEED" ] && [ "${have:-0}" -ge "$WL_TAKE" ]; then
    exit 0
  fi
fi

# 起始累加器：沿用今日已有缓存，否则空
if [ -r "$WORDS_CACHE_FILE" ] && \
   [ "$(jq -r '.seed // ""' "$WORDS_CACHE_FILE" 2>/dev/null)" = "$SEED" ]; then
  acc=$(cat "$WORDS_CACHE_FILE")
else
  acc=$(jq -nc --arg s "$SEED" '{seed:$s, words:{}}')
fi

wc_fetch(){  # $1=word，stdout=原始 API JSON，退出码透传
  if [ -n "${WORDS_FETCH_CMD:-}" ]; then
    "$WORDS_FETCH_CMD" "$1"
  else
    curl -sS --max-time 5 -A 'waybar-words/1.0' \
      "https://api.dictionaryapi.dev/api/v2/entries/en/$1"
  fi
}

wc_parse='
if type=="array" then {
  phonetic: ([.[0].phonetics[]?|select(.text!=null and .text!="")|.text]|first
             // (.[0].phonetic // "")),
  audio: ( ([.[0].phonetics[]?|select(.audio!=null and .audio!="")|.audio]) as $a
           | ([$a[]|select(test("-us\\.mp3$"))]|first) // ($a|first) // "" ),
  definition: ([.[0].meanings[]?.definitions[]?.definition]|first // ""),
  examples: ([.[0].meanings[]?.definitions[]?
              |select(.example!=null and .example!="")|.example]|.[0:2])
} else {phonetic:"",audio:"",definition:"",examples:[]} end'

for i in "${WL_IDX[@]}"; do
  w=$(wl_word_at "$i")
  # 今日缓存已有该词则跳过
  if [ "$(printf '%s' "$acc" | jq -r --arg w "$w" 'has("words") and (.words|has($w))')" = "true" ]; then
    continue
  fi
  body=$(wc_fetch "$w"); rc=$?
  [ $rc -eq 0 ] && [ -n "$body" ] || continue   # 网络失败：留待下次
  entry=$(printf '%s' "$body" | jq -c "$wc_parse" 2>/dev/null) || \
    entry='{"phonetic":"","audio":"","definition":"","examples":[]}'
  acc=$(printf '%s' "$acc" | jq -c --arg w "$w" --argjson e "$entry" '.words[$w]=$e')
done

tmp=$(mktemp "${WORDS_CACHE_FILE}.XXXXXX")
printf '%s' "$acc" > "$tmp" && mv -f "$tmp" "$WORDS_CACHE_FILE"
