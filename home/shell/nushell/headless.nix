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
      description = "Strings maint-switch treats as heavy local build markers in dry-run output.";
    };

    allowedLocalBuildMarkers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "hm_"
        "home-manager-path"
        "home-manager-files"
        "home-manager-generation"
        "user-environment"
        "unit-home-manager-"
        "-nix.conf.drv"
        "X-Restart-Triggers-nix-daemon"
        "unit-nix-daemon"
        "-system-units.drv"
        "-etc.drv"
        "-activate.drv"
        "nixos-system-"
      ];
      description = "Strings maint-switch allows in locally built NixOS/Home Manager glue derivations.";
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
          riskMarkers
          allowedLocalBuildMarkers
          parallel
          ;
      };
    };
  };
}
