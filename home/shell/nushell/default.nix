{
  programs.nushell = {
    enable = true;
    configFile.source = ./config.nu;
    loginFile.source = ./login.nu;
    shellAliases = {
      rg = "rg --hyperlink-format=default";
    };
  };
}
