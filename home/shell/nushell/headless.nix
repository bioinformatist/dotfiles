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

    parallel = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Moderate Nix concurrency settings used by maint-switch.";
    };

  };

  config = {
    programs.nushell = {
      enable = true;
      configFile.text = ''
        source ${./codex-doctor.nu}
        source ${./headless-config.nu}
        source ${./maint.nu}
      '';
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
          parallel
          ;
      };
    };
  };
}
