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

  home.packages = [
    pkgs.llm-agents.chatgpt
    pkgs.orca-ide
  ];
}
