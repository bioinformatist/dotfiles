{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    (import ../../home/workstation.nix { inherit inputs; })
  ];

  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "bottom";
      control-center-positionX = "right";
      control-center-positionY = "top";
      control-center-margin-top = 56;
      control-center-margin-right = 16;
      layer = "overlay";
      control-center-layer = "top";
      layer-shell = true;
      cssPriority = "user";
      notification-window-width = 400;
      control-center-width = 420;
      control-center-height = 640;
      notification-grouping = true;
      notification-inline-replies = false;
      relative-timestamps = true;
      timeout = 8;
      timeout-low = 5;
      timeout-critical = 0;
      hide-on-action = true;
      text-empty = "No notifications";
      widgets = [
        "title"
        "dnd"
        "notifications"
      ];
      widget-config = {
        title = {
          text = "Notifications";
          clear-all-button = true;
          button-text = "Clear all";
        };
        dnd.text = "Do Not Disturb";
        notifications.vexpand = true;
      };
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", "Noto Sans CJK SC", sans-serif;
        font-size: 13px;
        font-weight: 600;
      }

      notificationwindow,
      blankwindow {
        background: transparent;
      }

      .control-center {
        color: #ffffff;
        background: #090909;
        border: 1px solid #333333;
        border-radius: 8px;
        box-shadow: 0 0 8px rgba(255, 163, 26, 0.22);
      }

      .notification-row {
        outline: none;
      }

      .notification-row .notification-background {
        padding: 5px 10px;
      }

      .notification-row .notification-background .notification {
        color: #ffffff;
        background: #111111;
        border: 1px solid #333333;
        border-radius: 8px;
      }

      .notification-row .notification-background .notification.critical {
        border-color: #e5484d;
      }

      .notification-row .notification-background .notification .notification-default-action,
      .notification-row .notification-background .notification .notification-action {
        color: #ffffff;
        background: transparent;
        border-radius: 7px;
      }

      .notification-row .notification-background .notification .notification-default-action:hover,
      .notification-row .notification-background .notification .notification-action:hover {
        background: #242424;
      }

      .summary,
      .time,
      .widget-title > label {
        color: #ffffff;
        font-weight: 700;
      }

      .body,
      .widget-dnd > label {
        color: #a7a7a7;
      }

      .close-button,
      .widget-title > button {
        color: #000000;
        background: #ffa31a;
        border: 0;
        border-radius: 6px;
      }

      .widget-dnd > switch {
        background: #333333;
        border-radius: 8px;
      }

      .widget-dnd > switch:checked {
        background: #ffa31a;
      }

      .widget-dnd > switch slider {
        background: #ffffff;
      }
    '';
  };

  systemd.user.services.clash-verge-gui = {
    Unit = {
      Description = "Clash Verge graphical client";
      After = [
        "graphical-session.target"
        "dotfiles-eww-bars.service"
      ];
      ConditionPathExists = "/run/current-system/sw/bin/clash-verge";
    };
    Service = {
      ExecStart = "/run/current-system/sw/bin/clash-verge";
      Environment = "PATH=${lib.makeBinPath [ pkgs.coreutils ]}:/run/current-system/sw/bin";
      Slice = "app-graphical.slice";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  dotfiles.codex.trustedProjects = [
    "/home/ysun/github.com/bioinformatist/dotfiles"
  ];

  xdg.dataFile = {
    "fcitx5/rime/default.custom.yaml".text = ''
      patch:
        schema_list:
          - schema: luna_pinyin    # Mandarin Pinyin (Simplified)
          - schema: jyut6ping3     # Cantonese Jyutping (Traditional)
        menu:
          page_size: 9
        ascii_composer:
          switch_key:
            Shift_L: commit_code
            Shift_R: noop
    '';

    "fcitx5/rime/luna_pinyin.custom.yaml".text = ''
      patch:
        switches:
          - name: ascii_mode
            reset: 0
          - name: full_shape
            reset: 0
          - name: simplification
            reset: 1
          - name: ascii_punct
            reset: 0
    '';

    "fcitx5/rime/jyut6ping3.custom.yaml".text = ''
      patch:
        switches:
          - name: ascii_mode
            reset: 0
          - name: full_shape
            reset: 0
          - name: simplification
            reset: 0
          - name: ascii_punct
            reset: 0
    '';
  };

  home.activation.rimeInstallation = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    RIME_DIR="$HOME/.local/share/fcitx5/rime"
    if [ ! -f "$RIME_DIR/installation.yaml" ]; then
      mkdir -p "$RIME_DIR"
      printf '%s\n' 'installation_id: "nixos-ysun"' 'sync_dir: "/home/ysun/github.com/bioinformatist/dotfiles/rime-sync"' > "$RIME_DIR/installation.yaml"
    fi
  '';

  programs.git = {
    enable = true;
    signing.format = "openpgp";
    settings = {
      user.name = "Yu Sun";
      user.email = "ysun@sctmes.com";
    };
  };

  # OpenSSH rejects Nix-store-backed symlinked user config on this tmpfs/persist
  # layout, so write a real 0600 file instead of using programs.ssh.
  home.activation.sshConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        rm -f "$HOME/.ssh/config"
        install -m 600 /dev/stdin "$HOME/.ssh/config" <<'EOF'
    Host 116 bigdick 192.168.0.116
      IdentitiesOnly yes
      User ysun
      HostName 192.168.0.116
      IdentityFile ~/.ssh/id_ed25519_sctmes_ops
      UpdateHostKeys no
    EOF
  '';

  home.file.".ssh/id_ed25519_sctmes_ops.pub".text =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGtt7b+dw26OWbwowudCyFf+HwR6Phh/8pUA0DnA26tV ysun@sctmes-ops\n";

  services.ssh-agent.enable = true;
}
