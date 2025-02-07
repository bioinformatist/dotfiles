{
  programs.nushell = {
    enable = true;
    configFile.source = ./config.nu;
    loginFile.source = ./login.nu;
    shellAliases = {
      icat="kitten icat";
      rg="rg --hyperlink-format=kitty";
      s="kitten ssh";
    };
  };
}