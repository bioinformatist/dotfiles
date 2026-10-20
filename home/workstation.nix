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
    (import ./desktop { inherit inputs; })
    (import ./programs/workstation.nix { inherit inputs; })
  ];

  xdg.enable = true;

  programs = {
    yazi.package = toolPkgs.yazi;
    helix.package = toolPkgs.helix;
  };
}
