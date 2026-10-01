{ inputs }:

{
  imports = [
    ./anyrun
    ./ghostty
    ./hyprland
    (import ./noctalia.nix { inherit inputs; })
  ];
}
