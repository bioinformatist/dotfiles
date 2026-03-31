$env.config = {
  show_banner: false,
  buffer_editor: "hx",
}

$env.EDITOR = "hx"
$env.VISUAL = "hx"
$env.SOPS_AGE_KEY_FILE = ("~/.config/sops/age/keys.txt" | path expand)

# claude-proxy: run claude with credentials loaded from ~/.config/claude/proxy.nuon
# Usage: claude-proxy [claude args...]
# The proxy.nuon file is NOT tracked by git; delete it when the token expires.
def --wrapped claude-proxy [...args: string] {
  let creds_file = ($env.HOME | path join ".config" "claude" "proxy.nuon")
  if ($creds_file | path exists) {
    with-env (open $creds_file) { ^claude ...$args }
  } else {
    error make { msg: $"Credentials file not found: ($creds_file)\nCreate it with: mkdir -p ~/.config/claude && '{ ANTHROPIC_BASE_URL: \"...\", ANTHROPIC_AUTH_TOKEN: \"...\", ANTHROPIC_MODEL: \"...\" }' | save ($creds_file)" }
  }
}