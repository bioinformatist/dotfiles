{
  xdg.configFile = {
    "helix/yazi-picker.sh".source = ../helix/yazi-picker.sh;
    "yazi/hx_file.nu".source = ../yazi/hx_file.nu;
    "zellij/layouts" = {
      source = ./layouts;
      recursive = true;
    };
  };

  programs.helix.settings.keys.normal.C-y = {
    # Open the file(s) in the current window
    y = ":sh zellij run -c -f -x 10% -y 10% --width 80% --height 80% -- bash ~/.config/helix/yazi-picker.sh open";
    # Open the file(s) in a vertical pane
    v = ":sh zellij run -c -f -x 10% -y 10% --width 80% --height 80% -- bash ~/.config/helix/yazi-picker.sh vsplit";
    # Open the file(s) in a horizontal pane
    h = ":sh zellij run -c -f -x 10% -y 10% --width 80% --height 80% -- bash ~/.config/helix/yazi-picker.sh hsplit";
  };

  programs.yazi.settings.opener.edit = [
    {
      run = "nu ~/.config/yazi/hx_file.nu \"$1\"";
      desc = "Open File in a new pane";
    }
  ];

  programs.zellij = {
    enable = true;
  };
}
