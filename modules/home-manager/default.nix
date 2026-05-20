{
  core = import ../../home/core.nix;
  tui = import ../../home/tui;
  codex = import ../../home/programs/codex;
  workstationCn = import ../../home/workstation-cn.nix;
  shellHeadless = import ./shell-headless.nix;
  tuiHeadless = import ./tui-headless.nix;
  devHeadless = import ./dev-headless.nix;
}
