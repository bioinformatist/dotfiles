{ inputs }:

{ pkgs, ... }:

{
  imports = [
    ./anyrun
    ./ghostty
    ./hyprland
    (import ./noctalia.nix { inherit inputs; })
  ];

  gtk = {
    enable = true;
    font = {
      name = "Sarasa UI SC";
      package = pkgs.sarasa-gothic;
      size = 11;
    };
  };

  programs.ghostty.package = inputs.ghostty.packages.${pkgs.stdenv.hostPlatform.system}.default;

  wayland.windowManager.hyprland = {
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };
}
