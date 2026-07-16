#!/usr/bin/env bash

set -euo pipefail

ROOT=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
GET_PROFILE="$ROOT/home/desktop/eww-scripts/get-power-profile"
SET_PROFILE="$ROOT/home/desktop/eww-scripts/set-power-profile"
TEST_TMP=$(mktemp -d)
FAKE_BIN="$TEST_TMP/bin"
FAKE_BUSCTL_LOG="$TEST_TMP/busctl.log"
FAKE_NOTIFY_LOG="$TEST_TMP/notify.log"

cleanup() {
  rm -rf "$TEST_TMP"
}
trap cleanup EXIT

mkdir -p "$FAKE_BIN"
: > "$FAKE_BUSCTL_LOG"
: > "$FAKE_NOTIFY_LOG"

write_executable() {
  local path="$1"

  tee "$path" >/dev/null
  chmod +x "$path"
}

write_executable "$FAKE_BIN/busctl" <<'SCRIPT'
#!/usr/bin/env bash
set -u

printf "%s\n" "$*" >> "$FAKE_BUSCTL_LOG"

args=("$@")
command=
command_index=-1
for index in "${!args[@]}"; do
  case "${args[index]}" in
    list|get-property|set-property)
      command="${args[index]}"
      command_index="$index"
      break
      ;;
  esac
done

if [ "$command" = list ]; then
  if [ "$command_index" -ne "$((${#args[@]} - 1))" ]; then
    printf "Too many arguments\n" >&2
    exit 1
  fi
  if [ "$*" != "--system --no-pager --auto-start=false --no-legend list" ]; then
    printf "unexpected busctl list command: %s\n" "$*" >&2
    exit 97
  fi
  if [ "${FAKE_LIST_FAIL:-0}" = 1 ]; then
    printf "simulated service query failure\n" >&2
    exit 1
  fi
  printf "net.hadess.PowerProfiles.Helper - - -\n"
  if [ "${FAKE_SERVICE_AVAILABLE:-0}" = 1 ]; then
    printf "net.hadess.PowerProfiles - - -\n"
  fi
  exit 0
fi

case " $* " in
  *" get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile "*)
    if [ "${FAKE_PROPERTY_FAIL:-}" = ActiveProfile ]; then
      printf "simulated ActiveProfile failure\n" >&2
      exit 1
    fi
    printf "{\"type\":\"s\",\"data\":\"%s\"}\n" "$FAKE_ACTIVE"
    ;;
  *" get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles Profiles "*)
    if [ "${FAKE_PROPERTY_FAIL:-}" = Profiles ]; then
      printf "simulated Profiles failure\n" >&2
      exit 1
    fi
    printf "%s\n" "$FAKE_PROFILES_JSON"
    ;;
  *" get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles PerformanceDegraded "*)
    if [ "${FAKE_PROPERTY_FAIL:-}" = PerformanceDegraded ]; then
      printf "simulated PerformanceDegraded failure\n" >&2
      exit 1
    fi
    printf "{\"type\":\"s\",\"data\":\"%s\"}\n" "${FAKE_DEGRADED:-}"
    ;;
  *" set-property net.hadess.PowerProfiles /net/hadess/PowerProfiles net.hadess.PowerProfiles ActiveProfile s "*)
    [ "${FAKE_SET_FAIL:-0}" != 1 ] || {
      printf "simulated setter failure\n" >&2
      exit 1
    }
    ;;
  *)
    printf "unexpected busctl command: %s\n" "$*" >&2
    exit 97
    ;;
esac
SCRIPT

write_executable "$FAKE_BIN/notify-send" <<'SCRIPT'
#!/usr/bin/env bash
printf "%s\n" "$*" >> "$FAKE_NOTIFY_LOG"
SCRIPT

export PATH="$FAKE_BIN:$PATH"
export FAKE_BUSCTL_LOG FAKE_NOTIFY_LOG
export FAKE_ACTIVE=balanced
export FAKE_DEGRADED=lap-detected
export FAKE_PROFILES_JSON='{
  "type":"aa{sv}",
  "data":[
    [{"Profile":{"type":"s","data":"power-saver"}}],
    [{"Profile":{"type":"s","data":"balanced"}}],
    [{"Profile":{"type":"s","data":"performance"}}],
    [{"Profile":{"type":"s","data":"balanced"}}]
  ]
}'

assert_json() {
  local json="$1"
  local filter="$2"

  jq -e "$filter" <<< "$json" >/dev/null
}

reset_logs() {
  : > "$FAKE_BUSCTL_LOG"
  : > "$FAKE_NOTIFY_LOG"
  unset FAKE_LIST_FAIL FAKE_PROPERTY_FAIL FAKE_SET_FAIL
}

assert_list_command() {
  head -n 1 "$FAKE_BUSCTL_LOG" \
    | grep -Fx -- '--system --no-pager --auto-start=false --no-legend list' >/dev/null
}

test_missing_service() {
  local state

  reset_logs
  export FAKE_SERVICE_AVAILABLE=0
  state=$(bash "$GET_PROFILE")
  assert_json "$state" '. == {available:false, active:"", profiles:[], degraded:""}'
  [ "$(wc -l < "$FAKE_BUSCTL_LOG")" -eq 1 ]
  assert_list_command
  [ ! -s "$FAKE_NOTIFY_LOG" ]
  printf '%s\n' 'ok - profile state: exact service absence normalizes to unavailable'
}

test_normalized_state() {
  local state

  reset_logs
  export FAKE_SERVICE_AVAILABLE=1
  state=$(bash "$GET_PROFILE")
  assert_json "$state" '
    .available == true
    and .active == "balanced"
    and .profiles == ["power-saver", "balanced", "performance"]
    and .degraded == "lap-detected"
  '
  assert_list_command
  [ ! -s "$FAKE_NOTIFY_LOG" ]
  printf '%s\n' 'ok - profile state: active, ordered profiles, and degradation are normalized'
}

test_service_query_failure() {
  reset_logs
  export FAKE_LIST_FAIL=1
  if bash "$GET_PROFILE" >/dev/null 2>&1; then
    return 1
  fi
  assert_list_command
  grep -F 'Failed to query power-profiles-daemon: simulated service query failure' \
    "$FAKE_NOTIFY_LOG" >/dev/null
  printf '%s\n' 'ok - profile state: service-query failures notify and propagate'
}

test_property_read_failure() {
  reset_logs
  export FAKE_SERVICE_AVAILABLE=1
  export FAKE_PROPERTY_FAIL=Profiles
  if bash "$GET_PROFILE" >/dev/null 2>&1; then
    return 1
  fi
  assert_list_command
  grep -F 'Failed to read Profiles: simulated Profiles failure' \
    "$FAKE_NOTIFY_LOG" >/dev/null
  printf '%s\n' 'ok - profile state: property-read failures notify and propagate'
}

test_unknown_profile_rejected() {
  reset_logs
  export FAKE_SERVICE_AVAILABLE=1
  if bash "$SET_PROFILE" turbo >/dev/null 2>&1; then
    return 1
  fi
  if grep -F ' set-property ' "$FAKE_BUSCTL_LOG" >/dev/null; then
    return 1
  fi
  grep -F 'Unknown power profile: turbo' "$FAKE_NOTIFY_LOG" >/dev/null
  printf '%s\n' 'ok - profile setter: unknown daemon profile is rejected before mutation'
}

test_setter_success_and_failure() {
  reset_logs
  export FAKE_SERVICE_AVAILABLE=1
  bash "$SET_PROFILE" performance
  grep -F ' set-property ' "$FAKE_BUSCTL_LOG" | grep -F ' ActiveProfile s performance' >/dev/null

  reset_logs
  export FAKE_SET_FAIL=1
  if bash "$SET_PROFILE" power-saver >/dev/null 2>&1; then
    return 1
  fi
  grep -F 'Failed to set power-saver: simulated setter failure' "$FAKE_NOTIFY_LOG" >/dev/null
  printf '%s\n' 'ok - profile setter: daemon-reported values mutate and D-Bus failures propagate'
}

test_missing_service
test_normalized_state
test_service_query_failure
test_property_read_failure
test_unknown_profile_rejected
test_setter_success_and_failure
