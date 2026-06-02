{
  xdg.configFile = {
    "zellij/layouts" = {
      source = ./layouts;
      recursive = true;
    };
  };

  programs.zellij = {
    enable = true;
  };
}
