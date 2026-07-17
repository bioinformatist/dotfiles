# Gaming — Steam + Proton-GE
# Declarative gaming setup for Battle.net / D2R via Steam + Proton.
#
# Battle.net must be launched from Steam (non-Steam game shortcut).
# Direct launch outside Steam's pressure-vessel container is unreliable
# on NixOS + NVIDIA + Wayland (GLX BadAlloc, missing runtime libraries).
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    protontricks # Helper for Proton prefix management
  ];

  # Proton-GE is declared in configuration.nix via programs.steam.extraCompatPackages.
  # The NixOS Steam module handles Steam integration automatically.

  # Noctalia renders an application's official StatusNotifierItem. Battle.net
  # appears only when the Wine application exports SNI; this configuration does
  # not add a speculative XEmbed bridge. D2R/Terror Zone bar content is also out
  # of scope; a future implementation belongs in a separate Noctalia v5 plugin.
}
