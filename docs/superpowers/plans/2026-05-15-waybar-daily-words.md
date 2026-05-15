# Waybar 每日单词模块 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 waybar `custom/quotes` 模块从中文鸡汤改造成「每日单词」：本地词库每天确定性抽 10 个，bar 上每 10 秒轮换一个，显示「单词 释义」。

**Architecture:** 方案 A（无状态日期种子）。`quotes.sh` 用 `date +%Y%m%d` 作种子，经 `openssl enc` 派生确定性字节流喂 `shuf` 选出今日 10 个下标；轮换位置由 `(epoch/10)%10` 决定。为可测试，脚本接受 `WORDS_SEED` / `WORDS_EPOCH` / `WORDLIST_FILE` 环境变量覆盖，默认取真实值。

**Tech Stack:** bash, jq, shuf, openssl；waybar custom module (return-type json)。

参考 spec：`docs/superpowers/specs/2026-05-15-waybar-daily-words-design.md`

---

### Task 1: 生成词库 `wordlist.json`

**Files:**
- Create: `~/.config/waybar/wordlist.json`（= `~/dotfiles/waybar/wordlist.json`，symlink 仓库内路径 `waybar/wordlist.json`）

- [ ] **Step 1: 写词库文件**

结构：`{"words":[{"word":"...","meaning":"..."}]}`。至少 120 个中高频英文词（四六级/考研区间），每条含词性+中文释义。示例开头：

```json
{
  "words": [
    { "word": "abandon", "meaning": "v. 放弃；抛弃" },
    { "word": "ability", "meaning": "n. 能力；才能" },
    { "word": "absolute", "meaning": "adj. 绝对的；完全的" },
    { "word": "abstract", "meaning": "adj. 抽象的 n. 摘要" },
    { "word": "academic", "meaning": "adj. 学术的 n. 学者" },
    { "word": "accelerate", "meaning": "v. 加速；促进" },
    { "word": "accommodate", "meaning": "v. 容纳；适应" },
    { "word": "accomplish", "meaning": "v. 完成；实现" },
    { "word": "accurate", "meaning": "adj. 准确的；精确的" },
    { "word": "achieve", "meaning": "v. 达到；实现" }
  ]
}
```

实现时补齐到 ≥120 词（覆盖 a–w 常见词），保持同一 JSON 结构，UTF-8，无尾逗号。

- [ ] **Step 2: 校验 JSON 合法 + 词数**

Run: `jq '.words | length' ~/.config/waybar/wordlist.json`
Expected: 输出 ≥ 120 的整数，无 jq 解析报错。

- [ ] **Step 3: Commit**

```bash
cd ~/dotfiles
git add waybar/wordlist.json
git commit -m "feat(waybar): add english wordlist for daily-words module"
```

---

### Task 2: 写测试脚本（先失败）

**Files:**
- Create: `~/.config/waybar/test_quotes.sh`（仓库 `waybar/test_quotes.sh`）

- [ ] **Step 1: 写测试脚本**

```bash
#!/usr/bin/env bash
# quotes.sh 行为测试。用固定 fixture + 固定 seed/epoch 断言确定性、轮换、跨天、错误处理。
set -u
SCRIPT="$HOME/.config/waybar/quotes.sh"
FIX="$(mktemp)"
trap 'rm -f "$FIX"' EXIT

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

exit $fail
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `bash ~/.config/waybar/test_quotes.sh`
Expected: FAIL（此时 `quotes.sh` 仍是旧鸡汤逻辑，不认 `WORDLIST_FILE`/`WORDS_SEED`，多数断言失败）。

- [ ] **Step 3: Commit**

```bash
cd ~/dotfiles
git add waybar/test_quotes.sh
git commit -m "test(waybar): add behavior tests for daily-words quotes.sh"
```

---

### Task 3: 重写 `quotes.sh` 实现单词逻辑

**Files:**
- Modify: `~/.config/waybar/quotes.sh`（整文件重写，仓库 `waybar/quotes.sh`）

- [ ] **Step 1: 写实现**

```bash
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
```

- [ ] **Step 2: 运行测试，确认通过**

Run: `bash ~/.config/waybar/test_quotes.sh`
Expected: 所有断言 `ok ...`，脚本退出码 0。

- [ ] **Step 3: 手动 sanity check（用真实词库）**

Run: `WORDS_EPOCH=0 bash ~/.config/waybar/quotes.sh | jq .`
Expected: 合法 JSON，`text` 形如 `abandon v. 放弃；抛弃`，`tooltip` 有 10 行。
Run: `WORDS_EPOCH=10 bash ~/.config/waybar/quotes.sh | jq -r .text`
Expected: 与 epoch=0 不同的词（轮换生效）。

- [ ] **Step 4: Commit**

```bash
cd ~/dotfiles
git add waybar/quotes.sh
git commit -m "feat(waybar): rewrite quotes.sh as daily-words (date-seeded, rotating)"
```

---

### Task 4: 改 waybar 配置 + 删旧 quotes.json

**Files:**
- Modify: `~/.config/waybar/config.jsonc`（`custom/quotes` 的 `interval`）
- Delete: `~/.config/waybar/quotes.json`

- [ ] **Step 1: 把 custom/quotes 的 interval 改成 10**

定位 `config.jsonc` 中：

```jsonc
    "custom/quotes": {
        "format": "{}",
        "return-type": "json",
        "exec": "~/.config/waybar/quotes.sh",
        "interval": 600,
        "tooltip": true
    },
```

把 `"interval": 600,` 改为 `"interval": 10,`。其余字段不动（exec 路径、模块名复用）。

- [ ] **Step 2: 删除旧鸡汤数据**

```bash
cd ~/dotfiles
git rm waybar/quotes.json
```

- [ ] **Step 3: 重启 waybar 验证**

```bash
killall waybar; sleep 0.3; hyprctl dispatch exec waybar; sleep 0.6; pgrep -a waybar
```
Expected: waybar 起来，原 `custom/quotes` 位置显示「单词 释义」，约 10 秒换一个；悬停出 tooltip 列今日 10 词。

- [ ] **Step 4: Commit**

```bash
cd ~/dotfiles
git add waybar/config.jsonc
git commit -m "feat(waybar): point custom/quotes at daily-words, drop old quotes.json"
```

---

### Task 5: 收尾验证（验收标准）

**Files:** 无（纯验证）

- [ ] **Step 1: 跑测试套件**

Run: `bash ~/.config/waybar/test_quotes.sh; echo "exit=$?"`
Expected: 全 `ok`，`exit=0`。

- [ ] **Step 2: 确定性 & 跨天人工核对**

Run:
```bash
WORDS_SEED=20260515 WORDS_EPOCH=0 bash ~/.config/waybar/quotes.sh | jq -r .tooltip
WORDS_SEED=20260516 WORDS_EPOCH=0 bash ~/.config/waybar/quotes.sh | jq -r .tooltip
```
Expected: 两次 tooltip 的 10 词集合不同（跨天换新）；同 seed 多次运行集合一致。

- [ ] **Step 3: 错误兜底人工核对**

Run: `WORDLIST_FILE=/tmp/none.json bash ~/.config/waybar/quotes.sh`
Expected: `{"text": "", "class": "empty"}`，无 stderr 报错。

- [ ] **Step 4: 标记计划完成**

无需提交（前面任务已分别 commit）。在对话中向用户报告验收结果。

---

## Self-Review

**Spec coverage:**
- 本地词库随机抽 10 → Task 1 + Task 3（种子洗牌）✓
- 每天换新 10 → Task 3（SEED=date 派生）+ Task 5 跨天核对 ✓
- 每 10 秒轮换 → Task 3（`(EPOCH/10)%take`）+ Task 4（interval 10）✓
- bar 显示「单词 释义」原样不剥词性 → Task 3（`--arg t "$word $mean"`）✓
- tooltip 今日 10 词 → Task 3（循环拼 tip）✓
- 替换 quotes 复用模块位置 → Task 4（改 interval，exec/模块名不变）✓
- 删除 quotes.json → Task 4 Step 2 ✓
- 错误处理 empty class → Task 3（`emit_empty`）+ Task 2/5 测试 ✓
- 词库不足 10 → Task 3（`take=$N`）✓

**Placeholder scan:** 无 TBD/TODO；Task 1 词库要求"补齐到 ≥120 词"是明确可执行指令，非占位。

**Type consistency:** 环境变量名 `WORDLIST_FILE` / `WORDS_SEED` / `WORDS_EPOCH` 在 Task 2 测试与 Task 3 实现中一致；JSON 字段 `word`/`meaning`（词库）与 `text`/`tooltip`/`class`（输出）前后一致；`take` 变量在轮换、tooltip、错误分支统一使用。

无遗漏，无占位，类型一致。
