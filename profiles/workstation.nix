{ inputs }:
{ pkgs, ... }@moduleArgs:
{
  imports = [
    ./headless.nix
    (import ../nixos/desktop.nix (moduleArgs // { inherit inputs pkgs; }))
    ../nixos/workstation-audio.nix
  ];
}
