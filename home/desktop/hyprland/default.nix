{
  lib,
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

  wayland.windowManager.hyprland = {
    systemd.enable = false;
    enable = true;
    extraConfig = builtins.readFile ./hyprland.conf;
    settings = lib.mkIf isVM {
      debug.damage_tracking = 0;
    };
  };
}
