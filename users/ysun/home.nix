{ pkgs, lib, ... }:
{
  imports = [
    ../../home/core.nix

    ../../home/desktop
    ../../home/tui
    ../../home/shell
    ../../home/programs
  ];

  xdg.enable = true;

  # ── Cursor theme (unified across GTK / X11 / Wayland) ──────
  # Fixes: resize cursor invisible on UI splitters, XWayland compatibility.
  # home.pointerCursor also sets session-level XCURSOR_THEME/SIZE env vars.
  home.pointerCursor = {
    name = "Bibata-Modern-Classic";
    package = pkgs.bibata-cursors;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  services.dunst = {
    enable = true;
    settings = {
      global = {
        # ── 位置与尺寸 ──────────────────────────────────────────
        # bottom-right 避免与顶部 eww bar 重叠
        origin          = "bottom-right";
        offset          = "20x20";
        width           = "(0, 380)";
        height          = 200;
        gap_size        = 8;

        # ── 视觉 ───────────────────────────────────────────────
        frame_width        = 1;
        frame_color        = "#00dd36";
        corner_radius      = 10;
        separator_height   = 2;
        separator_color    = "frame";
        padding            = 12;
        horizontal_padding = 12;
        text_icon_padding  = 10;

        # 进度条
        progress_bar               = true;
        progress_bar_height        = 8;
        progress_bar_frame_width   = 1;
        progress_bar_min_width     = 150;
        progress_bar_max_width     = 300;
        progress_bar_corner_radius = 4;

        # ── 字体（Pango fallback 支持 CJK）─────────────────────
        font               = "JetBrainsMono Nerd Font 11, Noto Sans CJK SC 11";
        markup             = "full";
        format             = "<b>%s</b>\\n%b";
        alignment          = "left";
        vertical_alignment = "center";
        line_height        = 0;
        ellipsize          = "middle";

        # ── 图标 ───────────────────────────────────────────────
        icon_position              = "left";
        min_icon_size              = 32;
        max_icon_size              = 64;
        enable_recursive_icon_lookup = true;

        # ── 行为 ───────────────────────────────────────────────
        follow               = "mouse";
        stack_duplicates     = true;
        hide_duplicate_count = false;
        show_indicators      = true;
        sticky_history       = true;
        history_length       = 30;
        show_age_threshold   = 60;

        # ── Wayland ────────────────────────────────────────────
        layer = "overlay";

        # ── 鼠标操作 ───────────────────────────────────────────
        mouse_left_click   = "close_current";
        mouse_middle_click = "do_action, close_current";
        mouse_right_click  = "close_all";
      };

      urgency_low = {
        background  = "#050505F0";
        foreground  = "#00aa28";
        frame_color = "#005515";
        timeout     = 5;
      };

      urgency_normal = {
        background  = "#050808F0";
        foreground  = "#00ff41";
        frame_color = "#00dd36";
        timeout     = 8;
      };

      urgency_critical = {
        background  = "#1a0008F0";
        foreground  = "#ff2244";
        frame_color = "#ff2244";
        timeout     = 0;
      };
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
    };
  };

  # --- Declarative Rime schema configuration ---
  # Fcitx5 profile/config/addons are managed at the NixOS level (desktop.nix).
  # Here we only manage Rime's own schema YAML files via xdg.dataFile.
  # After `nixos-rebuild switch`, redeploy Rime: fcitx5-remote -r
  xdg.dataFile = {
    # Global: which schemas to enable and input behavior
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

    # Mandarin: default to Simplified Chinese output
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

    # Cantonese: default to Traditional Chinese output
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

  # installation.yaml must be a regular file (not symlink) because Rime writes
  # runtime metadata (distribution_code_name, etc.) into it. Seed it only when
  # the file doesn't exist yet, so user/runtime changes are preserved.
  home.activation.rimeInstallation = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    RIME_DIR="$HOME/.local/share/fcitx5/rime"
    if [ ! -f "$RIME_DIR/installation.yaml" ]; then
      mkdir -p "$RIME_DIR"
      printf '%s\n' 'installation_id: "nixos-ysun"' 'sync_dir: "/home/ysun/github.com/bioinformatist/dotfiles/rime-sync"' > "$RIME_DIR/installation.yaml"
    fi
  '';

  programs.git = {
    enable = true;
    signing.format = "openpgp"; # silence stateVersion < 25.05 warning
    settings = {
      user.name = "Yu Sun";
      user.email = "ysun@sctmes.com";
    };
  };

  services.ssh-agent.enable = true;
}
