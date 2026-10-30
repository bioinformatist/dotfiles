{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.hyprland;
in
{
  options.dotfiles.hyprland = {
    noHardwareCursors = lib.mkEnableOption "software-rendered Hyprland cursors";
    rightAltCompose = lib.mkEnableOption "Right Alt as the XKB Compose key";
  };

  config = {
    # nwg-displays needs a writable layout; never replace an existing one.
    home.activation.ensureMonitorsLua = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      hypr_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
      mkdir -p "$hypr_dir"
      if [ ! -e "$hypr_dir/monitors.lua" ]; then
        touch "$hypr_dir/monitors.lua"
      fi
    '';

    wayland.windowManager.hyprland = {
      systemd.enable = false;
      enable = true;
      configType = "lua";
      extraConfig =
        builtins.readFile ./hyprland.lua
        + ''

          hl.on("hyprland.start", function()
              hl.exec_cmd("${lib.getExe config.programs.noctalia.package}")
          end)
        ''
        + lib.optionalString cfg.rightAltCompose ''

          hl.config({ input = { kb_options = "compose:ralt" } })
        ''
        + lib.optionalString cfg.noHardwareCursors ''

          -- Avoid NVIDIA hardware cursor flicker from DRM page-flip timing races.
          hl.config({ cursor = { no_hardware_cursors = true } })
        '';
    };
  };
}
