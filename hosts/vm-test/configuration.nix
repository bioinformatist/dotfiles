# VM-test host configuration.
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
    ../../modules/nixos/vm-tweaks.nix
    ../../nixos/common.nix
    ../../nixos/desktop.nix
  ]
  ++ lib.optional (builtins.pathExists ./proxy.local.nix) ./proxy.local.nix;

  # --- VM-specific: Boot ---
  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  boot.loader.grub.device = "nodev";

  # --- VM-specific: Networking ---
  networking.hostName = "homePC";
  networking.wireless = {
    enable = true;
    networks = {
      "SC1906".pskRaw = "f6fe7a0e848914ef8a089cf3992d5a639c1feeb86fe758c0ec864d7a5f08e9e0";
      # tr -d '\n' < filename-containing-ssid | od -tx1 -An | tr -d ' ' | tr -d '\n'
      "536e6f772773".pskRaw = "8fe856b34c6755995a3258a5ad9c4e58ff4c089f41e2226dc814ca0b07d7e83a";
    };
  };

  # --- Sops secrets (host-specific paths) ---
  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  # Use the direct path in /persist to avoid race conditions with impermanence bind mounts
  sops.age.keyFile = "/persist/var/lib/sops-nix/key.txt";
  sops.secrets."ysun-password" = {
    neededForUsers = true;
  };
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
        ".local/share/io.github.clash-verge-rev.clash-verge-rev"
      ];
    };
  };
}
