{
  programs.nushell = {
    enable = true;
    configFile.source = ./headless-config.nu;
    loginFile.source = ./login.nu;
    shellAliases = {
      rg = "rg --hyperlink-format=default";
    };
  };
}
