{
  pkgs,
  ...
}:
{
  imports = [
    ./workstation-common.nix
    ../../home/programs/gaming.nix
    ../../home/programs/zeroclaw
  ];

  dotfiles.hyprland.noHardwareCursors = true;
  dotfiles.eww.d2r.enable = true;

  home.packages = [
    pkgs.orca-ide
  ];
}
