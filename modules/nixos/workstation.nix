{ inputs }:
{ pkgs, ... }@moduleArgs:
{
  imports = [
    (import ../../nixos/desktop.nix (moduleArgs // { inherit inputs pkgs; }))
    ../../nixos/workstation-audio.nix
  ];
}
