{
  config,
  lib,
  osConfig ? null,
  ...
}:
let
  hostName =
    if osConfig == null then
      "homePC"
    else
      osConfig.networking.hostName;
  repo = "${config.home.homeDirectory}/github.com/bioinformatist/dotfiles";
  riskMarkers = [
    "nvidia-x11"
    "linux-"
    "mesa-"
    "systemd-"
    "hyprland"
    "hyprlang"
    "hyprutils"
    "hyprgraphics"
    "hyprwayland-scanner"
    "hyprwire"
    "gcc-"
    "xgcc"
    "rustc-"
    "cargo-vendor"
    "chromium"
    "electron"
    "serenityos-emoji-font"
    "nanoemoji"
  ];
  allowedLocalBuildMarkers = [
    "hm_"
    "home-manager-path"
    "home-manager-files"
    "home-manager-generation"
    "user-environment"
    "unit-home-manager-"
    "-nix.conf.drv"
    "X-Restart-Triggers-nix-daemon"
    "unit-nix-daemon"
    "-system-units.drv"
    "-etc.drv"
    "-activate.drv"
    "nixos-system-"
  ];
  allowedDirectFetchMarkers = [
    "-codex-"
    "-zeroclaw-"
  ];
in
{
  programs.nushell = {
    enable = true;
    configFile.text = lib.mkForce ''
      source ${./codex-doctor.nu}
      source ${./config.nu}
      source ${./maint.nu}
    '';
    loginFile.source = lib.mkForce ./login.nu;
    shellAliases = {
      rg = "rg --hyperlink-format=default";
    };
  };

  xdg.configFile."dotfiles/maint.nuon".text = builtins.toJSON {
    repo = repo;
    host = hostName;
    parallel = {
      maxJobs = 4;
      cores = 2;
    };
    riskMarkers = riskMarkers;
    allowedLocalBuildMarkers = allowedLocalBuildMarkers;
    allowedDirectFetchMarkers = allowedDirectFetchMarkers;
  };
}
