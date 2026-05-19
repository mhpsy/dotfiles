# Quickshell 单词灵动岛(原生 quotes 胶囊 + QS 弹出卡)— 设计文档

- 日期:2026-05-19
- 状态:已确认,待实现
- 姊妹篇:`docs/superpowers/specs/2026-05-19-hybrid-weather-island-design.md`(已实现)。本设计**复用其混合架构与全部 Quickshell 本机经验**,对单词模块做同样的"原生 waybar 胶囊 + Quickshell 弹出卡"改造。
- 执行方式:本 spec + 配套 plan 由全新 Claude Code 会话照执行,必须自包含。

## 背景与动机

当前"每日单词"= waybar 原生 `custom/quotes` 胶囊(`quotes.sh`)+ eww `daily-word` 弹出岛(`word-island-toggle.sh` 翻 `word_reveal`)。与天气岛同样的痛点:eww 弹出层动画能力弱、且属待退役的旧栈。用户要求:把单词弹出卡改用 Quickshell 实现、动画更炫(阶梯入场 + 当前词辉光脉动)、按词性变背景、保留交互(点词切换 + 发音),并沿用刚验证成功的混合模式(收起态保持 waybar 原生胶囊以完美融入,Quickshell 只做点击弹出的富卡)。

## 已确认决策(用户)

1. **混合架构**(同天气岛):收起态 = waybar 原生 `custom/quotes` 胶囊;展开态 = Quickshell `qs -c word-island` 弹出卡。
2. **触发**:点原生胶囊;**Model A 纯切换**(点开、再点关),无 hover/自动收。机制 = 状态文件 `/tmp/qs-word-open`(新脚本 `qs-word-toggle.sh` 翻转 0/1)+ Quickshell `FileView` 监听。
3. **保留交互**:点今日列表某词 → 切到该词(`word-pick.sh <idx>`);🔊 发音按钮(`word-speak.sh`)。
4. **卡内动效**:卡 spring 弹入(复用天气岛 opacity+scale 弹性);今日 10 词逐条 fade+上滑**错峰入场**;**当前词辉光/呼吸脉动**。
5. **按词性(POS)变背景**:卡背景 tint 随当前词 `pos[0]` 变(低透明度,保证可读)。
6. **数据刷新**:卡 `open` 时每 ~1.5s 轮询 `word-popup.sh`(关闭不轮询,怠速零开销);点词/发音后立即重拉。
7. 复用所有数据脚本**不修改**(`quotes.sh`/`word-popup.sh`/`word-pick.sh`/`word-speak.sh`/`words-lib.sh`/`wordlist.json` 等)。
8. eww `daily-word` 退役:eww 文件 + `waybar/word-island-toggle.sh` **原样保留不动**(回退路径,不复用不覆盖);autostart 的 eww daily-word 行 → `qs -c word-island`。
9. **非目标**:不重构整条 waybar;不引 IPC/socket;不合并双 island 进程(各自 `qs -c <island>`,与天气岛一致);不动 weather-island/`weather*.sh`/`*.qml`(weather-island/);不动 word 数据脚本。

## 复用的数据脚本契约(不改,仅调用)

- `quotes.sh`:waybar `custom/quotes` 的 `exec`(每 2s),出 `{"text":"<word pos meaning>"}`;内部 10min 轮换,认手动 override。**不改**。
- `word-popup.sh`:卡数据源,出 `{"current":{word,pos:[..],phonetic,meaning,example},"today":[{word,meaning,current,idx}×10]}`,与胶囊同源(同 `wl_select`,认 override)。卡轮询此脚本。**不改**。
- `word-pick.sh <p>`:`p` = 今日列表 0 基位置(0..DAILY-1);写 override + 重置 10min 轮换计时 + 戳 wake FIFO。卡列表项点击 → `word-pick.sh <idx>`(idx 来自 `today[].idx`)。**不改**。
- `word-speak.sh`(无参):朗读当前词(认 override,无通知)。🔊 → `word-speak.sh`。**不改**。
- 状态文件由 `words-lib.sh` 管理(`~/.cache/waybar/{current-word,word-override,words.json,word-wake}`);卡不直接碰这些,只经上述脚本。

## 本机 Quickshell 0.3.0 经验(沿用,已在天气岛验证)

根 `ShellRoot`;窗口 `WlrLayershell`(`PanelWindow` `isCreatable:false`)直属性(`layer/keyboardFocus/namespace/color/exclusionMode/anchors/margins/implicitWidth/Height/mask`);**绝不把动画值绑到 `implicitWidth/Height`**(Wayland surface 抖动根因);`mask: Region { item: open ? card : null }`(关闭=null=全穿透零足迹);`Theme` 用 `pragma Singleton`+`import Quickshell`+`Singleton{}`、**无 qmldir**;`FileView`:`path` 属性、`text()` 是**异步方法**(`onFileChanged: reload()` 后在 `onTextChanged/onLoaded` 读)、缺文件 watch 不挂 → 加 ~400ms `Timer{reload()}` 兜底、`printErrors:false` 去 WARN 噪音;交互回调用 `Process`;`StdioCollector` 信号 `streamFinished`、读 `id`.text、`waitForEnd:true`;验证用 `qs`+`hyprctl`+`grim`+Read,**`pgrep -x qs`**(`pgrep -f` 自匹配)、STRICT 单实例。详见 `2026-05-19-hybrid-weather-island-*` 与项目内存 quickshell-machine-gotchas。

## 文件结构与改动

| 文件 | 改动 |
|---|---|
| `waybar/qs-word-toggle.sh` | **新增**(约 5 行):翻转 `/tmp/qs-word-open`(`1`↔`0`,缺失/非`1`→`1`),`chmod +x` |
| `quickshell/word-island/shell.qml` | **新增**:`ShellRoot{WlrLayershell{}}` 固定 surface + `FileView`(`/tmp/qs-word-open`)+ `WordData` + `WordCard`;套天气岛 shell.qml 范式 |
| `quickshell/word-island/WordData.qml` | **新增**:`open` 时 Timer(~1.5s)跑 `word-popup.sh`,`JSON.parse`,暴露 `ok/current/today`;`refresh()` 立即重拉 |
| `quickshell/word-island/WordCard.qml` | **新增**:hero+今日列表+🔊;交互(`word-pick.sh`/`word-speak.sh` via `Process`)+ 阶梯入场/辉光脉动/POS 背景 |
| `quickshell/word-island/Theme.qml` | **新增**:从 `quickshell/weather-island/Theme.qml` 复制(各岛自有,独立);加 `posTint` 映射 |
| `waybar/config.jsonc` | **改 1 处**:`custom/quotes` 的 `on-click` `~/.config/waybar/word-island-toggle.sh` → `~/.config/waybar/qs-word-toggle.sh`(其余字段不动) |
| `hypr/conf/autostart.conf` | **改 1 行**:`exec-once = eww --config ~/.config/eww open daily-word` → `exec-once = qs -c word-island`(`qs -c weather-island` 行保留不动) |
| eww 文件 / `word-island-toggle.sh` / `word*.sh` / `quotes.sh` / `words-lib.sh` / `wordlist.json` / weather-island/* | **不动** |

经符号链接 `~/.config/quickshell → dotfiles/quickshell`(已存在)生效。

## 组件设计

### `qs-word-toggle.sh`
与 `qs-weather-toggle.sh` 同形:`f=/tmp/qs-word-open; [ "$(cat $f 2>/dev/null)" = 1 ] && printf 0 >$f || printf 1 >$f`。`chmod +x`。**不复用/不覆盖** `word-island-toggle.sh`(eww 回退保留)。

### `shell.qml`(套天气岛范式)
`ShellRoot{WlrLayershell{ id:win; anchors{top;left}; margins.left≈近似x; margins.top≈40; exclusionMode:ExclusionMode.Ignore; color:"transparent"; layer:WlrLayer.Overlay; keyboardFocus:WlrKeyboardFocus.None; namespace:"qs-word-island"; implicitWidth/Height = WordCard 稳定隐式尺寸(无动画); mask:Region{item:win.open?card:null} }}`。`FileView{ path:"/tmp/qs-word-open"; watchChanges:true; printErrors:false; onFileChanged:reload(); onTextChanged/onLoaded: win.open=(text().trim()==="1") }` + ~400ms `Timer{reload()}` 兜底。`WordData{id:wd}` + `WordCard{id:card; wx-equivalent:wd; visible:opacity>0.01; opacity:win.open?1:0; scale:win.open?1:0.96; transformOrigin:Item.Top; Behavior opacity NumberAnimation 200 OutCubic; Behavior scale SpringAnimation spring4 damping0.5 }`。namespace 必须是 `qs-word-island`(与 weather 区分)。

### `WordData.qml`
`property bool active`(绑卡 open/visible);`Timer{ running:active; repeat:true; interval:1500; triggeredOnStart:true; onTriggered: proc.running=true }`;`Process{ id:proc; command:["bash","-c","~/.config/waybar/word-popup.sh"]; stdout:StdioCollector{ id:o; waitForEnd:true; onStreamFinished:{ try{ j=JSON.parse(o.text); ok=j.ok!==false; current=j.current||({}); today=j.today||[] }catch(e){ ok=false } } } }`;`function refresh(){ if(!proc.running) proc.running=true }`。关闭(active=false)→ Timer 停 → 怠速零开销。

### `WordCard.qml`
- hero:大词(`current.word`)+ `pos`(join)+ 音标(`current.phonetic`)+ 释义(`current.meaning`)+ 例句(`current.example`)+ 🔊 按钮(MouseArea → `Process` 跑 `~/.config/waybar/word-speak.sh`,完成后 `wd.refresh()`)。
- 今日列表:`Repeater{ model: wd.today }`,每项显示 `word`+`meaning`,`current` 项高亮(辉光脉动);项 MouseArea → `Process` 跑 `bash -c '~/.config/waybar/word-pick.sh <modelData.idx>'`,完成后 `wd.refresh()`。
- `clip:true`;隐式尺寸稳定(供 shell 固定 surface 绑定,不随动画/数据每帧变;数据变更导致的尺寸变化是低频、可接受)。

### `Theme.qml`(word-island 自有副本)
复制 weather-island 的(`pragma Singleton`+`Singleton{}`、`uiFont`/`glyphFont:"Font Awesome 7 Free"`/`glyphStyle:"Solid"`/颜色/`radius`,`#AARRGGBB` 注释)。新增:
```
readonly property var posTint: ({
  "n.":"#3360a5fa", "v.":"#33f0a050", "vt.":"#33f0a050", "vi.":"#33f0a050",
  "adj.":"#3340c0a0", "a.":"#3340c0a0", "adv.":"#33a070e0", "ad.":"#33a070e0"
})  // 低透明度 tint;未列词性 → "" (用默认 cardBg);具体色实现期可微调
readonly property color posTintDefault: "#00000000"
```

## 动效(创意重点)

1. **卡弹入**:复用天气岛——固定 surface 内 `opacity 0→1`(NumberAnimation 200 OutCubic)+ `scale 0.96→1`(SpringAnimation spring 4.0 damping 0.5,有界)。
2. **今日列表错峰入场**:`open` 变 true 时,Repeater 各项 `opacity 0→1` + `y` 轻微上滑入位,**逐项延时递增**(如 `delay = index * 35ms`,可用 per-delegate `NumberAnimation` + `PauseAnimation` 或 `SequentialAnimation`,卡关闭复位)。
3. **当前词辉光脉动**:当前项加循环 `SequentialAnimation`(opacity 或一个 glow `Rectangle`/边框透明度 0.5↔1.0,~1600ms InOutSine),**仅卡可见时跑、关闭停**(套 Ambient 怠速门控:绑 `running: card.visible`)。
4. **POS 背景过渡**:卡背景 = 深色玻璃底 + 一层 `posTint[current.pos[0]]`(空则透明);`current.pos` 变时 `ColorAnimation`(~300ms)平滑过渡。tint 透明度低,不压文字可读性(沿用天气岛可读性教训)。

## 数据流 / 交互 / 错误降级

`quotes.sh`(2s,原生胶囊文字,10min 轮换,认 override)→ 点胶囊 → `qs-word-toggle.sh` 翻 `/tmp/qs-word-open` → `FileView` → 卡显隐。卡 open:`WordData` 每 1.5s 跑 `word-popup.sh`(与胶囊同源 → 一致)。点列表词 → `word-pick.sh idx`(写 override + 重置轮换)→ `wd.refresh()` 立即重拉 → 卡与胶囊(下个 2s tick)都切到该词。🔊 → `word-speak.sh`(读当前词)→ `wd.refresh()`。降级:状态文件缺/坏 → 关;`word-popup.sh` 失败 → `ok=false`,卡显占位、保留上次;**qs 守护挂掉 → 原生 `custom/quotes` 胶囊照常显示/轮换单词**(bar 不失单词,比 eww 版严格更健壮)。

## 验证策略(无单测,沿用天气岛已证方法)

STRICT 单实例 `pgrep -x qs`。① `word-popup.sh | jq` 字段正常。② `qs -c word-island` 无 QML 错(Qt 版本 WARN 可接受);恰好 1 个 `qs-word-island` 表面。③ 关闭态:`grim` 截图无浮层、bar 全可点、`mask` 空穿透。④ 翻 `/tmp/qs-word-open` → 卡在 bar 下方弹出,真实词/今日列表/POS 背景/阶梯入场/当前词脉动,文字可读(Read 截图)。⑤ 交互:跑 `word-pick.sh <idx>` 等价或点卡内词 → 卡与原生胶囊(≤2s)同步切到该词;🔊 出声(`WORDS_DRY_RUN=1` 可干跑校验选词)。⑥ 无抖动:多次开关 surface 几何恒定。⑦ 回归:weather-island 仍工作;eww 回退文件/`word-island-toggle.sh`/`word*.sh`/`quotes.sh`/`words-lib.sh`/`wordlist.json` 未改;`qs -c weather-island` autostart 行未动;qs 挂掉胶囊仍显词。⑧ `git diff` 仅本设计列出文件。

## 已知风险 / 取舍

1. `FileView` 异步/缺文件 watch 问题已知,沿用天气岛方案(`reload()`+`onTextChanged/onLoaded`+400ms Timer+`printErrors:false`)。
2. 弹出卡 `margins.left` 近似常量;瞬态下拉面板可接受(同天气岛)。
3. `Theme.qml` 复制到 word-island(轻微重复),换取各岛配置独立、避免跨配置单例的 import 复杂度(依 gotchas 内存)。
4. 轮询间隔 1.5s:轮换最多 ~1.5s 延迟反映在已打开的卡上(人眼无感);点词经 `refresh()` 立即生效。
5. autostart 把 eww daily-word 行换成 `qs -c word-island`:本项目明确退役 eww 单词岛(eww 文件留作回退);此改动是本项目核心,非误触。
6. Qt 6.11.0-vs-6.11.1 构建 WARN 为环境既有,非缺陷,不阻塞。
7. 双 island 各自 `qs` 进程(weather-island + word-island);两个常驻守护,均默认隐藏 + 关闭态空 mask + 动画门控,怠速开销可忽略。后续若要合并为单进程是独立优化(YAGNI,不在本次)。

## 非目标(YAGNI)

- 不重构整条 waybar(独立未来项目)。
- 不引 IPC/socket(状态文件方案足够)。
- 不改任何 `word*.sh`/`quotes.sh`/`words-lib.sh`/`wordlist.json`/抓取与缓存。
- 不删 eww 单词岛回退文件、不复用/覆盖 `word-island-toggle.sh`。
- 不动 weather-island 任何文件 / `qs -c weather-island` autostart 行。
- 不合并 weather/word 两 island 进程。

## 相对天气岛的复用与差异

- **复用**:混合架构、shell.qml 固定 surface + state-mask 范式、`FileView`/`Process` 用法、Theme 单例形态、`qs-*-toggle.sh` 形态、全部 Quickshell 本机经验([[quickshell-machine-gotchas]])、验证方法、怠速门控。
- **差异/新增**:数据源 `word-popup.sh`(非 weather);`WordData`/`WordCard` 新组件;**交互回调**(`word-pick.sh`/`word-speak.sh` via `Process` + refresh);**阶梯入场 + 当前词辉光脉动**动效;**POS→背景 tint** 映射 + ColorAnimation;改的是 `custom/quotes` on-click(非 custom/weather)与 autostart 的 eww daily-word 行(非 weather 行)。
