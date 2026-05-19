{ lib, ... }:

{
  networking.networkmanager.insertNameservers = [
    "223.5.5.5"
    "223.6.6.6"
  ];

  nix.settings.substituters = lib.mkForce [
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://cache.nixos.org"
  ];
}
