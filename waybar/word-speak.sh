#!/usr/bin/env bash
# 灵动岛 🔊：只朗读当前词，不弹任何通知。WORDS_DRY_RUN=1 时打印计划不播放。
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WL_QUIET=1
. "$DIR/words-lib.sh"
PIDF="/tmp/waybar-word-mpv.pid"

# 直接用 wl_select 选词（与 word-popup.sh / 卡片同源，认手动 override）。
# 不再读 ~/.cache/waybar/current-word：那文件靠 waybar 每 interval 秒跑
# quotes.sh 才更新，手动切词后会滞后，导致念旧词。
wl_select
W="${WL_WORD:-}"
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
