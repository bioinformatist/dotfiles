{
  xdg.configFile = {
    "zellij/layouts" = {
      source = ./layouts;
      recursive = true;
    };
    "zellij/config.kdl" = {
      source = ./config.kdl;
    };
  };
  
  programs.zellij = {
    enable = true;
  };
}