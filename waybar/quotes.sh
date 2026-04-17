#!/bin/bash
QUOTES_FILE="$HOME/.config/waybar/quotes.json"

count=$(jq '.quotes | length' "$QUOTES_FILE")

if [ "$count" -eq 0 ]; then
    echo '{"text": "", "class": "empty"}'
    exit 0
fi

# Change every 10 minutes based on epoch time
index=$(( ($(date +%s) / 600) % count ))
text=$(jq -r ".quotes[$index].text" "$QUOTES_FILE")
tooltip=$(jq -r ".quotes[$index].tooltip" "$QUOTES_FILE")

echo "{\"text\": \"$text\", \"tooltip\": \"$tooltip\"}"
