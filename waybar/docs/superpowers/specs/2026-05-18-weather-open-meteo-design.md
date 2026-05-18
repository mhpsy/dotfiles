# Waybar 天气模块迁移至 Open-Meteo

日期: 2026-05-18
状态: 已实现

## 背景与问题

`~/.config/waybar/weather.sh` 当前使用 QWeather API,靠 ED25519 私钥签 JWT 认证。
该私钥文件 `weather/ed25519-private.pem` 已不存在(目录里只剩公钥),waybar 冷启动
日志确认 `pkeyutl: Error loading key`——**当前天气模块已完全失效**。QWeather 为
付费/需密钥方案,用户决定改用完全免费、无需 API key 的 Open-Meteo。

## 目标

- 用 Open-Meteo 替换 QWeather,移除 JWT / openssl / 密钥依赖。
- bar 上仍只显示一个天气图标(Nerd Font 码点),格式契约不变。
- tooltip 在原有内容基础上额外显示:日出/日落、UV 指数、降水概率+降水量、
  气压、能见度、精确风向角、未来 6 小时逐时预报。

## 非目标(YAGNI)

- 不做 IP 自动定位,坐标继续硬编码深圳宝安 `22.57, 113.85`(用户已确认)。
- 不改 `config.jsonc`(输出契约不变,`interval: 900` 与脚本缓存周期一致)。
- 不删除 `weather/ed25519-public.pem`(用户资产,留原地;本 spec 标注其已废弃)。

## 架构

单文件重写 `~/.config/waybar/weather.sh`,无其它文件改动。流程:

1. **缓存检查**:`/tmp/waybar-openmeteo.json`,新鲜期 900s。
2. **取数**(仅在缓存过期/缺失时):一次 `curl` 调用 Open-Meteo。
3. **健壮性**:仅当 `curl` 退出码 0 且 `jq -e '.current.temperature_2m != null'`
   通过时才覆盖缓存——沿用现脚本"失败不污染好缓存"的策略。
4. **解析 + 格式化**:从缓存文件读取,生成 waybar JSON。
5. **输出**:用 `jq -n --arg` 安全编码 JSON(比现脚本的 `printf` 更稳,避免
   内容含引号/特殊字符时坏 JSON)。

### API 请求

```
https://api.open-meteo.com/v1/forecast
  ?latitude=22.57&longitude=113.85
  &current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,
           weather_code,pressure_msl,wind_speed_10m,wind_direction_10m
  &hourly=temperature_2m,weather_code,visibility,precipitation_probability
  &daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,
         uv_index_max,precipitation_probability_max,precipitation_sum
  &timezone=Asia/Shanghai&forecast_days=3
```

单位:温度 °C、风速 km/h、气压 hPa、能见度 m(显示时换算 km)——均为
Open-Meteo 默认单位,无需额外参数。

说明:Open-Meteo 不返回天气文字,只给数字 WMO code,需自建映射(见下)。
能见度只在 `hourly` 提供,不在 `current`;"当前能见度"取 `hourly` 数组中
匹配当前整点的值。

### WMO code → 中文描述 + 图标码点

图标码点用 bash `$'\uXXXX'` 形式(Nerd Font)。复用现脚本码点:
``(日)``(云日)``(云)``(小雨)``(大雨)
``(雪)``(雾/霾)``(雷);新增夜间码点
``(月)``(云月)。

晴(0)/晴间多云(1)/多云(2)按 `current.is_day`(1=昼,0=夜)切换昼夜
码点;其余天气昼夜同码点。

| WMO code | 中文 | 昼码点 | 夜码点 |
|----------|------|--------|--------|
| 0 | 晴 | `` | `` |
| 1 | 晴间多云 | `` | `` |
| 2 | 多云 | `` | `` |
| 3 | 阴 | `` | `` |
| 45 | 雾 | `` | `` |
| 48 | 雾凇 | `` | `` |
| 51 | 小毛毛雨 | `` | `` |
| 53 | 毛毛雨 | `` | `` |
| 55 | 大毛毛雨 | `` | `` |
| 56 | 冻毛毛雨 | `` | `` |
| 57 | 强冻毛毛雨 | `` | `` |
| 61 | 小雨 | `` | `` |
| 63 | 中雨 | `` | `` |
| 65 | 大雨 | `` | `` |
| 66 | 冻雨 | `` | `` |
| 67 | 强冻雨 | `` | `` |
| 71 | 小雪 | `` | `` |
| 73 | 中雪 | `` | `` |
| 75 | 大雪 | `` | `` |
| 77 | 米雪 | `` | `` |
| 80 | 小阵雨 | `` | `` |
| 81 | 阵雨 | `` | `` |
| 82 | 强阵雨 | `` | `` |
| 85 | 小阵雪 | `` | `` |
| 86 | 阵雪 | `` | `` |
| 95 | 雷阵雨 | `` | `` |
| 96 | 雷阵雨伴小冰雹 | `` | `` |
| 99 | 雷阵雨伴冰雹 | `` | `` |
| 其它/缺失 | 未知 | `` | `` |

### 风向角 → 中文 16 方位

`idx = round(deg / 22.5) mod 16`,`idx=0` 对应正北(0°),顺时针每 22.5° 递增。
查表:

```
0:北   1:北东北 2:东北  3:东东北
4:东   5:东东南 6:东南  7:南东南
8:南   9:南西南 10:西南 11:西西南
12:西  13:西西北 14:西北 15:北西北
```

### tooltip 布局

(下示意中的图标为说明用;实际渲染为上表 Nerd Font 码点。pango 标记
`<b>` 加粗,行间用字面 `\n`。)

```
<b>深圳宝安  26°C  晴</b>
体感 28°C  |  湿度 65%  |  东南 12 km/h
气压 1013 hPa  |  能见度 24.0 km  |  风向 135°
日出 06:12  ·  日落 18:54  |  UV 8  降水 30% (0.2mm)
─────────────────────
逐时  14时 26°<icon>  15时 27°<icon>  16时 27°<icon>  17时 26°<icon>  18时 24°<icon>  19时 23°<icon>
─────────────────────
<icon>  今天  22° ~ 28°C  晴
<icon>  明天  21° ~ 27°C  多云
<icon>  后天  20° ~ 25°C  小雨
```

- 第 1 行:城市 + 当前温度(`current.temperature_2m` 四舍五入取整)+ 当前 WMO 中文。
- 第 2 行:体感(取整)、湿度 %、风向(16 方位)+ 风速 km/h(取整)。
- 第 3 行:气压 hPa(取整)、能见度 km(`m/1000`,一位小数)、风向原始角度(取整)。
- 第 4 行:日出/日落(`daily.sunrise[0]`/`sunset[0]` 取 `HH:MM`)、
  `daily.uv_index_max[0]`(取整)、`daily.precipitation_probability_max[0]`%
  与 `daily.precipitation_sum[0]`mm(一位小数)。
- 逐时:在 `hourly.time` 中定位当前整点(`date +%Y-%m-%dT%H:00`)下标 `i`,
  取 `i..i+5` 共 6 项,显示 `H时 <temp取整>°<该小时WMO字形>`。若定位不到
  (如跨日边界)则取数组前 6 项兜底。
- 三日预报:`daily[0..2]`,`min° ~ max°C` + WMO 中文 + 字形;
  天名固定 `今天/明天/后天`。

### 输出契约(不变)

```
{"text":"<当前WMO字形>","tooltip":"<上述多行字符串>"}
```

bar 仍只显示图标(`config.jsonc` 中 `format: "{}"`,`return-type: "json"`)。

### 错误处理

- 取数失败且无缓存 → 输出 `{"text":"","tooltip":"Weather unavailable"}`
  并 `exit 0`(与现脚本一致,bar 静默)。
- 取数失败但有旧缓存 → 用旧缓存渲染(不污染好缓存)。
- 单个字段缺失(`jq` 取到 `null`)→ 该字段显示 `--`,不整体崩溃。

## 测试

脚本结构上把"取数写缓存"与"读缓存→渲染"解耦,使渲染可脱网测试:

1. **fixture 测试**:准备一份真实 Open-Meteo 返回 JSON 存为 fixture,
   放到缓存路径(`mtime` 设为当前以保证"新鲜"→跳过取数),运行脚本,断言:
   - 输出是合法 JSON(`jq -e .` 通过);
   - `text` 字段为该 fixture WMO code 对应的预期字形;
   - `tooltip` 含预期各行关键字(体感 / 日出 / 逐时 / 今天)。
2. **映射单测**:对 WMO→中文/图标、风向角→方位 两个纯函数,喂边界值
   (WMO 0/45/61/95/未知;角度 0/90/135/350)断言输出。
3. **联网冒烟**:删缓存真实跑一次,`jq .` 校验,人工核对 tooltip 数值合理。

## 涉及文件

- 改写:`~/.config/waybar/weather.sh`
- 不变:`~/.config/waybar/config.jsonc`
- 废弃(留原地,不删):`~/.config/waybar/weather/ed25519-public.pem`
  (`ed25519-private.pem` 早已缺失)
