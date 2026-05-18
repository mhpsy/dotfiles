#!/usr/bin/env bash
# quotes.sh 行为测试。用固定 fixture + 固定 seed/epoch 断言确定性、轮换、跨天、错误处理。
set -u
SCRIPT="$HOME/.config/waybar/quotes.sh"
FIX="$(mktemp)"
STATE_TMP="$(mktemp)"
export WORDS_STATE_FILE="$STATE_TMP"
trap 'rm -f "$FIX" "$STATE_TMP"' EXIT

cat > "$FIX" <<'JSON'
{"words":[
{"word":"w0","meaning":"m0"},{"word":"w1","meaning":"m1"},
{"word":"w2","meaning":"m2"},{"word":"w3","meaning":"m3"},
{"word":"w4","meaning":"m4"},{"word":"w5","meaning":"m5"},
{"word":"w6","meaning":"m6"},{"word":"w7","meaning":"m7"},
{"word":"w8","meaning":"m8"},{"word":"w9","meaning":"m9"},
{"word":"w10","meaning":"m10"},{"word":"w11","meaning":"m11"},
{"word":"w12","meaning":"m12"},{"word":"w13","meaning":"m13"},
{"word":"w14","meaning":"m14"}
]}
JSON

fail=0
chk(){ if [ "$1" != "$2" ]; then echo "FAIL $3: expected [$2] got [$1]"; fail=1; else echo "ok $3"; fi; }

# 1. 输出是合法 JSON 且有 text 字段
out=$(WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=0 bash "$SCRIPT")
echo "$out" | jq -e '.text' >/dev/null 2>&1; chk "$?" "0" "valid-json-has-text"

# 2. 确定性：同 seed 同 epoch 两次结果一致
a=$(WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=0 bash "$SCRIPT")
b=$(WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=0 bash "$SCRIPT")
chk "$a" "$b" "deterministic-same-seed-epoch"

# 3. 轮换：epoch 进 10 秒 → text 通常变化（遍历 0..9 应出现 >1 种）
uniq=$(for e in 0 10 20 30 40 50 60 70 80 90; do
  WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=$e bash "$SCRIPT" | jq -r '.text'
done | sort -u | wc -l)
[ "$uniq" -gt 1 ] && chk "0" "0" "rotation-varies" || chk "1" "0" "rotation-varies"

# 4. 跨天：不同 seed → 今日 10 词集合应不同（tooltip 不同）
t1=$(WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=0 bash "$SCRIPT" | jq -r '.tooltip')
t2=$(WORDLIST_FILE="$FIX" WORDS_SEED=20260516 WORDS_EPOCH=0 bash "$SCRIPT" | jq -r '.tooltip')
[ "$t1" != "$t2" ] && chk "0" "0" "cross-day-changes" || chk "1" "0" "cross-day-changes"

# 5. 错误处理：文件不存在 → class empty 且不报错
out=$(WORDLIST_FILE="/nonexistent/xx.json" WORDS_SEED=20260515 WORDS_EPOCH=0 bash "$SCRIPT")
cls=$(echo "$out" | jq -r '.class // ""' 2>/dev/null)
chk "$cls" "empty" "missing-file-empty-class"

# === Task1: words-lib 与 quotes.sh 选词一致 ===
LIB="$HOME/.config/waybar/words-lib.sh"
libsel=$(
  WL_QUIET=1 WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=30 \
  bash -c '. "$0"; wl_select; printf "%s %s" "$WL_WORD" "$WL_MEANING"' "$LIB" 2>/dev/null
)
qtext=$(WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=30 bash "$SCRIPT" | jq -r '.text')
chk "$libsel" "$qtext" "lib-matches-quotes-text"

# === Task2: words-cache 写缓存 + 幂等 ===
CACHE_DIR="$(mktemp -d)"
trap 'rm -f "$FIX" "$STATE_TMP"; rm -rf "$CACHE_DIR"' EXIT
CF="$CACHE_DIR/words.json"
CALLS="$CACHE_DIR/calls"
: > "$CALLS"
STUB="$CACHE_DIR/stub.sh"
cat > "$STUB" <<'STUBEOF'
#!/usr/bin/env bash
# 测试用 fetch stub：记录调用次数，回 dictionaryapi.dev 形状的 JSON
echo "$1" >> "$CALLS_FILE"
printf '[{"phonetic":"/p-%s/","phonetics":[{"text":"/p-%s/","audio":"https://x/%s-us.mp3"}],"meanings":[{"definitions":[{"definition":"def-%s","example":"ex-%s one"},{"definition":"d2","example":"ex-%s two"}]}]}]' "$1" "$1" "$1" "$1" "$1" "$1"
STUBEOF
chmod +x "$STUB"
CACHE="$HOME/.config/waybar/words-cache.sh"

CALLS_FILE="$CALLS" WORDS_CACHE_FILE="$CF" WORDS_FETCH_CMD="$STUB" \
  WORDLIST_FILE="$FIX" WORDS_SEED=20260515 bash "$CACHE"
echo "$CF exists" ; [ -s "$CF" ] && r=0 || r=1; chk "$r" "0" "cache-file-written"
jq -e '.seed=="20260515" and (.words|length)==10' "$CF" >/dev/null 2>&1; chk "$?" "0" "cache-seed-and-10-words"
n1=$(wc -l < "$CALLS")
# 第二次跑：缓存已今日且齐全 → 不应再调 fetch（幂等）
CALLS_FILE="$CALLS" WORDS_CACHE_FILE="$CF" WORDS_FETCH_CMD="$STUB" \
  WORDLIST_FILE="$FIX" WORDS_SEED=20260515 bash "$CACHE"
n2=$(wc -l < "$CALLS")
chk "$n1" "$n2" "cache-idempotent-no-refetch"
# 任取一个今日词，断言字段齐全
fw=$(WL_QUIET=1 WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=0 \
  bash -c '. "$0"; wl_select; printf "%s" "$WL_WORD"' "$HOME/.config/waybar/words-lib.sh")
got=$(jq -r --arg w "$fw" '.words[$w] | "\(.phonetic)|\(.audio)|\(.examples|length)"' "$CF")
chk "$got" "/p-$fw/|https://x/$fw-us.mp3|2" "cache-entry-fields"

# === Task3: quotes.sh tooltip 富信息块 ===
# 复用 Task2 的 $CF（已含今日 10 词富信息）。当前词：
cw=$(WL_QUIET=1 WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=0 \
  bash -c '. "$0"; wl_select; printf "%s" "$WL_WORD"' "$HOME/.config/waybar/words-lib.sh")
ttip=$(WORDS_NO_PREFETCH=1 WORDS_CACHE_FILE="$CF" WORDLIST_FILE="$FIX" \
  WORDS_SEED=20260515 WORDS_EPOCH=0 bash "$SCRIPT" | jq -r '.tooltip')
case "$ttip" in
  "▶ $cw  /p-$cw/"*"例: ex-$cw one"*"今日单词"*) chk "0" "0" "tooltip-rich-block" ;;
  *) echo "got tooltip: $ttip"; chk "1" "0" "tooltip-rich-block" ;;
esac
# 无缓存降级：tooltip 仍是合法 JSON、不含「例:」、不报错
out=$(WORDS_NO_PREFETCH=1 WORDS_CACHE_FILE="/nonexistent/none.json" \
  WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=0 bash "$SCRIPT")
echo "$out" | jq -e '.text and .tooltip' >/dev/null 2>&1; chk "$?" "0" "tooltip-degrade-valid"
echo "$out" | jq -r '.tooltip' | grep -q '例:' && chk "1" "0" "tooltip-degrade-no-example" \
  || chk "0" "0" "tooltip-degrade-no-example"

# === Task4: speak-word.sh 解析 + dry-run ===
SPEAK="$HOME/.config/waybar/speak-word.sh"
SF="$CACHE_DIR/curword"
# quotes.sh 在该 seed/epoch 渲染并写下当前词
qfirst=$(WORDS_NO_PREFETCH=1 WORDS_STATE_FILE="$SF" WORDS_CACHE_FILE="$CF" \
  WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=20 bash "$SCRIPT" \
  | jq -r '.text' | awk '{print $1}')
# speak-word 读状态文件 → 必与 quotes 渲染的词一致（防漂移，验收 #8）
dr=$(WORDS_DRY_RUN=1 WORDS_STATE_FILE="$SF" WORDS_CACHE_FILE="$CF" \
  WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=20 bash "$SPEAK")
sw=$(printf '%s\n' "$dr" | sed -n 's/^WORD=//p')
chk "$sw" "$qfirst" "speak-word-matches-quotes"
src=$(printf '%s\n' "$dr" | sed -n 's/^AUDIO_SRC=//p')
chk "$src" "cache" "speak-audio-src-cache"
printf '%s\n' "$dr" | sed -n 's/^NOTIFY_BODY=//p' | grep -q "例: ex-$sw one" \
  && chk "0" "0" "speak-notify-has-example" || chk "1" "0" "speak-notify-has-example"
# 防漂移核心：点击发生在另一个 10s 桶(EPOCH=80)，仍念 quotes 渲染时(EPOCH=10)写下的词
SF2="$CACHE_DIR/curword2"
rword=$(WORDS_NO_PREFETCH=1 WORDS_STATE_FILE="$SF2" WORDS_CACHE_FILE="$CF" \
  WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=10 bash "$SCRIPT" \
  | jq -r '.text' | awk '{print $1}')
dword=$(WORDS_DRY_RUN=1 WORDS_STATE_FILE="$SF2" WORDS_CACHE_FILE="$CF" \
  WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=80 bash "$SPEAK" \
  | sed -n 's/^WORD=//p')
chk "$dword" "$rword" "speak-reads-rendered-word-not-click-epoch"
# 无缓存且无状态文件 → 走 gtts 兜底，且不报错
dr2=$(WORDS_DRY_RUN=1 WORDS_STATE_FILE="/nonexistent/sf.none" \
  WORDS_CACHE_FILE="/nonexistent/none.json" WORDLIST_FILE="$FIX" \
  WORDS_SEED=20260515 WORDS_EPOCH=20 bash "$SPEAK")
src2=$(printf '%s\n' "$dr2" | sed -n 's/^AUDIO_SRC=//p')
chk "$src2" "gtts" "speak-audio-src-gtts-fallback"

# === Task5: wordlist 词性拆分 jq 过滤器 ===
POSJQ="$HOME/.config/waybar/wordlist-pos.jq"
WLIN="$CACHE_DIR/wl_in.json"
cat > "$WLIN" <<'JSON'
{"words":[
{"word":"abandon","meaning":"v. 放弃；抛弃"},
{"word":"ability","meaning":"n. 能力；才能"},
{"word":"quick","meaning":"adj. 快的"},
{"word":"well","meaning":"adv. 好地"},
{"word":"record","meaning":"v. & n. 记录"},
{"word":"plain","meaning":"无前缀的释义"}
]}
JSON
wlout=$(jq -f "$POSJQ" "$WLIN")
chk "$(echo "$wlout" | jq -c '.words[0]')" '{"word":"abandon","pos":["v."],"meaning":"放弃；抛弃"}' "pos-verb"
chk "$(echo "$wlout" | jq -c '.words[1].pos')" '["n."]' "pos-noun"
chk "$(echo "$wlout" | jq -c '.words[3].pos')" '["adv."]' "pos-adv"
chk "$(echo "$wlout" | jq -c '.words[4]')" '{"word":"record","pos":["v.","n."],"meaning":"记录"}' "pos-compound"
chk "$(echo "$wlout" | jq -c '.words[5]')" '{"word":"plain","pos":[],"meaning":"无前缀的释义"}' "pos-none"
chk "$(echo "$wlout" | jq '.words|length')" "6" "pos-count-preserved"
midpos=$(jq -nc '{words:[{word:"abstract","meaning":"adj. 抽象的 n. 摘要"},{word:"slash","meaning":"v./n. 前进；进步"},{word:"amp","meaning":"v. & n. 记录"}]}' | jq -f "$POSJQ")
chk "$(echo "$midpos" | jq -c '.words[0]')" '{"word":"abstract","pos":["adj.","n."],"meaning":"抽象的；摘要"}' "pos-mid-token"
chk "$(echo "$midpos" | jq -c '.words[1]')" '{"word":"slash","pos":["v.","n."],"meaning":"前进；进步"}' "pos-slash"
chk "$(echo "$midpos" | jq -c '.words[2]')" '{"word":"amp","pos":["v.","n."],"meaning":"记录"}' "pos-amp-clean"

# === Task6: words-lib WL_POS / wl_pos_at ===
LIB="$HOME/.config/waybar/words-lib.sh"
WLP="$CACHE_DIR/wl_pos.json"
cat > "$WLP" <<'JSON'
{"words":[
{"word":"alpha","pos":["v."],"meaning":"放弃"},
{"word":"beta","pos":["v.","n."],"meaning":"记录"},
{"word":"gamma","pos":[],"meaning":"无词性"}
]}
JSON
# 取 idx=0 的 pos（确定性 helper，不依赖选词）
p0=$(WL_QUIET=1 WORDLIST_FILE="$WLP" bash -c '. "$0"; wl_pos_at 0' "$LIB")
chk "$p0" "v." "lib-pos-at-single"
p1=$(WL_QUIET=1 WORDLIST_FILE="$WLP" bash -c '. "$0"; wl_pos_at 1' "$LIB")
chk "$p1" "v. & n." "lib-pos-at-compound"
p2=$(WL_QUIET=1 WORDLIST_FILE="$WLP" bash -c '. "$0"; wl_pos_at 2' "$LIB")
chk "$p2" "" "lib-pos-at-empty"
# wl_select 设 WL_POS
ws=$(WL_QUIET=1 WORDLIST_FILE="$WLP" WORDS_SEED=20260518 WORDS_EPOCH=0 \
  bash -c '. "$0"; wl_select; printf "%s|%s|%s" "$WL_WORD" "$WL_POS" "$WL_MEANING"' "$LIB")
echo "$ws" | grep -qE '^[a-z]+\|([a-z]+\.( & [a-z]+\.)*)?\|.+$'; chk "$?" "0" "lib-wl-pos-set"
# 旧无 pos 字段的 fixture：wl_pos_at 返回空、不报错
op=$(WL_QUIET=1 WORDLIST_FILE="$FIX" bash -c '. "$0"; wl_pos_at 0' "$LIB" 2>/dev/null)
chk "$op" "" "lib-pos-missing-field-empty"

exit $fail
