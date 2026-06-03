{ yazelix }:

{ pkgs, ... }:

{
  imports = [
    yazelix.homeManagerModules.default
  ];

  programs.yazelix = {
    enable = true;
    package = yazelix.packages.${pkgs.stdenv.hostPlatform.system}.yazelix_ghostty;
    runtime_variant = "ghostty";
  };
}
