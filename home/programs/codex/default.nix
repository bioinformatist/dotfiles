{ inputs }:

{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Codex tooling update policy:
  # - Direct release pins below may be bumped here with their hashes.
  # - MCP packages should come from nixpkgs-tools; avoid local overrides unless
  #   fixing a concrete bug or security issue.
  # - Flake-input skills are updated through their input plus sync/check commands.
  codexToolPkgs = inputs.nixpkgs-tools.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  codexVersion = "0.145.0";
  codexAsset = "codex-x86_64-unknown-linux-musl.tar.gz";
  codexBinary = "codex-x86_64-unknown-linux-musl";
  codexHash = "sha256-v68Tybo08q12TkqRbEnPcXeuujKc8PcZ4iJ1ZvyNZio=";
  codexNode = pkgs.nodejs_24;
  playwrightCliVersion = "0.1.14";
  playwrightCliSource = pkgs.fetchFromGitHub {
    owner = "microsoft";
    repo = "playwright-cli";
    rev = "v${playwrightCliVersion}";
    hash = "sha256-wLE04sfPMh43IzIp6/HKBjloy3iSSanSYdYtklc6lQ4=";
  };
  mattPocockSkillsSource = inputs.mattpocock-skills;
  improveSource = inputs.shadcn-improve;
  stopSlopRev = "8da1f030185bdfe8471220585162991eaeb970e9";
  stopSlopSource = pkgs.fetchFromGitHub {
    owner = "hardikpandya";
    repo = "stop-slop";
    rev = stopSlopRev;
    hash = "sha256-JMqlCRVEAfwG1TLMDpnamznkBfkmX6e2XyETTTH/TSE=";
  };
  ponytailVersion = "4.8.3";
  ponytailSource = pkgs.fetchFromGitHub {
    owner = "DietrichGebert";
    repo = "ponytail";
    rev = "v${ponytailVersion}";
    hash = "sha256-4ZT89GA5xnomNBIzY8Kh1yYP0AC9SeVhv406DEKpE3A=";
  };
  stopSlopSkillMd = pkgs.writeText "stop-slop-SKILL.md" ''
    ---
    name: stop-slop
    description: Prose final-pass editor for GitHub issue bodies, pull request bodies, release notes, README/docs changes, public comments, and user-facing explanations. Use when Codex drafts or revises substantial prose that will be published or committed, especially when the user asks to polish, de-slop, make it less AI-written, improve a PR/issue body, or prepare docs text; do not use for ordinary code implementation, debugging transcripts, logs, quoted text, command output, API names, or Chinese conversational replies unless explicitly requested.
    ---

    # Stop Slop

    Use this skill as a final prose pass, after technical facts are correct.

    ## Workflow

    1. Preserve facts, scope, and intent.
    2. Leave code blocks, commands, logs, stack traces, quoted source text, identifiers, API names, filenames, branch names, commit messages, and test names unchanged unless the user explicitly asks to rewrite them.
    3. For English prose, remove formulaic AI phrasing, throat-clearing, empty emphasis, stock transitions, fake symmetry, inflated claims, and punchline endings.
    4. Prefer concrete nouns, direct verbs, and specific consequences over vague summaries.
    5. Keep useful technical caution. Do not remove uncertainty, caveats, or passive voice when they make the engineering claim more accurate.
    6. Keep the output in the user's requested language and tone. For Chinese output, use the reference files only as a smell list, not as English style rules.
    7. If a reference detail is needed, read only the relevant file:
       - `references/phrases.md` for filler phrases and stock wording.
       - `references/structures.md` for formulaic paragraph and sentence shapes.
       - `references/examples.md` for before/after patterns.

    ## Output Rules

    - Return the revised text, not a scoring report, unless asked.
    - Mention material factual changes separately if any were unavoidable.
    - Keep Markdown structure valid and preserve links.
    - Do not make the prose more combative or marketing-like.
  '';
  stopSlopOpenaiYaml = pkgs.writeText "stop-slop-openai.yaml" ''
    interface:
      display_name: "Stop Slop"
      short_description: "Polish publishable prose without AI tells"
      default_prompt: "Use $stop-slop to tighten this PR or issue text without changing technical facts."
    policy:
      allow_implicit_invocation: true
  '';
  stopSlopSkill = pkgs.runCommand "codex-stop-slop-skill" { } ''
    mkdir -p "$out/agents" "$out/references"
    cp ${stopSlopSource}/LICENSE "$out/LICENSE"
    cp ${stopSlopSource}/references/*.md "$out/references/"
    cp ${stopSlopSkillMd} "$out/SKILL.md"
    cp ${stopSlopOpenaiYaml} "$out/agents/openai.yaml"
  '';
  mkMattPocockSkill =
    {
      name,
      path,
      description,
      displayName,
      shortDescription,
      defaultPrompt,
      allowImplicit ? true,
      postPatch ? "",
    }:
    let
      skillHeader = pkgs.writeText "${name}-SKILL-header.md" ''
        ---
        name: ${name}
        description: ${description}
        ---
      '';
      openaiYaml = pkgs.writeText "${name}-openai.yaml" ''
        interface:
          display_name: "${displayName}"
          short_description: "${shortDescription}"
          default_prompt: "${defaultPrompt}"
        policy:
          allow_implicit_invocation: ${if allowImplicit then "true" else "false"}
      '';
    in
    pkgs.runCommand "codex-mattpocock-${name}-skill" { } ''
      mkdir -p "$out"
      cp -R ${mattPocockSkillsSource}/${path}/. "$out/"
      chmod -R u+w "$out"

      rm -f "$out/SKILL.md"
      cat ${skillHeader} > "$out/SKILL.md"
      awk '
        BEGIN { dashes = 0 }
        /^---$/ && dashes < 2 { dashes++; next }
        dashes >= 2 { print }
      ' ${mattPocockSkillsSource}/${path}/SKILL.md >> "$out/SKILL.md"

      mkdir -p "$out/agents"
      cp ${openaiYaml} "$out/agents/openai.yaml"

      ${postPatch}
    '';
  mattPocockDiagnosingBugsSkill = mkMattPocockSkill {
    name = "diagnosing-bugs";
    path = "skills/engineering/diagnosing-bugs";
    description = "Disciplined diagnosis loop for hard bugs, regressions, flaky failures, and performance problems with unclear cause. Use for root-cause debugging after a concrete symptom exists; do not use for routine implementation or speculative cleanup.";
    displayName = "Diagnosing Bugs";
    shortDescription = "Debug hard bugs with a tight feedback loop";
    defaultPrompt = "Use $diagnosing-bugs to build a tight repro loop and diagnose this bug.";
    postPatch = ''
      substituteInPlace "$out/SKILL.md" \
        --replace-fail 'hand off to the `/improve-codebase-architecture` skill with the specifics' \
        'recommend a follow-up architecture review with the specifics'
    '';
  };
  mattPocockTddSkill = mkMattPocockSkill {
    name = "tdd";
    path = "skills/engineering/tdd";
    description = "Test-driven development with red-green-refactor and behavior-focused tests. Use when the user explicitly wants test-first work, a regression test before a fix, or integration tests that drive a feature through a public interface.";
    displayName = "TDD";
    shortDescription = "Drive changes through behavior tests";
    defaultPrompt = "Use $tdd to implement this change through a red-green-refactor loop.";
    postPatch = ''
      substituteInPlace "$out/SKILL.md" \
        --replace-fail 'run the `/codebase-design` skill for the vocabulary and the testability checks' \
        'use `$codebase-design` for the vocabulary and testability checks'
    '';
  };
  mattPocockCodebaseDesignSkill = mkMattPocockSkill {
    name = "codebase-design";
    path = "skills/engineering/codebase-design";
    description = "Shared vocabulary for designing deep modules, interfaces, seams, adapters, leverage, and locality. Use when designing or reshaping module boundaries, making code more testable, or evaluating interface depth.";
    displayName = "Codebase Design";
    shortDescription = "Design deeper modules and cleaner seams";
    defaultPrompt = "Use $codebase-design to evaluate this module interface and seam placement.";
    postPatch = ''
      substituteInPlace "$out/DESIGN-IT-TWICE.md" \
        --replace-fail 'Spawn 3+ sub-agents in parallel using the Agent tool. Each must produce a **radically different** interface for the deepened module.' \
        'When multi-agent tools are available, spawn 3+ sub-agents in parallel; otherwise produce 3 distinct designs yourself. Each must produce a **radically different** interface for the deepened module.'
    '';
  };
  mattPocockGrillingSkill = mkMattPocockSkill {
    name = "grilling";
    path = "skills/productivity/grilling";
    description = "Explicit-only interview loop for stress-testing a plan or design. Use only when the user asks to grill, interrogate, interview, or stress-test a plan before implementation.";
    displayName = "Grilling";
    shortDescription = "Stress-test a plan by asking one question at a time";
    defaultPrompt = "Use $grilling to stress-test this plan before implementation.";
    allowImplicit = false;
  };
  improveSkill = pkgs.runCommand "codex-shadcn-improve-skill" { } ''
        mkdir -p "$out/agents" "$out/references"
        cp ${improveSource}/LICENSE.md "$out/LICENSE.md"
        cp ${./improve/SKILL.md} "$out/SKILL.md"
        cp ${./improve/agents/openai.yaml} "$out/agents/openai.yaml"
        cp ${improveSource}/skills/improve/references/audit-playbook.md "$out/references/audit-playbook.md"
        cp ${improveSource}/skills/improve/references/plan-template.md "$out/references/plan-template.md"
        cp ${./improve/references/closing-the-loop.md} "$out/references/closing-the-loop.md"
        cp ${./improve/references/planning-contract.md} "$out/references/planning-contract.md"
        cp ${./improve/references/review-verdict.schema.json} "$out/references/review-verdict.schema.json"

        substituteInPlace "$out/references/plan-template.md" \
          --replace-fail \
            'File naming: `plans/NNN-short-slug.md`, numbered in recommended execution order.' \
            'File naming: follow the repository'"'"'s explicit artifact convention. Otherwise use local-only `plans/NNN-short-slug.md`, or `advisor-plans/NNN-short-slug.md` when `plans/` already has another purpose, numbered in recommended execution order.' \
          --replace-fail \
            '> **Executor instructions**: Follow this plan step by step. Run every' \
            '> **Executor instructions**: Before editing, reread this complete plan and recover its objective, Semantic anchors, Modification scope, evidence/drift paths, Engineering contract, checks, and STOP conditions. Then follow it step by step. Run every' \
          --replace-fail \
            '> report — do not improvise. When done, update the status row for this plan
    > in `plans/README.md` — unless a reviewer dispatched you and told you they
    > maintain the index.' \
            '> report — do not improvise. Leave the plan and index unchanged; the advisor
    > updates lifecycle state after review.' \
          --replace-fail \
            '> **Drift check (run first)**: `git diff --stat <planned-at SHA>..HEAD -- <in-scope paths>`
    > If any in-scope file changed since this plan was written, compare the' \
            '> **Drift check (run first)**: `git diff --stat <planned-at SHA>..HEAD -- <Modification scope and evidence/drift paths>`
    > If any path in Modification scope or evidence/drift paths changed since this plan was written, compare the' \
          --replace-fail \
            '## Status

    - **Priority**: P1 | P2 | P3' \
            '## Status

    - **Status**: TODO
    - **Improve contract**: `1.0.0-codex.10`
    - **Implementation review**: PENDING
    - **Checkpoint**: NONE
    - **External acceptance**: NOT REQUIRED | PENDING
    - **Checkpoint ID**: none
    - **Priority**: P1 | P2 | P3' \
          --replace-fail \
            '- **Risk**: LOW | MED | HIGH' \
            '- **Risk**: LOW | MED | HIGH
    - **Executor lane**: spark | standard | deep
    - **Executor routing evidence**: <why this lane satisfies the Improve routing contract>
    - **Recovery seams**: none | <one to three dependency-ordered seams, each with relevant paths, gates, and a candidate lane>' \
          --replace-fail \
            '- **Issue**: <GitHub issue URL — only when published via `--issues`; omit otherwise>

    ## Why this matters' \
            '- **Issue**: <issue URL — only when published via `--issues`; omit otherwise>

    ## Semantic anchors

    Persist concise material semantics with stable provenance prefixes: `U` user decision, `F` verified fact, `D` advisor derivation, `A` assumption, and `R` rejected alternative. Include only populated categories and preserve identifiers across review.

    ## Review record

    Record the reviewed baseline, refreshed evidence, material semantic changes with provenance, and the `READY` or `BLOCKED` verdict.

    ## Checkpoint lineage

    Keep the scalar Checkpoint and Checkpoint ID above authoritative. Omit lineage rows until that persistent identity changes. Then append:

    | Stage | Identity | Superseded identity | Preserved evidence | Invalidated evidence |
    |-------|----------|---------------------|--------------------|----------------------|

    ## Why this matters' \
          --replace-fail \
            '**In scope** (the only files you should modify):' \
            '**Modification scope** (the only files you should modify):' \
          --replace-fail \
            '- `src/orders/api.test.ts` (create)

    **Out of scope**' \
            '- `src/orders/api.test.ts` (create)

    **Evidence/drift paths** (read-only inputs used to verify facts and baseline drift):
    - `src/lib/result.ts`

    **Out of scope**' \
          --replace-fail \
            '- **Depends on**: plans/NNN-*.md (or "none")' \
            '- **Depends on**: <plan artifact identifier at the repository-specific location> (or "none"); inline every dependency contract so execution never requires conversation context or another plan' \
          --replace-fail \
            '## Commands you will need' \
            '## Engineering contract

    Record one row for every planned change trigger. Modification scope limits edits, not read-only impact analysis; record a concern as not applicable only with repository evidence.

    | Concern | Planned change trigger | Requirement or command | Repository evidence | Expected result | Contract edit |
    |---------|------------------------|------------------------|---------------------|-----------------|---------------|
    | Build/generated artifacts | `<package, generated output, or N/A>` | `<exact command or N/A>` | `<path, config, or documented rule>` | `<observable result>` | `<no, pending approval, or approved>` |
    | Test/lint/type | `<behavior or source change>` | `<exact command or N/A>` | `<path, config, or documented rule>` | `<observable result>` | `<no, pending approval, or approved>` |
    | CI/policy/classifier | `<artifact, dependency, or workflow impact>` | `<exact gate or N/A>` | `<path, config, or documented rule>` | `<observable result>` | `<no, pending approval, or approved>` |
    | Compatibility/public interface | `<interface, format, or dependency change>` | `<boundary check or N/A>` | `<path, config, or documented rule>` | `<preserved behavior>` | `<no, pending approval, or approved>` |
    | Release/deployment | `<packaging, runtime, or rollout impact>` | `<exact check or N/A>` | `<path, config, or documented rule>` | `<observable result>` | `<no, pending approval, or approved>` |
    | Review/acceptance | `<risk or user-visible impact>` | `<required review or N/A>` | `<path, config, or documented rule>` | `<observable result>` | `<no, pending approval, or approved>` |

    Run state-sensitive checks before a build, cache, installation, deployment, or other local state can hide their evidence, or use clean base/head isolation. Any `pending approval` contract edit requires an evidence-backed `BLOCKED` verdict; after approval, mark it `approved`, add the exact edit paths to Modification scope, and add the exact checks to this table and the verification commands. Adding ordinary behavior tests inside an existing harness does not require approval.

    ## Verification and acceptance contract

    Classify every check exactly once. Implementation gates are deterministic or agent-observable and must pass before implementation approval. Deferred acceptance is limited to behavior the available agent and environment cannot exercise. Observations are non-blocking unless an explicit threshold and lifecycle transition are recorded.

    | Check | Class | Owner | Stage and target | Required evidence |
    |-------|-------|-------|------------------|-------------------|
    | `<exact check>` | `<implementation gate, deferred acceptance, or observation>` | `<executor, main agent, user, or external system>` | `<before review, checkpoint ID, or after integration>` | `<command output or observable result>` |

    When the Checkpoint ID changes between worktree/diff, commit, PR, integration, preview, or deployment, append one Checkpoint lineage row with the stage, new identity, superseded identity, preserved evidence, and invalidated evidence. Preserve evidence only after proving the reviewed diff is unchanged; a material diff change invalidates its applicable checks and reviewer conclusions.

    For stateful or deferred operations, add an Operational handoff with the target and checkpoint, owner, host or environment, working directory, complete commands or physical procedure, prerequisites, temporary runtime mutations, cleanup state and evidence, expected evidence, recovery, and drift invalidation. Name secret locations or credential types only, never values. Omit Operational handoff when no stateful or deferred operation exists.

    For every deferred acceptance, record the environment, exact procedure, expected evidence, rollback or recovery path, and what drift invalidates the result. Before an asynchronous handoff, the main agent records a resumable Checkpoint and exact Checkpoint ID; the executor never creates or integrates that checkpoint on its own.

    ## Commands you will need' \
          --replace-fail \
            '- Branch: `advisor/NNN-<slug>` (or the repo'"'"'s branch-naming convention if one is evident)' \
            '- Branch and worktree: created by `codex-improve-exec`; do not create another branch' \
          --replace-fail \
            '- Commit per step or per logical unit; message style: <match repo, e.g. conventional commits — include an example from `git log`>' \
            '- Leave all executor changes uncommitted for the main agent to review' \
          --replace-fail \
            '- Do NOT push or open a PR unless the operator instructed it.' \
            '- Do not commit, merge, push, open a PR, or remove the worktree.' \
          --replace-fail \
            '- [ ] `plans/README.md` status row updated' \
            '- [ ] Plan artifacts and any repository-specific plan index remain unchanged by the executor' \
          --replace-fail \
            '- [ ] No files outside the in-scope list are modified (`git status`)' \
            '- [ ] No files outside Modification scope are modified (`git status`)' \
          --replace-fail \
            '## Index file: `plans/README.md`' \
            '## Optional index at the repository-specific artifact location' \
          --replace-fail \
            'Written once by the advisor after all plans, updated by executors:' \
            'Written and maintained by the advisor after review:' \
          --replace-fail \
            'dependencies say otherwise. Each executor: read the plan fully before starting,' \
            'dependencies say otherwise. Each executor reads the plan fully before starting and' \
          --replace-fail \
            'honor its STOP conditions, and update your row when done.' \
            'honors its STOP conditions; the advisor updates status after review.' \
          --replace-fail \
            'Status values: TODO | IN PROGRESS | DONE | BLOCKED (with one-line reason) | REJECTED (with one-line rationale — finding fixed independently or approach abandoned)' \
            'Status values: TODO | IN PROGRESS | IMPLEMENTED | ACCEPTANCE PENDING | DONE | BLOCKED (with one-line reason) | REJECTED (with one-line rationale — finding fixed independently or approach abandoned). Derive ACCEPTANCE PENDING only when implementation review is APPROVED, a deferred acceptance is ready, and Checkpoint is RESUMABLE or INTEGRATED with an exact Checkpoint ID.' \
          --replace-fail \
            '- "Planned at" SHA is filled in and the in-scope paths in the drift check match the Scope section.' \
            '- "Planned at" SHA is filled in and the Modification scope plus evidence/drift paths in the drift check match the Scope section.'

        if grep -R -n -E \
          '(Explore agents|sonnet|haiku|Agent tool|subagent_type|isolation:|SendMessage|general-purpose)' \
          "$out"; then
          echo "adapted improve skill contains stale host-agent wording" >&2
          exit 1
        fi
  '';
  codexPkg = pkgs.stdenvNoCC.mkDerivation {
    pname = "codex";
    version = codexVersion;

    src = pkgs.fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/${codexAsset}";
      hash = codexHash;
    };

    sourceRoot = ".";
    nativeBuildInputs = [ pkgs.makeBinaryWrapper ];

    unpackPhase = ''
      tar -xzf "$src"
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin" "$out/libexec"
      install -m755 ${codexBinary} "$out/libexec/codex"
      makeBinaryWrapper "$out/libexec/codex" "$out/bin/codex" \
        --prefix PATH : ${
          pkgs.lib.makeBinPath [
            pkgs.ripgrep
            pkgs.bubblewrap
            pkgs.nixfmt
          ]
        }
      runHook postInstall
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck

      actualVersion="$("$out/libexec/codex" --version 2>&1 | sed -n 's/^codex-cli //p' | tail -n 1)"
      if [ "$actualVersion" != "${codexVersion}" ]; then
        echo "expected codex ${codexVersion}, got $actualVersion" >&2
        exit 1
      fi

      runHook postInstallCheck
    '';

    meta = with pkgs.lib; {
      description = "Lightweight coding agent that runs in your terminal";
      homepage = "https://github.com/openai/codex";
      license = licenses.asl20;
      mainProgram = "codex";
      platforms = [ "x86_64-linux" ];
    };
  };

  improveReviewerRole = {
    model = "gpt-5.6-sol";
    reasoningEffort = "high";
    verbosity = "medium";
    sandbox = "read-only";
    approval = "never";
    writableRoots = [ ];
    tokenLimit = 100000;
    reminders = [
      50000
      25000
      10000
    ];
    initialTimeout = 480;
    followupTimeout = null;
  };
  improveRoles = {
    standard = {
      profile = "improve-executor";
      model = "gpt-5.6-sol";
      reasoningEffort = "medium";
      verbosity = "medium";
      sandbox = "workspace-write";
      approval = "never";
      writableRoots = [ ];
      tokenLimit = 120000;
      reminders = [
        60000
        30000
        10000
      ];
      initialTimeout = 1200;
      followupTimeout = 720;
    };
    spark = {
      profile = "improve-executor-spark";
      model = "gpt-5.3-codex-spark";
      reasoningEffort = "high";
      verbosity = "medium";
      sandbox = "workspace-write";
      approval = "never";
      writableRoots = [ ];
      tokenLimit = 100000;
      reminders = [
        50000
        25000
        10000
      ];
      initialTimeout = 1200;
      followupTimeout = 720;
    };
    deep = {
      profile = "improve-executor-deep";
      model = "gpt-5.6-sol";
      reasoningEffort = "xhigh";
      verbosity = "medium";
      sandbox = "workspace-write";
      approval = "never";
      writableRoots = [ ];
      tokenLimit = 160000;
      reminders = [
        80000
        40000
        15000
      ];
      initialTimeout = 1800;
      followupTimeout = 1080;
    };
    correctness = improveReviewerRole // {
      profile = "improve-reviewer";
    };
    elegance = improveReviewerRole // {
      profile = "improve-elegance-reviewer";
    };
  };
  improveRolesJson = builtins.toJSON improveRoles;
  improveRunnerEnvironment = ''
    export CODEX_IMPROVE_ROLES_JSON=${lib.escapeShellArg improveRolesJson}
  '';
  mkImproveProfile =
    role:
    (pkgs.formats.toml { }).generate "codex-${role.profile}.config.toml" (
      {
        model = role.model;
        model_reasoning_effort = role.reasoningEffort;
        model_verbosity = role.verbosity;
        sandbox_mode = role.sandbox;
        approval_policy = role.approval;
        features = {
          multi_agent = false;
          goals = false;
          memories = false;
          rollout_budget = {
            enabled = true;
            limit_tokens = role.tokenLimit;
            reminder_at_remaining_tokens = role.reminders;
            sampling_token_weight = 1.0;
            prefill_token_weight = 1.0;
          };
        };
      }
      // lib.optionalAttrs (role.sandbox == "workspace-write") {
        sandbox_workspace_write.writable_roots = role.writableRoots;
      }
    );

  improveExec = pkgs.writeShellApplication {
    name = "codex-improve-exec";
    runtimeInputs = [
      pkgs.bash
      codexPkg
      pkgs.coreutils
      pkgs.gitMinimal
      pkgs.gnused
      pkgs.jq
    ];
    text = improveRunnerEnvironment + builtins.readFile ./improve/codex-improve-exec;
    checkPhase = ''
      runHook preCheck
      export PATH=${lib.makeBinPath [ pkgs.bash pkgs.coreutils pkgs.gitMinimal pkgs.gnused pkgs.jq ]}:$PATH
      bash -n "$target"
      ${lib.getExe pkgs.shellcheck-minimal} "$target"
      bash ${./improve/tests/exec-runner.bash} ${./improve/codex-improve-exec}
      runHook postCheck
    '';
  };

  improveReview = pkgs.writeShellApplication {
    name = "codex-improve-review";
    runtimeInputs = [
      codexPkg
      pkgs.coreutils
      pkgs.gitMinimal
      pkgs.jq
    ];
    text = ''
      export CODEX_IMPROVE_REVIEW_SCHEMA="${improveSkill}/references/review-verdict.schema.json"
      ${improveRunnerEnvironment}
      ${builtins.readFile ./improve/codex-improve-review}
    '';
    checkPhase = ''
      runHook preCheck
      export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.gitMinimal pkgs.jq ]}:$PATH
      bash -n "$target"
      ${lib.getExe pkgs.shellcheck-minimal} "$target"
      export CODEX_IMPROVE_REVIEW_SCHEMA=${./improve/references/review-verdict.schema.json}
      bash ${./improve/tests/review-runner.bash} ${./improve/codex-improve-review}
      runHook postCheck
    '';
  };

  improveScoutProfile = ''
    model = "gpt-5.6-luna"
    model_reasoning_effort = "high"
    model_verbosity = "low"
    sandbox_mode = "read-only"
    approval_policy = "never"

    [features]
    multi_agent = false
  '';
  improveExecutorProfile = mkImproveProfile improveRoles.standard;
  improveExecutorSparkProfile = mkImproveProfile improveRoles.spark;
  improveExecutorDeepProfile = mkImproveProfile improveRoles.deep;
  improveReviewerProfile = mkImproveProfile improveRoles.correctness;
  improveEleganceReviewerProfile = mkImproveProfile improveRoles.elegance;

  githubMcpServer = pkgs.writeShellScriptBin "github-mcp-server" ''
    set -euo pipefail

    token=""
    token_file="${config.dotfiles.codex.githubTokenFile}"
    if [ -n "$token_file" ] && [ -r "$token_file" ]; then
      token="$(tr -d '\n' < "$token_file")"
    fi
    if [ -z "$token" ] && [ -n "''${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
      token="$GITHUB_PERSONAL_ACCESS_TOKEN"
    fi
    if [ -z "$token" ]; then
      token="$(${pkgs.gh}/bin/gh auth token --hostname github.com 2>/dev/null || true)"
    fi

    if [ -z "$token" ]; then
      echo "GitHub token not found in dotfiles.codex.githubTokenFile, GITHUB_PERSONAL_ACCESS_TOKEN, or gh auth" >&2
      exit 1
    fi

    export GITHUB_PERSONAL_ACCESS_TOKEN="$token"
    exec ${codexToolPkgs.github-mcp-server}/bin/github-mcp-server stdio --toolsets context,issues,pull_requests,repos,users,orgs
  '';

  context7AuthMcpServer = pkgs.writeShellScriptBin "context7-auth-mcp-server" ''
    set -euo pipefail

    api_key_file="${config.dotfiles.codex.context7ApiKeyFile}"
    if [ ! -r "$api_key_file" ]; then
      echo "Context7 API key file is not readable: $api_key_file" >&2
      exit 1
    fi

    api_key="$(tr -d '\n' < "$api_key_file")"
    if [ -z "$api_key" ]; then
      echo "Context7 API key file is empty: $api_key_file" >&2
      exit 1
    fi

    export CONTEXT7_API_KEY="$api_key"
    exec ${codexToolPkgs.context7-mcp}/bin/context7-mcp
  '';

  playwrightCli = pkgs.writeShellScriptBin "playwright-cli" ''
    set -euo pipefail

    export PATH="${codexNode}/bin:$PATH"
    export npm_config_cache="''${XDG_CACHE_HOME:-$HOME/.cache}/npm"
    exec ${codexNode}/bin/npx -y @playwright/cli@${playwrightCliVersion} "$@"
  '';

  trustedProjects = lib.unique config.dotfiles.codex.trustedProjects;
  shellCacheHome = "${config.xdg.cacheHome}/codex-shell";
  writableRoots = lib.unique ([ shellCacheHome ] ++ config.dotfiles.codex.writableRoots);
  writableRootsToml = builtins.toJSON writableRoots;

  trustedProjectsToml = lib.concatMapStringsSep "\n\n" (path: ''
    [projects."${path}"]
    trust_level = "trusted"
  '') trustedProjects;

  codexConfigToml = pkgs.writeText "codex-config.toml" ''
    model = "gpt-5.6-sol"
    model_reasoning_effort = "low"
    model_verbosity = "medium"
    plan_mode_reasoning_effort = "medium"
    personality = "pragmatic"
    sandbox_mode = "workspace-write"
    approval_policy = "on-request"
    web_search = "live"
    mcp_oauth_credentials_store = "file"

    [sandbox_workspace_write]
    writable_roots = ${writableRootsToml}

    [features]
    memories = true
    hooks = true

    [notice]
    hide_rate_limit_model_nudge = true

    [tui]
    status_line = ["model-with-reasoning", "current-dir", "context-remaining", "five-hour-limit", "weekly-limit", "thread-title"]

    [shell_environment_policy]
    set = { XDG_CACHE_HOME = "${shellCacheHome}" }

    ${trustedProjectsToml}

    [mcp_servers.github]
    command = "${githubMcpServer}/bin/github-mcp-server"

    [mcp_servers.context7]
    command = "${codexToolPkgs.context7-mcp}/bin/context7-mcp"
    required = false
    startup_timeout_sec = 30
    tool_timeout_sec = 120
    ${lib.optionalString (config.dotfiles.codex.context7ApiKeyFile != "") ''

      [mcp_servers.context7_auth]
      command = "${context7AuthMcpServer}/bin/context7-auth-mcp-server"
      required = false
      startup_timeout_sec = 30
      tool_timeout_sec = 120
    ''}

    [plugins."github@openai-curated"]
    enabled = true
  '';

  mergeCodexConfig = pkgs.writeShellApplication {
    name = "merge-codex-config";
    runtimeInputs = [
      (pkgs.python3.withPackages (pythonPackages: [
        pythonPackages.tomlkit
      ]))
    ];
    text = ''
      python3 - "$@" <<'PY'
      import os
      import sys
      import tempfile
      from pathlib import Path

      import tomlkit

      managed_path = Path(sys.argv[1])
      target_path = Path(sys.argv[2])

      managed = tomlkit.parse(managed_path.read_text())
      if target_path.exists():
          target = tomlkit.parse(target_path.read_text())
      else:
          target = tomlkit.document()

      def merge(dst, src):
          for key, value in src.items():
              if (
                  key in dst
                  and hasattr(dst[key], "items")
                  and hasattr(value, "items")
              ):
                  merge(dst[key], value)
              else:
                  dst[key] = value

      merge(target, managed)

      target_path.parent.mkdir(parents=True, exist_ok=True)
      fd, tmp_name = tempfile.mkstemp(
          prefix=".config.toml.",
          dir=str(target_path.parent),
          text=True,
      )
      try:
          with os.fdopen(fd, "w") as tmp:
              tmp.write(tomlkit.dumps(target))
          os.chmod(tmp_name, 0o600)
          os.replace(tmp_name, target_path)
      finally:
          if os.path.exists(tmp_name):
              os.unlink(tmp_name)
      PY
    '';
  };

in
{
  options.dotfiles.codex.trustedProjects = lib.mkOption {
    type = with lib.types; listOf str;
    default = [ ];
    description = "Extra project roots that Codex should treat as trusted.";
  };

  options.dotfiles.codex.writableRoots = lib.mkOption {
    type = with lib.types; listOf str;
    default = [
      "${config.home.homeDirectory}/.codex/memories"
    ];
    description = "Extra directories that Codex may write in workspace-write mode.";
  };

  options.dotfiles.codex.githubTokenFile = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "Path to a GitHub token file used by the GitHub MCP server.";
  };

  options.dotfiles.codex.context7ApiKeyFile = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "Path to a Context7 API key file used by the authenticated fallback MCP server.";
  };

  options.dotfiles.codex.stopSlop.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install the stop-slop Codex prose-editing skill.";
  };

  options.dotfiles.codex.ponytail.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install the complete Ponytail Codex skill bundle; Improve independently requires ponytail-review.";
  };

  options.dotfiles.codex.mattPocockSkills.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install a narrow global subset of Matt Pocock's engineering Codex skills.";
  };

  options.dotfiles.codex.improve.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install the Codex-adapted shadcn improve workflow and isolated executor and reviewer profiles.";
  };

  config = {
    home.packages = [
      codexPkg
      codexToolPkgs.mcp-nixos
      codexNode
      playwrightCli
    ]
    ++ lib.optionals config.dotfiles.codex.improve.enable [
      improveExec
      improveReview
    ];

    home.file.".agents/skills/playwright-cli".source = "${playwrightCliSource}/skills/playwright-cli";
    home.file.".agents/skills/stop-slop" = lib.mkIf config.dotfiles.codex.stopSlop.enable {
      source = stopSlopSkill;
    };
    home.file.".agents/skills/ponytail-review" =
      lib.mkIf (config.dotfiles.codex.ponytail.enable || config.dotfiles.codex.improve.enable)
        {
          source = "${ponytailSource}/skills/ponytail-review";
        };
    home.file.".agents/skills/ponytail-audit" = lib.mkIf config.dotfiles.codex.ponytail.enable {
      source = "${ponytailSource}/skills/ponytail-audit";
    };
    home.file.".agents/skills/ponytail-debt" = lib.mkIf config.dotfiles.codex.ponytail.enable {
      source = "${ponytailSource}/skills/ponytail-debt";
    };
    home.file.".agents/skills/diagnosing-bugs" =
      lib.mkIf config.dotfiles.codex.mattPocockSkills.enable
        {
          source = mattPocockDiagnosingBugsSkill;
        };
    home.file.".agents/skills/tdd" = lib.mkIf config.dotfiles.codex.mattPocockSkills.enable {
      source = mattPocockTddSkill;
    };
    home.file.".agents/skills/codebase-design" =
      lib.mkIf config.dotfiles.codex.mattPocockSkills.enable
        {
          source = mattPocockCodebaseDesignSkill;
        };
    home.file.".agents/skills/grilling" = lib.mkIf config.dotfiles.codex.mattPocockSkills.enable {
      source = mattPocockGrillingSkill;
    };
    home.file.".agents/skills/improve" = lib.mkIf config.dotfiles.codex.improve.enable {
      source = improveSkill;
    };
    home.file.".codex/improve-scout.config.toml" = lib.mkIf config.dotfiles.codex.improve.enable {
      text = improveScoutProfile;
    };
    home.file.".codex/improve-executor.config.toml" = lib.mkIf config.dotfiles.codex.improve.enable {
      source = improveExecutorProfile;
    };
    home.file.".codex/improve-executor-spark.config.toml" =
      lib.mkIf config.dotfiles.codex.improve.enable
        {
          source = improveExecutorSparkProfile;
        };
    home.file.".codex/improve-executor-deep.config.toml" =
      lib.mkIf config.dotfiles.codex.improve.enable
        {
          source = improveExecutorDeepProfile;
        };
    home.file.".codex/improve-reviewer.config.toml" = lib.mkIf config.dotfiles.codex.improve.enable {
      source = improveReviewerProfile;
    };
    home.file.".codex/improve-elegance-reviewer.config.toml" =
      lib.mkIf config.dotfiles.codex.improve.enable
        {
          source = improveEleganceReviewerProfile;
        };

    # Codex keeps its own state under ~/.codex, which is ephemeral on this system.
    # Persist the whole directory so auth, history, and other runtime state
    # survive reboot.
    home.file.".codex/AGENTS.md".text = ''
      # AGENTS.md

      Apply these defaults across repositories. Closer project instructions
      override them.

      ## Working Style

      - Clarify material ambiguity before implementation. For minor ambiguity,
        state the assumption and proceed.
      - Prefer the smallest complete change that satisfies the request and
        matches existing repository patterns.
      - Do not modify, revert, or reformat unrelated work.
      - Complete implementation and proportionate verification unless the user
        asks only for analysis or a plan.

      ## Communication

      - Be concise for routine status updates, but make decisions self-contained.
      - On first use, briefly define uncommon names, terms, model variants, and
        project-specific concepts needed to understand the conclusion.
      - For a recommendation or solution, include the relevant context,
        mechanism, main tradeoff, and concrete verification or next action.
      - Do not make the user ask follow-up questions merely to discover what a
        proposed component is or why it is needed.

      ## Git And Nix

      Write commit messages in Conventional Commits format: `<type>: <summary>`.
      Run `nix eval`, `nix check`, and `nix build` directly; Codex already sets
      `XDG_CACHE_HOME`, so do not add an `env XDG_CACHE_HOME=...` prefix unless
      debugging that environment variable itself.

      If a GitHub or Nix fetch/update fails in a way that looks proxy-node or
      network dependent, such as API rate limits on a shared proxy IP, blocked
      downloads, DNS failures, or connection resets, treat it as an external
      blocker. Report the exact error and ask the user to switch proxy nodes
      before changing repository URLs, transports, or long-term config.

      When adding or updating a repo-local devShell, prefer a pinned lock that
      has been verified to enter quickly with the machine's configured
      substituters. If a fresh lock triggers large local builds such as
      Chromium, GCC, or xgcc for normal development, try a recent cache-hit lock
      before redesigning the shell. Do not implement dynamic nixpkgs fallback in
      `flake.nix`; keep lock selection explicit.

      ## Capability Routing

      Use installed skills for reusable workflows; keep workflow details in
      skill descriptions and `SKILL.md`, not in this global file.

      Use the anonymous `context7` MCP server first for current library,
      framework, SDK, API, CLI, or cloud-service docs. If it is rate-limited,
      unavailable, or missing a needed result, retry with `context7_auth` when
      that per-user authenticated fallback server is configured.

      Treat GitHub and Context7 tokens as per-user secrets. Never route one
      user's token or API key to another user's Codex configuration.
    '';

    # Keep config.toml as a real writable file. Codex stores runtime state there
    # too, so activation overlays only the keys this module owns.
    home.activation.codex-config = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      configFile="$HOME/.codex/config.toml"
      if [ -L "$configFile" ]; then
        rm -f "$configFile"
      fi
      ${mergeCodexConfig}/bin/merge-codex-config ${codexConfigToml} "$configFile"
    '';

    # Command allow/prompt rules are different from config.toml: keep a
    # declarative baseline in its own file, but do not take over default.rules.
    # That lets Codex continue writing ad-hoc approvals gathered from the TUI to
    # ~/.codex/rules/default.rules, while this baseline remains reproducible under
    # Home Manager.
    # This split is intentional: policy stays declarative, transient approvals do not.
    # Keep this baseline small so interactive approvals can stay the exception path.
    home.file.".codex/rules/baseline.rules".text = ''
      prefix_rule(pattern=["pwd"], decision="allow")
      prefix_rule(pattern=["ls"], decision="allow")
      prefix_rule(pattern=["cat"], decision="allow")
      prefix_rule(pattern=["rg"], decision="allow")
      prefix_rule(pattern=["sed", "-n"], decision="allow")
      prefix_rule(pattern=["head"], decision="allow")
      prefix_rule(pattern=["tail"], decision="allow")
      prefix_rule(pattern=["nl", "-ba"], decision="allow")
      prefix_rule(pattern=["wc"], decision="allow")
      prefix_rule(pattern=["stat"], decision="allow")
      prefix_rule(pattern=["file"], decision="allow")

      prefix_rule(pattern=["nix", "eval"], decision="allow")
      prefix_rule(pattern=["nix", "check"], decision="allow")
      prefix_rule(pattern=["nix", "build"], decision="allow")
      prefix_rule(pattern=["nix", "flake", "check"], decision="allow")
      prefix_rule(pattern=["env", "NIXPKGS_ALLOW_UNFREE=1", "nix", "flake", "check"], decision="allow")
      prefix_rule(pattern=["nix", "flake", "update"], decision="allow")
      prefix_rule(pattern=["nix", "flake", "show"], decision="allow")
      prefix_rule(pattern=["nix", "flake", "metadata"], decision="allow")
      prefix_rule(pattern=["nix", "path-info"], decision="allow")
      prefix_rule(pattern=["nix", "config", "show"], decision="allow")

      prefix_rule(pattern=["git", "status"], decision="allow")
      prefix_rule(pattern=["git", "diff"], decision="allow")
      prefix_rule(pattern=["git", "show"], decision="allow")
      prefix_rule(pattern=["git", "log"], decision="allow")
      prefix_rule(pattern=["git", "branch"], decision="allow")
      prefix_rule(pattern=["git", "rev-parse"], decision="allow")
      prefix_rule(pattern=["git", "ls-files"], decision="allow")

      prefix_rule(pattern=["systemctl", "is-active"], decision="allow")
      prefix_rule(pattern=["systemctl", "status"], decision="allow")
      prefix_rule(pattern=["systemctl", "show"], decision="allow")
      prefix_rule(pattern=["systemctl", "list-units"], decision="allow")

      prefix_rule(pattern=["date"], decision="allow")
      prefix_rule(pattern=["uname"], decision="allow")
      prefix_rule(pattern=["hostname"], decision="allow")
      prefix_rule(pattern=["uptime"], decision="allow")
      prefix_rule(pattern=["df"], decision="allow")
      prefix_rule(pattern=["free"], decision="allow")
    '';
  };

}
