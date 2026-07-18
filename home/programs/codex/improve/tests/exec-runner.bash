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
set -eu
: "${FAKE_COUNT_FILE:?}" "${FAKE_INVOCATION_LOG:?}" "${FAKE_PROMPT_LOG:?}"
printf '%s\n' invoked >>"$FAKE_COUNT_FILE"
printf '%s\n' "$@" >"$FAKE_INVOCATION_LOG"
cat >"$FAKE_PROMPT_LOG"
exit "${FAKE_CODEX_EXIT:-0}"
FAKE_CODEX
chmod +x "$fake_bin/codex"
export PATH="$fake_bin:$PATH"

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_eq() { [ "$1" = "$2" ] || fail "expected '$2', got '$1' ($3)"; }
field() { sed -n "s/^$2=//p" "$1" | tail -n 1; }

repo="$test_root/repo with spaces"
git -c init.defaultBranch=main init -q "$repo"
git -C "$repo" config user.email test@example.invalid
git -C "$repo" config user.name "Improve Test"
mkdir -p "$repo/plans"
printf '%s\n' "PLAN_UNIQUE_TOKEN" >"$repo/plans/001 plan.md"
printf '%s\n' "committed" >"$repo/tracked.txt"
git -C "$repo" add .
git -C "$repo" commit -qm "test: initial"

case_root="$test_root/cases"
mkdir -p "$case_root"

start_case() {
  case_name="$1"
  case_dir="$case_root/$case_name"
  mkdir -p "$case_dir"
  export FAKE_COUNT_FILE="$case_dir/count"
  export FAKE_INVOCATION_LOG="$case_dir/invocation"
  export FAKE_PROMPT_LOG="$case_dir/prompt"
  : >"$FAKE_COUNT_FILE"
  : >"$FAKE_INVOCATION_LOG"
  : >"$FAKE_PROMPT_LOG"
  unset FAKE_CODEX_EXIT
}

run_runner() {
  output="$case_dir/output"
  errors="$case_dir/errors"
  set +e
  (
    cd "$repo"
    bash "$runner_source" "$@"
  ) >"$output" 2>"$errors"
  status="$?"
  set -e
}

assert_not_invoked() {
  [ ! -s "$FAKE_COUNT_FILE" ] || fail "$1 invoked Codex"
}

start_case help
run_runner --help
assert_eq "$status" 0 "help status"
grep -F -- "--deep --revise WORKTREE DOSSIER" "$output" >/dev/null ||
  fail "help omits deep revision mode"
assert_not_invoked help

start_case invalid
run_runner --revise
assert_eq "$status" 2 "invalid argument status"
assert_not_invoked invalid

printf '%s\n' "dirty caller" >"$repo/dirty.txt"
start_case initial
export XDG_STATE_HOME="$case_dir/state"
run_runner "plans/001 plan.md"
assert_eq "$status" 0 "initial status"
assert_eq "$(field "$output" IMPROVE_MODE)" initial "initial mode"
assert_eq "$(field "$output" IMPROVE_PROFILE)" improve-executor "initial profile"
initial_worktree="$(field "$output" IMPROVE_WORKTREE)"
[ -d "$initial_worktree" ] || fail "initial worktree was not preserved"
[ ! -e "$initial_worktree/dirty.txt" ] || fail "dirty caller state entered initial worktree"
assert_eq "$(grep -o PLAN_UNIQUE_TOKEN "$FAKE_PROMPT_LOG" | wc -l)" 1 "plan insertion count"
grep -Fx -- --strict-config "$FAKE_INVOCATION_LOG" >/dev/null || fail "strict config missing"
grep -Fx -- --ephemeral "$FAKE_INVOCATION_LOG" >/dev/null || fail "ephemeral mode missing"

start_case deep_failure
export XDG_STATE_HOME="$case_dir/state"
export FAKE_CODEX_EXIT=17
run_runner --deep "plans/001 plan.md"
assert_eq "$status" 17 "deep failure status"
assert_eq "$(field "$output" IMPROVE_PROFILE)" improve-executor-deep "deep profile"
failed_worktree="$(field "$output" IMPROVE_WORKTREE)"
[ -d "$failed_worktree" ] || fail "failed initial worktree was not preserved"

start_case home_fallback
unset XDG_STATE_HOME
export HOME="$case_dir/home"
mkdir -p "$HOME"
run_runner "plans/001 plan.md"
fallback_worktree="$(field "$output" IMPROVE_WORKTREE)"
case "$fallback_worktree" in
  "$HOME/.local/state/codex-improve/worktrees/"*) ;;
  *) fail "HOME state fallback was not used: $fallback_worktree" ;;
esac

start_case second_user
export HOME="$case_dir/home"
export XDG_STATE_HOME="$case_dir/xdg state"
mkdir -p "$HOME"
run_runner "plans/001 plan.md"
second_worktree="$(field "$output" IMPROVE_WORKTREE)"
case "$second_worktree" in
  "$XDG_STATE_HOME/codex-improve/worktrees/"*) ;;
  *) fail "second user XDG state was not used: $second_worktree" ;;
esac
case "$second_worktree" in
  "$fallback_worktree"|"$test_root/cases/home_fallback/"*) fail "users shared state" ;;
esac
[ ! -e "$case_root/home_fallback/home/.local/state/codex-improve/worktrees/$(basename "$second_worktree")" ] ||
  fail "second user wrote into first user state"

revision_worktree="$test_root/revision worktree"
git -C "$repo" worktree add -q -b codex/improve-revision-test "$revision_worktree" HEAD
printf '%s\n' "preserve this diff" >>"$revision_worktree/tracked.txt"
dossier="$test_root/revision dossier.md"
printf '%s\n' "DOSSIER_UNIQUE_TOKEN" >"$dossier"
revision_status_before="$(git -C "$revision_worktree" status --short)"
worktrees_before="$(git -C "$repo" worktree list --porcelain)"

start_case revision
export HOME="$case_dir/home"
export XDG_STATE_HOME="$case_dir/state"
run_runner --revise "$revision_worktree" "$dossier"
assert_eq "$status" 0 "revision status"
assert_eq "$(field "$output" IMPROVE_MODE)" revision "revision mode"
assert_eq "$(field "$output" IMPROVE_BRANCH)" codex/improve-revision-test "revision branch"
assert_eq "$(field "$output" IMPROVE_PROFILE)" improve-executor "revision profile"
assert_eq "$(git -C "$revision_worktree" status --short)" "$revision_status_before" "revision diff preservation"
assert_eq "$(git -C "$repo" worktree list --porcelain)" "$worktrees_before" "revision worktree reuse"
assert_eq "$(grep -o DOSSIER_UNIQUE_TOKEN "$FAKE_PROMPT_LOG" | wc -l)" 1 "dossier insertion count"
grep -F -- "Do not load or reread the" "$FAKE_PROMPT_LOG" >/dev/null ||
  fail "revision recon prohibition missing"

start_case deep_revision
run_runner --deep --revise "$revision_worktree" "$dossier"
assert_eq "$status" 0 "deep revision status"
assert_eq "$(field "$output" IMPROVE_PROFILE)" improve-executor-deep "deep revision profile"

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

other_worktree="$test_root/other worktree"
git -C "$repo" worktree add -q -b feature/not-improve "$other_worktree" HEAD
reject_case non_improve_branch --revise "$other_worktree" "$dossier"

copied_worktree="$test_root/copied worktree"
cp -a "$revision_worktree" "$copied_worktree"
reject_case unregistered_worktree --revise "$copied_worktree" "$dossier"

echo "exec-runner: all tests passed"
