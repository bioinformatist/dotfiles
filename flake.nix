{
  description = "NixOS configuration of Yu Sun";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-tools.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-wechat.url = "github:NixOS/nixpkgs/nixos-unstable";
    anyrun.url = "github:anyrun-org/anyrun";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    yazelix = {
      url = "github:luccahuguet/yazelix";
      inputs.nixpkgs.follows = "nixpkgs-tools";
    };
    hyprland.url = "github:hyprwm/Hyprland";
    swww.url = "github:LGFae/swww";
    impermanence.url = "github:nix-community/impermanence";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      disko,
      home-manager,
      impermanence,
      sops-nix,
      ...
    }:
    let
      lib = nixpkgs.lib;
      systems = [ "x86_64-linux" ];
      forAllSystems = lib.genAttrs systems;
      overlays = import ./overlays { inherit inputs; };
      profiles = import ./profiles { inherit inputs; };
      nixosModules = import ./modules/nixos { inherit inputs; };
      homeManagerModules = import ./modules/home-manager { inherit inputs; };
      mkHost =
        {
          hostDir,
          username,
        }:
        let
          specialArgs = {
            inherit username inputs;
          };
        in
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          inherit specialArgs;

          modules = [
            ./hosts/${hostDir}/configuration.nix
            disko.nixosModules.disko
            impermanence.nixosModules.impermanence
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            {
              nixpkgs.overlays = [
                overlays.additions
                overlays.modifications
              ];

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = inputs // specialArgs;
              home-manager.users.${username} = import ./users/${username}/home.nix;
            }
          ];
        };
    in
    {
      inherit
        overlays
        profiles
        nixosModules
        homeManagerModules
        ;

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              overlays.additions
              overlays.modifications
            ];
          };
        in
        import ./pkgs pkgs
      );

      templates.workstation-cn = {
        path = ./templates/workstation-cn;
        description = "Internal China-friendly NixOS workstation starter";
      };

      nixosConfigurations = {
        homePC = mkHost {
          hostDir = "workstation";
          username = "ysun";
        };
      };

      homeConfigurations =
        let
          mkHome =
            username:
            home-manager.lib.homeManagerConfiguration {
              pkgs = import nixpkgs {
                system = "x86_64-linux";
                overlays = [
                  overlays.additions
                  overlays.modifications
                ];
              };
              extraSpecialArgs = inputs // {
                inherit username;
              };
              modules = [
                ./home/shared.nix
              ];
            };
        in
        {
          "ysun@homePC" = mkHome "ysun";
        };
    };
}
