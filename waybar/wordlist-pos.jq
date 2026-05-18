# meaning 里所有英文词性标记（首部或夹在中间）拆进 pos 数组（保序去重）；
# 标记与分隔符(& / ,)去掉后，剩余释义片段用 ； 连接。无标记 → pos:[]、meaning 原样。
.words |= map(
  (.meaning // "") as $m
  | ([$m | scan("[A-Za-z]+\\.")]) as $toks
  | if ($toks | length) == 0
    then .pos = [] | .meaning = $m
    else .pos = ($toks | reduce .[] as $t ([]; if index($t) then . else . + [$t] end))
       |  .meaning = (
            $m
            | [splits("[A-Za-z]+\\.")]
            | map(gsub("^[\\s&/,]+|[\\s&/,]+$"; ""))
            | map(select(length > 0))
            | join("；")
          )
    end
  | {word, pos, meaning}
)
