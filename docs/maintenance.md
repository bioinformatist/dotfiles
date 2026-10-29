# Maintenance Guide

#### [中文](maintenance.zh-CN.md) | English

Update a selected flake input when needed, review and commit the changes, then
run `maint-switch` to build and apply the current checkout. An input is a flake
dependency; one input can supply several components, so updating it does not
necessarily change only one application.

## Update on Demand

Renovate is disabled in `renovate.json`. Once that configuration reaches the
default branch, Renovate stops proposing updates and performs its own one-time
cleanup of existing bot work on a subsequent run.

Choose the input to update. If its URL in `flake.nix` pins a revision or tag,
change that pin first. For example, to update `nixpkgs-tools`:

```nu
cd /path/to/dotfiles
with-env (dotfiles-maint-config) {
  nix flake update nixpkgs-tools
}

git diff -- flake.nix flake.lock
git add flake.nix flake.lock
git commit -m "chore: update nixpkgs-tools input"
maint-switch
```

Use `nix flake update INPUT` for another input, replacing `INPUT` with its name.
Stage only the intended changes. Committing before activation makes the change
easy to identify and revert; `maint-switch` does not enforce a clean checkout
or create a commit. It does not pull from Git or update inputs.

Codex runtime packages come from `llm-agents`; the standalone CLI includes its
matching Code Mode Host and is used by terminals, Improve, and doctor. The
desktop launcher selects that CLI through `CODEX_CLI_PATH`. `codex-base`
supplies configuration, Improve, and skills. After updating either input, check
that the selected runtime works with the inherited configuration. A running
desktop application or SSH App Server keeps its backend until restarted.

## Cache and Proxy Configuration

`homePC` and `linglong` select the China-friendly profile:

```nix
dotfiles.nixNetwork.profile = "china";
```

Nix tries USTC first (`priority=10`), the official `cache.nixos.org` cache
second (`priority=40`), then the target's declared third-party caches
(`priority=60`). Lower numbers take priority; caches at the same priority have
no ordering contract. The shared headless profile adds Numtide's cache for
`llm-agents.nix`. Workstations also add Anyrun, Hyprland, and Noctalia Cachix
caches. URLs and signing keys live in `lib/nix-caches.nix`; the global profile
uses the official primary cache.

Nix uses its normal cache selection and metadata lifetimes. If no usable
substitute is available, it may compile from source. `fallback=false` still
prevents a failed substitute download from silently turning into a source
build. Signature checks remain enabled. There is no cache preflight or build
classification gate.

The local proxy is declared in NixOS configuration:

```nix
dotfiles.nixNetwork.proxy = {
  enable = true;
  url = "http://127.0.0.1:7897";
};
```

The proxy feeds `nix-daemon` and `/etc/dotfiles/nix-network.json`, which
`dotfiles-maint-config` reads. USTC is included in `NO_PROXY` for direct access.
The helper applies these values only around the build; activation runs outside
that environment. Desktop sessions do not receive these proxy settings.
Manual input updates use the scoped `with-env` command shown above. A proxy is
not required when the configured sources are reachable directly.

Diagnose network failures by fetch path: Nix substitutes, GitHub source or
release downloads, npm/node-gyp, Cargo, and application traffic use different
paths. A fix for one path does not establish the cause of another failure.

## Local `maint-switch`

```nu
maint-switch
maint-switch --repo /path/to/another/checkout
maint-switch --boot
```

The command reads `dotfiles/maint.nuon` under `XDG_CONFIG_HOME`, or `~/.config`
when that variable is unset. Home Manager writes the repo, host, and parallel
settings there. `--repo` overrides the configured checkout for this call.

It builds the selected host once, with visible logs and lock-file updates
disabled. A successful build must return exactly one nonempty target path.
Only then does it call `sudo nixos-rebuild --no-reexec … --store-path` with
that path. Build failure prevents activation; activation failure is reported
to the caller. The command leaves checkout files unchanged, so host-local
Rime data does not need a maintenance-only commit.

`--boot` installs the generation for the next boot and prints a reboot reminder.
Without that flag, a changed booted kernel or changed NVIDIA userspace selects
`boot` automatically; other changes use `switch` immediately.

The command-level concurrency defaults are `max-jobs=4` and `cores=2`, with
overrides from the maintenance settings. HTTP download concurrency belongs to
the daemon; the NixOS configuration sets `http-connections=8`.

## CI and Downstream Interfaces

The single `maintenance gate` job in
`.github/workflows/maintenance-gate.yml` checks `github.sha` with Nix 2.34.7 and
`NIXPKGS_ALLOW_UNFREE=1`. It pre-evaluates the Hyprland source, runs
`flake check --no-build`, evaluates the synthetic `ci@headless` Home Manager
activation, and builds the existing WeChat controller, Codex adapter, and
repo-local skill checks. These checks belong to CI; a passing run does not
prove a full system build or host activation.

The workflow handles pull requests, merge groups, and manual dispatch. Keep
the existing required check name when changing it. Workflow and Renovate
configuration changes require manual review; this change does not alter branch
protection.

`lib.maintenancePolicyBase` and `lib.extendMaintenancePolicy` remain available
for downstream consumers, backed by `scripts/maint/policy.json`. Upstream CI
and `maint-switch` no longer use them. The desktop policy and combined
`lib.maintenancePolicy` export are removed. Downstreams adopting the new helper
must remove `--no-pull` from manual examples; the helper always uses the
current checkout.

## First Adoption and Recovery

Sourcing `home/shell/nushell/maint.nu` from a new checkout replaces the shell
helper only. The first build still uses the running daemon's cache settings
and trust. New priorities and signing keys take effect after system activation.
The trust transition is tracked in
[#205](https://github.com/bioinformatist/dotfiles/issues/205); do not bypass it
with `sudo build`, temporary trust, or broader `trusted-users`.

Revert the repository change to restore the prior code, or select the previous
NixOS generation to recover an activated system. The on-demand workflow in
[#259](https://github.com/bioinformatist/dotfiles/issues/259) replaces the earlier
requirement to block uncached compilation. The application scope of
[#240](https://github.com/bioinformatist/dotfiles/issues/240) remains separate.
