{ inputs }:
{ pkgs, ... }@moduleArgs:
{
  imports = [
    ../../nixos/china-network.nix
    ../../nixos/proxy.nix
    (import ../../nixos/desktop.nix (moduleArgs // { inherit inputs pkgs; }))
    ../../nixos/workstation-audio.nix
  ];
}
