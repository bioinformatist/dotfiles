{
  config,
  lib,
  pkgs,
  ...
}:
let
  codexVersion = "0.131.0";
  codexAsset = "codex-x86_64-unknown-linux-musl.tar.gz";
  codexBinary = "codex-x86_64-unknown-linux-musl";
  codexPkg = pkgs.stdenvNoCC.mkDerivation {
    pname = "codex";
    version = codexVersion;

    src = pkgs.fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/${codexAsset}";
      hash = "sha256-9bJnMrdslUN0L3k3p8iPh54AwKc7ZzAIBDpc7mPoNh0=";
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

  trustedProjects = lib.unique config.dotfiles.codex.trustedProjects;

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
  '';
in
{
  options.dotfiles.codex.trustedProjects = lib.mkOption {
    type = with lib.types; listOf str;
    default = [ ];
    description = "Extra project roots that Codex should treat as trusted.";
  };

  options.dotfiles.codex.githubTokenFile = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "Path to a GitHub token file used by the GitHub MCP server.";
  };

  config = {
    home.packages = [ codexPkg ];

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
    '';

    # Keep the Codex baseline declarative, but install it as a real writable file.
    # Codex records hook trust decisions in config.toml; a Home Manager symlink
    # into the Nix store makes "Trust all and continue" fail with config/batchWrite.
    home.activation.codex-config = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      configFile="$HOME/.codex/config.toml"
      mkdir -p "$(dirname "$configFile")"
      if [ -L "$configFile" ] || [ ! -e "$configFile" ]; then
        rm -f "$configFile"
        install -m600 ${codexConfigToml} "$configFile"
      fi
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

      prefix_rule(pattern=["nix", "eval"], decision="allow")
      prefix_rule(pattern=["nix", "check"], decision="allow")
      prefix_rule(pattern=["nix", "build"], decision="allow")
      prefix_rule(pattern=["nix", "flake", "update"], decision="allow")

      prefix_rule(pattern=["git", "status"], decision="allow")
      prefix_rule(pattern=["git", "diff"], decision="allow")
      prefix_rule(pattern=["git", "show"], decision="allow")
      prefix_rule(pattern=["git", "log"], decision="allow")
    '';
  };

}
