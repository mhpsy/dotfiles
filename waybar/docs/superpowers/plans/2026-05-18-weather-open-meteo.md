# Open-Meteo 天气模块 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `~/.config/waybar/weather.sh` 从付费/失效的 QWeather 重写为免费免密钥的 Open-Meteo,并在 tooltip 中增加日出日落/UV/降水/气压/能见度/逐时预报。

**Architecture:** 单文件重写。脚本顶部是 3 个纯函数(WMO→中文、WMO→图标、风向角→中文方位)+ 一个取整 helper,用 `WEATHER_LIB_ONLY=1` 守卫使其可被测试脚本 source 而不执行主流程。主流程:缓存检查(900s)→ 一次 curl 取数(原子写,失败不污染好缓存)→ 从缓存读标量/数组渲染 → `jq -cn` 安全输出 waybar JSON。`config.jsonc` 不动。

**Tech Stack:** bash, `curl`, `jq`, `awk`, GNU `stat`/`date`(Arch 自带);Nerd Font 字形复用现脚本码点。

参考 spec:`docs/superpowers/specs/2026-05-18-weather-open-meteo-design.md`

---

## File Structure

- **Modify(整文件覆盖):** `~/.config/waybar/weather.sh` — 取数 + 渲染 + 输出,顶部纯函数可被 source。
- **Create:** `~/.config/waybar/test_weather.sh` — 单测(纯函数边界值)+ fixture 测(脱网渲染)。命名对齐现有 `test_quotes.sh`。
- **不变:** `~/.config/waybar/config.jsonc`(输出契约不变)。
- **废弃留原地:** `~/.config/waybar/weather/ed25519-public.pem`。

仓库根:`~/.config/waybar`(git 已跟踪)。所有 `git` 命令在该目录执行。

---

## Task 1: 纯函数 + lib 守卫(TDD)

**Files:**
- Create: `~/.config/waybar/weather.sh`(本任务只写函数段 + 守卫;覆盖旧 QWeather 脚本)
- Create: `~/.config/waybar/test_weather.sh`

- [ ] **Step 1: 写失败的单元测试**

写入 `~/.config/waybar/test_weather.sh`:

```bash
#!/usr/bin/env bash
# weather.sh 测试:纯函数单测 + fixture 渲染测。
set -u
SCRIPT="$HOME/.config/waybar/weather.sh"
fail=0
assert_eq() { # $1=actual $2=expected $3=label
    if [ "$1" = "$2" ]; then
        printf 'PASS  %s\n' "$3"
    else
        printf 'FAIL  %s\n        got=[%s]\n        exp=[%s]\n' "$3" "$1" "$2"
        fail=1
    fi
}
assert_contains() { # $1=haystack $2=needle $3=label
    case "$1" in
        *"$2"*) printf 'PASS  %s\n' "$3" ;;
        *) printf 'FAIL  %s (missing: %s)\n' "$3" "$2"; fail=1 ;;
    esac
}

# ---- 单元:纯函数 ----
WEATHER_LIB_ONLY=1 source "$SCRIPT"

assert_eq "$(wmo_text 0)"   "晴"               "wmo_text 0"
assert_eq "$(wmo_text 2)"   "多云"             "wmo_text 2"
assert_eq "$(wmo_text 55)"  "大毛毛雨"         "wmo_text 55"
assert_eq "$(wmo_text 95)"  "雷阵雨"           "wmo_text 95"
assert_eq "$(wmo_text 999)" "未知"             "wmo_text 未知回退"

assert_eq "$(wmo_icon 0 1)"  "$(printf '')" "wmo_icon 晴-昼"
assert_eq "$(wmo_icon 0 0)"  "$(printf '')" "wmo_icon 晴-夜"
assert_eq "$(wmo_icon 2 0)"  "$(printf '')" "wmo_icon 多云-夜"
assert_eq "$(wmo_icon 65 1)" "$(printf '')" "wmo_icon 大雨"
assert_eq "$(wmo_icon 95 1)" "$(printf '')" "wmo_icon 雷"
assert_eq "$(wmo_icon 999 1)" "$(printf '')" "wmo_icon 未知回退"

assert_eq "$(wind_dir_cn 0)"   "北"   "wind 0°"
assert_eq "$(wind_dir_cn 90)"  "东"   "wind 90°"
assert_eq "$(wind_dir_cn 135)" "东南" "wind 135°"
assert_eq "$(wind_dir_cn 350)" "北"   "wind 350°(环绕)"

assert_eq "$(r 26.4)"  "26"  "r 四舍五入下"
assert_eq "$(r 27.6)"  "28"  "r 四舍五入上"
assert_eq "$(r null)"  "--"  "r 非数字回退"
assert_eq "$(r '')"    "--"  "r 空回退"

echo "--- 单元测试段结束 ---"
exit $fail
```

- [ ] **Step 2: 跑测试确认失败**

```bash
chmod +x ~/.config/waybar/test_weather.sh
bash ~/.config/waybar/test_weather.sh; echo "exit=$?"
```

Expected: 失败 —— `weather.sh` 尚不存在或无这些函数,`source` 报错 / 函数未定义,`exit` 非 0。

- [ ] **Step 3: 写 weather.sh 函数段 + lib 守卫**

写入 `~/.config/waybar/weather.sh`(完整覆盖旧文件):

```bash
#!/usr/bin/env bash
# Waybar weather — Open-Meteo (免费,无需 API key)。
# bar 显示天气图标;tooltip:当前 / 逐时6h / 三日 + 日出日落/UV/降水/气压/能见度。
# 见 docs/superpowers/specs/2026-05-18-weather-open-meteo-design.md
set -u

CACHE="/tmp/waybar-openmeteo.json"
CACHE_AGE=900
LAT="22.57"
LON="113.85"
CITY="深圳宝安"

API="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}\
&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,pressure_msl,wind_speed_10m,wind_direction_10m\
&hourly=temperature_2m,weather_code,visibility,precipitation_probability\
&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max,precipitation_sum\
&timezone=Asia/Shanghai&forecast_days=3"

# ---- 纯函数(单元测试覆盖)----

# 四舍五入取整;非数字 -> "--"
r() {
    awk -v x="${1:-}" 'BEGIN{
        if (x ~ /^-?[0-9]+(\.[0-9]+)?$/) printf "%.0f", x;
        else print "--";
    }'
}

# WMO weather code -> 中文描述
wmo_text() {
    case "$1" in
        0) printf '晴' ;;
        1) printf '晴间多云' ;;
        2) printf '多云' ;;
        3) printf '阴' ;;
        45) printf '雾' ;;
        48) printf '雾凇' ;;
        51) printf '小毛毛雨' ;;
        53) printf '毛毛雨' ;;
        55) printf '大毛毛雨' ;;
        56) printf '冻毛毛雨' ;;
        57) printf '强冻毛毛雨' ;;
        61) printf '小雨' ;;
        63) printf '中雨' ;;
        65) printf '大雨' ;;
        66) printf '冻雨' ;;
        67) printf '强冻雨' ;;
        71) printf '小雪' ;;
        73) printf '中雪' ;;
        75) printf '大雪' ;;
        77) printf '米雪' ;;
        80) printf '小阵雨' ;;
        81) printf '阵雨' ;;
        82) printf '强阵雨' ;;
        85) printf '小阵雪' ;;
        86) printf '阵雪' ;;
        95) printf '雷阵雨' ;;
        96) printf '雷阵雨伴小冰雹' ;;
        99) printf '雷阵雨伴冰雹' ;;
        *) printf '未知' ;;
    esac
}

# WMO code + is_day(1/0) -> Nerd Font 字形(复用现脚本码点 + 新增夜间)
wmo_icon() {
    local code="$1" day="${2:-1}"
    case "$code" in
        0)     if [ "$day" = "1" ]; then printf ''; else printf ''; fi ;;
        1|2)   if [ "$day" = "1" ]; then printf ''; else printf ''; fi ;;
        3)     printf '' ;;
        45|48) printf '' ;;
        51|53|55|56|57|61|80) printf '' ;;
        63|65|66|67|81|82)    printf '' ;;
        71|73|75|77|85|86)    printf '' ;;
        95|96|99)             printf '' ;;
        *)     printf '' ;;
    esac
}

# 风向角(度) -> 中文 16 方位
wind_dir_cn() {
    local deg="${1:-0}" idx
    local names=(北 北东北 东北 东东北 东 东东南 东南 南东南 \
                 南 南西南 西南 西西南 西 西西北 西北 北西北)
    idx=$(awk -v d="$deg" 'BEGIN{ printf "%d", (int(d/22.5+0.5))%16 }')
    printf '%s' "${names[$idx]}"
}

# ---- 允许 source 仅加载函数(供测试),不跑主流程 ----
if [ "${WEATHER_LIB_ONLY:-}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi
```

- [ ] **Step 4: 跑测试确认单元段通过**

```bash
bash ~/.config/waybar/test_weather.sh; echo "exit=$?"
```

Expected: 所有 `wmo_text / wmo_icon / wind_dir_cn / r` 断言 `PASS`,输出 `--- 单元测试段结束 ---`,`exit=0`。

- [ ] **Step 5: Commit**

```bash
cd ~/.config/waybar
git add weather.sh test_weather.sh
git -c commit.gpgsign=false commit -m "feat(weather): Open-Meteo pure helpers + lib guard (TDD)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: 取数 + 渲染 + 输出(TDD,fixture 脱网测)

**Files:**
- Modify: `~/.config/waybar/weather.sh`(在 lib 守卫之后追加主流程)
- Modify: `~/.config/waybar/test_weather.sh`(追加 fixture 渲染测)

- [ ] **Step 1: 追加失败的 fixture 测试**

在 `~/.config/waybar/test_weather.sh` 末尾的 `exit $fail` **之前**插入以下段(即把原 `echo "--- 单元测试段结束 ---"` / `exit $fail` 两行替换为下面整段):

```bash
echo "--- 单元测试段结束 ---"

# ---- fixture:脱网渲染 ----
CACHE="/tmp/waybar-openmeteo.json"
# 动态生成含"当前整点"的 hourly,使 hidx=0 确定
mapfile -t T < <(for o in 0 1 2 3 4 5; do date -d "+$o hour" +%Y-%m-%dT%H:00; done)
fixture=$(jq -n \
  --arg t0 "${T[0]}" --arg t1 "${T[1]}" --arg t2 "${T[2]}" \
  --arg t3 "${T[3]}" --arg t4 "${T[4]}" --arg t5 "${T[5]}" \
  --arg sr "$(date +%Y-%m-%d)T06:12" --arg ss "$(date +%Y-%m-%d)T18:54" '
{
  current:{ temperature_2m:26.4, relative_humidity_2m:65,
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
          precipitation_sum:[0.2,1.0,3.4] }
}')
printf '%s' "$fixture" > "$CACHE"
touch "$CACHE"   # mtime=now -> 脚本视缓存新鲜,跳过 curl

out=$(bash "$SCRIPT")
echo "$out" | jq -e . >/dev/null 2>&1 \
  && { echo "PASS  输出是合法 JSON"; } \
  || { echo "FAIL  输出非合法 JSON: $out"; fail=1; }

txt=$(echo "$out" | jq -r '.text')
tip=$(echo "$out" | jq -r '.tooltip')

assert_eq "$txt" "$(printf '')"  "text=晴昼字形"
assert_contains "$tip" "深圳宝安"       "tooltip 含城市"
assert_contains "$tip" "26°C"           "tooltip 含当前温度(取整)"
assert_contains "$tip" "体感 28°C"      "tooltip 含体感"
assert_contains "$tip" "东南 12 km/h"   "tooltip 含风向+风速"
assert_contains "$tip" "风向 135°"      "tooltip 含原始风向角"
assert_contains "$tip" "能见度 24.0 km" "tooltip 含能见度"
assert_contains "$tip" "日出 06:12"     "tooltip 含日出"
assert_contains "$tip" "日落 18:54"     "tooltip 含日落"
assert_contains "$tip" "UV 8"           "tooltip 含 UV"
assert_contains "$tip" "降水 30% (0.2mm)" "tooltip 含降水概率/量"
assert_contains "$tip" "逐时"           "tooltip 含逐时段"
assert_contains "$tip" "今天"           "tooltip 含三日预报"
assert_contains "$tip" "后天  20° ~ 25°C  小雨" "tooltip 后天行正确"

rm -f "$CACHE"
exit $fail
```

- [ ] **Step 2: 跑测试确认 fixture 段失败**

```bash
bash ~/.config/waybar/test_weather.sh; echo "exit=$?"
```

Expected: 单元段仍 `PASS`;fixture 段 `FAIL`(主流程未实现,`bash "$SCRIPT"` 因 lib 守卫直接退出无输出,JSON/断言全挂),`exit=1`。

- [ ] **Step 3: 追加主流程实现**

在 `~/.config/waybar/weather.sh` **末尾**(lib 守卫之后)追加:

```bash

# ---- 取数(缓存过期/缺失才请求;原子写,失败不污染好缓存)----
need_fetch=1
if [ -f "$CACHE" ] && [ $(( $(date +%s) - $(stat -c %Y "$CACHE") )) -le "$CACHE_AGE" ]; then
    need_fetch=0
fi
if [ "$need_fetch" = "1" ]; then
    tmp=$(mktemp /tmp/waybar-openmeteo.XXXXXX)
    if curl -sf --compressed --connect-timeout 10 "$API" -o "$tmp" 2>/dev/null \
       && jq -e '.current.temperature_2m != null' "$tmp" >/dev/null 2>&1; then
        mv -f "$tmp" "$CACHE"
    else
        rm -f "$tmp"
    fi
fi

if [ ! -f "$CACHE" ]; then
    echo '{"text":"","tooltip":"Weather unavailable"}'
    exit 0
fi

# ---- 取标量;缺失 -> "--" ----
g() { jq -r "$1 // \"--\"" "$CACHE" 2>/dev/null; }

is_day=$(g '.current.is_day')
[ "$is_day" = "--" ] && is_day=1
cur_code=$(g '.current.weather_code')
cur_temp=$(r "$(g '.current.temperature_2m')")
cur_feel=$(r "$(g '.current.apparent_temperature')")
cur_hum=$(g '.current.relative_humidity_2m')
cur_pres=$(r "$(g '.current.pressure_msl')")
cur_wspd=$(r "$(g '.current.wind_speed_10m')")
cur_wdeg_raw=$(g '.current.wind_direction_10m')
cur_wdeg=$(r "$cur_wdeg_raw")
[ "$cur_wdeg_raw" = "--" ] && cur_wdeg_raw=0

icon=$(wmo_icon "$cur_code" "$is_day")
desc=$(wmo_text "$cur_code")
wdir=$(wind_dir_cn "$cur_wdeg_raw")

# 当前整点 -> hourly 下标(取不到回退 0)
now_key=$(date +%Y-%m-%dT%H:00)
hidx=$(jq -r --arg t "$now_key" '(.hourly.time | index($t)) // 0' "$CACHE" 2>/dev/null)
[ -z "$hidx" ] || [ "$hidx" = "null" ] && hidx=0

vis_m=$(jq -r --argjson i "$hidx" '.hourly.visibility[$i] // empty' "$CACHE" 2>/dev/null)
if [ -n "$vis_m" ]; then
    vis_km=$(awk -v m="$vis_m" 'BEGIN{ printf "%.1f", m/1000 }')
else
    vis_km="--"
fi

sr=$(g '.daily.sunrise[0]')
ss=$(g '.daily.sunset[0]')
[ "$sr" != "--" ] && sr="${sr:11:5}"
[ "$ss" != "--" ] && ss="${ss:11:5}"
uv=$(r "$(g '.daily.uv_index_max[0]')")
pop=$(g '.daily.precipitation_probability_max[0]')
psum=$(jq -r '.daily.precipitation_sum[0] // empty' "$CACHE" 2>/dev/null)
if [ -n "$psum" ]; then
    psum=$(awk -v x="$psum" 'BEGIN{ printf "%.1f", x }')
else
    psum="--"
fi

# 逐时未来 6 小时
mapfile -t h_time < <(jq -r --argjson i "$hidx" '.hourly.time[$i:$i+6][]?'         "$CACHE" 2>/dev/null)
mapfile -t h_temp < <(jq -r --argjson i "$hidx" '.hourly.temperature_2m[$i:$i+6][]?' "$CACHE" 2>/dev/null)
mapfile -t h_code < <(jq -r --argjson i "$hidx" '.hourly.weather_code[$i:$i+6][]?'   "$CACHE" 2>/dev/null)
hourly_line="逐时 "
for k in "${!h_time[@]}"; do
    hh="${h_time[$k]:11:2}"
    hh=$((10#${hh:-0}))
    ht=$(r "${h_temp[$k]:-}")
    hi=$(wmo_icon "${h_code[$k]:-x}" "$is_day")
    hourly_line+=" ${hh}时 ${ht}°${hi} "
done

# 三日预报
days=(今天 明天 后天)
forecast=""
for i in 0 1 2; do
    d_code=$(jq -r ".daily.weather_code[$i] // \"x\""        "$CACHE" 2>/dev/null)
    d_max=$(r "$(jq -r ".daily.temperature_2m_max[$i] // \"--\"" "$CACHE" 2>/dev/null)")
    d_min=$(r "$(jq -r ".daily.temperature_2m_min[$i] // \"--\"" "$CACHE" 2>/dev/null)")
    d_icon=$(wmo_icon "$d_code" 1)
    d_desc=$(wmo_text "$d_code")
    forecast+=$'\n'"${d_icon}  ${days[$i]}  ${d_min}° ~ ${d_max}°C  ${d_desc}"
done

# ---- 组装 tooltip(真实换行,交给 jq 编码为合法 JSON)----
sep="─────────────────────"
tooltip="<b>${CITY}  ${cur_temp}°C  ${desc}</b>"
tooltip+=$'\n'"体感 ${cur_feel}°C  |  湿度 ${cur_hum}%  |  ${wdir} ${cur_wspd} km/h"
tooltip+=$'\n'"气压 ${cur_pres} hPa  |  能见度 ${vis_km} km  |  风向 ${cur_wdeg}°"
tooltip+=$'\n'"日出 ${sr}  ·  日落 ${ss}  |  UV ${uv}  降水 ${pop}% (${psum}mm)"
tooltip+=$'\n'"${sep}"
tooltip+=$'\n'"${hourly_line}"
tooltip+=$'\n'"${sep}"
tooltip+="${forecast}"

jq -cn --arg x "$icon" --arg t "$tooltip" '{text:$x, tooltip:$t}'
```

- [ ] **Step 4: 跑测试确认全部通过**

```bash
bash ~/.config/waybar/test_weather.sh; echo "exit=$?"
```

Expected: 单元段全 `PASS`;fixture 段 `PASS 输出是合法 JSON`、`text=晴昼字形`、各 `tooltip 含…` 断言全 `PASS`,`exit=0`。

- [ ] **Step 5: Commit**

```bash
cd ~/.config/waybar
git add weather.sh test_weather.sh
git -c commit.gpgsign=false commit -m "feat(weather): Open-Meteo fetch/render/output + fixture test

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 联网冒烟 + waybar 重启验证

**Files:** 无代码改动(验证 + spec 状态更新)

- [ ] **Step 1: 删缓存,真实联网跑一次**

```bash
rm -f /tmp/waybar-openmeteo.json
~/.config/waybar/weather.sh | tee /tmp/weather-smoke.json | jq .
echo "exit=$?"
```

Expected: 输出合法 JSON;`.text` 为某天气字形;`.tooltip` 各行数值合理(温度/湿度/风/气压/能见度/日出日落/UV/逐时 6 段/三日)。`exit=0`。若此刻无网络:应输出 `{"text":"","tooltip":"Weather unavailable"}` 且 `exit=0`(降级正常)。

- [ ] **Step 2: 确认缓存已落盘且新鲜**

```bash
ls -la /tmp/waybar-openmeteo.json
jq '.current.temperature_2m, (.hourly.time|length), (.daily.time|length // (.daily.weather_code|length))' /tmp/waybar-openmeteo.json
```

Expected: 文件存在;`current.temperature_2m` 为数字;hourly/daily 数组非空。

- [ ] **Step 3: 重启 waybar 验证模块**

```bash
~/.config/waybar/launch.sh
sleep 2
pgrep -x waybar && echo "waybar 运行中"
```

Expected: waybar 新进程运行;**冷启动日志不再出现** `pkeyutl: Error loading key`(QWeather 密钥报错消失)。人工:鼠标悬停天气图标,确认 tooltip 多行内容渲染正确(中文方位、逐时、三日、日出日落、Nerd Font 图标)。

- [ ] **Step 4: 更新 spec 状态并提交**

把 spec 顶部 `状态: 已批准设计,待实现` 改为 `状态: 已实现`:

```bash
cd ~/.config/waybar
sed -i 's/^状态: 已批准设计,待实现$/状态: 已实现/' \
    docs/superpowers/specs/2026-05-18-weather-open-meteo-design.md
git add docs/superpowers/specs/2026-05-18-weather-open-meteo-design.md
git -c commit.gpgsign=false commit -m "docs: mark Open-Meteo weather spec implemented

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

Expected: 提交成功。`weather/ed25519-public.pem` 按 spec 留原地不删。

---

## Self-Review

**1. Spec coverage:**
- API 请求(经纬度/current/hourly/daily/timezone/forecast_days) → Task 2 Step 3 `API=` ✓
- 缓存 900s + 原子写 + 失败不污染 → Task 2 Step 3 取数段 ✓
- WMO→中文 / WMO→图标(昼夜) → Task 1 Step 3 `wmo_text`/`wmo_icon`,Task 1 单测 ✓
- 风向角→16 方位 → Task 1 `wind_dir_cn` + 单测 ✓
- tooltip 四行 + 逐时6h + 三日 → Task 2 Step 3 组装段 + fixture 断言 ✓
- 能见度取 hourly 当前整点 / 跨日回退前6项 → `hidx` 逻辑 + `[]?` 安全切片 ✓
- 缺失字段 → "--" → `g()` 默认 `// "--"`、`r()` 非数字回退、单测 `r null/''` ✓
- 输出契约不变 / config.jsonc 不动 → `jq -cn '{text,tooltip}'`,无 config 改动 ✓
- 错误降级 `Weather unavailable` exit 0 → Task 2 Step 3 ✓ ;Task 3 Step 1 验证
- 废弃公钥留原地 → Task 3 Step 4 注明,无删除 ✓
- 测试三件套(fixture / 映射单测 / 联网冒烟) → Task 1+2 测试脚本 + Task 3 ✓

无遗漏。

**2. Placeholder scan:** 无 TBD/TODO;每个 code step 含完整可粘贴代码;命令含预期输出。✓

**3. Type consistency:** 函数名 `r` / `wmo_text` / `wmo_icon` / `wind_dir_cn` / `g` 在 Task1 定义、Task2 主流程与测试中调用一致;`WEATHER_LIB_ONLY` 守卫值 `1` 测试与脚本一致;`CACHE` 路径 `/tmp/waybar-openmeteo.json` 脚本与 fixture 测一致;字形码点(`` 等)单测断言与 `wmo_icon` 实现一致。✓
