{pkgs, ...}:
{
  imports = [ ./zeroclaw ];

  # Cargo crates.io USTC mirror — declarative via home.file symlink.
  # ~/.cargo/registry/ (cache) is persisted separately via impermanence.
  home.file.".cargo/config.toml".source = ./cargo-config.toml;

  home.packages = with pkgs; [
    telegram-desktop
    sops # CLI for editing encrypted secrets (secrets/secrets.yaml)
    ouch # Rust-based archive tool (zip/tar/gz/xz/zstd/7z)
  ];

  programs.ripgrep.enable = true;
}