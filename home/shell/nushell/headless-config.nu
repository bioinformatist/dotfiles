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

def maint-repo [] {
  if "DOTFILES_MAINT_REPO" in $env {
    $env.DOTFILES_MAINT_REPO
  } else {
    error make { msg: "DOTFILES_MAINT_REPO is not set for maint-* commands." }
  }
}

def maint-host [] {
  if "DOTFILES_MAINT_HOST" in $env {
    $env.DOTFILES_MAINT_HOST
  } else {
    error make { msg: "DOTFILES_MAINT_HOST is not set for maint-* commands." }
  }
}

def maint-config-file [] {
  if "DOTFILES_MAINT_PROXY_CONFIG" in $env {
    $env.DOTFILES_MAINT_PROXY_CONFIG
  } else {
    ($env.HOME | path join ".config" "nix" "local-proxy.nuon")
  }
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

def maint-refresh-codex [] {
  let repo = (maint-repo)
  let codex_file = ($repo | path join "home" "programs" "codex" "default.nix")
  let codex_asset = "codex-x86_64-unknown-linux-musl.tar.gz"

  print "Refreshing codex release pin..."

  print "Fetching latest Codex release metadata..."
  let release_json = (with-env (maint-config) {
    ^curl -L --fail --silent --show-error --connect-timeout 10 --max-time 30 -H "Accept: application/vnd.github+json" -H "User-Agent: dotfiles-maint-update-tools" "https://api.github.com/repos/openai/codex/releases/latest"
  })
  let release = ($release_json | from json)

  let version = ($release.tag_name | str replace "rust-v" "")
  let assets = ($release.assets | where name == $codex_asset)
  if ($assets | is-empty) {
    error make { msg: $"Could not find ($codex_asset) in the latest Codex release." }
  }

  let asset = ($assets | first)
  let digest = ($asset.digest? | default "")
  if not ($digest | str starts-with "sha256:") {
    error make { msg: $"Could not find a sha256 digest for ($codex_asset) in the latest Codex release." }
  }

  print $"Using GitHub release digest for ($codex_asset) at Codex ($version)."
  let digest_hex = ($digest | str replace "sha256:" "")
  let hash = (^nix hash convert --hash-algo sha256 --from base16 --to sri $digest_hex | str trim)

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

def maint-check [] {
  let repo = (maint-repo)
  let host = (maint-host)
  let attr = $"($repo)#nixosConfigurations.($host).config.system.build.toplevel"
  let tmp = (^mktemp "/tmp/maint-check.XXXXXX" | str trim)
  let code_file = (^mktemp "/tmp/maint-check-code.XXXXXX" | str trim)

  with-env (maint-config) {
    ^bash -lc 'nix build --dry-run -L "$1" 2>&1 | tee "$2"; printf "%s" "${PIPESTATUS[0]}" > "$3"' bash $attr $tmp $code_file
  }

  let exit_code = (open --raw $code_file | str trim | into int)
  let output = (open --raw $tmp)

  let built = ($output | str contains "will be built")

  print ""
  print "---- maint-check summary ----"
  print $"exit_code: ($exit_code)"

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
