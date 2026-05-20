{ lib, ... }:
{
  programs.nushell = {
    enable = true;
    configFile.source = lib.mkForce ./config.nu;
    loginFile.source = lib.mkForce ./login.nu;
    shellAliases = {
      rg = "rg --hyperlink-format=default";
    };
  };
}
