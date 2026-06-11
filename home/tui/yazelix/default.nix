{
  yazelix,
}:

{ lib, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [
    yazelix.homeManagerModules.default
  ];

  # Keep Yazelix's runtime closure owned by the Yazelix flake, so downstream
  # hosts cannot perturb Yazelix cache keys with their own nixpkgs.
  _module.args.mkYazelixPackage = lib.mkForce (
    args:
    yazelix.lib.${system}.mkYazelix (
      builtins.removeAttrs args [
        "pkgs"
        "extraRuntimePackages"
      ]
      // lib.optionalAttrs ((args.extraRuntimePackages or null) == []) {
        extraRuntimePackages = [ ];
      }
    )
  );

  programs.yazelix = {
    enable = true;
    terminal = "ghostty";
  };
}
