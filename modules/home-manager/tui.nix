{ inputs }:

{ pkgs, ... }:

let
  tuiToolPkgs = inputs.nixpkgs-tools.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    ../../home/tui
    (import ../../home/tui/yazelix { yazelix = inputs.yazelix; })
  ];

  programs = {
    yazi.package = tuiToolPkgs.yazi;
    zellij.package = tuiToolPkgs.zellij;
    helix.package = tuiToolPkgs.helix;
  };
}
