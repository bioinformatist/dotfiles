{
  pkgs,
  ...
}:
{
  imports = [
    ./workstation-common.nix
    ../../home/programs/gaming.nix
  ];

  dotfiles.hyprland.noHardwareCursors = false;

  home.packages = [
    pkgs.orca-ide
  ];
}
