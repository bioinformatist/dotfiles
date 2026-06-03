$env.config = {
  show_banner: false,
  buffer_editor: "hx",
}

$env.EDITOR = "hx"
$env.VISUAL = "hx"
$env.SOPS_AGE_KEY_FILE = ("~/.config/sops/age/keys.txt" | path expand)

# Jump to the D2R mods directory.
def --env d2r-mods [] {
  let d2r_results = (glob ($env.HOME + "/.local/share/Steam/steamapps/compatdata/*/pfx/drive_c/Program Files \\(x86\\)/Diablo II Resurrected"))
  if ($d2r_results | is-empty) {
    error make { msg: "D2R install not found under compatdata" }
  }
  cd (($d2r_results | first) + "/mods")
}

# Print the installed Battle.net launcher path inside the Proton prefix.
def d2r-bnet [] {
  let bnet_results = (glob ($env.HOME + "/.local/share/Steam/steamapps/compatdata/*/pfx/drive_c/Program Files \\(x86\\)/Battle.net/Battle.net.exe"))
  if ($bnet_results | is-empty) {
    error make { msg: "Battle.net.exe not found under Steam compatdata" }
  }
  $bnet_results | first
}

# Print Steam shortcut fields for the installed Battle.net launcher.
def d2r-bnet-steam [] {
  let target = (d2r-bnet)
  {
    target: ('"' + $target + '"')
    start_in: ('"' + ($target | path dirname) + '"')
  }
}

# Run a Diablo II Resurrected mod .bat script inside the D2R Proton prefix.
# Usage: d2r-bat "<filename>.bat"   (from a mod directory, or relative to D2R's mods/ directory)
# Auto-discovers the Proton prefix and the wine binary bundled with proton-ge-bin.
# Note: scripts ending with "pause" will wait for Enter — press it to exit.
def d2r-bat [bat: string] {
  # 1. Locate D2R install dir inside any compatdata prefix
  let d2r_results = (glob ($env.HOME + "/.local/share/Steam/steamapps/compatdata/*/pfx/drive_c/Program Files \\(x86\\)/Diablo II Resurrected"))
  if ($d2r_results | is-empty) {
    error make { msg: "D2R install not found under ~/.local/share/Steam/steamapps/compatdata/*/pfx/drive_c/Program Files (x86)/" }
  }
  let d2r = ($d2r_results | first)

  # Derive WINEPREFIX (…/compatdata/<ID>/pfx)
  let prefix = ($d2r | path dirname | path dirname | path dirname)

  # 2. Locate wine binary shipped inside proton-ge-bin's steamcompattool output.
  #    glob can traverse /nix/store top-level but not subdirs, so find the dir first.
  let wine_results = (glob "/nix/store/*-proton-ge-bin-*steamcompattool*" | sort)
  if ($wine_results | is-empty) {
    error make { msg: "proton-ge-bin wine binary not found in nix store. Is programs.steam.extraCompatPackages set?" }
  }
  let wine = ($wine_results | last) + "/files/bin/wine"

  let mods_dir = ($d2r + "/mods")
  let cwd = (pwd)
  let bat_from_mod_dir = (
    ($cwd | str starts-with ($mods_dir + "/"))
    and not ($bat | str contains "/")
    and not ($bat | str contains "\\")
  )
  let bat_arg = if $bat_from_mod_dir {
    (($cwd | str substring (($mods_dir | str length) + 1)..) + "/" + $bat)
  } else {
    $bat
  }

  # 3. Run the .bat from the mods/ directory (cwd is mapped to Wine's cwd,
  #    avoiding cmd.exe path parsing issues with Chinese chars / fullwidth brackets).
  cd $mods_dir
  with-env { WINEPREFIX: $prefix } {
    ^steam-run $wine cmd.exe /c $bat_arg
  }
}

def dotfiles-maint-repo [] {
  "/home/ysun/github.com/bioinformatist/dotfiles"
}

def dotfiles-maint-host [] {
  "homePC"
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

def dotfiles-maint-fetch-github-release [repo_slug: string] {
  let release_json = (with-env (dotfiles-maint-config) {
    ^curl -L --fail --silent --show-error --connect-timeout 10 --max-time 30 -H "Accept: application/vnd.github+json" -H "User-Agent: dotfiles-maint-update-tools" $"https://api.github.com/repos/($repo_slug)/releases/latest"
  })

  $release_json | from json
}

def dotfiles-maint-github-release-asset-hash [release: record asset_name: string] {
  let assets = ($release.assets | where name == $asset_name)
  if ($assets | is-empty) {
    error make { msg: $"Could not find ($asset_name) in the latest release." }
  }

  let asset = ($assets | first)
  let digest = ($asset.digest? | default "")
  if not ($digest | str starts-with "sha256:") {
    error make { msg: $"Could not find a sha256 digest for ($asset_name)." }
  }

  let digest_hex = ($digest | str replace "sha256:" "")
  ^nix hash convert --hash-algo sha256 --from base16 --to sri $digest_hex | str trim
}

def dotfiles-maint-refresh-codex [] {
  let repo = (dotfiles-maint-repo)
  let codex_file = ($repo | path join "home" "programs" "codex" "default.nix")
  let codex_asset = "codex-x86_64-unknown-linux-musl.tar.gz"

  print "Refreshing Codex from the official OpenAI release binary..."
  print "Fetching latest Codex release metadata..."
  let release = (dotfiles-maint-fetch-github-release "openai/codex")
  let version = ($release.tag_name | str replace "rust-v" "")
  print $"Using GitHub release digest for ($codex_asset) at Codex ($version)."
  let hash = (dotfiles-maint-github-release-asset-hash $release $codex_asset)

  let old = (open --raw $codex_file)
  let new = (
    $old
    | str replace -r 'codexVersion = "[^"]+";' $'codexVersion = "($version)";'
    | str replace -r 'hash = "sha256-[^"]+";' $'hash = "($hash)";'
  )

  if $new == $old {
    print $"codex is already pinned at version ($version)."
  } else {
    $new | save -f $codex_file
    print $"Updated codex to version ($version)."
  }
}

def dotfiles-maint-refresh-zeroclaw [] {
  let repo = (dotfiles-maint-repo)
  let zeroclaw_file = ($repo | path join "home" "programs" "zeroclaw" "default.nix")
  let zeroclaw_asset = "zeroclaw-x86_64-unknown-linux-gnu.tar.gz"

  print "Refreshing ZeroClaw from the official release binary..."
  print "Fetching latest ZeroClaw release metadata..."
  let release = (dotfiles-maint-fetch-github-release "zeroclaw-labs/zeroclaw")
  let version = ($release.tag_name | str replace "v" "")
  print $"Using GitHub release digest for ($zeroclaw_asset) at ZeroClaw ($version)."
  let hash = (dotfiles-maint-github-release-asset-hash $release $zeroclaw_asset)

  let old = (open --raw $zeroclaw_file)
  let new = (
    $old
    | str replace -r 'zeroclawVersion = "[^"]+";' $'zeroclawVersion = "($version)";'
    | str replace -r 'hash = "sha256-[^"]+";' $'hash = "($hash)";'
  )

  if $new == $old {
    print $"zeroclaw is already pinned at version ($version)."
  } else {
    $new | save -f $zeroclaw_file
    print $"Updated zeroclaw to version ($version)."
  }
}

# Update binary-friendly tool inputs and refresh the Codex and ZeroClaw
# official release binary pins. TUI and proxy tools follow nixpkgs-tools so
# they can move without rolling the base system. Yazelix is intentionally kept
# out of the routine path because its main branch can require local Rust builds.
def maint-update-tools [] {
  print "Updating binary-friendly tool inputs..."
  dotfiles-maint-lock-update [
    "anyrun"
    "nixpkgs-tools"
    "nixpkgs-wechat"
  ]
  dotfiles-maint-refresh-codex
  dotfiles-maint-refresh-zeroclaw
  print "Tool-layer updates applied to flake.lock and release-pinned tool packages."
}

# Update low-frequency infrastructure inputs. These may build local helpers, so
# keep them out of the routine tool path.
def maint-update-infra [] {
  dotfiles-maint-lock-update [
    "sops-nix"
    "impermanence"
    "disko"
  ]
}

# Update Hyprland separately from nixpkgs.
def maint-update-hyprland [] {
  dotfiles-maint-lock-update [ "hyprland" ]
}

# Update the system base separately from Hyprland.
def maint-update-base [] {
  dotfiles-maint-lock-update [ "nixpkgs" "home-manager" ]
}

# Run a dry-run and summarize whether rebuilding is advisable.
def maint-check [] {
  let attr = (dotfiles-maint-toplevel-attr)
  let tmp = (^mktemp "/tmp/maint-check.XXXXXX" | str trim)
  let code_file = (^mktemp "/tmp/maint-check-code.XXXXXX" | str trim)

  with-env (dotfiles-maint-config) {
    ^bash -lc 'nix build --dry-run -L "$1" 2>&1 | tee "$2"; printf "%s" "${PIPESTATUS[0]}" > "$3"' bash $attr $tmp $code_file
  }

  let exit_code = (open --raw $code_file | str trim | into int)
  let output = (open --raw $tmp)

  let built = ($output | str contains "will be built")
  let risk_markers = (
    [
      "nvidia-x11"
      "linux-"
      "hyprland"
      "hyprlang"
      "hyprutils"
      "hyprgraphics"
      "hyprwayland-scanner"
      "hyprwire"
    ]
    | where {|marker| $output | str contains $marker }
  )

  print ""
  print "---- maint-check summary ----"
  print $"exit_code: ($exit_code)"

  if ($risk_markers | is-empty) {
    print "risk markers: none detected"
  } else {
    print $"risk markers: (($risk_markers | str join ', '))"
  }

  if $exit_code != 0 {
    print "summary: dry-run failed; inspect the output above before running maint-switch."
  } else if $built {
    print "summary: detected `will be built`; do not run maint-switch yet."
  } else {
    print "summary: no `will be built` detected; you may continue with maint-switch."
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
