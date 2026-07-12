# Linglong keyboard PC host configuration.

{
  inputs,
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disko-config.nix
    (import ../../profiles/workstation.nix { inherit inputs; })
    ../../nixos/china-network.nix
    ../../nixos/proxy.nix
    ../../nixos/amd-mobile.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "linglong";
  networking.networkmanager.enable = true;
  dotfiles.workstation.clash.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true;
  };
  services.hardware.bolt.enable = true;
  services.colord.enable = true;

  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/persist/var/lib/sops-nix/key.txt";
  sops.secrets."ysun-password" = {
    neededForUsers = true;
  };
  sops.secrets."github-ssh-key-vm-test" = {
    owner = "ysun";
    path = "/home/ysun/.ssh/id_ed25519";
  };
  sops.secrets."sctmes-ops-ssh-key" = {
    owner = "ysun";
    path = "/home/ysun/.ssh/id_ed25519_sctmes_ops";
  };
  sops.secrets."github-mcp-token" = {
    owner = "ysun";
  };
  sops.secrets."context7-api-key" = {
    owner = "ysun";
    mode = "0400";
  };

  systemd.tmpfiles.rules = [
    "d /home/ysun/.ssh        0700 ysun users -"
    "d /home/ysun/.local/bin  0755 ysun users -"
  ];

  home-manager.backupFileExtension = "backup";
  home-manager.users.ysun.dotfiles.codex.githubTokenFile =
    config.sops.secrets."github-mcp-token".path;
  home-manager.users.ysun.dotfiles.codex.context7ApiKeyFile =
    config.sops.secrets."context7-api-key".path;
  home-manager.users.ysun.home.packages = [ pkgs.networkmanagerapplet ];
  home-manager.users.ysun.systemd.user.services.nm-applet = {
    Unit = {
      Description = "NetworkManager applet";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.networkmanagerapplet}/bin/nm-applet --indicator";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  fileSystems."/persist".neededForBoot = true;

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/alsa"
      "/var/lib/boltd"
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/lib/NetworkManager"
      "/etc/NetworkManager/system-connections"
      "/var/lib/sops-nix"
      "/var/lib/upower"
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
        ".config/nix"
        ".config/sops"
        ".config/nushell"
        ".config/gh"
        ".config/google-chrome"
        ".config/orca"
        ".codex"
        ".local/share/io.github.clash-verge-rev.clash-verge-rev"
        ".local/share/fcitx5"
        ".local/share/TelegramDesktop"
        ".xwechat"
        "xwechat_files"
        "Downloads"
        "Documents"
        ".cache/eww"
        ".cache/fontconfig"
      ];
      files = [
        ".ssh/known_hosts"
        ".config/hypr/monitors.conf"
      ];
    };
  };
}
