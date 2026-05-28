{ inputs }:

{ pkgs, ... }:
{
  imports = [
    ../../home/core.nix
    ./shell-headless.nix
    (import ./tui-headless.nix { inherit inputs; })
    ../../home/programs/codex
  ];

  xdg.enable = true;

  home.file.".cargo/config.toml".source = ../../home/programs/cargo-config.toml;

  home.packages = with pkgs; [
    sops
    ouch
  ];

  programs.ripgrep.enable = true;
}
