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

  # Elegant Service Management via Systemd
  systemd.user.services = {
    swww-daemon = {
      Unit = {
        Description = "SWWW Wallpaper Daemon";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.swww}/bin/swww-daemon --no-cache";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    wallpaper-randomizer = {
      Unit = {
        Description = "Wallpaper Randomizer Script";
        Requires = [ "swww-daemon.service" ];
        After = [ "swww-daemon.service" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "%h/.config/hypr/scripts/swww_randomize_multi";
        Restart = "on-failure";
        Type = "simple";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
