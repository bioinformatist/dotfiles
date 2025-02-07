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
  };
  
  outputs = inputs@{ nixpkgs, disko, home-manager, yazi, ... }: {
    nixpkgs.overlays = [
      yazi.overlays.default
      import ./overlays {inherit inputs;}
    ];

    nixosModules = import ./modules/nixos;
    homeManagerModules = import ./modules/home-manager;
    
    nixosConfigurations = {
      homePC = let 
        username = "ysun";
        specialArgs = {inherit username;};
      in
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit username inputs; };

          modules = [ 
            ./nixos/configuration.nix
            disko.nixosModules.disko

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;

              home-manager.extraSpecialArgs = inputs // specialArgs;
              home-manager.users.${username} = import ./users/${username}/home.nix;
            }
          ];
        };
    };

    homeConfigurations = {
			"ysun@homePC" = home-manager.lib.homeManagerConfiguration {
				pkgs = nixpkgs.legacyPackages.x86_64-linux;
				modules = [
					({ pkgs, ... }: {
						home.packages = [ yazi.packages.${pkgs.system}.default ];
					})
				];
			};
		};
  };
}
