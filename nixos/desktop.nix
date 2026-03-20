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

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      qt6Packages.fcitx5-chinese-addons
    ];
  };

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
