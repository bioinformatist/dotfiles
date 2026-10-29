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
    # Ensure monitors.conf exists before Hyprland parses `source = monitors.conf`.
    # This must be a real writable file (not xdg.configFile symlink) because
    # nwg-displays writes to it. Impermanence persists it across reboots.
    home.activation.ensureMonitorsConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      touch "$HOME/.config/hypr/monitors.conf"
    '';

    wayland.windowManager.hyprland = {
      systemd.enable = false;
      enable = true;
      configType = "hyprlang";
      extraConfig =
        builtins.readFile ./hyprland.conf
        + "\nexec-once = ${lib.getExe config.programs.noctalia.package}\n"
        + lib.optionalString cfg.rightAltCompose ''

          # Keep the US layout while enabling Compose sequences for accents.
          input {
              kb_options = compose:ralt
          }
        ''
        + lib.optionalString cfg.noHardwareCursors ''

          # NVIDIA: software-rendered cursor avoids hardware cursor flicker caused
          # by DRM page-flip timing races. Perf impact is negligible.
          cursor {
              no_hardware_cursors = true
          }
        '';
    };
  };
}
