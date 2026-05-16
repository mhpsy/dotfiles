# Waybar 每日单词 — 点击朗读 + 例句 设计文档

日期：2026-05-16
状态：已确认，待实现
关联：扩展 [2026-05-15-waybar-daily-words-design.md](2026-05-15-waybar-daily-words-design.md)
（该文档「不做」一节里的「不做音标/发音」「不做联网词典兜底」在本需求中被有意推翻）

## 背景与目标

现有 `custom/quotes`「每日单词」模块只在 bar 上显示「单词 释义」、tooltip 列出今日 10 词。
本次新增两件事：

1. **点击朗读**：左键点击模块时，朗读当前正在显示的那个英文单词。
2. **例句**：把当前单词的音标 + 例句加入展示。

确认过的决策（来自 brainstorming）：

- 数据来源：**在线 API**（`dictionaryapi.dev`），拿真人录制 MP3 发音 + 真实例句，无需安装离线 TTS。
- 例句展示位置：**悬停 tooltip**（当前单词的音标/释义/例句加进 tooltip）。
- 点击交互：**左键同时**朗读发音 + 弹出例句通知（`notify-send`）。

## 方案

**方案 A：预取并缓存今日 10 词（采用）。**
今日 10 词由日期种子确定。后台预取脚本每天对这 10 词各调一次
`dictionaryapi.dev`，把「音频 URL + 音标 + 简短释义 + 1~2 条例句」写入
`~/.cache/waybar/words.json`。`quotes.sh` 读缓存即时填充 tooltip；点击脚本读
缓存播放音频 + 通知。每 10 秒刷新不触网，tooltip 不卡，点击即时响应。
代价：多一个缓存文件 + 一个预取步骤；跨天后首次约 1~3 秒后台填充期间例句暂缺。

否决的备选：

- 方案 B（每 10 秒实时拉当前词）：每次 waybar 刷新都带网络延迟，可见卡顿，
  且每天约 8640 次打 API。否决。
- 方案 C（只在点击时拉取）：tooltip 无法显示例句（不满足需求）。否决。

## 文件结构

所有脚本位于 `~/dotfiles/waybar/`，symlink 进 `~/.config/waybar/`。

| 文件 | 角色 | 变化 |
|---|---|---|
| `words-lib.sh` | 共享选词逻辑（种子→今日 10 下标 IDX；epoch→当前下标） | 新增 |
| `words-cache.sh` | 今日 10 词调 API，写 `~/.cache/waybar/words.json` | 新增 |
| `speak-word.sh` | `on-click` 目标：朗读当前词 + 弹例句通知 | 新增 |
| `quotes.sh` | 改为 source `words-lib.sh`；tooltip 增当前词富信息块；后台触发缓存 | 改 |
| `config.jsonc` | `custom/quotes` 增 `"on-click": "~/.config/waybar/speak-word.sh"` | 改 1 行 |
| `test_quotes.sh` | 新增选词一致性 / 缓存 JSON 合法性 / 点击词一致性 测试 | 改 |

`custom/quotes` 模块名、bar 位置、`text` 显示格式均不变。

## 缓存格式 `~/.cache/waybar/words.json`

```json
{
  "seed": "20260516",
  "words": {
    "abandon": {
      "phonetic": "/əˈbændən/",
      "audio": "https://api.dictionaryapi.dev/media/pronunciations/en/abandon-us.mp3",
      "definition": "To give up or relinquish control of...",
      "examples": ["Many baby girls have been abandoned on the streets of Beijing."]
    }
  }
}
```

- `seed` = 当天 `date +%Y%m%d`，用于判断缓存是否过期（跨天即整体重建）。
- `words` 以单词为键。任一字段可能缺失（API 无该词/无音频/无例句），消费方按缺失降级。

## `words-lib.sh`（共享选词）

把现 `quotes.sh` 内的选词逻辑原样抽出为可被 `source` 的库，保证显示与点击
对「当前是哪个词」永不漂移：

- `WORDLIST_FILE` / `SEED` / `EPOCH` / `DAILY=10` / `ROTATE=10` 变量与现状一致。
- 提供：今日下标集合 `IDX`（openssl AES-CTR keystream 喂 `shuf` 的确定性洗牌，
  算法与现 `quotes.sh` 第 68 行**完全相同**，不改算法）；当前下标
  `sel = IDX[(EPOCH/ROTATE)%take]`；以及取 `word`/`meaning` 的辅助。
- 无 `jq` / 词库不可读 / 词库空 → 与现状一致地走「空输出」路径（库提供可被
  调用方复用的空处理约定，行为不变）。

## `words-cache.sh`（预取）

```
1. source words-lib.sh，得今日 IDX → 今日 10 个 word
2. 若 ~/.cache/waybar/words.json 的 seed == 今日 seed 且 10 词齐全 → 直接退出（幂等）
3. 对每个缺失的 word：
   curl --max-time 5 -s "https://api.dictionaryapi.dev/api/v2/entries/en/<word>"
   解析：第一个非空 audio 的 mp3 URL；第一个 phonetic 文本；
        meanings[].definitions 里第一条 definition；最多取 2 条非空 example
4. 原子写入（写临时文件后 mv），seed 标记为今日
```

实现要点（已定）：

- 单词为 wordlist 内单 token，URL 直接拼接（必要时 `--data-urlencode` 兜底）。
- API 无该词（404/空数组）→ 该词写入仅有的字段或留空，**不重试**（当天不再拉）。
- 网络整体失败 → 写入已成功部分；下次 `quotes.sh` 触发时对仍缺失的词重试。
- `curl` 加 `-A` UA 头；总预取约 10 次串行请求，全程在后台跑，不阻塞 waybar。

## `quotes.sh`（改动）

- 顶部改为 `source words-lib.sh`，删除重复的内联选词代码（行为不变）。
- 缓存缺失或 `seed` 非今日 → 非阻塞触发后台预取：
  `setsid flock -n ~/.cache/waybar/words.lock ~/.config/waybar/words-cache.sh >/dev/null 2>&1 &`
  用 `flock -n` 单一去重机制保证同一时刻只有一个预取在跑（不另用 pid 文件）。
- bar `text`：**保持不变**（`<word> <meaning>`，不解析、不剥词性）。
- `tooltip`：现「今日单词」10 词列表**之上**新增当前词富信息块：
  ```
  ▶ abandon  /əˈbændən/
    v. 放弃；抛弃
    例: Many baby girls have been abandoned on the streets of Beijing.
  ──────────
  今日单词
  abandon  v. 放弃；抛弃
  ...（全 10 个，同现状）
  ```
  缓存未就绪 → 富信息块降级为仅 `word  meaning`（即与现状等价），不报错。

## `speak-word.sh`（新，on-click 目标）

```
1. source words-lib.sh，得当前 word（与 quotes.sh 当下显示的同一个）
2. 读 ~/.cache/waybar/words.json 取该词 audio/phonetic/definition/examples
3. 朗读：
   - 有 cached audio URL → mpv --no-video --really-quiet "<url>"
   - 无 → 兜底 Google TTS:
     mpv --no-video --really-quiet
       "https://translate.google.com/translate_tts?ie=UTF-8&tl=en&client=tw-ob&q=<word>"
   - 播放前杀掉上一次本脚本的 mpv（仅按 /tmp/waybar-word-mpv.pid 记录的 PID，
     绝不 pkill 全局 mpv，避免误杀用户音乐），新 mpv 的 PID 写入该文件
4. 通知：notify-send "abandon  /əˈbændən/" "v. 放弃；抛弃\n\n例: <example>"
   （音标/例句缺失则相应行省略）
```

## 错误处理

- 无 `mpv` / 无 `curl` / 无 `jq` → 静默降级（最多一条 `notify-send` 提示），
  bar 与 tooltip 不报错、不影响选词显示。
- 离线（API + Google TTS 均不可达）→ 不发声；tooltip 退回仅释义；
  可选发一条「🔇 离线」通知。
- 缓存文件损坏 / 非法 JSON → 当作缺失处理，重新预取。
- 跨天 → `seed` 不匹配触发整体重建为新 10 词。
- 快速连点 → 仅杀本脚本上次 mpv，不叠音、不影响用户其它 mpv。

## 不做（YAGNI）

- 不做离线 TTS（espeak/piper）——已选在线方案。
- 不做点击翻页 / 上一个下一个 / 生词本。
- 不做多 API 聚合、不做发音口音选择 UI（固定优先 US 音频）。
- 不做缓存 systemd timer——后台懒触发已足够。

## 验收标准

1. 左键点击模块 → 听到当前显示单词的英文发音（真人 MP3，失败时 Google TTS 兜底）。
2. 同一次点击 → 弹出 `notify-send` 通知，含单词 + 音标 + 释义 + 例句。
3. 鼠标悬停 → tooltip 顶部出现当前词的音标 + 释义 + 例句块，下方仍是今日 10 词列表。
4. 缓存未就绪（如刚跨天的头几秒）→ tooltip 富信息块降级为仅释义，waybar 不报错。
5. 播放期间快速连点 → 不叠音；用户正在用 mpv 放的音乐不被杀掉。
6. 断网 → 点击不报错、bar 与 tooltip 正常（无音频、无例句行）。
7. 跨天 → 缓存自动重建为新 10 词，发音与例句对应新词。
8. 固定 `SEED`/`EPOCH` 下，`speak-word.sh` 解析出的当前词与 `quotes.sh` 显示的完全一致。
