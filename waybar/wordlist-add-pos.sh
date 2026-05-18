#!/usr/bin/env bash
# 一次性：用 wordlist-pos.jq 把 wordlist.json 升级为含 pos 数组的新结构。
# 幂等：已含 pos 字段则跳过。原子写，先备份。
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WL="${WORDLIST_FILE:-$HOME/.config/waybar/wordlist.json}"
[ -r "$WL" ] || { echo "no $WL" >&2; exit 1; }
if jq -e '.words[0] | has("pos")' "$WL" >/dev/null 2>&1; then
  echo "already has pos, skip"; exit 0
fi
cp -f "$WL" "$WL.bak"
tmp=$(mktemp "${WL}.XXXXXX")
jq -f "$DIR/wordlist-pos.jq" "$WL" > "$tmp" && mv -f "$tmp" "$WL"
echo "rewritten: $WL (backup: $WL.bak)"
