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
    pkgs.llm-agents.chatgpt
    pkgs.orca-ide
  ];
}
