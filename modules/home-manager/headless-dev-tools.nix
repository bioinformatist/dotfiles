{ inputs }:

{ pkgs, ... }:
{
  imports = [
    ./shell-headless.nix
    (import ./tui-headless.nix { inherit inputs; })
    (import ../../home/programs/codex { inherit inputs; })
  ];

  xdg.enable = true;

  home.file.".cargo/config.toml".source = ../../home/programs/cargo-config.toml;

  home.packages = with pkgs; [
    sops
    ouch
  ];

  programs.ripgrep.enable = true;
}
