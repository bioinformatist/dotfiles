$env.config = {
  show_banner: false,
  buffer_editor: "hx",
}

$env.EDITOR = "hx"
$env.VISUAL = "hx"
$env.SOPS_AGE_KEY_FILE = ("~/.config/sops/age/keys.txt" | path expand)