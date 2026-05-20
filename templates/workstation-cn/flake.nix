{
  description = "NixOS workstation starter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    upstream = {
      url = "github:bioinformatist/dotfiles";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      disko,
      home-manager,
      upstream,
      ...
    }:
    let
      system = "x86_64-linux";
      username = "changeme";
      hostName = "workstation";
    in
    {
      nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs username;
        };
        modules = [
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          upstream.profiles.workstationCn
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
              initialPassword = "changeme";
              openssh.authorizedKeys.keys = [
                "ssh-ed25519 REPLACE_ME"
              ];
            };

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = inputs // {
              inherit username;
            };
            home-manager.users.${username} = {
              imports = [
                upstream.homeManagerModules.workstationCn
                ./users/changeme/home.nix
              ];
            };
          }
        ];
      };
    };
}
