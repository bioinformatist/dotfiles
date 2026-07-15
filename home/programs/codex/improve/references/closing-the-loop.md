# Closing The Loop

The advisor never edits source code. An executor works in a new Git worktree; the main agent verifies the result and returns a verdict. The worktree is preserved until the user decides what to do with it.

## Execute A Plan

### Preconditions

Before dispatch:

- Confirm the repository is a Git repository and the plan exists.
- Confirm every plan dependency is `DONE`. Allow only the planning contract's
  code-only exception: the dependent plan must inline a dependency contract
  that names an actual landing commit and an observable code prerequisite.
  Verify that the commit is an ancestor of the execution baseline and that the
  prerequisite is observable before dispatch; implementation state or an
  unnamed expectation is not sufficient.
- Run the plan's drift check against the current `HEAD`.
- Check that uncommitted source changes do not overlap the plan. The executor starts from `HEAD`; only the plan text is inlined.
- Verify that the Engineering-contract impact matrix covers every planned change
  trigger and its generated or packaged artifacts. Files outside modification
  scope remain in scope for read-only impact analysis.
- If a matrix row requires an unapproved CI, policy, classifier, release,
  compatibility, or other contract edit, return `BLOCKED` before dispatch.
- Reconcile a stale plan instead of asking the executor to improvise.

### Dispatch

Run one executor:

```console
codex-improve-exec <plan-artifact-path>
```

Use `--deep` only for a plan whose ambiguity or technical depth justifies the higher reasoning cost:

```console
codex-improve-exec --deep <plan-artifact-path>
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
5. Reconcile the actual diff, generated artifacts, dependency graph, public
   interfaces, and runtime effects with the Engineering-contract impact matrix.
   An unexplained trigger or out-of-scope impact returns to planning; a required
   unapproved contract edit `BLOCK`s. Omission is not evidence that the impact
   is absent.
6. Run applicable repository checks in evidence-preserving order. Capture a
   clean base/head delta before builds, caches, installations, deployments, or
   other local state can hide it, or use an isolated equivalent.
7. Perform the main-agent acceptance pass. Check behavior, tests, repository
   rules, reuse, justified abstraction, module boundaries, locality, speculative
   flexibility, compatibility layers, and removable code.
8. Apply the installed `$ponytail-review` skill to the current diff. Treat its
   suggestions as hypotheses; reject any that weaken settled semantics,
   correctness, repository rules, or necessary tests. Its line-count score is
   not an acceptance criterion.
9. Decide whether external-practice evidence or an independent review is
   required under the triggers below.

#### External-practice evidence

Use external-practice evidence when a structural decision materially depends on
an external ecosystem convention. New dependencies and compatibility layers
normally qualify. Public APIs, protocols, formats, OS integration, modules, and
abstractions qualify only when external guidance could distinguish plausible
designs. Purely internal organization with a settled repository precedent does
not qualify.

The main agent first verifies the normative or upstream position with the
applicable documentation skill, current official documentation, standards,
ADRs, RFCs, migration guides, release notes, upstream examples, or verified
maintainer explanations. Record exact versions, links, the upstream rationale,
and any unresolved applicability question. Do not delegate authoritative-source
selection or maintainer-identity verification to the practice scout.

Launch one read-only practice scout only when first-hand community evidence
could still materially qualify the upstream position or distinguish the
candidate approaches. Give `improve-scout` one exact decision question,
relevant versions, repository constraints, candidate approaches, the verified
upstream position and links, and the evidence that would support, qualify, or
contradict it. It may inspect the repository and public sources but must not
edit, launch agents, re-research a supplied authoritative conclusion without a
specific conflict, or issue a verdict:

```console
timeout 8m codex exec --strict-config --ephemeral --json \
  -C "$IMPROVE_WORKTREE" -p improve-scout \
  --output-last-message <practice-memo> - \
  > <practice-events> 2> <practice-diagnostics>
```

The scout treats generic articles as leads only and searches first-hand
maintainer discussions, issue reports, postmortems, benchmarks with disclosed
harnesses, and production reports. It fills a fixed evidence matrix:

- community evidence supporting the supplied upstream position;
- counterexamples or reported failure modes;
- material version, platform, scale, security, or compatibility differences;
- applicability to the repository constraints; and
- missing, disputed, or unavailable evidence.

Each cell ends as `SUPPORTED`, `CONTRADICTED`, `NOT_FOUND`, or
`NOT_APPLICABLE`. Search only unresolved cells, never repeat an equivalent query
without new evidence, and treat `NOT_FOUND` as a valid result after a targeted
pass over the appropriate first-hand sources. Emit one compact progress message,
preserved in the JSONL event log, after ingesting the supplied upstream position
and naming unresolved cells, and another after the community pass before final
synthesis. When every cell has a state, render the memo immediately. Stop with
explicit uncertainty when sources remain incompatible; never manufacture a
universal best practice.

The local Markdown memo contains the decision question, versions and
constraints, supplied upstream position and links, the completed evidence
matrix, repository applicability, uncertainties, candidate implication, and
source links. The main agent verifies each material community claim before
using it, gives the already verified upstream guidance the greatest weight, and
retains the final judgment. Upstream guidance does not override a version,
platform, security, or repository constraint without analysis.

Run at most one scout for a materially unchanged decision, never retry
automatically, and do not apply the reviewer rollout-token budget to this role.
The eight-minute timeout is a separate, provisional practice-scout fuse based on
an observed non-convergent run; it is not an established best practice or a
reviewer threshold. Preserve the JSONL checkpoints and diagnostics. A timeout,
missing memo, or otherwise incomplete run is `INCONCLUSIVE` and requires
explicit approval before another attempt or a plan change. Any application that
would change settled scope or an Engineering contract must `BLOCK` for
approval.

#### Independent review triggers

Run the correctness reviewer when behavior is consequential or ambiguous. Run
the elegance reviewer for a new abstraction, module, public interface,
dependency, compatibility layer, cross-owner boundary, complex lifecycle,
concurrency or security logic, a material disagreement about structure, or an
explicit repository or user requirement. A narrow revision reruns a reviewer
only when it invalidates that reviewer's evidence.

#### Bounded evidence dossier

For each triggered independent review, the main agent prepares one complete
dossier for a reviewer with no conversation context. It is not a transcript and
does not ask the reviewer to rediscover the repository. Include:

- the exact current plan artifact, its immutable baseline commit, settled
  semantic anchors, and Engineering contract;
- the Engineering-contract impact matrix reconciled against the actual diff,
  including generated artifacts and every out-of-scope impact;
- the baseline and complete diff boundary plus a changed-path manifest;
- executor and main-agent verification results, including generated-artifact
  evidence when applicable;
- the verified practice memo when external evidence applies;
- the exact checks and questions assigned to this reviewer; and
- the applicable host-injected repository instructions, clearly distinguished
  from ordinary repository evidence.

Do not include secret values. The dossier must remain sufficient for a fresh
reviewer after interruption or compaction. Missing material evidence produces a
`BLOCK` verdict; it never authorizes a broad repository audit.

The reviewer builds a coverage matrix for every requested check before new
recon. It reads each changed artifact completely at most once. Any reread names
one unresolved question first and targets only the range needed to answer it.
When rollout-budget reminders report 40,000 weighted tokens remaining, broad
recon stops and the coverage matrix is completed. At 20,000, only one named
evidence gap may be pursued at a time. At 10,000, tool use stops and the verdict
is rendered.

#### Review runner

Invoke only the applicable roles through the same bounded transport:

```console
codex-improve-review elegance "$IMPROVE_WORKTREE" <dossier-file>
codex-improve-review correctness "$IMPROVE_WORKTREE" <dossier-file>
```

The helper selects `improve-elegance-reviewer` or `improve-reviewer`, passes the
dossier once, and runs `codex exec --strict-config --ephemeral --json
--output-schema`. It preserves the JSONL event log, structured final output, and
diagnostic log in a unique local runtime directory. An eight-minute absolute
fuse is the last-resort runtime boundary. Three minutes without a new JSONL
event is recorded as a quiet-interval observation but never treated as proof
of a stalled model or used to interrupt the run. Bounded evidence and
model-visible rollout budgets remain the primary convergence controls.

The 80,000 weighted-token limit, 40,000/20,000/10,000 convergence gates,
1.0 sampling and prefill weights, eight-minute fuse, three-minute observation
marker, and two-revision boundary are provisional reviewer-only calibrations.
Observe elapsed time, token mix, tool events, maximum JSONL event gap, verdict,
and failure reason in subsequent reviews. Do not tune them automatically. A
change requires evidence from observed runs and explicit user approval.

The helper reports the role, profile, result, artifact paths, elapsed time,
maximum event gap, quiet-interval observation, and exit reason. Its model output
must satisfy [`review-verdict.schema.json`](review-verdict.schema.json) and keep
the verdict coherent with its findings, coverage, and unresolved items. A model
verdict is possible only when Codex exits successfully with valid JSONL and a
coherent structured result; otherwise the result is `INCONCLUSIVE`. Invalid
caller input or unavailable local storage may terminate before a complete
handoff. Metrics are content-free and best-effort. The helper never retries.

The correctness reviewer checks behavior, safety, regressions, meaningful
tests, and plan and Engineering-contract compliance. The elegance reviewer
checks reuse, justified abstraction, module boundaries, locality, speculative
flexibility, unnecessary compatibility layers, and removable code. It applies
the installed `$ponytail-review` skill once to the current diff as an internal
subreview. Ponytail suggestions remain hypotheses: reject any that weaken
settled semantics, correctness, repository rules, or necessary tests, and never
use its line-count score as an acceptance criterion. Elegance review does not
expand product scope or reopen settled user decisions without new contradictory
evidence.

The main agent validates every reviewer finding against the dossier and diff,
then follows the single acceptance policy below. It never overrides a triggered
review's `INCONCLUSIVE` status or tunes a provisional boundary on its own.

After an approved main-agent acceptance, the advisor records the lifecycle
state in the plan and any index:

- `ACCEPTANCE PENDING` when a named runtime, physical, human, or external check
  remains. This takes precedence over `IMPLEMENTED`.
- `IMPLEMENTED` when scoped implementation and executor checks are complete,
  no named acceptance check remains, and integration is not yet established.
- `DONE` only when the atomic change is integrated and every required
  acceptance check has passed.

Implementation approval establishes neither integration nor acceptance.

Render exactly one main-agent acceptance outcome. A triggered reviewer returns
a model verdict as evidence; `INCONCLUSIVE` remains a separate helper status:

- `APPROVE`: criteria pass, scope is clean, and implementation quality holds. Report the diff summary, branch, worktree path, and material notes. Do not commit, merge, or push.
- `REVISE`: give the executor specific failing criteria or hunks, inline the full plan again, and run `codex exec -C "$IMPROVE_WORKTREE" -p "$IMPROVE_PROFILE" --ephemeral -` against the same preserved worktree. Keep the executor restrictions from the initial prompt, rerun affected checks and only reviews whose evidence changed, and stop after two revision rounds.
- `BLOCK`: the plan is stale, a STOP condition occurred, required or not-yet-approved scope expanded, including an Engineering-contract change, or the approach is unsound. Return to planning and ask for user approval before changing direction.
- `INCONCLUSIVE`: report the helper's exact exit reason and preserved diagnostic
  paths, halt integration, and ask for explicit approval before another review
  attempt or a plan change. Never convert it to `APPROVE`.

Cleanup is a separate, explicit action after the user accepts or rejects the result:

```console
git worktree remove <worktree>
git branch -D <branch>
```

Never run cleanup while the worktree contains changes the user may still want.

## Reconcile

For each indexed plan:

- `TODO`: compare modification and evidence/drift paths with the stamped commit;
  refresh evidence, commands, and scope when drifted.
- `IN PROGRESS`: verify that an executor or revision is actually active. Resume
  review when active. Otherwise inspect the preserved worktree and record the
  lifecycle state its evidence supports; do not leave a stale `IN PROGRESS`.
- `IMPLEMENTED`: verify the scoped diff and executor checks, locate the actual
  landing commit if integrated, and advance to `DONE` only after all acceptance
  checks pass. If a named acceptance check remains, correct the state to
  `ACCEPTANCE PENDING`.
- `ACCEPTANCE PENDING`: preserve the named runtime, physical, human, or external
  check; verify its result without treating implementation approval or landing
  alone as acceptance. Advance to `DONE` only after integration and every check.
- `DONE`: verify the integrated implementation, checks, and acceptance evidence,
  then record or confirm the actual landing commit.
- `BLOCKED`: verify whether the blocker still exists; revise the plan only when
  the original approach remains valid.
- `REJECTED`: preserve the rationale and verify only whether new evidence makes
  deliberate re-planning appropriate; do not silently reactivate it.

Obsolete or independently fixed work becomes `REJECTED` with a one-line
rationale rather than being deleted. Reconciliation follows the planning
contract's authority, semantic-anchor, and material-change rules for every
state transition.

## Publish Issues

Only publish when `--issues` was explicitly requested. Before creating issues, check repository visibility. For a public repository, obtain explicit confirmation before publishing security findings, credential locations, private architecture, or operational details. Record each issue URL in the plan and index.
