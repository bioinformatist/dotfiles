{ inputs }:

{ pkgs, ... }:
{
  imports = [
    (import ./codex { inherit inputs; })
  ];

  home.file.".cargo/config.toml".source = ./cargo-config.toml;

  home.packages = with pkgs; [
    sops
    ouch
    telegram-desktop
    discord
    wemeet
  ];

  programs.ripgrep.enable = true;
}
