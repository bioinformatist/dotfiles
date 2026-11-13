{ ... }:
{
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
    enableNushellIntegration = true;
    initLua = ./init.lua;
    keymap = {
      mgr.prepend_keymap = [
        {
          on = [ "z" ];
          run = "plugin zoxide";
          desc = "Jump to a directory via zoxide";
        }
        {
          on = [ "Z" ];
          run = "plugin zoxide --args=list";
          desc = "Pick a directory via zoxide";
        }
        {
          on = [ "<C-s>" ];
          run = "plugin fzf";
          desc = "Find files by name via fzf";
        }
      ];
    };
  };

  # Nixpkgs wraps Yazi with its preview, archive and search helpers on a
  # private PATH. Do not also expose those implementation dependencies as
  # top-level user commands; keep independently used tools with their owner.

  # fzf and zoxide: shell integration keeps the zoxide database populated as
  # you navigate, so `z` / `Z` inside yazi actually finds historical paths.
  programs.fzf.enable = true;
  programs.zoxide = {
    enable = true;
    enableNushellIntegration = true;
  };
}
