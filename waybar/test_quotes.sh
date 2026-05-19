#!/usr/bin/env bash
# quotes.sh 行为测试。用固定 fixture + 固定 seed/epoch 断言确定性、轮换、跨天、错误处理。
set -u
SCRIPT="$HOME/.config/waybar/quotes.sh"
FIX="$(mktemp)"
STATE_TMP="$(mktemp)"
export WORDS_STATE_FILE="$STATE_TMP"
# 隔离手动覆盖文件：默认指向不存在路径，避免真实 ~/.cache/waybar/word-override
# 劫持那些不显式设 WORDS_OVERRIDE_FILE 的测试（Task10 各用例自带专属路径）。
export WORDS_OVERRIDE_FILE="$STATE_TMP.noovr"
trap 'rm -f "$FIX" "$STATE_TMP" "$STATE_TMP.noovr"' EXIT

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

# 3. 轮换：每过 ROTATE(600s) 一桶 → 遍历各桶应出现 >1 种
uniq=$(for e in 0 600 1200 1800 2400 3000 3600 4200 4800 5400; do
  WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=$e bash "$SCRIPT" | jq -r '.text'
done | sort -u | wc -l)
[ "$uniq" -gt 1 ] && chk "0" "0" "rotation-varies" || chk "1" "0" "rotation-varies"
# 3b. 同一 600s 桶内稳定：epoch 0 与 599 同词
t0=$(WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=0 bash "$SCRIPT" | jq -r '.text')
t599=$(WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=599 bash "$SCRIPT" | jq -r '.text')
chk "$t599" "$t0" "rotation-stable-within-bucket"

# 4. 跨天：不同 seed → 今日 10 词集合（WL_IDX）应不同（tooltip 已移除，改测选词源头）
s1=$(WL_QUIET=1 WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=0 \
  bash -c '. "$0"; wl_select; printf "%s," "${WL_IDX[@]}"' "$HOME/.config/waybar/words-lib.sh")
s2=$(WL_QUIET=1 WORDLIST_FILE="$FIX" WORDS_SEED=20260516 WORDS_EPOCH=0 \
  bash -c '. "$0"; wl_select; printf "%s," "${WL_IDX[@]}"' "$HOME/.config/waybar/words-lib.sh")
[ "$s1" != "$s2" ] && chk "0" "0" "cross-day-changes" || chk "1" "0" "cross-day-changes"

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
trap 'rm -f "$FIX" "$STATE_TMP" "$STATE_TMP.noovr"; rm -rf "$CACHE_DIR"' EXIT
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
# 防漂移核心：点击发生在另一个 ROTATE 桶(EPOCH=700)，仍念 quotes 渲染时(EPOCH=10)写下的词
SF2="$CACHE_DIR/curword2"
rword=$(WORDS_NO_PREFETCH=1 WORDS_STATE_FILE="$SF2" WORDS_CACHE_FILE="$CF" \
  WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=10 bash "$SCRIPT" \
  | jq -r '.text' | awk '{print $1}')
dword=$(WORDS_DRY_RUN=1 WORDS_STATE_FILE="$SF2" WORDS_CACHE_FILE="$CF" \
  WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=700 bash "$SPEAK" \
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

# === Task7: quotes.sh text 含词性、无 tooltip 富块 ===
WLQ="$CACHE_DIR/wl_q.json"
cat > "$WLQ" <<'JSON'
{"words":[
{"word":"k0","pos":["v."],"meaning":"放弃"},
{"word":"k1","pos":["n."],"meaning":"能力"},
{"word":"k2","pos":[],"meaning":"纯释义"},
{"word":"k3","pos":["adj."],"meaning":"快的"},
{"word":"k4","pos":["v."],"meaning":"动作"},
{"word":"k5","pos":["n."],"meaning":"名词"},
{"word":"k6","pos":["adv."],"meaning":"副词"},
{"word":"k7","pos":["v."],"meaning":"做"},
{"word":"k8","pos":["adj."],"meaning":"好的"},
{"word":"k9","pos":["n."],"meaning":"东西"},
{"word":"k10","pos":["v."],"meaning":"走"}
]}
JSON
txt=$(WORDS_NO_PREFETCH=1 WORDLIST_FILE="$WLQ" WORDS_SEED=20260518 WORDS_EPOCH=0 \
  bash "$SCRIPT" | jq -r '.text')
echo "$txt" | grep -qE '^k[0-9]+ ([a-z]+\. )?[^ ].*$'; chk "$?" "0" "quotes-text-shape"
seen=0
for e in 0 600 1200 1800 2400 3000 3600 4200 4800 5400 6000; do
  t=$(WORDS_NO_PREFETCH=1 WORDLIST_FILE="$WLQ" WORDS_SEED=20260518 WORDS_EPOCH=$e \
    bash "$SCRIPT" | jq -r '.text')
  echo "$t" | grep -qE '^k[0-9]+ (v|n|adj|adv)\. ' && seen=1
done
chk "$seen" "1" "quotes-text-has-pos"
hit=0
for e in 0 600 1200 1800 2400 3000 3600 4200 4800 5400 6000; do
  t=$(WORDS_NO_PREFETCH=1 WORDLIST_FILE="$WLQ" WORDS_SEED=20260518 WORDS_EPOCH=$e \
    bash "$SCRIPT" | jq -r '.text')
  [ "$t" = "k2 纯释义" ] && hit=1
done
chk "$hit" "1" "quotes-text-no-double-space"
out=$(WORDS_NO_PREFETCH=1 WORDLIST_FILE="$WLQ" WORDS_SEED=20260518 WORDS_EPOCH=0 bash "$SCRIPT")
echo "$out" | jq -e '.text' >/dev/null 2>&1; chk "$?" "0" "quotes-still-valid-json"
echo "$out" | jq -r '.tooltip // ""' | grep -q '今日单词' \
  && chk "1" "0" "quotes-no-tooltip-block" || chk "0" "0" "quotes-no-tooltip-block"

# === Task8: word-popup.sh 输出弹窗 JSON ===
POP="$HOME/.config/waybar/word-popup.sh"
# 复用 Task2 的 $CF（今日 10 词富信息），词库用带 pos 的 $WLQ
pj=$(WORDS_NO_PREFETCH=1 WORDS_CACHE_FILE="$CF" WORDLIST_FILE="$WLQ" \
  WORDS_SEED=20260515 WORDS_EPOCH=0 bash "$POP")
echo "$pj" | jq -e '.current and .today' >/dev/null 2>&1; chk "$?" "0" "popup-valid-json"
chk "$(echo "$pj" | jq '.today|length')" "10" "popup-today-10"
chk "$(echo "$pj" | jq '[.today[]|select(.current)]|length')" "1" "popup-one-current"
# current.word 必等于 quotes.sh 同 seed/epoch 渲染的词
qw=$(WORDS_NO_PREFETCH=1 WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 WORDS_EPOCH=0 \
  bash "$SCRIPT" | jq -r '.text' | awk '{print $1}')
chk "$(echo "$pj" | jq -r '.current.word')" "$qw" "popup-current-matches-quotes"
# pos 是数组
echo "$pj" | jq -e '.current.pos|type=="array"' >/dev/null 2>&1; chk "$?" "0" "popup-pos-array"
# 缓存缺失 → phonetic/example 为空字符串、仍合法
pj2=$(WORDS_NO_PREFETCH=1 WORDS_CACHE_FILE="/nonexistent/n.json" WORDLIST_FILE="$WLQ" \
  WORDS_SEED=20260515 WORDS_EPOCH=0 bash "$POP")
chk "$(echo "$pj2" | jq -r '.current.phonetic')" "" "popup-degrade-phonetic-empty"
chk "$(echo "$pj2" | jq -r '.current.example')" "" "popup-degrade-example-empty"
echo "$pj2" | jq -e '.today|length==10' >/dev/null 2>&1; chk "$?" "0" "popup-degrade-still-10"

# === Task9: word-speak.sh 仅朗读、不通知 ===
WSPK="$HOME/.config/waybar/word-speak.sh"
SF3="$CACHE_DIR/curw3"
rw=$(WORDS_NO_PREFETCH=1 WORDS_STATE_FILE="$SF3" WORDS_CACHE_FILE="$CF" \
  WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 WORDS_EPOCH=20 bash "$SCRIPT" \
  | jq -r '.text' | awk '{print $1}')
# 专门构造一份含当前词 audio 的缓存，确保命中 cache 分支
SPKCACHE="$CACHE_DIR/spk_cache.json"
jq -nc --arg w "$rw" '{seed:"x",words:{($w):{phonetic:"",audio:"https://x/\($w)-us.mp3",examples:[]}}}' > "$SPKCACHE"
dr=$(WORDS_DRY_RUN=1 WORDS_STATE_FILE="$SF3" WORDS_CACHE_FILE="$SPKCACHE" \
  WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 WORDS_EPOCH=20 bash "$WSPK")
chk "$(printf '%s\n' "$dr" | sed -n 's/^WORD=//p')" "$rw" "speak2-word-matches"
chk "$(printf '%s\n' "$dr" | sed -n 's/^AUDIO_SRC=//p')" "cache" "speak2-src-cache"
printf '%s\n' "$dr" | grep -q '^NOTIFY' && chk "1" "0" "speak2-no-notify" \
  || chk "0" "0" "speak2-no-notify"
# 缓存文件存在但该词不在其中 → 仍 gtts（src 反映"该词音频是否已缓存"）
dr3=$(WORDS_DRY_RUN=1 WORDS_STATE_FILE="$SF3" WORDS_CACHE_FILE="$CF" \
  WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 WORDS_EPOCH=20 bash "$WSPK")
chk "$(printf '%s\n' "$dr3" | sed -n 's/^AUDIO_SRC=//p')" "gtts" "speak2-src-gtts-when-word-absent"
# 无缓存无状态 → gtts 兜底，不报错
dr2=$(WORDS_DRY_RUN=1 WORDS_STATE_FILE="/nonexistent/x" \
  WORDS_CACHE_FILE="/nonexistent/n.json" WORDLIST_FILE="$WLQ" \
  WORDS_SEED=20260515 WORDS_EPOCH=20 bash "$WSPK")
chk "$(printf '%s\n' "$dr2" | sed -n 's/^AUDIO_SRC=//p')" "gtts" "speak2-gtts-fallback"

# === Task10: 10分钟轮换 + 手动覆盖（点词重置计时）===
WPICK="$HOME/.config/waybar/word-pick.sh"
# 锚点 epoch=1000 pos=3：当 epoch=锚点时选 WL_IDX[3]
OVR="$CACHE_DIR/ovr"
printf '%s\t%s\t%s' 20260515 1000 3 > "$OVR"
r=$(WL_QUIET=1 WORDS_OVERRIDE_FILE="$OVR" WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 WORDS_EPOCH=1000 \
  bash -c '. "$0"; wl_select; printf "%s|%s" "$WL_WORD" "$(wl_word_at "${WL_IDX[3]}")"' "$LIB")
chk "${r%%|*}" "${r##*|}" "override-anchor-pos"
# 锚点 +600s → 往后一位 pos=4
r=$(WL_QUIET=1 WORDS_OVERRIDE_FILE="$OVR" WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 WORDS_EPOCH=1600 \
  bash -c '. "$0"; wl_select; printf "%s|%s" "$WL_WORD" "$(wl_word_at "${WL_IDX[4]}")"' "$LIB")
chk "${r%%|*}" "${r##*|}" "override-advances-after-rotate"
# 锚点 +599s（不足一桶）→ 仍 pos=3
r=$(WL_QUIET=1 WORDS_OVERRIDE_FILE="$OVR" WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 WORDS_EPOCH=1599 \
  bash -c '. "$0"; wl_select; printf "%s|%s" "$WL_WORD" "$(wl_word_at "${WL_IDX[3]}")"' "$LIB")
chk "${r%%|*}" "${r##*|}" "override-stable-within-bucket"
# 跨天（override seed 不匹配）→ 忽略覆盖，回退纯时间公式
printf '%s\t%s\t%s' 20991231 1000 7 > "$OVR"
wovr=$(WL_QUIET=1 WORDS_OVERRIDE_FILE="$OVR" WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 WORDS_EPOCH=1000 \
  bash -c '. "$0"; wl_select; printf "%s" "$WL_WORD"' "$LIB")
wnone=$(WL_QUIET=1 WORDS_OVERRIDE_FILE="/nonexistent/x" WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 WORDS_EPOCH=1000 \
  bash -c '. "$0"; wl_select; printf "%s" "$WL_WORD"' "$LIB")
chk "$wovr" "$wnone" "override-stale-seed-ignored"
# pos 越界 → 忽略，回退时间公式
printf '%s\t%s\t%s' 20260515 1000 999 > "$OVR"
wbad=$(WL_QUIET=1 WORDS_OVERRIDE_FILE="$OVR" WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 WORDS_EPOCH=1000 \
  bash -c '. "$0"; wl_select; printf "%s" "$WL_WORD"' "$LIB")
chk "$wbad" "$wnone" "override-bad-pos-ignored"
# word-pick.sh：写出 "SEED\t<digits>\t5"
PK="$CACHE_DIR/pick_ovr"
WORDS_OVERRIDE_FILE="$PK" WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 bash "$WPICK" 5
IFS=$'\t' read -r ps pe pp < "$PK"
chk "$ps" "20260515" "pick-writes-seed"
chk "$pp" "5" "pick-writes-pos"
case "$pe" in ''|*[!0-9]*) chk "1" "0" "pick-writes-epoch" ;; *) chk "0" "0" "pick-writes-epoch" ;; esac
# word-pick 非法/越界参数 → 不写文件
rm -f "$PK"
WORDS_OVERRIDE_FILE="$PK" WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 bash "$WPICK" abc
[ -e "$PK" ] && chk "1" "0" "pick-ignores-nonint" || chk "0" "0" "pick-ignores-nonint"
WORDS_OVERRIDE_FILE="$PK" WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 bash "$WPICK" 999
[ -e "$PK" ] && chk "1" "0" "pick-ignores-oob" || chk "0" "0" "pick-ignores-oob"
# word-pick → words-lib 往返：pick 5 后，用写下的 epoch 读，应选 WL_IDX[5]
WORDS_OVERRIDE_FILE="$PK" WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 bash "$WPICK" 5
IFS=$'\t' read -r _ pe2 _ < "$PK"
r=$(WL_QUIET=1 WORDS_OVERRIDE_FILE="$PK" WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 WORDS_EPOCH="$pe2" \
  bash -c '. "$0"; wl_select; printf "%s|%s" "$WL_WORD" "$(wl_word_at "${WL_IDX[5]}")"' "$LIB")
chk "${r%%|*}" "${r##*|}" "pick-roundtrip-selects-clicked"
# word-popup.sh：today 每项带 idx，且 0..len-1 顺序
pj=$(WORDS_NO_PREFETCH=1 WORDS_OVERRIDE_FILE="/nonexistent/x" WORDS_CACHE_FILE="$CF" \
  WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 WORDS_EPOCH=0 bash "$POP")
chk "$(echo "$pj" | jq -c '[.today[].idx] == [range(0; .today|length)]')" "true" "popup-today-has-idx"
chk "$(echo "$pj" | jq '.today[3].idx')" "3" "popup-idx-positional"

# === Task11: word-stream.sh 事件推送源 ===
STREAM="$HOME/.config/waybar/word-stream.sh"
SFIFO="$CACHE_DIR/wake.fifo"
# 启动即吐一行合法 JSON，且与 word-popup.sh 同环境输出一致
sl=$(timeout 2 env WORDS_NO_PREFETCH=1 WORDS_WAKE_FIFO="$SFIFO" \
  WORDS_OVERRIDE_FILE="/nonexistent/x" WORDS_CACHE_FILE="$CF" \
  WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 WORDS_EPOCH=0 \
  bash "$STREAM" 2>/dev/null | head -n1)
echo "$sl" | jq -e '.current and .today' >/dev/null 2>&1; chk "$?" "0" "stream-emits-valid-json"
pp=$(WORDS_NO_PREFETCH=1 WORDS_OVERRIDE_FILE="/nonexistent/x" WORDS_CACHE_FILE="$CF" \
  WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 WORDS_EPOCH=0 bash "$POP")
chk "$sl" "$pp" "stream-matches-popup"
rm -f "$SFIFO"
# word-pick.sh 在无 FIFO 时不挂起、仍写 override（<1s 完成）
PK2="$CACHE_DIR/pk2"; t0=$(date +%s)
WORDS_OVERRIDE_FILE="$PK2" WORDS_WAKE_FIFO="/nonexistent/nofifo" \
  WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 bash "$WPICK" 4
t1=$(date +%s)
[ -s "$PK2" ] && [ $((t1-t0)) -lt 3 ] && chk "0" "0" "pick-no-fifo-no-hang" \
  || chk "1" "0" "pick-no-fifo-no-hang"

exit $fail
