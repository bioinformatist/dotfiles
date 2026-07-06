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
