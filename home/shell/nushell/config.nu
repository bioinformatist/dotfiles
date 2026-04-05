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

# d2r-mods: jump to the D2R mods directory.
def --env d2r-mods [] {
  let d2r_results = (glob ($env.HOME + "/.local/share/Steam/steamapps/compatdata/*/pfx/drive_c/Program Files \\(x86\\)/Diablo II Resurrected"))
  if ($d2r_results | is-empty) {
    error make { msg: "D2R install not found under compatdata" }
  }
  cd (($d2r_results | first) + "/mods")
}

# d2r-bat: run a Diablo II Resurrected mod .bat script inside the D2R Proton prefix.
# Usage: d2r-bat "<filename>.bat"   (file name relative to D2R's mods/ directory)
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

  # 3. Run the .bat from the mods/ directory (cwd is mapped to Wine's cwd,
  #    avoiding cmd.exe path parsing issues with Chinese chars / fullwidth brackets).
  cd ($d2r + "/mods")
  with-env { WINEPREFIX: $prefix } {
    ^steam-run $wine cmd.exe /c $bat
  }
}