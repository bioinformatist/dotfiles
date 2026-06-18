{ inputs }:

{
  core = import ../../home/core.nix;
  tui = import ./tui.nix { inherit inputs; };
  codex = import ../../home/programs/codex { inherit inputs; };
  workstation = import ./workstation.nix { inherit inputs; };
  shellHeadless = import ./shell-headless.nix;
  tuiHeadless = import ./tui-headless.nix { inherit inputs; };
  headlessDevTools = import ./headless-dev-tools.nix { inherit inputs; };
  devHeadless = import ./dev-headless.nix { inherit inputs; };
}
