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
    "user-units"
    "X-Restart-Triggers-"
    "unit-"
    "unit-home-manager-"
    "-nix.conf.drv"
    "X-Restart-Triggers-nix-daemon"
    "unit-nix-daemon"
    "-activation-script.drv"
    "-dbus-1.drv"
    "-dry-activate.drv"
    "-hwdb.bin.drv"
    "-manifest-for-users.json.drv"
    "-manifest.json.drv"
    "-system-generators.drv"
    "-system-path.drv"
    "-system-shutdown.drv"
    "-system-units.drv"
    "-tmpfiles.d.drv"
    "-udev-rules.drv"
    "-user-generators.drv"
    "-users-groups.json.drv"
    "-etc-"
    "-etc.drv"
    "-ensure-all-wrappers-paths-exist.drv"
    "-boot.json.drv"
    "-activate.drv"
    "nixos-system-"
    "-openai.yaml.drv"
    "-SKILL-header.md.drv"
    "-SKILL.md.drv"
    "-skill.drv"
    "-source.drv"
    "-codex-config.toml.drv"
    "-context7-auth-mcp-server.drv"
    "-github-mcp-server.drv"
    "-playwright-cli.drv"
  ];
  allowedDirectFetchMarkers = [
    "-codex-x86_64-unknown-linux-musl.tar.gz"
    "-codex-0."
    "-zeroclaw-x86_64-unknown-linux-gnu.tar.gz"
    "-zeroclaw-0."
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
