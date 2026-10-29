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

def dotfiles-maint-parallel [] {
  (dotfiles-maint-settings).parallel? | default {
    maxJobs: 4
    cores: 2
  }
}

def dotfiles-maint-nix-options [] {
  let parallel = (dotfiles-maint-parallel)
  mut args = ["--option" "fallback" "false" "--no-update-lock-file"]

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

def dotfiles-maint-build-toplevel [attr: string] {
  let nix_options = (dotfiles-maint-nix-options)
  let result = (with-env (dotfiles-maint-config) {
    ^nix build ...$nix_options --print-out-paths --no-link -L $attr err> /dev/stderr | complete
  })
  if $result.exit_code != 0 {
    error make { msg: $"System build failed with exit code ($result.exit_code); not activating." }
  }
  let targets = ($result.stdout | lines | str trim | where {|line| $line != "" })
  if ($targets | length) != 1 {
    error make { msg: "System build did not return exactly one target path; not activating." }
  }
  $targets | first
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

# Build the current checkout before activating its complete system closure.
def maint-switch [--repo: string, --boot] {
  let repo_env = if $repo == null { {} } else { { DOTFILES_MAINT_REPO: $repo } }
  with-env $repo_env {
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
    if $env.LAST_EXIT_CODE != 0 {
      error make { msg: $"System activation failed with exit code ($env.LAST_EXIT_CODE)." }
    }
  }
}
