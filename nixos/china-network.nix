{ ... }:

{
  imports = [ ../modules/nixos/nix-network.nix ];

  dotfiles.nixNetwork = {
    profile = "china";
    networkManagerNameservers = [
      "223.5.5.5"
      "223.6.6.6"
    ];
  };
}
