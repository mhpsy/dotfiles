# Waybar 每日单词模块 — 设计文档

日期：2026-05-15
状态：已确认，待实现

## 背景与目标

把现有的 waybar `custom/quotes`（中文鸡汤）模块改造成「每日单词」模块：

- 本地词库随机抽取，每天 10 个单词
- 当天这 10 个固定，逐个轮换展示，每 10 秒换一个
- 跨天自动换一批新的 10 个
- bar 上显示「单词 中文释义」，tooltip 显示今日全部 10 个词
- 无联网、无定时器、无缓存文件 —— 纯 stateless

## 方案

**方案 A：日期种子确定性选取。** `quotes.sh` 每次运行时用当天日期作为随机种子，确定性地从词库里挑 10 个下标；当天恒定，跨天变化。轮换下标由 epoch 取模得出。契合现有 `quotes.sh` 的「epoch 取模」无状态哲学。

否决的备选：

- 方案 B（/tmp 缓存今日 10 词）：多了缓存读写、日期判断、并发写风险，无收益。
- 方案 C（词库 + systemd timer 每日生成）：引入 timer 单元，对此需求过度设计。

## 文件结构

| 文件 | 角色 | 变化 |
|---|---|---|
| `~/.config/waybar/wordlist.json` | 词库池（~300 中高频英文词 + 中文释义） | 新增 |
| `~/.config/waybar/quotes.json` | 旧鸡汤数据，不再使用 | 删除 |
| `~/.config/waybar/quotes.sh` | 单词逻辑（日期种子抽 10 + 轮换） | 重写 |
| `~/.config/waybar/config.jsonc` | `custom/quotes` 的 `interval` 改为 10 | 改 1 行 |

`custom/quotes` 模块名与其在 bar 中的位置不变，仅替换其背后的脚本与数据。

## 数据格式 `wordlist.json`

```json
{
  "words": [
    { "word": "abandon", "meaning": "v. 放弃；抛弃" },
    { "word": "benefit",  "meaning": "n. 益处 v. 受益" }
  ]
}
```

- ~300 个中高频词（四六级/考研常见区间），每条含词性 + 中文释义。
- 用户后续可直接往 `words` 数组追加对象扩充。

## `quotes.sh` 算法（方案 A）

```
1. 读 wordlist.json，总词数 N
2. 今日种子 seed = $(date +%Y%m%d)            # 例：20260515
3. 用 seed 作为 shuf 的 --random-source 派生源，
   对 0..N-1 下标做确定性洗牌，取前 10 个 → 今日下标集合
4. 轮换位置 pos = (epoch / 10) % 10           # 每 10 秒进 1，0..9 循环
5. 取今日下标集合中第 pos 个词 w
6. 输出 JSON:
   {
     "text": "<w.word> <w.meaning>",
     "tooltip": "今日单词\n<word>  <meaning>\n... 全 10 个 ..."
   }
```

实现要点（已定，无歧义）：

- 种子洗牌方法**定为**：`shuf -i 0-$((N-1)) -n 10 --random-source=<(openssl enc -aes-256-ctr -pass pass:"$seed" -nosalt </dev/zero 2>/dev/null)`。
  以 `seed=$(date +%Y%m%d)` 作为口令，openssl 产生确定性字节流喂给 shuf，
  保证当天恒定、跨天变化。不使用 awk Fisher-Yates 备选。
- bar `text`：直接 `<word> <meaning>` 原样拼接，**不解析、不剥词性**
  （例：`abandon v. 放弃；抛弃`）。保持简单，无字符串处理逻辑。
- `tooltip`：今日全部 10 词，每行 `<word>  <meaning>`。

## 错误处理

- `wordlist.json` 不存在 / 为空 / 系统无 `jq` → 输出 `{"text":"","class":"empty"}`，
  bar 上不显示该模块、不报错（与现有 `quotes.sh` 空处理一致）。
- 词库不足 10 个 → 有几个取几个，不崩溃。

## 不做（YAGNI）

- 不做音标/发音
- 不做点击翻页 / 上一个下一个
- 不做生词本 / 收藏
- 不做联网词典兜底

## 验收标准

1. 重启 waybar 后 `custom/quotes` 位置显示「单词 释义」，每 ~10 秒换一个。
2. 一整天内反复观察，10 个词循环且集合不变。
3. 修改系统日期到次日（或等到次日），10 个词整体换新。
4. 鼠标悬停显示今日全部 10 词的 tooltip。
5. 删除/清空 `wordlist.json` 时 waybar 不报错、该模块不显示。
