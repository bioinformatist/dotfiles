{
  xdg.configFile."helix/yazi-picker.sh".source = ./yazi-picker.sh;

  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = builtins.fromTOML(builtins.readFile ./config.toml);
  };
}