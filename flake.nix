{
  description = "NixOS configuration of Yu Sun";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    llm-agents.url = "github:numtide/llm-agents.nix";
    ghostty.url = "github:ghostty-org/ghostty/v1.4.0";
    hyprland.url = "github:hyprwm/Hyprland/v0.57.1";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia-d2r = {
      url = "github:bioinformatist/noctalia-d2r";
      flake = false;
    };
    impermanence.url = "github:nix-community/impermanence";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fieldcraft = {
      url = "github:bioinformatist/fieldcraft";
      flake = false;
    };
    codex-base = {
      url = "github:bioinformatist/codex-base";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-tools.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
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
          homeModule ? ./users/${username}/home.nix,
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
              home-manager.users.${username} = import homeModule;
            }
          ];
        };
      repoLocalSkills = [
        {
          name = "product-form-ux";
          source = "${inputs.fieldcraft}/skills/product-form-ux";
        }
      ];
      syncRepoLocalSkillShell =
        targetRoot:
        let
          syncOne =
            skill:
            ''
              sync_skill "${skill.source}" "${skill.name}"
            '';
        in
        ''
          sync_skill() {
            source="$1"
            name="$2"
            target="${targetRoot}/.agents/skills/$name"

            rm -rf "$target"
            mkdir -p "$target"
            cp -R "$source/." "$target/"
            chmod -R u+w "$target"
          }

          ${lib.concatMapStringsSep "\n" syncOne repoLocalSkills}
        '';
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
          communityCodex = inputs.llm-agents.packages.${system}.codex;
          communityChatgpt = inputs.llm-agents.packages.${system}.chatgpt;
          syncVendoredSkills = pkgs.writeShellApplication {
            name = "sync-vendored-skills";
            runtimeInputs = with pkgs; [
              coreutils
              gitMinimal
            ];
            text = ''
              root="$PWD"
              if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
                root="$git_root"
              fi

              ${syncRepoLocalSkillShell "$root"}

              echo "Synced vendored repo-local skills to $root/.agents/skills"
            '';
          };
          syncFieldcraftSkill = pkgs.writeShellApplication {
            name = "sync-fieldcraft-skill";
            runtimeInputs = with pkgs; [
              coreutils
              gitMinimal
            ];
            text = ''
              root="$PWD"
              if git_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
                root="$git_root"
              fi

              source="${inputs.fieldcraft}/skills/product-form-ux"
              target="$root/.agents/skills/product-form-ux"

              rm -rf "$target"
              mkdir -p "$target"
              cp -R "$source/." "$target/"
              chmod -R u+w "$target"

              echo "Synced Fieldcraft product-form-ux skill to $target"
            '';
          };
        in
        (import ./pkgs pkgs)
        // {
          "sync-vendored-skills" = syncVendoredSkills;
          "sync-fieldcraft-skill" = syncFieldcraftSkill;
          codex = communityCodex;
          chatgpt = communityChatgpt.overrideAttrs (old: {
            postFixup = (old.postFixup or "") + ''
              wrapProgram "$out/bin/chatgpt" \
                --set CODEX_CLI_PATH ${lib.getExe communityCodex}
            '';
          });
        }
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
              exec trunk serve --public-url "''${PUBLIC_URL:-/}" --address "''${ADDRESS:-127.0.0.1}" --port "''${PORT:-8080}" --open false "$@"
            '';
          };
          workstationWebFonts = pkgs.makeFontsConf {
            fontDirectories = with pkgs; [
              noto-fonts
              noto-fonts-cjk-sans
              noto-fonts-color-emoji
            ];
          };
          workstationWebChrome = pkgs.writeShellApplication {
            name = "workstation-web-chrome";
            runtimeInputs = with pkgs; [
              chromium
              coreutils
            ];
            text = ''
              export FONTCONFIG_FILE="${workstationWebFonts}"

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
          syncVendoredSkills = self.packages.${system}."sync-vendored-skills";
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
              syncVendoredSkills
            ];
          };

          workstation-web = pkgs.mkShell {
            packages = workstationWebPackages ++ [
              workstationWebServe
            ];
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

      checks = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
          noctaliaPackage =
            self.nixosConfigurations.homePC.config.home-manager.users.ysun.programs.noctalia.package;
          noctaliaConfigSources = {
            homePC =
              self.nixosConfigurations.homePC.config.home-manager.users.ysun.xdg.configFile."noctalia/config.toml".source;
            linglong =
              self.nixosConfigurations.linglong.config.home-manager.users.ysun.xdg.configFile."noctalia/config.toml".source;
          };
          noctaliaDisabledConfigSources = lib.mapAttrs (
            name: _:
            (self.nixosConfigurations.${name}.extendModules {
              modules = [
                {
                  home-manager.users.ysun.dotfiles.noctalia.d2r.enable = lib.mkForce false;
                }
              ];
            }).config.home-manager.users.ysun.xdg.configFile."noctalia/config.toml".source
          ) noctaliaConfigSources;
          noctaliaPaletteSources = {
            homePC =
              self.nixosConfigurations.homePC.config.home-manager.users.ysun.xdg.configFile."noctalia/palettes/dotfiles.json".source;
            linglong =
              self.nixosConfigurations.linglong.config.home-manager.users.ysun.xdg.configFile."noctalia/palettes/dotfiles.json".source;
          };
          homePCCodexConfig = self.nixosConfigurations.homePC.config.home-manager.users.ysun;
          linglongCodexConfig = self.nixosConfigurations.linglong.config.home-manager.users.ysun;
          headlessCodexConfig = self.homeConfigurations."ci@headless".config;
          homePCCodexDisabledConfig =
            (self.nixosConfigurations.homePC.extendModules {
              modules = [
                {
                  home-manager.users.ysun.dotfiles.codex.proxyRecovery.enable = false;
                }
              ];
            }).config.home-manager.users.ysun;
          codexConsumerConfigs = [
            homePCCodexConfig
            linglongCodexConfig
            headlessCodexConfig
          ];
          engineeringPreferencesText = builtins.readFile ./home/programs/codex/engineering-preferences.md;
          engineeringPreferencesIncludedOnce = lib.all (
            consumer:
            builtins.length (
              lib.splitString engineeringPreferencesText consumer.home.file.".codex/AGENTS.md".text
            ) == 2
          ) (codexConsumerConfigs ++ [ homePCCodexDisabledConfig ]);
          baselineRulesPath = ".codex/rules/baseline.rules";
          personalRulesPath = ".codex/rules/personal.rules";
          improveSkillPath = ".agents/skills/improve";
          proxyRecoveryText = builtins.readFile ./home/programs/codex/proxy-recovery.md;
          proxyRecoveryEnabled =
            lib.hasInfix proxyRecoveryText
              homePCCodexConfig.home.file.".codex/AGENTS.md".text;
          proxyRecoveryDisabled =
            !(lib.hasInfix proxyRecoveryText homePCCodexDisabledConfig.home.file.".codex/AGENTS.md".text);
          allCodexBaseConsumersEnabled = lib.all (
            consumer: consumer.programs.codexBase.enable
          ) codexConsumerConfigs;
          personalRulesPresentOnWorkstations =
            builtins.hasAttr personalRulesPath homePCCodexConfig.home.file
            && builtins.hasAttr personalRulesPath linglongCodexConfig.home.file;
          personalRulesAbsentFromHeadless =
            !(builtins.hasAttr personalRulesPath headlessCodexConfig.home.file);
          improvePresentForAllConsumers = lib.all (
            consumer: builtins.hasAttr improveSkillPath consumer.home.file
          ) codexConsumerConfigs;
          baselineRuleSource = homePCCodexConfig.home.file.${baselineRulesPath}.source;
          homePCPersonalRules = homePCCodexConfig.home.file.${personalRulesPath}.source;
          linglongPersonalRules = linglongCodexConfig.home.file.${personalRulesPath}.source;
          improveSkillSources = map (
            consumer: consumer.home.file.${improveSkillPath}.source
          ) codexConsumerConfigs;
        in
        {
          wechat-control =
            pkgs.runCommand "wechat-control-check"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.jq
                  pkgs.shellcheck-minimal
                  pkgs.util-linux
                ];
              }
              ''
                ${lib.getExe pkgs.bash} -n \
                  ${./nixos/wechat-control} \
                  ${./nixos/wechat-control-test}
                shellcheck \
                  ${./nixos/wechat-control} \
                  ${./nixos/wechat-control-test}
                ${lib.getExe pkgs.bash} \
                  ${./nixos/wechat-control-test} \
                  ${./nixos/wechat-control}

                mkdir -p "$out"
                touch "$out/ok"
              '';

          noctalia-config =
            pkgs.runCommand "noctalia-config-check"
              {
                nativeBuildInputs = [
                  noctaliaPackage
                  pkgs.jq
                  pkgs.python3
                ];
              }
              ''
                validate_palette() {
                  name="$1"
                  palette="$2"

                  if ! jq -e '
                    def color:
                      type == "string" and test("^#[0-9A-Fa-f]{6}$");

                    . as $root
                    | ($root.dark | type == "object")
                      and ([
                        "mPrimary",
                        "mOnPrimary",
                        "mSecondary",
                        "mOnSecondary",
                        "mTertiary",
                        "mOnTertiary",
                        "mError",
                        "mOnError",
                        "mSurface",
                        "mOnSurface",
                        "mSurfaceVariant",
                        "mOnSurfaceVariant",
                        "mOutline",
                        "mShadow",
                        "mHover",
                        "mOnHover"
                      ] | all(. as $key | $root.dark[$key] | color))
                      and ($root.dark.terminal | type == "object")
                      and ([
                        "foreground",
                        "background",
                        "cursor",
                        "cursorText",
                        "selectionFg",
                        "selectionBg"
                      ] | all(. as $key | $root.dark.terminal[$key] | color))
                      and ($root.dark.terminal.normal | type == "object")
                      and ($root.dark.terminal.bright | type == "object")
                      and ([
                        "black",
                        "red",
                        "green",
                        "yellow",
                        "blue",
                        "magenta",
                        "cyan",
                        "white"
                      ] | all(
                        . as $key
                        | ($root.dark.terminal.normal[$key] | color)
                          and ($root.dark.terminal.bright[$key] | color)
                      ))
                  ' "$palette" >/dev/null; then
                    echo "Noctalia custom palette validation failed for $name" >&2
                    exit 1
                  fi
                }

                ${lib.getExe noctaliaPackage} plugins lint ${inputs.noctalia-d2r}/d2r-tz

                validate_d2r() {
                  python3 - "$1" "$2" "$3" ${lib.escapeShellArg (toString inputs.noctalia-d2r)} <<'PY'
                import copy
                import sys
                import tomllib

                name, on_path, off_path, plugin_path = sys.argv[1:]
                with open(on_path, "rb") as f:
                    on = tomllib.load(f)
                with open(off_path, "rb") as f:
                    off = tomllib.load(f)

                sources = on["plugins"]["source"]
                d2r = {"name": "noctalia-d2r", "kind": "path", "location": plugin_path, "enabled": True}
                assert d2r in sources, f"{name}: D2R plugin source missing"
                assert on["plugins"]["enabled"].count("bioinformatist/d2r-tz") == 1, name
                assert on["widget"]["d2r-tz"] == {"type": "bioinformatist/d2r-tz:tz"}, name
                center = on["bar"]["main"]["center"]
                assert center.count("d2r-tz") == 1, name

                assert "plugins" not in off, f"{name}: disabled source remains"
                assert "d2r-tz" not in off.get("widget", {}), name
                assert "d2r-tz" not in off["bar"]["main"]["center"], name
                assert "bioinformatist/d2r-tz" not in off.get("plugin_settings", {}), name

                without_d2r = copy.deepcopy(on)
                del without_d2r["plugins"]
                del without_d2r["widget"]["d2r-tz"]
                without_d2r["bar"]["main"]["center"].remove("d2r-tz")
                del without_d2r["plugin_settings"]["bioinformatist/d2r-tz"]
                if not without_d2r["plugin_settings"]:
                    del without_d2r["plugin_settings"]
                assert without_d2r == off, f"{name}: unrelated settings changed"
                PY
                }

                ${lib.concatStringsSep "\n" (
                  lib.mapAttrsToList (
                    name: source:
                    "validate_d2r ${lib.escapeShellArg name} ${lib.escapeShellArg (toString source)} ${
                      lib.escapeShellArg (toString noctaliaDisabledConfigSources.${name})
                    }"
                  ) noctaliaConfigSources
                )}
                ${lib.concatStringsSep "\n" (
                  lib.mapAttrsToList (
                    name: source: "validate_palette ${lib.escapeShellArg name} ${lib.escapeShellArg (toString source)}"
                  ) noctaliaPaletteSources
                )}

                mkdir -p "$out"
                touch "$out/ok"
              '';

          repo-local-skills = pkgs.runCommand "repo-local-skills-check" { } ''
            expected="$TMPDIR/expected"
            mkdir -p "$expected"
            ${syncRepoLocalSkillShell "$expected"}

            for skill_dir in ${./.agents/skills}/*; do
              test -d "$skill_dir" || continue
              skill_name="$(basename "$skill_dir")"
              test -f "$skill_dir/SKILL.md" || {
                echo "$skill_name is missing SKILL.md" >&2
                exit 1
              }
              test -f "$skill_dir/agents/openai.yaml" || {
                echo "$skill_name is missing agents/openai.yaml" >&2
                exit 1
              }
              grep -q "^name: $skill_name$" "$skill_dir/SKILL.md" || {
                echo "$skill_name SKILL.md name does not match directory" >&2
                exit 1
              }
              grep -q "^description: .*$" "$skill_dir/SKILL.md" || {
                echo "$skill_name SKILL.md is missing description" >&2
                exit 1
              }
            done

            if grep -R -n -E \
              '(/codebase-design|/grilling|/domain-modeling|/improve-codebase-architecture|Agent tool|subagent_type|xdg-open <path>|open <path>|start <path>)' \
              ${./.agents/skills}; then
              echo "repo-local skills contain stale host-agent wording; adapt vendored skills for Codex first" >&2
              exit 1
            fi

            ${lib.concatMapStringsSep "\n" (skill: ''
              diff -ru "$expected/.agents/skills/${skill.name}" "${./.agents/skills}/${skill.name}"
            '') repoLocalSkills}

            mkdir -p "$out"
            touch "$out/ok"
          '';

          codex-base-adapter =
            assert homePCCodexConfig.programs.codexBase.package == self.packages.${system}.codex;
            assert linglongCodexConfig.programs.codexBase.package == self.packages.${system}.codex;
            assert headlessCodexConfig.programs.codexBase.package == self.packages.${system}.codex;
            assert
              homePCCodexConfig.xdg.mimeApps.defaultApplications."x-scheme-handler/https"
              == [ "google-chrome.desktop" ];
            assert
              linglongCodexConfig.xdg.mimeApps.defaultApplications."x-scheme-handler/https"
              == [ "google-chrome.desktop" ];
            assert
              homePCCodexConfig.xdg.mimeApps.defaultApplications."x-scheme-handler/codex"
              == [ "chatgpt.desktop" ];
            assert
              linglongCodexConfig.xdg.mimeApps.defaultApplications."x-scheme-handler/codex"
              == [ "chatgpt.desktop" ];
            assert builtins.elem self.packages.${system}.chatgpt homePCCodexConfig.home.packages;
            assert builtins.elem self.packages.${system}.chatgpt linglongCodexConfig.home.packages;
            assert !(builtins.elem self.packages.${system}.chatgpt headlessCodexConfig.home.packages);
            pkgs.runCommand "codex-base-adapter-check"
              {
                inherit
                  baselineRuleSource
                  homePCPersonalRules
                  improveSkillSources
                  linglongPersonalRules
                  ;
                nativeBuildInputs = [
                  pkgs.coreutils
                  pkgs.diffutils
                  pkgs.gnugrep
                ];
              }
              ''
                ${lib.optionalString (!allCodexBaseConsumersEnabled) ''
                  echo "codex-base is not enabled for every maintained Codex consumer" >&2
                  exit 1
                ''}
                ${lib.optionalString (!personalRulesPresentOnWorkstations) ''
                  echo "personal Codex rules are missing from a ysun workstation" >&2
                  exit 1
                ''}
                ${lib.optionalString (!personalRulesAbsentFromHeadless) ''
                  echo "personal Codex rules leaked into ci@headless" >&2
                  exit 1
                ''}
                ${lib.optionalString (!improvePresentForAllConsumers) ''
                  echo "the inherited Improve skill is missing from a maintained Codex consumer" >&2
                  exit 1
                ''}
                ${lib.optionalString (!proxyRecoveryEnabled || !proxyRecoveryDisabled) ''
                  echo "proxy recovery instructions do not follow the workstation switch" >&2
                  exit 1
                ''}
                ${lib.optionalString (!engineeringPreferencesIncludedOnce) ''
                  echo "engineering preferences are missing or duplicated for a Codex consumer" >&2
                  exit 1
                ''}

                cmp "$homePCPersonalRules" "$linglongPersonalRules"

                cat "$baselineRuleSource" "$homePCPersonalRules" > "$TMPDIR/combined.rules"
                if sort "$TMPDIR/combined.rules" | uniq -d | grep -q .; then
                  echo "the public and personal Codex rule sets overlap" >&2
                  exit 1
                fi

                for skill in $improveSkillSources; do
                  test -f "$skill/SKILL.md"
                  test -f "$skill/references/planning-contract.md"
                done

                mkdir -p "$out"
                touch "$out/ok"
              '';
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
        linglong = mkHost {
          hostDir = "linglong";
          username = "ysun";
          homeModule = ./users/ysun/linglong-home.nix;
        };
      };

      homeConfigurations =
        let
          mkHomePkgs = import nixpkgs {
            system = "x86_64-linux";
            overlays = [
              overlays.additions
              overlays.modifications
            ];
          };
          mkHome =
            username:
            home-manager.lib.homeManagerConfiguration {
              pkgs = mkHomePkgs;
              extraSpecialArgs = inputs // {
                inherit username;
              };
              modules = [
                ./home/shared.nix
              ];
            };
          mkHeadlessHome =
            username:
            home-manager.lib.homeManagerConfiguration {
              pkgs = mkHomePkgs;
              extraSpecialArgs = inputs // {
                inherit username;
              };
              modules = [
                homeManagerModules.devHeadless
              ];
            };
        in
        {
          "ysun@homePC" = mkHome "ysun";
          "ci@headless" = mkHeadlessHome "ci";
        };
    };
}
