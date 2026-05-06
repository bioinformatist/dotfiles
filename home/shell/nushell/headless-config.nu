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

def maint-settings-file [] {
  ($env.HOME | path join ".config" "dotfiles" "maint.nuon")
}

def maint-settings [] {
  let settings_file = (maint-settings-file)
  if not ($settings_file | path exists) {
    error make { msg: $"Maintenance settings not found: ($settings_file)" }
  }

  open $settings_file
}

def maint-repo [] {
  (maint-settings).repo
}

def maint-host [] {
  (maint-settings).host
}

def maint-config-file [] {
  (maint-settings).proxyConfig
}

def maint-risk-markers [] {
  (maint-settings).riskMarkers? | default []
}

def maint-update-groups [] {
  (maint-settings).updateGroups? | default {}
}

def maint-config [] {
  let cfg_file = (maint-config-file)
  if not ($cfg_file | path exists) {
    return {}
  }

  let cfg = (open $cfg_file)
  let substituters = ($cfg.substituters? | default [] | str join " ")

  {
    HTTP_PROXY: ($cfg.HTTP_PROXY? | default "")
    HTTPS_PROXY: ($cfg.HTTPS_PROXY? | default "")
    http_proxy: ($cfg.HTTP_PROXY? | default "")
    https_proxy: ($cfg.HTTPS_PROXY? | default "")
    NO_PROXY: ($cfg.NO_PROXY? | default "")
    no_proxy: ($cfg.NO_PROXY? | default "")
    NIX_CONFIG: (if ($substituters | is-empty) { "" } else { $"substituters = ($substituters)" })
  }
}

def maint-lock-update [inputs: list<string>] {
  let repo = (maint-repo)
  let args = (["flake" "update"] | append $inputs | append "--flake" | append $repo)

  print $"Updating flake inputs: (($inputs | str join ', '))"
  with-env (maint-config) {
    ^nix ...$args
  }
}

def maint-update [group: string] {
  let inputs = (maint-update-groups | get --optional $group | default [])
  if ($inputs | is-empty) {
    error make { msg: $"Maintenance update group not configured: ($group)" }
  }

  maint-lock-update $inputs
}

def maint-update-tools [] {
  print "Updating configured binary-friendly tool inputs..."
  print "Codex pins are refreshed upstream; headless hosts receive them through their upstream flake input."
  maint-update "tools"
}

def maint-update-infra [] {
  print "Updating configured low-frequency infrastructure inputs..."
  maint-update "infra"
}

def maint-update-base [] {
  maint-update "base"
}

def maint-check [risk_markers: list<string> = []] {
  let repo = (maint-repo)
  let host = (maint-host)
  let attr = $"($repo)#nixosConfigurations.($host).config.system.build.toplevel"
  let markers = if ($risk_markers | is-empty) { maint-risk-markers } else { $risk_markers }
  let tmp = (^mktemp "/tmp/maint-check.XXXXXX" | str trim)
  let code_file = (^mktemp "/tmp/maint-check-code.XXXXXX" | str trim)

  with-env (maint-config) {
    ^bash -lc 'nix build --dry-run -L "$1" 2>&1 | tee "$2"; printf "%s" "${PIPESTATUS[0]}" > "$3"' bash $attr $tmp $code_file
  }

  let exit_code = (open --raw $code_file | str trim | into int)
  let output = (open --raw $tmp)

  let built = ($output | str contains "will be built")
  let matched_markers = (
    $markers
    | where {|marker| $output | str contains $marker }
  )

  print ""
  print "---- maint-check summary ----"
  print $"exit_code: ($exit_code)"
  if ($matched_markers | is-empty) {
    print "risk markers: none detected"
  } else {
    print $"risk markers: (($matched_markers | str join ', '))"
  }

  if $exit_code != 0 {
    print "summary: dry-run failed; inspect the output above before rebuilding."
  } else if $built {
    print "summary: detected `will be built`; review the dry-run output before rebuilding."
  } else {
    print "summary: no `will be built` detected; rebuild is likely cache-friendly."
  }

  ^rm -f $tmp $code_file
}

def maint-switch [] {
  let repo = (maint-repo)
  let host = (maint-host)
  let flake = $"($repo)#($host)"

  with-env (maint-config) {
    ^sudo --preserve-env=HTTP_PROXY,HTTPS_PROXY,http_proxy,https_proxy,NO_PROXY,no_proxy,NIX_CONFIG nixos-rebuild switch --flake $flake
  }
}
