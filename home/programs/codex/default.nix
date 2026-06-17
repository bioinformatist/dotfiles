{ inputs }:

{
  config,
  lib,
  pkgs,
  ...
}:
let
  codexToolPkgs = inputs.nixpkgs-tools.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  codexVersion = "0.139.0";
  codexAsset = "codex-x86_64-unknown-linux-musl.tar.gz";
  codexBinary = "codex-x86_64-unknown-linux-musl";
  codexHash = "sha256-Euv3DfQdyDEGGGKRKrXn6s3RErsX6M6bIJjLPZIYAIE=";
  playwrightCliVersion = "0.1.13";
  playwrightCliSource = pkgs.fetchFromGitHub {
    owner = "microsoft";
    repo = "playwright-cli";
    rev = "v${playwrightCliVersion}";
    hash = "sha256-hHK/GR5Drlt+e0L9kyNmn+ht1PCrVH6WrVbxGB1Wsxg=";
  };
  stopSlopRev = "8da1f030185bdfe8471220585162991eaeb970e9";
  stopSlopSource = pkgs.fetchFromGitHub {
    owner = "hardikpandya";
    repo = "stop-slop";
    rev = stopSlopRev;
    hash = "sha256-JMqlCRVEAfwG1TLMDpnamznkBfkmX6e2XyETTTH/TSE=";
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
    exec ${pkgs.github-mcp-server}/bin/github-mcp-server stdio --toolsets context,issues,pull_requests,repos,users,orgs
  '';

  playwrightCli = pkgs.writeShellScriptBin "playwright-cli" ''
    set -euo pipefail

    export PATH="${pkgs.nodejs_24}/bin:$PATH"
    export npm_config_cache="''${XDG_CACHE_HOME:-$HOME/.cache}/npm"
    exec ${pkgs.nodejs_24}/bin/npx -y @playwright/cli@${playwrightCliVersion} "$@"
  '';

  trustedProjects = lib.unique config.dotfiles.codex.trustedProjects;
  writableRoots = lib.unique config.dotfiles.codex.writableRoots;
  writableRootsToml = builtins.toJSON writableRoots;
  stopSlopAgentsText = lib.optionalString config.dotfiles.codex.stopSlop.enable ''

    ## 6. Publishable Prose

    Use `$stop-slop` as a final pass for English PR bodies, issue bodies,
    release notes, README/docs text, public comments, and other publishable
    prose. Preserve technical facts, quoted text, code blocks, command output,
    identifiers, API names, and useful uncertainty.
  '';

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
    command = "${pkgs.context7-mcp}/bin/context7-mcp"
    required = true
    startup_timeout_sec = 30
    tool_timeout_sec = 120

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
      "/home/ysun/.codex/memories"
    ];
    description = "Extra directories that Codex may write in workspace-write mode.";
  };

  options.dotfiles.codex.githubTokenFile = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "Path to a GitHub token file used by the GitHub MCP server.";
  };

  options.dotfiles.codex.stopSlop.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether to install the stop-slop Codex prose-editing skill and reference it from global AGENTS.md.";
  };

  config = {
    home.packages = [
      codexPkg
      codexToolPkgs.mcp-nixos
      playwrightCli
    ];

    home.file.".agents/skills/playwright-cli".source = "${playwrightCliSource}/skills/playwright-cli";
    home.file.".agents/skills/stop-slop" = lib.mkIf config.dotfiles.codex.stopSlop.enable {
      source = stopSlopSkill;
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
    ''
    + stopSlopAgentsText;

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
