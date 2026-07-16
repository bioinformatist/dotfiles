#!/usr/bin/env bash

set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
GET_WEATHER="$ROOT/home/desktop/eww-scripts/get-weather"
SEARCH_WEATHER="$ROOT/home/desktop/eww-scripts/search-weather"
TEST_TMP=$(mktemp -d)
FAKE_BIN="$TEST_TMP/bin"
FAKE_CURL_LOG="$TEST_TMP/curl.log"

cleanup() {
  rm -rf "$TEST_TMP"
}
trap cleanup EXIT

mkdir -p "$FAKE_BIN"

write_executable() {
  local path="$1"

  tee "$path" >/dev/null
  chmod +x "$path"
}

write_executable "$FAKE_BIN/curl" <<'SCRIPT'
#!/usr/bin/env bash
set -u

for argument in "$@"; do
  printf "<%s>\n" "$argument" >> "$FAKE_CURL_LOG"
done
printf "%s\n" "---" >> "$FAKE_CURL_LOG"

case " $* " in
  *"nominatim.openstreetmap.org/search"*)
    printf "%s\n" "$FAKE_NOMINATIM_RESPONSE"
    ;;
  *"api.met.no/weatherapi/locationforecast/2.0/compact"*)
    if [ "${FAKE_MET_FAILURE:-0}" = 1 ]; then
      exit 28
    fi
    printf "%s\n" "$FAKE_MET_RESPONSE"
    ;;
  *)
    printf "unexpected curl request: %s\n" "$*" >&2
    exit 97
    ;;
esac
SCRIPT

for command in notify-send eww zenity; do
  write_executable "$FAKE_BIN/$command" <<'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT
done

export PATH="$FAKE_BIN:$PATH"
export FAKE_CURL_LOG
export FAKE_NOMINATIM_RESPONSE='[{"lat":"31.2304","lon":"121.4737","display_name":"上海, 中国"}]'
export FAKE_MET_RESPONSE='{"properties":{"timeseries":[{"data":{"instant":{"details":{"air_temperature":22.6}},"next_1_hours":{"summary":{"symbol_code":"partlycloudy_day"}}}}]}}'

new_case() {
  local name="$1"

  CASE_DIR="$TEST_TMP/$name"
  export HOME="$CASE_DIR/home"
  export XDG_CACHE_HOME="$CASE_DIR/cache"
  mkdir -p "$HOME" "$XDG_CACHE_HOME/eww"
  : > "$FAKE_CURL_LOG"
  unset FAKE_MET_FAILURE
}

write_location() {
  local city="${1:-Shanghai}"

  jq -cn --arg city "$city" \
    '{lat:31.2304, lon:121.4737, city:$city}' > "$XDG_CACHE_HOME/eww/weather_location.json"
}

write_weather() {
  local temp="$1"
  local city="${2:-Shanghai}"

  jq -cn --argjson temp "$temp" --arg city "$city" \
    '{temp:$temp, icon:"☁", city:$city, symbol:"cloudy", stale:false}' \
    > "$XDG_CACHE_HOME/eww/weather_data.json"
}

curl_calls() {
  grep -c '^---$' "$FAKE_CURL_LOG" || true
}

assert_json() {
  local json="$1"
  local filter="$2"

  jq -e "$filter" <<< "$json" >/dev/null
}

assert_bounded_curl_calls() {
  local expected="$1"

  [ "$(grep -c '^<--connect-timeout>$' "$FAKE_CURL_LOG" || true)" -eq "$expected" ]
  [ "$(grep -c '^<--max-time>$' "$FAKE_CURL_LOG" || true)" -eq "$expected" ]
  [ "$(grep -c '^<--retry>$' "$FAKE_CURL_LOG" || true)" -eq "$expected" ]
}

test_fresh_valid_cache() {
  local output

  new_case fresh-valid-cache
  write_location
  write_weather 17

  output=$(bash "$GET_WEATHER")
  assert_json "$output" '.temp == 17 and .city == "Shanghai" and .stale == false'
  [ "$(curl_calls)" -eq 0 ]
  printf '%s\n' 'ok - fresh valid cache: cached result, no network call'
}

test_stale_cache_refresh() {
  local output cache

  new_case stale-cache-refresh
  write_location
  write_weather 4
  touch -d '31 minutes ago' "$XDG_CACHE_HOME/eww/weather_data.json"

  output=$(bash "$GET_WEATHER")
  cache=$(<"$XDG_CACHE_HOME/eww/weather_data.json")
  assert_json "$output" '.temp == 23 and .symbol == "partlycloudy_day" and .stale == false'
  assert_json "$cache" '.temp == 23 and .stale == false'
  [ "$(curl_calls)" -eq 1 ]
  assert_bounded_curl_calls 1
  if compgen -G "$XDG_CACHE_HOME/eww/.weather_data.*" >/dev/null; then
    return 1
  fi
  printf '%s\n' 'ok - stale cache plus MET success: one bounded refresh, atomic replacement'
}

test_stale_cache_failure() {
  local output before after

  new_case stale-cache-failure
  write_location
  write_weather 9
  touch -d '31 minutes ago' "$XDG_CACHE_HOME/eww/weather_data.json"
  before=$(sha256sum "$XDG_CACHE_HOME/eww/weather_data.json")
  export FAKE_MET_FAILURE=1

  output=$(bash "$GET_WEATHER")
  after=$(sha256sum "$XDG_CACHE_HOME/eww/weather_data.json")
  assert_json "$output" '.temp == 9 and .stale == true'
  [ "$before" = "$after" ]
  [ "$(curl_calls)" -eq 1 ]
  assert_bounded_curl_calls 1
  printf '%s\n' 'ok - failed refresh: stale JSON emitted, valid cache retained'
}

test_no_location() {
  local output

  new_case no-location
  output=$(bash "$GET_WEATHER")
  assert_json "$output" '.temp == "--" and .city == "Set location" and .stale == false'
  [ "$(curl_calls)" -eq 0 ]
  printf '%s\n' 'ok - no location: stable manual-selection placeholder, no network call'
}

test_manual_location_safe_argv() {
  local query location weather

  new_case manual-location-safe-argv
  write_location "Previous City"
  write_weather 8 "Previous City"
  query="City 'quoted'; \$(touch $CASE_DIR/pwned) 雪"

  bash "$SEARCH_WEATHER" "$query"

  [ ! -e "$CASE_DIR/pwned" ]
  grep -F -x -- "<q=$query>" "$FAKE_CURL_LOG" >/dev/null
  location=$(<"$XDG_CACHE_HOME/eww/weather_location.json")
  weather=$(<"$XDG_CACHE_HOME/eww/weather_data.json")
  assert_json "$location" '.lat == 31.2304 and .lon == 121.4737 and .city == "上海"'
  assert_json "$weather" '.temp == 23 and .city == "上海" and .stale == false'
  [ "$(curl_calls)" -eq 2 ]
  assert_bounded_curl_calls 2
  if compgen -G "$XDG_CACHE_HOME/eww/.weather_location.*" >/dev/null; then
    return 1
  fi
  if compgen -G "$XDG_CACHE_HOME/eww/.weather_data.*" >/dev/null; then
    return 1
  fi
  printf '%s\n' 'ok - manual location: spaces, quotes, metacharacters, and Unicode stay argv/data'
}

test_fresh_valid_cache
test_stale_cache_refresh
test_stale_cache_failure
test_no_location
test_manual_location_safe_argv

printf '%s\n' 'all weather cases passed'
