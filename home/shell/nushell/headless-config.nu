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

def dotfiles-maint-risk-markers [] {
  (dotfiles-maint-settings).riskMarkers? | default []
}

def dotfiles-maint-update-groups [] {
  (dotfiles-maint-settings).updateGroups? | default {}
}

def dotfiles-maint-config [] {
  {}
}

def dotfiles-maint-lock-update [inputs: list<string>] {
  let repo = (dotfiles-maint-repo)
  let args = (["flake" "update"] | append $inputs | append "--flake" | append $repo)

  print $"Updating flake inputs: (($inputs | str join ', '))"
  with-env (dotfiles-maint-config) {
    ^nix ...$args
  }
}

def dotfiles-maint-toplevel-attr [] {
  let repo = (dotfiles-maint-repo)
  let host = (dotfiles-maint-host)
  $"($repo)#nixosConfigurations.($host).config.system.build.toplevel"
}

def dotfiles-maint-build-toplevel [attr: string] {
  with-env (dotfiles-maint-config) {
    ^nix build --print-out-paths --no-link $attr | str trim
  }
}

def dotfiles-maint-switch-risk [target: string] {
  let target_kernel = (^readlink -f ($target | path join "kernel") | str trim)
  let booted_kernel = (^readlink -f "/run/booted-system/kernel" | str trim)
  let kernel_changed = ($target_kernel != $booted_kernel)

  let current_nvidia = "/run/current-system/sw/bin/nvidia-smi"
  let target_nvidia = ($target | path join "sw/bin/nvidia-smi")
  let nvidia_changed = if (($current_nvidia | path exists) and ($target_nvidia | path exists)) {
    let current_nvidia_real = (^readlink -f $current_nvidia | str trim)
    let target_nvidia_real = (^readlink -f $target_nvidia | str trim)
    $current_nvidia_real != $target_nvidia_real
  } else {
    false
  }

  {
    kernelChanged: $kernel_changed
    nvidiaChanged: $nvidia_changed
    requiresBoot: ($kernel_changed or $nvidia_changed)
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
  let attr = (dotfiles-maint-toplevel-attr)
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
  let attr = (dotfiles-maint-toplevel-attr)

  print "Building target system closure..."
  let target = (dotfiles-maint-build-toplevel $attr)
  let risk = (dotfiles-maint-switch-risk $target)

  with-env (dotfiles-maint-config) {
    if $risk.requiresBoot {
      print "Detected runtime-sensitive changes; using boot activation instead of hot switch."
      if $risk.kernelChanged { print "risk: booted kernel differs from target kernel" }
      if $risk.nvidiaChanged { print "risk: NVIDIA userspace differs from current system" }
      print "Next step after this finishes: reboot into the new generation."
      ^sudo --preserve-env=HTTP_PROXY,HTTPS_PROXY,http_proxy,https_proxy,NO_PROXY,no_proxy,NIX_CONFIG nixos-rebuild boot --flake $flake
    } else {
      ^sudo --preserve-env=HTTP_PROXY,HTTPS_PROXY,http_proxy,https_proxy,NO_PROXY,no_proxy,NIX_CONFIG nixos-rebuild switch --flake $flake
    }
  }
}
