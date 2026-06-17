{ pkgs, ... }:

{
  imports = [
    ../../home/shell/headless.nix
  ];

  home.packages = [
    pkgs.gh
  ];
}
