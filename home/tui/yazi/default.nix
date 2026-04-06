{ pkgs, ... }:
{
  xdg.configFile."yazi/hx_file.nu".source = ./hx_file.nu;

  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
    enableNushellIntegration = true;
    initLua = ./init.lua;
    settings = builtins.fromTOML (builtins.readFile ./yazi.toml);
    keymap = {
      mgr.prepend_keymap = [
        { on = [ "z" ]; run = "plugin zoxide"; desc = "Jump to a directory via zoxide"; }
        { on = [ "Z" ]; run = "plugin zoxide --args=list"; desc = "Pick a directory via zoxide"; }
        { on = [ "<C-s>" ]; run = "plugin fzf"; desc = "Find files by name via fzf"; }
      ];
    };
  };

  # Optional dependencies — auto-discovered by yazi via PATH.
  # video: ffmpeg  |  archive: p7zip (7z)  |  JSON: jq  |  PDF: poppler_utils (pdftoppm)
  # SVG: resvg     |  HEIC/JXL/font: imagemagick (≥7.1.1)  |  file search: fd
  home.packages = with pkgs; [
    ffmpeg
    p7zip
    jq
    poppler-utils
    fd
    resvg
    imagemagick
  ];

  # fzf and zoxide: shell integration keeps the zoxide database populated as
  # you navigate, so `z` / `Z` inside yazi actually finds historical paths.
  programs.fzf.enable = true;
  programs.zoxide = {
    enable = true;
    enableNushellIntegration = true;
  };
}
