{
  username,
  ...
}:

{
  imports = [ ../modules/nixos/nix-proxy.nix ];

  dotfiles.nixProxy = {
    enable = true;
    configPath = "/home/${username}/.config/nix/local-proxy.nuon";
  };
}
