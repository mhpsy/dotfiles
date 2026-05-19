# Quickshell 单词灵动岛 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把"每日单词"弹出岛从 eww 改为 Quickshell:收起态保持 waybar 原生 `custom/quotes` 胶囊(完美融入),点击经状态文件触发常驻 `qs -c word-island` 守护进程弹出富交互卡(点词切换 + 🔊 + 阶梯入场 + 当前词辉光脉动 + 按词性变背景)。

**Architecture:** 直接复用已上线的天气岛混合模式与全部 Quickshell 本机经验。waybar `custom/quotes` 的 `on-click` 改指向新 `qs-word-toggle.sh`(翻 `/tmp/qs-word-open` 0/1);`qs -c word-island` 用 `FileView` 监听该文件,固定 surface 内显隐 `WordCard`;`WordData` 卡打开时轮询 `word-popup.sh`;列表项/🔊 经 `Process` 调 `word-pick.sh`/`word-speak.sh`。数据脚本全部复用不改。

**Tech Stack:** Quickshell 0.3.0(Qt6 QML:QtQuick / Quickshell / Quickshell.Wayland / Quickshell.Io)、bash、waybar(jsonc)、hyprland。

关联 spec:`docs/superpowers/specs/2026-05-19-quickshell-word-island-design.md`

---

## 重要执行须知(全程适用)

- **本机 = 用户活跃 Hyprland 会话**。无单测:验证 = 跑 `qs` + `hyprctl layers -j` + `grim` 截图后用 **Read 工具看图** + 看 `qs` stderr。
- **STRICT 单实例**:`pgrep -f 'qs -c <x>'` 会自匹配 shell 包装(假阳性)——**一律 `pgrep -x qs`**。但注意本机现在有**两个** qs 守护:`weather-island` 与(本计划新增)`word-island`。`pkill -9 -x qs` 会**同时杀掉 weather-island**——这是可接受的(验证期间),每个任务验证完若需保留 weather-island 运行,在任务末尾重启它:`( qs -c weather-island >/tmp/qsw.log 2>&1 & )`。每次验证 word-island 前:
  ```bash
  for i in 1 2 3 4 5; do pkill -9 -x qs 2>/dev/null; sleep 0.6; pgrep -x qs >/dev/null || break; done
  pgrep -x qs && echo "ALIVE bad" || echo "ZERO good"
  ```
  起一个 `( qs -c word-island >/tmp/qsword.log 2>&1 & )`,确认**恰好 1 个** `qs-word-island` 表面再继续。任务结尾恢复:重启两者(`( qs -c weather-island >/tmp/qsw.log 2>&1 & ); ( qs -c word-island >/tmp/qsword.log 2>&1 & )`),并把 `/tmp/qs-word-open` 复位为关。
- **本机 Quickshell 0.3.0 经验(已在天气岛验证,以此为准)**:根 `ShellRoot`;窗口 `WlrLayershell`(`PanelWindow` `isCreatable:false`)直属性;**绝不把动画/变化值绑 `WlrLayershell.implicitWidth/implicitHeight`**(Wayland surface 每帧 reconfigure = 剧烈抖动)——surface 尺寸必须稳定常量级,动画只作用于固定 surface 内的 QML 内容;`mask: Region { item: open ? card : null }`(关闭 null = 全穿透零足迹);`Theme` = `pragma Singleton`+`import Quickshell`+`Singleton{}`,**无 qmldir**(qmldir 破坏同目录组件自动发现);同目录组件 `import "."`;`FileView`(`Quickshell.Io`):`path` 属性、`text()` 是**异步方法**(`onFileChanged` 时 `text()` 还是旧值)→ `onFileChanged: reload()` 然后在 `onTextChanged`/`onLoaded` 读 `text()`;缺文件时 watch 不挂 → 加 ~400ms `Timer{ reload() }` 兜底;`printErrors:false` 去缺文件 WARN 噪音;交互回调用 `Process`;`StdioCollector` 信号 `streamFinished`、读其 `id`.text、`waitForEnd:true`。
- dotfiles 仓库 `/home/mhpsy/dotfiles`,当前分支 `feat/word-island`(在此分支提交,**不要切分支**)。提交只 `git add` 明确文件,**绝不** `git add -A`。提交信息结尾带 `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`。
- **预存在的无关脏文件,绝不 stage/提交**:` M eww/colors.scss`、` M matugen/config.toml`、`?? matugen/templates/quickshell-colors.json`、`?? quickshell/colors.json`、`?? .claude/`。
- **绝不触碰**:任何 `quickshell/weather-island/*`、`hypr/conf/autostart.conf` 的 `exec-once = qs -c weather-island` 行、`waybar/custom/weather` 块、`waybar/weather*.sh`、`waybar/word-island-toggle.sh`(eww 回退,保留不动不复用)、`waybar/eww/*`、`eww/*`、`waybar/quotes.sh`/`word-popup.sh`/`word-pick.sh`/`word-speak.sh`/`words-lib.sh`/`words-cache.sh`/`word-stream.sh`/`wordlist.json`(数据脚本全部复用、**不改**)、上述预存在脏文件。

## 复用的数据脚本契约(只调用,不改)

- `~/.config/waybar/word-popup.sh`(无参,直接可跑)→ 单行 JSON:
  `{"current":{"word":<str>,"pos":[<str>...],"phonetic":<str>,"meaning":<str>,"example":<str>},"today":[{"word":<str>,"meaning":<str>,"current":<bool>,"idx":<int>}, …10项]}`
  与原生胶囊同源(认手动 override / 10min 轮换)。卡轮询此脚本拿数据。
- `~/.config/waybar/word-pick.sh <p>`:`p` = `today[].idx`(今日列表 0 基位置);切到该词 + 重置轮换。卡列表项点击调用。
- `~/.config/waybar/word-speak.sh`(无参):朗读当前词(认 override,无通知)。🔊 调用。`WORDS_DRY_RUN=1` 时只打印不播放(供验证)。

## File Structure

| 文件 | 责任 | 改动 |
|---|---|---|
| `waybar/qs-word-toggle.sh` | 翻转 `/tmp/qs-word-open` 0/1 | **新增** |
| `quickshell/word-island/Theme.qml` | 颜色/字体单例 + `posTint` 词性映射 | **新增**(从 weather-island Theme.qml 复制 + 加 posTint) |
| `quickshell/word-island/WordData.qml` | open 时轮询 word-popup.sh,暴露 ok/current/today,refresh() | **新增** |
| `quickshell/word-island/WordCard.qml` | hero+今日列表+🔊;交互+动效+POS背景 | **新增**(W2 静态→W3 交互→W4 动效 增量) |
| `quickshell/word-island/shell.qml` | 窗口+FileView+WordData+WordCard(套天气岛固定surface范式) | **新增** |
| `waybar/config.jsonc` | `custom/quotes` 的 `on-click` 改指向 qs-word-toggle.sh | **改 1 处** |
| `hypr/conf/autostart.conf` | eww daily-word 行 → `qs -c word-island` | **改 1 行** |

经符号链接 `~/.config/quickshell → dotfiles/quickshell`(已存在)。

---

## Task W1: qs-word-toggle.sh + 状态文件契约

**Files:** Create `/home/mhpsy/dotfiles/waybar/qs-word-toggle.sh`

(FileView API 已在天气岛验证,无需再查;本任务只做触发脚本。)

- [ ] **Step 1: 写 qs-word-toggle.sh**

Create `/home/mhpsy/dotfiles/waybar/qs-word-toggle.sh`:
```sh
#!/bin/sh
# Toggle the Quickshell word card open-state file. Missing/non-"1" => treat
# as currently closed, so this opens it (writes "1"). on-click target of the
# waybar custom/quotes module.
f=/tmp/qs-word-open
if [ "$(cat "$f" 2>/dev/null)" = "1" ]; then
    printf 0 > "$f"
else
    printf 1 > "$f"
fi
```

- [ ] **Step 2: 可执行 + 验证翻转契约**

```bash
chmod +x /home/mhpsy/dotfiles/waybar/qs-word-toggle.sh
rm -f /tmp/qs-word-open
~/.config/waybar/qs-word-toggle.sh; echo "1st:[$(cat /tmp/qs-word-open)]"
~/.config/waybar/qs-word-toggle.sh; echo "2nd:[$(cat /tmp/qs-word-open)]"
~/.config/waybar/qs-word-toggle.sh; echo "3rd:[$(cat /tmp/qs-word-open)]"
printf 'xyz' > /tmp/qs-word-open; ~/.config/waybar/qs-word-toggle.sh; echo "garbage:[$(cat /tmp/qs-word-open)]"
```
Expected: `1st:[1]`, `2nd:[0]`, `3rd:[1]`, `garbage:[1]`(非 `1` 一律视为关→开为 `1`)。不符则修脚本至契约成立。

- [ ] **Step 3: 提交**

```bash
cd /home/mhpsy/dotfiles
git add waybar/qs-word-toggle.sh
git commit -m "feat(waybar): qs-word-toggle.sh — flip /tmp/qs-word-open for QS word card

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task W2: word-island Quickshell 配置 — Theme + WordData + WordCard(静态) + shell.qml

**Files:** Create `quickshell/word-island/Theme.qml`, `WordData.qml`, `WordCard.qml`, `shell.qml`

- [ ] **Step 1: Theme.qml(复制 weather-island 的 + 加 posTint)**

Create `/home/mhpsy/dotfiles/quickshell/word-island/Theme.qml`:
```qml
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property string uiFont: "Fira Sans"
    readonly property string glyphFont: "Font Awesome 7 Free"
    readonly property string glyphStyle: "Solid"
    // colors are #AARRGGBB (QML/Qt ARGB order — alpha first)
    readonly property color cardBg1: "#f7101016"
    readonly property color cardBg2: "#f70a0a0e"
    readonly property color stroke:  "#22ffffff"
    readonly property color fg:      "#ffffff"
    readonly property color fgDim:   "#8cffffff"
    readonly property color fgFaint: "#73ffffff"
    readonly property color accent:  "#cdd6ff"
    readonly property color chipBg:  "#10ffffff"
    readonly property int radius: 18
    // POS → low-alpha background tint (#AARRGGBB). Unlisted POS → "transparent".
    readonly property var posTint: ({
        "n.":  "#3360a5fa",
        "v.":  "#33f0a050", "vt.": "#33f0a050", "vi.": "#33f0a050",
        "adj.":"#3340c0a0", "a.":  "#3340c0a0",
        "adv.":"#33a070e0", "ad.": "#33a070e0"
    })
    function tintFor(posArr) {
        var k = (posArr && posArr.length) ? posArr[0] : ""
        return posTint[k] || "transparent"
    }
}
```

- [ ] **Step 2: WordData.qml(open 时轮询 word-popup.sh)**

Create `/home/mhpsy/dotfiles/quickshell/word-island/WordData.qml`:
```qml
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property bool active: false          // bound by shell.qml to card open/visible
    property bool ok: false
    property var current: ({})
    property var today: []
    property string lastError: ""

    // Public: immediate re-fetch (after pick / speak). No-op if a run is in flight.
    function refresh() { if (!proc.running) proc.running = true }

    Process {
        id: proc
        command: ["bash", "-c", "~/.config/waybar/word-popup.sh"]
        stdout: StdioCollector {
            id: out
            waitForEnd: true
            onStreamFinished: {
                try {
                    var j = JSON.parse(out.text)
                    root.current = j.current || ({})
                    root.today = j.today || []
                    root.ok = !!(root.current && root.current.word)
                    root.lastError = ""
                } catch (e) {
                    root.ok = false
                    root.lastError = "" + e
                }
            }
        }
    }

    // Poll only while the card is open (active). Closed → Timer stopped → idle-free.
    Timer {
        interval: 1500
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
```

- [ ] **Step 3: WordCard.qml(静态:hero + 今日列表 + POS 背景;无交互/动效,后续任务加)**

Create `/home/mhpsy/dotfiles/quickshell/word-island/WordCard.qml`:
```qml
import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: card
    property var words                                   // the WordData instance
    readonly property var cur: (words && words.current) ? words.current : ({})
    readonly property var todays: (words && words.today) ? words.today : []

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

    // POS background tint (behind content). Smoothly cross-fades on POS change.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        z: -1
        color: Theme.tintFor(card.cur.pos)
        Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    }

    ColumnLayout {
        id: col
        z: 1
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
        spacing: 12

        // hero
        ColumnLayout {
            spacing: 2
            RowLayout {
                spacing: 10
                Text { text: card.cur.word || "--"; color: Theme.accent; font.family: Theme.uiFont; font.pixelSize: 34; font.bold: true }
                Text { text: (card.cur.pos && card.cur.pos.length ? card.cur.pos.join(" ") : ""); color: Theme.fgFaint; font.family: Theme.uiFont; font.pixelSize: 14 }
                Item { Layout.fillWidth: true }
                // 🔊 button (interaction wired in W3)
                Rectangle {
                    id: speakBtn
                    implicitWidth: 34; implicitHeight: 28; radius: 8
                    color: Theme.chipBg
                    Text { anchors.centerIn: parent; text: ""; font.family: Theme.glyphFont; font.styleName: Theme.glyphStyle; font.pixelSize: 15; color: Theme.fg }
                }
            }
            Text { text: card.cur.phonetic || ""; color: Theme.fgDim; font.family: Theme.uiFont; font.pixelSize: 13 }
            Text { text: card.cur.meaning || "--"; color: Theme.fg; font.family: Theme.uiFont; font.pixelSize: 16; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            Text { text: card.cur.example || ""; color: Theme.fgFaint; font.family: Theme.uiFont; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WordWrap }
        }

        Text { text: "今日单词"; color: Theme.fgFaint; font.family: Theme.uiFont; font.pixelSize: 11 }

        Repeater {
            model: card.todays
            delegate: Rectangle {
                id: row
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 10
                color: modelData.current ? Theme.chipBg : "transparent"
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 10
                    Text { text: modelData.word || "--"; color: modelData.current ? Theme.accent : Theme.fg; font.family: Theme.uiFont; font.pixelSize: 14; font.bold: modelData.current }
                    Text { text: modelData.meaning || ""; color: Theme.fgDim; font.family: Theme.uiFont; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                }
            }
        }
    }
}
```

- [ ] **Step 4: shell.qml(套天气岛已验证的固定 surface + FileView 范式)**

Create `/home/mhpsy/dotfiles/quickshell/word-island/shell.qml`:
```qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

ShellRoot {
    WlrLayershell {
        id: win
        anchors { top: true; left: true }
        margins.left: 120          // approx x: transient dropdown near the quotes module; tunable
        margins.top: 40            // bar height ~40 → card hangs just below the bar
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        layer: WlrLayer.Overlay
        keyboardFocus: WlrKeyboardFocus.None
        namespace: "qs-word-island"

        // FIXED Wayland surface = card bbox. NEVER animate / NEVER add a Behavior here.
        implicitWidth: card.implicitWidth
        implicitHeight: card.implicitHeight

        mask: Region { item: win.open ? card : null }

        WordData { id: words; active: win.open }

        // Open/closed via /tmp/qs-word-open (waybar on-click flips it). FileView reads
        // are async on this build: reload() on fileChanged, read in onTextChanged/onLoaded.
        property bool open: false
        function syncOpen() {
            var t = stateFile.text()
            win.open = t ? t.trim() === "1" : false
        }
        FileView {
            id: stateFile
            path: "/tmp/qs-word-open"
            watchChanges: true
            printErrors: false
            onFileChanged: reload()
            onTextChanged: win.syncOpen()
            onLoaded: win.syncOpen()
        }
        // Safety net: missing-file inotify watch never attaches → periodic reload.
        Timer { interval: 400; running: true; repeat: true; onTriggered: stateFile.reload() }

        WordCard {
            id: card
            words: words
            visible: opacity > 0.01
            opacity: win.open ? 1 : 0
            scale: win.open ? 1 : 0.96
            transformOrigin: Item.Top
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on scale   { SpringAnimation { spring: 4.0; damping: 0.5; epsilon: 0.01 } }
        }
    }
}
```
(若本机 `qs` 报 `FileView`/属性/类型错,以天气岛同款本机 API 修正——但天气岛已证此写法在本机可用,应无错。)

- [ ] **Step 5: 验证(STRICT 单实例;关闭态零足迹 + 翻文件出卡 + 无抖动)**

```bash
echo "--- word-popup.sh sane? ---"; bash -c '~/.config/waybar/word-popup.sh' | jq '{w:.current.word,pos:.current.pos,t:(.today|length)}'
for i in 1 2 3 4 5; do pkill -9 -x qs 2>/dev/null; sleep 0.6; pgrep -x qs >/dev/null || break; done
pgrep -x qs && echo "ALIVE bad" || echo "ZERO good"
rm -f /tmp/qs-word-open
( qs -c word-island >/tmp/qsword.log 2>&1 & ); sleep 4
echo "--- LOG ---"; cat /tmp/qsword.log
python3 - <<'PY'
import json,subprocess
d=json.loads(subprocess.check_output(["hyprctl","layers","-j"]))
g=[s for m,i in d.items() for lv,a in i.get("levels",{}).items() for s in a if "qs-word-island" in (s.get("namespace") or "")]
print("closed surfaces:",len(g),[(s["x"],s["y"],s["w"],s["h"]) for s in g])
PY
grim -g "0,0 900x760" /tmp/w2_closed.png && echo shot
~/.config/waybar/qs-word-toggle.sh; echo "[$(cat /tmp/qs-word-open)]"; sleep 2
G=$(python3 -c 'import json,subprocess;d=json.loads(subprocess.check_output(["hyprctl","layers","-j"]));print(next(("%d,%d %dx%d"%(s["x"],s["y"],s["w"],s["h"]) for m,i in d.items() for lv,a in i.get("levels",{}).items() for s in a if "qs-word-island" in (s.get("namespace") or "")),""))')
echo surf=$G; grim -g "${G:-120,40 460x500}" /tmp/w2_open.png && echo shot
~/.config/waybar/qs-word-toggle.sh; sleep 1.5; grim -g "0,0 900x760" /tmp/w2_closed2.png && echo shot
# jitter: geometry constant across toggles
( while :; do ~/.config/waybar/qs-word-toggle.sh; sleep 1.2; done ) & T=$!
python3 - <<'PY'
import json,subprocess,time
seen=set()
for _ in range(50):
    d=json.loads(subprocess.check_output(["hyprctl","layers","-j"]))
    for m,i in d.items():
     for lv,a in i.get("levels",{}).items():
      for s in a:
       if "qs-word-island" in (s.get("namespace") or ""): seen.add((s["w"],s["h"]))
    time.sleep(0.1)
print("unique (w,h):",sorted(seen))
PY
kill $T 2>/dev/null; [ "$(cat /tmp/qs-word-open)" = "1" ] && ~/.config/waybar/qs-word-toggle.sh
```
Expected:`word-popup.sh` 出 `{w:<word>,pos:[...],t:10}`;`qsword.log` 无 QML 错(Qt 版本 WARN + 缺文件 WARN 因 printErrors:false 应已静默,可接受);closed surfaces==1(固定 bbox);**Read `/tmp/w2_closed.png`** 无浮层;**Read `/tmp/w2_open.png`** 显示卡:hero(大词/词性/音标/释义/例句/🔊占位)+ "今日单词" + 10 词列表(当前词高亮)+ 该词性对应背景 tint;**Read `/tmp/w2_closed2.png`** 卡消失;`unique (w,h)` 只有**一个**尺寸对(无抖动)。有错按天气岛同款本机 API 修正重跑至通过。

- [ ] **Step 6: 提交**

```bash
cd /home/mhpsy/dotfiles
git add quickshell/word-island/Theme.qml quickshell/word-island/WordData.qml quickshell/word-island/WordCard.qml quickshell/word-island/shell.qml
git commit -m "feat(quickshell): word-island daemon — FileView toggle popup, static card + POS tint

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task W3: WordCard 交互 — 点列表词切换 + 🔊 发音

**Files:** Modify `quickshell/word-island/WordCard.qml`

- [ ] **Step 1: 给 WordCard 加 Process + 列表项点击 + 🔊 点击**

修改 `/home/mhpsy/dotfiles/quickshell/word-island/WordCard.qml`:在 `ColumnLayout { id: col … }` **之前**(作为 card 的直接子、与 col 同级)插入两个 `Process`:
```qml
    Process { id: pickProc; command: ["bash", "-c", "true"] }   // command set on click
    Process { id: speakProc; command: ["bash", "-c", "~/.config/waybar/word-speak.sh"] }
```
把 hero 里的 🔊 `Rectangle { id: speakBtn … }` 加 `MouseArea`(在其内部,作为最后子元素):
```qml
                Rectangle {
                    id: speakBtn
                    implicitWidth: 34; implicitHeight: 28; radius: 8
                    color: speakMA.containsMouse ? Theme.stroke : Theme.chipBg
                    Text { anchors.centerIn: parent; text: ""; font.family: Theme.glyphFont; font.styleName: Theme.glyphStyle; font.pixelSize: 15; color: Theme.fg }
                    MouseArea {
                        id: speakMA
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { speakProc.running = false; speakProc.running = true; if (card.words) card.words.refresh() }
                    }
                }
```
给今日列表 `Repeater` 的 `delegate` 根 `Rectangle { id: row … }` 加 `MouseArea`(作为 row 的最后子元素,在那个 inner `RowLayout` 之后):
```qml
                MouseArea {
                    id: rowMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        pickProc.command = ["bash", "-c", "~/.config/waybar/word-pick.sh " + row.modelData.idx]
                        pickProc.running = false
                        pickProc.running = true
                        if (card.words) card.words.refresh()
                    }
                }
```
并把 `row` 的 `color` 改为带 hover 反馈:`color: rowMA.containsMouse ? Theme.chipBg : (modelData.current ? Theme.chipBg : "transparent")`。
(`word-pick.sh <idx>` 的 idx 用 `row.modelData.idx`,即 `today[].idx`。写完 `pickProc.command` 后置 `running=false` 再 `=true` 确保即使上次同命令也重跑。`card.words.refresh()` 让卡立即重拉新当前词。)

- [ ] **Step 2: 验证交互(STRICT 单实例)**

```bash
for i in 1 2 3 4 5; do pkill -9 -x qs 2>/dev/null; sleep 0.6; pgrep -x qs >/dev/null || break; done
rm -f /tmp/qs-word-open
( qs -c word-island >/tmp/qsword.log 2>&1 & ); sleep 4
~/.config/waybar/qs-word-toggle.sh; sleep 2          # open
echo "--- current word before pick ---"; bash -c '~/.config/waybar/word-popup.sh' | jq -r '.current.word'
# 等价点击列表第 4 项(idx=3):走真实脚本路径
~/.config/waybar/word-pick.sh 3; sleep 2
echo "--- current word after pick idx=3 ---"; bash -c '~/.config/waybar/word-popup.sh' | jq -r '{w:.current.word,sel:[.today[]|select(.current)|.idx]}'
G=$(python3 -c 'import json,subprocess;d=json.loads(subprocess.check_output(["hyprctl","layers","-j"]));print(next(("%d,%d %dx%d"%(s["x"],s["y"],s["w"],s["h"]) for m,i in d.items() for lv,a in i.get("levels",{}).items() for s in a if "qs-word-island" in (s.get("namespace") or "")),""))')
grim -g "${G:-120,40 460x500}" /tmp/w3_picked.png && echo shot
echo "--- speak (dry-run validates word selection) ---"; WORDS_DRY_RUN=1 ~/.config/waybar/word-speak.sh
cat /tmp/qsword.log
~/.config/waybar/qs-word-toggle.sh   # close
```
Expected:`word-pick.sh 3` 后 `current.word` 变为今日第 4 词且 `sel:[3]`;**Read `/tmp/w3_picked.png`**:卡内高亮项已切到该词(卡 ≤2s 内经轮询 refresh 跟随);`WORDS_DRY_RUN=1 word-speak.sh` 打印 `WORD=<当前词>`(证明 🔊 走的脚本会念当前词);`qsword.log` 无 QML 错。(真实点击由用户验证;agent 侧用脚本等价路径 + 截图验证卡跟随;卡内 MouseArea→Process 的 QML 正确性由代码审查保证,运行期 `word-pick.sh`/`word-speak.sh` 真实可调用已验证。)

- [ ] **Step 3: 提交**

```bash
cd /home/mhpsy/dotfiles
git add quickshell/word-island/WordCard.qml
git commit -m "feat(quickshell): word card interactions — click word -> word-pick, speak -> word-speak

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task W4: 动效 — 今日列表阶梯入场 + 当前词辉光脉动

**Files:** Modify `quickshell/word-island/WordCard.qml`

- [ ] **Step 1: 列表项错峰入场**

在今日列表 `Repeater` 的 `delegate` 根 `Rectangle { id: row … }` 上加入场动画:用 `index` 做递增延时(`row` 需能拿到 `index`——Repeater delegate 自带 `index`)。给 `row` 加:
```qml
                opacity: 0
                transform: Translate { id: rowT; y: 8 }
                Component.onCompleted: rowIn.start()
                ParallelAnimation {
                    id: rowIn
                    NumberAnimation { target: row; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
                    NumberAnimation { target: rowT; property: "y"; from: 8; to: 0; duration: 260; easing.type: Easing.OutCubic }
                    // staggered: each row starts a bit later than the previous
                    PauseAnimation { duration: 0 }
                }
                Connections {
                    target: card
                    function onWordsChanged() {}   // delegates recreate on model change → re-run via Component.onCompleted
                }
```
错峰延时:把 `rowIn` 包一层启动延时 = `index * 35`。最简实现——把 `Component.onCompleted: rowIn.start()` 改为:
```qml
                Component.onCompleted: rowStartTimer.start()
                Timer { id: rowStartTimer; interval: row.index * 35; repeat: false; onTriggered: rowIn.start() }
```
(Repeater delegate 内 `row.index` 即列表位置;每项延后 35ms 起,形成自上而下的阶梯入场。模型刷新时 delegate 重建 → 重新跑,保持每次打开/换词都有入场。)

- [ ] **Step 2: 当前词辉光脉动(仅卡可见时跑,关闭停 → 怠速门控)**

在今日列表 delegate 的 `row` 内,叠一个发光边框 `Rectangle`(仅当前项可见且脉动);在 `row` 内最后加:
```qml
                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.accent
                    visible: row.modelData.current
                    opacity: 0
                    SequentialAnimation on opacity {
                        running: row.modelData.current && card.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.25; to: 0.9; duration: 1300; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.9; to: 0.25; duration: 1300; easing.type: Easing.InOutSine }
                    }
                }
```
(`card.visible` 来自 shell.qml `visible: opacity>0.01` —— 卡关闭后该项不可见、动画 `running:false` 停,零怠速开销,套天气岛 Ambient 门控同理。`card` 需在 WordCard 根有 `id: card`(W2 已有)。`card.visible` 在组件内即根 visible。)

- [ ] **Step 3: 验证动效(STRICT 单实例;截图 + 怠速)**

```bash
for i in 1 2 3 4 5; do pkill -9 -x qs 2>/dev/null; sleep 0.6; pgrep -x qs >/dev/null || break; done
rm -f /tmp/qs-word-open
( qs -c word-island >/tmp/qsword.log 2>&1 & ); sleep 4
~/.config/waybar/qs-word-toggle.sh; sleep 0.25
G=$(python3 -c 'import json,subprocess;d=json.loads(subprocess.check_output(["hyprctl","layers","-j"]));print(next(("%d,%d %dx%d"%(s["x"],s["y"],s["w"],s["h"]) for m,i in d.items() for lv,a in i.get("levels",{}).items() for s in a if "qs-word-island" in (s.get("namespace") or "")),""))')
grim -g "${G:-120,40 460x500}" /tmp/w4_mid.png && echo "mid-entrance shot"   # 入场中
sleep 1.2; grim -g "${G:-120,40 460x500}" /tmp/w4_settled.png && echo "settled shot"
sleep 1.0; grim -g "${G:-120,40 460x500}" /tmp/w4_pulse.png && echo "pulse-phase shot"
cat /tmp/qsword.log
~/.config/waybar/qs-word-toggle.sh; sleep 1   # close
echo "--- idle: closed, animations must be stopped (no error/no busy) ---"; cat /tmp/qsword.log | tail -3
```
Expected:`qsword.log` 无 QML 错;**Read 三图**:`w4_mid.png` 列表项处于半入场(部分淡入/上滑中,体现阶梯);`w4_settled.png` 列表完全入位、当前词有发光边框;`w4_pulse.png` 当前词发光强度与 settled 不同(脉动在跑)。文字始终可读(POS tint + 脉动不压可读性)。关闭后无新错误(动画 `running:false` 已停)。视觉不达标就地调时长/延时重跑。

- [ ] **Step 4: 提交**

```bash
cd /home/mhpsy/dotfiles
git add quickshell/word-island/WordCard.qml
git commit -m "feat(quickshell): word card animations — staggered list entrance + current-word glow pulse

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task W5: 接入 — waybar on-click + hypr 自启动

**Files:** Modify `waybar/config.jsonc`, `hypr/conf/autostart.conf`

- [ ] **Step 1: 看当前两处**

```bash
grep -n -A8 '"custom/quotes": {' /home/mhpsy/dotfiles/waybar/config.jsonc
grep -n 'daily-word\|qs -c weather-island\|qs -c word-island' /home/mhpsy/dotfiles/hypr/conf/autostart.conf
```
预期:`custom/quotes` 块的 `"on-click": "~/.config/waybar/word-island-toggle.sh"`;autostart 有 `exec-once = eww --config ~/.config/eww open daily-word` 和(天气岛留下的)`exec-once = qs -c weather-island`。

- [ ] **Step 2: 改 custom/quotes 的 on-click**

在 `waybar/config.jsonc` 的 `"custom/quotes"` 块内,把这一行
```jsonc
        "on-click": "~/.config/waybar/word-island-toggle.sh"
```
改为
```jsonc
        "on-click": "~/.config/waybar/qs-word-toggle.sh"
```
(该块其余字段 `format`/`return-type`/`exec`/`interval`/`tooltip` **全部不动**。`word-island-toggle.sh` 文件本身保留不动,只是不再被引用。)

- [ ] **Step 3: 改 autostart 的 eww daily-word 行**

在 `hypr/conf/autostart.conf` 中,把这一行
```
exec-once = eww --config ~/.config/eww open daily-word
```
整行替换为
```
exec-once = qs -c word-island
```
**`exec-once = qs -c weather-island` 行绝不动。** `eww --config ~/.config/eww` 的其它行(若有,非 daily-word)也不动。

- [ ] **Step 4: 校验 + 重启 waybar**

```bash
python3 -c 'import json,re; s=open("/home/mhpsy/dotfiles/waybar/config.jsonc").read(); d=json.loads(re.sub(r"//.*","",s)); assert d["custom/quotes"]["on-click"]=="~/.config/waybar/qs-word-toggle.sh", d["custom/quotes"]["on-click"]; assert d["custom/quotes"]["exec"]=="~/.config/waybar/quotes.sh"; print("jsonc OK; custom/quotes on-click -> qs-word-toggle.sh; exec unchanged")'
grep -n 'qs -c word-island\|qs -c weather-island\|daily-word' /home/mhpsy/dotfiles/hypr/conf/autostart.conf
~/.config/waybar/launch.sh ; sleep 2
pgrep -x waybar >/dev/null && echo "waybar running" || echo "waybar DOWN bad"
grim -g "0,0 1000x60" /tmp/w5_bar.png && echo shot
```
Expected:python 打印 OK 行;autostart 有 `exec-once = qs -c word-island`、仍有 `exec-once = qs -c weather-island`、无 `daily-word` 行;waybar 正常;**Read `/tmp/w5_bar.png`**:原生 quotes 单词胶囊仍在 bar 内(原生、融入、未变样)。失败多为逗号→修至 python 校验通过。

- [ ] **Step 5: 提交**

```bash
cd /home/mhpsy/dotfiles
git add waybar/config.jsonc hypr/conf/autostart.conf
git commit -m "feat: retire eww daily-word — custom/quotes on-click + autostart -> qs -c word-island

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task W6: 端到端验收 + 回归 + 收尾

**Files:** 无新增改动(验收;微调回对应任务文件并补提交)。

- [ ] **Step 1: 全新起两守护(STRICT)**

```bash
for i in 1 2 3 4 5; do pkill -9 -x qs 2>/dev/null; sleep 0.6; pgrep -x qs >/dev/null || break; done
rm -f /tmp/qs-word-open
( qs -c weather-island >/tmp/qsw.log 2>&1 & ); ( qs -c word-island >/tmp/qsword.log 2>&1 & ); sleep 5
cat /tmp/qsword.log; echo "---"; cat /tmp/qsw.log | tail -2
pgrep -x qs && echo "qs daemons alive"; ~/.config/waybar/launch.sh; sleep 2; pgrep -x waybar >/dev/null && echo "waybar alive"
```
Expected:两 log 无 QML 错;qs 进程在(应有两个,weather + word);waybar 在。

- [ ] **Step 2: 真实路径验收(点原生胶囊 → 词卡;再点 → 收)**

由用户点 waybar 单词胶囊验证;agent 用 toggle 脚本等价驱动 + 截图:
```bash
~/.config/waybar/qs-word-toggle.sh; echo "[$(cat /tmp/qs-word-open)]"; sleep 2
G=$(python3 -c 'import json,subprocess;d=json.loads(subprocess.check_output(["hyprctl","layers","-j"]));print(next(("%d,%d %dx%d"%(s["x"],s["y"],s["w"],s["h"]) for m,i in d.items() for lv,a in i.get("levels",{}).items() for s in a if "qs-word-island" in (s.get("namespace") or "")),""))')
echo surf=$G; grim -g "${G:-120,40 460x500}" /tmp/w6_open.png && echo open-shot
~/.config/waybar/qs-word-toggle.sh; sleep 1.5; grim -g "0,0 1000x760" /tmp/w6_closed.png && echo closed-shot
```
**Read 两图**:`w6_open.png` 原生胶囊在 bar 内 + 其下方 Quickshell 词卡(hero/今日列表/POS背景/阶梯入场已settle/当前词脉动,文字可读);`w6_closed.png` 卡消失、bar 完整、无浮层。

- [ ] **Step 3: 切词同步 + 关闭态零死区**

```bash
~/.config/waybar/qs-word-toggle.sh; sleep 2
b=$(bash -c '~/.config/waybar/word-popup.sh' | jq -r '.current.word')
~/.config/waybar/word-pick.sh 5; sleep 2
a=$(bash -c '~/.config/waybar/word-popup.sh' | jq -r '.current.word')
echo "before=$b after-pick5=$a (应不同, a=今日第6词)"
WORDS_DRY_RUN=1 ~/.config/waybar/word-speak.sh
~/.config/waybar/qs-word-toggle.sh; sleep 1
python3 -c 'import json,subprocess;d=json.loads(subprocess.check_output(["hyprctl","layers","-j"]));g=[s for m,i in d.items() for lv,a in i.get("levels",{}).items() for s in a if "qs-word-island" in (s.get("namespace") or "")];print("closed:",len(g),[(s["w"],s["h"]) for s in g])'
```
Expected:pick 后 `current.word` 改变(卡 ≤2s 跟随,W3 已验);`WORDS_DRY_RUN` 打印当前词;关闭态 surface 即使在(固定 bbox)其 mask 为空 → 穿透零死区(结合 w6_closed 无浮层即过)。

- [ ] **Step 4: 回归 — weather-island / eww 回退 / 数据脚本未动**

```bash
python3 -c 'import json,subprocess;d=json.loads(subprocess.check_output(["hyprctl","layers","-j"]));ns=set(s.get("namespace") for m,i in d.items() for lv,a in i.get("levels",{}).items() for s in a);print("weather-island surface present:", any(x and "qs-weather-island" in x for x in ns))'
~/.config/waybar/qs-weather-toggle.sh; sleep 2; python3 -c 'import json,subprocess;d=json.loads(subprocess.check_output(["hyprctl","layers","-j"]));print("weather card opens:", any("qs-weather-island" in (s.get("namespace") or "") for m,i in d.items() for lv,a in i.get("levels",{}).items() for s in a))'; ~/.config/waybar/qs-weather-toggle.sh
test -f /home/mhpsy/dotfiles/waybar/word-island-toggle.sh && echo "eww word toggle (fallback) retained"
git -C /home/mhpsy/dotfiles status --porcelain | grep -E '(\.config/)?eww/|weather-island|weather.*\.sh|word-popup|word-pick|word-speak|words-lib|quotes\.sh|wordlist' && echo "WARN touched forbidden" || echo "forbidden untouched OK"
git -C /home/mhpsy/dotfiles diff --stat 8696adb..HEAD
git -C /home/mhpsy/dotfiles log --oneline -8
```
Expected:weather-island 守护仍在且可开卡(未受影响);`word-island-toggle.sh` 仍在(eww 回退);**禁区未动**;`git diff 8696adb..HEAD --stat` 仅:`waybar/qs-word-toggle.sh`(新)、`quickshell/word-island/{Theme,WordData,WordCard,shell}.qml`(新)、`waybar/config.jsonc`、`hypr/conf/autostart.conf`,加本计划文档。预存在脏文件仍未提交。

- [ ] **Step 5: qs 守护挂掉降级**

```bash
for i in 1 2 3 4 5; do pkill -9 -x qs 2>/dev/null; sleep 0.6; pgrep -x qs >/dev/null || break; done
sleep 1; ~/.config/waybar/launch.sh; sleep 2; grim -g "0,0 1000x60" /tmp/w6_qsdead.png && echo shot
( qs -c weather-island >/tmp/qsw.log 2>&1 & ); ( qs -c word-island >/tmp/qsword.log 2>&1 & ); sleep 4
[ "$(cat /tmp/qs-word-open 2>/dev/null)" = "1" ] && ~/.config/waybar/qs-word-toggle.sh; pgrep -x qs && echo "both daemons restarted (closed)"
```
Expected:**Read `/tmp/w6_qsdead.png`**:qs 全挂时,原生 quotes 单词胶囊仍显示/轮换单词(bar 不失单词,比 eww 版严格更健壮)。验毕重启两守护,word 状态复位关。

- [ ] **Step 6: 完成开发分支**

REQUIRED SUB-SKILL:用 superpowers:finishing-a-development-branch。注意:本仓库无单测,"测试通过"= 上述端到端验收通过;normal repo;分支 `feat/word-island`;`main` 与本分支**已分叉**(见 [[weather-island-hybrid-state]] 内存:feat 是近超集,main 有 ~44 行独有 word 改动)——收尾选项里**默认推荐"保持现状不合并"**或谨慎处理;预存在脏文件非本工作产物不纳入;`reset --hard`/`merge`/`pull` 这类对 main 的破坏性或意外操作**必须先跟用户确认**(approval 不跨上下文)。

---

## Self-Review

**Spec 覆盖核对(对 `2026-05-19-quickshell-word-island-design.md`):**
- 混合架构(原生 quotes 胶囊 + QS word-island 弹出卡):W2(daemon)+W5(on-click/autostart)。✓
- Model A 纯切换 + 状态文件/FileView:W1(qs-word-toggle.sh)+W2 shell.qml(FileView /tmp/qs-word-open,套天气岛异步范式)。✓
- 保留交互(点词 word-pick / 🔊 word-speak):W3(MouseArea→Process,idx=today[].idx;speak 无参)。✓
- 卡内动效(spring 弹入 + 阶梯入场 + 当前词辉光脉动):弹入 W2 shell.qml(复用);阶梯入场+脉动 W4(怠速门控 running:card.visible)。✓
- POS 背景:W2 Theme.posTint + WordCard tint 层 + ColorAnimation。✓
- 数据刷新(open 轮询 word-popup.sh + 点词/发音后立即重拉):W2 WordData(Timer running:active,refresh())+W3(交互后 card.words.refresh())。✓
- 复用脚本不改:全程"绝不触碰"清单含 word*/quotes/words-lib/wordlist;调用经 Process/exec。✓
- eww daily-word 退役、文件保留、autostart 换 qs -c word-island、weather-island 不动:W5 + 回归 W6 Step4。✓
- 双 island 各自 qs、互不影响:W6 Step1/Step4 验 weather-island 仍工作。✓
- 固定 surface / 关闭零足迹 / 无抖动:W2 shell.qml(implicit 绑稳定 card 尺寸、mask null)+ W2 Step5 几何恒定验证。✓
- 降级(状态文件缺/坏→关、word-popup 失败→ok=false、qs 挂→原生胶囊仍显词):WordData catch + W6 Step5。✓
- 验证法(无单测;qs+hyprctl+grim+Read;STRICT pgrep -x qs;两守护并存处理):每任务验证步 + 执行须知。✓
- 非目标(不重构 waybar/不引 IPC/不合并双进程/不动 weather):非目标即范围,计划未越界。✓

**占位扫描:** 无 TBD/TODO;每写码步给完整 QML/脚本;FileView 沿用天气岛已证写法(非占位);POS 色值具体(实现期可微调是 tuning 非占位);验证步给确切命令与预期。✓

**类型/命名一致性:** 状态文件 `/tmp/qs-word-open`、脚本 `qs-word-toggle.sh`、namespace `qs-word-island` 全程一致(且与 weather 的 `qs-word-island`≠`qs-weather-island` 区分);`WordData` 暴露 `ok/current/today/active/refresh()` 在 W2 定义,W3 用 `card.words.refresh()`、W4 用 `card.visible`/`row.modelData.current` 一致;`WordCard` 根 `id: card`、`property var words`、`words: words` 绑定在 W2 定义,W3/W4 引用一致;`row.modelData.idx` 喂 `word-pick.sh`(= `today[].idx`,与脚本 `p` 0 基位置契约一致);base 提交 `8696adb`(spec 提交)为 W6 diff 基线;Theme.posTint/tintFor 在 W2 定义、W2 WordCard 用、与 spec 一致。✓
