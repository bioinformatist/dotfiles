{ config, lib, ... }:
let
  cfg = config.dotfiles.maint;
in
{
  options.dotfiles.maint = {
    enable = lib.mkEnableOption "headless maintenance helpers";

    repo = lib.mkOption {
      type = lib.types.str;
      description = "Repository path used by maint-* commands.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      description = "NixOS flake host used by maint-* commands.";
    };

    riskMarkers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Strings maint-check highlights when they appear in dry-run output.";
    };

    updateGroups = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = "Named flake input groups used by maint-update commands.";
    };

  };

  config = {
    programs.nushell = {
      enable = true;
      configFile.source = ./headless-config.nu;
      loginFile.text = "";
      shellAliases = {
        rg = "rg --hyperlink-format=default";
      };
    };

    xdg.configFile."dotfiles/maint.nuon" = lib.mkIf cfg.enable {
      text = builtins.toJSON {
        inherit (cfg)
          repo
          host
          riskMarkers
          updateGroups
          ;
      };
    };
  };
}
