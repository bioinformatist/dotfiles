{
  pkgs,
  ...
}:
let
  codexVersion = "0.121.0";
  codexAsset = "codex-x86_64-unknown-linux-musl.tar.gz";
  codexBinary = "codex-x86_64-unknown-linux-musl";
  codexPkg = pkgs.stdenvNoCC.mkDerivation {
    pname = "codex";
    version = codexVersion;

    src = pkgs.fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${codexVersion}/${codexAsset}";
      hash = "sha256-J4xysD1OH2YbqCjBzPNuui+I2AdMcOPwMhHb+2MSc8Q=";
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
        --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.ripgrep pkgs.bubblewrap ]}
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

    # Reuse the GitHub token already managed for Claude Code so both tools share
    # the same auth without duplicating a secret in the repository.
    token="$(${pkgs.jq}/bin/jq -r '.mcpServers.github.env.GITHUB_PERSONAL_ACCESS_TOKEN // empty' "$HOME/.claude.json" 2>/dev/null || true)"
    if [ -z "$token" ] && [ -n "''${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
      token="$GITHUB_PERSONAL_ACCESS_TOKEN"
    fi

    if [ -z "$token" ]; then
      echo "GitHub token not found in ~/.claude.json or GITHUB_PERSONAL_ACCESS_TOKEN" >&2
      exit 1
    fi

    export GITHUB_PERSONAL_ACCESS_TOKEN="$token"
    exec ${pkgs.github-mcp-server}/bin/github-mcp-server stdio --toolsets context,issues,pull_requests,repos,users,orgs
  '';
in
{
  home.packages = [ codexPkg ];

  # Codex keeps its own state under ~/.codex, which is ephemeral on this system.
  # Persist the whole directory so auth, history, and other runtime state
  # survive reboot.
  home.file.".codex/config.toml" = {
    # Even though ~/.codex is persisted, keep config.toml declarative so
    # long-lived policy and UI defaults do not drift from the Nix-managed
    # baseline. This also means interactive Codex features that try to rewrite
    # config.toml will fail by design, because the file is a read-only symlink
    # into the Nix store.
    # Model and sandbox defaults are intentionally managed here for the same reason.
    force = true;
    text = ''
      model = "gpt-5.4"
      model_reasoning_effort = "medium"
      personality = "pragmatic"
      sandbox_mode = "danger-full-access"
      [features]
      memories = true
      codex_hooks = true

      [tui]
      status_line = ["model-with-reasoning", "current-dir", "context-remaining", "five-hour-limit", "weekly-limit", "thread-title"]

      [projects."/home/ysun/github.com/bioinformatist/dotfiles"]
      trust_level = "trusted"

      [mcp_servers.github]
      command = "${githubMcpServer}/bin/github-mcp-server"
    '';
  };

  # Command allow/prompt rules are different from config.toml: keep a
  # declarative baseline in its own file, but do not take over default.rules.
  # That lets Codex continue writing ad-hoc approvals gathered from the TUI to
  # ~/.codex/rules/default.rules, while this baseline remains reproducible under
  # Home Manager.
  # This split is intentional: policy stays declarative, transient approvals do not.
  # Keep this baseline small so interactive approvals can stay the exception path.
  home.file.".codex/rules/baseline.rules".text = ''
    # Read-only shell commands that are routinely useful during code exploration.
    prefix_rule(
        pattern = ["pwd"],
        decision = "allow",
        justification = "Allow checking the current working directory.",
        match = ["pwd"],
    )

    prefix_rule(
        pattern = ["ls"],
        decision = "allow",
        justification = "Allow listing directory contents.",
        match = [
            "ls",
            "ls -la",
            "ls home/programs",
        ],
    )

    prefix_rule(
        pattern = ["cat"],
        decision = "allow",
        justification = "Allow reading file contents.",
        match = [
            "cat flake.nix",
            "cat home/programs/codex/default.nix",
        ],
    )

    prefix_rule(
        pattern = ["rg"],
        decision = "allow",
        justification = "Allow fast text and file search during repository exploration.",
        match = [
            "rg codex home/programs",
            "rg --files home/programs",
        ],
    )

    prefix_rule(
        pattern = ["git", "status"],
        decision = "allow",
        justification = "Allow checking repository status.",
        match = [
            "git status",
            "git status --short",
        ],
    )

    prefix_rule(
        pattern = ["git", "diff"],
        decision = "allow",
        justification = "Allow inspecting uncommitted changes.",
        match = [
            "git diff",
            "git diff --stat",
            "git diff home/programs/codex/default.nix",
        ],
    )

    prefix_rule(
        pattern = ["git", "show"],
        decision = "allow",
        justification = "Allow inspecting commits and object contents.",
        match = [
            "git show HEAD",
            "git show HEAD~1:flake.nix",
        ],
    )

    prefix_rule(
        pattern = ["git", "log"],
        decision = "allow",
        justification = "Allow browsing commit history.",
        match = [
            "git log --oneline -5",
            "git log -- home/programs/codex/default.nix",
        ],
    )
  '';

}
