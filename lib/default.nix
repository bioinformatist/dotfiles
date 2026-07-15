{
  inputs,
  profiles,
  nixosModules,
  homeManagerModules,
}:

let
  lib = inputs.nixpkgs.lib;
  maintenancePolicyBase = builtins.fromJSON (builtins.readFile ../scripts/maint/policy.json);
  workstationPolicy = builtins.fromJSON (builtins.readFile ../scripts/maint/policy-workstation.json);
  extendMaintenancePolicy =
    base: overlay:
    (base // overlay)
    // {
      riskMarkers = lib.unique ((base.riskMarkers or [ ]) ++ (overlay.riskMarkers or [ ]));
      allowedLocalBuildMarkers = lib.unique (
        (base.allowedLocalBuildMarkers or [ ]) ++ (overlay.allowedLocalBuildMarkers or [ ])
      );
      allowedDirectFetchMarkers = lib.unique (
        (base.allowedDirectFetchMarkers or [ ]) ++ (overlay.allowedDirectFetchMarkers or [ ])
      );
      leafDirectFetchMarkers =
        (base.leafDirectFetchMarkers or { }) // (overlay.leafDirectFetchMarkers or { });
    };
in
{
  versions = import ./versions.nix;

  inherit
    extendMaintenancePolicy
    maintenancePolicyBase
    ;

  maintenancePolicy = extendMaintenancePolicy maintenancePolicyBase workstationPolicy;

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
