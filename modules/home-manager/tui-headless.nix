{ inputs }:

{ pkgs, lib, ... }:

{
  imports = [
    ../../home/tui
  ];

  programs = {
    yazi.package = lib.mkDefault pkgs.yazi;
    helix.package = lib.mkDefault pkgs.helix;
  };
}
