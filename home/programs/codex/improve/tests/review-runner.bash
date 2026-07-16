#!/usr/bin/env bash

set -euo pipefail

[ "$#" -eq 1 ] || { echo "usage: review-runner.bash REVIEW_RUNNER" >&2; exit 2; }
runner_source="$(realpath -- "$1")"
[ -f "$runner_source" ] || { echo "review runner does not exist: $runner_source" >&2; exit 2; }

if [ -z "${CODEX_IMPROVE_REVIEW_SCHEMA:-}" ]; then
  CODEX_IMPROVE_REVIEW_SCHEMA="$(dirname -- "$runner_source")/references/review-verdict.schema.json"
  export CODEX_IMPROVE_REVIEW_SCHEMA
fi

test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
fake_bin="$test_root/bin"
mkdir -p "$fake_bin"

cat >"$fake_bin/codex" <<'FAKE_CODEX'
#!/usr/bin/env bash
set -u

: "${FAKE_CODEX_MODE:?}" "${FAKE_COUNT_FILE:?}" "${FAKE_INVOCATION_LOG:?}" "${FAKE_PROMPT_LOG:?}"
printf '%s\n' 1 >"$FAKE_COUNT_FILE"
printf '%s\n' "$@" >"$FAKE_INVOCATION_LOG"

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
printf '%s\n' TOP_SECRET_STDERR >&2

emit_usage() {
  printf '%s\n' '{"type":"item.completed","item":{"type":"command_execution"}}'
  printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":10,"cached_input_tokens":2,"output_tokens":3}}'
}

case "$FAKE_CODEX_MODE" in
  approve)
    emit_usage
    printf '%s\n' '{"verdict":"APPROVE","summary":"TOP_SECRET_FINDING","findings":[],"coverage":[{"check":"complete diff","status":"PASS","evidence":"bounded evidence"}],"review_blockers":[],"deferred_acceptance":[]}' >"$final_output"
    ;;
  approve_deferred)
    emit_usage
    printf '%s\n' '{"verdict":"APPROVE","summary":"implementation approved","findings":[],"coverage":[{"check":"complete diff","status":"PASS","evidence":"bounded evidence"}],"review_blockers":[],"deferred_acceptance":[{"check":"physical display acceptance","owner":"user","reason":"display is not visible to the reviewer","evidence_required":"user confirms the named checkpoint renders correctly"}]}' >"$final_output"
    ;;
  approve_with_blocker)
    emit_usage
    printf '%s\n' '{"verdict":"APPROVE","summary":"contradictory blocker","findings":[],"coverage":[{"check":"complete diff","status":"PASS","evidence":"bounded evidence"}],"review_blockers":[{"item":"missing implementation evidence","impact":"implementation cannot be reviewed"}],"deferred_acceptance":[]}' >"$final_output"
    ;;
  revise)
    emit_usage
    printf '%s\n' '{"verdict":"REVISE","summary":"revise","findings":[{"check":"complete diff","severity":"medium","location":"runner","claim":"revision required","evidence":"bounded evidence","action":"revise"}],"coverage":[{"check":"complete diff","status":"FAIL","evidence":"bounded evidence"}],"review_blockers":[],"deferred_acceptance":[]}' >"$final_output"
    ;;
  block)
    emit_usage
    printf '%s\n' '{"verdict":"BLOCK","summary":"blocked","findings":[],"coverage":[{"check":"complete diff","status":"BLOCKED","evidence":"decision required"}],"review_blockers":[{"item":"user decision","impact":"cannot proceed"}],"deferred_acceptance":[]}' >"$final_output"
    ;;
  whitespace_verdict)
    emit_usage
    printf '%s\n' '{"verdict":"APPROVE","summary":" ","findings":[],"coverage":[{"check":" ","status":"PASS","evidence":" "}],"review_blockers":[],"deferred_acceptance":[]}' >"$final_output"
    ;;
  contradictory_verdict)
    emit_usage
    printf '%s\n' '{"verdict":"APPROVE","summary":"contradictory","findings":[{"check":"complete diff","severity":"medium","location":"runner","claim":"unexpected finding","evidence":"bounded evidence","action":"revise"}],"coverage":[{"check":"complete diff","status":"PASS","evidence":"bounded evidence"}],"review_blockers":[],"deferred_acceptance":[]}' >"$final_output"
    ;;
  multiple_verdicts)
    emit_usage
    printf '%s\n' '{"verdict":"APPROVE","summary":"first","findings":[],"coverage":[{"check":"complete diff","status":"PASS","evidence":"bounded evidence"}],"review_blockers":[],"deferred_acceptance":[]}' >"$final_output"
    printf '%s\n' '{"verdict":"APPROVE","summary":"second","findings":[],"coverage":[{"check":"complete diff","status":"PASS","evidence":"bounded evidence"}],"review_blockers":[],"deferred_acceptance":[]}' >>"$final_output"
    ;;
  invalid_jsonl)
    printf '%s\n' 'not-json'
    printf '%s\n' '{"verdict":"APPROVE","summary":"valid final","findings":[],"coverage":[{"check":"complete diff","status":"PASS","evidence":"bounded evidence"}],"review_blockers":[],"deferred_acceptance":[]}' >"$final_output"
    ;;
  concatenated_jsonl)
    printf '%s\n' '{}{}'
    printf '%s\n' '{"verdict":"APPROVE","summary":"valid final","findings":[],"coverage":[{"check":"complete diff","status":"PASS","evidence":"bounded evidence"}],"review_blockers":[],"deferred_acceptance":[]}' >"$final_output"
    ;;
  nonzero)
    emit_usage
    exit 17
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
  quiet)
    printf '%s\n' '{"type":"turn.started"}'
    sleep 2
    emit_usage
    printf '%s\n' '{"verdict":"APPROVE","summary":"quiet completed","findings":[],"coverage":[{"check":"complete diff","status":"PASS","evidence":"bounded evidence"}],"review_blockers":[],"deferred_acceptance":[]}' >"$final_output"
    ;;
esac
FAKE_CODEX
chmod +x "$fake_bin/codex"

repo="$test_root/repo"
mkdir -p "$repo"
git -C "$repo" init -q
dossier="$test_root/dossier.md"
printf '%s\n' 'TOP_SECRET_DOSSIER /private/repository/path' >"$dossier"

export PATH="$fake_bin:$PATH"

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "expected '$2', got '$1' ($3)"; }
field() { sed -n "s/^$2=//p" "$1" | tail -n 1; }

start_case() {
  case_name="$1"
  case_dir="$test_root/cases/$case_name"
  mkdir -p "$case_dir/runtime" "$case_dir/state"
  export XDG_RUNTIME_DIR="$case_dir/runtime"
  export XDG_STATE_HOME="$case_dir/state"
  export FAKE_COUNT_FILE="$case_dir/count"
  export FAKE_INVOCATION_LOG="$case_dir/invocation"
  export FAKE_PROMPT_LOG="$case_dir/prompt"
  export FAKE_CHILD_PID_FILE="$case_dir/child-pid"
  : >"$FAKE_COUNT_FILE"
}

run_case() {
  case_name="$1"
  role="$2"
  mode="$3"
  expected_status="$4"
  expected_result="$5"
  expected_reason="$6"
  absolute_seconds="${7:-5}"
  quiet_seconds="${8:-3}"

  start_case "$case_name"
  export FAKE_CODEX_MODE="$mode"
  runner="$case_dir/review-runner"
  sed \
    -e "s/^absolute_seconds=480$/absolute_seconds=$absolute_seconds/" \
    -e "s/^quiet_seconds=180$/quiet_seconds=$quiet_seconds/" \
    -e 's/^kill_after_seconds=5$/kill_after_seconds=1/' \
    -e 's/^poll_seconds=1$/poll_seconds=0.1/' \
    "$runner_source" >"$runner"
  set +e
  bash "$runner" "$role" "$repo" "$dossier" >"$case_dir/stdout" 2>"$case_dir/stderr"
  status="$?"
  set -e

  assert_eq "$status" "$expected_status" "$case_name status"
  assert_eq "$(field "$case_dir/stdout" IMPROVE_REVIEW_RESULT)" "$expected_result" "$case_name result"
  assert_eq "$(field "$case_dir/stdout" IMPROVE_REVIEW_EXIT_REASON)" "$expected_reason" "$case_name reason"
  event_log="$(field "$case_dir/stdout" IMPROVE_REVIEW_EVENT_LOG)"
  case "$event_log" in
    "$case_dir/state/codex-improve/reviews/"*) ;;
    *) fail "$case_name review artifacts are not in persistent state: $event_log" ;;
  esac
  metric="$case_dir/state/codex-improve/review-metrics.jsonl"
  [ -s "$metric" ] || fail "$case_name metric missing"
  if grep -F -e TOP_SECRET -e /private/repository/path "$metric" >/dev/null; then
    fail "$case_name metric leaked review content"
  fi
}

start_case invalid_input
export FAKE_CODEX_MODE=approve
set +e
bash "$runner_source" unsupported "$repo" "$dossier" >/dev/null 2>&1
invalid_status="$?"
set -e
assert_eq "$invalid_status" 2 "invalid role"
assert_eq "$(wc -c <"$FAKE_COUNT_FILE")" 0 "invalid role invocation count"

run_case approve correctness approve 0 APPROVE completed
approve_dir="$test_root/cases/approve"
grep -Fx -- improve-reviewer "$approve_dir/invocation" >/dev/null || fail "correctness profile missing"
grep -Fx -- --strict-config "$approve_dir/invocation" >/dev/null || fail "strict config missing"
grep -Fx -- --output-schema "$approve_dir/invocation" >/dev/null || fail "output schema missing"
assert_eq "$(grep -o TOP_SECRET_DOSSIER "$approve_dir/prompt" | wc -l)" 1 "dossier pass count"
jq -e '
  .token_usage == {"input_tokens":10,"cached_input_tokens":2,"output_tokens":3}
  and .tool_event_count == 1 and .verdict == "APPROVE"
' "$approve_dir/state/codex-improve/review-metrics.jsonl" >/dev/null || fail "approve metric"

run_case approve_deferred correctness approve_deferred 0 APPROVE completed
deferred_output="$(field "$test_root/cases/approve_deferred/stdout" IMPROVE_REVIEW_FINAL_OUTPUT)"
jq -e '.deferred_acceptance | length == 1' "$deferred_output" >/dev/null ||
  fail "deferred acceptance was not preserved"

run_case revise elegance revise 0 REVISE completed
grep -Fx -- improve-elegance-reviewer "$test_root/cases/revise/invocation" >/dev/null || fail "elegance profile missing"
grep -F -- "main agent's single Ponytail pass" "$test_root/cases/revise/prompt" >/dev/null ||
  fail "Ponytail handoff missing"
ponytail_invocation="\$ponytail-review"
if grep -F -- "$ponytail_invocation" "$test_root/cases/revise/prompt" >/dev/null; then
  fail "elegance reviewer still invokes Ponytail"
fi
run_case block correctness block 0 BLOCK completed
run_case approve_with_blocker correctness approve_with_blocker 1 INCONCLUSIVE invalid_final_output
run_case whitespace correctness whitespace_verdict 1 INCONCLUSIVE invalid_final_output
run_case contradictory correctness contradictory_verdict 1 INCONCLUSIVE invalid_final_output
run_case multiple correctness multiple_verdicts 1 INCONCLUSIVE invalid_final_output
run_case invalid_jsonl correctness invalid_jsonl 1 INCONCLUSIVE invalid_event_log
run_case concatenated_jsonl correctness concatenated_jsonl 1 INCONCLUSIVE invalid_event_log
run_case nonzero correctness nonzero 1 INCONCLUSIVE codex_exit_17
run_case timeout correctness timeout 1 INCONCLUSIVE absolute_timeout 1 5

run_case descendant correctness descendant 1 INCONCLUSIVE absolute_timeout 1 5
descendant_pid="$(<"$test_root/cases/descendant/child-pid")"
for _ in $(seq 1 20); do
  kill -0 "$descendant_pid" 2>/dev/null || break
  sleep 0.1
done
if kill -0 "$descendant_pid" 2>/dev/null; then
  kill -KILL "$descendant_pid" 2>/dev/null || true
  fail "timeout descendant survived"
fi

run_case quiet elegance quiet 0 APPROVE completed 5 1
quiet_metric="$test_root/cases/quiet/state/codex-improve/review-metrics.jsonl"
jq -e '.quiet_interval_observed == true and .max_event_gap_seconds >= 1' "$quiet_metric" >/dev/null ||
  fail "quiet interval metric"

echo "review-runner: all tests passed"
