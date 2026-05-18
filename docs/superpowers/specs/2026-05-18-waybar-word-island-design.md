# Waybar 每日单词 — 灵动岛弹窗 设计文档

日期：2026-05-18
状态：已实现
关联：扩展 [2026-05-15-waybar-daily-words-design.md](2026-05-15-waybar-daily-words-design.md)、
[2026-05-16-waybar-word-tts-design.md](2026-05-16-waybar-word-tts-design.md)
（本次有意推翻后者的「悬停 tooltip 展示」「点击 = 朗读 + notify-send」两项交互）

## 背景与目标

现有 `custom/quotes`「每日单词」模块在 bar 上显示「单词 释义」（每 10s 轮换），
富信息靠 waybar 自带 **tooltip**（Pango 文本框）展示，点击 = 朗读 + `notify-send`。
tooltip 粗糙、无动画、外观不可定制。

目标：用一个**点击展开、带回弹动画、跟随主题**的精致弹窗（类似苹果灵动岛）
替换 tooltip 这条展示路径。

确认过的决策（来自 brainstorming）：

- **交互**：点击切换。点 bar 上的模块 = 开/关弹窗；再点一次 / 按 `Esc` 关闭。
  （点窗外关闭：eww 无原生失焦关闭，需透明背板，**列为不做**）
- **渲染**：**eww**（独立 layer-shell 浮层，社区做灵动岛的主流方案；已安装）。
- **内容**：当前词大卡（单词 / 词性 / 音标 / 释义 / 例句 / 🔊 朗读）
  \+ 下半「今日单词 · 10」列表，当前词高亮、随轮换实时更新。
- **动画**：eww `revealer`，slide + 透明度，~400ms `cubic-bezier` 回弹手感。
- **主题**：经 matugen 模板生成 eww 配色，换肤时与 waybar/swaync 统一。
- **词性**：拆成结构化 **数组**字段 `pos`，做成 chip 显示。
- **无历史包袱**：旧交互直接重写，不保留兼容开关。

## 方案

**胶囊不重做，只做展开卡（采用）。**
waybar 的 `custom/quotes` 模块**保持不变**，它就是顶栏那颗常驻「胶囊」
（继续显示 `单词 释义`、每 10s 轮换、复用现有选词与缓存逻辑）。
新增的 eww 窗口 `daily-word` 只渲染「展开后的卡片」，定位在该模块正下方。
点击模块触发 `eww open --toggle`，关闭走 toggle / `Esc`。

否决的备选：

- **eww 内重做胶囊 + 卡片整体**：与 waybar 模块视觉重复、需隐藏原模块、
  数据双份维护。否决。
- **AGS/Astal**：能力更强但依赖一整套库、配置重、维护成本高。否决。
- **纯 GTK4 layer-shell 脚本**：零新依赖但窗口/动画全手写、GTK CSS 动画能力有限。否决。

## 文件结构

脚本位于 `~/dotfiles/waybar/`（symlink 进 `~/.config/waybar/`）；
eww 配置位于 `~/dotfiles/eww/`（symlink 进 `~/.config/eww/`）。

| 文件 | 角色 | 变化 |
|---|---|---|
| `wordlist.json` | 词库，`meaning` 前缀词性拆为数组字段 `pos` | 改（重新生成） |
| `words-lib.sh` | 共享选词逻辑 | 改（读 `pos`；`WL_POS` 等） |
| `word-popup.sh` | 给 eww 输出弹窗 JSON（当前词富信息 + 今日 10 词数组） | 新增 |
| `word-island-toggle.sh` | `on-click` 目标：`eww open --toggle daily-word` | 新增 |
| `word-speak.sh` | 卡片内 🔊 调用：仅朗读当前词，**不** `notify-send` | 新增（取代 `speak-word.sh` 的点击职责） |
| `quotes.sh` | 去掉 tooltip 富信息块；`tooltip` 关；`on-click` 改 toggle | 改 |
| `config.jsonc` | `custom/quotes`：`"tooltip": false`、`on-click` 改 toggle 脚本 | 改 |
| `eww/eww.yuck` | `daily-word` 窗口 + widget 树 + revealer 动画 | 新增 |
| `eww/eww.scss` | 灵动岛样式，`@import` matugen 生成的 `colors.scss` | 新增 |
| `eww/colors.scss` | matugen 生成（不手改） | 新增（生成） |
| `matugen/config.toml` | 增 `[templates.eww]` → `~/.config/eww/colors.scss` | 改 |
| `matugen/templates/eww-colors.scss` | matugen 模板，输出 `$primary` 等 SCSS 变量 | 新增 |
| `test_quotes.sh` | 增：wordlist `pos` 转换、`word-popup.sh` JSON 断言 | 改 |

`custom/quotes` 模块名、bar 位置、`text` 显示格式不变。
`speak-word.sh` 不再被点击调用（无历史包袱，可保留文件不引用或后续清理，实现计划定）。

## 数据格式

### 新 `wordlist.json`

`pos` 为**数组**（一个词可有多个词性，未来可扩展；当前数据均为单元素）：

```json
{
  "words": [
    { "word": "abandon",   "pos": ["v."],   "meaning": "放弃；抛弃" },
    { "word": "ability",   "pos": ["n."],   "meaning": "能力；才能" },
    { "word": "ephemeral", "pos": ["adj."], "meaning": "短暂的；瞬息的" }
  ]
}
```

**重新生成规则**（纯本地、确定性、可测）：
对旧 `meaning` 切掉开头的词性前缀（已核实 161 词 100% 覆盖：`v.` 87、
`adj.` 43、`n.` 30、`adv.` 1），切出的 token 进 `pos` 数组，剩余去首空格作 `meaning`。
支持复合前缀（`&`/`/`/`,`/空格分隔，逐个入数组）；无可识别前缀 → `pos: []`、
`meaning` 不变。该转换是一次性脚本，结果直接覆盖 `wordlist.json`，旧文件先备份。

### eww 弹窗 JSON（`word-popup.sh` stdout）

```json
{
  "current": {
    "word": "ephemeral",
    "pos": ["adj."],
    "phonetic": "/ɪˈfemərəl/",
    "meaning": "短暂的；瞬息的",
    "example": "Fame in the digital age is often ephemeral."
  },
  "today": [
    { "word": "ephemeral",   "meaning": "短暂的", "current": true },
    { "word": "serendipity", "meaning": "意外之喜", "current": false }
  ]
}
```

- `current` 富信息：`word`/`pos`/`meaning` 来自 `wordlist.json`；
  `phonetic`/`example` 来自 `~/.cache/waybar/words.json`（缺失则为 `""`，UI 隐藏对应行）。
- `today`：今日 10 词（`word` + 短 `meaning`），`current` 标记当前轮换词供高亮。
- eww 用 `defpoll`（间隔 ≤ 轮换周期 10s）跟随 `~/.cache/waybar/current-word` 的变化，
  开着时高亮随轮换走。

## eww widget 与动画

- 窗口 `daily-word`：`:stacking "overlay"`、layer-shell，锚定屏幕**顶部偏左**，
  `:margin` 调到 `custom/quotes` 模块正下方（左偏移在 `eww.yuck` 里给可调常量，
  实现时按当前 bar 左侧模块宽度标定一个默认值；模块宽度随内容变化，标定到「足够接近」即可）。
- 结构：根 `revealer`（`:transition "slidedown"` + 透明度），内含
  「当前词卡片」+ 分隔线 + 「今日单词 · 10」列表（当前词行加 `.current` 类高亮）。
- 动画：revealer `:duration "400ms"`，SCSS 对卡片做
  `cubic-bezier(.34,1.5,.36,1)` 的 transform/opacity 过渡，复刻 brainstorm 中
  「点击切换」B 方案的回弹手感；收起为反向。
- 🔊 按钮 `:onclick` → `word-speak.sh`（仅朗读，无通知）。

## 交互

- `custom/quotes` `on-click` → `word-island-toggle.sh` → `eww open --toggle daily-word`。
- 关闭：再次点击模块（toggle）；`Esc`（eww 窗口键绑定 / Hyprland 规则，实现计划定）。
- 不再有「点击即朗读」；朗读只在卡片内 🔊。

## 主题（matugen 集成）

- 新增 `~/.config/matugen/templates/eww-colors.scss`，输出
  `$primary: {{colors.primary.default.hex}};` 等（沿用 `colors.css` 模板的同名色）。
- `matugen/config.toml` 增：

  ```toml
  [templates.eww]
  input_path = '~/.config/matugen/templates/eww-colors.scss'
  output_path = '~/.config/eww/colors.scss'
  post_hook = 'eww reload'
  ```

- `eww.scss` 顶部 `@import "colors";`，所有颜色走变量，换肤即跟随。

## 测试

- **wordlist 转换**：fixture（带各类词性前缀 + 无前缀的旧 meaning）→ 断言
  生成的 `pos` 数组与 `meaning` 正确；100% 覆盖与单元素不变性。
- **`word-popup.sh`**：给定 fixture `wordlist.json` + `words.json` + `current-word`
  → 断言输出 JSON 合法、`current` 字段正确、`today` 长度与高亮位正确、
  缓存缺失时 `phonetic`/`example` 为 `""`。
- 沿用 `test_quotes.sh` 风格（fixture + jq 断言），不触网。
- eww 视觉/动画、toggle、Esc、主题切换：手动验收清单。

## 不做（明确排除）

- 点窗外自动关闭（需透明全屏背板，复杂度不值，本期不做）。
- 卡片内翻页 / 上一词下一词（brainstorm 中 C 方案，未选）。
- 联网获取词性（数据已自带，纯本地拆分）。
- 保留旧「点击朗读 + notify-send」兼容路径（无历史包袱，直接重写）。
- 改动选词算法、轮换周期、bar 上 `text` 显示格式。
