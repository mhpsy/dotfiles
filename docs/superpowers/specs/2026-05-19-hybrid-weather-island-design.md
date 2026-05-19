# 混合天气岛(waybar 原生胶囊 + Quickshell 点击弹出卡)— 设计文档

- 日期:2026-05-19
- 状态:已确认,待实现
- 前身:`docs/superpowers/specs/2026-05-19-quickshell-weather-island-design.md`(全量 Quickshell 版)
- 关系:**本设计取代前身的 UI/接入层决策**,复用其数据层与卡片/氛围实现成果。
- 执行方式:本 spec + 配套 plan 由全新 Claude Code 会话照执行,必须自包含。

## 背景与动机

前身设计让 Quickshell 独立画"收起胶囊 + 展开卡"并从 waybar 移除 `custom/weather`。实现完成并通过逐任务复审后,真机交互暴露一个**架构性硬限制**:Quickshell 是独立的 Wayland layer-shell 进程,其窗口只能**悬浮**在 waybar 上层,**无法嵌入 waybar 那一排原生模块**。结果是收起态胶囊视觉上"不融入、悬浮、突兀",再怎么调 `margins`/`exclusionMode` 也只是治标。期间还发现:把会弹簧动画的 `stack` 尺寸绑到 `WlrLayershell.implicitWidth/Height` 会让真实 Wayland surface 每帧 reconfigure、欠阻尼弹簧下冲到 ~1px,产生点击时的剧烈抖动(已用"固定 surface"修复并验证)。

用户据此决策改走**混合方案**:收起态回归 waybar 原生模块(天生完美融入),Quickshell 只负责点击后弹出的富交互详情卡(瞬态弹层,不需要嵌进 bar)。

## 已确认决策(用户)

1. **混合架构**:收起态 = waybar 原生 `custom/weather` 模块;展开态 = Quickshell 弹出卡。
2. **触发**:点击 waybar 原生胶囊;**纯切换 Model A**——点一下开,再点一下关。**无 hover、无自动收起**。
3. **触发机制 = 状态文件 + FileView**(方案 A):waybar `on-click` 跑一个新的小脚本翻转 `/tmp/qs-weather-open`(`0`/`1`);Quickshell 用 `FileView` 监听该文件决定显隐。选此是为把 API 不确定性降到最低(本项目反复踩到"假设 API ≠ 本机 API")。
4. **复用前身成果**:`Theme.qml`、`WeatherData.qml`、`Card.qml`、`Ambient.qml` 基本原样保留。
5. **删除** `Pill.qml` 及整套 hover/自动收起状态机(纯切换不需要)。
6. eww 天气回退文件(含 `waybar/weather-island-toggle.sh`、`waybar/eww/` 的 weather-island)**保留不动、不复用、不覆盖**;**绝不触碰 word-island**(`~/.config/eww`、autostart 的 `daily-word` 行)。
7. 不修改 `weather.sh` / `weather-eww.sh`(复用)。
8. **非目标**:不重构整条 waybar(那是另一个独立未来项目,见调研报告;本次明确排除)。

## 架构

| 层 | 实现 | 说明 |
|---|---|---|
| 收起态胶囊 | waybar `custom/weather` 原生模块 | `exec: ~/.config/waybar/weather.sh`(不改)。原生渲染 → 完美融入、完美对齐、零悬浮 |
| 展开态详情卡 | Quickshell `qs -c weather-island` 守护进程 | 默认隐藏;切换打开时在 bar 下方下拉显示 `Card`(+`Ambient`) |
| 触发桥 | `/tmp/qs-weather-open` 状态文件 | waybar on-click 翻转;Quickshell `FileView` 监听 |

附带架构收益:`custom/weather` 回归后,**waybar 重新每 900s 执行 `weather.sh`**,`/tmp/waybar-openmeteo.json` 缓存重新由 waybar 驱动 —— 前身设计的"抓取接管"风险彻底消失,无需 Quickshell 触发抓取。

## 文件结构与改动

仓库 `/home/mhpsy/dotfiles`;`~/.config/<app>` 为指向仓库的符号链接(`~/.config/quickshell → dotfiles/quickshell` 已在前身建立)。

| 文件 | 改动 |
|---|---|
| `waybar/config.jsonc` | **恢复** `custom/weather`:加回 `modules-left` 原槽位(`custom/date` 与 `custom/sp-entertainment` 之间);加回定义块,`exec: ~/.config/waybar/weather.sh`、`return-type: json`、`interval: 900`、`tooltip: false`、`on-click: ~/.config/waybar/qs-weather-toggle.sh` |
| `waybar/qs-weather-toggle.sh` | **新增**(约 3 行):若 `/tmp/qs-weather-open` 内容为 `1` 则写 `0`,否则写 `1`(缺失视为关闭→写 `1`)。`chmod +x` |
| `quickshell/weather-island/shell.qml` | **重写(大幅变小)**:`ShellRoot { WlrLayershell {} }` + `FileView` 监听状态文件 + `WeatherData` + `Card`(含 `Ambient`)。固定 surface;`open` 驱动 Card 显隐;`mask` 开=card、关=空 |
| `quickshell/weather-island/Pill.qml` | **删除**(`git rm`),不再使用 |
| `quickshell/weather-island/Card.qml` | 仅摘除已无用的 hover 钩子(`cardHover` 等),最小改动;其余(hero/九宫格/逐时/三天、`clip`、gradient、`Ambient` 接入)不变 |
| `quickshell/weather-island/Theme.qml` / `WeatherData.qml` / `Ambient.qml` | **原样保留** |
| `hypr/conf/autostart.conf` | `exec-once = qs -c weather-island` 保持不变;`daily-word` 行绝不动 |
| eww 天气回退文件、`weather.sh`、`weather-eww.sh` | **不动** |

## 组件设计

### waybar `custom/weather`(收起态)
恢复前身 Task 7 删除的那段定义块,唯一改动是 `on-click` 指向新的 `qs-weather-toggle.sh`(原 eww 版指向 `weather-island-toggle.sh`)。`tooltip: false`(详情交由 Quickshell 卡,不要 GTK tooltip)。其余字段保持原值。

### `qs-weather-toggle.sh`(触发)
最小实现意图:
```sh
f=/tmp/qs-weather-open
[ "$(cat "$f" 2>/dev/null)" = "1" ] && echo 0 > "$f" || echo 1 > "$f"
```
(实现期可按本机 shell 习惯微调;契约:翻转 `/tmp/qs-weather-open` 在 `0`/`1` 间,文件缺失/非 `1` 视为当前关闭、本次写 `1`。)

### `shell.qml`(Quickshell 弹出卡窗口)
- 沿用前身已查证的本机 API:根 `ShellRoot`;窗口 `WlrLayershell`(`PanelWindow` 在本机 `isCreatable:false`),直属性 `layer: WlrLayer.Overlay`、`keyboardFocus: WlrKeyboardFocus.None`、`namespace: "qs-weather-island"`、`color: "transparent"`、`exclusionMode: ExclusionMode.Ignore`。
- **固定 surface(关键,杜绝抖动)**:`implicitWidth/implicitHeight` 绑定 `Card` 的稳定隐式尺寸(常量级,仅随天气数据刷新偶变,**绝不做 surface 动画、绝不加 Behavior**)。
- `FileView`(`Quickshell.Io`)监听 `/tmp/qs-weather-open`,暴露 `property bool open`(内容 `== "1"`)。**FileView 的精确 API(属性名/变更信号/读取方式)须在本机查证**(`ls /usr/lib/qt6/qml/Quickshell/Io`、grep qmltypes),与本机一致为准;退路:`Timer` 周期 `Process cat` 读该文件。
- `WeatherData { id: wx }` 保留(读 `weather-eww.sh`;Timer 周期刷新;打开时数据已就绪)。
- `Card { wx: wx; visible: <open 时可见>; opacity/scale 过渡 }` —— 复用前身抖动修复的做法:动画只作用于 Card 的 opacity/scale(纯视觉、在固定透明 surface 内、`clip`),开:`opacity 0→1` `OutCubic`、`scale 0.96→1` 轻弹(有界,`transformOrigin: Item.Top`);关:反向。
- **`mask`**:`open` 时 `Region { item: card }`(卡片可交互);**关闭时输入区为空**(无 `Region`/零尺寸 Region)→ 关闭态整个透明 surface 100% 穿透点击、零死区、零可见物。
- **下拉定位**:`anchors { top: true; left: true }`,`margins.top ≈ bar 高(约 40)` 使卡悬于 bar 正下方;`margins.left ≈ 近似 x`(常量,目视靠近天气模块即可)。该近似偏移**可接受**:卡仅在打开时瞬态可见,且本就是个下拉面板,轻微偏移读起来正常(不再"假装嵌在 bar 里")。
- 删除全部 hover/`evalCollapse`/`collapseTimer`/`pillHover`/`cardHover`/双 `Connections` 逻辑(Model A 纯切换不需要)。

### `Card.qml` / `Ambient.qml` / `Theme.qml` / `WeatherData.qml`
原样复用。仅 `Card.qml` 摘掉前身为自动收起加的 `HoverHandler { id: cardHover }`(及 shell 侧对应引用已随 shell.qml 重写移除)。`Ambient` 的"怠速门控"(随 Card 可见性停粒子/动画)保留有效:关闭态 Card 不可见 → 粒子/动画停 → 零怠速开销。

## 数据流

1. waybar 每 900s 跑 `weather.sh` → 原生胶囊显示图标+温度 + 刷新 `/tmp/waybar-openmeteo.json`。
2. 用户点原生胶囊 → waybar `on-click` 跑 `qs-weather-toggle.sh` → 翻转 `/tmp/qs-weather-open`。
3. Quickshell `FileView` 感知变更 → `open` 翻转 → `Card` 淡入/淡出;`WeatherData` 读 `weather-eww.sh`(读缓存)提供数据。
4. 再点 → 翻回 → 卡隐藏、surface 输入区清空。

## 错误处理 / 降级

- 状态文件缺失/乱码 → 视为关闭(安全默认:卡隐藏)。
- `weather-eww.sh` 失败 / `ok:false` → Card 占位符(前身 `WeatherData`/`Card` 已具备此降级)。
- **Quickshell 守护进程异常 → 点击无反应,但 waybar 原生胶囊照常显示天气、缓存照常更新**——bar 永不失去天气。比前身设计**严格更健壮**(前身:qs 挂 = 全部天气消失)。

## 验证策略(无单测框架,沿用本会话已证有效方法)

1. 数据:`bash -c '~/.config/waybar/weather.sh >/dev/null 2>&1; ~/.config/waybar/weather-eww.sh' | jq .` 正常(`ok:true`、字段齐)。
2. waybar:重启 waybar,左侧 `custom/weather` 原生胶囊渲染、与相邻模块对齐(截图肉眼确认融入);`config.jsonc` 合法 JSONC。
3. 触发:`qs-weather-toggle.sh` 反复执行,`/tmp/qs-weather-open` 在 `0`/`1` 正确翻转。
4. 显隐:点击(或直接跑 toggle 脚本)→ `hyprctl layers -j` 看 `qs-weather-island` 表面;打开态卡在 bar 下方、`grim` 截图肉眼确认真实数据+氛围+可读;关闭态**输入区为空/窗口无交互足迹**、`grim` 截图无悬浮物、bar 全可点。
5. 无抖动:结构上不可能(无 surface 动画);可用程序翻转状态文件多次,`hyprctl` 观察 surface 几何在开/关全程**恒定**(或关闭态无表面)。
6. 回归:word-island eww 仍运行/未改;`weather.sh`/`weather-eww.sh`/eww 回退文件未改;缓存仍由 waybar 更新;`git diff` 仅涉及本设计列出的文件。
7. Quickshell 0.3.0 API 不确定项(本次主要为 `FileView`)实现期本机查证,与本机一致为准并记录;每次跑 `qs` 看 stderr 即时暴露。STRICT 单实例纪律:`pgrep -x qs`(`pgrep -f 'qs -c weather-island'` 会自匹配 shell 包装)。

## 已知风险 / 取舍

1. `FileView` 的本机 API 需实现首步查证(属性名/信号);退路:`Timer`+`Process cat` 轮询状态文件(低频,开销可忽略)。
2. 弹出卡 `margins.left` 仍是近似常量;因卡为瞬态下拉面板,偏移在体验上可接受(对比前身:作为"常驻伪 bar 模块"时偏移不可接受)。
3. 守护进程常驻但默认隐藏 + 关闭态空输入区,开销可忽略;`Ambient` 怠速门控保证关闭态零粒子开销。
4. Qt 6.11.0-vs-6.11.1 构建 WARN 为环境既有问题(非本设计缺陷),不阻塞。

## 非目标(YAGNI)

- 不重构整条 waybar(独立未来项目,见 Quickshell waybar 重构调研报告;本次明确排除)。
- 不引入 IPC/socket(对开/关切换属过度设计;已选状态文件方案)。
- 不改 `weather.sh`/`weather-eww.sh`/抓取与缓存周期。
- 不删 eww 天气回退文件、不动 word-island、不动其它 waybar 模块。
- 不保留 Quickshell 收起胶囊与展开/收起弹簧形变(改由 waybar 原生胶囊 + 纯切换替代)。

## 相对前身的复用与变更小结

- **复用(不改或极小改)**:`Theme.qml`、`WeatherData.qml`、`Ambient.qml`、`Card.qml`(摘 hover);本机 API 查证成果(WlrLayershell 直属性、Singleton 无 qmldir、StdioCollector `streamFinished`、`ExclusionMode.Ignore`、`Region`/`mask`);抖动根因教训(**绝不把动画值绑到 Wayland surface 尺寸**)。
- **变更**:`shell.qml` 重写为"FileView 驱动的开/关弹出卡";删 `Pill.qml`;`waybar/config.jsonc` 恢复 `custom/weather`(on-click 指向新 toggle 脚本);新增 `qs-weather-toggle.sh`。
- **撤销前身决策**:不再"从 waybar 删除 custom/weather";不再由 Quickshell 画收起胶囊;不再需要 Quickshell 接管抓取。
