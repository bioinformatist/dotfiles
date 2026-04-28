{
  username,
  ...
}:

{
  imports = [ ../modules/nixos/nix-proxy.nix ];

  dotfiles.nixProxy = {
    enable = true;
    configPath = "/home/${username}/.config/nix/local-proxy.nuon";
    networkingProxyDefault = "http://127.0.0.1:7897";
    networkingNoProxy = "127.0.0.1,localhost,internal.domain";
    nameservers = [
      "8.8.8.8"
      "1.1.1.1"
    ];
  };
}
