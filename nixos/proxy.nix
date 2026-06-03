{ ... }:

{
  imports = [ ../modules/nixos/nix-network.nix ];

  dotfiles.nixNetwork.proxy = {
    enable = true;
    url = "http://127.0.0.1:7897";
  };
}
