def dotfiles-maint-codex-github-plugin [] {
  let result = (^codex plugin list --marketplace openai-curated | complete)
  let output = $"($result.stdout)\n($result.stderr)"
  let rows = ($output | lines | where {|line| $line =~ '^github@openai-curated\s+installed, enabled\b' })
  let line = if ($rows | is-empty) { "" } else { $rows | first }

  {
    commandOk: ($result.exit_code == 0)
    enabled: ($line | str contains "installed, enabled")
    line: $line
  }
}

def maint-codex [--check-only] {
  mut failed = false

  let version = (^codex --version | complete)
  if $version.exit_code == 0 {
    print $"codex: ($version.stdout | str trim)"
  } else {
    print "codex: unavailable"
    let err = ($version.stderr | str trim)
    if $err != "" { print $err }
    $failed = true
  }

  if $version.exit_code == 0 {
    mut plugin_status = (dotfiles-maint-codex-github-plugin)
    if ($plugin_status.commandOk and $plugin_status.enabled) {
      print $"github plugin: ($plugin_status.line)"
    } else if $check_only {
      print "github plugin: github@openai-curated is not installed and enabled"
      $failed = true
    } else {
      print "github plugin: installing/enabling github@openai-curated..."
      let install = (^codex plugin add github@openai-curated | complete)
      let out = ($install.stdout | str trim)
      let err = ($install.stderr | str trim)
      if $out != "" { print $out }
      if $err != "" { print $err }
      if $install.exit_code != 0 { $failed = true }

      $plugin_status = (dotfiles-maint-codex-github-plugin)
      if ($plugin_status.commandOk and $plugin_status.enabled) {
        print $"github plugin: ($plugin_status.line)"
      } else {
        print "github plugin: still not installed and enabled"
        $failed = true
      }
    }
  }

  let mcp = (which mcp-nixos)
  if ($mcp | is-empty) {
    print "mcp-nixos: missing from PATH; rebuild the declarative Codex environment"
    $failed = true
  } else {
    print $"mcp-nixos: (($mcp | first).path)"
  }

  if $failed {
    error make { msg: "Codex maintenance checks failed." }
  }
}
