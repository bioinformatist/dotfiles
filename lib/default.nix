{
  inputs,
  profiles,
  nixosModules,
  homeManagerModules,
}:

{
  versions = import ./versions.nix;

  mkWorkstationSystem =
    {
      username,
      system ? "x86_64-linux",
      modules ? [ ],
      homeModules ? [ ],
    }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit inputs username;
      };
      modules = [
        inputs.disko.nixosModules.disko
        inputs.home-manager.nixosModules.home-manager
        profiles.workstation
        nixosModules.nixNetwork
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = inputs // {
            inherit username;
          };
          home-manager.users.${username}.imports = [
            homeManagerModules.workstation
          ]
          ++ homeModules;
        }
      ]
      ++ modules;
    };
}
