# Waybar 每日单词 — 点击朗读 + 例句 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 waybar `custom/quotes` 每日单词模块加上：左键点击朗读当前英文单词 + tooltip/通知显示音标和例句，数据来自在线词典 API 并缓存。

**Architecture:** 抽出共享选词库 `words-lib.sh`（算法不变），后台 `words-cache.sh` 每天预取今日 10 词的音频/音标/例句到 `~/.cache/waybar/words.json`。`quotes.sh` 读缓存丰富 tooltip 并懒触发预取；新 `speak-word.sh` 作为 `on-click` 目标朗读 + 弹通知。全部脚本提供 env 注入测试缝（`WORDS_FETCH_CMD`/`WORDS_DRY_RUN`/`WORDS_CACHE_FILE`/`WORDS_NO_PREFETCH`），离线可测。

**Tech Stack:** bash, jq, curl, mpv, notify-send, flock, openssl/shuf（沿用现有确定性洗牌）。测试沿用 `test_quotes.sh` 的 fixture + `chk()` 断言风格。

**Spec:** `docs/superpowers/specs/2026-05-16-waybar-word-tts-design.md`

**关键事实：** `~/.config/waybar` 是指向 `~/dotfiles/waybar` 的**目录** symlink。在 `~/dotfiles/waybar/` 新建的文件会自动出现在运行路径，无需逐文件建链；新脚本需 `chmod +x`。所有路径以运行路径 `~/.config/waybar/` 表述，编辑时改 `~/dotfiles/waybar/` 源文件。

---

## File Structure

| 文件 | 职责 | 变化 |
|---|---|---|
| `~/dotfiles/waybar/words-lib.sh` | 共享：env 默认值、前置检查、确定性选词（填充 `WL_*`） | 新增 |
| `~/dotfiles/waybar/words-cache.sh` | 预取今日 10 词 → 原子写 `words.json`，幂等，可注入 fetch | 新增 |
| `~/dotfiles/waybar/speak-word.sh` | `on-click`：解析当前词 → 播音频 + `notify-send`，含 dry-run 缝 | 新增 |
| `~/dotfiles/waybar/quotes.sh` | 改 source 共享库；tooltip 加当前词富信息块；懒触发预取 | 重写 |
| `~/dotfiles/waybar/config.jsonc` | `custom/quotes` 加 `on-click` 1 行 | 改 |
| `~/dotfiles/waybar/test_quotes.sh` | 追加 lib 一致性 / 缓存 / 点击 三组测试 | 改 |

测试统一入口：`bash ~/.config/waybar/test_quotes.sh`，打印 `ok/FAIL` 行，全过则 `exit 0`。

---

## Task 1: `words-lib.sh` 共享选词库（行为保持的重构）

把现 `quotes.sh` 内联选词逻辑原样抽进可 source 的库，`quotes.sh` 改为 source 它。算法一字不改，现有 5 个测试必须仍全过（即重构无回归），并新增「库与 quotes.sh 选出同一个词」断言。

**Files:**
- Create: `~/dotfiles/waybar/words-lib.sh`
- Modify: `~/dotfiles/waybar/quotes.sh`（整体重写选词部分）
- Test: `~/dotfiles/waybar/test_quotes.sh`（追加一组）

- [ ] **Step 1: 追加失败测试到 `test_quotes.sh`**

在 `test_quotes.sh` 末尾 `exit $fail` **之前**插入：

```bash
# === Task1: words-lib 与 quotes.sh 选词一致 ===
LIB="$HOME/.config/waybar/words-lib.sh"
libsel=$(
  WL_QUIET=1 WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=30 \
  bash -c '. "$0"; wl_select; printf "%s %s" "$WL_WORD" "$WL_MEANING"' "$LIB" 2>/dev/null
)
qtext=$(WORDLIST_FILE="$FIX" WORDS_SEED=20260515 WORDS_EPOCH=30 bash "$SCRIPT" | jq -r '.text')
chk "$libsel" "$qtext" "lib-matches-quotes-text"
```

- [ ] **Step 2: 跑测试确认新断言失败**

Run: `bash ~/.config/waybar/test_quotes.sh`
Expected: 出现 `FAIL lib-matches-quotes-text:`（`words-lib.sh` 不存在，`libsel` 为空），脚本最终 `exit 1`。

- [ ] **Step 3: 创建 `words-lib.sh`**

写入 `~/dotfiles/waybar/words-lib.sh`：

```bash
#!/usr/bin/env bash
# 共享：waybar 每日单词的确定性选词逻辑。
# 被 quotes.sh / speak-word.sh / words-cache.sh source。
# 洗牌算法与原 quotes.sh 完全一致：openssl AES-CTR keystream 喂 shuf。

WORDLIST_FILE="${WORDLIST_FILE:-$HOME/.config/waybar/wordlist.json}"
SEED="${WORDS_SEED:-$(date +%Y%m%d)}"
EPOCH="${WORDS_EPOCH:-$(date +%s)}"
WORDS_CACHE_FILE="${WORDS_CACHE_FILE:-$HOME/.cache/waybar/words.json}"
WORDS_LOCK_FILE="${WORDS_LOCK_FILE:-$HOME/.cache/waybar/words.lock}"
DAILY=10
ROTATE=10   # 秒/词

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
  local pos=$(( (EPOCH / ROTATE) % WL_TAKE ))
  WL_SEL=${WL_IDX[$pos]}
  WL_WORD=$(jq -r ".words[$WL_SEL].word"    "$WORDLIST_FILE")
  WL_MEANING=$(jq -r ".words[$WL_SEL].meaning" "$WORDLIST_FILE")
}

wl_word_at(){ jq -r ".words[$1].word" "$WORDLIST_FILE"; }
wl_meaning_at(){ jq -r ".words[$1].meaning" "$WORDLIST_FILE"; }
```

- [ ] **Step 4: 重写 `quotes.sh` 改为 source 共享库**

把 `~/dotfiles/waybar/quotes.sh` 整体替换为（本任务仅做重构，tooltip 仍只输出今日列表，富信息块与预取在 Task 3 加）：

```bash
#!/usr/bin/env bash
# Waybar 每日单词：本地词库日期种子确定性抽 10，按 epoch 每 10 秒轮换一个。
# 选词逻辑见 words-lib.sh。
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/words-lib.sh"

wl_select   # 设 WL_IDX/WL_SEL/WL_WORD/WL_MEANING；前置失败则已空输出退出

nl=$'\n'
tip="今日单词"
for i in "${WL_IDX[@]}"; do
  tip="$tip$nl$(wl_word_at "$i")  $(wl_meaning_at "$i")"
done

jq -nc --arg t "$WL_WORD $WL_MEANING" --arg tip "$tip" '{text:$t, tooltip:$tip}'
```

- [ ] **Step 5: 赋可执行权限**

Run: `chmod +x ~/dotfiles/waybar/words-lib.sh`
（`quotes.sh` 已可执行，无需改。）

- [ ] **Step 6: 跑全部测试确认通过**

Run: `bash ~/.config/waybar/test_quotes.sh; echo "exit=$?"`
Expected: 原有 5 项（`valid-json-has-text` / `deterministic-same-seed-epoch` / `rotation-varies` / `cross-day-changes` / `missing-file-empty-class`）全 `ok`，新增 `ok lib-matches-quotes-text`，最后 `exit=0`。

- [ ] **Step 7: 提交**

```bash
git -C ~/dotfiles add waybar/words-lib.sh waybar/quotes.sh waybar/test_quotes.sh
git -C ~/dotfiles commit -m "refactor: extract waybar word selection into words-lib.sh

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `words-cache.sh` 预取 + 原子写 + 幂等

给定今日 10 词，调词典 API（默认 curl，可用 `WORDS_FETCH_CMD` 注入 stub），把音标/音频/释义/例句写入 `WORDS_CACHE_FILE`。已是今日且齐全则跳过（幂等）。fetch 命令退出 0 即视为「API 已回应」并写入条目（404 也算，不再当天重试）；退出非 0 视为网络失败，跳过该词留待下次。

**Files:**
- Create: `~/dotfiles/waybar/words-cache.sh`
- Test: `~/dotfiles/waybar/test_quotes.sh`（追加一组）

- [ ] **Step 1: 追加失败测试到 `test_quotes.sh`（`exit $fail` 之前）**

```bash
# === Task2: words-cache 写缓存 + 幂等 ===
CACHE_DIR="$(mktemp -d)"
trap 'rm -f "$FIX"; rm -rf "$CACHE_DIR"' EXIT
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
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash ~/.config/waybar/test_quotes.sh`
Expected: `FAIL cache-file-written`（`words-cache.sh` 不存在），后续 cache 断言连带 FAIL，`exit 1`。

- [ ] **Step 3: 创建 `words-cache.sh`**

写入 `~/dotfiles/waybar/words-cache.sh`：

```bash
#!/usr/bin/env bash
# 预取今日 10 词的音标/音频/释义/例句，原子写入 WORDS_CACHE_FILE。幂等。
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WL_QUIET=1
. "$DIR/words-lib.sh"

command -v jq >/dev/null 2>&1 || exit 0

wl_select   # 需要 WL_IDX；前置失败则静默退出

mkdir -p "$(dirname "$WORDS_CACHE_FILE")" 2>/dev/null

# 已是今日且 10 词齐全 → 跳过
if [ -r "$WORDS_CACHE_FILE" ]; then
  cur_seed=$(jq -r '.seed // ""' "$WORDS_CACHE_FILE" 2>/dev/null)
  have=$(jq -r '.words | length' "$WORDS_CACHE_FILE" 2>/dev/null || echo 0)
  if [ "$cur_seed" = "$SEED" ] && [ "${have:-0}" -ge "$WL_TAKE" ]; then
    exit 0
  fi
fi

# 起始累加器：沿用今日已有缓存，否则空
if [ -r "$WORDS_CACHE_FILE" ] && \
   [ "$(jq -r '.seed // ""' "$WORDS_CACHE_FILE" 2>/dev/null)" = "$SEED" ]; then
  acc=$(cat "$WORDS_CACHE_FILE")
else
  acc=$(jq -nc --arg s "$SEED" '{seed:$s, words:{}}')
fi

wc_fetch(){  # $1=word，stdout=原始 API JSON，退出码透传
  if [ -n "${WORDS_FETCH_CMD:-}" ]; then
    "$WORDS_FETCH_CMD" "$1"
  else
    curl -sS --max-time 5 -A 'waybar-words/1.0' \
      "https://api.dictionaryapi.dev/api/v2/entries/en/$1"
  fi
}

wc_parse='
if type=="array" then {
  phonetic: ([.[0].phonetics[]?|select(.text!=null and .text!="")|.text]|first
             // (.[0].phonetic // "")),
  audio: ( ([.[0].phonetics[]?|select(.audio!=null and .audio!="")|.audio]) as $a
           | ([$a[]|select(test("-us\\.mp3$"))]|first) // ($a|first) // "" ),
  definition: ([.[0].meanings[]?.definitions[]?.definition]|first // ""),
  examples: ([.[0].meanings[]?.definitions[]?
              |select(.example!=null and .example!="")|.example]|.[0:2])
} else {phonetic:"",audio:"",definition:"",examples:[]} end'

for i in "${WL_IDX[@]}"; do
  w=$(wl_word_at "$i")
  # 今日缓存已有该词则跳过
  if [ "$(printf '%s' "$acc" | jq -r --arg w "$w" 'has("words") and (.words|has($w))')" = "true" ]; then
    continue
  fi
  body=$(wc_fetch "$w"); rc=$?
  [ $rc -eq 0 ] && [ -n "$body" ] || continue   # 网络失败：留待下次
  entry=$(printf '%s' "$body" | jq -c "$wc_parse" 2>/dev/null) || \
    entry='{"phonetic":"","audio":"","definition":"","examples":[]}'
  acc=$(printf '%s' "$acc" | jq -c --arg w "$w" --argjson e "$entry" '.words[$w]=$e')
done

tmp=$(mktemp "${WORDS_CACHE_FILE}.XXXXXX")
printf '%s' "$acc" > "$tmp" && mv -f "$tmp" "$WORDS_CACHE_FILE"
```

- [ ] **Step 4: 赋可执行权限**

Run: `chmod +x ~/dotfiles/waybar/words-cache.sh`

- [ ] **Step 5: 跑测试确认通过**

Run: `bash ~/.config/waybar/test_quotes.sh; echo "exit=$?"`
Expected: 新增 `ok cache-file-written` / `ok cache-seed-and-10-words` / `ok cache-idempotent-no-refetch` / `ok cache-entry-fields`，Task 1 与原有项仍全 `ok`，`exit=0`。

- [ ] **Step 6: 提交**

```bash
git -C ~/dotfiles add waybar/words-cache.sh waybar/test_quotes.sh
git -C ~/dotfiles commit -m "feat: words-cache.sh prefetch dictionary data with idempotent atomic write

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `quotes.sh` tooltip 富信息块 + 懒触发预取

tooltip 顶部加当前词的「▶ word  /音标/ / 释义 / 例: 例句」块，下接分隔线与今日 10 词列表（原样）。缓存非今日时后台 `flock` 触发预取（`WORDS_NO_PREFETCH=1` 跳过，供测试）。缓存缺字段则对应行省略，永不报错。

**Files:**
- Modify: `~/dotfiles/waybar/quotes.sh`
- Test: `~/dotfiles/waybar/test_quotes.sh`（追加一组）

- [ ] **Step 1: 追加失败测试到 `test_quotes.sh`（`exit $fail` 之前）**

```bash
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
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash ~/.config/waybar/test_quotes.sh`
Expected: `FAIL tooltip-rich-block`（当前 `quotes.sh` tooltip 以 `今日单词` 开头，无 `▶`），`exit 1`。`tooltip-degrade-*` 此时可能已 ok（不影响该任务以富信息块为准）。

- [ ] **Step 3: 重写 `quotes.sh` 加富信息块与预取触发**

把 `~/dotfiles/waybar/quotes.sh` 整体替换为：

```bash
#!/usr/bin/env bash
# Waybar 每日单词：日期种子确定性抽 10，每 10 秒轮换。
# 选词见 words-lib.sh；tooltip 顶部用 ~/.cache/waybar/words.json 富信息。
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$DIR/words-lib.sh"

wl_select   # 设 WL_IDX/WL_SEL/WL_WORD/WL_MEANING；前置失败则已空输出退出

# 后台懒触发预取：缓存缺失或非今日 seed（WORDS_NO_PREFETCH=1 跳过）
cache_seed=""
[ -r "$WORDS_CACHE_FILE" ] && \
  cache_seed=$(jq -r '.seed // ""' "$WORDS_CACHE_FILE" 2>/dev/null)
if [ -z "${WORDS_NO_PREFETCH:-}" ] && [ "$cache_seed" != "$SEED" ]; then
  mkdir -p "$(dirname "$WORDS_LOCK_FILE")" 2>/dev/null
  setsid flock -n "$WORDS_LOCK_FILE" "$DIR/words-cache.sh" >/dev/null 2>&1 &
fi

# 当前词富信息（缓存就绪时）
ph=""; ex=""
if [ -r "$WORDS_CACHE_FILE" ]; then
  ph=$(jq -r --arg w "$WL_WORD" '.words[$w].phonetic // ""' "$WORDS_CACHE_FILE" 2>/dev/null)
  ex=$(jq -r --arg w "$WL_WORD" '.words[$w].examples[0] // ""' "$WORDS_CACHE_FILE" 2>/dev/null)
fi

nl=$'\n'
head="▶ $WL_WORD"
[ -n "$ph" ] && head="$head  $ph"
block="$head$nl  $WL_MEANING"
[ -n "$ex" ] && block="$block$nl  例: $ex"

tip="$block$nl──────────$nl今日单词"
for i in "${WL_IDX[@]}"; do
  tip="$tip$nl$(wl_word_at "$i")  $(wl_meaning_at "$i")"
done

jq -nc --arg t "$WL_WORD $WL_MEANING" --arg tip "$tip" '{text:$t, tooltip:$tip}'
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash ~/.config/waybar/test_quotes.sh; echo "exit=$?"`
Expected: 新增 `ok tooltip-rich-block` / `ok tooltip-degrade-valid` / `ok tooltip-degrade-no-example`；原有及 Task1/2 项仍全 `ok`，`exit=0`。

- [ ] **Step 5: 提交**

```bash
git -C ~/dotfiles add waybar/quotes.sh waybar/test_quotes.sh
git -C ~/dotfiles commit -m "feat: enrich quotes.sh tooltip with phonetic/example + lazy prefetch trigger

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: `speak-word.sh` 点击朗读 + 通知（dry-run 缝）

`on-click` 目标：解析与 `quotes.sh` 当下显示的同一个词，朗读其发音并 `notify-send` 含音标/释义/例句。`WORDS_DRY_RUN=1` 时不播放、不通知，改向 stdout 打印可断言的解析结果。

dry-run stdout 固定格式（每行一项）：
```
WORD=<word>
AUDIO_SRC=<cache|gtts|none>
NOTIFY_TITLE=<title>
NOTIFY_BODY=<body，换行用字面 \n>
```
`AUDIO_SRC`：缓存有 audio→`cache`；无 audio 但有 word→`gtts`（Google TTS 兜底）；无词→`none`。

**Files:**
- Create: `~/dotfiles/waybar/speak-word.sh`
- Test: `~/dotfiles/waybar/test_quotes.sh`（追加一组）

- [ ] **Step 1: 追加失败测试到 `test_quotes.sh`（`exit $fail` 之前）**

```bash
# === Task4: speak-word.sh 解析 + dry-run ===
SPEAK="$HOME/.config/waybar/speak-word.sh"
# 当前词须与 quotes.sh .text 第一段一致（防漂移，验收 #8）
qfirst=$(WORDS_NO_PREFETCH=1 WORDS_CACHE_FILE="$CF" WORDLIST_FILE="$FIX" \
  WORDS_SEED=20260515 WORDS_EPOCH=20 bash "$SCRIPT" | jq -r '.text' | awk '{print $1}')
dr=$(WORDS_DRY_RUN=1 WORDS_CACHE_FILE="$CF" WORDLIST_FILE="$FIX" \
  WORDS_SEED=20260515 WORDS_EPOCH=20 bash "$SPEAK")
sw=$(printf '%s\n' "$dr" | sed -n 's/^WORD=//p')
chk "$sw" "$qfirst" "speak-word-matches-quotes"
src=$(printf '%s\n' "$dr" | sed -n 's/^AUDIO_SRC=//p')
chk "$src" "cache" "speak-audio-src-cache"   # $CF 里有 audio
printf '%s\n' "$dr" | sed -n 's/^NOTIFY_BODY=//p' | grep -q "例: ex-$sw one" \
  && chk "0" "0" "speak-notify-has-example" || chk "1" "0" "speak-notify-has-example"
# 无缓存 → 走 gtts 兜底，且不报错
dr2=$(WORDS_DRY_RUN=1 WORDS_CACHE_FILE="/nonexistent/none.json" WORDLIST_FILE="$FIX" \
  WORDS_SEED=20260515 WORDS_EPOCH=20 bash "$SPEAK")
src2=$(printf '%s\n' "$dr2" | sed -n 's/^AUDIO_SRC=//p')
chk "$src2" "gtts" "speak-audio-src-gtts-fallback"
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash ~/.config/waybar/test_quotes.sh`
Expected: `FAIL speak-word-matches-quotes`（`speak-word.sh` 不存在，`sw` 为空），后续 speak 断言连带 FAIL，`exit 1`。

- [ ] **Step 3: 创建 `speak-word.sh`**

写入 `~/dotfiles/waybar/speak-word.sh`：

```bash
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
```

- [ ] **Step 4: 赋可执行权限**

Run: `chmod +x ~/dotfiles/waybar/speak-word.sh`

- [ ] **Step 5: 跑测试确认通过**

Run: `bash ~/.config/waybar/test_quotes.sh; echo "exit=$?"`
Expected: 新增 `ok speak-word-matches-quotes` / `ok speak-audio-src-cache` / `ok speak-notify-has-example` / `ok speak-audio-src-gtts-fallback`；全部历史项仍 `ok`，`exit=0`。

- [ ] **Step 6: 提交**

```bash
git -C ~/dotfiles add waybar/speak-word.sh waybar/test_quotes.sh
git -C ~/dotfiles commit -m "feat: speak-word.sh on-click TTS + notification with dry-run seam

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 接线 `config.jsonc` + 真机验证

把 `on-click` 接到模块，重载 waybar，按验收标准人工验证（音频/通知需桌面环境，无法自动化）。

**Files:**
- Modify: `~/dotfiles/waybar/config.jsonc`（`custom/quotes` 块）

- [ ] **Step 1: 给 `custom/quotes` 加 `on-click`**

编辑 `~/dotfiles/waybar/config.jsonc`，把：

```jsonc
    "custom/quotes": {
        "format": "{}",
        "return-type": "json",
        "exec": "~/.config/waybar/quotes.sh",
        "interval": 10,
        "tooltip": true
    },
```

改为：

```jsonc
    "custom/quotes": {
        "format": "{}",
        "return-type": "json",
        "exec": "~/.config/waybar/quotes.sh",
        "interval": 10,
        "tooltip": true,
        "on-click": "~/.config/waybar/speak-word.sh"
    },
```

- [ ] **Step 2: 全量测试 + 语法校验**

Run:
```bash
bash ~/.config/waybar/test_quotes.sh; echo "tests exit=$?"
jq -e . ~/.config/waybar/config.jsonc >/dev/null 2>&1 \
  && echo "config jsonc OK" || echo "config jsonc PARSE-ERR(注意注释/尾逗号，仅警示)"
```
Expected: `tests exit=0`；config 行若因 jsonc 注释令 `jq` 解析失败可忽略（waybar 用宽松解析），关键是肉眼确认仅多了 `on-click` 一行、上一行末尾补了逗号。

- [ ] **Step 3: 重载 waybar**

Run: `~/.config/waybar/launch.sh >/dev/null 2>&1 & disown` 或 `pkill waybar; ~/.config/waybar/launch.sh & disown`
（沿用仓库现有 `launch.sh`；不要新引入重启方式。）

- [ ] **Step 4: 人工验收（对照 spec 验收标准）**

逐条确认：
1. 左键点击模块 → 听到当前单词英文发音。
2. 同一次点击 → 弹通知，含单词 + 音标 + 释义 + 例句。
3. 悬停 → tooltip 顶部为当前词富信息块，下方仍是今日 10 词列表。
4. 刚跨天头几秒缓存未就绪 → tooltip 退化为仅释义，waybar 不报错。
5. 播放时快速连点 → 不叠音；同时在放的音乐（你自己的 mpv）不被杀。
6. 断网（`nmcli networking off` 或拔网测试后恢复）→ 点击不报错，bar/tooltip 正常。
7. 手动构造跨天：`WORDS_SEED=$(date -d tomorrow +%Y%m%d)` 不便于真机；改为删缓存 `rm -f ~/.cache/waybar/words.json` 后等约 10s，确认后台预取重建、新值生效。
8. 已由 `speak-word-matches-quotes` 自动断言覆盖。

- [ ] **Step 5: 提交**

```bash
git -C ~/dotfiles add waybar/config.jsonc
git -C ~/dotfiles commit -m "feat: wire on-click speak-word.sh into custom/quotes module

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage**

| Spec 要求 | 实现位置 |
|---|---|
| 在线 API 取音频+例句 | Task 2 `words-cache.sh`（dictionaryapi.dev） |
| 预取+缓存今日 10 词（方案 A） | Task 2；缓存 `WORDS_CACHE_FILE`，seed 标记 |
| `words-lib.sh` 共享选词、算法不变 | Task 1（沿用 openssl AES-CTR + shuf） |
| tooltip 顶部当前词富信息块 + 今日列表 | Task 3 |
| 缓存未就绪降级仅释义 | Task 3（`tooltip-degrade-*` 断言） |
| 后台 `flock` 懒触发预取 | Task 3（`setsid flock -n` + `WORDS_NO_PREFETCH` 缝） |
| 左键朗读 + 弹例句通知 | Task 4 `speak-word.sh` |
| cached MP3 优先，无则 Google TTS 兜底 | Task 4（`AUDIO_SRC=cache/gtts`） |
| 仅按 pid 文件杀本脚本 mpv，不误杀音乐 | Task 4（`/proc/<pid>/comm` 校验） |
| 跨天按 seed 整体重建 | Task 2（seed 不符则重建） |
| API 无该词不当天重试 / 网络失败下次重试 | Task 2（fetch 退出码区分） |
| 配置接 `on-click` | Task 5 |
| `test_quotes.sh` 新增测试 | Task 1–4 各追加 |
| 显示词与点击词永不漂移（验收 #8） | Task 1 `lib-matches-quotes-text` + Task 4 `speak-word-matches-quotes` |

无遗漏。

**2. Placeholder scan:** 无 TBD/TODO；每个改代码步骤含完整脚本/断言代码与确切命令、预期输出。

**3. Type/名称一致性:** 全程统一 `WL_WORD/WL_MEANING/WL_IDX/WL_SEL/WL_TAKE/WL_N`、`wl_select/wl_word_at/wl_meaning_at/wl_preflight/wl_emit_empty/wl_rand_src`、env `WORDLIST_FILE/WORDS_SEED/WORDS_EPOCH/WORDS_CACHE_FILE/WORDS_LOCK_FILE/WORDS_FETCH_CMD/WORDS_NO_PREFETCH/WORDS_DRY_RUN/WL_QUIET`、缓存形状 `{seed, words:{<w>:{phonetic,audio,definition,examples}}}`、dry-run 键 `WORD/AUDIO_SRC/NOTIFY_TITLE/NOTIFY_BODY`，跨任务一致。`test_quotes.sh` 的 `trap` 在 Task 2 重定义为同时清理 `$FIX` 与 `$CACHE_DIR`，Task 3/4 复用 `$CF`/`$CACHE_DIR`，顺序依赖已在计划顺序中保证。
