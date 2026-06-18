{ inputs }:

{
  imports = [
    (import ../../home/workstation.nix { inherit inputs; })
  ];
}
