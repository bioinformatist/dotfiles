{
  anyrun,
  pkgs,
  ...
}:
let
  anyrunPkgs = anyrun.packages.${pkgs.stdenv.hostPlatform.system};
  applicationExecPreprocessor = pkgs.writeShellScript "anyrun-application-exec-preprocessor" ''
    first="$1"
    shift

    case "$first" in
      term|no-term)
        term_flag="$first"
        ;;
      *)
        term_flag="$1"
        shift
        ;;
    esac

    if [ "$term_flag" = "term" ]; then
      printf '%s\n' "$*"
    else
      printf 'uwsm-app -s a -- %s\n' "$*"
    fi
  '';
in
{
  imports = [
    (
      { modulesPath, ... }:
      {
        disabledModules = [ "${modulesPath}/programs/anyrun.nix" ];
      }
    )
    anyrun.homeManagerModules.default
  ];

  programs.anyrun = {
    enable = true;
    daemon.enable = true;
    package = anyrunPkgs.default;

    config = {
      x = {
        fraction = 0.5;
      };
      y = {
        absolute = 200;
      };
      width = {
        absolute = 800;
      };
      height = {
        absolute = 1;
      };
      hideIcons = false;
      ignoreExclusiveZones = false;
      layer = "overlay";
      hidePluginInfo = false;
      closeOnClick = true;
      showResultsImmediately = false;
      maxEntries = null;
      plugins = with anyrunPkgs; [
        applications
        rink
        shell
        symbols
        websearch
      ];
    };

    extraConfigFiles."websearch.ron".text = ''
      Config(
        prefix: "?",
        engines: [Google],
      )
    '';

    extraConfigFiles."applications.ron".text = ''
      Config(
        desktop_actions: false,
        max_entries: 5,
        hide_description: false,
        preprocess_exec_script: Some("${applicationExecPreprocessor}"),
        terminal: None,
      )
    '';

    extraCss = ''
      @define-color accent rgba(51, 204, 255, 0.9);
      @define-color accent-dim rgba(51, 204, 255, 0.4);
      @define-color bg-color rgba(22, 22, 22, 0.85);
      @define-color fg-color #eeeeee;
      @define-color desc-color #aaaaaa;

      window {
        background: transparent;
      }

      box.main {
        padding: 12px;
        margin: 10px;
        border-radius: 16px;
        border: 2px solid @accent-dim;
        background-color: @bg-color;
        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.6);
      }

      text {
        min-height: 36px;
        padding: 8px 12px;
        border-radius: 8px;
        color: @fg-color;
        font-size: 16px;
        caret-color: @accent;
      }

      .matches {
        background-color: transparent;
        border-radius: 12px;
        margin-top: 8px;
      }

      box.plugin:first-child {
        margin-top: 4px;
      }

      box.plugin.info {
        min-width: 200px;
      }

      list.plugin {
        background-color: transparent;
      }

      label.match {
        color: @fg-color;
        font-size: 14px;
      }

      label.match.description {
        font-size: 11px;
        color: @desc-color;
      }

      label.plugin.info {
        font-size: 13px;
        color: @desc-color;
      }

      .match {
        padding: 6px 10px;
        border-radius: 8px;
        background: transparent;
        transition: all 0.15s ease;
      }

      .match:selected {
        border-left: 3px solid @accent;
        background: rgba(51, 204, 255, 0.08);
      }
    '';
  };
}
