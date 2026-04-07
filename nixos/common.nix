# Shared NixOS configuration for all hosts.
# Host-specific settings (bootloader, networking, hardware) belong in hosts/<name>/configuration.nix.

{
  username,
  config,
  pkgs,
  ...
}:

{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [
      "https://mirrors.ustc.edu.cn/nix-channels/store"
    ];
    extra-substituters = [
      "https://hyprland.cachix.org"
      "https://yazi.cachix.org"
      "https://anyrun.cachix.org"
    ];
    trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
    extra-trusted-public-keys = [
      "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k="
      "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
    ];
    download-buffer-size = 1024 * 1024 * 1024; # 1GB
  };

  time.timeZone = "Asia/Shanghai";

  # System Proxy: Always point to local proxy client (Clash Verge)
  # Dynamic routing is handled by the client's GUI, not NixOS config.
  networking.proxy.default = "http://127.0.0.1:7897";
  networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Use public DNS so queries are routed through TUN and hijacked by Clash's
  # DNS resolver (DoH).  Without this, DNS goes to the LAN router (e.g.
  # 192.168.0.1) which bypasses TUN auto-route → GFW-polluted results.
  networking.nameservers = [
    "8.8.8.8"
    "1.1.1.1"
  ];

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.extraConfig = {
      # --- Audio routing: prefer onboard Realtek ALC892 over GPU HDMI ---
      # On this machine (dual RTX 3090), PipeWire defaults to GPU HDMI audio
      # on boot. This rule forces activation of the onboard analog-stereo
      # profile for the AMD HD Audio controller (headphone jack) and disables
      # the GPU HDMI audio output for all users on this machine.
      "90-alsa-routing" = {
        "monitor.alsa.rules" = [
          {
            matches = [{ "device.name" = "alsa_card.pci-0000_2b_00.3"; }];
            actions = {
              update-props = {
                "device.profile" = "output:analog-stereo+input:analog-stereo";
                "device.disabled" = false;
              };
            };
          }
          {
            matches = [{ "device.name" = "alsa_card.pci-0000_29_00.1"; }];
            actions = {
              update-props = {
                "device.profile" = "off";
              };
            };
          }
        ];
      };
    };
  };

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.nushell;
    hashedPasswordFile = config.sops.secrets."ysun-password".path;
  };

  fonts = {
    packages = with pkgs; [
      sarasa-gothic
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      nerd-fonts.jetbrains-mono
      maple-mono.NF
    ];

    fontconfig.defaultFonts = {
      serif = [
        "Noto Serif CJK SC"
        "Noto Serif"
      ];
      sansSerif = [
        "Sarasa UI SC"
        "Noto Sans CJK SC"
        "Noto Sans"
      ];
      monospace = [
        "JetBrains Mono"
        "Sarasa Mono SC"
        "Noto Sans Mono CJK SC"
      ];
    };
  };

  security.sudo.extraRules = [
    {
      users = [ username ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
  # Prevent sudo from inheriting $HOME, which causes root-owned files
  # in ~/.cache/nix/ and breaks user-level nix commands (e.g. nix shell).
  security.sudo.extraConfig = "Defaults always_set_home";

  nixpkgs.config.allowUnfree = true;

  services.openssh.enable = true;

  # Declarative SSH known hosts — eliminates fingerprint prompts on ephemeral root
  programs.ssh.knownHosts = {
    "github.com-ed25519" = {
      hostNames = [ "github.com" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    };
    "github.com-ecdsa" = {
      hostNames = [ "github.com" ];
      publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=";
    };
    "github.com-rsa" = {
      hostNames = [ "github.com" ];
      publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=";
    };
    # ssh.github.com needs its own entry since knownHosts matches by hostname
    "ssh.github.com-ed25519" = {
      hostNames = [ "ssh.github.com" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
    };
    "ssh.github.com-ecdsa" = {
      hostNames = [ "ssh.github.com" ];
      publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=";
    };
    "ssh.github.com-rsa" = {
      hostNames = [ "ssh.github.com" ];
      publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=";
    };
  };

  # Route GitHub SSH through port 443 to work around Clash TUN mode.
  # TUN intercepts port 22 traffic but fails to proxy SSH protocol;
  # port 443 is handled correctly (treated like HTTPS).
  programs.ssh.extraConfig = ''
    Host github.com
        Hostname ssh.github.com
        Port 443
        User git
        UpdateHostKeys no
  '';

  # Ensure ~/.ssh directory has correct ownership (sops-nix creates it as root)
  system.activationScripts.fixSshDirOwnership = ''
    if [ -d /home/${username}/.ssh ]; then
      chown ${username}:users /home/${username}/.ssh
    fi
  '';

  system.stateVersion = "24.11";
}
