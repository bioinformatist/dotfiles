{ inputs }:

{ pkgs, ... }:

{
  imports = [
    ./anyrun
    ./ghostty
    ./hyprland
    (import ./noctalia.nix { inherit inputs; })
  ];

  programs.ghostty.package = inputs.ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default;

  wayland.windowManager.hyprland = {
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };
}
