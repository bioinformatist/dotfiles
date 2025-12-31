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
    settings = {
      cursor = {
        no_hardware_cursors = true;
      };
      env = [
        "NIXOS_OZONE_WL,1"
        "WLR_RENDERER_ALLOW_SOFTWARE,1"
      ];
    };
  };
}
