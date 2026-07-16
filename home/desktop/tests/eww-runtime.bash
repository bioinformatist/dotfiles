#!/usr/bin/env bash

set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
MANAGE_BARS="$ROOT/home/desktop/eww-scripts/manage-bars"
TOGGLE_POPUP="$ROOT/home/desktop/eww-scripts/toggle-popup"
CLOSE_POPUPS="$ROOT/home/desktop/eww-scripts/close-popups"
GET_AUDIO_SINKS="$ROOT/home/desktop/eww-scripts/get-audio-sinks"
GET_VOLUME="$ROOT/home/desktop/eww-scripts/get-volume"
TEST_TMP=$(mktemp -d)
FAKE_BIN="$TEST_TMP/bin"
FAKE_EWW_STATE="$TEST_TMP/eww.state"
FAKE_EWW_LOG="$TEST_TMP/eww.log"

cleanup() {
  rm -rf "$TEST_TMP"
}
trap cleanup EXIT

mkdir -p "$FAKE_BIN"
: > "$FAKE_EWW_STATE"
: > "$FAKE_EWW_LOG"

write_executable() {
  local path="$1"

  tee "$path" >/dev/null
  chmod +x "$path"
}

write_executable "$FAKE_BIN/hyprctl" <<'SCRIPT'
#!/usr/bin/env bash
set -u
printf "%s\n" "$FAKE_MONITORS"
SCRIPT

write_executable "$FAKE_BIN/eww" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

command=${1:?}
shift
case "$command" in
  active-windows)
    while IFS= read -r id; do
      [ -n "$id" ] && printf "%s: window\n" "$id"
    done < "$FAKE_EWW_STATE"
    ;;
  close)
    printf "close" >> "$FAKE_EWW_LOG"
    for id in "$@"; do
      printf "\t%s" "$id" >> "$FAKE_EWW_LOG"
      grep -Fxv -- "$id" "$FAKE_EWW_STATE" > "$FAKE_EWW_STATE.next" || true
      mv "$FAKE_EWW_STATE.next" "$FAKE_EWW_STATE"
    done
    printf "\n" >> "$FAKE_EWW_LOG"
    ;;
  open)
    window=${1:?}
    shift
    printf "open\t%s" "$window" >> "$FAKE_EWW_LOG"
    id=""
    while [ "$#" -gt 0 ]; do
      printf "\t%s" "$1" >> "$FAKE_EWW_LOG"
      if [ "$1" = --id ]; then
        shift
        id=${1:?}
        printf "\t%s" "$id" >> "$FAKE_EWW_LOG"
      fi
      shift
    done
    printf "\n" >> "$FAKE_EWW_LOG"
    if [ "${FAKE_EWW_FAIL_WINDOW:-}" = "$window" ]; then
      exit 1
    fi
    grep -Fxq "$id" "$FAKE_EWW_STATE" || printf "%s\n" "$id" >> "$FAKE_EWW_STATE"
    ;;
  *)
    printf "unexpected eww command: %s\n" "$command" >&2
    exit 97
    ;;
esac
SCRIPT

write_executable "$FAKE_BIN/pactl" <<'SCRIPT'
#!/usr/bin/env bash
set -u

case "$*" in
  "get-default-sink") printf "%s\n" "${FAKE_DEFAULT_SINK:-auto_null}" ;;
  "--format=json list sinks") printf "%s\n" "$FAKE_SINKS_JSON" ;;
  "get-sink-volume @DEFAULT_SINK@") printf "Volume: front-left: 65536 / 42%% / 0.00 dB\n" ;;
  "get-source-volume @DEFAULT_SOURCE@") printf "Volume: front-left: 65536 / 55%% / 0.00 dB\n" ;;
  "get-sink-mute @DEFAULT_SINK@") printf "Mute: no\n" ;;
  "get-source-mute @DEFAULT_SOURCE@") printf "Mute: no\n" ;;
  "get-default-source") printf "fake_source\n" ;;
  "list sources") exit 0 ;;
  "info") exit 0 ;;
  "subscribe") /bin/sleep 10 ;;
  *)
    printf "unexpected pactl command: %s\n" "$*" >&2
    exit 97
    ;;
esac
SCRIPT

write_executable "$FAKE_BIN/wpctl" <<'SCRIPT'
#!/usr/bin/env bash
printf "unexpected wpctl command: %s\n" "$*" >&2
exit 97
SCRIPT

write_executable "$FAKE_BIN/amixer" <<'SCRIPT'
#!/usr/bin/env bash
exit 0
SCRIPT

export PATH="$FAKE_BIN:$PATH"
export FAKE_EWW_STATE FAKE_EWW_LOG

# shellcheck disable=SC1090,SC1091 # The repository root determines this source path.
source "$MANAGE_BARS"
# shellcheck disable=SC1090,SC1091 # The repository root determines this source path.
source "$GET_VOLUME"

assert_json() {
  local json="$1"
  local filter="$2"

  jq -e "$filter" <<< "$json" >/dev/null
}

reset_eww() {
  : > "$FAKE_EWW_STATE"
  : > "$FAKE_EWW_LOG"
  unset FAKE_EWW_FAIL_WINDOW
}

test_monitor_mapping() {
  local state

  export FAKE_MONITORS='[
    {"name":"DP-2","id":9,"model":"Same Model"},
    {"name":"HDMI-A-1","id":2,"model":"Same Model"}
  ]'
  state=$(monitor_state)
  assert_json "$state" '
    length == 2
    and .[0] == {name:"HDMI-A-1", id:2, screen_index:0}
    and .[1] == {name:"DP-2", id:9, screen_index:1}
  '
  printf '%s\n' 'ok - monitor mapping: non-contiguous IDs and duplicate models use sorted ordinals'
}

test_popup_types_and_toggle() {
  local type

  for type in audio power profile; do
    reset_eww
    bash "$TOGGLE_POPUP" "$type" DP-2 9 1
    grep -F $'open\tpopup-closer' "$FAKE_EWW_LOG" | grep -F -- $'--screen\t1' >/dev/null
    grep -F $'open\t'"$type"'-popup' "$FAKE_EWW_LOG" | grep -F -- $'--screen\t1' >/dev/null
    if grep -F -- $'--arg' "$FAKE_EWW_LOG" >/dev/null; then
      return 1
    fi
    if grep -F -- $'--screen\tDP-2' "$FAKE_EWW_LOG" >/dev/null; then
      return 1
    fi
    [ "$(wc -l < "$FAKE_EWW_STATE")" -eq 2 ]

    bash "$TOGGLE_POPUP" "$type" DP-2 9 1
    [ ! -s "$FAKE_EWW_STATE" ]
  done
  printf '%s\n' 'ok - popup lifecycle: all types use numeric screens and active pairs toggle closed'
}

test_popup_dismiss_is_idempotent() {
  reset_eww
  bash "$TOGGLE_POPUP" power DP-2 9 1
  bash "$CLOSE_POPUPS" --once
  bash "$CLOSE_POPUPS" --once
  [ ! -s "$FAKE_EWW_STATE" ]
  printf '%s\n' 'ok - popup dismissal: repeated close callbacks leave all popup windows closed'
}

test_popup_validation_and_rollback() {
  reset_eww
  if bash "$TOGGLE_POPUP" unknown DP-2 9 1 >/dev/null 2>&1; then
    return 1
  fi
  if bash "$TOGGLE_POPUP" audio DP-2 invalid 1 >/dev/null 2>&1; then
    return 1
  fi
  if bash "$TOGGLE_POPUP" audio DP-2 9 invalid >/dev/null 2>&1; then
    return 1
  fi
  [ ! -s "$FAKE_EWW_STATE" ]

  export FAKE_EWW_FAIL_WINDOW=audio-popup
  if bash "$TOGGLE_POPUP" audio DP-2 9 1 >/dev/null 2>&1; then
    return 1
  fi
  [ ! -s "$FAKE_EWW_STATE" ]
  printf '%s\n' 'ok - popup validation: type and numeric fields reject bad input; partial open rolls back'
}

test_ordinal_change_reconciliation() {
  local dp_key

  reset_eww
  CURRENT_MONITORS='[
    {"name":"DP-2","id":5,"screen_index":0},
    {"name":"HDMI-A-1","id":9,"screen_index":1}
  ]'
  wait_for_stable_monitors() {
    printf '%s\n' "$CURRENT_MONITORS"
  }

  reconcile_bars
  bash "$TOGGLE_POPUP" audio DP-2 5 0
  dp_key=$(monitor_key DP-2)
  grep -Fxq "popup-audio-$dp_key" "$FAKE_EWW_STATE"

  : > "$FAKE_EWW_LOG"
  CURRENT_MONITORS='[
    {"name":"eDP-1","id":1,"screen_index":0},
    {"name":"DP-2","id":5,"screen_index":1},
    {"name":"HDMI-A-1","id":9,"screen_index":2}
  ]'
  reconcile_bars

  if grep -Fq "popup-audio-$dp_key" "$FAKE_EWW_STATE"; then
    return 1
  fi
  grep -F $'open\tbar' "$FAKE_EWW_LOG" | grep -F -- $'--screen\t1' | grep -F "bar-$dp_key" >/dev/null
  grep -F $'close' "$FAKE_EWW_LOG" | grep -F "popup-audio-$dp_key" >/dev/null
  [ "$(grep -c '^bar-' "$FAKE_EWW_STATE")" -eq 3 ]
  printf '%s\n' 'ok - topology reconciliation: ordinal changes close popups and reopen bars'
}

test_audio_availability() {
  local sinks status

  export FAKE_DEFAULT_SINK=auto_null
  export FAKE_SINKS_JSON='[
    {"index":31,"name":"auto_null","description":"Dummy Output","driver":"PipeWire","properties":{"device.class":"abstract","factory.name":"support.null-audio-sink"}}
  ]'
  sinks=$(bash "$GET_AUDIO_SINKS")
  status=$(get_audio_status)
  assert_json "$sinks" 'length == 0'
  assert_json "$status" '.available == false and .sink_vol == 42'

  export FAKE_DEFAULT_SINK=alsa_output.pci-0000_00_1f.3.analog-stereo
  export FAKE_SINKS_JSON='[
    {"index":42,"name":"alsa_output.pci-0000_00_1f.3.analog-stereo","description":"Front Headphones","driver":"PipeWire","state":"SUSPENDED","properties":{"device.api":"alsa","device.class":"sound","port.available":"no"}}
  ]'
  sinks=$(bash "$GET_AUDIO_SINKS")
  status=$(get_audio_status)
  assert_json "$sinks" 'length == 1 and .[0].id == "42" and .[0].active == true'
  assert_json "$status" '.available == true and .sink_vol == 42'

  export FAKE_DEFAULT_SINK=alsa_output.pci-0000_01_00.1.hdmi-stereo
  export FAKE_SINKS_JSON='[
    {"index":47,"name":"alsa_output.pci-0000_01_00.1.hdmi-stereo","description":"HDMI / DisplayPort 2","driver":"PipeWire","properties":{"device.api":"alsa","device.class":"sound"}}
  ]'
  sinks=$(bash "$GET_AUDIO_SINKS")
  status=$(get_audio_status)
  assert_json "$sinks" 'length == 1 and .[0].id == "47" and .[0].active == true'
  assert_json "$status" '.available == true and .sink_vol == 42'
  printf '%s\n' 'ok - audio availability: dummy-only hides audio while powered-off analog and HDMI remain real'
}

test_monitor_mapping
test_popup_types_and_toggle
test_popup_dismiss_is_idempotent
test_popup_validation_and_rollback
test_ordinal_change_reconciliation
test_audio_availability
