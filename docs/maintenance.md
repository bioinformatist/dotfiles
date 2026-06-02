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
- Codex and ZeroClaw release hashes come from GitHub's release asset digest, so the update helper does not download tarballs just to compute hashes
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
- Keep Home Manager release-aligned with the current Nixpkgs release number.
  This system may use `nixos-unstable`, but if Nixpkgs reports `26.05`,
  Home Manager should use `release-26.05` rather than `master`. Do not silence
  release mismatch warnings with `home.enableNixpkgsReleaseCheck = false`.
- Always run `maint-check` before `maint-switch`.
- If `maint-check` reports `will be built`, prefer waiting and trying again later instead of compiling locally.

## Update Commands

### `maint-update-tools`

Updates the lower-risk tool layer:

- flake input: `nixpkgs-wechat` for WeChat
- flake input: `anyrun` for Anyrun
- local Codex release pin in [home/programs/codex/default.nix](/home/ysun/github.com/bioinformatist/dotfiles/home/programs/codex/default.nix)
- local ZeroClaw release pin in [home/programs/zeroclaw/default.nix](/home/ysun/github.com/bioinformatist/dotfiles/home/programs/zeroclaw/default.nix)

This is the normal entry point when you want binary-friendly tools to stay fresh without pushing the whole system base forward. WeChat uses a dedicated nixpkgs input so it can move independently. Anyrun uses its upstream flake input so it can move independently while using the upstream binary cache. Yazi follows `nixpkgs-tools`.

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

This is the riskiest update category because it can pull in a new kernel / NVIDIA combination. When bumping this layer, keep the Home Manager branch matched to the Nixpkgs release reported by the target system, for example `release-26.05` with a `26.05` Nixpkgs.

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

Builds the target system using the current lock state, then chooses a safe
activation mode.

```nu
maint-switch
```

`maint-switch` does not update any inputs by itself. It only applies the state currently recorded in the repository.

Before activating, it compares the target system with the booted system:

- If the booted kernel changes, it runs `nixos-rebuild boot` and asks you to reboot.
- If the NVIDIA userspace changes, it also runs `nixos-rebuild boot` and asks you to reboot.
- Otherwise it runs the normal `nixos-rebuild switch`.

This avoids hot-switching into a mixed kernel/NVIDIA/Hyprland runtime, which can
break the running Wayland session.

## Recommended Workflow

### Tool-layer refresh

Use this when you mainly care about binary-friendly tool pins such as Codex, ZeroClaw, WeChat, and Anyrun. Yazi follows `nixpkgs-tools`.

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

If the check shows `nvidia-x11`, `linux-`, or other heavy components under `will be built`, stop if you do not want to accept those updates yet. If you continue, `maint-switch` will use boot activation instead of hot switch when kernel or NVIDIA changes require it.

## Notes

- The maintenance helpers assume the current host is `homePC`.
- `~/.config/nix/` is persisted on `homePC`, so `local-proxy.nuon` survives reboot once created.
