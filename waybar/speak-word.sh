#!/usr/bin/env bash
# Waybar 每日单词 on-click：朗读当前词 + notify-send 例句。
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WL_QUIET=1
. "$DIR/words-lib.sh"

PIDF="/tmp/waybar-word-mpv.pid"

wl_select   # 当前词 = quotes.sh 当下显示的同一个
W="${WL_WORD:-}"
[ -n "$W" ] || exit 0

ph=""; ex=""; au=""
if [ -r "$WORDS_CACHE_FILE" ]; then
  ph=$(jq -r --arg w "$W" '.words[$w].phonetic  // ""' "$WORDS_CACHE_FILE" 2>/dev/null)
  au=$(jq -r --arg w "$W" '.words[$w].audio     // ""' "$WORDS_CACHE_FILE" 2>/dev/null)
  ex=$(jq -r --arg w "$W" '.words[$w].examples[0] // ""' "$WORDS_CACHE_FILE" 2>/dev/null)
fi

# 选音源
if [ -n "$au" ]; then
  src="cache"; url="$au"
else
  src="gtts"
  url="https://translate.google.com/translate_tts?ie=UTF-8&tl=en&client=tw-ob&q=$W"
fi

title="$W"
[ -n "$ph" ] && title="$W  $ph"
body="$WL_MEANING"
[ -n "$ex" ] && body="$body"$'\n\n'"例: $ex"

if [ -n "${WORDS_DRY_RUN:-}" ]; then
  printf 'WORD=%s\n' "$W"
  printf 'AUDIO_SRC=%s\n' "$src"
  printf 'NOTIFY_TITLE=%s\n' "$title"
  printf 'NOTIFY_BODY=%s\n' "$(printf '%s' "$body" | sed ':a;N;$!ba;s/\n/\\n/g')"
  exit 0
fi

# 仅杀本脚本上次的 mpv（按 pid 文件 + comm 校验，不动用户其它 mpv）
if [ -r "$PIDF" ]; then
  old=$(cat "$PIDF" 2>/dev/null)
  if [ -n "$old" ] && [ "$(cat /proc/"$old"/comm 2>/dev/null)" = "mpv" ]; then
    kill "$old" 2>/dev/null
  fi
fi

if command -v notify-send >/dev/null 2>&1; then
  notify-send -a "waybar-words" "$title" "$body"
fi

if command -v mpv >/dev/null 2>&1; then
  mpv --no-video --no-terminal --really-quiet "$url" >/dev/null 2>&1 &
  echo $! > "$PIDF"
fi
