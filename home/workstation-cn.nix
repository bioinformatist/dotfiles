{ inputs }:

{
  pkgs,
  yazelix ? inputs.yazelix,
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
    (import ./tui/yazelix {
      inherit yazelix;
    })
    ./desktop
    (import ./programs/workstation-cn.nix { inherit inputs; })
  ];

  xdg.enable = true;

  programs = {
    yazi.package = toolPkgs.yazi;
    zellij.package = toolPkgs.zellij;
    helix.package = toolPkgs.helix;
  };
}
