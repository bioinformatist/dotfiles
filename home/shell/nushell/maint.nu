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

def dotfiles-maint-network-config [] {
  let config_file = "/etc/dotfiles/nix-network.json"
  if ($config_file | path exists) {
    open $config_file
  } else {
    {}
  }
}

def dotfiles-maint-config [] {
  (dotfiles-maint-network-config).proxyEnv? | default {}
}

def dotfiles-maint-has-proxy-env [] {
  let proxy_env = (dotfiles-maint-config)
  (($proxy_env.HTTP_PROXY? | default "") != "")
    or (($proxy_env.HTTPS_PROXY? | default "") != "")
    or (($proxy_env.ALL_PROXY? | default "") != "")
    or (($proxy_env.http_proxy? | default "") != "")
    or (($proxy_env.https_proxy? | default "") != "")
    or (($proxy_env.all_proxy? | default "") != "")
}

def dotfiles-maint-risk-markers [] {
  (dotfiles-maint-settings).riskMarkers? | default [
    "nvidia-x11"
    "linux-"
    "mesa-"
    "systemd-"
    "hyprland"
    "hyprlang"
    "hyprutils"
    "hyprgraphics"
    "hyprwayland-scanner"
    "hyprwire"
    "gcc-"
    "xgcc"
    "rustc-"
    "cargo-vendor"
    "chromium"
    "electron"
    "serenityos-emoji-font"
    "nanoemoji"
  ]
}

def dotfiles-maint-allowed-local-build-markers [] {
  (dotfiles-maint-settings).allowedLocalBuildMarkers? | default [
    "hm_"
    "home-manager-path"
    "home-manager-files"
    "home-manager-generation"
    "user-environment"
    "unit-home-manager-"
    "-nix.conf.drv"
    "X-Restart-Triggers-nix-daemon"
    "unit-nix-daemon"
    "-system-units.drv"
    "-etc.drv"
    "-activate.drv"
    "nixos-system-"
  ]
}

def dotfiles-maint-allowed-direct-fetch-markers [] {
  (dotfiles-maint-settings).allowedDirectFetchMarkers? | default [
    "-codex-"
    "-zeroclaw-"
  ]
}

def dotfiles-maint-parallel [] {
  (dotfiles-maint-settings).parallel? | default {
    maxJobs: 4
    cores: 2
  }
}

def dotfiles-maint-nix-options [] {
  let parallel = (dotfiles-maint-parallel)
  mut args = []

  let max_jobs = ($parallel.maxJobs? | default null)
  if $max_jobs != null {
    $args = ($args | append ["--option" "max-jobs" ($max_jobs | into string)])
  }

  let cores = ($parallel.cores? | default null)
  if $cores != null {
    $args = ($args | append ["--option" "cores" ($cores | into string)])
  }

  $args
}

def dotfiles-maint-toplevel-attr [] {
  let repo = (dotfiles-maint-repo)
  let host = (dotfiles-maint-host)
  $"($repo)#nixosConfigurations.($host).config.system.build.toplevel"
}

def dotfiles-maint-repo-clean [] {
  let repo = (dotfiles-maint-repo)
  ((^git -C $repo status --porcelain | str trim) == "")
}

def dotfiles-maint-current-rev [] {
  let repo = (dotfiles-maint-repo)
  ^git -C $repo rev-parse HEAD | str trim
}

def dotfiles-maint-pull [] {
  let repo = (dotfiles-maint-repo)
  print "Updating local checkout with git pull --ff-only..."
  with-env (dotfiles-maint-config) {
    ^git -C $repo pull --ff-only
  }
}

def dotfiles-maint-derivation-matches [derivation: string markers: list<string>] {
  $markers | where {|marker| $derivation | str contains $marker }
}

def dotfiles-maint-dry-run [attr: string markers: list<string>] {
  let tmp = (^mktemp "/tmp/maint-dry-run.XXXXXX" | str trim)
  let code_file = (^mktemp "/tmp/maint-dry-run-code.XXXXXX" | str trim)
  let nix_options = (dotfiles-maint-nix-options)

  with-env (dotfiles-maint-config) {
    ^bash -lc 'attr="$1"; out="$2"; code="$3"; shift 3; nix build "$@" --dry-run -L "$attr" 2>&1 | tee "$out"; printf "%s" "${PIPESTATUS[0]}" > "$code"' bash $attr $tmp $code_file ...$nix_options
  }

  let exit_code = (open --raw $code_file | str trim | into int)
  let output = (open --raw $tmp)
  let built = ($output | str contains "will be built")
  let built_derivations = (
    $output
    | lines
    | each {|line| $line | str trim }
    | where {|line| ($line | str starts-with "/nix/store/") and ($line | str ends-with ".drv") }
  )
  let built_derivation_text = ($built_derivations | str join "\n")
  let matched_markers = (
    $markers
    | where {|marker| $built_derivation_text | str contains $marker }
  )
  let allowed_markers = (dotfiles-maint-allowed-local-build-markers)
  let allowed_direct_fetch_markers = (dotfiles-maint-allowed-direct-fetch-markers)
  let direct_fetch_derivations = (
    $built_derivations
    | where {|derivation| not (dotfiles-maint-derivation-matches $derivation $allowed_direct_fetch_markers | is-empty) }
  )
  let blocked_derivations = (
    $built_derivations
    | where {|derivation|
      (dotfiles-maint-derivation-matches $derivation $allowed_markers | is-empty)
        and (dotfiles-maint-derivation-matches $derivation $allowed_direct_fetch_markers | is-empty)
    }
  )
  let result = {
    exitCode: $exit_code
    built: $built
    builtDerivations: $built_derivations
    matchedMarkers: $matched_markers
    directFetchDerivations: $direct_fetch_derivations
    blockedDerivations: $blocked_derivations
    output: $output
  }

  rm -f $tmp $code_file
  $result
}

def dotfiles-maint-print-dry-run-summary [label: string result: record] {
  print ""
  print $"---- ($label) dry-run summary ----"
  print $"exit_code: ($result.exitCode)"
  if ($result.matchedMarkers | is-empty) {
    print "blocking markers: none detected"
  } else {
    print $"blocking markers: (($result.matchedMarkers | str join ', '))"
  }

  if (($result.blockedDerivations? | default []) | is-empty) {
    print "blocked local derivations: none detected"
  } else {
    print "blocked local derivations:"
    $result.blockedDerivations | first 20 | each {|derivation| print $"  ($derivation)" }
  }

  if (($result.directFetchDerivations? | default []) | is-empty) {
    print "declared direct fetches: none detected"
  } else {
    print "declared direct fetches:"
    $result.directFetchDerivations | first 20 | each {|derivation| print $"  ($derivation)" }
  }

  let has_direct_fetch = (not (($result.directFetchDerivations? | default []) | is-empty))
  if $result.exitCode != 0 {
    print "summary: dry-run failed; inspect the output above."
  } else if (not ($result.matchedMarkers | is-empty)) or (not (($result.blockedDerivations? | default []) | is-empty)) {
    print "summary: heavy or unapproved local builds detected; not switching."
  } else if $has_direct_fetch {
    print "summary: only approved glue builds or declared direct fetches detected; continuing through the maintenance proxy."
  } else if $result.built {
    print "summary: only unblocked local build steps detected; continuing."
  } else {
    print "summary: no `will be built` detected; cache coverage looks good."
  }
}

def dotfiles-maint-gate-current-system [] {
  let attr = (dotfiles-maint-toplevel-attr)
  let result = (dotfiles-maint-dry-run $attr (dotfiles-maint-risk-markers))
  dotfiles-maint-print-dry-run-summary "current system" $result

  if $result.exitCode != 0 {
    error make { msg: "Current system dry-run failed; not switching." }
  }

  if not ($result.matchedMarkers | is-empty) {
    error make {
      msg: $"Current system would build blocked derivations: (($result.matchedMarkers | str join ', '))"
    }
  }

  if not (($result.blockedDerivations? | default []) | is-empty) {
    error make {
      msg: $"Current system would build unapproved local derivations: (($result.blockedDerivations | first 5 | str join ', '))"
    }
  }

  if (not (($result.directFetchDerivations? | default []) | is-empty)) and (not (dotfiles-maint-has-proxy-env)) {
    error make {
      msg: "Current system needs declared direct release fetches, but no maintenance proxy is configured."
    }
  }
}

def dotfiles-maint-build-toplevel [attr: string] {
  let nix_options = (dotfiles-maint-nix-options)
  with-env (dotfiles-maint-config) {
    ^nix build ...$nix_options --print-out-paths --no-link $attr | str trim
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

# Daily local entry point: consume the already-reviewed main branch state, gate it
# against the machine's cache policy, then activate one complete system closure.
def maint-switch [--no-pull] {
  if not (dotfiles-maint-repo-clean) {
    error make { msg: "Repository has local changes; commit or stash them before maint-switch." }
  }

  let before = (dotfiles-maint-current-rev)
  if not $no_pull {
    dotfiles-maint-pull
  }

  if not (dotfiles-maint-repo-clean) {
    error make { msg: "Repository has local changes after pull; resolve them before maint-switch." }
  }

  let after = (dotfiles-maint-current-rev)
  if $before != $after {
    print $"Updated checkout: ($before) -> ($after)"
  }

  dotfiles-maint-gate-current-system

  let attr = (dotfiles-maint-toplevel-attr)

  print "Building target system closure..."
  let target = (dotfiles-maint-build-toplevel $attr)
  let risk = (dotfiles-maint-switch-risk $target)

  if $risk.requiresBoot {
    print "Detected runtime-sensitive changes; using boot activation instead of hot switch."
    if $risk.kernelChanged { print "risk: booted kernel differs from target kernel" }
    if $risk.nvidiaChanged { print "risk: NVIDIA userspace differs from current system" }
    print "Next step after this finishes: reboot into the new generation."
    ^sudo nixos-rebuild --no-reexec boot --store-path $target
  } else {
    ^sudo nixos-rebuild --no-reexec switch --store-path $target
  }
}
