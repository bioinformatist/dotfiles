{
  config,
  lib,
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
