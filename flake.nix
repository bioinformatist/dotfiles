{
  description = "NixOS configuration of Yu Sun";

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
    hyprland.url = "github:hyprwm/Hyprland";
    swww.url = "github:LGFae/swww";
    yazi.url = "github:sxyazi/yazi";
    impermanence.url = "github:nix-community/impermanence";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    antigravity = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    anyrun = {
      url = "github:anyrun-org/anyrun";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      disko,
      home-manager,
      yazi,
      impermanence,
      sops-nix,
      ...
    }:
    {
      nixpkgs.overlays = [
        yazi.overlays.default
        import
        ./overlays
        { inherit inputs; }
      ];

      nixosModules = import ./modules/nixos;
      homeManagerModules = import ./modules/home-manager;

      nixosConfigurations =
        let
          username = "ysun";
          mkHost =
            { hostDir, isVM }:
            let
              specialArgs = {
                inherit username isVM;
              };
            in
            nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              specialArgs = { inherit username inputs; };

              modules = [
                ./hosts/${hostDir}/configuration.nix
                disko.nixosModules.disko
                impermanence.nixosModules.impermanence
                sops-nix.nixosModules.sops
                home-manager.nixosModules.home-manager
                {
                  home-manager.useGlobalPkgs = true;
                  home-manager.useUserPackages = true;

                  home-manager.extraSpecialArgs = inputs // specialArgs;
                  home-manager.users.${username} = import ./users/${username}/home.nix;
                }
              ];
            };
        in
        {
          vm-test = mkHost {
            hostDir = "vm-test";
            isVM = true;
          };
          homePC = mkHost {
            hostDir = "workstation";
            isVM = false;
          };
        };

      homeConfigurations =
        let
          mkHome = home-manager.lib.homeManagerConfiguration {
            pkgs = nixpkgs.legacyPackages.x86_64-linux;
            modules = [
              (
                { pkgs, ... }:
                {
                  home.packages = [ yazi.packages.${pkgs.stdenv.hostPlatform.system}.default ];
                }
              )
            ];
          };
        in
        {
          "ysun@vm-test" = mkHome;
          "ysun@homePC" = mkHome;
        };
    };
}
