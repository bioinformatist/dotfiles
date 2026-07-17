{ inputs }:

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.noctalia;
  noctaliaPackage =
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  options.dotfiles.noctalia.weatherLocation = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = ''
      Fixed weather location for Noctalia. Set to null to disable configured
      weather and leave location unset.
    '';
  };

  config.programs.noctalia = {
    enable = true;
    systemd.enable = true;
    package = noctaliaPackage;
    validateConfig = true;

    settings =
      let
        noctaliaSettings = {
          shell = {
            font_family = "JetBrainsMono Nerd Font";
            telemetry_enabled = false;
            setup_wizard_enabled = false;
            external_ip_enabled = false;
            polkit_agent = false;
            clipboard_enabled = false;
            screen_time_enabled = false;
            launch_apps_as_systemd_services = true;

            shadow = {
              direction = "center";
              alpha = 0.8;
            };

            panel = {
              transparency_mode = "solid";
              borders = true;
              shadow = true;
              control_center_placement = "attached";
              session_placement = "attached";
            };

            session.actions = [
              {
                action = "logout";
                command = "uwsm stop";
                variant = "default";
              }
              {
                action = "reboot";
                command = "systemctl --user start dotfiles-power-action@reboot.service";
                variant = "primary";
              }
              {
                action = "shutdown";
                command = "systemctl --user start dotfiles-power-action@poweroff.service";
                variant = "destructive";
              }
            ];
          };

          theme = {
            mode = "dark";
            source = "custom";
            custom_palette = "dotfiles";
            pure_black_dark = false;
            templates = {
              enable_builtin_templates = false;
              enable_community_templates = false;
            };
          };

          bar.main = {
            position = "top";
            thickness = 42;
            background_opacity = 1.0;
            radius = 8;
            margin_ends = 8;
            margin_edge = 6;
            padding = 10;
            widget_spacing = 5;
            shadow = true;
            border = "primary";
            border_width = 1.0;
            font_weight = 700;
            start = [ "workspaces" ];
            center = [
              "clock"
              "weather"
            ];
            end = [
              "cpu"
              "mem"
              "gpu"
              "tray"
              "notifications"
              "network"
              "bluetooth"
              "volume"
              "battery"
              "control-center"
              "session"
            ];
          };

          widget = {
            workspaces = {
              hide_when_empty = false;
              labels_only_when_occupied = false;
              focused_color = "primary";
              occupied_color = "secondary";
              empty_color = "secondary";
            };

            cpu = {
              type = "sysmon";
              stat = "cpu_usage";
              display = "text";
              show_label = true;
              scale = 0.85;
              capsule = true;
              capsule_fill = "surface_variant";
              capsule_foreground = "on_surface";
              capsule_padding = 5;
              capsule_radius = 6.0;
            };

            mem = {
              type = "sysmon";
              stat = "ram_used";
              display = "text";
              show_label = true;
              scale = 0.85;
              capsule = true;
              capsule_fill = "surface_variant";
              capsule_foreground = "on_surface";
              capsule_padding = 5;
              capsule_radius = 6.0;
            };

            gpu = {
              type = "sysmon";
              stat = "gpu_usage";
              display = "text";
              show_label = true;
              scale = 0.85;
              capsule = true;
              capsule_fill = "primary";
              capsule_foreground = "on_primary";
              capsule_padding = 5;
              capsule_radius = 6.0;
            };

            network.show_label = false;
            bluetooth.show_label = false;
            volume.show_label = false;
          };

          system.monitor.enabled = true;

          weather = {
            enabled = cfg.weatherLocation != null;
            refresh_minutes = 30;
            unit = "celsius";
          };

          location = {
            auto_locate = false;
          }
          // lib.optionalAttrs (cfg.weatherLocation != null) {
            address = cfg.weatherLocation;
          };

          audio.enable_overdrive = false;
          notification.enable_daemon = true;
          wallpaper.enabled = false;
          dock.enabled = false;
          desktop_widgets.enabled = false;
          lockscreen.enabled = false;
          lockscreen_widgets.enabled = false;
        };
      in
      (pkgs.formats.toml { }).generate "dotfiles-noctalia-settings.toml" noctaliaSettings;

    customPalettes.dotfiles.dark = {
      mPrimary = "#FFA31A";
      mOnPrimary = "#000000";
      mSecondary = "#21D4FD";
      mOnSecondary = "#000000";
      mTertiary = "#21D4FD";
      mOnTertiary = "#000000";
      mError = "#E5484D";
      mOnError = "#FFFFFF";
      mSurface = "#090909";
      mOnSurface = "#FFFFFF";
      mSurfaceVariant = "#161616";
      mOnSurfaceVariant = "#C7C7C7";
      mOutline = "#FFA31A";
      mShadow = "#FFA31A";
      mHover = "#242424";
      mOnHover = "#FFFFFF";
    };
  };
}
