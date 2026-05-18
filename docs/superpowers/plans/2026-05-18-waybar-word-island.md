# Waybar 每日单词灵动岛弹窗 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用点击展开、带回弹动画、跟随 matugen 主题的 eww 灵动岛弹窗，替换 waybar 每日单词模块的粗糙 tooltip。

**Architecture:** waybar 的 `custom/quotes` 模块保持为顶栏常驻胶囊（不重做）；新增一个常驻打开的 eww 窗口 `daily-word`，内容裹在 `revealer` 里，点击模块翻转 `word_reveal` 变量触发滑入/滑出动画。词性从 `meaning` 前缀拆成结构化 `pos` 数组。所有数据复用现有 `words-lib.sh` 选词与 `~/.cache/waybar/words.json` 缓存。

**Tech Stack:** bash + jq、eww 0.5.0 (yuck/scss)、matugen 模板、Hyprland、waybar。

**关键环境事实（实现者必读）：**
- `~/.config/waybar` 是指向 `~/dotfiles/waybar` 的整目录 symlink；编辑任一路径等价。git 仓库根是 `~/dotfiles`。
- `~/.config/eww` 尚不存在；按同样模式新建 `~/dotfiles/eww/` 并 symlink。
- eww 已装，版本 **0.5.0**。
- 测试入口：`bash ~/.config/waybar/test_quotes.sh`（fixture + `chk` 断言 + 退出码，不触网）。
- 词库 `~/.config/waybar/wordlist.json` 共 161 词，`meaning` 100% 带前缀：`v.` 87 / `adj.` 43 / `n.` 30 / `adv.` 1。
- matugen 占位语法：`{{colors.<name>.default.hex}}`（见 `~/dotfiles/matugen/templates/gtk-colors.css`）。
- waybar 冷重启：`~/.config/waybar/launch.sh`。
- hypr 自启文件：`~/.config/hypr/conf/autostart.conf`（`exec-once` 列表）。

**提交约定：** 每个 commit message 末尾加：
`Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`
git 用 `git -C ~/dotfiles -c commit.gpgsign=false ...`。

---

### Task 1: wordlist.json 词性拆分（jq 纯过滤器 + 一次性应用）

**Files:**
- Create: `~/.config/waybar/wordlist-pos.jq`
- Create: `~/.config/waybar/wordlist-add-pos.sh`
- Modify: `~/.config/waybar/test_quotes.sh`（文件末尾 `exit $fail` 之前插入新段）
- Modify: `~/.config/waybar/wordlist.json`（一次性重新生成，先备份）

- [ ] **Step 1: 写失败测试**

在 `test_quotes.sh` 中，最后一行 `exit $fail` **之前**插入：

```bash
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
```

- [ ] **Step 2: 运行确认失败**

Run: `bash ~/.config/waybar/test_quotes.sh`
Expected: FAIL，新增的 `pos-*` 行报 `FAIL`（`wordlist-pos.jq` 不存在，jq 报错）。

- [ ] **Step 3: 写 jq 过滤器**

Create `~/.config/waybar/wordlist-pos.jq`:

```jq
# 把 meaning 开头的英文词性前缀拆进 pos 数组（按 & / , 分隔）。
# 无可识别前缀 → pos:[]、meaning 原样。其余字段保留。
.words |= map(
  (.meaning // "") as $m
  | ($m | capture("^(?<p>[A-Za-z]+\\.(?:\\s*[&/,]\\s*[A-Za-z]+\\.)*)\\s*(?<rest>.*)$") // null) as $c
  | if $c == null
    then .pos = [] | .meaning = $m
    else .pos = ([$c.p | splits("\\s*[&/,]\\s*")] | map(select(length>0)))
       |  .meaning = $c.rest
    end
  | {word, pos, meaning}
)
```

- [ ] **Step 4: 运行确认通过**

Run: `bash ~/.config/waybar/test_quotes.sh`
Expected: PASS，`pos-verb`/`pos-noun`/`pos-adv`/`pos-compound`/`pos-none`/`pos-count-preserved` 全 `ok`，其余原有断言仍 `ok`。

- [ ] **Step 5: 写一次性应用脚本**

Create `~/.config/waybar/wordlist-add-pos.sh`:

```bash
#!/usr/bin/env bash
# 一次性：用 wordlist-pos.jq 把 wordlist.json 升级为含 pos 数组的新结构。
# 幂等：已含 pos 字段则跳过。原子写，先备份。
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WL="${WORDLIST_FILE:-$HOME/.config/waybar/wordlist.json}"
[ -r "$WL" ] || { echo "no $WL" >&2; exit 1; }
if jq -e '.words[0] | has("pos")' "$WL" >/dev/null 2>&1; then
  echo "already has pos, skip"; exit 0
fi
cp -f "$WL" "$WL.bak"
tmp=$(mktemp "${WL}.XXXXXX")
jq -f "$DIR/wordlist-pos.jq" "$WL" > "$tmp" && mv -f "$tmp" "$WL"
echo "rewritten: $WL (backup: $WL.bak)"
```

- [ ] **Step 6: 应用到真实词库并核验**

Run:
```bash
chmod +x ~/.config/waybar/wordlist-add-pos.sh
~/.config/waybar/wordlist-add-pos.sh
jq '[.words[]|select((.pos|length)==0)]|length' ~/.config/waybar/wordlist.json
jq '.words[0:3]' ~/.config/waybar/wordlist.json
```
Expected: 打印 `rewritten:`；无前缀计数为 `0`（161 词 100% 覆盖）；前 3 词形如 `{"word":...,"pos":["v."|"n."|"adj."|"adv."],"meaning":"..."}`。

- [ ] **Step 7: Commit**

`wordlist.json.bak` 是本地安全备份，**不入 git**（确认它已被忽略或显式不 add）。

```bash
git -C ~/dotfiles add waybar/wordlist-pos.jq waybar/wordlist-add-pos.sh waybar/wordlist.json waybar/test_quotes.sh
echo 'waybar/wordlist.json.bak' >> ~/dotfiles/.gitignore
git -C ~/dotfiles add .gitignore
git -C ~/dotfiles -c commit.gpgsign=false commit -m "feat(words): split POS prefix into structured pos array

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: words-lib.sh 暴露 WL_POS / wl_pos_at（兼容无 pos 的旧 fixture）

**Files:**
- Modify: `~/.config/waybar/words-lib.sh`（`wl_select` 末尾、helper 区）
- Modify: `~/.config/waybar/test_quotes.sh`（Task1 段之后插入）

- [ ] **Step 1: 写失败测试**

在 `test_quotes.sh` 的 Task5 段之后、`exit $fail` 之前插入：

```bash
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
```

- [ ] **Step 2: 运行确认失败**

Run: `bash ~/.config/waybar/test_quotes.sh`
Expected: FAIL，`lib-pos-*` / `lib-wl-pos-set` 报错（`wl_pos_at` 未定义、`WL_POS` 空）。

- [ ] **Step 3: 改 words-lib.sh**

把 `wl_select` 函数最后一行 `WL_MEANING=$(jq -r ".words[$WL_SEL].meaning" "$WORDLIST_FILE")` 之后追加一行（在该函数闭合 `}` 之前）：

```bash
  WL_POS=$(wl_pos_at "$WL_SEL")
```

在文件末尾两个 helper 之间/之后，新增 `wl_pos_at`（紧跟 `wl_meaning_at` 那行后）：

```bash
wl_pos_at(){ jq -r ".words[$1].pos // [] | join(\" & \")" "$WORDLIST_FILE"; }
```

- [ ] **Step 4: 运行确认通过**

Run: `bash ~/.config/waybar/test_quotes.sh`
Expected: PASS，`lib-pos-at-single`=`v.`、`lib-pos-at-compound`=`v. & n.`、`lib-pos-at-empty`=空、`lib-wl-pos-set` ok、`lib-pos-missing-field-empty` ok；所有原有断言仍 ok。

- [ ] **Step 5: Commit**

```bash
git -C ~/dotfiles add waybar/words-lib.sh waybar/test_quotes.sh
git -C ~/dotfiles -c commit.gpgsign=false commit -m "feat(words): WL_POS + wl_pos_at in words-lib

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: quotes.sh — bar text 重建 \`词 词性 释义\`，去掉 tooltip 计算

**Files:**
- Modify: `~/.config/waybar/quotes.sh`
- Modify: `~/.config/waybar/test_quotes.sh`（Task6 段之后插入）

说明：词库 `meaning` 现已不含词性前缀。为保持顶栏视觉**完全不变**，
text 由 `词 + 词性 + 释义` 拼回；空词性时不留双空格（与旧 fixture 输出一致，原有 `lib-matches-quotes-text` 断言继续成立）。tooltip 关闭后不再生成富信息块。

- [ ] **Step 1: 写失败测试**

在 `test_quotes.sh` 的 Task6 段之后、`exit $fail` 之前插入：

```bash
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
# 含词性的词：text 必有 "kX <pos> <meaning>"（遍历确保至少出现一次带词性）
seen=0
for e in 0 10 20 30 40 50 60 70 80 90 100; do
  t=$(WORDS_NO_PREFETCH=1 WORDLIST_FILE="$WLQ" WORDS_SEED=20260518 WORDS_EPOCH=$e \
    bash "$SCRIPT" | jq -r '.text')
  echo "$t" | grep -qE '^k[0-9]+ (v|n|adj|adv)\. ' && seen=1
done
chk "$seen" "1" "quotes-text-has-pos"
# 空词性的词 k2：text 恰为 "k2 纯释义"（无双空格）
hit=0
for e in 0 10 20 30 40 50 60 70 80 90 100; do
  t=$(WORDS_NO_PREFETCH=1 WORDLIST_FILE="$WLQ" WORDS_SEED=20260518 WORDS_EPOCH=$e \
    bash "$SCRIPT" | jq -r '.text')
  [ "$t" = "k2 纯释义" ] && hit=1
done
chk "$hit" "1" "quotes-text-no-double-space"
# tooltip 不再含富信息块标记
out=$(WORDS_NO_PREFETCH=1 WORDLIST_FILE="$WLQ" WORDS_SEED=20260518 WORDS_EPOCH=0 bash "$SCRIPT")
echo "$out" | jq -e '.text' >/dev/null 2>&1; chk "$?" "0" "quotes-still-valid-json"
echo "$out" | jq -r '.tooltip // ""' | grep -q '今日单词' \
  && chk "1" "0" "quotes-no-tooltip-block" || chk "0" "0" "quotes-no-tooltip-block"
```

- [ ] **Step 2: 运行确认失败**

Run: `bash ~/.config/waybar/test_quotes.sh`
Expected: FAIL，`quotes-text-has-pos`（旧 text 不含 pos）与 `quotes-no-tooltip-block`（旧 tooltip 仍有"今日单词"）报错。

- [ ] **Step 3: 改 quotes.sh**

打开 `~/.config/waybar/quotes.sh`，把从 `nl=$'\n'` 到结尾（含 `head=`、`block=`、`tip=`、`for i in ... done`、最后那行 `jq -nc ...`）的整段，替换为：

```bash
# bar text：词 + 词性 + 释义，拼回旧视觉（空词性不留双空格）
parts="$WL_WORD"
[ -n "${WL_POS:-}" ] && parts="$parts $WL_POS"
parts="$parts $WL_MEANING"
jq -nc --arg t "$parts" '{text:$t}'
```

该行之前的全部内容**原样保留不动**（source words-lib、`wl_select`、写 `WORDS_STATE_FILE`、后台预取触发、`ph=`/`ex=` 读取都留着——它们对新输出无副作用）。只替换从 `nl=$'\n'` 到文件末尾的那一段。

- [ ] **Step 4: 运行确认通过**

Run: `bash ~/.config/waybar/test_quotes.sh`
Expected: PASS，`quotes-text-shape`/`quotes-text-has-pos`/`quotes-text-no-double-space`/`quotes-still-valid-json`/`quotes-no-tooltip-block` 全 ok；原有 `lib-matches-quotes-text` 仍 ok（旧 fixture 无 pos → text=`w m`）。

- [ ] **Step 5: Commit**

```bash
git -C ~/dotfiles add waybar/quotes.sh waybar/test_quotes.sh
git -C ~/dotfiles -c commit.gpgsign=false commit -m "feat(words): rebuild bar text with pos, drop tooltip block

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: word-popup.sh — 输出 eww 弹窗 JSON

**Files:**
- Create: `~/.config/waybar/word-popup.sh`
- Modify: `~/.config/waybar/test_quotes.sh`（Task7 段之后插入）

- [ ] **Step 1: 写失败测试**

在 Task7 段之后、`exit $fail` 之前插入：

```bash
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
```

- [ ] **Step 2: 运行确认失败**

Run: `bash ~/.config/waybar/test_quotes.sh`
Expected: FAIL，`popup-*` 报错（`word-popup.sh` 不存在）。

- [ ] **Step 3: 写 word-popup.sh**

Create `~/.config/waybar/word-popup.sh`:

```bash
#!/usr/bin/env bash
# eww 弹窗数据源：当前词富信息 + 今日 10 词。复用 words-lib 选词与缓存。
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WL_QUIET=1
. "$DIR/words-lib.sh"

wl_select   # 设 WL_IDX/WL_SEL/WL_WORD/WL_POS/WL_MEANING；前置失败静默退出

ph=""; ex=""
if [ -r "$WORDS_CACHE_FILE" ]; then
  ph=$(jq -r --arg w "$WL_WORD" '.words[$w].phonetic    // ""' "$WORDS_CACHE_FILE" 2>/dev/null)
  ex=$(jq -r --arg w "$WL_WORD" '.words[$w].examples[0] // ""' "$WORDS_CACHE_FILE" 2>/dev/null)
fi
pos_json=$(jq -nc --arg p "$WL_POS" '($p|select(length>0)|split(" & "))//[]')

today="[]"
for i in "${WL_IDX[@]}"; do
  w=$(wl_word_at "$i"); m=$(wl_meaning_at "$i")
  cur=$([ "$i" = "$WL_SEL" ] && echo true || echo false)
  today=$(jq -c --arg w "$w" --arg m "$m" --argjson c "$cur" \
    '. + [{word:$w,meaning:$m,current:$c}]' <<<"$today")
done

jq -nc \
  --arg w "$WL_WORD" --argjson pos "$pos_json" --arg ph "$ph" \
  --arg m "$WL_MEANING" --arg ex "$ex" --argjson today "$today" \
  '{current:{word:$w,pos:$pos,phonetic:$ph,meaning:$m,example:$ex},today:$today}'
```

- [ ] **Step 4: 运行确认通过**

Run: `bash ~/.config/waybar/test_quotes.sh && chmod +x ~/.config/waybar/word-popup.sh`
Expected: PASS，`popup-valid-json`/`popup-today-10`/`popup-one-current`/`popup-current-matches-quotes`/`popup-pos-array`/`popup-degrade-*` 全 ok。

- [ ] **Step 5: Commit**

```bash
git -C ~/dotfiles add waybar/word-popup.sh waybar/test_quotes.sh
git -C ~/dotfiles -c commit.gpgsign=false commit -m "feat(words): word-popup.sh emits eww popup JSON

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: word-speak.sh — 仅朗读当前词（无 notify-send）

**Files:**
- Create: `~/.config/waybar/word-speak.sh`
- Modify: `~/.config/waybar/test_quotes.sh`（Task8 段之后插入）

- [ ] **Step 1: 写失败测试**

在 Task8 段之后、`exit $fail` 之前插入：

```bash
# === Task9: word-speak.sh 仅朗读、不通知 ===
WSPK="$HOME/.config/waybar/word-speak.sh"
SF3="$CACHE_DIR/curw3"
rw=$(WORDS_NO_PREFETCH=1 WORDS_STATE_FILE="$SF3" WORDS_CACHE_FILE="$CF" \
  WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 WORDS_EPOCH=20 bash "$SCRIPT" \
  | jq -r '.text' | awk '{print $1}')
dr=$(WORDS_DRY_RUN=1 WORDS_STATE_FILE="$SF3" WORDS_CACHE_FILE="$CF" \
  WORDLIST_FILE="$WLQ" WORDS_SEED=20260515 WORDS_EPOCH=20 bash "$WSPK")
chk "$(printf '%s\n' "$dr" | sed -n 's/^WORD=//p')" "$rw" "speak2-word-matches"
chk "$(printf '%s\n' "$dr" | sed -n 's/^AUDIO_SRC=//p')" "cache" "speak2-src-cache"
printf '%s\n' "$dr" | grep -q '^NOTIFY' && chk "1" "0" "speak2-no-notify" \
  || chk "0" "0" "speak2-no-notify"
# 无缓存无状态 → gtts 兜底，不报错
dr2=$(WORDS_DRY_RUN=1 WORDS_STATE_FILE="/nonexistent/x" \
  WORDS_CACHE_FILE="/nonexistent/n.json" WORDLIST_FILE="$WLQ" \
  WORDS_SEED=20260515 WORDS_EPOCH=20 bash "$WSPK")
chk "$(printf '%s\n' "$dr2" | sed -n 's/^AUDIO_SRC=//p')" "gtts" "speak2-gtts-fallback"
```

- [ ] **Step 2: 运行确认失败**

Run: `bash ~/.config/waybar/test_quotes.sh`
Expected: FAIL，`speak2-*` 报错（`word-speak.sh` 不存在）。

- [ ] **Step 3: 写 word-speak.sh**

Create `~/.config/waybar/word-speak.sh`:

```bash
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
```

- [ ] **Step 4: 运行确认通过**

Run: `bash ~/.config/waybar/test_quotes.sh && chmod +x ~/.config/waybar/word-speak.sh`
Expected: PASS，`speak2-word-matches`/`speak2-src-cache`/`speak2-no-notify`/`speak2-gtts-fallback` 全 ok。

- [ ] **Step 5: Commit**

```bash
git -C ~/dotfiles add waybar/word-speak.sh waybar/test_quotes.sh
git -C ~/dotfiles -c commit.gpgsign=false commit -m "feat(words): word-speak.sh, TTS only, no notify

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: matugen → eww 配色模板

**Files:**
- Create: `~/dotfiles/matugen/templates/eww-colors.scss`
- Modify: `~/dotfiles/matugen/config.toml`（在 `[templates.swaync]` 段之后追加）

- [ ] **Step 1: 写 matugen 模板**

Create `~/dotfiles/matugen/templates/eww-colors.scss`:

```scss
/* Generated with Matugen — do not edit */
$bg:        {{colors.surface.default.hex}};
$sc:        {{colors.surface_container.default.hex}};
$sc_low:    {{colors.surface_container_low.default.hex}};
$sc_lowest: {{colors.surface_container_lowest.default.hex}};
$sc_high:   {{colors.surface_container_high.default.hex}};
$on:        {{colors.on_surface.default.hex}};
$on_var:    {{colors.on_surface_variant.default.hex}};
$primary:   {{colors.primary.default.hex}};
$pri_cont:  {{colors.primary_container.default.hex}};
$on_pri_c:  {{colors.on_primary_container.default.hex}};
$outline:   {{colors.outline.default.hex}};
$out_var:   {{colors.outline_variant.default.hex}};
$sec_cont:  {{colors.secondary_container.default.hex}};
$tertiary:  {{colors.tertiary.default.hex}};
```

- [ ] **Step 2: 注册模板**

在 `~/dotfiles/matugen/config.toml` 中 `[templates.swaync]` 三行块之后，追加：

```toml
[templates.eww]
input_path = '~/.config/matugen/templates/eww-colors.scss'
output_path = '~/.config/eww/colors.scss'
post_hook = 'eww reload 2>/dev/null || true'
```

- [ ] **Step 3: 提交（生成留待 Task 7 建好 eww 目录后）**

```bash
git -C ~/dotfiles add matugen/templates/eww-colors.scss matugen/config.toml
git -C ~/dotfiles -c commit.gpgsign=false commit -m "feat(matugen): eww colors template

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: eww 配置脚手架（窗口 + revealer + 卡片 + 样式）

**Files:**
- Create: `~/dotfiles/eww/eww.yuck`
- Create: `~/dotfiles/eww/eww.scss`
- Create: `~/dotfiles/eww/colors.scss`（占位，随后由 matugen 覆盖）
- Create symlink: `~/.config/eww` → `~/dotfiles/eww`

- [ ] **Step 1: 建目录与 symlink**

Run:
```bash
mkdir -p ~/dotfiles/eww
ln -sfn ~/dotfiles/eww ~/.config/eww
ls -ld ~/.config/eww
```
Expected: `~/.config/eww -> /home/mhpsy/dotfiles/eww`。

- [ ] **Step 2: 写占位 colors.scss（防 matugen 未跑时 @import 失败）**

Create `~/dotfiles/eww/colors.scss`:

```scss
$bg:#111318;$sc:#1e1f25;$sc_low:#1a1b20;$sc_lowest:#0c0e13;$sc_high:#282a2f;
$on:#e2e2e9;$on_var:#c4c6d0;$primary:#adc6ff;$pri_cont:#2b4678;$on_pri_c:#d8e2ff;
$outline:#8e9099;$out_var:#44474f;$sec_cont:#3f4759;$tertiary:#debcdf;
```

- [ ] **Step 3: 写 eww.yuck**

Create `~/dotfiles/eww/eww.yuck`:

```lisp
;; 每日单词灵动岛。窗口常驻打开；word_reveal 翻转触发 revealer 动画。
(defvar word_reveal false)

(defpoll WP :interval "5s" :initial "{}" `~/.config/waybar/word-popup.sh`)

(defwidget poschips [pos]
  (box :class "chips" :space-evenly false :spacing 6 :visible {arraylength(pos) > 0}
    (for p in pos (label :class "chip" :text p))))

(defwidget wordcard []
  (box :class "card" :orientation "v" :space-evenly false
    (box :class "pad" :orientation "v" :space-evenly false
      (box :class "wrow" :space-evenly false :spacing 10
        (label :class "word" :text {WP.current.word ?: ""})
        (poschips :pos {WP.current.pos ?: "[]"}))
      (label :class "ph" :halign "start" :visible {(WP.current.phonetic ?: "") != ""}
             :text {WP.current.phonetic ?: ""})
      (label :class "mean" :halign "start" :wrap true :text {WP.current.meaning ?: ""})
      (label :class "ex" :halign "start" :wrap true
             :visible {(WP.current.example ?: "") != ""}
             :text {WP.current.example ?: ""})
      (button :class "spk" :halign "start"
              :onclick "~/.config/waybar/word-speak.sh &" "🔊  朗读单词"))
    (box :class "divider")
    (label :class "listhdr" :halign "start" :text "今日单词 · 10")
    (box :class "lst" :orientation "v" :space-evenly false
      (for it in {WP.today ?: "[]"}
        (box :class {it.current ? "row cur" : "row"} :space-evenly false
          (label :class "rw" :halign "start" :hexpand true :text {it.word})
          (label :class "rm" :halign "end" :text {it.meaning}))))))

(defwindow daily-word
  :stacking "overlay"
  :focusable false
  :geometry (geometry :x "520px" :y "0px" :anchor "top left" :width "360px")
  (revealer :transition "slidedown" :duration "400ms" :reveal word_reveal
    (eventbox :onclick "" (wordcard))))
```

注：`:x "520px"` 是 `custom/quotes` 模块大致左偏移的初值，Task 9 里目测微调。

- [ ] **Step 4: 写 eww.scss**

Create `~/dotfiles/eww/eww.scss`:

```scss
@import "colors";

* { all: unset; font-family: "JetBrains Mono", "LXGW WenKai", sans-serif; }

.card {
  background: $sc;
  border: 1px solid $out_var;
  border-radius: 20px;
  margin: 6px 0 0 0;
  box-shadow: 0 20px 60px rgba(0,0,0,0.6);
}
.pad { padding: 17px 19px; }
.wrow { }
.word { font-size: 21px; font-weight: 600; color: $on; }
.chips { }
.chip {
  font-size: 12px; color: $tertiary;
  background: rgba(222,188,223,0.10);
  padding: 3px 7px; border-radius: 6px; margin-left: 6px;
}
.ph   { color: $primary; font-size: 13px; margin: 8px 0 0 0; }
.mean { color: $on_var; font-size: 15px; margin-top: 8px; }
.ex   {
  color: $outline; font-size: 13px; font-style: italic;
  margin-top: 11px; padding-left: 10px;
  border-left: 2px solid $sec_cont;
}
.spk {
  background: $pri_cont; color: $on_pri_c;
  border-radius: 9px; padding: 7px 13px; margin-top: 15px; font-size: 12px;
}
.spk:hover { background: lighten($pri_cont, 6%); }
.divider { background: $out_var; min-height: 1px; margin: 15px 0 0 0; }
.listhdr { color: $outline; font-size: 11px; padding: 13px 19px 7px 19px; }
.lst { padding: 0 10px 14px 10px; }
.row { padding: 6px 9px; border-radius: 8px; font-size: 13px; }
.row.cur { background: rgba(173,198,255,0.10); }
.rw { color: $primary; }
.rm { color: $outline; }
```

- [ ] **Step 5: 生成真实配色并验证 eww 配置可解析**

Run:
```bash
matugen image "$(cat ~/.cache/wal/wal 2>/dev/null || echo)" >/dev/null 2>&1 || true
ls -l ~/.config/eww/colors.scss
eww --config ~/.config/eww ping 2>&1 || eww --config ~/.config/eww reload 2>&1
eww open daily-word
eww update word_reveal=true
```
Expected: `colors.scss` 存在；eww 无 yuck/scss 解析错误；屏幕顶部偏左出现单词卡片（位置可能偏，Task 9 调）。
若 matugen 那条没刷新颜色也没关系，占位 `colors.scss` 已能渲染。

- [ ] **Step 6: Commit**

```bash
git -C ~/dotfiles add eww/eww.yuck eww/eww.scss eww/colors.scss
git -C ~/dotfiles -c commit.gpgsign=false commit -m "feat(eww): daily-word island window + card + scss

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: 接线 — toggle 脚本 + waybar config + hypr 自启

**Files:**
- Create: `~/.config/waybar/word-island-toggle.sh`
- Modify: `~/.config/waybar/config.jsonc`（`custom/quotes` 块）
- Modify: `~/.config/hypr/conf/autostart.conf`

- [ ] **Step 1: 写 toggle 脚本**

Create `~/.config/waybar/word-island-toggle.sh`:

```bash
#!/usr/bin/env bash
# waybar custom/quotes on-click：开/关灵动岛（翻转 eww word_reveal）。
set -u
C="$HOME/.config/eww"
command -v eww >/dev/null 2>&1 || exit 0
eww --config "$C" ping >/dev/null 2>&1 || eww --config "$C" daemon >/dev/null 2>&1
eww --config "$C" windows 2>/dev/null | grep -qx 'daily-word' \
  || eww --config "$C" open daily-word >/dev/null 2>&1
cur=$(eww --config "$C" get word_reveal 2>/dev/null)
[ "$cur" = "true" ] && nv=false || nv=true
eww --config "$C" update word_reveal=$nv >/dev/null 2>&1
```

Run: `chmod +x ~/.config/waybar/word-island-toggle.sh`

- [ ] **Step 2: 改 waybar config.jsonc**

把 `~/.config/waybar/config.jsonc` 中 `custom/quotes` 块：

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

改为：

```jsonc
    "custom/quotes": {
        "format": "{}",
        "return-type": "json",
        "exec": "~/.config/waybar/quotes.sh",
        "interval": 10,
        "tooltip": false,
        "on-click": "~/.config/waybar/word-island-toggle.sh"
    },
```

- [ ] **Step 3: hypr 自启拉起 eww 窗口**

在 `~/.config/hypr/conf/autostart.conf` 中 `exec-once = ~/.config/waybar/launch.sh` 那行之后，新增一行：

```conf
exec-once = eww --config ~/.config/eww open daily-word
```

- [ ] **Step 4: 重载并冒烟验证**

Run:
```bash
~/.config/waybar/launch.sh
eww --config ~/.config/eww open daily-word 2>/dev/null
~/.config/waybar/word-island-toggle.sh; sleep 1
eww --config ~/.config/eww get word_reveal
~/.config/waybar/word-island-toggle.sh; sleep 1
eww --config ~/.config/eww get word_reveal
```
Expected: 两次分别打印 `true` 然后 `false`；屏幕上卡片对应滑入/滑出（有动画）。waybar 顶栏单词模块显示不变、悬停无 tooltip。

- [ ] **Step 5: Commit**

```bash
git -C ~/dotfiles add waybar/word-island-toggle.sh waybar/config.jsonc
git -C ~/dotfiles -c commit.gpgsign=false commit -m "feat(words): wire island toggle into waybar + hypr autostart

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```
（`~/.config/hypr/conf/autostart.conf` 若在 git 仓库内一并 add；用 `git -C ~/dotfiles status` 确认其路径后加入同一 commit。）

---

### Task 9: 位置微调 + 主题联动 + 验收 + 收尾

**Files:**
- Modify: `~/dotfiles/eww/eww.yuck`（`:x` 数值）
- Modify: `~/dotfiles/docs/superpowers/specs/2026-05-18-waybar-word-island-design.md`（状态）

- [ ] **Step 1: 目测对齐 X 偏移**

点开灵动岛，看卡片左缘是否对齐顶栏「单词」模块。偏了就改 `eww.yuck` 里
`:x "520px"` 的数值（每次改后 `eww --config ~/.config/eww reload`，再 toggle 看），
直到卡片大致在该模块正下方。

- [ ] **Step 2: 主题联动验证**

Run:
```bash
matugen image ~/.config/hypr/wallpapers/* 2>/dev/null | tail -1 || true
sleep 1
grep -m1 primary ~/.config/eww/colors.scss
```
Expected: `colors.scss` 的 `$primary` 等已是当前壁纸配色；toggle 打开灵动岛颜色与 waybar/swaync 一致。（若你的换壁纸流程不是上面这条命令，用你平时换壁纸的方式触发一次，确认 eww 颜色跟着变。）

- [ ] **Step 3: 跑全量测试**

Run: `bash ~/.config/waybar/test_quotes.sh; echo "exit=$?"`
Expected: 末行 `exit=0`，无 `FAIL` 行。

- [ ] **Step 4: 手动验收清单（逐项打勾）**

- [ ] 顶栏单词模块视觉与改造前一致（词 + 词性 + 释义，每 10s 轮换）
- [ ] 悬停模块**无** tooltip
- [ ] 点击模块：卡片带回弹动画滑出；再点：滑回（动画顺滑）
- [ ] 卡片内容正确：单词 / 词性 chip / 音标 / 释义 / 例句 / 🔊
- [ ] 「今日单词 · 10」列表 10 行，当前词高亮
- [ ] 开着不动等 ≥10s：当前词随轮换变、列表高亮跟着移动
- [ ] 点 🔊：朗读当前词，**不**弹 swaync 通知
- [ ] 换壁纸/主题后：灵动岛配色跟随变化
- [ ] 重启（或重新登录）后：`eww` 自启、点击仍可开合

- [ ] **Step 5: 标记 spec 完成并提交**

把 `docs/superpowers/specs/2026-05-18-waybar-word-island-design.md` 第 4 行
`状态：已确认，待实现` 改为 `状态：已实现`。

```bash
git -C ~/dotfiles add eww/eww.yuck docs/superpowers/specs/2026-05-18-waybar-word-island-design.md
git -C ~/dotfiles -c commit.gpgsign=false commit -m "feat(words): tune island position, mark spec implemented

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## 不做（明确排除，沿用 spec）

- 点窗外/`Esc` 自动关闭：eww 0.5 对非聚焦窗口键盘支持弱，全局 Esc 重绑侵入性大。
  MVP 关闭方式 = 再点一次模块（toggle）。Esc 列为后续可选增强，不在本计划。
- 卡片内翻页（上一词/下一词）。
- 联网取词性。
- 保留旧「点击朗读 + notify-send」兼容路径（`speak-word.sh` 不再被引用，保留文件不删）。

## 自检结论

- **spec 覆盖**：交互(Task8)、eww 渲染(Task7)、内容含今日清单(Task4/7)、动画 revealer(Task7)、matugen 主题(Task6/9)、词性数组(Task1/2)、测试(Task1-5,9)、不做项一致——逐条有对应任务。
- **占位符**：无 TBD；所有 code step 给出完整代码/命令/期望输出。
- **类型一致**：`WL_POS`(字符串 `a & b`)、`wl_pos_at`、`word_reveal`、`WP`、`word-popup.sh` JSON 字段名在各 Task 间一致；`word-popup.sh` 的 pos 由 `WL_POS` split 回数组，与 eww `poschips` 消费的数组一致。
