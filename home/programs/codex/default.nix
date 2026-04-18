{
  pkgs,
  ...
}:
let
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
  # Codex keeps its own state under ~/.codex, which is ephemeral on this system.
  # Persist the whole directory so auth, history, and config survive reboot.
  home.file.".codex/config.toml".text = ''
    model = "gpt-5.4-mini"
    model_reasoning_effort = "medium"
    [features]
    memories = true

    [projects."/home/ysun/github.com/bioinformatist/dotfiles"]
    trust_level = "trusted"

    [mcp_servers.github]
    command = "${githubMcpServer}/bin/github-mcp-server"
  '';
}
