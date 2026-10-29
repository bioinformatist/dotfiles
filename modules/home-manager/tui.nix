{ inputs }:

{ pkgs, ... }:

{
  imports = [
    ../../home/tui
  ];

  programs = {
    yazi.package = pkgs.yazi;
    helix.package = pkgs.helix;
  };
}
