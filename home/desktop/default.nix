{
  config,
  pkgs,
  lib,
  ...
}:
let
  ewwRuntimePath =
    lib.makeBinPath (
      with pkgs;
      [
        alsa-utils
        bash
        coreutils
        curl
        gawk
        gnugrep
        gnused
        hyprland
        iproute2
        jq
        libnotify
        nushell
        pavucontrol
        pulseaudio
        socat
        swaynotificationcenter
        systemd
        util-linux
        xdg-utils
        zenity
      ]
      ++ [ config.programs.eww.package ]
    )
    + ":/run/current-system/sw/bin";

  powerAction = pkgs.writeShellApplication {
    name = "dotfiles-power-action";
    runtimeInputs = with pkgs; [
      coreutils
      systemd
      uwsm
    ];
    text = ''
      action="''${1:?Usage: dotfiles-power-action <poweroff|reboot>}"

      case "$action" in
        poweroff|reboot)
          ;;
        *)
          echo "Unknown power action: $action" >&2
          exit 1
          ;;
      esac

      if uwsm check is-active; then
        timeout 60s uwsm stop || true
      fi

      exec systemctl "$action"
    '';
  };

  # ── eww config files (yuck + scss) ─────────────────────────
  # These are plain config files, no executable flag needed.
  ewwConfigFiles = {
    "eww/eww.yuck".source = ./eww/eww.yuck;
    "eww/eww.scss".source = ./eww/eww.scss;
    # Phase 1: modules
    "eww/modules/workspaces.yuck".source = ./eww/modules/workspaces.yuck;
    "eww/modules/window-title.yuck".source = ./eww/modules/window-title.yuck;
    "eww/modules/clock.yuck".source = ./eww/modules/clock.yuck;
    "eww/modules/weather.yuck".source = ./eww/modules/weather.yuck;
    "eww/modules/bar-center-extra.yuck".source =
      if config.dotfiles.eww.d2r.enable then
        ./eww-features/d2r/bar-center-extra.yuck
      else
        ./eww/modules/bar-center-extra.yuck;
    # Phase 2: modules
    "eww/modules/audio.yuck".source = ./eww/modules/audio.yuck;
    "eww/modules/battery.yuck".source = ./eww/modules/battery.yuck;
    "eww/modules/proxy-status.yuck".source = ./eww/modules/proxy-status.yuck;
    "eww/modules/power.yuck".source = ./eww/modules/power.yuck;
    "eww/modules/sysinfo.yuck".source = ./eww/modules/sysinfo.yuck;
    "eww/modules/notifications.yuck".source = ./eww/modules/notifications.yuck;
    # Windows
    "eww/windows/bar.yuck".source = ./eww/windows/bar.yuck;
    "eww/windows/audio-popup.yuck".source = ./eww/windows/audio-popup.yuck;
    "eww/windows/popup-closer.yuck".source = ./eww/windows/popup-closer.yuck;
    "eww/windows/power-popup.yuck".source = ./eww/windows/power-popup.yuck;
    # Data files
  };

  # ── eww scripts (need executable permission) ───────────────
  ewwScriptFiles = builtins.listToAttrs (
    map
      (name: {
        name = "eww/scripts/${name}";
        value = {
          source = ./eww-scripts/${name};
          executable = true;
        };
      })
      [
        # Phase 1
        "get-workspaces"
        "get-window-title"
        "get-weather"
        "open-weather"
        "open-calendar"
        "manage-bars"
        # Phase 2
        "get-volume"
        "get-audio-sinks"
        "get-audio-sources"
        "set-audio-device"
        "set-vol"
        "get-battery"
        "get-proxy-status"
        "get-sysinfo"
        "get-notifications"
        "close-popups"
        "toggle-popup"
        "run-power-action"
        "search-weather"
      ]
  );

  d2rFiles = lib.optionalAttrs config.dotfiles.eww.d2r.enable {
    "eww/terror-zones.json".source = ./eww-features/d2r/terror-zones.json;
    "eww/scripts/get-terror-zone" = {
      source = ./eww-features/d2r/get-terror-zone;
      executable = true;
    };
  };

  ewwRestartTriggers = map (file: toString file.source) (
    builtins.attrValues (ewwConfigFiles // ewwScriptFiles // d2rFiles)
  );
in
{
  imports = [
    ./anyrun
    ./ghostty
    ./hyprland
  ];

  options.dotfiles.eww.d2r.enable = lib.mkEnableOption "D2R terror-zone content in the Eww bar";

  config = {
    # ── eww bar ────────────────────────────────────────────────
    # We do NOT use programs.eww.configDir because it conflicts
    # with adding scripts that need executable permission.
    # Instead, we install the eww package and manage all files
    # via xdg.configFile individually.
    programs.eww.enable = true;

    xdg.configFile = ewwConfigFiles // ewwScriptFiles // d2rFiles;

    systemd.user.services = {
      eww = {
        Unit = {
          Description = "Eww widget daemon";
          Documentation = "https://elkowar.github.io/eww/";
          After = [ "graphical-session.target" ];
          X-Restart-Triggers = ewwRestartTriggers;
        };
        Service = {
          ExecStart = "${lib.getExe config.programs.eww.package} daemon --no-daemonize";
          Environment = "PATH=${ewwRuntimePath}";
          Slice = "app-graphical.slice";
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      dotfiles-eww-bars = {
        Unit = {
          Description = "Reconcile Eww bars with Hyprland monitors";
          After = [
            "graphical-session.target"
            "eww.service"
          ];
          Wants = [ "eww.service" ];
          X-Restart-Triggers = [ (toString ewwScriptFiles."eww/scripts/manage-bars".source) ];
        };
        Service = {
          Type = "notify";
          NotifyAccess = "all";
          TimeoutStartSec = 20;
          ExecStart = "%h/.config/eww/scripts/manage-bars";
          Environment = "PATH=${ewwRuntimePath}";
          Slice = "background-graphical.slice";
          Restart = "on-failure";
          RestartSec = 1;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      dotfiles-eww-popup-closer = {
        Unit = {
          Description = "Close Eww popups when application focus changes";
          After = [
            "graphical-session.target"
            "eww.service"
          ];
          Wants = [ "eww.service" ];
          X-Restart-Triggers = [ (toString ewwScriptFiles."eww/scripts/close-popups".source) ];
        };
        Service = {
          ExecStart = "%h/.config/eww/scripts/close-popups";
          Environment = "PATH=${ewwRuntimePath}";
          Slice = "background-graphical.slice";
          Restart = "on-failure";
          RestartSec = 1;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      "dotfiles-power-action@" = {
        Unit = {
          Description = "Stop UWSM session and %i";
          Documentation = "man:uwsm(1)";
        };
        Service = {
          Type = "oneshot";
          Slice = "session.slice";
          ExecStart = "${lib.getExe powerAction} %i";
        };
      };
    };

    # ── eww runtime dependencies ───────────────────────────────
    home.packages = with pkgs; [
      socat # Hyprland IPC socket listener
      curl # Weather API requests
      swaynotificationcenter # Notification daemon and maintained control center
      pulseaudio # pactl stream for volume events
      alsa-utils # amixer for hardware capture gain in the audio popup
      pavucontrol # Full PipeWire/PulseAudio mixer opened from the audio popup
      # jq is already in nixos/desktop.nix systemPackages

      # Fonts — Nerd Font variant includes all glyph icons
      nerd-fonts.jetbrains-mono
      noto-fonts-cjk-sans
    ];
  };
}
