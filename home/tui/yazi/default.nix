{
  xdg.configFile."yazi/hx_file.nu".source = ./hx_file.nu;

  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
    enableNushellIntegration = true;
    initLua = ./init.lua;
    settings = builtins.fromTOML (builtins.readFile ./yazi.toml);
  };
}
