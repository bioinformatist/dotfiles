{
  lib,
  pkgs,
  isVM ? false,
  ...
}:
{
  xdg.configFile = {
    "hypr/scripts" = {
      source = ./scripts;
      recursive = true;
    };
    "hypr/wallpapers" = {
      source = ./wallpapers;
      recursive = true;
    };
  };

  # Ensure monitors.conf exists before Hyprland parses `source = monitors.conf`.
  # This must be a real writable file (not xdg.configFile symlink) because
  # nwg-displays writes to it. Impermanence persists it across reboots.
  home.activation.ensureMonitorsConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    touch "$HOME/.config/hypr/monitors.conf"
  '';

  wayland.windowManager.hyprland = {
    systemd.enable = false;
    enable = true;
    extraConfig = builtins.readFile ./hyprland.conf;
    settings = lib.mkIf isVM {
      debug.damage_tracking = 0;
    };
  };

  # ── swww wallpaper services ──────────────────────────────────────────
  #
  # Background: Hyprland + UWSM (withUWSM = true) + systemd.enable = false
  #
  # UWSM manages the session and activates graphical-session.target once
  # the compositor is ready. HM's built-in systemd integration is disabled
  # (per Hyprland docs) to avoid double-starting graphical-session.target.
  #
  # Key design constraints for these services:
  #
  #   1. swww-daemon MUST start AFTER Wayland is ready (WAYLAND_DISPLAY set,
  #      socket exists). On NVIDIA this is slower than nouveau/mesa.
  #      → After=graphical-session.target
  #
  #   2. swww-wallpaper MUST start AFTER swww-daemon is ready.
  #      → After=swww-daemon.service + BindsTo=swww-daemon.service
  #
  #   3. Do NOT use PartOf=graphical-session.target on swww-daemon.
  #      Combined with WantedBy + After on the same target, it creates
  #      an ordering cycle that systemd breaks by deleting jobs.
  #
  #   4. swww-wallpaper uses WantedBy=swww-daemon.service (not target)
  #      to be pulled in transitively, avoiding another cycle path.
  #
  # Dependency chain (no cycles):
  #   graphical-session.target ─(Wants)─▸ swww-daemon
  #   swww-daemon ─(After)──────────────▸ graphical-session.target
  #   swww-daemon ─(Wants)──────────────▸ swww-wallpaper
  #   swww-wallpaper ─(After+BindsTo)───▸ swww-daemon
  #
  systemd.user.services.swww-daemon = {
    Unit = {
      Description = "swww wallpaper daemon";
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "/run/current-system/sw/bin/swww-daemon";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.swww-wallpaper = {
    Unit = {
      Description = "Random wallpaper switcher (swww)";
      After = [ "swww-daemon.service" ];
      BindsTo = [ "swww-daemon.service" ];
    };
    Service = {
      ExecStart = "%h/.config/hypr/scripts/swww_randomize_multi";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "swww-daemon.service" ];
  };
}
