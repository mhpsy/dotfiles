# Waybar 天气灵动岛 — 设计文档

- 日期:2026-05-18
- 状态:已确认,待实现
- 关联:`docs/superpowers/specs/2026-05-18-weather-open-meteo-design.md`(数据源/脚本基础)

## 目标

把 waybar 现有的天气 tooltip 替换为一个 **iPhone 灵动岛风格**的展开卡片:点击 waybar 里的天气胶囊,信息卡从胶囊正下方缓慢向下展开,展示全部天气信息,带与天气类型联动的氛围动效。解决"现有 GTK tooltip 太朴素"的问题。

## 用户已确认的决策

1. 形态:方案 A —— 深色玻璃"灵动岛"风格(顶部刘海岛的视觉,但**定位在 waybar 现有天气槽位**,不居中)。
2. 触发:**点击切换**(再次点击胶囊,或鼠标移开卡片 → 收起)。选此方案因为胶囊位置 100% 不漂移。
3. 展开方向:向下。
4. 动画:缓慢的 tooltip 展开感,但比预览 demo 快一点 —— 展开/收起约 **0.35–0.45s**,带缓动回弹。
5. 内容:**全量展示**(下述全部字段)。
6. 实现技术:**eww**(用户已安装)。

## 架构与数据流

```
Open-Meteo API
   │ (weather.sh 已有的抓取+缓存逻辑,15min)
   ▼
/tmp/waybar-openmeteo.json   ← 单一数据源,两个消费者共享,不重复联网
   ├──→ weather.sh            (不改) → waybar custom/weather 胶囊文字
   └──→ weather-eww.sh (新增) → 结构化 JSON → eww defpoll → 灵动岛卡片
```

- **`weather.sh`:只读不改。** 继续给 waybar 胶囊输出 `{text,tooltip}`。其 `/tmp/waybar-openmeteo.json` 缓存被复用。
- **`weather-eww.sh`(新增):**
  - `source` `weather.sh` 并设 `WEATHER_LIB_ONLY=1`(脚本已支持该模式,只导入纯函数不跑主流程),复用 `wmo_text`、`wmo_icon`、`wind_dir_cn`、`r`。
  - 读取 `/tmp/waybar-openmeteo.json`(若缺失/陈旧,逻辑与 weather.sh 一致:有缓存就用,无则输出降级 JSON)。本脚本**不主动联网**,联网由 waybar 侧的 weather.sh 周期触发;若缓存不存在,卡片显示"天气数据不可用"。
  - 输出一份结构化 JSON(见下"数据契约")。
- **eww 配置(新增):**
  - `eww.yuck`:`defpoll weather :interval "900s"` 调 `weather-eww.sh`;`defwindow weather-island` 浮窗;widget 树渲染卡片。
  - `weather.scss`:玻璃卡样式 + `@keyframes` 氛围动效 + 展开/收起过渡。
- **waybar 接入:**`config.jsonc` 的 `custom/weather` 增加 `"on-click": "eww open --toggle weather-island"`。
- **启动:**`launch.sh` 中在拉起 waybar 的同时启动 eww daemon(`eww daemon` + 预热 `eww open` 不需要;由 on-click 按需 open/toggle)。需保证 daemon 存活。

## 数据契约(`weather-eww.sh` 输出 JSON)

```jsonc
{
  "ok": true,                       // false 时仅 city + 提示语有效
  "city": "深圳宝安",
  "current": {
    "icon": "⛅",                   // 由 wmo_icon 映射(eww 用 emoji 或 Nerd Font,见"图标"节)
    "temp": "27",                   // 整数字符串,缺失为 "--"
    "desc": "晴间多云",
    "feel": "30",
    "humidity": "76",
    "wind_dir": "东东南",
    "wind_speed": "18",
    "pressure": "1008",
    "visibility": "15.7",
    "wind_deg": "113",
    "uv": "9",
    "sunrise": "05:43",
    "sunset": "18:58",
    "pop": "27",                    // 降水概率 %
    "precip": "2.8",                // 降水量 mm
    "cond": "clouds"                // 氛围动效分类:clear|clouds|rain|snow|thunder|fog
  },
  "hourly": [ { "time": "17时", "icon": "⛅", "temp": "28" }, … 共 6 项 ],
  "daily":  [ { "label": "今天", "icon": "🌦️", "min": "24", "max": "29", "desc": "小雨" }, … 共 3 项 ]
}
```

- `cond` 由 WMO code 归并(复用现有 `wmo_icon` 的分组逻辑):0/1/2→`clear`(夜间也归 clear,动效用月相冷光晕);3→`clouds`;45/48→`fog`;51–67/80–82→`rain`;71–77/85/86→`snow`;95–99→`thunder`。
- 所有数值缺失统一用 `"--"`,与 weather.sh 现有约定一致。

## 图标策略

预览用 emoji 演示;实现时与现有 bar 胶囊保持一致,**优先沿用 `wmo_icon` 输出的 Nerd Font 字形**(weather.sh 已用 `` 等)。eww 的 SCSS 指定字体回退链含 `FiraCode Nerd Font`(与 waybar `style.css` 一致)。逐时/三天图标同样走 `wmo_icon`。

## UI 布局(展开卡)

宽约 460px,深色玻璃(`linear-gradient(180deg,#101016,#0a0a0e)` + 1px 内描边 + 大圆角 28px + 投影),自上而下:

1. **Hero**:左侧大天气图标;右侧 城市(小,弱化)/ 大温度(渐变字 白→蓝紫)/ 描述 / 体感。
2. **九宫格**(3×3 chip):湿度、风(向+速)、气压、能见度、风向°、UV、日出、日落、降水(%+mm)。
3. **逐时**:6 个等宽 chip(时间 / 图标 / 温度)。
4. **未来三天**:3 行(图标 + 标签 / 最低~最高 + 描述)。

收起态:仅胶囊(图标 + 温度),保持极简,**收起时无动效**。

## 动效

- **展开/收起**:卡片高度 + 透明度过渡,约 0.35–0.45s,`cubic-bezier(.22,1,.36,1)` 回弹缓动(eww `revealer` slide 过渡 + SCSS 过渡组合)。
- **氛围**(仅展开卡内,按 `cond`):
  - `clear`:右上暖色径向光晕呼吸(opacity 0.5↔1,~5s)。
  - `clouds`/`fog`:两团模糊云块横向漂移(~14s/20s 线性循环)。
  - `rain`:斜向落雨线(多条,错相位,~1s 循环)。
  - `snow`:缓降雪点。
  - `thunder`:偶发高光闪动 + 雨。
- 性能:动画为纯 CSS `@keyframes` / GTK transition,粒子数克制(雨≤约 8 条),仅卡片打开时渲染。

## 窗口与定位(eww)

- `defwindow weather-island`:`:stacking "overlay"`、`:focusable false`、`:exclusive false`,wlroots/Hyprland。
- 几何:锚定屏幕顶部偏左,x 用**固定偏移**近似对齐胶囊(胶囊左侧为 clock + date,宽度基本稳定;卡片够宽,几像素差视觉无感)。y 紧贴 waybar 下沿。
- 关闭路径:① 再次点击 waybar 胶囊(`--toggle`);② 卡片根 `eventbox` 的 `onhoverlost` 调 `eww close weather-island`(鼠标移开自动收)。两条都接。

## 改动清单

| 文件 | 改动 |
|---|---|
| `~/.config/waybar/weather.sh` | 不改(只读复用) |
| `~/.config/waybar/weather-eww.sh` | 新增 — 结构化 JSON 输出 |
| `~/.config/waybar/eww.yuck`(或 eww 配置目录内) | 新增 — 窗口 + widget |
| `~/.config/waybar/weather.scss`(eww scss) | 新增 — 样式与动效 |
| `~/.config/waybar/config.jsonc` | `custom/weather` 加 `on-click` |
| `~/.config/waybar/launch.sh` | 启动时拉起 eww daemon |

> eww 配置实际放置目录(`~/.config/eww/` 还是 waybar 目录内)在实现计划阶段按 eww 约定确定;本设计以"新增 eww 配置 + scss + 数据脚本"为准。

## 测试策略

- `weather-eww.sh` 纯函数与 JSON 输出:沿用现有 `test_weather.sh` 模式,喂固定 `/tmp` 缓存样本,断言输出 JSON 字段(含缺失→`--`、`cond` 归类、6 项逐时/3 项三天、`ok:false` 降级)。
- 手动验收:点击胶囊展开/收起;晴/雨/阴各跑一次看氛围动效;缓存缺失看降级提示;eww daemon 重启后仍可 toggle。

## 已知风险 / 取舍

1. eww 浮窗水平位置为固定偏移,非像素级跟随 waybar 布局;clock/date 宽度极端变化时下拉卡可能偏几像素,调偏移到视觉无感即可(胶囊本体在 bar 内不漂移)。
2. 依赖 eww daemon 存活;launch.sh 负责拉起,daemon 异常时点击无反应(降级:waybar 胶囊文字仍正常)。
3. 新增外部依赖 eww(用户已安装并明确选用)。

## 非目标(YAGNI)

- 不做横向展开、不做多城市切换、不做点击外部任意处关闭(只做"再点胶囊"+"移开卡片"两种关闭)。
- 不改 `weather.sh` 数据抓取逻辑、不改 Open-Meteo 接口与缓存周期。
- 不替换 waybar 其他模块、不动 `hyprland/workspaces`(因定位在天气原位,无中间区冲突)。
