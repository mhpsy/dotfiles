#!/usr/bin/env bash
# Waybar 每日单词 on-click：朗读当前词 + notify-send 例句。
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WL_QUIET=1
. "$DIR/words-lib.sh"

PIDF="/tmp/waybar-word-mpv.pid"

# 优先读 quotes.sh 写下的"当前显示词"，确保朗读的就是 bar 上那个；
# 状态文件缺失时回落到确定性选词。
W=""; MEANING=""
if [ -r "$WORDS_STATE_FILE" ]; then
  IFS=$'\t' read -r W MEANING < "$WORDS_STATE_FILE" || true
fi
if [ -z "$W" ]; then
  wl_select
  W="${WL_WORD:-}"
  MEANING="${WL_MEANING:-}"
fi
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
body="$MEANING"
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
  if [ -n "$old" ] && tr '\0' ' ' < /proc/"$old"/cmdline 2>/dev/null | grep -q 'waybar-word-tts'; then
    kill "$old" 2>/dev/null
  fi
fi

if command -v notify-send >/dev/null 2>&1; then
  notify-send -a "waybar-words" "$title" "$body"
fi

if command -v mpv >/dev/null 2>&1; then
  mpv --no-video --no-terminal --really-quiet --force-media-title=waybar-word-tts "$url" >/dev/null 2>&1 &
  echo $! > "$PIDF"
fi
