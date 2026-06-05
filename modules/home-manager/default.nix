{ inputs }:

{
  core = import ../../home/core.nix;
  tui = import ./tui.nix { inherit inputs; };
  codex = import ../../home/programs/codex { inherit inputs; };
  workstationCn = import ./workstation-cn.nix { inherit inputs; };
  shellHeadless = import ./shell-headless.nix;
  tuiHeadless = import ./tui-headless.nix { inherit inputs; };
  devHeadless = import ./dev-headless.nix { inherit inputs; };
}
