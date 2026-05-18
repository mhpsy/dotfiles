# 把 meaning 开头的英文词性前缀拆进 pos 数组（按 & / , 分隔）。
# 无可识别前缀 → pos:[]、meaning 原样。其余字段保留。
.words |= map(
  (.meaning // "") as $m
  | ($m | capture("^(?<p>[A-Za-z]+\\.(?:\\s*[&/,]\\s*[A-Za-z]+\\.)*)\\s*(?<rest>.*)$") // null) as $c
  | if $c == null
    then .pos = [] | .meaning = $m
    else .pos = ([$c.p | splits("\\s*[&/,]\\s*")] | map(select(length>0)))
       |  .meaning = $c.rest
    end
  | {word, pos, meaning}
)
