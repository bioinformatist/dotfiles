{ inputs }:

{ ... }:
{
  imports = [
    ../../home/core.nix
    (import ./headless-dev-tools.nix { inherit inputs; })
  ];
}
