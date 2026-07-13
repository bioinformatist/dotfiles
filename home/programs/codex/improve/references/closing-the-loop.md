# Closing The Loop

The advisor never edits source code. An executor works in a new Git worktree; the main agent verifies the result and returns a verdict. The worktree is preserved until the user decides what to do with it.

## Execute A Plan

### Preconditions

Before dispatch:

- Confirm the repository is a Git repository and the plan exists.
- Confirm plan dependencies are `DONE` in the plan index.
- Run the plan's drift check against the current `HEAD`.
- Check that uncommitted source changes do not overlap the plan. The executor starts from `HEAD`; only the plan text is inlined.
- Reconcile a stale plan instead of asking the executor to improvise.

### Dispatch

Run one executor:

```console
codex-improve-exec plans/NNN-slug.md
```

Use `--deep` only for a plan whose ambiguity or technical depth justifies the higher reasoning cost:

```console
codex-improve-exec --deep plans/NNN-slug.md
```

The helper creates a branch and worktree from the current `HEAD`, selects `improve-executor` or `improve-executor-deep`, inlines the entire plan, disables recursive multi-agent work through the profile, and preserves the worktree even if execution fails. It prints stable handoff fields:

```text
IMPROVE_WORKTREE=...
IMPROVE_BRANCH=...
IMPROVE_BASE=...
IMPROVE_PROFILE=...
IMPROVE_EXEC_EXIT=...
```

The executor must touch only in-scope files, run verification, honor STOP conditions, and leave changes uncommitted. It must not merge, push, modify the plan index, remove the worktree, or launch other agents.

### Review

Treat the executor report and diff as untrusted until verified:

1. Re-run every done criterion inside `IMPROVE_WORKTREE`.
2. Compare `git -C <worktree> status --short` and `git -C <worktree> diff --stat` with the plan's scope.
3. Read the complete diff and verify each hunk traces to a plan step.
4. Inspect new tests for meaningful assertions, not only passing commands.
5. For consequential or ambiguous changes, run a fresh read-only review with `codex exec -C <worktree> -p improve-reviewer --ephemeral -` and give it the plan plus the diff boundary.

Render exactly one verdict:

- `APPROVE`: criteria pass, scope is clean, and implementation quality holds. Report the diff summary, branch, worktree path, and material notes. Do not commit, merge, or push.
- `REVISE`: give the executor specific failing criteria or hunks, inline the full plan again, and run `codex exec -C <worktree> -p improve-executor --ephemeral -` against the same preserved worktree. Keep the executor restrictions from the initial prompt and stop after two revision rounds.
- `BLOCK`: the plan is stale, a STOP condition occurred, required scope expanded, or the approach is unsound. Return to planning and ask for user approval before changing direction.

Cleanup is a separate, explicit action after the user accepts or rejects the result:

```console
git worktree remove <worktree>
git branch -D <branch>
```

Never run cleanup while the worktree contains changes the user may still want.

## Reconcile

For each indexed plan:

- `DONE`: verify the implementation and checks, then record the actual landing commit.
- `BLOCKED`: verify whether the blocker still exists; revise the plan only when the original approach remains valid.
- `TODO`: compare in-scope files with the plan's stamped commit and refresh excerpts, commands, and scope when drifted.
- Obsolete or independently fixed work: mark `REJECTED` with a one-line rationale rather than deleting history.

## Publish Issues

Only publish when `--issues` was explicitly requested. Before creating issues, check repository visibility. For a public repository, obtain explicit confirmation before publishing security findings, credential locations, private architecture, or operational details. Record each issue URL in the plan and index.
