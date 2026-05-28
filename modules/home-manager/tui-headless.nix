{ inputs }:

{
  imports = [
    (import ./tui.nix { inherit inputs; })
  ];
}
