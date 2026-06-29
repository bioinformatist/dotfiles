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
  codexVersion = "0.142.2";
  codexAsset = "codex-x86_64-unknown-linux-musl.tar.gz";
  codexBinary = "codex-x86_64-unknown-linux-musl";
  codexHash = "sha256-EskAXId46fdiOxe3fzy/VugFmAmsaAJ7NWDBqBOapOI=";
  codexNode = pkgs.nodejs_24;
  playwrightCliVersion = "0.1.14";
  playwrightCliSource = pkgs.fetchFromGitHub {
    owner = "microsoft";
    repo = "playwright-cli";
    rev = "v${playwrightCliVersion}";
    hash = "sha256-wLE04sfPMh43IzIp6/HKBjloy3iSSanSYdYtklc6lQ4=";
  };
  mattPocockSkillsSource = inputs.mattpocock-skills;
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
  ponytailSkillMd = pkgs.writeText "ponytail-SKILL.md" ''
    ---
    name: ponytail
    description: On-demand minimalist implementation assistant. Use only when the user explicitly asks for Ponytail, YAGNI, the simplest viable implementation, stdlib/native-first implementation, or a minimal solution. Do not use as an always-on coding style, persistent mode, prose editor, or substitute for correctness/security review.
    license: MIT
    upstream: https://github.com/DietrichGebert/ponytail/tree/v${ponytailVersion}
    ---

    # Ponytail

    Use this skill as a bounded YAGNI and minimal-implementation pass. It is
    intentionally not persistent: apply it to the current task only, unless the
    user explicitly asks again.

    ## Ladder

    Prefer the first option that actually satisfies the request:

    1. Skip work that does not need to exist.
    2. Use the standard library when it covers the need.
    3. Use native platform features before custom code or new dependencies.
    4. Use already-installed dependencies before adding new ones.
    5. Keep the implementation as small and direct as the real requirement allows.

    ## Boundaries

    Do not remove trust-boundary validation, security controls, accessibility
    basics, data-loss prevention, edge-case correctness, required checks, or
    explicitly requested behavior. If the smallest implementation has a known
    ceiling, say what triggers the larger version.

    For over-engineering review, prefer `$ponytail-review` or
    `$ponytail-audit`; those are complexity-only passes and do not replace a
    normal correctness/security review.
  '';
  ponytailSkill = pkgs.runCommand "codex-ponytail-skill" { } ''
    mkdir -p "$out"
    cp ${ponytailSource}/LICENSE "$out/LICENSE"
    cp ${ponytailSkillMd} "$out/SKILL.md"
  '';
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
  writableRoots = lib.unique config.dotfiles.codex.writableRoots;
  writableRootsToml = builtins.toJSON writableRoots;

  trustedProjectsToml = lib.concatMapStringsSep "\n\n" (path: ''
    [projects."${path}"]
    trust_level = "trusted"
  '') trustedProjects;

  codexConfigToml = pkgs.writeText "codex-config.toml" ''
    model = "gpt-5.5"
    model_reasoning_effort = "medium"
    personality = "pragmatic"
    sandbox_mode = "workspace-write"
    approval_policy = "on-request"

    [sandbox_workspace_write]
    writable_roots = ${writableRootsToml}

    [features]
    memories = true
    hooks = true

    [notices]
    hide_rate_limit_model_nudge = true

    [tui]
    status_line = ["model-with-reasoning", "current-dir", "context-remaining", "five-hour-limit", "weekly-limit", "thread-title"]

    [shell_environment_policy]
    set = { XDG_CACHE_HOME = "/tmp/codex-nix-cache" }

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
    description = "Whether to install Ponytail Codex skills for on-demand YAGNI and over-engineering review workflows.";
  };

  options.dotfiles.codex.mattPocockSkills.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install a narrow global subset of Matt Pocock's engineering Codex skills.";
  };

  config = {
    home.packages = [
      codexPkg
      codexToolPkgs.mcp-nixos
      codexNode
      playwrightCli
    ];

    home.file.".agents/skills/playwright-cli".source = "${playwrightCliSource}/skills/playwright-cli";
    home.file.".agents/skills/stop-slop" = lib.mkIf config.dotfiles.codex.stopSlop.enable {
      source = stopSlopSkill;
    };
    home.file.".agents/skills/ponytail" = lib.mkIf config.dotfiles.codex.ponytail.enable {
      source = ponytailSkill;
    };
    home.file.".agents/skills/ponytail-review" = lib.mkIf config.dotfiles.codex.ponytail.enable {
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

    # Codex keeps its own state under ~/.codex, which is ephemeral on this system.
    # Persist the whole directory so auth, history, and other runtime state
    # survive reboot.
    home.file.".codex/AGENTS.md".text = ''
      # AGENTS.md

      Behavioral guidelines to reduce common LLM coding mistakes. Merge with
      project-specific instructions as needed.

      Tradeoff: These guidelines bias toward caution over speed. For trivial
      tasks, use judgment.

      ## 1. Think Before Coding

      Don't assume. Don't hide confusion. Surface tradeoffs.

      Before implementing:

      - State your assumptions explicitly. If uncertain, ask.
      - If multiple interpretations exist, present them; don't pick silently.
      - If a simpler approach exists, say so. Push back when warranted.
      - If something is unclear, stop. Name what's confusing. Ask.

      ## 2. Simplicity First

      Minimum code that solves the problem. Nothing speculative.

      - No features beyond what was asked.
      - No abstractions for single-use code.
      - No "flexibility" or "configurability" that wasn't requested.
      - No error handling for impossible scenarios.
      - If you write 200 lines and it could be 50, rewrite it.

      Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes,
      simplify.

      ## 3. Surgical Changes

      Touch only what you must. Clean up only your own mess.

      When editing existing code:

      - Don't "improve" adjacent code, comments, or formatting.
      - Don't refactor things that aren't broken.
      - Match existing style, even if you'd do it differently.
      - If you notice unrelated dead code, mention it; don't delete it.

      When your changes create orphans:

      - Remove imports, variables, or functions that your changes made unused.
      - Don't remove pre-existing dead code unless asked.

      The test: Every changed line should trace directly to the user's request.

      ## 4. Goal-Driven Execution

      Define success criteria. Loop until verified.

      Transform tasks into verifiable goals:

      - "Add validation" -> "Write tests for invalid inputs, then make them pass"
      - "Fix the bug" -> "Write a test that reproduces it, then make it pass"
      - "Refactor X" -> "Ensure tests pass before and after"

      For multi-step tasks, state a brief plan:

      ```text
      1. [Step] -> verify: [check]
      2. [Step] -> verify: [check]
      3. [Step] -> verify: [check]
      ```

      Strong success criteria let you loop independently. Weak criteria ("make it
      work") require constant clarification.

      ## 5. Git And Nix

      Write commit messages in Conventional Commits format: `<type>: <summary>`.
      Run `nix eval`, `nix check`, and `nix build` directly; Codex already sets
      `XDG_CACHE_HOME`, so do not add an `env XDG_CACHE_HOME=...` prefix unless
      debugging that environment variable itself.

      When adding or updating a repo-local devShell, prefer a pinned lock that
      has been verified to enter quickly with the machine's configured
      substituters. If a fresh lock triggers large local builds such as
      Chromium, GCC, or xgcc for normal development, try a recent cache-hit lock
      before redesigning the shell. Do not implement dynamic nixpkgs fallback in
      `flake.nix`; keep lock selection explicit.

      ## 6. Capability Routing

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
