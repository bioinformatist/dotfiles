#!/usr/bin/env bash

set -euo pipefail

[ "$#" -eq 1 ] || { echo "usage: exec-runner.bash EXEC_RUNNER" >&2; exit 2; }
runner_source="$(realpath -- "$1")"
[ -f "$runner_source" ] || { echo "exec runner does not exist: $runner_source" >&2; exit 2; }

test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
fake_bin="$test_root/fake bin"
mkdir -p "$fake_bin"

printf '#!%s\n' "$(command -v bash)" >"$fake_bin/codex"
cat >>"$fake_bin/codex" <<'FAKE_CODEX'
set -u

: "${FAKE_CODEX_MODE:?}" "${FAKE_COUNT_FILE:?}" "${FAKE_INVOCATION_LOG:?}" "${FAKE_PROMPT_LOG:?}" "${FAKE_LOCALE_LOG:?}"
printf '%s\n' invoked >>"$FAKE_COUNT_FILE"
printf '%s\n' "$@" >"$FAKE_INVOCATION_LOG"
if [ "${LC_ALL+x}" = x ]; then
  printf 'set:%s\n' "$LC_ALL" >"$FAKE_LOCALE_LOG"
else
  printf '%s\n' unset >"$FAKE_LOCALE_LOG"
fi

final_output=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--output-last-message" ]; then
    final_output="$2"
    shift 2
  else
    shift
  fi
done
cat >"$FAKE_PROMPT_LOG"
printf '%s\n' 'TOP_SECRET_STDERR /private/repository/path' >&2

emit_usage() {
  printf '%s\n' '{"type":"item.completed","item":{"type":"command_execution","aggregated_output":"TOP_SECRET_DIFF /private/repository/path"}}'
  printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":10,"cached_input_tokens":2,"output_tokens":3}}'
}

complete_report() {
  cat >"$final_output" <<'EOF'
STATUS: COMPLETE
STEPS: all steps done; verification passed
FILES CHANGED: scoped files
NOTES: no deviations
EOF
}

case "$FAKE_CODEX_MODE" in
  complete)
    emit_usage
    complete_report
    ;;
  unterminated_final)
    emit_usage
    {
      printf '%s\n' 'STATUS: COMPLETE'
      printf '%s\n' 'STEPS: all steps done; verification passed'
      printf '%s\n' 'FILES CHANGED: scoped files'
      printf '%s' 'NOTES: no deviations'
    } >"$final_output"
    ;;
  stopped)
    emit_usage
    cat >"$final_output" <<'EOF'
STATUS: STOPPED
STEPS: stopped at the required condition
STOPPED BECAUSE: deterministic test stop
FILES CHANGED: none
NOTES: worktree preserved
EOF
    ;;
  nonzero)
    emit_usage
    exit 17
    ;;
  rollout_budget_exhausted)
    printf '%s\n' '{"type":"error","message":"shared rollout token budget exhausted","request_id":"test"}'
    exit 1
    ;;
  rollout_budget_with_malformed_jsonl)
    printf '%s\n' '{"type":"error","message":"shared rollout token budget exhausted","request_id":"test"}'
    printf '%s\n' 'not-json'
    exit 1
    ;;
  nested_rollout_budget_text)
    printf '%s\n' '{"type":"item.completed","item":{"type":"agent_message","text":"shared rollout token budget exhausted"}}'
    exit 17
    ;;
  exit_124)
    emit_usage
    exit 124
    ;;
  exit_137)
    emit_usage
    exit 137
    ;;
  malformed_jsonl)
    printf '%s\n' not-json
    complete_report
    ;;
  malformed_final)
    emit_usage
    printf '%s\n' 'STATUS: COMPLETE' >"$final_output"
    ;;
  missing_final)
    emit_usage
    ;;
  oversize_final)
    emit_usage
    complete_report
    printf '%0200d\n' 0 >>"$final_output"
    ;;
  timeout)
    trap 'exit 130' INT TERM
    while true; do sleep 0.1; done
    ;;
  descendant)
    bash -c 'trap "" INT TERM; while true; do sleep 30; done' &
    printf '%s\n' "$!" >"$FAKE_CHILD_PID_FILE"
    trap 'exit 130' INT TERM
    while true; do sleep 0.1; done
    ;;
  signal)
    bash -c 'trap "" INT TERM; while true; do sleep 30; done' &
    printf '%s\n' "$!" >"$FAKE_CHILD_PID_FILE"
    trap 'exit 143' INT TERM
    while true; do sleep 0.1; done
    ;;
  quiet)
    printf '%s\n' '{"type":"turn.started"}'
    sleep 2
    emit_usage
    complete_report
    ;;
  oversize_event)
    printf '{"type":"item.completed","item":{"type":"command_execution","aggregated_output":"'
    printf '%0600d' 0
    printf '"}}\n'
    trap 'exit 130' INT TERM
    while true; do sleep 0.1; done
    ;;
esac
FAKE_CODEX
chmod +x "$fake_bin/codex"
export PATH="$fake_bin:$PATH"
export CODEX_IMPROVE_ROLES_JSON='{
  "standard":{"profile":"improve-executor","model":"gpt-5.6-sol","reasoningEffort":"medium","verbosity":"medium","sandbox":"workspace-write","approval":"never","writableRoots":[],"tokenLimit":120000,"reminders":[60000,30000,10000],"initialTimeout":5,"followupTimeout":4},
  "spark":{"profile":"improve-executor-spark","model":"gpt-5.3-codex-spark","reasoningEffort":"high","verbosity":"medium","sandbox":"workspace-write","approval":"never","writableRoots":[],"tokenLimit":100000,"reminders":[50000,25000,10000],"initialTimeout":5,"followupTimeout":4},
  "deep":{"profile":"improve-executor-deep","model":"gpt-5.6-sol","reasoningEffort":"xhigh","verbosity":"medium","sandbox":"workspace-write","approval":"never","writableRoots":[],"tokenLimit":160000,"reminders":[80000,40000,15000],"initialTimeout":7,"followupTimeout":6}
}'

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "expected '$2', got '$1' ($3)"; }
field() { sed -n "s/^$2=//p" "$1" | tail -n 1; }
assert_private() {
  mode="$(stat -c '%a' "$1")"
  case "$mode" in
    600|700) ;;
    *) fail "non-private permissions $mode on $1" ;;
  esac
}
assert_no_private_content() {
  file="$1"
  if grep -F -e TOP_SECRET_PLAN -e TOP_SECRET_DOSSIER -e TOP_SECRET_DIFF \
    -e TOP_SECRET_STDERR -e /private/repository/path "$file" >/dev/null; then
    fail "private execution content leaked into $file"
  fi
}

repo="$test_root/repo with spaces"
git -c init.defaultBranch=main init -q "$repo"
git -C "$repo" config user.email test@example.invalid
git -C "$repo" config user.name "Improve Test"
mkdir -p "$repo/plans"
printf '%s\n' "TOP_SECRET_PLAN /private/repository/path" >"$repo/plans/001 plan.md"
printf '%s\n' "committed" >"$repo/tracked.txt"
git -C "$repo" add .
git -C "$repo" commit -qm "test: initial"

case_root="$test_root/cases"
mkdir -p "$case_root"

start_case() {
  case_name="$1"
  case_dir="$case_root/$case_name"
  mkdir -p "$case_dir"
  export HOME="$case_dir/home"
  export XDG_STATE_HOME="$case_dir/state"
  export FAKE_COUNT_FILE="$case_dir/count"
  export FAKE_INVOCATION_LOG="$case_dir/invocation"
  export FAKE_PROMPT_LOG="$case_dir/prompt"
  export FAKE_LOCALE_LOG="$case_dir/locale"
  export FAKE_CHILD_PID_FILE="$case_dir/child-pid"
  export FAKE_CODEX_MODE="${2:-complete}"
  mkdir -p "$HOME"
  : >"$FAKE_COUNT_FILE"
  : >"$FAKE_INVOCATION_LOG"
  : >"$FAKE_PROMPT_LOG"
}

copy_runner() {
  runner="$case_dir/exec-runner"
  sed \
    -e 's/^kill_after_seconds=5$/kill_after_seconds=1/' \
    -e 's/^heartbeat_seconds=60$/heartbeat_seconds=1/' \
    -e 's/^quiet_seconds=180$/quiet_seconds=1/' \
    -e 's/^event_log_limit_bytes=33554432$/event_log_limit_bytes=512/' \
    -e 's/^final_output_limit_bytes=65536$/final_output_limit_bytes=256/' \
    -e 's/^poll_seconds=1$/poll_seconds=0.1/' \
    "$runner_source" >"$runner"
}

run_runner() {
  output="$case_dir/output"
  errors="$case_dir/errors"
  copy_runner
  set +e
  (
    cd "$repo"
    bash "$runner" "$@"
  ) >"$output" 2>"$errors"
  status="$?"
  set -e
}

assert_not_invoked() {
  [ ! -s "$FAKE_COUNT_FILE" ] || fail "$1 invoked Codex"
}

invocation_profile() {
  sed -n '/^-p$/{n;p;q;}' "$FAKE_INVOCATION_LOG"
}

assert_transport_case() {
  expected_status="$1"
  expected_result="$2"
  expected_reason="$3"
  assert_eq "$status" "$expected_status" "$case_name status"
  assert_eq "$(field "$output" IMPROVE_EXEC_RESULT)" "$expected_result" "$case_name result"
  assert_eq "$(field "$output" IMPROVE_EXEC_EXIT_REASON)" "$expected_reason" "$case_name reason"
  case "$(field "$output" IMPROVE_EXEC_ROLLOUT_BUDGET_EXHAUSTED)" in
    0|1) ;;
    *) fail "$case_name budget flag is not 0 or 1" ;;
  esac
  artifact_dir="$(field "$output" IMPROVE_EXEC_ARTIFACT_DIR)"
  case "$artifact_dir" in
    "$XDG_STATE_HOME/codex-improve/executions/"*) ;;
    *) fail "$case_name artifacts are outside per-user state: $artifact_dir" ;;
  esac
  [ -d "$artifact_dir" ] || fail "$case_name artifact directory missing"
  assert_private "$artifact_dir"
  for artifact in prompt.txt events.jsonl final.txt stderr.log timeout.log; do
    [ -e "$artifact_dir/$artifact" ] || fail "$case_name missing $artifact"
    assert_private "$artifact_dir/$artifact"
  done
  metric="$XDG_STATE_HOME/codex-improve/execution-metrics.jsonl"
  [ -s "$metric" ] || fail "$case_name metric missing"
  assert_private "$metric"
  jq -e '(.fuse_flags.rollout_budget_exhausted | type) == "boolean"' "$metric" >/dev/null ||
    fail "$case_name budget metric fuse is not Boolean"
  assert_no_private_content "$output"
  assert_no_private_content "$errors"
  assert_no_private_content "$metric"
}

start_case help
run_runner --help
assert_eq "$status" 0 "help status"
grep -F -- "--deep --revise WORKTREE DOSSIER" "$output" >/dev/null ||
  fail "help omits deep revision mode"
grep -F -- "--spark PLAN" "$output" >/dev/null ||
  fail "help omits Spark initial mode"
grep -F -- "--spark --revise WORKTREE DOSSIER" "$output" >/dev/null ||
  fail "help omits Spark revision mode"
grep -F -- "codex-improve-exec --recover WORKTREE DOSSIER" "$output" >/dev/null ||
  fail "help omits standard recovery mode"
grep -F -- "--spark --recover WORKTREE DOSSIER" "$output" >/dev/null ||
  fail "help omits Spark recovery mode"
grep -F -- "--deep --recover WORKTREE DOSSIER" "$output" >/dev/null ||
  fail "help omits deep recovery mode"
assert_not_invoked help

start_case missing_generated_config
copy_runner
set +e
env -u CODEX_IMPROVE_ROLES_JSON bash "$runner" --help >"$output" 2>"$errors"
status="$?"
set -e
assert_eq "$status" 0 "help without generated config status"
grep -F -- "codex-improve-exec PLAN" "$output" >/dev/null ||
  fail "help without generated config omits usage"
assert_not_invoked missing_generated_config

start_case missing_generated_config_action
copy_runner
set +e
(
  cd "$repo"
  env -u CODEX_IMPROVE_ROLES_JSON bash "$runner" "plans/001 plan.md"
) >"$output" 2>"$errors"
status="$?"
set -e
assert_eq "$status" 2 "missing generated config action status"
grep -F "generated executor role configuration is missing or invalid" "$errors" >/dev/null ||
  fail "missing generated config reason"
assert_not_invoked missing_generated_config_action
[ ! -e "$XDG_STATE_HOME/codex-improve/worktrees" ] ||
  fail "missing generated config action created a worktree directory"

start_case invalid
run_runner --revise
assert_eq "$status" 2 "invalid argument status"
assert_not_invoked invalid

start_case spark_then_deep
run_runner --spark --deep "plans/001 plan.md"
assert_eq "$status" 2 "Spark/deep argument status"
grep -F -- "--spark and --deep are mutually exclusive" "$errors" >/dev/null ||
  fail "Spark/deep rejection reason missing"
assert_not_invoked spark_then_deep

start_case deep_then_spark
run_runner --deep --spark "plans/001 plan.md"
assert_eq "$status" 2 "deep/Spark argument status"
grep -F -- "--spark and --deep are mutually exclusive" "$errors" >/dev/null ||
  fail "deep/Spark rejection reason missing"
assert_not_invoked deep_then_spark

printf '%s\n' "dirty caller" >"$repo/dirty.txt"
start_case initial complete
LC_ALL=C.UTF-8 run_runner "plans/001 plan.md"
assert_transport_case 0 COMPLETE completed
assert_eq "$(<"$FAKE_LOCALE_LOG")" "set:C.UTF-8" "explicit caller locale"
assert_eq "$(field "$output" IMPROVE_MODE)" initial "initial mode"
assert_eq "$(field "$output" IMPROVE_PROFILE)" improve-executor "initial profile"
assert_eq "$(field "$output" IMPROVE_EXEC_EXIT)" 0 "initial raw Codex status"
assert_eq "$(field "$output" IMPROVE_EXEC_ACTIVE_TIMEOUT_SECONDS)" 5 "normal initial timeout"
assert_eq "$(field "$output" IMPROVE_EXEC_ACTIVE_TOKEN_LIMIT)" 120000 "Standard token limit"
assert_eq "$(field "$output" IMPROVE_EXEC_ROLLOUT_BUDGET_EXHAUSTED)" 0 "initial budget flag"
initial_worktree="$(field "$output" IMPROVE_WORKTREE)"
[ -d "$initial_worktree" ] || fail "initial worktree was not preserved"
[ ! -e "$initial_worktree/dirty.txt" ] || fail "dirty caller state entered initial worktree"
assert_eq "$(grep -o TOP_SECRET_PLAN "$FAKE_PROMPT_LOG" | wc -l)" 1 "plan insertion count"
grep -Fx -- --strict-config "$FAKE_INVOCATION_LOG" >/dev/null || fail "strict config missing"
grep -Fx -- --ephemeral "$FAKE_INVOCATION_LOG" >/dev/null || fail "ephemeral mode missing"
grep -Fx -- --json "$FAKE_INVOCATION_LOG" >/dev/null || fail "JSONL mode missing"
grep -Fx -- --model "$FAKE_INVOCATION_LOG" >/dev/null || fail "model pin missing"
grep -Fx -- --sandbox "$FAKE_INVOCATION_LOG" >/dev/null || fail "sandbox pin missing"
grep -Fx -- memories "$FAKE_INVOCATION_LOG" >/dev/null || fail "memory disable missing"
grep -Fx -- goals "$FAKE_INVOCATION_LOG" >/dev/null || fail "goals disable missing"
grep -Fx -- multi_agent "$FAKE_INVOCATION_LOG" >/dev/null || fail "multi-agent disable missing"
if grep -Fx -- --ignore-user-config "$FAKE_INVOCATION_LOG" >/dev/null; then
  fail "user config was disabled"
fi
grep -Fx -- --output-last-message "$FAKE_INVOCATION_LOG" >/dev/null ||
  fail "final-message output missing"
grep -F -- "Do not load or reread the Improve skill" "$FAKE_PROMPT_LOG" >/dev/null ||
  fail "initial no-Improve/Ponytail boundary missing"
grep -F -- "A targeted reread is allowed after editing that" "$FAKE_PROMPT_LOG" >/dev/null ||
  fail "initial targeted-reread boundary missing"
jq -e '
  .mode == "initial"
  and .profile == "improve-executor"
  and .result == "COMPLETE"
  and .exit_reason == "completed"
  and .active_timeout_seconds == 5
  and .active_token_limit == 120000
  and .token_usage == {"input_tokens":10,"cached_input_tokens":2,"output_tokens":3}
  and .usage_observed == true
  and .tool_event_count == 1
  and .command_execution_count == 1
  and .file_change_count == 0
  and .mcp_tool_call_count == 0
  and .web_search_count == 0
  and (.prompt_bytes | type) == "number"
  and (.execution_id | test("^[a-z0-9-]+$"))
  and .fuse_flags == {
    "absolute_timeout":false,
    "event_log_limit":false,
    "wrapper_signal":false,
    "rollout_budget_exhausted":false
  }
' "$metric" >/dev/null || fail "initial metric"
execution_id="$(field "$output" IMPROVE_EXECUTION_ID)"
case "$execution_id" in
  *[!a-z0-9-]*|'') fail "invalid execution identity: $execution_id" ;;
esac
assert_eq "$(jq -r '.execution_id' "$metric")" "$execution_id" "metric execution identity"
grep -F "Authoritative runtime metadata: IMPROVE_EXECUTION_ID=$execution_id" \
  "$FAKE_PROMPT_LOG" >/dev/null || fail "prompt execution identity"

start_case stopped stopped
unset LC_ALL
run_runner "plans/001 plan.md"
assert_transport_case 0 STOPPED completed
assert_eq "$(<"$FAKE_LOCALE_LOG")" unset "unset caller locale"
grep -Fx -- "STATUS: STOPPED" "$output" >/dev/null || fail "STOPPED report not printed"

start_case deep deep
export FAKE_CODEX_MODE=complete
run_runner --deep "plans/001 plan.md"
assert_transport_case 0 COMPLETE completed
assert_eq "$(field "$output" IMPROVE_PROFILE)" improve-executor-deep "deep profile"
assert_eq "$(field "$output" IMPROVE_EXEC_ACTIVE_TIMEOUT_SECONDS)" 7 "deep initial timeout"
assert_eq "$(field "$output" IMPROVE_EXEC_ACTIVE_TOKEN_LIMIT)" 160000 "deep token limit"

start_case spark complete
run_runner --spark "plans/001 plan.md"
assert_transport_case 0 COMPLETE completed
assert_eq "$(field "$output" IMPROVE_PROFILE)" improve-executor-spark "Spark profile"
assert_eq "$(invocation_profile)" improve-executor-spark "Spark invoked profile"
assert_eq "$(field "$output" IMPROVE_EXEC_ACTIVE_TIMEOUT_SECONDS)" 5 "Spark initial timeout"
assert_eq "$(field "$output" IMPROVE_EXEC_ACTIVE_TOKEN_LIMIT)" 100000 "Spark token limit"
assert_eq "$(wc -l <"$FAKE_COUNT_FILE")" 1 "Spark invocation count"
grep -F -- "The user explicitly requires every verification command in the plan." \
  "$FAKE_PROMPT_LOG" >/dev/null || fail "Spark initial verification requirement missing"

start_case spark_nonzero nonzero
run_runner --spark "plans/001 plan.md"
assert_transport_case 1 INCONCLUSIVE codex_exit_17
assert_eq "$(field "$output" IMPROVE_PROFILE)" improve-executor-spark "failed Spark profile"
assert_eq "$(invocation_profile)" improve-executor-spark "failed Spark invoked profile"
assert_eq "$(wc -l <"$FAKE_COUNT_FILE")" 1 "failed Spark invocation count"
spark_failure_worktree="$(field "$output" IMPROVE_WORKTREE)"
[ -d "$spark_failure_worktree" ] || fail "failed Spark worktree was not preserved"

transport_failure() {
  name="$1"
  fake_mode="$2"
  expected_reason="$3"
  start_case "$name" "$fake_mode"
  run_runner "plans/001 plan.md"
  assert_transport_case 1 INCONCLUSIVE "$expected_reason"
  preserved_worktree="$(field "$output" IMPROVE_WORKTREE)"
  [ -d "$preserved_worktree" ] || fail "$name worktree was not preserved"
}

transport_failure nonzero nonzero codex_exit_17
assert_eq "$(field "$output" IMPROVE_EXEC_EXIT)" 17 "nonzero raw Codex status"
transport_failure rollout_budget_exhausted rollout_budget_exhausted rollout_budget_exhausted
assert_eq "$(field "$output" IMPROVE_EXEC_EXIT)" 1 "budget raw Codex status"
assert_eq "$(field "$output" IMPROVE_EXEC_ROLLOUT_BUDGET_EXHAUSTED)" 1 "budget flag"
assert_eq "$(wc -l <"$FAKE_COUNT_FILE")" 1 "budget invocation count"
jq -e '.fuse_flags.rollout_budget_exhausted == true' "$metric" >/dev/null ||
  fail "budget metric fuse"
transport_failure rollout_budget_with_malformed_jsonl rollout_budget_with_malformed_jsonl codex_exit_1
assert_eq "$(field "$output" IMPROVE_EXEC_EXIT)" 1 "malformed budget raw Codex status"
assert_eq "$(field "$output" IMPROVE_EXEC_ROLLOUT_BUDGET_EXHAUSTED)" 0 "malformed budget flag"
assert_eq "$(wc -l <"$FAKE_COUNT_FILE")" 1 "malformed budget invocation count"
jq -e '.fuse_flags.rollout_budget_exhausted == false' "$metric" >/dev/null ||
  fail "malformed budget metric fuse"
transport_failure nested_rollout_budget_text nested_rollout_budget_text codex_exit_17
assert_eq "$(field "$output" IMPROVE_EXEC_ROLLOUT_BUDGET_EXHAUSTED)" 0 "nested budget flag"
jq -e '.fuse_flags.rollout_budget_exhausted == false' "$metric" >/dev/null ||
  fail "nested budget text set metric fuse"
transport_failure exit_124 exit_124 codex_exit_124
assert_eq "$(field "$output" IMPROVE_EXEC_EXIT)" 124 "natural 124 raw Codex status"
jq -e '.fuse_flags.absolute_timeout == false' "$metric" >/dev/null ||
  fail "natural 124 set timeout fuse"
transport_failure exit_137 exit_137 codex_exit_137
assert_eq "$(field "$output" IMPROVE_EXEC_EXIT)" 137 "natural 137 raw Codex status"
jq -e '.fuse_flags.absolute_timeout == false' "$metric" >/dev/null ||
  fail "natural 137 set timeout fuse"
transport_failure malformed_jsonl malformed_jsonl invalid_event_log
transport_failure malformed_final malformed_final invalid_final_output
transport_failure missing_final missing_final empty_final_output
transport_failure oversize_final oversize_final final_output_limit
transport_failure timeout timeout absolute_timeout
jq -e '.fuse_flags.absolute_timeout == true' "$metric" >/dev/null ||
  fail "deadline omitted timeout fuse"
timeout_log="$(field "$output" IMPROVE_EXEC_ARTIFACT_DIR)/timeout.log"
grep -F 'timeout: sending signal INT to command' "$timeout_log" >/dev/null ||
  fail "deadline omitted deterministic private timeout marker"
transport_failure oversize_event oversize_event event_log_limit
assert_eq "$(field "$output" IMPROVE_EXEC_EVENT_LOG_LIMIT_HIT)" 1 "event fuse field"

start_case descendant descendant
run_runner "plans/001 plan.md"
assert_transport_case 1 INCONCLUSIVE absolute_timeout
descendant_worktree="$(field "$output" IMPROVE_WORKTREE)"
[ -d "$descendant_worktree" ] || fail "descendant timeout removed worktree"
descendant_pid="$(<"$FAKE_CHILD_PID_FILE")"
for _ in $(seq 1 20); do
  kill -0 "$descendant_pid" 2>/dev/null || break
  sleep 0.1
done
if kill -0 "$descendant_pid" 2>/dev/null; then
  kill -KILL "$descendant_pid" 2>/dev/null || true
  fail "timeout descendant survived"
fi

start_case quiet quiet
run_runner "plans/001 plan.md"
assert_transport_case 0 COMPLETE completed
jq -e '.quiet_interval_observed == true and .max_event_gap_seconds >= 1' "$metric" >/dev/null ||
  fail "quiet interval metric"
if grep -F 'no new JSONL event' "$errors" >/dev/null; then
  fail "quiet observation printed a second progress form"
fi
heartbeat_count="$(sed -n '/^codex-improve-exec: elapsed=/p' "$errors" | wc -l)"
unique_heartbeat_count="$(
  sed -n 's/^codex-improve-exec: elapsed=\([0-9][0-9]*\)s .*/\1/p' "$errors" |
    sort -u |
    wc -l
)"
assert_eq "$heartbeat_count" "$unique_heartbeat_count" "quiet heartbeat cadence"

start_case unterminated_final unterminated_final
run_runner "plans/001 plan.md"
assert_transport_case 0 COMPLETE completed

start_case runtime_closure complete
copy_runner
runtime_bin="$case_dir/runtime-bin"
mkdir -p "$runtime_bin"
for command in \
  bash basename cat codex date git jq mkdir mktemp realpath sed sleep tail timeout wc; do
  ln -s "$(command -v "$command")" "$runtime_bin/$command"
done
output="$case_dir/output"
errors="$case_dir/errors"
set +e
(
  cd "$repo"
  PATH="$runtime_bin" "$runtime_bin/bash" "$runner" "plans/001 plan.md"
) >"$output" 2>"$errors"
status="$?"
set -e
assert_transport_case 0 COMPLETE completed

start_case signal signal
copy_runner
output="$case_dir/output"
errors="$case_dir/errors"
(
  cd "$repo"
  exec bash "$runner" "plans/001 plan.md"
) >"$output" 2>"$errors" &
wrapper_pid="$!"
for _ in $(seq 1 50); do
  [ -s "$FAKE_CHILD_PID_FILE" ] && break
  sleep 0.1
done
[ -s "$FAKE_CHILD_PID_FILE" ] || fail "signal case did not start descendant"
kill -TERM "$wrapper_pid"
set +e
wait "$wrapper_pid"
status="$?"
set -e
assert_transport_case 1 INCONCLUSIVE wrapper_signal_TERM
signal_worktree="$(field "$output" IMPROVE_WORKTREE)"
[ -d "$signal_worktree" ] || fail "signal removed worktree"
signal_child_pid="$(<"$FAKE_CHILD_PID_FILE")"
for _ in $(seq 1 20); do
  kill -0 "$signal_child_pid" 2>/dev/null || break
  sleep 0.1
done
if kill -0 "$signal_child_pid" 2>/dev/null; then
  kill -KILL "$signal_child_pid" 2>/dev/null || true
  fail "signal-resistant descendant survived cancellation"
fi

start_case home_fallback complete
unset XDG_STATE_HOME
run_runner "plans/001 plan.md"
fallback_worktree="$(field "$output" IMPROVE_WORKTREE)"
case "$fallback_worktree" in
  "$HOME/.local/state/codex-improve/worktrees/"*) ;;
  *) fail "HOME state fallback was not used: $fallback_worktree" ;;
esac

start_case second_user complete
run_runner "plans/001 plan.md"
second_worktree="$(field "$output" IMPROVE_WORKTREE)"
case "$second_worktree" in
  "$XDG_STATE_HOME/codex-improve/worktrees/"*) ;;
  *) fail "second user XDG state was not used: $second_worktree" ;;
esac
case "$second_worktree" in
  "$fallback_worktree"|"$case_root/home_fallback/"*) fail "users shared state" ;;
esac

revision_worktree="$test_root/revision worktree"
git -C "$repo" worktree add -q -b codex/improve-revision-test "$revision_worktree" HEAD
printf '%s\n' "preserve this diff" >>"$revision_worktree/tracked.txt"
dossier="$test_root/revision dossier.md"
printf '%s\n' "TOP_SECRET_DOSSIER /private/repository/path" >"$dossier"
revision_status_before="$(git -C "$revision_worktree" status --short)"
worktrees_before="$(git -C "$repo" worktree list --porcelain)"

start_case count_failure complete
copy_runner
failure_bin="$case_dir/failure-bin"
mkdir -p "$failure_bin"
printf '#!%s\nexit 9\n' "$(command -v bash)" >"$failure_bin/sed"
chmod +x "$failure_bin/sed"
output="$case_dir/output"
errors="$case_dir/errors"
set +e
(
  cd "$repo"
  PATH="$failure_bin:$PATH" bash "$runner" --revise "$revision_worktree" "$dossier"
) >"$output" 2>"$errors"
status="$?"
set -e
assert_transport_case 1 INCONCLUSIVE invalid_final_output

start_case revision complete
run_runner --revise "$revision_worktree" "$dossier"
assert_transport_case 0 COMPLETE completed
assert_eq "$(field "$output" IMPROVE_MODE)" revision "revision mode"
assert_eq "$(field "$output" IMPROVE_BRANCH)" codex/improve-revision-test "revision branch"
assert_eq "$(field "$output" IMPROVE_PROFILE)" improve-executor "revision profile"
assert_eq "$(field "$output" IMPROVE_EXEC_ACTIVE_TIMEOUT_SECONDS)" 4 "normal revision timeout"
assert_eq "$(field "$output" IMPROVE_EXEC_ACTIVE_TOKEN_LIMIT)" 120000 "Standard revision token limit"
assert_eq "$(git -C "$revision_worktree" status --short)" "$revision_status_before" "revision diff preservation"
assert_eq "$(git -C "$repo" worktree list --porcelain)" "$worktrees_before" "revision worktree reuse"
assert_eq "$(grep -o TOP_SECRET_DOSSIER "$FAKE_PROMPT_LOG" | wc -l)" 1 "dossier insertion count"
grep -F -- "Do not load or reread the" "$FAKE_PROMPT_LOG" >/dev/null ||
  fail "revision recon prohibition missing"
grep -F -- "A targeted reread is allowed after editing that" "$FAKE_PROMPT_LOG" >/dev/null ||
  fail "revision targeted-reread boundary missing"

start_case spark_revision complete
run_runner --spark --revise "$revision_worktree" "$dossier"
assert_transport_case 0 COMPLETE completed
assert_eq "$(field "$output" IMPROVE_PROFILE)" improve-executor-spark "Spark revision profile"
assert_eq "$(invocation_profile)" improve-executor-spark "Spark revision invoked profile"
assert_eq "$(field "$output" IMPROVE_EXEC_ACTIVE_TIMEOUT_SECONDS)" 4 "Spark revision timeout"
assert_eq "$(field "$output" IMPROVE_EXEC_ACTIVE_TOKEN_LIMIT)" 100000 "Spark revision token limit"
assert_eq "$(git -C "$revision_worktree" status --short)" "$revision_status_before" "Spark revision diff preservation"
assert_eq "$(git -C "$repo" worktree list --porcelain)" "$worktrees_before" "Spark revision worktree reuse"
grep -F -- "The user explicitly requires every verification command named by the dossier." \
  "$FAKE_PROMPT_LOG" >/dev/null || fail "Spark revision verification requirement missing"

start_case deep_revision complete
run_runner --deep --revise "$revision_worktree" "$dossier"
assert_transport_case 0 COMPLETE completed
assert_eq "$(field "$output" IMPROVE_PROFILE)" improve-executor-deep "deep revision profile"
assert_eq "$(field "$output" IMPROVE_EXEC_ACTIVE_TIMEOUT_SECONDS)" 6 "deep revision timeout"
assert_eq "$(field "$output" IMPROVE_EXEC_ACTIVE_TOKEN_LIMIT)" 160000 "deep revision token limit"

start_case recovery complete
run_runner --recover "$revision_worktree" "$dossier"
assert_transport_case 0 COMPLETE completed
assert_eq "$(field "$output" IMPROVE_MODE)" recovery "recovery mode"
assert_eq "$(field "$output" IMPROVE_BRANCH)" codex/improve-revision-test "recovery branch"
assert_eq "$(field "$output" IMPROVE_PROFILE)" improve-executor "recovery profile"
assert_eq "$(invocation_profile)" improve-executor "recovery invoked profile"
assert_eq "$(field "$output" IMPROVE_EXEC_ACTIVE_TIMEOUT_SECONDS)" 4 "normal recovery timeout"
assert_eq "$(field "$output" IMPROVE_EXEC_ACTIVE_TOKEN_LIMIT)" 120000 "Standard recovery token limit"
assert_eq "$(git -C "$revision_worktree" status --short)" "$revision_status_before" "recovery diff preservation"
assert_eq "$(git -C "$repo" worktree list --porcelain)" "$worktrees_before" "recovery worktree reuse"
assert_eq "$(grep -o TOP_SECRET_DOSSIER "$FAKE_PROMPT_LOG" | wc -l)" 1 "recovery dossier insertion count"
grep -F -- "completing exactly one bounded recovery slice after an inconclusive" \
  "$FAKE_PROMPT_LOG" >/dev/null || fail "recovery one-slice contract missing"
grep -F -- "Preserve the existing diff and" "$FAKE_PROMPT_LOG" >/dev/null ||
  fail "recovery diff preservation contract missing"
grep -F -- "only the dossier's permitted paths" "$FAKE_PROMPT_LOG" >/dev/null ||
  fail "recovery path boundary missing"
grep -F -- "COMPLETE means" "$FAKE_PROMPT_LOG" >/dev/null ||
  fail "recovery completion boundary missing"
grep -F -- "Never decompose or recover this slice." "$FAKE_PROMPT_LOG" >/dev/null ||
  fail "recursive recovery prohibition missing"
assert_eq "$(wc -l <"$FAKE_COUNT_FILE")" 1 "recovery invocation count"
jq -e '
  .mode == "recovery"
  and .profile == "improve-executor"
  and .result == "COMPLETE"
  and .exit_reason == "completed"
  and .active_timeout_seconds == 4
  and .active_token_limit == 120000
  and .token_usage == {"input_tokens":10,"cached_input_tokens":2,"output_tokens":3}
  and .tool_event_count == 1
' "$metric" >/dev/null || fail "recovery metric"

start_case spark_recovery complete
run_runner --spark --recover "$revision_worktree" "$dossier"
assert_transport_case 0 COMPLETE completed
assert_eq "$(field "$output" IMPROVE_MODE)" recovery "Spark recovery mode"
assert_eq "$(field "$output" IMPROVE_PROFILE)" improve-executor-spark "Spark recovery profile"
assert_eq "$(invocation_profile)" improve-executor-spark "Spark recovery invoked profile"
assert_eq "$(field "$output" IMPROVE_EXEC_ACTIVE_TIMEOUT_SECONDS)" 4 "Spark recovery timeout"
assert_eq "$(field "$output" IMPROVE_EXEC_ACTIVE_TOKEN_LIMIT)" 100000 "Spark recovery token limit"
assert_eq "$(git -C "$revision_worktree" status --short)" "$revision_status_before" "Spark recovery diff preservation"
assert_eq "$(wc -l <"$FAKE_COUNT_FILE")" 1 "Spark recovery invocation count"

start_case deep_recovery complete
run_runner --deep --recover "$revision_worktree" "$dossier"
assert_transport_case 0 COMPLETE completed
assert_eq "$(field "$output" IMPROVE_MODE)" recovery "deep recovery mode"
assert_eq "$(field "$output" IMPROVE_PROFILE)" improve-executor-deep "deep recovery profile"
assert_eq "$(invocation_profile)" improve-executor-deep "deep recovery invoked profile"
assert_eq "$(field "$output" IMPROVE_EXEC_ACTIVE_TIMEOUT_SECONDS)" 6 "deep recovery timeout"
assert_eq "$(field "$output" IMPROVE_EXEC_ACTIVE_TOKEN_LIMIT)" 160000 "deep recovery token limit"
assert_eq "$(git -C "$revision_worktree" status --short)" "$revision_status_before" "deep recovery diff preservation"
assert_eq "$(wc -l <"$FAKE_COUNT_FILE")" 1 "deep recovery invocation count"

recovery_transport_case() {
  name="$1"
  fake_mode="$2"
  expected_status="$3"
  expected_result="$4"
  expected_reason="$5"
  start_case "$name" "$fake_mode"
  run_runner --recover "$revision_worktree" "$dossier"
  assert_transport_case "$expected_status" "$expected_result" "$expected_reason"
  assert_eq "$(field "$output" IMPROVE_MODE)" recovery "$name mode"
  assert_eq "$(wc -l <"$FAKE_COUNT_FILE")" 1 "$name invocation count"
  assert_eq "$(git -C "$revision_worktree" status --short)" "$revision_status_before" "$name diff preservation"
}

recovery_transport_case recovery_stopped stopped 0 STOPPED completed
recovery_transport_case recovery_nonzero nonzero 1 INCONCLUSIVE codex_exit_17
recovery_transport_case recovery_budget rollout_budget_exhausted 1 INCONCLUSIVE rollout_budget_exhausted
recovery_transport_case recovery_timeout timeout 1 INCONCLUSIVE absolute_timeout
recovery_transport_case recovery_malformed malformed_jsonl 1 INCONCLUSIVE invalid_event_log

start_case recovery_signal signal
copy_runner
output="$case_dir/output"
errors="$case_dir/errors"
(
  cd "$repo"
  exec bash "$runner" --recover "$revision_worktree" "$dossier"
) >"$output" 2>"$errors" &
wrapper_pid="$!"
for _ in $(seq 1 50); do
  [ -s "$FAKE_CHILD_PID_FILE" ] && break
  sleep 0.1
done
[ -s "$FAKE_CHILD_PID_FILE" ] || fail "recovery signal case did not start descendant"
kill -TERM "$wrapper_pid"
set +e
wait "$wrapper_pid"
status="$?"
set -e
assert_transport_case 1 INCONCLUSIVE wrapper_signal_TERM
assert_eq "$(field "$output" IMPROVE_MODE)" recovery "recovery signal mode"
assert_eq "$(wc -l <"$FAKE_COUNT_FILE")" 1 "recovery signal invocation count"
assert_eq "$(git -C "$revision_worktree" status --short)" "$revision_status_before" "recovery signal diff preservation"
recovery_signal_child_pid="$(<"$FAKE_CHILD_PID_FILE")"
for _ in $(seq 1 20); do
  kill -0 "$recovery_signal_child_pid" 2>/dev/null || break
  sleep 0.1
done
if kill -0 "$recovery_signal_child_pid" 2>/dev/null; then
  kill -KILL "$recovery_signal_child_pid" 2>/dev/null || true
  fail "recovery signal-resistant descendant survived cancellation"
fi

reject_case() {
  name="$1"
  shift
  start_case "$name"
  run_runner "$@"
  assert_eq "$status" 2 "$name status"
  assert_not_invoked "$name"
}

reject_case main_worktree --revise "$repo" "$dossier"
mkdir -p "$revision_worktree/subdir"
reject_case subdirectory --revise "$revision_worktree/subdir" "$dossier"
reject_case missing_dossier --revise "$revision_worktree" "$test_root/missing.md"
reject_case repeated_recovery --recover --recover "$revision_worktree" "$dossier"
reject_case revision_then_recovery --revise --recover "$revision_worktree" "$dossier"
reject_case recovery_then_revision --recover --revise "$revision_worktree" "$dossier"
reject_case lane_after_recovery --recover --spark "$revision_worktree" "$dossier"
reject_case recovery_main_worktree --recover "$repo" "$dossier"
reject_case recovery_subdirectory --recover "$revision_worktree/subdir" "$dossier"
reject_case recovery_missing_dossier --recover "$revision_worktree" "$test_root/missing.md"

other_worktree="$test_root/other worktree"
git -C "$repo" worktree add -q -b feature/not-improve "$other_worktree" HEAD
reject_case non_improve_branch --revise "$other_worktree" "$dossier"
reject_case recovery_non_improve_branch --recover "$other_worktree" "$dossier"

copied_worktree="$test_root/copied worktree"
cp -a "$revision_worktree" "$copied_worktree"
reject_case unregistered_worktree --revise "$copied_worktree" "$dossier"
reject_case recovery_unregistered_worktree --recover "$copied_worktree" "$dossier"

echo "exec-runner: all tests passed"
