# 混合天气岛(waybar 原生胶囊 + Quickshell 点击弹出卡)Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把天气岛改成混合形态:收起态回归 waybar 原生 `custom/weather` 模块(完美融入),点击它经状态文件触发常驻 Quickshell 守护进程在 bar 下方弹出已有的富详情卡(Model A 纯切换)。

**Architecture:** waybar 原生模块画胶囊(`exec weather.sh`,顺带恢复 waybar 驱动缓存);`on-click` 跑新脚本翻转 `/tmp/qs-weather-open`;Quickshell `qs -c weather-island` 守护进程用 `FileView` 监听该文件,固定尺寸 layer-shell surface 内显隐已有的 `Card`(含 `Ambient`)。绝不把动画绑到 Wayland surface 尺寸(前身抖动根因)。复用 `Theme/WeatherData/Card/Ambient`,删 `Pill.qml` 及全部 hover/收起状态机。

**Tech Stack:** Quickshell 0.3.0(Qt6 QML:QtQuick / Quickshell / Quickshell.Wayland / Quickshell.Io)、bash、waybar(jsonc)。

关联 spec:`docs/superpowers/specs/2026-05-19-hybrid-weather-island-design.md`

---

## 重要执行须知(全程适用)

- **本机 = 用户活跃 Hyprland 会话**(`WAYLAND_DISPLAY` 已设、`hyprctl`/`grim` 可用)。**无单测框架**:验证 = 跑 `qs` + `hyprctl layers -j` 看表面 + `grim` 截图后用 Read 工具看图 + 看 `qs` stderr。
- **STRICT 单实例纪律**:`pgrep -f 'qs -c weather-island'` 会自匹配 shell 包装字符串(假阳性)——**一律用 `pgrep -x qs`**。每次起 `qs` 前:
  ```bash
  for i in 1 2 3 4 5; do pkill -9 -x qs 2>/dev/null; sleep 0.6; pgrep -x qs >/dev/null || break; done
  pgrep -x qs && echo "ALIVE bad" || echo "ZERO good"
  ```
  起一个后确认**恰好 1 个**表面再继续。
- **本机已查证的 Quickshell 0.3.0 API(以此为准,计划示例若与本机报错以本机修正并记录)**:根 `ShellRoot`;窗口 **`WlrLayershell`**(`PanelWindow` 在本机 `isCreatable:false`),**直属性**:`layer: WlrLayer.Overlay`、`keyboardFocus: WlrKeyboardFocus.None`、`namespace: "qs-weather-island"`、`color`、`exclusionMode: ExclusionMode.Ignore`(枚举值 Normal/Ignore/Auto,经 `import Quickshell` 可用)、`anchors{top;left}`、`margins.left/top`、`implicitWidth/implicitHeight`、`mask`(类型 `Quickshell/Region`,用 `Region { item: <Item> }`);`Theme` 是 **Quickshell 原生 `Singleton`**(`pragma Singleton` + `import Quickshell` + `Singleton{}` 根,**无 qmldir** —— 有 qmldir 会破坏同目录组件自动发现);同目录组件用 `import "."`;`QtQuick.Particles` 本机**无** `qrc:///particleresources/glowdot.png`(`Ambient.qml` 已用 `ItemParticle`+`Rectangle` delegate 兜底,**不要动**);qs 表面 y 会比 anchor 多约 40(Hyprland waybar 偏移),属正常。
- **抖动根因教训(铁律)**:**绝不**把会变化/动画的值绑到 `WlrLayershell.implicitWidth/implicitHeight`(那是真实 Wayland surface 尺寸,每帧 reconfigure → 剧烈抖动)。surface 尺寸必须是稳定常量级表达式;动画只作用于固定 surface 内的 QML 内容(opacity/scale)。
- dotfiles 仓库 `/home/mhpsy/dotfiles`,当前分支 `feat/word-island`(在此分支提交,**不要切分支**)。提交只 `git add` 明确文件,**绝不** `git add -A`/`git add .`。提交信息结尾带 `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`。
- **仓库存在与本工作无关的预存在脏文件,绝不 stage/提交**:` M eww/colors.scss`、` M matugen/config.toml`、`?? matugen/templates/quickshell-colors.json`、`?? quickshell/colors.json`、`?? .claude/`。
- **绝不触碰**:`~/.config/eww`、`hypr/conf/autostart.conf` 的 `exec-once = eww --config ~/.config/eww open daily-word`(word-island)行、`waybar/word-island-toggle.sh`、`waybar/weather-island-toggle.sh`(eww 天气回退脚本,保留不动不复用)、`waybar/eww/*`、`waybar/weather.sh`、`waybar/weather-eww.sh`、`Theme.qml`/`WeatherData.qml`/`Ambient.qml`(原样复用)、上面的预存在脏文件。
- 每次跑 `qs` 用于验证后,若该任务是最终交付相关,保持 `qs` 守护进程运行到 Task 5。

## File Structure

| 文件 | 责任 | 改动 |
|---|---|---|
| `waybar/qs-weather-toggle.sh` | 翻转 `/tmp/qs-weather-open`(0/1) | **新增** |
| `quickshell/weather-island/shell.qml` | FileView 驱动的开/关弹出卡;固定 surface;关闭态零足迹 | **重写** |
| `quickshell/weather-island/Pill.qml` | (原收起胶囊,改 waybar 原生) | **删除** |
| `quickshell/weather-island/Card.qml` | 详情卡 | 仅摘除无用的 `HoverHandler { id: cardHover }` |
| `quickshell/weather-island/Theme.qml` `WeatherData.qml` `Ambient.qml` | 主题/数据/氛围 | **不动** |
| `waybar/config.jsonc` | 恢复 `custom/weather` 原生模块 | **修改**(加回数组项 + 定义块,on-click 指向新脚本) |
| `hypr/conf/autostart.conf` | `exec-once = qs -c weather-island` 已存在 | **不改**(仅 Task 5 验证其在) |

仓库内建,经符号链接 `~/.config/quickshell → dotfiles/quickshell`(前身已建)、`~/.config/waybar → dotfiles/waybar` 生效。

---

## Task 1: FileView API 查证 + qs-weather-toggle.sh + 状态文件契约

**Files:**
- Create: `/home/mhpsy/dotfiles/waybar/qs-weather-toggle.sh`

- [ ] **Step 1: 查证本机 Quickshell.Io FileView API(后续 Task 2 依据)**

Run 并把输出记入本任务笔记:
```bash
ls /usr/lib/qt6/qml/Quickshell/Io 2>/dev/null
qf=$(find /usr/lib/qt6/qml/Quickshell -name '*.qmltypes' 2>/dev/null | xargs grep -l -i 'FileView' 2>/dev/null); echo "$qf"
grep -n -A40 'name: "FileView"' /usr/lib/qt6/qml/Quickshell/Io/*.qmltypes 2>/dev/null | sed -n '1,80p'
grep -nEi '"path"|"text"|"data"|"blockLoading"|"watchChanges"|"preload"|"reload"|"loaded"|"fileChanged"|"adapter"|Changed"' /usr/lib/qt6/qml/Quickshell/Io/*.qmltypes 2>/dev/null | grep -i fileview -A0 | head -40
```
确认并记录:① `FileView` 是否存在、导入路径(应为 `Quickshell.Io`);② 读取文件内容的属性/方法名(`text()` 方法?`text` 属性?`data`?);③ 监听变化的属性/信号(`watchChanges: true`?`onFileChanged`?`onTextChanged`?`reload()`?);④ 路径属性名(`path`)。**若 `FileView` 不存在或不适合**(无法监听变化),记录"用退路":`Timer { interval: 250; repeat: true; running: true; onTriggered: catProc.running = true }` + `Process { id: catProc; command:["cat","/tmp/qs-weather-open"]; stdout: StdioCollector{ id:c; waitForEnd:true; onStreamFinished: root.open = (c.text.trim()==="1") } }`(`StdioCollector` 信号 `streamFinished`、读 `id.text` 已是本机查证写法)。Task 2 以本机查到的为准。

- [ ] **Step 2: 写 qs-weather-toggle.sh**

Create `/home/mhpsy/dotfiles/waybar/qs-weather-toggle.sh`:
```sh
#!/bin/sh
# Toggle the Quickshell weather card open-state file. Missing/non-"1" => treat
# as currently closed, so this opens it (writes "1"). on-click target of the
# waybar custom/weather module.
f=/tmp/qs-weather-open
if [ "$(cat "$f" 2>/dev/null)" = "1" ]; then
    printf 0 > "$f"
else
    printf 1 > "$f"
fi
```

- [ ] **Step 3: 可执行 + 验证翻转契约**

```bash
chmod +x /home/mhpsy/dotfiles/waybar/qs-weather-toggle.sh
rm -f /tmp/qs-weather-open
~/.config/waybar/qs-weather-toggle.sh; echo "after 1st: [$(cat /tmp/qs-weather-open)]"   # expect [1]
~/.config/waybar/qs-weather-toggle.sh; echo "after 2nd: [$(cat /tmp/qs-weather-open)]"   # expect [0]
~/.config/waybar/qs-weather-toggle.sh; echo "after 3rd: [$(cat /tmp/qs-weather-open)]"   # expect [1]
```
Expected:依次 `[1]`、`[0]`、`[1]`(缺失→视为关→开为 `1`;`1`→`0`;`0`→`1`)。`~/.config/waybar` 是指向 `dotfiles/waybar` 的符号链接,故 `~/.config/waybar/qs-weather-toggle.sh` 即新脚本。若不符,修脚本至契约成立。

- [ ] **Step 4: 提交**

```bash
cd /home/mhpsy/dotfiles
git add waybar/qs-weather-toggle.sh
git commit -m "feat(waybar): qs-weather-toggle.sh — flip /tmp/qs-weather-open for QS card

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```
(`/tmp/qs-weather-open` 是运行期状态文件,不入库。)

---

## Task 2: 重写 shell.qml — FileView 驱动的开/关弹出卡(固定 surface)

**Files:**
- Modify(整文件替换): `/home/mhpsy/dotfiles/quickshell/weather-island/shell.qml`

> 前置:Task 1 已查到本机 `FileView` 真实 API。下方示例用常见 Quickshell `FileView` 写法(`path` + `text()` + `watchChanges`/`onTextChanged`);**若 Task 1 查到的属性/信号名不同,据本机改**;若 `FileView` 不可用,用 Task 1 Step 1 记录的 `Timer`+`Process cat` 退路实现同一契约(`root.open` = 文件内容 trim 后 == `"1"`)。

- [ ] **Step 1: 整文件替换 shell.qml**

Create/replace `/home/mhpsy/dotfiles/quickshell/weather-island/shell.qml`:
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
        margins.left: 120          // 近似 x:卡为瞬态下拉面板,目视靠近天气模块即可,可调
        margins.top: 40            // bar 高 ~40 → 卡悬于 bar 正下方
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        layer: WlrLayer.Overlay
        keyboardFocus: WlrKeyboardFocus.None
        namespace: "qs-weather-island"

        // 固定 Wayland surface = 卡片 bbox。绝不动画、绝不加 Behavior。
        // 仅随天气数据刷新(card.implicitHeight,~15min)偶变,交互期恒定 → 抖动结构上不可能。
        implicitWidth: card.implicitWidth
        implicitHeight: card.implicitHeight

        // 输入区:打开=卡片矩形(可交互);关闭=空 Region → 大透明 surface 100% 穿透、零死区、零足迹。
        mask: Region { item: root.open ? card : null }

        WeatherData { id: wx }

        // 开/关状态:监听 /tmp/qs-weather-open(由 waybar on-click 的 qs-weather-toggle.sh 翻转)
        property bool open: false
        FileView {
            id: stateFile
            path: "/tmp/qs-weather-open"
            watchChanges: true
            onTextChanged: win.open = (text.trim() === "1")
            onLoadedChanged: win.open = (text.trim() === "1")
        }

        Card {
            id: card
            wx: wx
            visible: opacity > 0.01
            opacity: win.open ? 1 : 0
            scale: win.open ? 1 : 0.96
            transformOrigin: Item.Top
            // 动画只作用于卡片本身(纯视觉、固定透明 surface 内、Card 自带 clip:true)。
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on scale   { SpringAnimation { spring: 4.0; damping: 0.5; epsilon: 0.01 } }
        }
    }
}
```
按本机修正点(以 Task 1 查证为准):
- `FileView` 的内容读取:示例用 `text`(属性)与 `onTextChanged`;若本机是 `text()` 方法或需 `reload()`/`onFileChanged`,据实改;`watchChanges` 若非该名(可能 `blockLoading`/`preload`/无)据实改;保证"文件变 → `win.open` 跟着变"。
- 退路(FileView 不可用):删 `FileView` 块,换:
  ```qml
  property bool open: false
  Process { id: catProc; command: ["cat", "/tmp/qs-weather-open"]
      stdout: StdioCollector { id: sc; waitForEnd: true
          onStreamFinished: win.open = (sc.text.trim() === "1") } }
  Timer { interval: 250; repeat: true; running: true; triggeredOnStart: true
      onTriggered: catProc.running = true }
  ```
- `Card` 的隐式尺寸:`Card.qml` 现有 `implicitWidth: 460`、`implicitHeight: col.implicitHeight + 40`(稳定,仅随数据偶变)——`win.implicitWidth/Height` 绑这俩**不加任何动画**,符合铁律。

- [ ] **Step 2: 跑起来 —— 默认关闭态零足迹(STRICT 单实例)**

```bash
for i in 1 2 3 4 5; do pkill -9 -x qs 2>/dev/null; sleep 0.6; pgrep -x qs >/dev/null || break; done
pgrep -x qs && echo "ALIVE bad" || echo "ZERO good"
rm -f /tmp/qs-weather-open      # 缺失 → 关闭
( qs -c weather-island >/tmp/qs.log 2>&1 & ); sleep 4
echo "--- LOG ---"; cat /tmp/qs.log
python3 - <<'PY'
import json,subprocess
d=json.loads(subprocess.check_output(["hyprctl","layers","-j"]))
g=[s for m,i in d.items() for lv,a in i.get("levels",{}).items() for s in a if "qs-weather" in (s.get("namespace") or "")]
print("surfaces:",len(g),[(s["x"],s["y"],s["w"],s["h"]) for s in g])
PY
grim -g "0,0 900x760" /tmp/t2_closed.png && echo shot
```
Expected:`qs.log` 无 QML 错误(仅 Qt 6.11.0-vs-6.11.1 WARN 是环境既有,可接受);恰好 1 个表面(固定 bbox,如 460x631,位于 bar 下方);**用 Read 工具看 `/tmp/t2_closed.png`:不应有任何可见浮层/卡片**(关闭态 Card opacity 0),桌面/其它窗口正常。若报 `FileView`/属性/类型错 → 按 Task 1 本机 API 修正(或切退路),重跑至无错。

- [ ] **Step 3: 翻转状态文件 → 卡片弹出(STRICT 单实例已在跑,直接翻文件)**

```bash
~/.config/waybar/qs-weather-toggle.sh; echo "open=[$(cat /tmp/qs-weather-open)]"; sleep 1   # → 1
G=$(python3 - <<'PY'
import json,subprocess
d=json.loads(subprocess.check_output(["hyprctl","layers","-j"]))
for m,i in d.items():
 for lv,a in i.get("levels",{}).items():
  for s in a:
   if "qs-weather" in (s.get("namespace") or ""): print("%d,%d %dx%d"%(s["x"],s["y"],s["w"],s["h"]))
PY
)
echo "surf=$G"; grim -g "${G:-120,40 460x631}" /tmp/t2_open.png && echo shot
~/.config/waybar/qs-weather-toggle.sh; echo "open=[$(cat /tmp/qs-weather-open)]"; sleep 1   # → 0
grim -g "${G:-120,40 460x631}" /tmp/t2_closed2.png && echo shot
```
Expected:用 Read 看 `/tmp/t2_open.png` —— bar 下方出现完整卡(hero/九宫格/逐时/三天 + 当前天气 `Ambient`,数据真实、文字可读);`/tmp/t2_closed2.png` —— 卡已消失。`qs.log` 仍无错。若翻文件后卡不出现 → FileView 监听没生效,按 Task 1 本机 API 修正(或退路),重跑本步至开/关都对。

- [ ] **Step 4: 无抖动验证(surface 几何在开/关全程恒定)**

```bash
( while :; do ~/.config/waybar/qs-weather-toggle.sh; sleep 1.2; done ) & TPID=$!
python3 - <<'PY'
import json,subprocess,time
seen=set()
for _ in range(60):
    d=json.loads(subprocess.check_output(["hyprctl","layers","-j"]))
    for m,i in d.items():
     for lv,a in i.get("levels",{}).items():
      for s in a:
       if "qs-weather" in (s.get("namespace") or ""): seen.add((s["w"],s["h"]))
    time.sleep(0.1)
print("unique (w,h) over ~6s of toggling:", sorted(seen))
PY
kill $TPID 2>/dev/null
~/.config/waybar/qs-weather-toggle.sh 2>/dev/null; [ "$(cat /tmp/qs-weather-open)" = "1" ] && ~/.config/waybar/qs-weather-toggle.sh   # 复位到关
```
Expected:`unique (w,h)` 只有**一个**尺寸对(固定 bbox)——证明 surface 全程不变、无前身那种抖动。(打开/关闭只改 mask 与 Card opacity/scale,不改 surface。)

- [ ] **Step 5: 提交**

```bash
cd /home/mhpsy/dotfiles
git add quickshell/weather-island/shell.qml
git commit -m "feat(quickshell): rewrite shell.qml as FileView-driven toggle popup (fixed surface, no jitter)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 删除 Pill.qml + Card.qml 摘除无用 hover 钩子

**Files:**
- Delete: `/home/mhpsy/dotfiles/quickshell/weather-island/Pill.qml`
- Modify: `/home/mhpsy/dotfiles/quickshell/weather-island/Card.qml`

- [ ] **Step 1: 删 Pill.qml**

```bash
cd /home/mhpsy/dotfiles
git rm quickshell/weather-island/Pill.qml
```
(收起胶囊已由 waybar 原生模块承担,`Pill.qml` 不再被任何文件引用——Task 2 重写后的 shell.qml 已无 `Pill`。)

- [ ] **Step 2: 摘除 Card.qml 中无用的 cardHover**

在 `/home/mhpsy/dotfiles/quickshell/weather-island/Card.qml` 中删除这一行(前身为自动收起加的、现已无引用):
```qml
        HoverHandler { id: cardHover }
```
(精确定位:`grep -n 'HoverHandler' quickshell/weather-island/Card.qml` 找到该行;它应在卡片 `Rectangle`/内容块内、无其它逻辑依赖。删除整行。不要改 Card 其它任何内容——`implicitWidth:460`、`implicitHeight: col.implicitHeight+40`、`clip:true`、gradient、hero/九宫格/逐时/三天、`Ambient` 接入全部保持。)
若 `grep` 显示 Card.qml 已无 `HoverHandler`(例如前身结构里 cardHover 实际在别处),则本步无需改 Card.qml,记录"Card.qml 无 cardHover,跳过"。

- [ ] **Step 3: 跑起来确认无回归(STRICT 单实例)**

```bash
for i in 1 2 3 4 5; do pkill -9 -x qs 2>/dev/null; sleep 0.6; pgrep -x qs >/dev/null || break; done
pgrep -x qs && echo "ALIVE bad" || echo "ZERO good"
rm -f /tmp/qs-weather-open
( qs -c weather-island >/tmp/qs.log 2>&1 & ); sleep 4
cat /tmp/qs.log
~/.config/waybar/qs-weather-toggle.sh; sleep 1     # 开
G=$(python3 - <<'PY'
import json,subprocess
d=json.loads(subprocess.check_output(["hyprctl","layers","-j"]))
for m,i in d.items():
 for lv,a in i.get("levels",{}).items():
  for s in a:
   if "qs-weather" in (s.get("namespace") or ""): print("%d,%d %dx%d"%(s["x"],s["y"],s["w"],s["h"]))
PY
)
grim -g "${G:-120,40 460x631}" /tmp/t3_open.png && echo shot
~/.config/waybar/qs-weather-toggle.sh   # 复位关
```
Expected:`qs.log` 无 QML 错误(尤其无 `Pill is not a type`/`cardHover is not defined`);用 Read 看 `/tmp/t3_open.png` —— 卡片照常完整渲染。有错按本机改(多半是仍有悬空引用)。

- [ ] **Step 4: 提交**

```bash
cd /home/mhpsy/dotfiles
git add -u quickshell/weather-island/Card.qml quickshell/weather-island/Pill.qml
git commit -m "refactor(quickshell): drop Pill.qml and unused cardHover (pill now native waybar)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```
(`git add -u <两文件>` 只暂存这两文件的修改/删除,**不**用 `git add -A`。若 Step 2 跳过未改 Card.qml,则 `git add quickshell/weather-island/Pill.qml` 仅提交删除。)

---

## Task 4: waybar 恢复 custom/weather 原生模块(on-click 接 toggle)

**Files:**
- Modify: `/home/mhpsy/dotfiles/waybar/config.jsonc`

- [ ] **Step 1: 看当前 modules-left 与插入点**

```bash
grep -n '"custom/date"\|"custom/sp-entertainment"\|"custom/quotes"\|// Quotes\|// Weather\|custom/weather' /home/mhpsy/dotfiles/waybar/config.jsonc
```
预期:`modules-left` 含 `"custom/date",` 与紧随的 `"custom/sp-entertainment",`(前身 Task 7 把 `"custom/weather",` 从两者之间删了);定义区有 `// Quotes` / `"custom/quotes": {`(前身把 `// Weather` + `custom/weather` 块删在其前)。当前应**无** `custom/weather`。

- [ ] **Step 2: 在 modules-left 加回 "custom/weather"**

在 `config.jsonc` 的 `"modules-left"` 数组里,`"custom/date",` 之后、`"custom/sp-entertainment",` 之前,插入一行(保持原缩进):
```jsonc
        "custom/weather",
```

- [ ] **Step 3: 加回 custom/weather 定义块(on-click 指向新脚本)**

在 `config.jsonc` 中 `// Quotes` 行(及其下 `"custom/quotes": {`)之前,插入(原缩进;块尾逗号保持 JSONC 合法):
```jsonc
    // Weather
    "custom/weather": {
        "format": "{}",
        "return-type": "json",
        "exec": "~/.config/waybar/weather.sh",
        "interval": 900,
        "tooltip": false,
        "on-click": "~/.config/waybar/qs-weather-toggle.sh"
    },

```
(与前身被删块逐字一致,唯一差异:`on-click` 由旧 `weather-island-toggle.sh` 改为新 `qs-weather-toggle.sh`。`weather.sh`/`weather-eww.sh` 不动。)

- [ ] **Step 4: 校验 JSONC 合法 + custom/weather 在**

```bash
python3 -c 'import json,re; s=open("/home/mhpsy/dotfiles/waybar/config.jsonc").read(); d=json.loads(re.sub(r"//.*","",s)); assert "custom/weather" in d, "missing def"; assert "custom/weather" in d["modules-left"], "missing in modules-left"; assert d["custom/weather"]["on-click"]=="~/.config/waybar/qs-weather-toggle.sh"; assert "custom/quotes" in d and "custom/date" in d; print("jsonc OK, custom/weather restored, on-click -> qs-weather-toggle.sh")'
```
Expected:打印 `jsonc OK ...`。失败多半逗号问题,修至通过(整体仍合法 JSON、相邻块未被破坏)。

- [ ] **Step 5: 重启 waybar,确认原生胶囊融入**

```bash
~/.config/waybar/launch.sh ; sleep 2
pgrep -x waybar >/dev/null && echo "waybar running" || echo "waybar DOWN (bad)"
grim -g "0,0 900x60" /tmp/t4_bar.png && echo shot
```
Expected:waybar 正常;用 Read 看 `/tmp/t4_bar.png` —— 左侧出现**原生**天气胶囊(图标+温度),与相邻模块同行、同风格、**完美对齐无悬浮**(这正是本次返工目标)。无关于 `custom/weather` 的报错。

- [ ] **Step 6: 提交**

```bash
cd /home/mhpsy/dotfiles
git add waybar/config.jsonc
git commit -m "feat(waybar): restore native custom/weather pill — on-click toggles QS card

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 端到端验收 + 回归 + 收尾

**Files:** 无新增改动(验收;微调回对应任务文件并补提交)。

- [ ] **Step 1: 确认 autostart 守护进程行在 + 全新起 qs(STRICT 单实例)**

```bash
grep -n 'exec-once = qs -c weather-island\|daily-word' /home/mhpsy/dotfiles/hypr/conf/autostart.conf
for i in 1 2 3 4 5; do pkill -9 -x qs 2>/dev/null; sleep 0.6; pgrep -x qs >/dev/null || break; done
rm -f /tmp/qs-weather-open
( qs -c weather-island >/tmp/qs.log 2>&1 & ); sleep 5
cat /tmp/qs.log; pgrep -x qs && echo "qs daemon alive"
```
Expected:autostart 有 `exec-once = qs -c weather-island`(前身 Task 7 已加,不改)且 `daily-word` 行原样在;`qs.log` 无 QML 错误;qs 守护进程存活。

- [ ] **Step 2: 真实路径验收 —— 点击原生胶囊开/关**

由用户点击 waybar 原生天气胶囊验证;agent 侧用 toggle 脚本等价驱动并截图:
```bash
~/.config/waybar/qs-weather-toggle.sh; echo "[$(cat /tmp/qs-weather-open)]"; sleep 1
G=$(python3 - <<'PY'
import json,subprocess
d=json.loads(subprocess.check_output(["hyprctl","layers","-j"]))
for m,i in d.items():
 for lv,a in i.get("levels",{}).items():
  for s in a:
   if "qs-weather" in (s.get("namespace") or ""): print("%d,%d %dx%d"%(s["x"],s["y"],s["w"],s["h"]))
PY
)
echo "surf=$G"; grim -g "${G:-120,40 460x631}" /tmp/t5_open.png && echo shot-open
~/.config/waybar/qs-weather-toggle.sh; echo "[$(cat /tmp/qs-weather-open)]"; sleep 1
grim -g "0,0 900x760" /tmp/t5_closed.png && echo shot-closed
```
Expected(Read 两图):`t5_open.png` —— 原生胶囊在 bar 内 + 其下方 Quickshell 富卡(真实数据、`Ambient`、可读);`t5_closed.png` —— 卡消失、无任何浮层、bar 完整可见。`qs.log` 无错。问题就地回对应任务文件修正并补提交。

- [ ] **Step 3: 关闭态零死区 / 穿透验证**

```bash
[ "$(cat /tmp/qs-weather-open)" = "1" ] && ~/.config/waybar/qs-weather-toggle.sh   # 确保关
sleep 1
python3 - <<'PY'
import json,subprocess
d=json.loads(subprocess.check_output(["hyprctl","layers","-j"]))
g=[s for m,i in d.items() for lv,a in i.get("levels",{}).items() for s in a if "qs-weather" in (s.get("namespace") or "")]
print("closed-state qs-weather surfaces:", len(g), [(s["w"],s["h"]) for s in g])
PY
```
Expected:关闭态即使 surface 存在(固定 bbox),其 `mask` 为空 → 指针穿透。结合 Step 2 的 `t5_closed.png` 无浮层即验收通过(对比前身:无 eww 那种死区、无悬浮丑块)。说明 mask 关闭态生效。

- [ ] **Step 4: 抓取由 waybar 驱动(回归原始模型)**

```bash
stat -c '%Y %n' /tmp/waybar-openmeteo.json 2>/dev/null || echo "no cache"
rm -f /tmp/waybar-openmeteo.json
bash -c '~/.config/waybar/weather.sh >/dev/null 2>&1'   # 等价 waybar 的 exec(custom/weather interval)
ls -l /tmp/waybar-openmeteo.json && echo "cache recreated by weather.sh (waybar-driven)"
bash -c '~/.config/waybar/weather-eww.sh' | jq '.ok'
```
Expected:缓存被 `weather.sh` 重建、`.ok` 为 `true`。说明恢复 `custom/weather` 后 waybar 重新驱动抓取(本设计无需 Quickshell 接管抓取);Quickshell 卡只读缓存。

- [ ] **Step 5: 回归 —— word-island / eww 回退 / 复用脚本未动**

```bash
eww --config ~/.config/eww active-windows 2>&1 | head
test -f /home/mhpsy/dotfiles/waybar/weather-island-toggle.sh && echo "eww 回退脚本保留"
git -C /home/mhpsy/dotfiles status --porcelain | grep -E '(\.config/)?eww/|word-island|weather\.sh|weather-eww\.sh' && echo "WARN 动了禁区" || echo "禁区未动 OK"
git -C /home/mhpsy/dotfiles diff --stat 19a79b4..HEAD
git -C /home/mhpsy/dotfiles log --oneline -8
```
Expected:word-island eww 仍运行/未改;`weather-island-toggle.sh`(eww 回退)仍在且未改;`weather.sh`/`weather-eww.sh`/eww/word-island 不在改动里;`git diff 19a79b4..HEAD --stat` 仅涉及:`waybar/qs-weather-toggle.sh`(新)、`quickshell/weather-island/shell.qml`、`quickshell/weather-island/Pill.qml`(删)、`quickshell/weather-island/Card.qml`、`waybar/config.jsonc`。预存在脏文件(eww/colors.scss、matugen/*、quickshell/colors.json、.claude/)仍未提交。

- [ ] **Step 6: qs 守护进程挂掉的降级验证(本设计核心健壮性)**

```bash
for i in 1 2 3 4 5; do pkill -9 -x qs 2>/dev/null; sleep 0.6; pgrep -x qs >/dev/null || break; done
sleep 1; grim -g "0,0 900x60" /tmp/t5_qsdead.png && echo shot
~/.config/waybar/launch.sh; sleep 2   # 确保 waybar 在
```
Expected:用 Read 看 `/tmp/t5_qsdead.png` —— **qs 死了,waybar 原生天气胶囊仍在显示天气**(bar 不失天气;点击此时无卡弹出但不报错)。证明比前身"qs 挂=全部天气没了"严格更健壮。验收后重起守护进程:`( qs -c weather-island >/tmp/qs.log 2>&1 & )`,保持运行。

- [ ] **Step 7: 完成开发分支**

REQUIRED SUB-SKILL:用 superpowers:finishing-a-development-branch 决定合并/PR/清理(注意:本仓库无单测,"测试通过"= 上述端到端验收通过;normal repo 非 worktree;分支 `feat/word-island`;预存在脏文件非本工作产物,不纳入)。

---

## Self-Review

**Spec 覆盖核对(对 `2026-05-19-hybrid-weather-island-design.md`):**
- 混合架构:收起=waybar 原生 custom/weather → Task 4;展开=QS 弹出卡 → Task 2。✓
- 纯切换 Model A:Task 1 toggle 脚本(0/1 翻转)+ Task 2 FileView 驱动 open;无 hover/收起逻辑(Task 2 重写已不含、Task 3 删 cardHover/Pill)。✓
- 触发=状态文件+FileView(方案 A):Task 1 `/tmp/qs-weather-open`+脚本;Task 2 FileView 监听(+退路)。✓
- 复用 Theme/WeatherData/Card/Ambient:File Structure 标注不动;Task 3 仅 Card 摘 cardHover。✓
- 删 Pill.qml + hover 状态机:Task 3 `git rm` Pill;Task 2 重写后 shell.qml 无 hover/collapse/evalCollapse/Connections。✓
- 恢复 waybar custom/weather(on-click→新脚本,tooltip false,exec weather.sh):Task 4 逐字块 + 校验。✓
- 固定 surface / 关闭态零足迹 / 抖动结构上不可能:Task 2 Step1 注释铁律 + Step4 几何恒定验证 + Step2/3 关闭态零浮层。✓
- 抓取回归 waybar 驱动:Task 5 Step4 专项。✓
- 错误降级(文件缺失→关、ok:false→占位、qs 挂→原生仍显):Task 2(缺失→关)+ Task 5 Step6(qs 挂降级)。✓
- 回归不碰 word-island/eww 回退/复用脚本:Task 5 Step5;全程"绝不触碰"清单。✓
- 非目标(不重构整条 waybar、不引 IPC):计划范围仅 5 任务、触发用文件非 IPC。✓
- API 不确定(FileView)首步查证 + 退路:Task 1 Step1 + Task 2 退路块。✓
- 本机 API 既有查证沿用(WlrLayershell 直属性/Singleton 无 qmldir/ExclusionMode.Ignore/Region/StdioCollector):执行须知 + Task 2 示例已含,与前身一致。✓
- 验证法(无单测;qs+hyprctl+grim+Read;STRICT `pgrep -x qs`):每任务验证步均如此。✓

**占位扫描:** 无 TBD/TODO;每写码步给完整 QML/脚本/命令;API 不确定处给"本机查证 + 明确退路代码"而非占位;校验步给确切命令与预期。✓

**类型/命名一致性:** 状态文件路径 `/tmp/qs-weather-open` 全程一致;脚本名 `qs-weather-toggle.sh` 在 Task1 创建、Task4 on-click 引用、Task2/3/5 调用一致;`win.open`/`card`/`wx`/`stateFile` id 在 Task2 内自洽;`Card` 暴露 `wx`/`implicitWidth`/`implicitHeight` 与前身既有契约一致;namespace `qs-weather-island` 全程一致;base 提交 `19a79b4`(spec 提交)用于 Task5 diff 基线一致。✓
