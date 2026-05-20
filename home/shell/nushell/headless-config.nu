$env.config = {
  show_banner: false,
  buffer_editor: "hx",
}

$env.EDITOR = "hx"
$env.VISUAL = "hx"
$env.SOPS_AGE_KEY_FILE = ("~/.config/sops/age/keys.txt" | path expand)

def dotfiles-maint-settings-file [] {
  ($env.HOME | path join ".config" "dotfiles" "maint.nuon")
}

def dotfiles-maint-settings [] {
  let settings_file = (dotfiles-maint-settings-file)
  if not ($settings_file | path exists) {
    error make { msg: $"Maintenance settings not found: ($settings_file)" }
  }

  open $settings_file
}

def dotfiles-maint-repo [] {
  (dotfiles-maint-settings).repo
}

def dotfiles-maint-host [] {
  (dotfiles-maint-settings).host
}

def dotfiles-maint-config-file [] {
  (dotfiles-maint-settings).proxyConfig
}

def dotfiles-maint-risk-markers [] {
  (dotfiles-maint-settings).riskMarkers? | default []
}

def dotfiles-maint-update-groups [] {
  (dotfiles-maint-settings).updateGroups? | default {}
}

def dotfiles-maint-config [] {
  let cfg_file = (dotfiles-maint-config-file)
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

def dotfiles-maint-lock-update [inputs: list<string>] {
  let repo = (dotfiles-maint-repo)
  let args = (["flake" "update"] | append $inputs | append "--flake" | append $repo)

  print $"Updating flake inputs: (($inputs | str join ', '))"
  with-env (dotfiles-maint-config) {
    ^nix ...$args
  }
}

def dotfiles-maint-update [group: string] {
  let inputs = (dotfiles-maint-update-groups | get --optional $group | default [])
  if ($inputs | is-empty) {
    error make { msg: $"Maintenance update group not configured: ($group)" }
  }

  dotfiles-maint-lock-update $inputs
}

# Update the configured binary-friendly tool input group.
def maint-update-tools [] {
  print "Updating configured binary-friendly tool inputs..."
  print "Codex pins are refreshed upstream; headless hosts receive them through their upstream flake input."
  dotfiles-maint-update "tools"
}

# Update configured low-frequency infrastructure inputs.
def maint-update-infra [] {
  print "Updating configured low-frequency infrastructure inputs..."
  dotfiles-maint-update "infra"
}

# Update configured base system inputs.
def maint-update-base [] {
  dotfiles-maint-update "base"
}

# Run a dry-run and summarize whether rebuilding is advisable.
def maint-check [risk_markers: list<string> = []] {
  let repo = (dotfiles-maint-repo)
  let host = (dotfiles-maint-host)
  let attr = $"($repo)#nixosConfigurations.($host).config.system.build.toplevel"
  let markers = if ($risk_markers | is-empty) { dotfiles-maint-risk-markers } else { $risk_markers }
  let tmp = (^mktemp "/tmp/maint-check.XXXXXX" | str trim)
  let code_file = (^mktemp "/tmp/maint-check-code.XXXXXX" | str trim)

  with-env (dotfiles-maint-config) {
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

# Rebuild and switch using the current lock state.
def maint-switch [] {
  let repo = (dotfiles-maint-repo)
  let host = (dotfiles-maint-host)
  let flake = $"($repo)#($host)"

  with-env (dotfiles-maint-config) {
    ^sudo --preserve-env=HTTP_PROXY,HTTPS_PROXY,http_proxy,https_proxy,NO_PROXY,no_proxy,NIX_CONFIG nixos-rebuild switch --flake $flake
  }
}
