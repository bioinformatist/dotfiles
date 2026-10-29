{ inputs }:

{
  pkgs,
  ...
}:

{
  imports = [
    ./core.nix
    ./shell
    ./tui
    (import ./desktop { inherit inputs; })
    (import ./programs/workstation.nix { inherit inputs; })
  ];

  xdg.enable = true;

  programs = {
    yazi.package = pkgs.yazi;
    helix.package = pkgs.helix;
  };
}
