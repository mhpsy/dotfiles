# Quickshell 天气灵动岛(全量重写)— 设计文档

- 日期:2026-05-19
- 状态:已确认,待实现
- 前身:eww 版 `docs/superpowers/specs/2026-05-18-weather-dynamic-island-design.md`(本设计取代其 UI 层,数据层复用)
- 执行方式:本 spec + 配套 plan 将由**全新的 Claude Code 会话**照着执行,必须自包含。

## 目标

用 **Quickshell 0.3.0(Qt6/QML)** 重写天气灵动岛,取代现有 eww 版。Quickshell 同时绘制**收起胶囊**和**展开卡片**,从 waybar 移除 `custom/weather`。动画用 QML 真动画(弹性流体形变 + 粒子/着色器氛围),解决 eww/GTK3 的动画天花板与死区问题。数据层完全复用现有 shell 脚本,不重写网络/缓存。

## 已确认决策(用户)

1. 范围:**全量重写**(功能与 eww 版齐平,非最小原型)。
2. **Quickshell 画一切**:收起胶囊 + 展开卡都由 Quickshell 画;从 waybar `modules-left` 删除 `custom/weather` 及其定义块。
3. 数据层复用 `~/.config/waybar/weather.sh` + `~/.config/waybar/weather-eww.sh`,两者**均不修改**。
4. eww 天气岛退役(文件保留以便回退,不删除);**绝不触碰 word-island**(那是 `~/.config/eww` 的独立 eww,用户自有)。
5. Quickshell 0.3.0 已安装(`/usr/bin/quickshell`、`/usr/bin/qs`)。

## 关键依赖(必须正确处理,否则天气停更)

`/tmp/waybar-openmeteo.json` 缓存当前由 waybar 的 `custom/weather` 每 900s 执行 `weather.sh`(其 `curl` 抓取 Open-Meteo)生成/刷新。`weather-eww.sh` 只**读**该缓存、不抓取(它以 `WEATHER_LIB_ONLY=1` source `weather.sh`,跳过抓取主体)。

**从 waybar 移除 `custom/weather` 后,必须由 Quickshell 接管抓取触发**:Quickshell 的刷新 `Process` 必须先运行 `weather.sh`(其副作用刷新缓存),再运行 `weather-eww.sh` 取结构化 JSON。即单条命令:

```
bash -c '~/.config/waybar/weather.sh >/dev/null 2>&1; ~/.config/waybar/weather-eww.sh'
```

`weather.sh` 自带"缓存新鲜则跳过 curl"逻辑,故此调用低成本且不重复联网。

## 架构与文件结构

dotfiles 仓库约定:`~/.config/<app>` 是指向 `/home/mhpsy/dotfiles/<app>` 的符号链接(waybar/eww/hypr 皆如此)。Quickshell 配置同样处理:

| 路径(仓库内) | 符号链接 | 职责 |
|---|---|---|
| `/home/mhpsy/dotfiles/quickshell/weather-island/shell.qml` | `~/.config/quickshell/weather-island/shell.qml` | 入口:layer-shell 窗口 + 状态机 + 组件装配 |
| `…/quickshell/weather-island/WeatherData.qml` | 同步 | 数据:Timer + Process 跑上面那条命令,JSON.parse,暴露属性 |
| `…/quickshell/weather-island/Pill.qml` | 同步 | 收起态胶囊(图标 + 温度) |
| `…/quickshell/weather-island/Card.qml` | 同步 | 展开态完整卡(hero/九宫格/逐时/三天) |
| `…/quickshell/weather-island/Ambient.qml` | 同步 | 按天气 cond 的氛围动效层 |
| `…/quickshell/weather-island/Theme.qml`(单例,可选) | 同步 | 颜色/字号常量集中 |

符号链接由 plan 创建:`ln -s /home/mhpsy/dotfiles/quickshell ~/.config/quickshell`(若 `~/.config/quickshell` 不存在)。

启动:`qs -c weather-island`(读 `~/.config/quickshell/weather-island/shell.qml`)。

## 组件设计

### WeatherData.qml
- `Timer { interval: 900000; running: true; repeat: true; triggeredOnStart: true; onTriggered: refresh() }`。
- `Process`(`import Quickshell.Io`)运行关键依赖那条命令;stdout 用 `StdioCollector`,完成后 `JSON.parse`。
- 暴露属性:`ok`(bool)、`city`、`current`(object: icon/temp/desc/feel/humidity/wind_dir/wind_speed/pressure/visibility/wind_deg/uv/sunrise/sunset/pop/precip/cond)、`hourly`(6 元素数组,每项 time/icon/temp)、`daily`(3 元素数组,每项 label/icon/min/max/desc)。解析失败保留上一次值并置 `ok=false`。
- 字段与 `weather-eww.sh` 当前输出严格一致(见前身 spec 的"数据契约")。

### shell.qml(窗口 + 状态)
- `import Quickshell`、`Quickshell.Wayland`、`QtQuick`。
- 顶层 `PanelWindow`(Quickshell 的 layer-shell 窗口):
  - 锚定屏幕顶部偏左(`anchors { top: true; left: true }`,`margins.left ≈ 120`,`margins.top: 0`)。x 用固定边距近似对齐 waybar 左侧原天气位置(同既往近似定位问题,可调常量)。
  - `exclusiveZone: 0`(不挤占)、layer 用 overlay、键盘焦点 None。
  - **隐式尺寸绑定内容**:`implicitWidth`/`implicitHeight` = 当前状态(收起=胶囊尺寸 / 展开=卡片尺寸)。Quickshell 将 layer 表面尺寸绑定到隐式尺寸 → 收起时表面就是胶囊大小,**天然无 eww 那种透明死区**(输入区=表面=可见内容)。
- 状态机:`property bool expanded: false`。`Pill` 始终在;`Card` 通过状态/可见性切换。点击胶囊 `expanded = !expanded`;指针移开卡片区域(`HoverHandler`/`MouseArea` + 短延时 `Timer`)→ `expanded = false`。

### Pill.qml / Card.qml
- Pill:圆角胶囊,`Text` 图标(Nerd Font)+ 温度。点击区 `MouseArea`。
- Card:与 eww 版齐平布局 —— hero(大图标 + 城市 + 大温度 + 描述 + 体感)、九宫格 3×3 chip(湿度/风向+风速/气压/能见度/风向°/UV/日出/日落/降水)、逐时 6 列(时/图标/温度)、三天 3 行(标签/图标/min~max/描述)。深色玻璃质感(半透明渐变背景 + 圆角 + 细描边),内容自适应高度。

### Ambient.qml(动效重点)
- 输入 `cond`(clear/clouds/fog/rain/snow/thunder)。
- QML 真动画(远超 GTK3):
  - rain:`import QtQuick.Particles` `ParticleSystem` 真斜向落雨。
  - snow:粒子缓降雪。
  - clear:`RadialGradient`/`ShaderEffect` 暖色光晕,`SequentialAnimation` 呼吸。
  - clouds/fog:横向漂移的柔和渐变层。
  - thunder:偶发高光闪 + 雨。
- 置于卡片背景与内容之间;`opacity` 适度,不挡可读性。

### 展开/收起动画
- QML `Behavior on implicitWidth/implicitHeight` + `SpringAnimation`(`spring`/`damping` 调出弹性回弹)实现"灵动岛"流体形变。
- 内容用 `states` + `transitions`:展开时卡片内容 `opacity` 0→1、轻微 `scale`/`y` 位移入场;收起反向。时长约 280–360ms,缓动 `Easing.OutBack` 或弹簧。

## 接入与退役

| 文件 | 改动 |
|---|---|
| `quickshell/weather-island/*.qml` | 新增(上表) |
| `~/.config/quickshell` 符号链接 | 新建指向 `dotfiles/quickshell`(若无) |
| `waybar/config.jsonc` | 从 `modules-left` 数组删除 `"custom/weather"`;删除其 `"custom/weather": { … }` 定义块 |
| `hypr/conf/autostart.conf` | 删除/替换天气 eww 行 `exec-once = eww --config ~/.config/waybar/eww daemon` → `exec-once = qs -c weather-island`(daily-word 那行不动) |
| `waybar/weather.sh`、`waybar/weather-eww.sh` | **不改**(复用) |
| eww 天气文件(`waybar/eww/eww.yuck` 的 weather-island defwindow、`waybar/weather-island-toggle.sh`) | 保留不删(回退用);不再被引用即可 |
| `~/.config/eww` word-island 全部 | **不碰** |

## 验证策略(无单测框架,用本会话已验证有效的方法)

1. 数据:命令行跑 `bash -c '~/.config/waybar/weather.sh >/dev/null 2>&1; ~/.config/waybar/weather-eww.sh' | jq .` 确认 JSON 正常(ok:true、字段齐全)。
2. QML 语法/加载:`qs -c weather-island` 启动,无 QML 报错(stderr 干净);`qs` 进程存活。
3. 渲染/几何/死区:`hyprctl layers -j` 查看 Quickshell 表面 —— 收起时尺寸≈胶囊(小),展开时≈卡片;`grim -g "<x,y wxh>" /tmp/x.png` 截图肉眼确认胶囊与完整卡片正常显示、动画到位。收起态表面小 → 无死区(对比 eww 的痛点)。
4. 交互:点击胶囊展开、再点/移开收起;`expanded` 状态切换正确。
5. 数据更新:确认 900s Timer + 启动即取;断网/无缓存时 `ok=false` 降级不崩(显示占位)。
6. 接管抓取:确认移除 waybar custom/weather 后,Quickshell 的刷新确实触发了 `weather.sh` 抓取(`/tmp/waybar-openmeteo.json` mtime 随刷新更新)。

## 已知风险 / 取舍

1. **Quickshell 0.3.0 API 名称需实现期核对**:`PanelWindow`/`WlrLayershell`/`Quickshell.Io` 的具体属性名随版本演进。实现计划首步必须查证本机 Quickshell 0.3.0 的实际 API(`qs` 自带文档/`--help`、`/usr/share/quickshell` 示例、或官方 0.3.0 文档),并据此校正 QML;不可照搬可能过时的属性名。
2. 浮层 x 为固定近似偏移,非像素级跟随 waybar 布局(同既往;胶囊由 Quickshell 自画,可调常量到视觉对齐)。
3. 图标:`weather-eww.sh` 输出 Nerd Font 私用区字形;若所选字体缺天气字形会显示占位符(与 eww 版同问题,纯外观)。需在 QML `Text.font.family` 指定含 weather glyph 的 Nerd Font;字体精修列为可选后续,不阻塞。
4. 抓取接管使天气更新依赖 Quickshell 存活;Quickshell 异常时天气停更(可接受:与 eww 版"daemon 挂则停"同级)。

## 非目标(YAGNI)

- 不用 Quickshell 替换整条 waybar(仅天气模块)。
- 不改 `weather.sh`/`weather-eww.sh`/Open-Meteo 抓取与缓存周期。
- 不删除 eww 天气文件(保留回退路径)。
- 不动 word-island、不重写其它 waybar 模块。
- 图标字体精修、主题与 matugen 联动 —— 可选后续,不在本次。
