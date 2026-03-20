# Shared desktop environment configuration for all hosts.
# Covers Hyprland, GUI applications, input method, and proxy tools.

{
  inputs,
  pkgs,
  ...
}:

{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage =
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  # Portal configuration: add GTK portal as fallback for Screenshot interface.
  # WeChat calls org.freedesktop.portal.Screenshot via D-Bus, but the Hyprland
  # portal doesn't implement it. The GTK portal provides a working Screenshot
  # backend that captures via Wayland screencopy and returns the image to the
  # requesting app (WeChat), which then opens its own annotation editor.
  xdg.portal = {
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.hyprland = {
      default = [ "hyprland" "gtk" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
    };
  };

  programs.clash-verge = {
    enable = true;
    package = pkgs.clash-verge-rev;
  };

  programs.proxychains = {
    enable = true;
    quietMode = false;
    proxies.default = {
      enable = true;
      type = "socks5";
      host = "127.0.0.1";
      port = 7897;
    };
  };

  programs.nix-ld.enable = true;



  environment.systemPackages =
    with pkgs;
    [
      wl-clipboard
      git
      ghostty
      eww
      dunst
      google-chrome
      hyprlock
      wechat-uos
    grim # Wayland screenshot backend
    slurp # Wayland region selector
    satty # Screenshot annotation editor (arrows, text, blur)
    xclip # X11 clipboard bridge (for XWayland apps like WeChat)
    ]
    ++ [
      inputs.swww.packages.${pkgs.stdenv.hostPlatform.system}.swww
      inputs.antigravity.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
}
