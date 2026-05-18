#!/usr/bin/env bash
# 共享：waybar 每日单词的确定性选词逻辑。
# 被 quotes.sh / speak-word.sh / words-cache.sh source。
# 洗牌算法与原 quotes.sh 完全一致：openssl AES-CTR keystream 喂 shuf。

WORDLIST_FILE="${WORDLIST_FILE:-$HOME/.config/waybar/wordlist.json}"
SEED="${WORDS_SEED:-$(date +%Y%m%d)}"
EPOCH="${WORDS_EPOCH:-$(date +%s)}"
WORDS_CACHE_FILE="${WORDS_CACHE_FILE:-$HOME/.cache/waybar/words.json}"
WORDS_LOCK_FILE="${WORDS_LOCK_FILE:-$HOME/.cache/waybar/words.lock}"
WORDS_STATE_FILE="${WORDS_STATE_FILE:-$HOME/.cache/waybar/current-word}"
# 手动选词覆盖：点列表里某词后写入 "SEED\t锚点epoch\t锚点pos"，
# 之后从锚点起每 ROTATE 秒继续往后轮换（点击 = 重置 10 分钟计时）。
WORDS_OVERRIDE_FILE="${WORDS_OVERRIDE_FILE:-$HOME/.cache/waybar/word-override}"
DAILY=10
ROTATE=600   # 秒/词（10 分钟自动切换）

# waybar 空输出约定。WL_QUIET=1 时静默（供 on-click 脚本用）。
wl_emit_empty(){
  [ -n "${WL_QUIET:-}" ] || echo '{"text": "", "class": "empty"}'
  exit 0
}

# 前置检查；任一不满足按空输出退出（行为同原 quotes.sh）。
wl_preflight(){
  command -v jq >/dev/null 2>&1 || wl_emit_empty
  [ -r "$WORDLIST_FILE" ] || wl_emit_empty
  WL_N=$(jq '.words | length' "$WORDLIST_FILE" 2>/dev/null) || wl_emit_empty
  [ -n "$WL_N" ] && [ "$WL_N" -gt 0 ] 2>/dev/null || wl_emit_empty
}

wl_rand_src(){ openssl enc -aes-256-ctr -pass "pass:$SEED" -nosalt </dev/zero 2>/dev/null; }

# 选词：填充 WL_N WL_TAKE WL_IDX[] WL_SEL WL_WORD WL_MEANING
wl_select(){
  wl_preflight
  WL_TAKE=$DAILY
  [ "$WL_N" -lt "$DAILY" ] && WL_TAKE=$WL_N
  mapfile -t WL_IDX < <(shuf -i 0-$((WL_N-1)) -n "$WL_TAKE" --random-source=<(wl_rand_src))
  local pos=""
  # 有当日有效手动覆盖：从锚点 pos 起按 ROTATE 继续轮换
  if [ -r "$WORDS_OVERRIDE_FILE" ]; then
    local o_seed="" o_epoch="" o_pos=""
    IFS=$'\t' read -r o_seed o_epoch o_pos < "$WORDS_OVERRIDE_FILE" || true
    if [ "$o_seed" = "$SEED" ] \
       && [ -n "$o_epoch" ] && [ "$o_epoch" -ge 0 ] 2>/dev/null \
       && [ -n "$o_pos" ] && [ "$o_pos" -ge 0 ] 2>/dev/null \
       && [ "$o_pos" -lt "$WL_TAKE" ] 2>/dev/null; then
      local elapsed=$(( EPOCH - o_epoch ))
      [ "$elapsed" -lt 0 ] && elapsed=0
      pos=$(( ( o_pos + elapsed / ROTATE ) % WL_TAKE ))
    fi
  fi
  # 无覆盖（或跨天失效）：纯时间公式
  [ -z "$pos" ] && pos=$(( (EPOCH / ROTATE) % WL_TAKE ))
  WL_SEL=${WL_IDX[$pos]}
  WL_WORD=$(jq -r ".words[$WL_SEL].word"    "$WORDLIST_FILE")
  WL_MEANING=$(jq -r ".words[$WL_SEL].meaning" "$WORDLIST_FILE")
  WL_POS=$(wl_pos_at "$WL_SEL")
}

wl_word_at(){ jq -r ".words[$1].word" "$WORDLIST_FILE"; }
wl_meaning_at(){ jq -r ".words[$1].meaning" "$WORDLIST_FILE"; }
wl_pos_at(){ jq -r ".words[$1].pos // [] | join(\" & \")" "$WORDLIST_FILE"; }
