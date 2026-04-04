# Workstation (physical machine) host configuration.
# Shared settings are in ../../nixos/common.nix and ../../nixos/desktop.nix.



{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disko-config.nix
    ../../nixos/common.nix
    ../../nixos/desktop.nix
    ../../nixos/nvidia.nix
  ];

  # --- Physical machine: Boot ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- Physical machine: Networking ---
  networking.hostName = "homePC";
  networking.networkmanager.enable = true;

  # --- Physical machine: Bluetooth ---
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true; # Enable battery display etc.
  };

  # --- Sops secrets (host-specific paths) ---
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/persist/var/lib/sops-nix/key.txt";
  sops.secrets."ysun-password" = {
    neededForUsers = true;
  };
  # Shared GitHub SSH key (same key for all hosts)
  sops.secrets."github-ssh-key-vm-test" = {
    owner = "ysun";
    path = "/home/ysun/.ssh/id_ed25519";
  };
  sops.secrets."clash-subscription-url" = {
    owner = "ysun";
  };
  # ZeroClaw secrets — fill via: sudo SOPS_AGE_KEY_FILE=... sops set secrets/secrets.yaml
  sops.secrets."zeroclaw-telegram-token" = {
    owner = "ysun";
  };

  sops.secrets."zeroclaw-user-context" = {
    owner = "ysun";
  };
  # systemd-tmpfiles-setup runs before sops-install-secrets, so this
  # guarantees ~/.zeroclaw/workspace/ is ysun-owned when sops writes USER.md.
  # Without this, sops (running as root) creates the parent dir as root,
  # blocking home-manager's symlink creation → HM fails → Hyprland unconfigured.
  # Ref: https://github.com/Mic92/sops-nix/issues/235 (known sops-nix limitation)
  systemd.tmpfiles.rules = [
    "d /home/ysun/.zeroclaw/workspace 0755 ysun users -"
  ];

  # ZeroClaw USER.md — private personal context rendered from sops secret.
  # Edit via: sops secrets/secrets.yaml → zeroclaw-user-context key.
  sops.templates."zeroclaw-user" = {
    owner = "ysun";
    path = "/home/ysun/.zeroclaw/workspace/USER.md";
    content = ''
      ${config.sops.placeholder."zeroclaw-user-context"}
    '';
  };
  # ZeroClaw config.toml — rendered from template with secret injection.
  # The template is placed at a sops-managed path, then symlinked to
  # ~/.zeroclaw/config.toml by the home-manager activation below.
  sops.templates."zeroclaw-config" = {
    owner = "ysun";
    path = "/home/ysun/.zeroclaw/config.toml";
    content = ''
      # --- Self-hosted vLLM only (Qwen3-30B-A3B on 2x3090 GPU server) ---
      # No cloud APIs. Zero cost, zero rate limits, full data privacy.
      default_provider = "custom:http://192.168.0.116:8080/v1"
      default_model = "qwen3-30b-a3b"
      api_key = "no-key-needed"

      # --- Agent behavior ---
      [agent]
      max_tool_iterations = 10
      tool_dispatcher = "auto"
      compact_context = true

      [agent.thinking]
      default_level = "off"

      # --- Reliability ---
      [reliability]
      provider_retries = 1

      [autonomy]
      level = "supervised"
      workspace_only = false
      allowed_roots = ["~/github.com"]
      allowed_commands = ["git", "nix", "nixos-rebuild", "systemctl"]

      [memory]
      backend = "sqlite"
      auto_save = true

      # --- Web search: self-hosted SearXNG (replaces DuckDuckGo IA API) ---
      [web_search]
      enabled = true
      provider = "searxng"
      searxng_instance_url = "http://192.168.0.116:8888"
      max_results = 5

      # --- Channel ---
      [channels_config.telegram]
      bot_token = "${config.sops.placeholder."zeroclaw-telegram-token"}"
      allowed_users = ["6531282851"]
      stream_mode = "off"
      interrupt_on_new_message = true

      [channels_config.telegram.commands]
      native = true
    '';
  };

  # --- Home Manager ---
  home-manager.backupFileExtension = "backup";

  # --- Gaming ---
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    # NixOS Steam module handles symlinking Proton-GE into Steam's runtime.
    # Do NOT manually place in compatibilitytools.d — impermanence makes that unreliable.
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };

  # --- Impermanence ---
  fileSystems."/persist".neededForBoot = true;

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/NetworkManager"
      "/etc/NetworkManager/system-connections"
      "/var/lib/sops-nix"
      {
        directory = "/var/lib/colord";
        user = "colord";
        group = "colord";
        mode = "u=rwx,g=rx,o=";
      }
    ];
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
    users.ysun = {
      directories = [
        "github.com"
        ".config/sops"
        ".config/nushell"
        ".config/google-chrome" # Chrome profile (bookmarks, passwords, extensions)
        ".config/Antigravity" # Antigravity IDE login and session state
        ".config/claude" # Claude Code credentials and session state
        ".claude" # Claude Code memory, history, and session data
        ".local/share/io.github.clash-verge-rev.clash-verge-rev"
        ".local/share/fcitx5" # Fcitx5/Rime user dictionary and learned words
        ".gemini" # Antigravity IDE data (conversations, knowledge base)
        "xwechat_files" # WeChat chat history and data
        # Physical machine daily-use paths
        "Downloads"
        "Documents"
        ".local/share/TelegramDesktop" # Telegram login session + chat cache
        ".cargo/registry" # Cargo registry cache (speeds up rebuilds)
        ".local/share/Steam" # Steam games, Proton prefixes, saves
        ".cache/eww" # Weather location cache (prevents proxy-IP mis-detection on reboot)
      ];
      # known_hosts is a symlink → /persist (cross-filesystem), so SSH cannot
      # atomically update it (link() fails). We suppress the harmless warning
      # via UpdateHostKeys=no in programs.ssh.extraConfig.
      # NOTE: Do NOT persist .ssh as a directory — the bind mount would hide
      # the id_ed25519 symlink that sops-nix creates on tmpfs.
      files = [
        ".ssh/known_hosts"
        ".claude.json" # Claude Code user preferences (theme, model, etc.)
        ".config/hypr/monitors.conf" # nwg-displays monitor layout (persists across reboots)
        # ZeroClaw mutable state only — config.toml is declarative (via sops.templates)
        ".zeroclaw/active_workspace.toml" # workspace marker
        ".zeroclaw/estop-state.json" # emergency stop state
        ".zeroclaw/memory.sqlite" # conversation memory database
      ];
    };
  };
}
