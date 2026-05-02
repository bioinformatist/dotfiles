{
  programs.nushell = {
    enable = true;
    configFile.source = ./headless-config.nu;
    loginFile.text = "";
    shellAliases = {
      rg = "rg --hyperlink-format=default";
    };
  };
}
