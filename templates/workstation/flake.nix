{
  description = "NixOS workstation starter";

  inputs = {
    upstream.url = "github:bioinformatist/dotfiles";
  };

  outputs =
    inputs@{
      upstream,
      ...
    }:
    let
      system = "x86_64-linux";
      username = "changeme";
      hostName = "workstation";
    in
    {
      nixosConfigurations.${hostName} = upstream.lib.mkWorkstationSystem {
        inherit system;
        inherit username;
        modules = [
          ./hosts/workstation/disko-config.nix
          ./hosts/workstation/hardware-configuration.nix
          {
            networking = {
              inherit hostName;
              networkmanager.enable = true;
            };

            boot.loader.systemd-boot.enable = true;
            boot.loader.efi.canTouchEfiVariables = true;

            users.users.${username} = {
              openssh.authorizedKeys.keys = [
                "ssh-ed25519 REPLACE_ME"
              ];
            };
          }
        ];
        homeModules = [
          ./users/changeme/home.nix
        ];
      };
    };
}
