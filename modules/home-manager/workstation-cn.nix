{ inputs }:

{
  imports = [
    (import ../../home/workstation-cn.nix { inherit inputs; })
  ];
}
