{
  # Keep the background image for potential future Ghostty support
  xdg.configFile = {
    "ghostty/wife_and_son.jpg" = {
      source = ./wife_and_son.jpg;
    };
  };

  programs.ghostty = {
    enable = true;

    settings = {
      font-family = "Maple Mono";
      theme = "Catppuccin Mocha";
      window-decoration = false;
      gtk-titlebar = false;
    };
  };
}
