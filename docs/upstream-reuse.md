# Upstream Reuse

This repository now exposes a stable upstream boundary for downstream dotfiles or product repos.

## Public outputs

Downstream repositories should only consume these flake outputs:

- `profiles.headless`
- `profiles.ai-serving`
- `profiles.workstation`
- `nixosModules.{headless,ai-serving,nixNetwork,nvidiaDesktop,workstation}`
- `homeManagerModules.{core,tui,codex,devHeadless,workstation}`
- `lib.{versions,mkWorkstationSystem}`
- `overlays`
- `packages`
- `templates.workstation`

Do not import internal paths like `./nixos/*.nix`, `./home/*.nix`, or `./hosts/*` from downstream.

## Profile boundaries

`profiles.headless` provides the reusable base layer:

- Nix settings and cache keys
- OpenSSH and GitHub SSH host policy
- a normal user defined by `specialArgs.username`
- sudo policy and core system defaults
- optional automatic password wiring when `${username}-password` exists under `sops.secrets`

It does not include:

- Hyprland or GUI applications
- PipeWire, Bluetooth, or input methods
- company secrets
- host-specific business services

`profiles.ai-serving` only provides GPU host capability:

- NVIDIA driver host support
- Docker
- NVIDIA container toolkit for Docker GPU workloads
- generic runtime directories under `/var/lib/ai-serving`

It does not include CUDA userspace or model-serving application stacks.

`profiles.workstation` provides the development workstation system layer:

- `profiles.headless`
- Hyprland / PipeWire / Fcitx5 + Rime / CJK fonts
- WeChat, screenshot tools, and baseline GUI tools

It does not include:

- disk layout
- China network/proxy defaults
- Clash Verge unless `dotfiles.workstation.clash.enable = true` is set explicitly
- sops secrets
- personal account content beyond the configured username
- NVIDIA desktop patches
- ZeroClaw, D2R, company SSH, or business services

NVIDIA desktop hosts should explicitly add `nixosModules.nvidiaDesktop`.

## Current host composition

The personal hosts in this repo stay full-featured by composing extra local modules:

- `homePC`: `profiles.workstation` + China network/proxy settings + Clash Verge + NVIDIA desktop integration + personal Home Manager layer

## Downstream example

```nix
{
  inputs.upstream.url = "github:bioinformatist/dotfiles";

  outputs = { self, nixpkgs, upstream, ... }: {
    nixosConfigurations."116" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        username = "ops";
      };
      modules = [
        upstream.profiles.headless
        upstream.profiles.ai-serving
        ./hosts/116
      ];
    };
  };
}
```

If the downstream repo uses `sops-nix`, defining `sops.secrets."ops-password"` will automatically feed the user password into `profiles.headless`. Otherwise, set the user password in downstream code by some other mechanism.

## 116 ownership split

This upstream repo is responsible for the reusable headless and GPU-host layers.

The downstream company repo should own:

- the `116` host module
- `disko` layout for the system SSD
- `/data1` mdraid assembly and mount declarations
- sops secrets and access policy
- `jarvis*` Docker service definitions
- `nixos-anywhere` install orchestration

## 116 install shape

For 116, the intended downstream install flow is:

1. connect to the existing machine over SSH
2. run `nixos-anywhere`
3. let `disko` rebuild only the system SSD
4. preserve and remount the existing `/data1`
5. place the sops age key under both `/mnt/persist/var/lib/sops-nix/key.txt` and `/mnt/var/lib/sops-nix/key.txt`

The downstream repo should keep `/data1` declarative at the mount/assembly layer only in phase one; it should not try to recreate the RAID layout yet.
