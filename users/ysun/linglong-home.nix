{
  pkgs,
  ...
}:
{
  imports = [
    ./workstation-common.nix
  ];

  dotfiles.hyprland.noHardwareCursors = false;

  home.packages = [
    pkgs.orca-ide
  ];
}
