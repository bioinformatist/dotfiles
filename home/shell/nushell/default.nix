{ lib, ... }:
{
  programs.nushell = {
    enable = true;
    configFile.text = lib.mkForce ''
      source ${./maint-codex.nu}
      source ${./config.nu}
    '';
    loginFile.source = lib.mkForce ./login.nu;
    shellAliases = {
      rg = "rg --hyperlink-format=default";
    };
  };
}
