{ inputs }:
{ pkgs, ... }@moduleArgs:
{
  imports = [
    ./headless.nix
    ../nixos/china-network.nix
    ../nixos/proxy.nix
    (import ../nixos/desktop.nix (moduleArgs // { inherit inputs pkgs; }))
    ../nixos/workstation-audio.nix
  ];
}
