{
  ...
}:
{
  imports = [
    ./workstation-common.nix
    ../../home/programs/gaming.nix
    ../../home/programs/zeroclaw
  ];

  dotfiles.hyprland.noHardwareCursors = true;
}
