{
  yazelix,
  yazelixPkgs,
}:

{ lib, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [
    yazelix.homeManagerModules.default
  ];

  _module.args.mkYazelixPackage = lib.mkForce (
    args:
    yazelix.lib.${system}.mkYazelix (
      args
      // {
        pkgs = yazelixPkgs;
      }
    )
  );

  programs.yazelix = {
    enable = true;
    terminal = "ghostty";
  };
}
