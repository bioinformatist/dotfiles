{
  inputs ? null,
  pkgs,
  yazelix ? inputs.yazelix,
  ...
}:

let
  toolPkgs =
    if inputs != null && inputs ? nixpkgs-tools then
      inputs.nixpkgs-tools.legacyPackages.${pkgs.stdenv.hostPlatform.system}
    else
      pkgs;
in
{
  imports = [
    ./core.nix
    ./shell
    ./tui
    (import ./tui/yazelix { inherit yazelix; })
    ./desktop
    ./programs/workstation-cn.nix
  ];

  xdg.enable = true;

  programs = {
    yazi.package = toolPkgs.yazi;
    zellij.package = toolPkgs.zellij;
    helix.package = toolPkgs.helix;
  };
}
