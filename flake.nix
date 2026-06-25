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
    fieldcraft = {
      url = "github:bioinformatist/fieldcraft";
      flake = false;
    };
    mattpocock-skills = {
      url = "github:mattpocock/skills/v1.0.1";
      flake = false;
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
      repoLocalSkills = [
        {
          name = "product-form-ux";
          source = "${inputs.fieldcraft}/skills/product-form-ux";
        }
        {
          name = "domain-modeling";
          source = "${inputs.mattpocock-skills}/skills/engineering/domain-modeling";
          openaiYaml = ''
            interface:
              display_name: "Domain Modeling"
              short_description: "Sharpen dotfiles domain terms and ADRs"
              default_prompt: "Use $domain-modeling to clarify dotfiles domain terms or record an ADR-worthy decision."

            policy:
              allow_implicit_invocation: true
          '';
        }
        {
          name = "grill-with-docs";
          source = "${inputs.mattpocock-skills}/skills/engineering/grill-with-docs";
          skillMd = ''
            ---
            name: grill-with-docs
            description: Explicit-only dotfiles design interview that stress-tests a plan while maintaining domain docs. Use only when the user explicitly invokes grill-with-docs or asks to stress-test a dotfiles design with docs.
            ---

            # Grill With Docs

            This repo-local wrapper expects `dotfiles.codex.mattPocockSkills.enable`
            to stay enabled for `homePC`; that global skill subset provides the
            `$grilling` dependency used by this workflow.

            Run `$grilling` to stress-test the user's dotfiles design one question
            at a time. Keep `$domain-modeling` active as decisions settle:

            - Update `CONTEXT.md` when a durable dotfiles domain term is introduced
              or sharpened.
            - Offer an ADR only when the decision is hard to reverse, surprising
              without context, and the result of a real tradeoff.
            - Keep implementation work out of the grilling loop unless the user
              explicitly asks to proceed.
          '';
          openaiYaml = ''
            interface:
              display_name: "Grill With Docs"
              short_description: "Stress-test a plan and update domain docs"
              default_prompt: "Use $grill-with-docs to interview a dotfiles design and update domain docs as decisions settle."

            policy:
              allow_implicit_invocation: false
          '';
        }
        {
          name = "improve-codebase-architecture";
          source = "${inputs.mattpocock-skills}/skills/engineering/improve-codebase-architecture";
          skillMd = ''
            ---
            name: improve-codebase-architecture
            description: Explicit-only dotfiles architecture review that scans for deepening opportunities and writes a temporary visual report. Use only when the user explicitly invokes improve-codebase-architecture or asks for a dotfiles architecture review.
            ---

            # Improve Codebase Architecture

            This repo-local wrapper expects `dotfiles.codex.mattPocockSkills.enable`
            to stay enabled for `homePC`; that global skill subset provides the
            `$codebase-design` and `$grilling` dependencies used by this workflow.

            Surface architectural friction in this dotfiles repo and propose
            deepening opportunities: changes that make modules smaller at the
            interface and deeper in implementation.

            ## Process

            1. Read `CONTEXT.md` and any relevant ADRs before judging the code.
               Use `$codebase-design` for the architecture vocabulary.
            2. Explore with normal Codex tools. Use available multi-agent tooling
               when it is actually present; otherwise inspect the code directly and
               make distinct candidates yourself.
            3. Write a self-contained HTML report under the OS temp directory:
               `$TMPDIR` when set, otherwise `/tmp`, using
               `architecture-review-<timestamp>.html`.
            4. Tell the user the absolute report path. Open a GUI viewer only when
               the user explicitly asks.
            5. For each candidate include files, problem, solution, benefits,
               before/after diagram, and recommendation strength.
            6. End with the top recommendation, then ask which candidate the user
               wants to explore.

            After the user picks a candidate, use `$grilling` to walk the design
            tree with them. Use `$domain-modeling` to update `CONTEXT.md` or offer
            an ADR when the conversation produces durable domain terms or decisions.

            See [HTML-REPORT.md](HTML-REPORT.md) for the report scaffold, diagram
            patterns, and styling guidance.
          '';
          htmlReportMd = builtins.replaceStrings [ "/codebase-design" ] [ "$codebase-design" ] (
            builtins.readFile "${inputs.mattpocock-skills}/skills/engineering/improve-codebase-architecture/HTML-REPORT.md"
          );
          openaiYaml = ''
            interface:
              display_name: "Improve Codebase Architecture"
              short_description: "Review dotfiles architecture with visual candidates"
              default_prompt: "Use $improve-codebase-architecture to scan this dotfiles repo for architecture deepening opportunities."

            policy:
              allow_implicit_invocation: false
          '';
        }
      ];
      syncRepoLocalSkillShell =
        targetRoot:
        let
          syncOne =
            skill:
            ''
              sync_skill "${skill.source}" "${skill.name}"
            ''
            + lib.optionalString (skill ? skillMd) ''
              cp ${builtins.toFile "${skill.name}-SKILL.md" skill.skillMd} "$target/SKILL.md"
            ''
            + lib.optionalString (skill ? htmlReportMd) ''
              cp ${builtins.toFile "${skill.name}-HTML-REPORT.md" skill.htmlReportMd} "$target/HTML-REPORT.md"
            ''
            + lib.optionalString (skill ? openaiYaml) ''
              mkdir -p "$target/agents"
              cat > "$target/agents/openai.yaml" <<'YAML'
              ${skill.openaiYaml}YAML
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
          globalMattPocockSkillsEnabled =
            self.nixosConfigurations.homePC.config.home-manager.users.ysun.dotfiles.codex.mattPocockSkills.enable;
        in
        {
          repo-local-skills = pkgs.runCommand "repo-local-skills-check" { } ''
            ${lib.optionalString (!globalMattPocockSkillsEnabled) ''
              echo "repo-local Matt Pocock workflow skills require dotfiles.codex.mattPocockSkills.enable for homePC" >&2
              exit 1
            ''}

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

            for stray_doc in $(find ${./.agents/skills} -mindepth 2 -maxdepth 2 \
              \( -name README.md -o -name INSTALLATION_GUIDE.md -o -name QUICK_REFERENCE.md -o -name CHANGELOG.md \)); do
              echo "unexpected auxiliary skill doc: $stray_doc" >&2
              exit 1
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
