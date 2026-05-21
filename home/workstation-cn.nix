{ ... }:
{
  imports = [
    ./core.nix
    ./shell
    ./tui
    ./desktop
    ./programs/workstation-cn.nix
  ];

  xdg.enable = true;
}
