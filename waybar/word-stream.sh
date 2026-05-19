#!/usr/bin/env bash
# eww WP 的事件推送源（deflisten 目标）。零轮询：
#  - 启动即吐一行当前 JSON；
#  - 之后阻塞在 FIFO 上，read 超时 = 距下一个轮换点/午夜的秒数；
#  - 被唤醒（word-pick.sh 写 FIFO）或超时（10 分钟自动切换 / 跨天）后重出。
# 选词真值仍来自 word-popup.sh（其内部 wl_select 认手动 override）。
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WL_QUIET=1
. "$DIR/words-lib.sh"   # 取 ROTATE / WORDS_OVERRIDE_FILE

WAKE="${WORDS_WAKE_FIFO:-$HOME/.cache/waybar/word-wake}"
mkdir -p "$(dirname "$WAKE")" 2>/dev/null
[ -p "$WAKE" ] || { rm -f "$WAKE" 2>/dev/null; mkfifo "$WAKE" 2>/dev/null; }
# 读写方式打开：自身常驻读端，写者永不阻塞，读端永不 EOF
exec 9<>"$WAKE"

# 距下一次"当前词会变"的秒数：取 轮换边界 与 次日零点 的较小值，下限 1
secs_to_next(){
  local now rem mid to o_seed o_epoch o_pos today
  now=$(date +%s)
  today=$(date +%Y%m%d)
  rem=$ROTATE
  if [ -r "$WORDS_OVERRIDE_FILE" ]; then
    IFS=$'\t' read -r o_seed o_epoch o_pos < "$WORDS_OVERRIDE_FILE" || true
    if [ "$o_seed" = "$today" ] && [ -n "${o_epoch:-}" ] \
       && [ "$o_epoch" -ge 0 ] 2>/dev/null; then
      local el=$(( now - o_epoch )); [ "$el" -lt 0 ] && el=0
      rem=$(( ROTATE - el % ROTATE ))
    else
      rem=$(( ROTATE - now % ROTATE ))
    fi
  else
    rem=$(( ROTATE - now % ROTATE ))
  fi
  [ "$rem" -le 0 ] && rem=$ROTATE
  mid=$(( $(date -d 'tomorrow 00:00:00' +%s) - now ))
  to=$rem; [ "$mid" -lt "$to" ] && to=$mid
  [ "$to" -lt 1 ] && to=1
  printf '%s' "$to"
}

while :; do
  "$DIR/word-popup.sh" || true        # 一行紧凑 JSON
  read -t "$(secs_to_next)" -u 9 _ || true   # FIFO 唤醒 或 到点超时
done
