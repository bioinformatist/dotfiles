{ inputs }:

{
  pkgs,
  ...
}:

let
  toolPkgs = inputs.nixpkgs-tools.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    ./core.nix
    ./shell
    ./tui
    ./desktop
    (import ./programs/workstation.nix { inherit inputs; })
  ];

  xdg.enable = true;

  programs = {
    yazi.package = toolPkgs.yazi;
    zellij.package = toolPkgs.zellij;
    helix.package = toolPkgs.helix;
  };
}
