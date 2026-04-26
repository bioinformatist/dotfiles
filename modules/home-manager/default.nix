{
  core = import ../../home/core.nix;
  tui = import ../../home/tui;
  codex = import ../../home/programs/codex;
  shellHeadless = import ./shell-headless.nix;
  tuiHeadless = import ./tui-headless.nix;
  devHeadless = import ./dev-headless.nix;
}
