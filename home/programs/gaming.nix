# Gaming — Steam + Proton-GE + GameMode
# Declarative gaming setup for Battle.net / D2R via Steam + Proton.
#
# Battle.net must be launched from Steam (non-Steam game shortcut).
# Direct launch outside Steam's pressure-vessel container is unreliable
# on NixOS + NVIDIA + Wayland (GLX BadAlloc, missing runtime libraries).
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    protontricks    # Helper for Proton prefix management
    gamemode        # Feral GameMode — CPU governor + nice level optimization
  ];

  # Proton-GE is declared in configuration.nix via programs.steam.extraCompatPackages.
  # The NixOS Steam module handles Steam integration automatically.

  # TODO: systray architecture (deferred)
  # When tray interaction is needed (Clash Verge, Telegram, WeChat, or future Wine apps):
  #   1. Add (systray) widget to eww bar  — handles SNI protocol apps
  #   2. Autostart xembedsniproxy         — bridges Wine/XEMBED tray icons → SNI
  #   3. Hyprland window rule to hide the steam_app_0 floating helper window
  # See memory: project_systray.md
}
