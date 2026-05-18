# Waybar 天气灵动岛 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用 eww 实现一个点击展开的"灵动岛"天气卡片,替代 waybar 现有的朴素 GTK tooltip。

**Architecture:** waybar 的 `custom/weather` 胶囊保持原位,点击触发一个 eww 浮窗从胶囊下方缓慢向下展开(revealer slidedown)。eww 卡片数据来自新脚本 `weather-eww.sh`,它复用 `weather.sh` 已有的 Open-Meteo 缓存 `/tmp/waybar-openmeteo.json` 与纯函数,不重复联网。eww 配置与天气脚本同目录(`~/.config/waybar/eww/`),用 `eww --config` 指定。

**Tech Stack:** bash + jq(数据)、eww 0.5.0(yuck + scss,gtk-layer-shell/Hyprland overlay)、waybar custom 模块 `on-click`。

关联 spec:`docs/superpowers/specs/2026-05-18-weather-dynamic-island-design.md`

---

## File Structure

| 文件 | 责任 | 改动 |
|---|---|---|
| `~/.config/waybar/weather.sh` | waybar 胶囊文字 + 纯函数库 + Open-Meteo 缓存 | **不改**(只读复用,已支持 `WEATHER_LIB_ONLY=1`) |
| `~/.config/waybar/weather-eww.sh` | 读共享缓存 → 输出 eww 用的结构化 JSON;含纯函数 `wmo_cond` | 新增 |
| `~/.config/waybar/test_weather_eww.sh` | `weather-eww.sh` 单元 + 夹具测试 | 新增 |
| `~/.config/waybar/eww/eww.yuck` | eww 窗口 / defpoll / 卡片 widget 树 | 新增 |
| `~/.config/waybar/eww/eww.scss` | 玻璃卡样式 + revealer 过渡 + 按天气的氛围动画 | 新增 |
| `~/.config/waybar/weather-island-toggle.sh` | 点击切换:open+reveal / hide+close 时序 | 新增 |
| `~/.config/waybar/config.jsonc` | `custom/weather` 加 `on-click` | 改 1 处 |
| `~/.config/waybar/launch.sh` | 启动时拉起 eww daemon | 加几行 |

约定:eww 配置不放默认 `~/.config/eww`,放 `~/.config/waybar/eww/`,所有 eww 命令带 `--config "$HOME/.config/waybar/eww"`,让天气相关文件聚在一起。

---

## Task 1: `weather-eww.sh` 骨架 + 测试夹具(有效 JSON / ok / city)

**Files:**
- Create: `~/.config/waybar/weather-eww.sh`
- Test: `~/.config/waybar/test_weather_eww.sh`

- [ ] **Step 1: 写失败测试**

Create `~/.config/waybar/test_weather_eww.sh`:

```bash
#!/usr/bin/env bash
# weather-eww.sh tests: 纯函数单元 + 离线夹具渲染。
set -u
SCRIPT="$HOME/.config/waybar/weather-eww.sh"
fail=0
assert_eq() { # $1=actual $2=expected $3=label
    if [ "$1" = "$2" ]; then printf 'PASS  %s\n' "$3"
    else printf 'FAIL  %s\n        got=[%s]\n        exp=[%s]\n' "$3" "$1" "$2"; fail=1; fi
}

# ---- 夹具:离线渲染(mtime=now 让 weather.sh 缓存逻辑视为新鲜,不联网) ----
CACHE="/tmp/waybar-openmeteo.json"
mapfile -t T < <(for o in 0 1 2 3 4 5; do date -d "+$o hour" +%Y-%m-%dT%H:00; done)
fixture=$(jq -n \
  --arg t0 "${T[0]}" --arg t1 "${T[1]}" --arg t2 "${T[2]}" \
  --arg t3 "${T[3]}" --arg t4 "${T[4]}" --arg t5 "${T[5]}" \
  --arg sr "$(date +%Y-%m-%d)T06:12" --arg ss "$(date +%Y-%m-%d)T18:54" '
{ current:{ temperature_2m:26.4, relative_humidity_2m:65,
            apparent_temperature:28.1, is_day:1, weather_code:0,
            pressure_msl:1013.2, wind_speed_10m:12.3, wind_direction_10m:135 },
  hourly:{ time:[$t0,$t1,$t2,$t3,$t4,$t5],
           temperature_2m:[26,27,27,26,24,23],
           weather_code:[0,2,2,61,61,3],
           visibility:[24000,23000,22000,20000,18000,17000],
           precipitation_probability:[10,20,30,40,30,20] },
  daily:{ weather_code:[0,2,61],
          temperature_2m_max:[28.2,27.1,25.4],
          temperature_2m_min:[22.0,21.3,20.1],
          sunrise:[$sr,$sr,$sr], sunset:[$ss,$ss,$ss],
          uv_index_max:[8.1,7.0,5.5],
          precipitation_probability_max:[30,40,60],
          precipitation_sum:[0.2,1.0,3.4] } }')
printf '%s' "$fixture" > "$CACHE"; touch "$CACHE"

out=$(bash "$SCRIPT")
if echo "$out" | jq -e . >/dev/null 2>&1; then echo "PASS  output is valid JSON"
else echo "FAIL  output is not valid JSON: $out"; fail=1; fi
assert_eq "$(echo "$out" | jq -r '.ok')"   "true"     "ok=true with cache"
assert_eq "$(echo "$out" | jq -r '.city')" "深圳宝安" "city correct"

rm -f "$CACHE"
exit $fail
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash ~/.config/waybar/test_weather_eww.sh`
Expected: FAIL —— `weather-eww.sh` 不存在,`bash "$SCRIPT"` 输出空,非合法 JSON。

- [ ] **Step 3: 写最小实现**

Create `~/.config/waybar/weather-eww.sh`:

```bash
#!/usr/bin/env bash
# Waybar 天气灵动岛数据脚本 — 读 weather.sh 的共享缓存,输出 eww 结构化 JSON。
# 不主动联网(联网由 waybar 侧 weather.sh 周期触发)。
# See docs/superpowers/specs/2026-05-18-weather-dynamic-island-design.md
set -u
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="/tmp/waybar-openmeteo.json"
CITY="深圳宝安"

# 导入 weather.sh 纯函数(r / wmo_text / wmo_icon / wind_dir_cn),不跑其 main
WEATHER_LIB_ONLY=1 source "$SELF_DIR/weather.sh"

# WMO code -> 氛围动效分类
wmo_cond() {
    case "$1" in
        0|1|2) printf 'clear' ;;
        3)     printf 'clouds' ;;
        45|48) printf 'fog' ;;
        51|53|55|56|57|61|63|65|66|67|80|81|82) printf 'rain' ;;
        71|73|75|77|85|86) printf 'snow' ;;
        95|96|99) printf 'thunder' ;;
        *) printf 'clouds' ;;
    esac
}

# 仅导入函数供测试
if [ "${WEATHER_EWW_LIB_ONLY:-}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi

if [ ! -f "$CACHE" ]; then
    jq -cn --arg c "$CITY" '{ok:false, city:$c, msg:"天气数据不可用"}'
    exit 0
fi

jq -cn --arg c "$CITY" '{ok:true, city:$c}'
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash ~/.config/waybar/test_weather_eww.sh`
Expected: 4 行 PASS(valid JSON / ok=true / city),exit 0。

- [ ] **Step 5: 提交**

```bash
chmod +x ~/.config/waybar/weather-eww.sh ~/.config/waybar/test_weather_eww.sh
cd /home/mhpsy/dotfiles
git add waybar/weather-eww.sh waybar/test_weather_eww.sh
git commit -m "feat(waybar): weather-eww.sh skeleton + test harness

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: 纯函数 `wmo_cond` 单元测试

**Files:**
- Modify: `~/.config/waybar/test_weather_eww.sh`(在夹具段之前插入单元段)
- 已在 Task 1 实现 `wmo_cond`,本任务补测试覆盖。

- [ ] **Step 1: 写失败测试**

在 `test_weather_eww.sh` 的 `# ---- 夹具` 行**之前**插入:

```bash
# ---- 单元:纯函数 ----
WEATHER_EWW_LIB_ONLY=1 source "$SCRIPT"
assert_eq "$(wmo_cond 0)"   "clear"   "cond 0 clear"
assert_eq "$(wmo_cond 2)"   "clear"   "cond 2 clear"
assert_eq "$(wmo_cond 3)"   "clouds"  "cond 3 clouds"
assert_eq "$(wmo_cond 48)"  "fog"     "cond 48 fog"
assert_eq "$(wmo_cond 61)"  "rain"    "cond 61 rain"
assert_eq "$(wmo_cond 82)"  "rain"    "cond 82 rain"
assert_eq "$(wmo_cond 75)"  "snow"    "cond 75 snow"
assert_eq "$(wmo_cond 95)"  "thunder" "cond 95 thunder"
assert_eq "$(wmo_cond 999)" "clouds"  "cond unknown fallback"
echo "--- unit section end ---"
```

- [ ] **Step 2: 跑测试确认通过**(实现已存在,这步验证测试正确接线)

Run: `bash ~/.config/waybar/test_weather_eww.sh`
Expected: 9 行 cond PASS + Task 1 的 4 行 PASS,exit 0。
(若 `WEATHER_EWW_LIB_ONLY=1 source` 报错,说明早退逻辑未生效——回查 Task 1 Step 3 的早退判断。)

- [ ] **Step 3: 提交**

```bash
cd /home/mhpsy/dotfiles
git add waybar/test_weather_eww.sh
git commit -m "test(waybar): cover wmo_cond classification

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `current{}` 全字段

**Files:**
- Modify: `~/.config/waybar/weather-eww.sh`(替换末尾占位 jq)
- Modify: `~/.config/waybar/test_weather_eww.sh`(夹具段加断言)

- [ ] **Step 1: 写失败测试**

在 `test_weather_eww.sh` 的 `assert_eq "$(echo "$out" | jq -r '.city')" ...` 行**之后**插入:

```bash
assert_eq "$(echo "$out" | jq -r '.current.temp')"       "26"   "current.temp rounded"
assert_eq "$(echo "$out" | jq -r '.current.feel')"       "28"   "current.feel rounded"
assert_eq "$(echo "$out" | jq -r '.current.desc')"       "晴"   "current.desc"
assert_eq "$(echo "$out" | jq -r '.current.cond')"       "clear" "current.cond"
assert_eq "$(echo "$out" | jq -r '.current.humidity')"   "65"   "current.humidity"
assert_eq "$(echo "$out" | jq -r '.current.wind_dir')"   "东南" "current.wind_dir"
assert_eq "$(echo "$out" | jq -r '.current.wind_speed')" "12"   "current.wind_speed"
assert_eq "$(echo "$out" | jq -r '.current.pressure')"   "1013" "current.pressure"
assert_eq "$(echo "$out" | jq -r '.current.visibility')" "24.0" "current.visibility"
assert_eq "$(echo "$out" | jq -r '.current.wind_deg')"   "135"  "current.wind_deg"
assert_eq "$(echo "$out" | jq -r '.current.uv')"         "8"    "current.uv"
assert_eq "$(echo "$out" | jq -r '.current.sunrise')"    "06:12" "current.sunrise"
assert_eq "$(echo "$out" | jq -r '.current.sunset')"     "18:54" "current.sunset"
assert_eq "$(echo "$out" | jq -r '.current.pop')"        "30"   "current.pop"
assert_eq "$(echo "$out" | jq -r '.current.precip')"     "0.2"  "current.precip"
assert_eq "$(echo "$out" | jq -r '.current.icon')" "$(printf '')" "current.icon clear-day glyph"
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash ~/.config/waybar/test_weather_eww.sh`
Expected: FAIL —— 当前实现只输出 `{ok,city}`,`current.*` 全为 `null`。

- [ ] **Step 3: 写实现**

把 `weather-eww.sh` 末尾这行:

```bash
jq -cn --arg c "$CITY" '{ok:true, city:$c}'
```

替换为:

```bash
g() { jq -r "$1 // \"--\"" "$CACHE" 2>/dev/null; }

is_day=$(g '.current.is_day'); [ "$is_day" = "--" ] && is_day=1
cur_code=$(g '.current.weather_code')
temp=$(r "$(g '.current.temperature_2m')")
feel=$(r "$(g '.current.apparent_temperature')")
hum=$(g '.current.relative_humidity_2m')
pres=$(r "$(g '.current.pressure_msl')")
wspd=$(r "$(g '.current.wind_speed_10m')")
wdeg_raw=$(g '.current.wind_direction_10m'); [ "$wdeg_raw" = "--" ] && wdeg_raw=0
wdeg=$(r "$wdeg_raw")
icon=$(wmo_icon "$cur_code" "$is_day")
desc=$(wmo_text "$cur_code")
wdir=$(wind_dir_cn "$wdeg_raw")
cond=$(wmo_cond "$cur_code")

now_key=$(date +%Y-%m-%dT%H:00)
hidx=$(jq -r --arg t "$now_key" '(.hourly.time | index($t)) // 0' "$CACHE" 2>/dev/null)
[ -z "$hidx" ] || [ "$hidx" = "null" ] && hidx=0
vis_m=$(jq -r --argjson i "$hidx" '.hourly.visibility[$i] // empty' "$CACHE" 2>/dev/null)
if [ -n "$vis_m" ]; then vis=$(awk -v m="$vis_m" 'BEGIN{printf "%.1f", m/1000}'); else vis="--"; fi

sr=$(g '.daily.sunrise[0]'); ss=$(g '.daily.sunset[0]')
[ "$sr" != "--" ] && sr="${sr:11:5}"
[ "$ss" != "--" ] && ss="${ss:11:5}"
uv=$(r "$(g '.daily.uv_index_max[0]')")
pop=$(g '.daily.precipitation_probability_max[0]')
psum=$(jq -r '.daily.precipitation_sum[0] // empty' "$CACHE" 2>/dev/null)
if [ -n "$psum" ]; then psum=$(awk -v x="$psum" 'BEGIN{printf "%.1f", x}'); else psum="--"; fi

jq -cn \
  --arg city "$CITY" --arg icon "$icon" --arg temp "$temp" --arg desc "$desc" --arg feel "$feel" \
  --arg hum "$hum" --arg wdir "$wdir" --arg wspd "$wspd" --arg pres "$pres" --arg vis "$vis" \
  --arg wdeg "$wdeg" --arg uv "$uv" --arg sr "$sr" --arg ss "$ss" --arg pop "$pop" --arg psum "$psum" \
  --arg cond "$cond" '
{ ok:true, city:$city,
  current:{ icon:$icon, temp:$temp, desc:$desc, feel:$feel, humidity:$hum,
            wind_dir:$wdir, wind_speed:$wspd, pressure:$pres, visibility:$vis,
            wind_deg:$wdeg, uv:$uv, sunrise:$sr, sunset:$ss, pop:$pop, precip:$psum,
            cond:$cond } }'
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash ~/.config/waybar/test_weather_eww.sh`
Expected: 全 PASS(含 17 条 current.* 断言),exit 0。

- [ ] **Step 5: 提交**

```bash
cd /home/mhpsy/dotfiles
git add waybar/weather-eww.sh waybar/test_weather_eww.sh
git commit -m "feat(waybar): emit full current{} block for eww card

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: `hourly[6]` + `daily[3]`

**Files:**
- Modify: `~/.config/waybar/weather-eww.sh`
- Modify: `~/.config/waybar/test_weather_eww.sh`

- [ ] **Step 1: 写失败测试**

在 Task 3 插入的最后一条断言之后追加:

```bash
assert_eq "$(echo "$out" | jq -r '.hourly | length')"        "6"     "hourly has 6"
assert_eq "$(echo "$out" | jq -r '.hourly[0].temp')"         "26"    "hourly[0].temp"
assert_eq "$(echo "$out" | jq -r '.hourly[3].temp')"         "26"    "hourly[3].temp"
assert_eq "$(echo "$out" | jq -r '.hourly[0].icon')" "$(printf '')" "hourly[0] clear glyph"
assert_eq "$(echo "$out" | jq -r '.hourly[0].time' | grep -c 时)" "1" "hourly time has 时"
assert_eq "$(echo "$out" | jq -r '.daily | length')"         "3"     "daily has 3"
assert_eq "$(echo "$out" | jq -r '.daily[0].label')"         "今天"  "daily[0].label"
assert_eq "$(echo "$out" | jq -r '.daily[2].label')"         "后天"  "daily[2].label"
assert_eq "$(echo "$out" | jq -r '.daily[0].max')"           "28"    "daily[0].max rounded"
assert_eq "$(echo "$out" | jq -r '.daily[0].min')"           "22"    "daily[0].min rounded"
assert_eq "$(echo "$out" | jq -r '.daily[2].desc')"          "小雨"  "daily[2].desc (code 61)"
```

- [ ] **Step 2: 跑测试确认失败**

Run: `bash ~/.config/waybar/test_weather_eww.sh`
Expected: FAIL —— `.hourly` / `.daily` 为 `null`,length 报错/不等。

- [ ] **Step 3: 写实现**

在 `weather-eww.sh` 末尾那段 `jq -cn ... { ok:true ... }` 输出**之前**插入:

```bash
hourly_json='[]'
mapfile -t h_time < <(jq -r --argjson i "$hidx" '.hourly.time[$i:$i+6][]?'         "$CACHE" 2>/dev/null)
mapfile -t h_temp < <(jq -r --argjson i "$hidx" '.hourly.temperature_2m[$i:$i+6][]?' "$CACHE" 2>/dev/null)
mapfile -t h_code < <(jq -r --argjson i "$hidx" '.hourly.weather_code[$i:$i+6][]?'   "$CACHE" 2>/dev/null)
for k in "${!h_time[@]}"; do
    hh=$((10#${h_time[$k]:11:2}))
    ht=$(r "${h_temp[$k]:-}")
    hi=$(wmo_icon "${h_code[$k]:-x}" "$is_day")
    hourly_json=$(jq -c --arg t "${hh}时" --arg i "$hi" --arg d "$ht" \
        '. + [{time:$t, icon:$i, temp:$d}]' <<<"$hourly_json")
done

labels=(今天 明天 后天)
daily_json='[]'
for i in 0 1 2; do
    dc=$(jq -r ".daily.weather_code[$i] // \"x\""           "$CACHE" 2>/dev/null)
    dmax=$(r "$(jq -r ".daily.temperature_2m_max[$i] // \"--\"" "$CACHE" 2>/dev/null)")
    dmin=$(r "$(jq -r ".daily.temperature_2m_min[$i] // \"--\"" "$CACHE" 2>/dev/null)")
    di=$(wmo_icon "$dc" 1)
    dd=$(wmo_text "$dc")
    daily_json=$(jq -c --arg l "${labels[$i]}" --arg i "$di" --arg mn "$dmin" --arg mx "$dmax" --arg d "$dd" \
        '. + [{label:$l, icon:$i, min:$mn, max:$mx, desc:$d}]' <<<"$daily_json")
done
```

然后把最后那条 `jq -cn` 输出语句改为(增加 `--argjson hourly/daily` 与对应字段):

```bash
jq -cn \
  --arg city "$CITY" --arg icon "$icon" --arg temp "$temp" --arg desc "$desc" --arg feel "$feel" \
  --arg hum "$hum" --arg wdir "$wdir" --arg wspd "$wspd" --arg pres "$pres" --arg vis "$vis" \
  --arg wdeg "$wdeg" --arg uv "$uv" --arg sr "$sr" --arg ss "$ss" --arg pop "$pop" --arg psum "$psum" \
  --arg cond "$cond" --argjson hourly "$hourly_json" --argjson daily "$daily_json" '
{ ok:true, city:$city,
  current:{ icon:$icon, temp:$temp, desc:$desc, feel:$feel, humidity:$hum,
            wind_dir:$wdir, wind_speed:$wspd, pressure:$pres, visibility:$vis,
            wind_deg:$wdeg, uv:$uv, sunrise:$sr, sunset:$ss, pop:$pop, precip:$psum,
            cond:$cond },
  hourly:$hourly, daily:$daily }'
```

- [ ] **Step 4: 跑测试确认通过**

Run: `bash ~/.config/waybar/test_weather_eww.sh`
Expected: 全 PASS(新增 11 条 hourly/daily 断言),exit 0。

- [ ] **Step 5: 提交**

```bash
cd /home/mhpsy/dotfiles
git add waybar/weather-eww.sh waybar/test_weather_eww.sh
git commit -m "feat(waybar): emit hourly[6] + daily[3] arrays

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 缓存缺失降级路径

**Files:**
- Modify: `~/.config/waybar/test_weather_eww.sh`(实现已在 Task 1 写好,补测试)

- [ ] **Step 1: 写失败测试**

在 `test_weather_eww.sh` 的 `rm -f "$CACHE"` 行**之后**、`exit $fail` **之前**插入:

```bash
# ---- 降级:无缓存 ----
rm -f "$CACHE"
dout=$(bash "$SCRIPT")
assert_eq "$(echo "$dout" | jq -r '.ok')"   "false"        "degraded ok=false"
assert_eq "$(echo "$dout" | jq -r '.city')" "深圳宝安"     "degraded keeps city"
assert_eq "$(echo "$dout" | jq -r '.msg')"  "天气数据不可用" "degraded msg"
```

- [ ] **Step 2: 跑测试确认通过**(降级实现已在 Task 1 Step 3 写好)

Run: `bash ~/.config/waybar/test_weather_eww.sh`
Expected: 全 PASS,含 3 条 degraded 断言,exit 0。

- [ ] **Step 3: 提交**

```bash
cd /home/mhpsy/dotfiles
git add waybar/test_weather_eww.sh
git commit -m "test(waybar): cover missing-cache degraded path

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: eww 配置 — 窗口 + defpoll + 卡片 widget 树

**Files:**
- Create: `~/.config/waybar/eww/eww.yuck`
- Create: `~/.config/waybar/eww/eww.scss`(本任务先建最小占位,Task 7 写完整样式)

eww 0.5.0,gtk-layer-shell(Hyprland)。JSON 字段用安全访问 `?.` + elvis `?:` 兜底(初始 `{"ok":false}` 无 `current` 时不报错)。逐时固定 6、三天固定 3,用下标访问。

- [ ] **Step 1: 建最小 scss 占位**

Create `~/.config/waybar/eww/eww.scss`:

```scss
/* 占位,Task 7 替换为完整样式 */
.wcard { background-color: rgba(16,16,22,0.96); color: #fff; padding: 16px; }
```

- [ ] **Step 2: 写 eww.yuck**

Create `~/.config/waybar/eww/eww.yuck`:

```lisp
(defvar wisland_open false)

(defpoll weather :interval "900s"
                 :initial '{"ok":false,"city":"深圳宝安","msg":"加载中…"}'
  "$HOME/.config/waybar/weather-eww.sh")

(defwidget chip [k v]
  (box :class "chip" :orientation "v" :space-evenly false
    (label :class "chip-k" :text k)
    (label :class "chip-v" :text v)))

(defwidget hcell [i]
  (box :class "hcell" :orientation "v" :space-evenly false
    (label :class "h-t" :text {weather.hourly[i].time ?: "--"})
    (label :class "h-i" :text {weather.hourly[i].icon ?: ""})
    (label :class "h-d" :text {(weather.hourly[i].temp ?: "--") + "°"})))

(defwidget drow [i]
  (box :class "drow" :orientation "h" :space-evenly false
    (label :class "d-i" :text {weather.daily[i].icon ?: ""})
    (label :class "d-l" :text {weather.daily[i].label ?: "--"})
    (box :hexpand true)
    (label :class "d-r"
      :text {(weather.daily[i].min ?: "--") + "° ~ " + (weather.daily[i].max ?: "--") + "°C  " + (weather.daily[i].desc ?: "")})))

(defwidget card-ok []
  (box :class "wcard cond-${weather.current.cond ?: "clouds"}" :orientation "v" :space-evenly false
    (overlay
      (box :class "amb")
      (box :orientation "v" :space-evenly false :class "wbody"
        ; --- hero ---
        (box :class "hero" :orientation "h" :space-evenly false
          (label :class "hero-ic" :text {weather.current.icon ?: ""})
          (box :orientation "v" :space-evenly false :hexpand true
            (label :class "hero-city" :halign "start" :text {weather.city ?: "--"})
            (label :class "hero-temp" :halign "start" :text {(weather.current.temp ?: "--") + "°"})
            (label :class "hero-desc" :halign "start" :text {weather.current.desc ?: "--"})
            (label :class "hero-feel" :halign "start" :text {"体感 " + (weather.current.feel ?: "--") + "°C"})))
        ; --- 九宫格 ---
        (box :class "grid" :orientation "v" :space-evenly false
          (box :orientation "h" :space-evenly true
            (chip :k "湿度"   :v {(weather.current.humidity ?: "--") + "%"})
            (chip :k {"风 " + (weather.current.wind_dir ?: "--")} :v {(weather.current.wind_speed ?: "--") + " km/h"})
            (chip :k "气压"   :v {(weather.current.pressure ?: "--") + " hPa"}))
          (box :orientation "h" :space-evenly true
            (chip :k "能见度" :v {(weather.current.visibility ?: "--") + " km"})
            (chip :k "风向"   :v {(weather.current.wind_deg ?: "--") + "°"})
            (chip :k "紫外线" :v {"UV " + (weather.current.uv ?: "--")}))
          (box :orientation "h" :space-evenly true
            (chip :k "日出"   :v {weather.current.sunrise ?: "--"})
            (chip :k "日落"   :v {weather.current.sunset ?: "--"})
            (chip :k "降水"   :v {(weather.current.pop ?: "--") + "% · " + (weather.current.precip ?: "--") + "mm"})))
        ; --- 逐时 ---
        (label :class "sec" :halign "start" :text "逐时预报")
        (box :class "hours" :orientation "h" :space-evenly true
          (hcell :i 0) (hcell :i 1) (hcell :i 2) (hcell :i 3) (hcell :i 4) (hcell :i 5))
        ; --- 三天 ---
        (label :class "sec" :halign "start" :text "未来三天")
        (drow :i 0) (drow :i 1) (drow :i 2)))))

(defwidget card-err []
  (box :class "wcard cond-clouds" :orientation "v" :space-evenly false
    (label :class "hero-city" :text {weather.city ?: "天气"})
    (label :class "hero-desc" :text {weather.msg ?: "天气数据不可用"})))

(defwindow weather-island
  :monitor 0
  :geometry (geometry :x "150px" :y "38px" :width "0px" :height "0px" :anchor "top left")
  :stacking "overlay"
  :focusable false
  :exclusive false
  (eventbox :onhoverlost "bash -c 'eww --config $HOME/.config/waybar/eww update wisland_open=false; sleep 0.45; eww --config $HOME/.config/waybar/eww close weather-island'"
    (revealer :transition "slidedown" :duration "420ms" :reveal wisland_open
      (box :class "island-wrap"
        (eventbox :visible {weather.ok ?: false} (card-ok))
        (eventbox :visible {!(weather.ok ?: false)} (card-err))))))
```

- [ ] **Step 3: 手动验证 eww 能渲染**

Run:
```bash
pkill -f 'eww.*waybar/eww' 2>/dev/null; sleep 0.3
eww --config "$HOME/.config/waybar/eww" daemon &
sleep 1
eww --config "$HOME/.config/waybar/eww" open weather-island
eww --config "$HOME/.config/waybar/eww" update wisland_open=true
sleep 1
eww --config "$HOME/.config/waybar/eww" active-windows
```
Expected:
- `active-windows` 输出含 `weather-island`。
- 屏幕左上(约 x=150,bar 下方)出现一张深色卡片(占位样式很素),含城市/温度/九宫格/逐时/三天真实数据。
- 若卡片不显示或字段为空:
  - 字段空 → 验证 `bash ~/.config/waybar/weather-eww.sh | jq .` 正常;再单测 eww JSON 访问:`eww --config "$HOME/.config/waybar/eww" get weather`(应是合法 JSON 串)。
  - 报 `unknown property ?.`/解析错 → 该 eww 版本对 `?.` 兼容性问题;改用 `weather.current.temp` 直接访问并把 `defpoll :initial` 设为含完整空骨架(`current:{...全字段:"--"},hourly:[6×],daily:[3×]`)以避免初始无字段。把该改动记录到本任务并继续。
  - 位置太偏 → 记下,Task 8 再统一调 x/y。

清理:
```bash
eww --config "$HOME/.config/waybar/eww" close weather-island
eww --config "$HOME/.config/waybar/eww" kill
```

- [ ] **Step 4: 提交**

```bash
cd /home/mhpsy/dotfiles
git add waybar/eww/eww.yuck waybar/eww/eww.scss
git commit -m "feat(waybar): eww island window + card widget tree

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: eww.scss — 玻璃卡 + revealer 过渡 + 氛围动画

**Files:**
- Modify: `~/.config/waybar/eww/eww.scss`(整体替换占位)

- [ ] **Step 1: 写完整样式**

整文件替换 `~/.config/waybar/eww/eww.scss` 为:

```scss
* { all: unset; font-family: "Fira Sans Semibold", "FiraCode Nerd Font", "LXGW WenKai Screen", sans-serif; }

.island-wrap { background-color: transparent; }

.wcard {
  background: linear-gradient(180deg, rgba(16,16,22,0.97), rgba(10,10,14,0.97));
  border: 1px solid rgba(255,255,255,0.06);
  border-radius: 26px;
  padding: 20px 22px;
  margin: 4px;
  color: #ffffff;
  box-shadow: 0 18px 46px rgba(0,0,0,0.6);
}
.wbody { min-width: 420px; }

/* hero */
.hero-ic   { font-size: 46px; margin-right: 16px; }
.hero-city { font-size: 12px; color: rgba(255,255,255,0.55); }
.hero-temp { font-size: 42px; font-weight: 700; color: #cdd6ff; }
.hero-desc { font-size: 14px; color: #cdd3ff; }
.hero-feel { font-size: 12px; color: rgba(255,255,255,0.5); margin-top: 2px; }

/* 九宫格 */
.grid { margin-top: 14px; }
.grid > box { margin: 4px 0; }
.chip {
  background-color: rgba(255,255,255,0.055);
  border: 1px solid rgba(255,255,255,0.06);
  border-radius: 12px;
  padding: 8px 10px;
  margin: 0 4px;
}
.chip-k { font-size: 10px; color: rgba(255,255,255,0.45); }
.chip-v { font-size: 14px; font-weight: 600; margin-top: 2px; }

.sec { font-size: 11px; color: rgba(255,255,255,0.4); margin: 16px 0 8px 0; }

/* 逐时 */
.hcell { background-color: rgba(255,255,255,0.05); border-radius: 12px; padding: 8px 0; margin: 0 3px; }
.h-t { font-size: 10px; color: rgba(255,255,255,0.5); }
.h-i { font-size: 17px; margin: 3px 0; }
.h-d { font-size: 13px; font-weight: 600; }

/* 三天 */
.drow { background-color: rgba(255,255,255,0.05); border-radius: 12px; padding: 9px 14px; margin-bottom: 7px; }
.d-i { font-size: 19px; margin-right: 10px; }
.d-l { font-size: 14px; }
.d-r { font-size: 13px; color: rgba(255,255,255,0.7); }

/* 氛围层:覆盖在卡片背景上,按 .cond-* 切换动画 */
.amb { border-radius: 26px; background-repeat: no-repeat; }

.cond-clear .amb {
  background-image: radial-gradient(circle at 82% 14%, rgba(255,196,90,0.30), rgba(255,196,90,0) 60%);
  animation: glow 5s ease-in-out infinite alternate;
}
@keyframes glow { from { opacity: 0.45; } to { opacity: 1; } }

.cond-clouds .amb, .cond-fog .amb {
  background-image: linear-gradient(110deg, rgba(170,185,225,0) 0%, rgba(170,185,225,0.10) 45%, rgba(170,185,225,0) 90%);
  background-size: 220% 100%;
  animation: drift 16s linear infinite;
}
@keyframes drift { from { background-position: -60% 0; } to { background-position: 160% 0; } }

.cond-rain .amb {
  background-image: repeating-linear-gradient(68deg,
    rgba(150,190,255,0) 0px, rgba(150,190,255,0) 16px,
    rgba(150,190,255,0.20) 17px, rgba(150,190,255,0) 22px);
  background-size: 120% 140%;
  animation: rainfall 0.9s linear infinite;
}
@keyframes rainfall { from { background-position: 0 0; } to { background-position: -28px 46px; } }

.cond-snow .amb {
  background-image: radial-gradient(rgba(255,255,255,0.22) 1.4px, transparent 1.6px);
  background-size: 26px 26px;
  animation: snowfall 6s linear infinite;
}
@keyframes snowfall { from { background-position: 0 0; } to { background-position: 6px 60px; } }

.cond-thunder .amb {
  background-image: linear-gradient(0deg, rgba(180,200,255,0.10), rgba(180,200,255,0.10));
  animation: flash 4s steps(1) infinite;
}
@keyframes flash {
  0%,92%,100% { opacity: 0.10; }
  93% { opacity: 0.65; } 95% { opacity: 0.12; } 97% { opacity: 0.5; }
}
```

- [ ] **Step 2: 手动验证样式 + 动画**

Run:
```bash
pkill -f 'eww.*waybar/eww' 2>/dev/null; sleep 0.3
eww --config "$HOME/.config/waybar/eww" daemon &
sleep 1
eww --config "$HOME/.config/waybar/eww" open weather-island
eww --config "$HOME/.config/waybar/eww" update wisland_open=true
```
Expected:
- 卡片为深色玻璃圆角、有投影;hero/九宫格/逐时/三天排版整齐。
- 氛围层按当前 `cond` 跑对应动画(晴=右上暖光呼吸 / 雨=斜向流动条纹 / 阴=横向渐变漂移)。
- 临时验证其它天气动画(可选):`eww --config "$HOME/.config/waybar/eww" inspector` 或改 `weather-eww.sh` 的 `CITY` 不影响;若要快速看雨,可临时手造缓存 `weather_code:61` 重跑 daemon。
- 不满意(颜色/密度/速度)→ 直接调本 scss 重 `eww reload`,迭代到满意再继续。

清理:`eww --config "$HOME/.config/waybar/eww" kill`

- [ ] **Step 3: 提交**

```bash
cd /home/mhpsy/dotfiles
git add waybar/eww/eww.scss
git commit -m "feat(waybar): glass card styling + condition ambient animations

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: 接线 — toggle 脚本 + waybar on-click + launch.sh,端到端验收

**Files:**
- Create: `~/.config/waybar/weather-island-toggle.sh`
- Modify: `~/.config/waybar/config.jsonc`(`custom/weather` 加 `on-click`)
- Modify: `~/.config/waybar/launch.sh`(拉起 eww daemon)

- [ ] **Step 1: 写 toggle 脚本**

Create `~/.config/waybar/weather-island-toggle.sh`:

```bash
#!/usr/bin/env bash
# 点击 waybar 天气胶囊:打开并展开 / 收起并关闭(带 revealer 动画时序)。
set -u
EWWC="$HOME/.config/waybar/eww"
ew() { eww --config "$EWWC" "$@"; }

if ew active-windows 2>/dev/null | grep -q 'weather-island'; then
    ew update wisland_open=false
    sleep 0.45
    ew close weather-island
else
    ew open weather-island
    ew update wisland_open=true
fi
```

```bash
chmod +x ~/.config/waybar/weather-island-toggle.sh
```

- [ ] **Step 2: waybar custom/weather 加 on-click**

把 `~/.config/waybar/config.jsonc` 中(约 87–93 行)的:

```jsonc
    "custom/weather": {
        "format": "{}",
        "return-type": "json",
        "exec": "~/.config/waybar/weather.sh",
        "interval": 900,
        "tooltip": true
    },
```

改为(加 `on-click`,`tooltip` 关掉——新卡片取代旧 tooltip):

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

- [ ] **Step 3: launch.sh 拉起 eww daemon**

在 `~/.config/waybar/launch.sh` 末尾(最后的 `setsid -f waybar ...` 块**之后**)追加:

```bash

# 天气灵动岛:确保 eww daemon 运行(配置在 waybar 目录内)。
# pgrep 去重,避免重复 daemon;daemon 异常不影响 waybar 本体。
if ! pgrep -f 'eww.*waybar/eww.*daemon' >/dev/null 2>&1; then
    setsid -f eww --config "$HOME/.config/waybar/eww" daemon >/dev/null 2>&1
fi
```

- [ ] **Step 4: 端到端验收**

Run(完整重启 waybar 使 config.jsonc 生效;memory:waybar 改 config 需重启,非 SIGUSR2):
```bash
~/.config/waybar/launch.sh
sleep 2
pgrep -f 'eww.*waybar/eww.*daemon' && echo "eww daemon up"
```
然后手动验收(逐项确认):
- [ ] 鼠标点 waybar 天气胶囊 → 卡片从胶囊下方**缓慢向下展开**(~0.42s)。
- [ ] 再点一次胶囊 → 卡片**向上收起**后窗口关闭。
- [ ] 展开后鼠标移开卡片区域 → 自动收起关闭。
- [ ] 卡片内容与 `bash ~/.config/waybar/weather-eww.sh | jq .` 一致(温度/九宫格/逐时6/三天3)。
- [ ] 旧的 GTK tooltip 不再弹出(`tooltip:false` 生效)。
- [ ] 水平位置大致对齐胶囊下方;偏了则调 `eww.yuck` 里 `:geometry :x`(像素),`eww --config "$HOME/.config/waybar/eww" reload` 后重测,直到视觉对齐。
- [ ] 断网/删缓存(`rm -f /tmp/waybar-openmeteo.json`)点击 → 卡片显示"天气数据不可用",waybar 胶囊本体仍正常。

- [ ] **Step 5: 跑全部脚本测试做回归**

Run:
```bash
bash ~/.config/waybar/test_weather.sh && bash ~/.config/waybar/test_weather_eww.sh
```
Expected: 两个测试套件全 PASS,exit 0(确认 `weather.sh` 未被破坏、`weather-eww.sh` 仍绿)。

- [ ] **Step 6: 提交**

```bash
cd /home/mhpsy/dotfiles
git add waybar/weather-island-toggle.sh waybar/config.jsonc waybar/launch.sh
git commit -m "feat(waybar): wire weather island (on-click toggle + eww daemon)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 7: 完成开发分支**

REQUIRED SUB-SKILL: 用 superpowers:finishing-a-development-branch 决定合并/PR/清理(当前分支 `feat/word-island`)。

---

## Self-Review

**Spec 覆盖核对:**
- 形态/触发(点击)/向下展开 → Task 6(revealer slidedown)+ Task 8(toggle 脚本)。✓
- 全量内容(hero/九宫格/逐时6/三天3)→ Task 3/4 数据 + Task 6 widget。✓
- 数据流(复用 weather.sh 缓存与纯函数,不重复联网)→ Task 1 `source ... WEATHER_LIB_ONLY=1`,只读 `$CACHE`。✓
- 数据契约 JSON 字段 → Task 3/4 完整产出,与 spec "数据契约" 节字段逐一对应。✓
- `cond` 归并(0/1/2 clear;3 clouds;45/48 fog;rain/snow/thunder)→ Task 1 `wmo_cond` + Task 2 测试,与 spec 修订后的映射一致。✓
- 图标走 `wmo_icon` Nerd Font → Task 3/4 用 `wmo_icon`,Task 7 scss 字体链含 `FiraCode Nerd Font`。✓
- 动画 0.35–0.45s 回弹 → Task 6 revealer `:duration "420ms"`;氛围动画 → Task 7 keyframes。✓
- 窗口 overlay/`focusable false`/关闭两路径(再点 + 移开)→ Task 6 defwindow + onhoverlost,Task 8 toggle。✓
- 改动清单 6 文件 + weather.sh 不改 → Task 表一致。✓
- 测试策略(夹具 + 缺失降级 + 手动验收)→ Task 1–5 + Task 8 Step 4/5。✓
- 已知风险(x 固定偏移)→ Task 8 Step 4 调 x 闭环。✓

**占位扫描:** 无 TBD/TODO;每个写代码步骤含完整代码;eww/scss 不可单测,改为明确的手动验证命令与预期(含失败排查分支)。✓

**类型/命名一致性:** JSON 字段名 `current.{icon,temp,desc,feel,humidity,wind_dir,wind_speed,pressure,visibility,wind_deg,uv,sunrise,sunset,pop,precip,cond}`、`hourly[].{time,icon,temp}`、`daily[].{label,icon,min,max,desc}` 在 Task 3/4(产出)、Task 6(eww 消费)、测试断言三处一致;`wisland_open` defvar、`weather-island` 窗口名、`--config "$HOME/.config/waybar/eww"` 在 Task 6/7/8 一致。✓
