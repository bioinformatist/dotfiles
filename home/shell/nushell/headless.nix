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
        "user-units"
        "X-Restart-Triggers-"
        "unit-"
        "unit-home-manager-"
        "-nix.conf.drv"
        "X-Restart-Triggers-nix-daemon"
        "unit-nix-daemon"
        "-activation-script.drv"
        "-dbus-1.drv"
        "-dry-activate.drv"
        "-hwdb.bin.drv"
        "-manifest-for-users.json.drv"
        "-manifest.json.drv"
        "-system-generators.drv"
        "-system-path.drv"
        "-system-shutdown.drv"
        "-system-units.drv"
        "-tmpfiles.d.drv"
        "-udev-rules.drv"
        "-user-generators.drv"
        "-users-groups.json.drv"
        "-etc.drv"
        "-activate.drv"
        "nixos-system-"
        "-openai.yaml.drv"
        "-SKILL-header.md.drv"
        "-SKILL.md.drv"
        "-skill.drv"
        "-source.drv"
        "-codex-config.toml.drv"
        "-context7-auth-mcp-server.drv"
        "-github-mcp-server.drv"
        "-playwright-cli.drv"
      ];
      description = "Strings maint-switch allows in locally built NixOS/Home Manager glue derivations.";
    };

    allowedDirectFetchMarkers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "-codex-x86_64-unknown-linux-musl.tar.gz"
        "-codex-0."
        "-zeroclaw-x86_64-unknown-linux-gnu.tar.gz"
        "-zeroclaw-0."
      ];
      description = "Strings maint-switch allows as declared fixed-output direct release fetches.";
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
          allowedDirectFetchMarkers
          parallel
          ;
      };
    };
  };
}
