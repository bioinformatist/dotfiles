{ inputs }:

{ pkgs, ... }:

let
  tuiToolPkgs = inputs.nixpkgs-tools.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    ../../home/tui
  ];

  programs = {
    yazi.package = tuiToolPkgs.yazi;
    helix.package = tuiToolPkgs.helix;
  };
}
