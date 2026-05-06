# Maintenance Guide

#### [中文](maintenance.zh-CN.md) | English

This guide covers the **preferred maintenance workflow** for this system:

- keep day-to-day tools reasonably fresh
- avoid local compilation whenever possible
- treat `hyprland` and `nixpkgs` as separate, higher-risk updates

The commands below are provided by Nushell functions defined in [home/shell/nushell/config.nu](/home/ysun/github.com/bioinformatist/dotfiles/home/shell/nushell/config.nu).

## Local Proxy Config

All maintenance commands and `nix-daemon` now read network settings from a single local file:

`~/.config/nix/local-proxy.nuon`

This file is intentionally not tracked by git. Example:

```nushell
{
  HTTP_PROXY: "http://192.168.0.116:7890",
  HTTPS_PROXY: "http://192.168.0.116:7890",
  NO_PROXY: "mirrors.ustc.edu.cn,cache.nixos.org,127.0.0.1,localhost",
  substituters: [
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://cache.nixos.org"
  ]
}
```

Meaning:

- maintenance helpers use this file for GitHub API requests
- Codex release hashes come from GitHub's release asset digest, so the update helper does not download the tarball just to compute a hash
- `nix-daemon` uses the same file for proxy, `NO_PROXY`, and `substituters`
- changing the proxy address only requires editing this one file

After changing this file, restart the daemon once so new daemon-side settings take effect:

```nu
sudo systemctl restart nix-daemon
```

## Principles

- Do **not** use `nix flake update` as a routine one-shot update command.
- Update tool-layer components separately from `hyprland`.
- Update `hyprland` separately from the base system (`nixpkgs` / `home-manager`).
- Always run `maint-check` before `maint-switch`.
- If `maint-check` reports `will be built`, prefer waiting and trying again later instead of compiling locally.

## Update Commands

### `maint-update-tools`

Updates the lower-risk tool layer:

- flake inputs: `zeroclaw`, `antigravity`
- local Codex release pin in [home/programs/codex/default.nix](/home/ysun/github.com/bioinformatist/dotfiles/home/programs/codex/default.nix)

This is the normal entry point when you want binary-friendly tools to stay fresh without pushing the whole system base forward. Yazi and Anyrun intentionally follow nixpkgs instead of separate source flake inputs.

```nu
maint-update-tools
```

### `maint-update-infra`

Updates low-frequency infrastructure inputs:

- `sops-nix`
- `impermanence`
- `disko`

This path may build local helper programs, so use it during an infrastructure maintenance window instead of the routine tool refresh.

```nu
maint-update-infra
```

### `maint-update-hyprland`

Updates only the standalone `hyprland` flake input.

```nu
maint-update-hyprland
```

### `maint-update-base`

Updates only the base system inputs:

- `nixpkgs`
- `home-manager`

This is the riskiest update category because it can pull in a new kernel / NVIDIA combination.

```nu
maint-update-base
```

### `maint-check`

Runs a dry-run build of:

```text
.#nixosConfigurations.homePC.config.system.build.toplevel
```

and then appends a summary.

```nu
maint-check
```

The summary intentionally focuses on:

- whether `will be built` was detected
- whether high-risk markers such as `nvidia-x11`, `linux-`, or `hyprland` appeared

If `will be built` is detected, the summary explicitly recommends **not** rebuilding yet.

### `maint-switch`

Performs the actual rebuild and switch using the current lock state.

```nu
maint-switch
```

`maint-switch` does not update any inputs by itself. It only applies the state currently recorded in the repository.

## Recommended Workflow

### Tool-layer refresh

Use this when you mainly care about binary-friendly tool pins such as Codex, ZeroClaw, and Antigravity. Yazi and Anyrun follow nixpkgs.

```nu
maint-update-tools
maint-check
maint-switch
```

Stop after `maint-check` if it reports `will be built`.

### Infrastructure refresh

Use this when you intentionally want newer secret, persistence, or partitioning infrastructure.

```nu
maint-update-infra
maint-check
maint-switch
```

Stop after `maint-check` if it shows local helper builds you do not want to accept yet.

### Hyprland refresh

Use this when you specifically want newer Hyprland bits.

```nu
maint-update-hyprland
maint-check
maint-switch
```

If the check shows a large `hypr*` build, stop and wait for caches to catch up.

### Base system refresh

Use this when you intentionally want newer `nixpkgs` / `home-manager`.

```nu
maint-update-base
maint-check
maint-switch
```

If the check shows `nvidia-x11`, `linux-`, or other heavy components under `will be built`, stop and retry later.

## Notes

- `claude-code` follows `pkgs.claude-code`, so it moves with `nixpkgs` and therefore belongs to `maint-update-base`, not `maint-update-tools`.
- The maintenance helpers assume the current host is `homePC`.
- `~/.config/nix/` is persisted on `homePC`, so `local-proxy.nuon` survives reboot once created.
