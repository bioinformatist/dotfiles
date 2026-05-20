{ ... }:
{
  imports = [
    ./core.nix
    ./shell/headless.nix
    ./tui
    ./desktop
    ./programs/workstation-cn.nix
  ];

  xdg.enable = true;
}
