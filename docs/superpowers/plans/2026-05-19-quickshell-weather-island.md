# Quickshell 天气灵动岛(全量重写)Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 Quickshell 0.3.0 (Qt6/QML) 重写天气灵动岛(收起胶囊 + 弹性流体展开卡 + 粒子氛围),取代 eww 版,数据层复用现有 shell 脚本。

**Architecture:** 一个 Quickshell layer-shell `PanelWindow`,`mask` 把输入区限制为可见内容(收起即胶囊大小,无死区)。`WeatherData` 用 `Process` 跑 `weather.sh`(刷新缓存)+ `weather-eww.sh`(出 JSON)并 `JSON.parse`。`Pill`/`Card`/`Ambient` 组件;`SpringAnimation` + states/transitions 做动画。从 waybar 移除 custom/weather,hypr 自启动改 `qs -c weather-island`。

**Tech Stack:** Quickshell 0.3.0、Qt6 QML(QtQuick / QtQuick.Particles / Quickshell / Quickshell.Wayland / Quickshell.Io)、bash 数据脚本(复用,不改)。

关联 spec:`docs/superpowers/specs/2026-05-19-quickshell-weather-island-design.md`

---

## 重要执行须知(全程适用)

- **本机 = 用户的活跃 Hyprland 会话**(`WAYLAND_DISPLAY` 已设、`hyprctl` 可用)。验证用本会话已证实有效的方法:`qs -c weather-island`(前台/后台跑)、`hyprctl layers -j`(看 layer 表面 namespace=`qs-weather-island` 的 x/y/w/h)、`grim -g "X,Y WxH" /tmp/f.png` 截图后用 Read 工具看图。**没有单测框架,验证=跑起来+看图+查 hyprctl/stderr。**
- **Quickshell 0.3.0 API 名称可能与下方代码略有出入**(工具在演进)。**Task 1 必须先在本机查证真实 API**,后续每个任务的 QML 若 `qs` 报"unknown property/type/import"等错,以 Task 1 查到的本机 API 为准最小化修正,并在该任务记录改了什么。给出的 QML 是最佳已知写法,不是不可改的教条。
- dotfiles 仓库:`/home/mhpsy/dotfiles`,`~/.config/<app>` 是指向 `dotfiles/<app>` 的符号链接。当前分支非 main(`git branch --show-current` 确认;在该分支提交)。提交只 `git add` 明确文件,**不要 `git add -A`**;提交信息结尾带 `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`。
- **绝不触碰** `~/.config/eww`(word-island,用户自有)、`waybar/word-island-toggle.sh`、`hypr/conf/autostart.conf` 里的 `daily-word` 行。
- eww 天气文件(`waybar/eww/eww.yuck` 的 weather-island、`waybar/weather-island-toggle.sh`)**保留不删**(回退路径),仅解除引用。
- 每次跑 `qs` 前先 `pkill -f 'qs -c weather-island' 2>/dev/null; sleep 0.3`;任务结尾如启动了 qs 用于验证,**保持它运行**到 Task 8(最终交付要它活着),但每个任务重启它以加载新代码。

## File Structure

| 文件 | 责任 |
|---|---|
| `quickshell/weather-island/shell.qml` | 入口:root + `PanelWindow`(layer/锚点/mask)+ 状态机 `expanded` + 组件装配 |
| `quickshell/weather-island/WeatherData.qml` | `Timer`+`Process` 跑数据命令,`JSON.parse`,暴露 ok/city/current/hourly/daily |
| `quickshell/weather-island/Theme.qml` | 颜色/字号/字体常量(`pragma Singleton`) |
| `quickshell/weather-island/Pill.qml` | 收起胶囊(图标+温度)+ 点击区 |
| `quickshell/weather-island/Card.qml` | 展开卡:hero/九宫格/逐时/三天 |
| `quickshell/weather-island/Ambient.qml` | 按 cond 的粒子/渐变氛围层 |
| `quickshell/weather-island/qmldir` | 注册 Theme 单例(若 Task 1 确认需要) |
| `waybar/config.jsonc` | 删除 `custom/weather`(modules-left 数组项 + 定义块) |
| `hypr/conf/autostart.conf` | 天气 eww 行 → `exec-once = qs -c weather-island` |

仓库内建在 `/home/mhpsy/dotfiles/quickshell/weather-island/`;通过符号链接 `~/.config/quickshell → dotfiles/quickshell` 生效(Task 1 建链)。

---

## Task 1: 环境 + Quickshell 0.3.0 API 查证 + 配置链接 + "Hello 窗口"

**Files:**
- Create: `/home/mhpsy/dotfiles/quickshell/weather-island/shell.qml`
- Create symlink: `~/.config/quickshell` → `/home/mhpsy/dotfiles/quickshell`

- [ ] **Step 1: 查证本机 Quickshell API(必须先做,产出后续依据)**

Run 并阅读输出,记录到本任务笔记:
```bash
qs --version
qs --help 2>&1 | sed -n '1,60p'
# 文档/示例位置
ls -R /usr/share/quickshell 2>/dev/null | head -40
ls /usr/share/doc/quickshell 2>/dev/null
# 已装 QML 模块
ls /usr/lib/qt6/qml/Quickshell 2>/dev/null
ls /usr/lib/qt6/qml/Quickshell/Wayland 2>/dev/null
ls /usr/lib/qt6/qml/Quickshell/Io 2>/dev/null
qmldir=$(find /usr/lib/qt6/qml/Quickshell -name qmldir 2>/dev/null); echo "$qmldir"
grep -rEi 'PanelWindow|WlrLayershell|exclusiveZone|StdioCollector|SplitParser|ShellRoot|WlrLayer|keyboardFocus|class Region|mask' /usr/lib/qt6/qml/Quickshell 2>/dev/null | grep -i qmldir -v | head -40
```
确认并记录:① shell.qml 根元素(`ShellRoot` 还是其它);② `PanelWindow` 的导入与属性(`anchors`/`margins`/`exclusiveZone`/`implicitWidth`/`color`/`mask`);③ layer/键盘焦点设法(`WlrLayershell.layer` 枚举名、`WlrLayer.Overlay`、`WlrKeyboardFocus.None` 是否如此命名);④ `Quickshell.Io` 的 `Process`/`StdioCollector` 写法;⑤ 输入区/`Region`/`mask` 的实际属性名。**若与本计划代码不一致,以本机为准,后续任务遇到 import/属性报错即按此修正。**

- [ ] **Step 2: 建符号链接**

```bash
[ -e ~/.config/quickshell ] || ln -s /home/mhpsy/dotfiles/quickshell ~/.config/quickshell
mkdir -p /home/mhpsy/dotfiles/quickshell/weather-island
ls -la ~/.config/quickshell && ls -la ~/.config/quickshell/weather-island
```
Expected: `~/.config/quickshell` 是指向 `dotfiles/quickshell` 的符号链接;子目录存在。
(若 `~/.config/quickshell` 已存在且非该链接 → STOP,报告 BLOCKED,不要覆盖用户已有配置。)

- [ ] **Step 3: 写最小 "Hello 窗口" shell.qml**

Create `/home/mhpsy/dotfiles/quickshell/weather-island/shell.qml`:
```qml
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    PanelWindow {
        id: win
        anchors { top: true; left: true }
        margins.left: 120
        margins.top: 0
        exclusiveZone: 0
        color: "transparent"
        implicitWidth: box.width
        implicitHeight: box.height
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "qs-weather-island"

        Rectangle {
            id: box
            width: 220; height: 60
            radius: 16
            color: "#cc1020ff"
            Text {
                anchors.centerIn: parent
                text: "QS WEATHER OK"
                color: "white"; font.pixelSize: 18
            }
        }
    }
}
```
(若 Step 1 查到根元素不是 `ShellRoot`,或 layer 枚举名不同,据实修正。)

- [ ] **Step 4: 跑起来并截图验证窗口可见**

```bash
pkill -f 'qs -c weather-island' 2>/dev/null; sleep 0.3
( qs -c weather-island >/tmp/qs.log 2>&1 & ) ; sleep 2
echo "--- qs.log ---"; cat /tmp/qs.log
hyprctl layers -j | python3 -c 'import json,sys
d=json.load(sys.stdin)
for m,i in d.items():
 for lv,a in i.get("levels",{}).items():
  for s in a:
   if "qs-weather" in (s.get("namespace") or ""): print("SURF",s["x"],s["y"],s["w"],s["h"])'
G=$(hyprctl layers -j | python3 -c 'import json,sys
d=json.load(sys.stdin)
for m,i in d.items():
 for lv,a in i.get("levels",{}).items():
  for s in a:
   if "qs-weather" in (s.get("namespace") or ""): print("%d,%d %dx%d"%(s["x"],s["y"],s["w"],s["h"]))')
grim -g "${G:-120,0 220x60}" /tmp/t1.png && echo "shot:/tmp/t1.png"
```
Expected: `qs.log` 无 QML error;`hyprctl` 列出 `qs-weather-island` 表面,尺寸约 `220x60`;`/tmp/t1.png`(用 Read 看)是一个蓝紫色圆角块写着 "QS WEATHER OK"。
- 若 qs.log 报 import/类型/属性错 → 按 Step 1 查到的本机 API 修正 shell.qml,重跑本步,直至窗口可见。这是后续一切的地基,**必须**先肉眼确认可见再继续。
- 纯无显示错误不适用(本机有显示)。

- [ ] **Step 5: 提交**

```bash
cd /home/mhpsy/dotfiles
git add quickshell/weather-island/shell.qml
git commit -m "feat(quickshell): weather-island hello layer-shell window

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```
(符号链接是本机环境、不在仓库内,无需提交。)

---

## Task 2: WeatherData.qml — 复用脚本取 JSON

**Files:**
- Create: `/home/mhpsy/dotfiles/quickshell/weather-island/WeatherData.qml`
- Modify: `/home/mhpsy/dotfiles/quickshell/weather-island/shell.qml`

- [ ] **Step 1: 先验证数据命令本身(这是"失败测试"的等价物)**

```bash
bash -c '~/.config/waybar/weather.sh >/dev/null 2>&1; ~/.config/waybar/weather-eww.sh' | jq '{ok,city,t:.current.temp,c:.current.cond,h:(.hourly|length),d:(.daily|length)}'
```
Expected: `ok:true`,city 非空,temp 数字串,cond ∈ clear/clouds/fog/rain/snow/thunder,h=6,d=3。若不 ok → 先 `ls -l /tmp/waybar-openmeteo.json`、单独跑 `~/.config/waybar/weather.sh` 排查(不要改这两个脚本)。

- [ ] **Step 2: 写 WeatherData.qml**

Create `/home/mhpsy/dotfiles/quickshell/weather-island/WeatherData.qml`:
```qml
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property bool ok: false
    property string city: "--"
    property var current: ({})
    property var hourly: []
    property var daily: []
    property string lastError: ""

    function refresh() { proc.running = true }

    Process {
        id: proc
        command: ["bash", "-c",
            "~/.config/waybar/weather.sh >/dev/null 2>&1; ~/.config/waybar/weather-eww.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(this.text)
                    root.ok = j.ok === true
                    root.city = j.city || "--"
                    root.current = j.current || ({})
                    root.hourly = j.hourly || []
                    root.daily = j.daily || []
                    root.lastError = ""
                } catch (e) {
                    root.ok = false
                    root.lastError = "" + e
                }
            }
        }
    }

    Timer {
        interval: 900000      // 15 min
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
```
(`Process`/`StdioCollector`/`onStreamFinished`/`this.text` 以 Task 1 Step 1 查到的 `Quickshell.Io` API 为准;若 0.3.0 用 `SplitParser` 或不同信号名,据实改成"读全 stdout 后 JSON.parse"。)

- [ ] **Step 3: 在 shell.qml 接入并把数据显示到 Hello 块上验证**

替换 `shell.qml` 的 `Rectangle box {...}` 内容为(其余 PanelWindow 包裹不变):
```qml
        WeatherData { id: wx }

        Rectangle {
            id: box
            width: 360; height: 70
            radius: 16
            color: "#cc101016"
            Text {
                anchors.centerIn: parent
                color: "white"; font.pixelSize: 16
                text: wx.ok
                      ? (wx.city + "  " + (wx.current.temp || "--") + "°  " + (wx.current.desc || "")
                         + "  [h" + wx.hourly.length + " d" + wx.daily.length + "]")
                      : ("loading… " + wx.lastError)
            }
        }
```

- [ ] **Step 4: 跑起来截图验证真实数据**

```bash
pkill -f 'qs -c weather-island' 2>/dev/null; sleep 0.3
( qs -c weather-island >/tmp/qs.log 2>&1 & ); sleep 4   # 给抓取留时间
cat /tmp/qs.log
G=$(hyprctl layers -j | python3 -c 'import json,sys
d=json.load(sys.stdin)
[print("%d,%d %dx%d"%(s["x"],s["y"],s["w"],s["h"])) for m,i in d.items() for lv,a in i.get("levels",{}).items() for s in a if "qs-weather" in (s.get("namespace") or "")]')
grim -g "${G:-120,0 360x70}" /tmp/t2.png && echo shot
```
Expected: qs.log 无错;`/tmp/t2.png`(Read 看)显示真实城市/温度/描述及 `[h6 d3]`。若显示 "loading…" 且 lastError 非空 → 看 lastError,多半是 Process API 名不对(回 Step 2 按本机 API 改),不是脚本问题(Step 1 已证脚本 OK)。

- [ ] **Step 5: 提交**

```bash
cd /home/mhpsy/dotfiles
git add quickshell/weather-island/WeatherData.qml quickshell/weather-island/shell.qml
git commit -m "feat(quickshell): WeatherData reuses weather.sh/weather-eww.sh JSON

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Theme.qml 单例

**Files:**
- Create: `/home/mhpsy/dotfiles/quickshell/weather-island/Theme.qml`
- Create: `/home/mhpsy/dotfiles/quickshell/weather-island/qmldir`

- [ ] **Step 1: 写 Theme.qml**

Create `/home/mhpsy/dotfiles/quickshell/weather-island/Theme.qml`:
```qml
pragma Singleton
import QtQuick

QtObject {
    // 字体:含 Nerd Font weather glyph;若缺字形为已知外观问题(非阻塞)
    readonly property string uiFont: "Fira Sans"
    readonly property string glyphFont: "Symbols Nerd Font"
    readonly property color cardBg1: "#f7101016"
    readonly property color cardBg2: "#f70a0a0e"
    readonly property color stroke:  "#22ffffff"
    readonly property color fg:      "#ffffff"
    readonly property color fgDim:   "#8cffffff"
    readonly property color fgFaint: "#73ffffff"
    readonly property color accent:  "#cdd6ff"
    readonly property color chipBg:  "#10ffffff"
    readonly property int radius: 18
}
```

- [ ] **Step 2: 写 qmldir 注册单例**

Create `/home/mhpsy/dotfiles/quickshell/weather-island/qmldir`:
```
singleton Theme 1.0 Theme.qml
```
(若 Task 1 查证本机 Quickshell 用隐式同目录组件、不需要 qmldir 即可单例,则改用 `pragma Singleton` + 直接 `import "."`;以本机实际为准。)

- [ ] **Step 3: 验证 Theme 可被引用**

临时在 shell.qml 的 Text 里把 `color: "white"` 改成 `color: Theme.accent`(顶部加 `import "."`),重跑:
```bash
pkill -f 'qs -c weather-island' 2>/dev/null; sleep 0.3
( qs -c weather-island >/tmp/qs.log 2>&1 & ); sleep 3; cat /tmp/qs.log
```
Expected: 无 "Theme is not a type/defined" 错;文字变浅蓝(`#cdd6ff`)。确认后把该处改回 `Theme.accent` 保留(后续都用 Theme)。若单例解析失败 → 按 Task 1 查到的本机单例机制修正 qmldir/import。

- [ ] **Step 4: 提交**

```bash
cd /home/mhpsy/dotfiles
git add quickshell/weather-island/Theme.qml quickshell/weather-island/qmldir quickshell/weather-island/shell.qml
git commit -m "feat(quickshell): Theme singleton

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Pill.qml + Card.qml(静态布局,功能齐平)

**Files:**
- Create: `/home/mhpsy/dotfiles/quickshell/weather-island/Pill.qml`
- Create: `/home/mhpsy/dotfiles/quickshell/weather-island/Card.qml`
- Modify: `shell.qml`(装配 Pill+Card,先各自常显以便看布局)

- [ ] **Step 1: 写 Pill.qml**

Create `/home/mhpsy/dotfiles/quickshell/weather-island/Pill.qml`:
```qml
import QtQuick
import "."

Rectangle {
    id: pill
    property var wx
    signal toggle()
    implicitWidth: row.implicitWidth + 28
    implicitHeight: 34
    radius: height / 2
    color: Theme.cardBg1
    border.color: Theme.stroke
    border.width: 1

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Text {
            text: (pill.wx && pill.wx.current ? (pill.wx.current.icon || "") : "")
            font.family: Theme.glyphFont; font.pixelSize: 18; color: Theme.fg
        }
        Text {
            text: (pill.wx && pill.wx.current ? (pill.wx.current.temp || "--") : "--") + "°"
            font.family: Theme.uiFont; font.pixelSize: 15; font.bold: true; color: Theme.fg
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.toggle()
    }
}
```

- [ ] **Step 2: 写 Card.qml(与 eww 版齐平内容)**

Create `/home/mhpsy/dotfiles/quickshell/weather-island/Card.qml`:
```qml
import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: card
    property var wx
    readonly property var cur: (wx && wx.current) ? wx.current : ({})
    implicitWidth: 460
    implicitHeight: col.implicitHeight + 40
    radius: Theme.radius
    border.color: Theme.stroke
    border.width: 1
    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.cardBg1 }
        GradientStop { position: 1.0; color: Theme.cardBg2 }
    }
    clip: true

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
        spacing: 12

        // hero
        RowLayout {
            spacing: 16
            Text { text: card.cur.icon || ""; font.family: Theme.glyphFont; font.pixelSize: 46; color: Theme.fg }
            ColumnLayout {
                spacing: 0
                Text { text: card.wx ? (card.wx.city || "--") : "--"; color: Theme.fgDim; font.family: Theme.uiFont; font.pixelSize: 12 }
                Text { text: (card.cur.temp || "--") + "°"; color: Theme.accent; font.family: Theme.uiFont; font.pixelSize: 42; font.bold: true }
                Text { text: card.cur.desc || "--"; color: Theme.accent; font.family: Theme.uiFont; font.pixelSize: 14 }
                Text { text: "体感 " + (card.cur.feel || "--") + "°C"; color: Theme.fgFaint; font.family: Theme.uiFont; font.pixelSize: 12 }
            }
            Item { Layout.fillWidth: true }
        }

        // 九宫格
        GridLayout {
            columns: 3
            rowSpacing: 8; columnSpacing: 8
            Layout.fillWidth: true
            Repeater {
                model: [
                    { k: "湿度",   v: (card.cur.humidity || "--") + "%" },
                    { k: "风 " + (card.cur.wind_dir || "--"), v: (card.cur.wind_speed || "--") + " km/h" },
                    { k: "气压",   v: (card.cur.pressure || "--") + " hPa" },
                    { k: "能见度", v: (card.cur.visibility || "--") + " km" },
                    { k: "风向",   v: (card.cur.wind_deg || "--") + "°" },
                    { k: "紫外线", v: "UV " + (card.cur.uv || "--") },
                    { k: "日出",   v: card.cur.sunrise || "--" },
                    { k: "日落",   v: card.cur.sunset || "--" },
                    { k: "降水",   v: (card.cur.pop || "--") + "% · " + (card.cur.precip || "--") + "mm" }
                ]
                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: 12
                    color: Theme.chipBg
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text { text: modelData.k; color: Theme.fgFaint; font.family: Theme.uiFont; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: modelData.v; color: Theme.fg; font.family: Theme.uiFont; font.pixelSize: 14; font.bold: true; horizontalAlignment: Text.AlignHCenter; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }
            }
        }

        Text { text: "逐时预报"; color: Theme.fgFaint; font.family: Theme.uiFont; font.pixelSize: 11 }
        RowLayout {
            spacing: 7
            Layout.fillWidth: true
            Repeater {
                model: card.wx ? card.wx.hourly : []
                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    radius: 12
                    color: Theme.chipBg
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        Text { text: modelData.time || "--"; color: Theme.fgDim; font.family: Theme.uiFont; font.pixelSize: 10; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: modelData.icon || ""; color: Theme.fg; font.family: Theme.glyphFont; font.pixelSize: 17; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: (modelData.temp || "--") + "°"; color: Theme.fg; font.family: Theme.uiFont; font.pixelSize: 13; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }
            }
        }

        Text { text: "未来三天"; color: Theme.fgFaint; font.family: Theme.uiFont; font.pixelSize: 11 }
        Repeater {
            model: card.wx ? card.wx.daily : []
            delegate: Rectangle {
                Layout.fillWidth: true
                implicitHeight: 40
                radius: 12
                color: Theme.chipBg
                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    spacing: 10
                    Text { text: modelData.icon || ""; color: Theme.fg; font.family: Theme.glyphFont; font.pixelSize: 19 }
                    Text { text: modelData.label || "--"; color: Theme.fg; font.family: Theme.uiFont; font.pixelSize: 14 }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (modelData.min || "--") + "° ~ " + (modelData.max || "--") + "°C  " + (modelData.desc || "")
                        color: Theme.fgDim; font.family: Theme.uiFont; font.pixelSize: 13
                    }
                }
            }
        }
    }
}
```
(若本机 Quickshell 不随 Qt 自带 `QtQuick.Layouts` → `pacman -Ql qt6-declarative | grep -i layouts` 确认;它属 qt6-declarative,通常已装。)

- [ ] **Step 3: shell.qml 临时同时显示 Pill 与 Card 看布局**

shell.qml 的 box 区域替换为(PanelWindow 外壳不变,临时纵向堆叠两者便于一次看清):
```qml
        WeatherData { id: wx }
        Column {
            id: box
            spacing: 8
            Pill { wx: wx.ok ? ({current: wx.current}) : null; }
            Card { wx: wx }
        }
```
(Pill 的 wx 这里传一个含 current 的壳即可看样式;Task 5 再接真实联动。)

- [ ] **Step 4: 跑起来截全图验证齐平内容**

```bash
pkill -f 'qs -c weather-island' 2>/dev/null; sleep 0.3
( qs -c weather-island >/tmp/qs.log 2>&1 & ); sleep 4; cat /tmp/qs.log
G=$(hyprctl layers -j | python3 -c 'import json,sys
d=json.load(sys.stdin)
[print("%d,%d %dx%d"%(s["x"],s["y"],s["w"],s["h"])) for m,i in d.items() for lv,a in i.get("levels",{}).items() for s in a if "qs-weather" in (s.get("namespace") or "")]')
echo "surf=$G"; grim -g "${G:-120,0 470x680}" /tmp/t4.png && echo shot
```
Expected(Read 看 /tmp/t4.png):上方一个胶囊;下方完整深色玻璃卡 —— hero(大图标/城市/大温度/描述/体感)、3×3 九宫格九项、逐时 6 列、三天 3 行,数据真实、排版整齐。qs.log 无 QML error。布局问题就地调 QML 重跑直至齐平美观。

- [ ] **Step 5: 提交**

```bash
cd /home/mhpsy/dotfiles
git add quickshell/weather-island/Pill.qml quickshell/weather-island/Card.qml quickshell/weather-island/shell.qml
git commit -m "feat(quickshell): Pill + full Card layout (parity with eww)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: shell.qml 状态机 + 弹性流体展开/收起动画 + mask 无死区

**Files:**
- Modify: `/home/mhpsy/dotfiles/quickshell/weather-island/shell.qml`

- [ ] **Step 1: 重写 shell.qml 为完整状态机 + 动画 + 输入掩码**

整文件替换 `/home/mhpsy/dotfiles/quickshell/weather-island/shell.qml`:
```qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

ShellRoot {
    PanelWindow {
        id: win
        anchors { top: true; left: true }
        margins.left: 120
        margins.top: 0
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "qs-weather-island"

        // 窗口尺寸 = 当前可见容器尺寸(收起=胶囊 / 展开=卡)
        implicitWidth: stack.width
        implicitHeight: stack.height

        // 输入区只覆盖可见内容 -> 收起时就胶囊那么大,无 eww 那种死区
        mask: Region { item: stack }

        WeatherData { id: wx }
        property bool expanded: false

        Item {
            id: stack
            width: Math.max(pill.implicitWidth, expanded ? card.implicitWidth : 0)
            height: pill.implicitHeight + (expanded ? card.implicitHeight + 6 : 0)
            Behavior on width  { SpringAnimation { spring: 3.2; damping: 0.28; epsilon: 0.5 } }
            Behavior on height { SpringAnimation { spring: 3.2; damping: 0.28; epsilon: 0.5 } }

            Pill {
                id: pill
                wx: wx
                onToggle: win.expanded = !win.expanded
            }

            Card {
                id: card
                wx: wx
                y: pill.implicitHeight + 6
                width: implicitWidth
                visible: opacity > 0.01
                opacity: win.expanded ? 1 : 0
                scale: win.expanded ? 1 : 0.96
                transformOrigin: Item.Top
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }

                // 移开卡片自动收起(短延时避免抖动)
                HoverHandler { id: cardHover }
            }

            Timer {
                id: collapseTimer
                interval: 350
                onTriggered: if (!cardHover.hovered && !pillHover.hovered) win.expanded = false
            }
            HoverHandler { id: pillHover; target: pill }
            Connections {
                target: cardHover
                function onHoveredChanged() {
                    if (win.expanded && !cardHover.hovered) collapseTimer.restart()
                    else collapseTimer.stop()
                }
            }
        }
    }
}
```
(`Region`/`mask`、`HoverHandler`、`SpringAnimation` 的确切名以 Task 1 查到的本机 API 为准。若 0.3.0 的 `mask` 写法不同,目标是"输入区=stack 矩形";若 `Region` 不可用,退路:不设 mask,但把 `implicitWidth/Height` 严格绑定 stack(收起时 stack=胶囊小尺寸,死区也很小,可接受并记录。)

- [ ] **Step 2: 跑起来,验证收起态(无死区)**

```bash
pkill -f 'qs -c weather-island' 2>/dev/null; sleep 0.3
( qs -c weather-island >/tmp/qs.log 2>&1 & ); sleep 4; cat /tmp/qs.log
hyprctl layers -j | python3 -c 'import json,sys
d=json.load(sys.stdin)
[print("collapsed surf %d,%d %dx%d"%(s["x"],s["y"],s["w"],s["h"])) for m,i in d.items() for lv,a in i.get("levels",{}).items() for s in a if "qs-weather" in (s.get("namespace") or "")]'
```
Expected:收起态表面**约胶囊大小(宽~一两百、高~34)**,不是几百高。qs.log 无错。若收起态仍是大尺寸 → mask/implicit 绑定没生效,按 Task 1 API 修正(这是"无死区"的核心验收点)。

- [ ] **Step 3: 验证展开态(点击 → 弹性流体展开)**

用脚本模拟点击不易;改为程序触发并截图前后两态:
```bash
# 展开(直接置 expanded —— 验证动画后形态;真实交互靠点击,逻辑同)
hyprctl dispatch exec true >/dev/null 2>&1
# 用 grim 连拍:先收起
G=$(hyprctl layers -j | python3 -c 'import json,sys
d=json.load(sys.stdin)
[print("%d,%d %dx%d"%(s["x"],s["y"],s["w"],s["h"])) for m,i in d.items() for lv,a in i.get("levels",{}).items() for s in a if "qs-weather" in (s.get("namespace") or "")]')
grim -g "${G:-120,0 200x40}" /tmp/t5_collapsed.png && echo "collapsed shot"
```
然后用鼠标真实点击胶囊验证(本会话可由用户做;agent 验证用:在 shell.qml 末尾临时加 `Component.onCompleted: win.expanded = true` 重跑,截展开全图,确认弹性展开形态与完整卡,然后**移除该临时行**):
```bash
# 临时加展开后:
G=$(hyprctl layers -j | python3 -c 'import json,sys
d=json.load(sys.stdin)
[print("%d,%d %dx%d"%(s["x"],s["y"],s["w"],s["h"])) for m,i in d.items() for lv,a in i.get("levels",{}).items() for s in a if "qs-weather" in (s.get("namespace") or "")]')
grim -g "${G:-120,0 470x700}" /tmp/t5_expanded.png && echo "expanded shot"
```
Expected:collapsed 图=小胶囊;expanded 图=胶囊下方完整卡。Read 两图确认。确认后**务必删掉临时的 `Component.onCompleted: win.expanded = true`**(默认应收起)。

- [ ] **Step 4: 提交**

```bash
cd /home/mhpsy/dotfiles
git add quickshell/weather-island/shell.qml
git commit -m "feat(quickshell): state machine + spring expand/collapse + input mask (no dead zone)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Ambient.qml — 按天气的粒子/渐变氛围

**Files:**
- Create: `/home/mhpsy/dotfiles/quickshell/weather-island/Ambient.qml`
- Modify: `Card.qml`(把 Ambient 垫在内容下层)

- [ ] **Step 1: 写 Ambient.qml**

Create `/home/mhpsy/dotfiles/quickshell/weather-island/Ambient.qml`:
```qml
import QtQuick
import QtQuick.Particles
import "."

Item {
    id: amb
    property string cond: "clouds"
    anchors.fill: parent
    clip: true

    // 晴:暖色光晕呼吸
    Rectangle {
        anchors.fill: parent
        visible: amb.cond === "clear"
        radius: Theme.radius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#00ffc45a" }
            GradientStop { position: 1.0; color: "#33ffc45a" }
        }
        SequentialAnimation on opacity {
            running: amb.cond === "clear"; loops: Animation.Infinite
            NumberAnimation { from: 0.4; to: 1.0; duration: 2600; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.0; to: 0.4; duration: 2600; easing.type: Easing.InOutSine }
        }
    }

    // 阴/雾:横向漂移柔光带
    Rectangle {
        id: drift
        visible: amb.cond === "clouds" || amb.cond === "fog"
        width: parent.width * 0.6; height: parent.height
        radius: Theme.radius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#00aab9e1" }
            GradientStop { position: 0.5; color: "#1faab9e1" }
            GradientStop { position: 1.0; color: "#00aab9e1" }
        }
        SequentialAnimation on x {
            running: drift.visible; loops: Animation.Infinite
            NumberAnimation { from: -drift.width; to: amb.width; duration: 12000; easing.type: Easing.Linear }
        }
    }

    // 雨 / 雷雨:粒子斜雨
    ParticleSystem {
        id: psys
        running: amb.cond === "rain" || amb.cond === "thunder"
        anchors.fill: parent
        ImageParticle {
            groups: ["d"]
            color: "#7896beff"
            // 细线状:用很小的内置矩形纹理替代图片
            source: "qrc:///particleresources/glowdot.png"
            alpha: 0.0
        }
        Emitter {
            group: "d"
            enabled: psys.running
            anchors { top: parent.top; left: parent.left; right: parent.right }
            emitRate: 120
            lifeSpan: 1100
            size: 6
            velocity: AngleDirection { angle: 75; magnitude: 420; angleVariation: 4 }
        }
    }

    // 雪:缓降
    ParticleSystem {
        id: snow
        running: amb.cond === "snow"
        anchors.fill: parent
        ImageParticle { groups: ["s"]; color: "#ddffffff"; source: "qrc:///particleresources/glowdot.png" }
        Emitter {
            group: "s"; enabled: snow.running
            anchors { top: parent.top; left: parent.left; right: parent.right }
            emitRate: 26; lifeSpan: 6000; size: 7
            velocity: AngleDirection { angle: 90; magnitude: 60; angleVariation: 12 }
        }
    }

    // 雷:偶发高光闪
    Rectangle {
        anchors.fill: parent; radius: Theme.radius
        visible: amb.cond === "thunder"; color: "#b4c8ff"
        opacity: 0
        SequentialAnimation on opacity {
            running: amb.cond === "thunder"; loops: Animation.Infinite
            NumberAnimation { to: 0.0; duration: 3600 }
            NumberAnimation { to: 0.5; duration: 60 }
            NumberAnimation { to: 0.0; duration: 90 }
            NumberAnimation { to: 0.45; duration: 70 }
            NumberAnimation { to: 0.0; duration: 120 }
        }
    }
}
```
(`QtQuick.Particles` 属 qt6-declarative,通常已装;`pacman -Ql qt6-declarative | grep -i particles` 可确认。`qrc:///particleresources/glowdot.png` 是 Qt 内置粒子纹理;若本机 Qt6 该 qrc 路径不存在,退路:用一个 `Rectangle`/`ShaderEffect` 自绘小亮点作 `ItemParticle` 的 delegate —— 目标是"有真实落雨/雪粒子动",据本机情况调整。)

- [ ] **Step 2: Card.qml 垫入 Ambient(内容之下)**

在 `Card.qml` 的 `ColumnLayout { id: col … }` **之前**插入(作为同级、铺满、在内容下层):
```qml
    Ambient {
        anchors.fill: parent
        cond: (card.cur && card.cur.cond) ? card.cur.cond : "clouds"
        opacity: 0.9
        z: -1
    }
```
(确保 `clip: true` 已在 card 上 —— Task 4 已加 —— 使粒子裁在圆角内。)

- [ ] **Step 3: 跑起来逐天气验证动效**

```bash
pkill -f 'qs -c weather-island' 2>/dev/null; sleep 0.3
( qs -c weather-island >/tmp/qs.log 2>&1 & ); sleep 4; cat /tmp/qs.log
# 临时加 Component.onCompleted: win.expanded=true 看展开态;截图
G=$(hyprctl layers -j | python3 -c 'import json,sys
d=json.load(sys.stdin)
[print("%d,%d %dx%d"%(s["x"],s["y"],s["w"],s["h"])) for m,i in d.items() for lv,a in i.get("levels",{}).items() for s in a if "qs-weather" in (s.get("namespace") or "")]')
grim -g "${G:-120,0 470x700}" /tmp/t6.png && echo shot
```
Expected:qs.log 无错;/tmp/t6.png(Read 看)展开卡内有与当前 `cond` 对应的氛围层(雨天能看到斜雨粒子等),且**不影响文字可读性**。当前真实天气若非雨,可临时把 Card 里 `cond:` 写死成 `"rain"`/`"snow"` 各跑一次确认粒子,验证后改回 `card.cur.cond`。验证完删除临时 expanded 行。

- [ ] **Step 4: 提交**

```bash
cd /home/mhpsy/dotfiles
git add quickshell/weather-island/Ambient.qml quickshell/weather-island/Card.qml
git commit -m "feat(quickshell): condition-driven particle/gradient ambient layer

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: 接入 — 从 waybar 移除 custom/weather + hypr 自启动改 Quickshell

**Files:**
- Modify: `/home/mhpsy/dotfiles/waybar/config.jsonc`
- Modify: `/home/mhpsy/dotfiles/hypr/conf/autostart.conf`

- [ ] **Step 1: 记录当前 custom/weather 块(回退用)+ 从 modules-left 删除引用**

先看实际内容:
```bash
grep -n '"custom/weather"' /home/mhpsy/dotfiles/waybar/config.jsonc
grep -n -A8 '"custom/weather": {' /home/mhpsy/dotfiles/waybar/config.jsonc
```
在 `config.jsonc` 的 `"modules-left"` 数组里删除整行 `"custom/weather",`(注意逗号:删除后保证 JSON/JSONC 仍合法 —— 若它是数组最后一项,删掉前一项末尾多余逗号;通常它后面还有项,直接删该行即可)。

- [ ] **Step 2: 删除 custom/weather 定义块**

删除 `config.jsonc` 中整段:
```jsonc
    "custom/weather": {
        "format": "{}",
        "return-type": "json",
        "exec": "~/.config/waybar/weather.sh",
        "interval": 900,
        "tooltip": false,
        "on-click": "~/.config/waybar/weather-island-toggle.sh"
    },
```
(以 Step 1 grep 到的实际内容为准逐字删除整块,含其后的逗号使 JSONC 仍合法。`weather.sh`/`weather-eww.sh` 文件本身不动 —— Quickshell 会调用它们。)

- [ ] **Step 3: 校验 config.jsonc 合法**

```bash
sed 's://.*$::' /home/mhpsy/dotfiles/waybar/config.jsonc | jq -e 'has("custom/weather") | not' && echo "custom/weather removed & JSON valid"
python3 -c 'import json,re,sys; s=open("/home/mhpsy/dotfiles/waybar/config.jsonc").read(); s=re.sub(r"//.*","",s); json.loads(s); print("jsonc parses OK")'
```
Expected:两行都成功(`custom/weather` 已无、整体仍是合法 JSON)。失败 → 多半逗号问题,修正。

- [ ] **Step 4: hypr 自启动:天气 eww 行 → Quickshell**

```bash
grep -n 'weather\|qs -c\|quickshell\|daily-word' /home/mhpsy/dotfiles/hypr/conf/autostart.conf
```
把那行 `exec-once = eww --config ~/.config/waybar/eww daemon`(天气 eww daemon 预热行,Task d1ccc50 加的)替换为:
```
exec-once = qs -c weather-island
```
**`exec-once = eww --config ~/.config/eww open daily-word` 那行(word-island)绝对不动。** 确认:
```bash
grep -n 'exec-once' /home/mhpsy/dotfiles/hypr/conf/autostart.conf | grep -E 'qs -c weather-island|daily-word'
```
Expected:有 `qs -c weather-island` 行;`daily-word` 行原样还在。

- [ ] **Step 5: 重启 waybar 使其去掉天气模块,确认不报错**

```bash
~/.config/waybar/launch.sh ; sleep 2
pgrep -x waybar >/dev/null && echo "waybar running (no custom/weather)"
```
Expected:waybar 正常起、左侧不再有天气胶囊(其它模块左移),无关于 custom/weather 的报错。

- [ ] **Step 6: 提交**

```bash
cd /home/mhpsy/dotfiles
git add waybar/config.jsonc hypr/conf/autostart.conf
git commit -m "feat: retire eww weather island — remove waybar custom/weather, autostart qs -c weather-island

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: 端到端验收 + 抓取接管确认 + 收尾

**Files:** 无新增改动(验收;必要的微调回到对应任务文件并补提交)

- [ ] **Step 1: 全新会话方式启动(模拟开机)**

```bash
pkill -f 'qs -c weather-island' 2>/dev/null; sleep 0.3
( qs -c weather-island >/tmp/qs.log 2>&1 & ); sleep 5
cat /tmp/qs.log    # 必须无 QML error
pgrep -af 'qs -c weather-island' && echo "qs alive"
```

- [ ] **Step 2: 收起态无死区**

```bash
hyprctl layers -j | python3 -c 'import json,sys
d=json.load(sys.stdin)
g=[s for m,i in d.items() for lv,a in i.get("levels",{}).items() for s in a if "qs-weather" in (s.get("namespace") or "")]
print("collapsed surface:", "%dx%d"%(g[0]["w"],g[0]["h"]) if g else "NONE")'
```
Expected:宽~一两百、**高 ~34**(胶囊大小),不是几百。说明 mask/隐式尺寸生效,左上角无大片死区。

- [ ] **Step 3: 真实交互验收(人工 + 截图)**

由用户点击胶囊;agent 侧验证:临时在 shell.qml 末尾加 `Component.onCompleted: win.expanded = true`,重跑,截展开全图:
```bash
G=$(hyprctl layers -j | python3 -c 'import json,sys
d=json.load(sys.stdin)
[print("%d,%d %dx%d"%(s["x"],s["y"],s["w"],s["h"])) for m,i in d.items() for lv,a in i.get("levels",{}).items() for s in a if "qs-weather" in (s.get("namespace") or "")]')
grim -g "${G:-120,0 470x720}" /tmp/final.png && echo shot
```
Read /tmp/final.png 确认:胶囊→完整卡(hero/九宫格/逐时/三天 + 氛围动效),数据真实。**确认后删除临时 `Component.onCompleted` 行并补一次提交。**

- [ ] **Step 4: 抓取接管确认(关键 —— 别让天气停更)**

```bash
stat -c '%Y %n' /tmp/waybar-openmeteo.json
rm -f /tmp/waybar-openmeteo.json
# 触发 Quickshell 刷新:重启 qs(Timer triggeredOnStart 会跑数据命令)
pkill -f 'qs -c weather-island' 2>/dev/null; sleep 0.3
( qs -c weather-island >/tmp/qs.log 2>&1 & ); sleep 6
ls -l /tmp/waybar-openmeteo.json && echo "cache RE-CREATED by Quickshell-triggered weather.sh -> 抓取接管成功"
bash -c '~/.config/waybar/weather-eww.sh' | jq '.ok'
```
Expected:缓存被重新生成(说明 Quickshell 的数据命令确实跑了 `weather.sh` 抓取),`.ok` 为 true。这验证了移除 waybar custom/weather 后天气仍会更新。

- [ ] **Step 5: 回归 —— 没碰 word-island / 没删 eww 回退文件**

```bash
eww --config ~/.config/eww active-windows 2>&1   # word-island daemon 仍在,未受影响
test -f /home/mhpsy/dotfiles/waybar/weather-island-toggle.sh && echo "eww 回退脚本保留"
git -C /home/mhpsy/dotfiles status --porcelain | grep -E '(\.config/)?eww/|word-island' && echo "WARN 动了 word-island" || echo "word-island 未改 OK"
git -C /home/mhpsy/dotfiles log --oneline -8
```
Expected:word-island eww 仍运行;eww 天气回退文件还在;diff 未涉及 word-island。

- [ ] **Step 6: 完成开发分支**

REQUIRED SUB-SKILL: 用 superpowers:finishing-a-development-branch 决定合并/PR/清理。

---

## Self-Review

**Spec 覆盖核对:**
- Quickshell 画胶囊+卡、从 waybar 移除 custom/weather → Task 4(Pill/Card)+ Task 7(移除)。✓
- 数据复用 weather.sh+weather-eww.sh 不改 → Task 2 命令 `bash -c 'weather.sh>/dev/null; weather-eww.sh'`;Task 8 Step4 验证抓取接管。✓
- 关键依赖(抓取接管)→ Task 2 命令含 weather.sh;Task 8 Step4 专项验证缓存重建。✓
- 内容齐平(hero/九宫格/逐时6/三天3)→ Task 4 Card 完整实现,字段对齐 weather-eww.sh 契约。✓
- QML 真动画(弹簧形变 + 内容过渡 + 粒子氛围)→ Task 5(SpringAnimation + states/Behavior)+ Task 6(ParticleSystem)。✓
- 无死区(mask/隐式尺寸)→ Task 5 Step1 mask + Step2 收起态尺寸验收;Task 8 Step2。✓
- eww 退役但保留回退、不碰 word-island → Task 7 Step4 仅换天气行;Task 8 Step5 回归。✓
- 配置链接、qs -c weather-island 启动、hypr 自启动 → Task 1 建链;Task 7 Step4 autostart。✓
- Quickshell 0.3.0 API 不确定性 → Task 1 Step1 强制查证 + 全程"以本机 API 为准修正"约定 + 每任务跑 qs 看 stderr 即时暴露。✓
- 验证方法(无单测,用 qs+hyprctl+grim+Read 图)→ 每个 Task 的验证步均如此,与本会话已证有效方法一致。✓
- 改动清单(quickshell/* 新增,config.jsonc / autostart.conf 改)→ File Structure 表 + Task 对应。✓

**占位扫描:** 无 TBD/TODO;每个写代码步给出完整 QML/命令;API 不确定处给了"以本机为准 + 退路"的明确处理而非占位;验证步给了确切命令与预期。✓

**类型/命名一致性:** `WeatherData` 暴露 `ok/city/current/hourly/daily` 在 Task 2 定义,Task 4/5 中 `wx.ok`/`wx.city`/`wx.current.<field>`/`wx.hourly`/`wx.daily` 一致;`Theme.*` 常量 Task 3 定义、Task 4/6 引用一致;namespace `qs-weather-island` 全程一致;`win.expanded`、`stack`、`pill`/`card` id 在 Task 5 内自洽;数据字段名(temp/desc/feel/humidity/wind_dir/wind_speed/pressure/visibility/wind_deg/uv/sunrise/sunset/pop/precip/cond、hourly{time,icon,temp}、daily{label,icon,min,max,desc})与 weather-eww.sh 现有输出契约一致。✓
