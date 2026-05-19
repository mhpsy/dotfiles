#!/usr/bin/env bash
# 灵动岛「今日单词」列表点击：手动切到第 $1 个词（0 基，今日 WL_IDX 内的位置），
# 并把 10 分钟自动轮换的计时从此刻重置。写 WORDS_OVERRIDE_FILE，供 words-lib 读。
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WL_QUIET=1
. "$DIR/words-lib.sh"   # 取 SEED / WORDS_OVERRIDE_FILE / DAILY

p="${1:-}"
case "$p" in ''|*[!0-9]*) exit 0 ;; esac   # 非法/缺参 → 静默忽略
[ "$p" -lt "$DAILY" ] 2>/dev/null || exit 0  # 超出今日词数 → 忽略

mkdir -p "$(dirname "$WORDS_OVERRIDE_FILE")" 2>/dev/null
if tmp=$(mktemp "${WORDS_OVERRIDE_FILE}.XXXXXX" 2>/dev/null); then
  trap 'rm -f "$tmp"' EXIT
  printf '%s\t%s\t%s' "$SEED" "$(date +%s)" "$p" > "$tmp" \
    && mv -f "$tmp" "$WORDS_OVERRIDE_FILE"
fi

# 立刻唤醒 word-stream.sh 重出 JSON（事件推送，无需等轮询）。
# stream 常驻读端时写不阻塞；无 stream 时 timeout 兜底，不影响选词。
WAKE="${WORDS_WAKE_FIFO:-$HOME/.cache/waybar/word-wake}"
[ -p "$WAKE" ] && timeout 0.3 sh -c 'echo > "$1"' _ "$WAKE" 2>/dev/null
exit 0
