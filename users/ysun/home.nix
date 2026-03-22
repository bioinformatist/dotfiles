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

  services.dunst = {
    enable = true;
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
    settings = {
      user.name = "Yu Sun";
      user.email = "ysun@sctmes.com";
    };
  };

  services.ssh-agent.enable = true;
}
