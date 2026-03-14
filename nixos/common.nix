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
      "https://hyprland.cachix.org"
    ];
    trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
    extra-substituters = [ "https://yazi.cachix.org" ];
    extra-trusted-public-keys = [ "yazi.cachix.org-1:Dcdz63NZKfvUCbDGngQDAZq6kOroIrFoyO064uvLh8k=" ];
    download-buffer-size = 1024 * 1024 * 1024; # 1GB
  };

  time.timeZone = "Asia/Shanghai";

  # System Proxy: Always point to local proxy client (Clash Verge)
  # Dynamic routing is handled by the client's GUI, not NixOS config.
  networking.proxy.default = "http://127.0.0.1:7897";
  networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
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
      jetbrains-mono
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

  nixpkgs.config.allowUnfree = true;

  services.openssh.enable = true;

  system.stateVersion = "24.11";
}
