{ inputs }:

{
  imports = [
    (import ./anyrun { inherit inputs; })
    ./ghostty
    ./hyprland
    (import ./noctalia.nix { inherit inputs; })
  ];
}
