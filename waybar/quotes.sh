#!/usr/bin/env bash
# Waybar 每日单词：本地词库日期种子确定性抽 10，按 epoch 每 10 秒轮换一个。
set -u

WORDLIST_FILE="${WORDLIST_FILE:-$HOME/.config/waybar/wordlist.json}"
SEED="${WORDS_SEED:-$(date +%Y%m%d)}"
EPOCH="${WORDS_EPOCH:-$(date +%s)}"
DAILY=10
ROTATE=10   # 秒/词

emit_empty(){ echo '{"text": "", "class": "empty"}'; exit 0; }

command -v jq >/dev/null 2>&1 || emit_empty
[ -r "$WORDLIST_FILE" ] || emit_empty

N=$(jq '.words | length' "$WORDLIST_FILE" 2>/dev/null) || emit_empty
[ -n "$N" ] && [ "$N" -gt 0 ] 2>/dev/null || emit_empty

# 今日取多少个（词库不足 DAILY 时有几个用几个）
take=$DAILY
[ "$N" -lt "$DAILY" ] && take=$N

# 确定性字节流：以 SEED 为口令的 AES-CTR keystream
rand_src() { openssl enc -aes-256-ctr -pass "pass:$SEED" -nosalt </dev/zero 2>/dev/null; }

# 今日下标集合（确定性洗牌取前 take 个）
mapfile -t IDX < <(shuf -i 0-$((N-1)) -n "$take" --random-source=<(rand_src))

# 轮换位置
pos=$(( (EPOCH / ROTATE) % take ))
sel=${IDX[$pos]}

word=$(jq -r ".words[$sel].word"    "$WORDLIST_FILE")
mean=$(jq -r ".words[$sel].meaning" "$WORDLIST_FILE")

# tooltip：今日全部 take 个词
tip="今日单词"
for i in "${IDX[@]}"; do
  w=$(jq -r ".words[$i].word"    "$WORDLIST_FILE")
  m=$(jq -r ".words[$i].meaning" "$WORDLIST_FILE")
  tip="$tip\n$w  $m"
done

# 用 jq 组装输出，安全转义
jq -nc --arg t "$word $mean" --arg tip "$tip" '{text:$t, tooltip:$tip}'
