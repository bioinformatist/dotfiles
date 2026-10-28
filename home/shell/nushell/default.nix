{
  config,
  lib,
  pkgs,
  osConfig ? null,
  ...
}:
let
  hostName =
    if osConfig == null then
      "homePC"
    else
      osConfig.networking.hostName;
  repo = "${config.home.homeDirectory}/github.com/bioinformatist/dotfiles";
in
{
  home.packages = [ pkgs.jq ];
  xdg.configFile."dotfiles/nix-plan.jq".source = ../../../scripts/maint/nix-plan.jq;
  xdg.configFile."dotfiles/classify-plan.jq".source = ../../../scripts/maint/classify-plan.jq;

  programs.nushell = {
    enable = true;
    configFile.text = lib.mkForce ''
      source ${./codex-doctor.nu}
      source ${./config.nu}
      source ${./maint.nu}
    '';
    loginFile.source = lib.mkForce ./login.nu;
    shellAliases = {
      rg = "rg --hyperlink-format=default";
    };
  };

  xdg.configFile."dotfiles/maint.nuon".text = builtins.toJSON {
    repo = repo;
    host = hostName;
    parallel = {
      maxJobs = 4;
      cores = 2;
    };
  };
}
