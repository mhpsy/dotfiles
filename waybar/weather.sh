#!/bin/bash
# Waybar weather module — QWeather API with JWT (ED25519)

KEY_DIR="$HOME/.config/waybar/weather"
PRIVATE_KEY="$KEY_DIR/ed25519-private.pem"
KID="TDPPQY832D"
SUB="3M2BEU6TKD"
API_HOST="https://jn44ua62f7.re.qweatherapi.com"

CACHE_NOW="/tmp/waybar-qweather-now.json"
CACHE_FORECAST="/tmp/waybar-qweather-3d.json"
LOC_CACHE="/tmp/waybar-weather-loc.json"
CACHE_AGE=900  # 15 minutes

# --- helpers ---
base64url() {
    openssl base64 -A | tr '+/' '-_' | tr -d '='
}

generate_jwt() {
    local now=$(($(date +%s) - 30))
    local exp=$((now + 3600))
    local tmp="/tmp/waybar-jwt-$$"

    local header=$(printf '{"alg":"EdDSA","kid":"%s"}' "$KID" | base64url)
    local payload=$(printf '{"sub":"%s","iat":%d,"exp":%d}' "$SUB" "$now" "$exp" | base64url)

    printf '%s.%s' "$header" "$payload" > "$tmp"
    local signature=$(openssl pkeyutl -sign -inkey "$PRIVATE_KEY" -rawin -in "$tmp" | base64url)
    rm -f "$tmp"

    printf '%s.%s.%s' "$header" "$payload" "$signature"
}

get_icon() {
    case "$1" in
        100|150) printf '\uf185' ;;
        101|102|103|151|152|153) printf '\uf6c4' ;;
        104) printf '\uf0c2' ;;
        300|301|350|351) printf '\uf73d' ;;
        302|303|304) printf '\uf76c' ;;
        305|306|307|308|309|310|311|312|313|314|315|316|317|318|399) printf '\uf740' ;;
        400|401|402|403|404|405|406|407|408|409|410|456|457|499) printf '\uf2dc' ;;
        500|501|502|503|504|505|506|507|508|509|510|511|512|513|514|515) printf '\uf75f' ;;
        *) printf '\uf0c2' ;;
    esac
}

# --- location (Shenzhen Bao'an) ---
lat="22.57"
lon="113.85"
city="深圳宝安"
location="${lon},${lat}"

# --- fetch weather if stale ---
if [[ ! -f "$CACHE_NOW" ]] || [[ $(($(date +%s) - $(stat -c %Y "$CACHE_NOW"))) -gt $CACHE_AGE ]]; then
    token=$(generate_jwt)
    auth="Authorization: Bearer $token"

    now_data=$(curl -sf --compressed --connect-timeout 10 -H "$auth" \
        "${API_HOST}/v7/weather/now?location=${location}&lang=zh" 2>/dev/null)
    forecast_data=$(curl -sf --compressed --connect-timeout 10 -H "$auth" \
        "${API_HOST}/v7/weather/3d?location=${location}&lang=zh" 2>/dev/null)

    # Only cache if API returned success (code 200)
    if echo "$now_data" | jq -e '.code == "200"' &>/dev/null; then
        echo "$now_data" > "$CACHE_NOW"
    fi
    if echo "$forecast_data" | jq -e '.code == "200"' &>/dev/null; then
        echo "$forecast_data" > "$CACHE_FORECAST"
    fi
fi

if [[ ! -f "$CACHE_NOW" ]]; then
    echo '{"text":"","tooltip":"Weather unavailable"}'
    exit 0
fi

# --- parse current ---
temp=$(jq -r '.now.temp' "$CACHE_NOW")
feels=$(jq -r '.now.feelsLike' "$CACHE_NOW")
text=$(jq -r '.now.text' "$CACHE_NOW")
icon_code=$(jq -r '.now.icon' "$CACHE_NOW")
humidity=$(jq -r '.now.humidity' "$CACHE_NOW")
wind_dir=$(jq -r '.now.windDir' "$CACHE_NOW")
wind_scale=$(jq -r '.now.windScale' "$CACHE_NOW")

icon=$(get_icon "$icon_code")

# --- build tooltip ---
tooltip="<b>${city}  ${temp}°C</b>  ${text}\n"
tooltip+="体感 ${feels}°C  |  湿度 ${humidity}%  |  ${wind_dir} ${wind_scale}级\n"
tooltip+="─────────────────────\n"

if [[ -f "$CACHE_FORECAST" ]]; then
    days=("今天" "明天" "后天")
    for i in 0 1 2; do
        d_icon_code=$(jq -r ".daily[$i].iconDay" "$CACHE_FORECAST")
        d_text=$(jq -r ".daily[$i].textDay" "$CACHE_FORECAST")
        d_max=$(jq -r ".daily[$i].tempMax" "$CACHE_FORECAST")
        d_min=$(jq -r ".daily[$i].tempMin" "$CACHE_FORECAST")
        d_icon=$(get_icon "$d_icon_code")
        tooltip+="${d_icon}  <b>${days[$i]}</b>  ${d_min}° ~ ${d_max}°C  ${d_text}\n"
    done
fi

printf '{"text":"%s","tooltip":"%s"}\n' "$icon" "$tooltip"
