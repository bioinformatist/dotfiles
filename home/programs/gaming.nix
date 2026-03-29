# Gaming — Steam + Proton-GE + GameMode
# Declarative gaming setup for Battle.net / D2R via Steam + Proton.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    protontricks    # Helper for Proton prefix management
    gamemode        # Feral GameMode — CPU governor + nice level optimization
  ];
  # Proton-GE is declared in configuration.nix via programs.steam.extraCompatPackages.
  # The NixOS Steam module handles Steam integration automatically.
}
