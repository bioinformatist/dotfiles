{pkgs, ...}: {
  imports = [
    ../../home/core.nix

    ../../home/desktop
    ../../home/tui
    ../../home/shell
    ../../home/programs
  ];

  xdg.enable = true;

  services.dunst = {
    enable = true;
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
    };
  };

  i18n.inputMethod = {
    enabled = "fcitx5";
    fcitx5 = {
      addons = with pkgs; [
        fcitx5-gtk
        fcitx5-rime
        fcitx5-configtool
        fcitx5-chinese-addons
      ];
    };
  };

  programs.git = {
    enable = true;
    userName = "Yu Sun";
    userEmail = "ysun@sctmes.com";
  };

  services.ssh-agent.enable = true;
}
