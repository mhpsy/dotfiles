#!/usr/bin/env bash
# 灵动岛 🔊：只朗读当前词，不弹任何通知。WORDS_DRY_RUN=1 时打印计划不播放。
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WL_QUIET=1
. "$DIR/words-lib.sh"
PIDF="/tmp/waybar-word-mpv.pid"

W=""
if [ -r "$WORDS_STATE_FILE" ]; then
  IFS=$'\t' read -r W _ < "$WORDS_STATE_FILE" || true
fi
if [ -z "$W" ]; then
  wl_select; W="${WL_WORD:-}"
fi
[ -n "$W" ] || exit 0

au=""
[ -r "$WORDS_CACHE_FILE" ] && \
  au=$(jq -r --arg w "$W" '.words[$w].audio // ""' "$WORDS_CACHE_FILE" 2>/dev/null)
if [ -n "$au" ]; then
  src="cache"; url="$au"
else
  src="gtts"
  url="https://translate.google.com/translate_tts?ie=UTF-8&tl=en&client=tw-ob&q=$W"
fi

if [ -n "${WORDS_DRY_RUN:-}" ]; then
  printf 'WORD=%s\nAUDIO_SRC=%s\n' "$W" "$src"
  exit 0
fi

if [ -r "$PIDF" ]; then
  old=$(cat "$PIDF" 2>/dev/null)
  if [ -n "$old" ] && tr '\0' ' ' < /proc/"$old"/cmdline 2>/dev/null \
     | grep -q 'waybar-word-tts'; then
    kill "$old" 2>/dev/null
  fi
fi
if command -v mpv >/dev/null 2>&1; then
  mpv --no-video --no-terminal --really-quiet \
      --force-media-title=waybar-word-tts "$url" >/dev/null 2>&1 &
  echo $! > "$PIDF"
fi
