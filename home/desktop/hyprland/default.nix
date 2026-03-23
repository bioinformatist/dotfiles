{
  lib,
  pkgs,
  isVM ? false,
  ...
}:
{
  xdg.configFile = {
    "hypr/scripts" = {
      source = ./scripts;
      recursive = true;
    };
    "hypr/wallpapers" = {
      source = ./wallpapers;
      recursive = true;
    };
  };

  # Ensure monitors.conf exists before Hyprland parses `source = monitors.conf`.
  # This must be a real writable file (not xdg.configFile symlink) because
  # nwg-displays writes to it. Impermanence persists it across reboots.
  home.activation.ensureMonitorsConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    touch "$HOME/.config/hypr/monitors.conf"
  '';

  wayland.windowManager.hyprland = {
    systemd.enable = false;
    enable = true;
    extraConfig = builtins.readFile ./hyprland.conf;
    settings = lib.mkIf isVM {
      debug.damage_tracking = 0;
    };
  };
}
