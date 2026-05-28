{ inputs }:

{ pkgs, ... }:

let
  tuiToolPkgs = inputs.nixpkgs-tools.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    ../../home/workstation-cn.nix
  ];

  _module.args = {
    inherit tuiToolPkgs;
    yazelix = inputs.yazelix;
  };
}
