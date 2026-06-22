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
    yazelix.url = "github:luccahuguet/yazelix";
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
      dotfilesLib = import ./lib {
        inherit
          inputs
          profiles
          nixosModules
          homeManagerModules
          ;
      };
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
      lib = dotfilesLib;

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

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
          workstationWebPackages = with pkgs; [
            binaryen
            cargo
            clippy
            lld
            rustc
            rustfmt
            trunk
            wasm-bindgen-cli
          ];
          workstationWebServe = pkgs.writeShellApplication {
            name = "workstation-web-serve";
            runtimeInputs = with pkgs; [
              gitMinimal
              trunk
            ];
            text = ''
              root="$PWD"
              if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
                root="$git_root"
              fi

              app_dir="$root/web/workstation"
              if [ ! -d "$app_dir" ]; then
                echo "web/workstation not found under $root" >&2
                exit 1
              fi

              cd "$app_dir"
              # Trunk 0.21 parses NO_COLOR as a boolean and rejects the common
              # NO_COLOR=1 convention used by Codex shells.
              unset NO_COLOR
              exec trunk serve --address 127.0.0.1 --port "''${PORT:-8080}" --open false "$@"
            '';
          };
          workstationWebChrome = pkgs.writeShellApplication {
            name = "workstation-web-chrome";
            runtimeInputs = with pkgs; [
              chromium
              coreutils
            ];
            text = ''
              export FONTCONFIG_FILE="${pkgs.fontconfig.out}/etc/fonts/fonts.conf"

              url="http://127.0.0.1:''${PORT:-8080}/"
              if [ "$#" -gt 0 ] && [[ "$1" != -* ]]; then
                url="$1"
                shift
              fi

              profile_dir="$(mktemp -d -t workstation-web-chrome.XXXXXX)"
              cleanup() {
                rm -rf "$profile_dir"
              }
              finish() {
                status=$?
                cleanup
                exit "$status"
              }
              trap finish EXIT

              sandbox_flags=()
              if [ "''${WORKSTATION_WEB_CHROME_NO_SANDBOX:-}" = "1" ]; then
                sandbox_flags+=(--no-sandbox)
              fi

              chromium \
                --headless=new \
                --remote-debugging-address=127.0.0.1 \
                --remote-debugging-port="''${CDP_PORT:-9222}" \
                --user-data-dir="$profile_dir" \
                --window-size="''${WINDOW_SIZE:-1440,1000}" \
                --no-first-run \
                --no-default-browser-check \
                --disable-dev-shm-usage \
                --disable-background-networking \
                --disable-sync \
                "''${sandbox_flags[@]}" \
                "$@" \
                "$url"
            '';
          };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              actionlint
              binaryen
              cargo
              clippy
              jq
              lld
              nil
              nixfmt
              rustc
              rustfmt
              trunk
              wasm-bindgen-cli
            ];
          };

          workstation-web = pkgs.mkShell {
            packages = workstationWebPackages;
          };

          workstation-web-browser = pkgs.mkShell {
            packages = workstationWebPackages ++ [
              pkgs.chromium
              workstationWebServe
              workstationWebChrome
            ];
          };
        }
      );

      templates.workstation = {
        path = ./templates/workstation;
        description = "NixOS workstation starter";
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
