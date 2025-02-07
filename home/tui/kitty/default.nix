{
  xdg.configFile = {
    "kitty/wife_and_son.jpg" = {
      source = ./wife_and_son.jpg;
      recursive = true;
    };
  };

  programs.kitty = {
    enable = true;

    settings = {
      font_family = "family=\"maple-mono\"";
      background_image = "wife_and_son.jpg";
      background_image_layout = "cscaled";
      background_image_linear = "yes";
      dynamic_background_opacity = "yes";
      background_tint = "0.918";
      shell = "zellij -l welcome";
      editor = "hx";
    };
  };
}