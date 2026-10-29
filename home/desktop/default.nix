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
}
