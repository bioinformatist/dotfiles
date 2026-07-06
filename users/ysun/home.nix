{
  ...
}:
{
  imports = [
    ./workstation-common.nix
    ./d2r-eww
    ../../home/programs/gaming.nix
    ../../home/programs/zeroclaw
  ];

  dotfiles.hyprland.noHardwareCursors = true;
}
