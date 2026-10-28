def dotfiles-maint-config-dir [] {
  ($env.XDG_CONFIG_HOME? | default ($env.HOME | path join ".config")) | path join "dotfiles"
}

def dotfiles-maint-settings-file [] {
  dotfiles-maint-config-dir | path join "maint.nuon"
}

def dotfiles-maint-settings [] {
  let settings_file = (dotfiles-maint-settings-file)
  if not ($settings_file | path exists) {
    error make { msg: $"Maintenance settings not found: ($settings_file)" }
  }

  open $settings_file
}

def dotfiles-maint-repo [] {
  let override = ($env | get -o DOTFILES_MAINT_REPO | default "")
  if $override != "" {
    $override
  } else {
    (dotfiles-maint-settings).repo
  }
}

def dotfiles-maint-host [] {
  (dotfiles-maint-settings).host
}

def dotfiles-maint-policy [] {
  let repo = (dotfiles-maint-repo)
  let policy_attr = $"($repo)#lib.maintenancePolicy"
  let result = (with-env (dotfiles-maint-config) {
    ^nix eval --json --no-write-lock-file $policy_attr | complete
  })
  if $result.exit_code != 0 {
    error make { msg: $"Maintenance policy evaluation failed: ($result.stderr)" }
  }
  $result.stdout | from json
}

def dotfiles-maint-list-setting [policy: record, name: string, extra_name: string] {
  let settings = (dotfiles-maint-settings)
  let policy_values: list<string> = ($policy | get $name)
  let extra_values: list<string> = ($settings | get -o $extra_name | default [])
  $policy_values | append $extra_values | uniq
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
  [
    ($proxy_env.HTTP_PROXY? | default "")
    ($proxy_env.HTTPS_PROXY? | default "")
    ($proxy_env.ALL_PROXY? | default "")
    ($proxy_env.http_proxy? | default "")
    ($proxy_env.https_proxy? | default "")
    ($proxy_env.all_proxy? | default "")
  ] | any {|value| $value != "" }
}

def dotfiles-maint-risk-markers [policy: record] {
  dotfiles-maint-list-setting $policy "riskMarkers" "extraRiskMarkers"
}

def dotfiles-maint-allowed-local-build-markers [policy: record] {
  dotfiles-maint-list-setting $policy "allowedLocalBuildMarkers" "extraAllowedLocalBuildMarkers"
}

def dotfiles-maint-allowed-direct-fetch-markers [policy: record] {
  dotfiles-maint-list-setting $policy "allowedDirectFetchMarkers" "extraAllowedDirectFetchMarkers"
}

def dotfiles-maint-parallel [] {
  (dotfiles-maint-settings).parallel? | default {
    maxJobs: 4
    cores: 2
  }
}

def dotfiles-maint-nix-options [] {
  let parallel = (dotfiles-maint-parallel)
  mut args = ["--option" "fallback" "false" "--no-write-lock-file"]

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

def dotfiles-maint-dry-run [attr: string, policy: record] {
  let config_dir = (dotfiles-maint-config-dir)
  let parser = ($config_dir | path join "nix-plan.jq")
  let classifier = ($config_dir | path join "classify-plan.jq")
  for helper in [$parser $classifier] {
    if not ($helper | path exists) {
      error make { msg: $"Maintenance helpers not ready: ($helper) is missing." }
    }
  }
  let nix_options = (dotfiles-maint-nix-options)
  let root = (with-env (dotfiles-maint-config) {
    ^nix eval --raw --no-write-lock-file $"($attr).drvPath" | complete
  })
  if $root.exit_code != 0 {
    error make { msg: $"Maintenance root evaluation failed: ($root.stderr)" }
  }
  let dry = (with-env (dotfiles-maint-config) {
    ^nix build ...$nix_options --dry-run --json --log-format internal-json --no-link --impure --option allow-import-from-derivation false $attr | complete
  })
  if $dry.exit_code != 0 {
    error make { msg: $"Current daemon dry-run failed; not switching. ($dry.stderr)" }
  }
  let parsed = ($dry.stderr | ^jq -R -s --argjson outputs $dry.stdout --argjson expected ([($root.stdout | str trim)] | to json --raw) -f $parser | complete)
  if $parsed.exit_code != 0 {
    error make { msg: $"Nix plan is unparseable; not switching. ($parsed.stderr) ($dry.stderr)" }
  }
  let plan = ($parsed.stdout | from json)
  if not $plan.complete {
    error make { msg: $"Nix roots or plan are incomplete; not switching. ($dry.stderr)" }
  }
  let classified = ({plan: $plan, policy: $policy, leaf: ""} | to json --raw | ^jq -f $classifier | complete)
  if $classified.exit_code != 0 {
    error make { msg: $"Maintenance classification failed; not switching. ($classified.stderr)" }
  }
  let result = ($classified.stdout | from json)
  let blocked_text = ($result.blocked | str join "\n")
  $result | merge {
    builds: $plan.builds
    fetches: $plan.fetches
    matchedMarkers: ($policy.riskMarkers | where {|marker| $marker != "" and ($blocked_text | str contains $marker) })
    output: $dry.stderr
  }
}

def dotfiles-maint-print-dry-run-summary [result: record] {
  print ""
  print "---- current system dry-run summary ----"
  print $"builds: ($result.builds | length); fetches: ($result.fetches | length); blocked: ($result.blocked | length)"
  if not ($result.matchedMarkers | is-empty) {
    print $"blocking markers: ($result.matchedMarkers | str join ', ')"
  }
  for derivation in $result.blocked { print $"blocked: ($derivation)" }
  for derivation in $result.direct { print $"declared direct fetch: ($derivation)" }
  if ($result.output | str contains "ignoring untrusted substituter") or ($result.output | str contains "not a trusted user") {
    print "Cache trust boundary (#205): CI uses the target's keys; the running daemon may not trust them yet. Activate a cache-only transition through the normal maintenance path first; do not build with sudo. https://github.com/bioinformatist/dotfiles/issues/205"
  }
}

def dotfiles-maint-gate-current-system [] {
  let attr = (dotfiles-maint-toplevel-attr)
  let base = (dotfiles-maint-policy)
  let policy = ($base | merge {
    riskMarkers: (dotfiles-maint-risk-markers $base)
    allowedLocalBuildMarkers: (dotfiles-maint-allowed-local-build-markers $base)
    allowedDirectFetchMarkers: (dotfiles-maint-allowed-direct-fetch-markers $base)
  })
  let result = (dotfiles-maint-dry-run $attr $policy)
  dotfiles-maint-print-dry-run-summary $result

  if not ($result.blocked | is-empty) {
    error make {
      msg: $"Current daemon plan needs unapproved local builds; not switching: ($result.blocked | first 5 | str join ', ')"
    }
  }
  if (not ($result.direct | is-empty)) and (not (dotfiles-maint-has-proxy-env)) {
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
def maint-switch [--no-pull, --repo: string, --boot] {
  let repo_env = if $repo == null { {} } else { { DOTFILES_MAINT_REPO: $repo } }
  with-env $repo_env {
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

    if $boot {
      print "Boot-only activation requested; the running system will not be switched."
      print "Next step after this finishes: reboot into the new generation."
      ^sudo nixos-rebuild --no-reexec boot --store-path $target
    } else if $risk.requiresBoot {
      print "Detected runtime-sensitive changes; using boot activation instead of hot switch."
      if $risk.kernelChanged { print "risk: booted kernel differs from target kernel" }
      if $risk.nvidiaChanged { print "risk: NVIDIA userspace differs from current system" }
      print "Next step after this finishes: reboot into the new generation."
      ^sudo nixos-rebuild --no-reexec boot --store-path $target
    } else {
      ^sudo nixos-rebuild --no-reexec switch --store-path $target
    }
  }
}
