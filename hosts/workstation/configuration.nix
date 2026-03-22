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
  ];

  # --- Physical machine: Boot ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- Physical machine: Networking ---
  networking.hostName = "homePC";
  networking.networkmanager.enable = true;

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

  # --- Home Manager ---
  home-manager.backupFileExtension = "backup";

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
        ".local/share/io.github.clash-verge-rev.clash-verge-rev"
        ".local/share/fcitx5" # Fcitx5/Rime user dictionary and learned words
        ".gemini" # Antigravity IDE data (conversations, knowledge base)
        "xwechat_files" # WeChat chat history and data
        # Physical machine daily-use paths
        "Downloads"
        "Documents"
        ".mozilla"   # Firefox profile (if used)
      ];
      files = [
        ".ssh/known_hosts" # SSH host fingerprint cache
      ];
    };
  };
}
