{ inputs }:

{ pkgs, lib, ... }:

let
  tuiToolPkgs = inputs.nixpkgs-tools.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    ../../home/tui
  ];

  programs = {
    yazi.package = lib.mkDefault tuiToolPkgs.yazi;
    helix.package = lib.mkDefault tuiToolPkgs.helix;
  };
}
