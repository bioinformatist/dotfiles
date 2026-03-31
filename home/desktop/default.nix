{
  pkgs,
  lib,
  ...
}:
let
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
    # Phase 2: modules
    "eww/modules/audio.yuck".source = ./eww/modules/audio.yuck;
    "eww/modules/bluetooth.yuck".source = ./eww/modules/bluetooth.yuck;
    "eww/modules/network.yuck".source = ./eww/modules/network.yuck;
    "eww/modules/sysinfo.yuck".source = ./eww/modules/sysinfo.yuck;
    "eww/modules/notifications.yuck".source = ./eww/modules/notifications.yuck;
    # Windows
    "eww/windows/bar.yuck".source = ./eww/windows/bar.yuck;
    "eww/windows/audio-popup.yuck".source = ./eww/windows/audio-popup.yuck;
    "eww/windows/bt-popup.yuck".source = ./eww/windows/bt-popup.yuck;
    "eww/windows/net-popup.yuck".source = ./eww/windows/net-popup.yuck;
    "eww/windows/weather-search.yuck".source = ./eww/windows/weather-search.yuck;
  };

  # ── eww scripts (need executable permission) ───────────────
  ewwScriptFiles = builtins.listToAttrs (
    map (name: {
      name = "eww/scripts/${name}";
      value = {
        source = ./eww-scripts/${name};
        executable = true;
      };
    }) [
      # Phase 1
      "get-workspaces"
      "get-window-title"
      "get-weather"
      "open-weather"
      "open-bars"
      # Phase 2
      "get-volume"
      "get-audio-sinks"
      "get-audio-sources"
      "set-audio-device"
      "set-vol"
      "get-bluetooth"
      "bt-toggle"
      "bt-pair"
      "get-network"
      "get-sysinfo"
      "get-notifications"
      "close-popups"
      "toggle-popup"
      "search-weather"
    ]
  );
in
{
  imports = [
    ./anyrun
    ./hyprland
  ];

  # ── eww bar ────────────────────────────────────────────────
  # We do NOT use programs.eww.configDir because it conflicts
  # with adding scripts that need executable permission.
  # Instead, we install the eww package and manage all files
  # via xdg.configFile individually.
  programs.eww.enable = true;

  xdg.configFile = ewwConfigFiles // ewwScriptFiles;

  # ── eww runtime dependencies ───────────────────────────────
  home.packages = with pkgs; [
    socat        # Hyprland IPC socket listener
    curl         # Weather API requests
    dbus         # dbus-monitor for Bluetooth events
    dunst        # Notification daemon (dunstctl)
    pulseaudio   # pactl stream for volume events
    # jq is already in nixos/desktop.nix systemPackages

    # Fonts — Nerd Font variant includes all glyph icons
    nerd-fonts.jetbrains-mono
    noto-fonts-cjk-sans
  ];
}