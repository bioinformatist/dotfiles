# Maintenance Guide

#### [中文](maintenance.zh-CN.md) | English

The preferred local maintenance entry point is still:

```nu
maint-switch
```

Renovate proposes root `flake.lock` input updates. After they reach `main`, `maint-switch` performs the final China-network gate and system activation.

## Declarative Network Profile

`homePC` and `linglong` select the China-friendly profile:

```nix
dotfiles.nixNetwork.profile = "china";
```

Nix tries USTC first (`priority=10`), the official `cache.nixos.org` cache
second (`priority=40`), then the target's declared third-party caches
(`priority=60`). Lower priority numbers win; caches at the same priority have
no ordering contract. The shared headless profile adds Numtide's cache for
`llm-agents.nix` packages. Workstations also add Anyrun, Hyprland, and Noctalia
Cachix caches. URLs and public signing keys are maintained in
`lib/nix-caches.nix`; the global profile uses the official primary cache.

Nix keeps its default metadata-cache lifetimes. `fallback=false` prevents a
failed substitute download from silently turning into a source build. Signature
checks remain enabled. The local proxy URL is declared in NixOS config:

```nix
dotfiles.nixNetwork.proxy = {
  enable = true;
  url = "http://127.0.0.1:7897";
};
```

This proxy is intentionally scoped to Nix maintenance paths. It is injected into `nix-daemon`, and the same values are exported to `/etc/dotfiles/nix-network.json` for `maint-switch`. It is not a desktop/session proxy.

## Automated Update PRs

`renovate.json` lets Renovate propose one root flake input per PR:

| Leaf | Policy | What it updates |
|---|---|---|
| `anyrun` | `tools` | `anyrun` flake input |
| `codex-base` | `tools` | Codex Base configuration, Improve, and global skills |
| `llm-agents` | `tools` | Community standalone CLI and desktop packages |
| `nixpkgs-tools` | `tools` | `nixpkgs-tools` flake input |
| `wechat` | `tools` | `nixpkgs-wechat` flake input |
| `nixpkgs-desktop` | `desktop` | Hyprland and its portal from the pinned `nixpkgs-desktop` input |
| `noctalia` | `desktop` | Noctalia stable release input |
| `sops-nix` | `infra` | `sops-nix` flake input |
| `impermanence` | `infra` | `impermanence` flake input |
| `disko` | `infra` | `disko` flake input |
| `base` | `core` | `nixpkgs`, `home-manager` |

Default cadence:

| Policy | Schedule |
|---|---|
| `tools` | daily |
| `desktop` | Saturdays UTC |
| `infra` | first day of each month UTC |
| `core` | first day of each month UTC |

Root inputs outside this table, currently `fieldcraft`, `mattpocock-skills`, and `swww`, are intentionally not updated by Renovate until they are promoted to an explicit policy.
Renovate `lockFileMaintenance` is disabled because whole-lock refreshes would
mix multiple leaves into one PR and weaken cache-miss attribution.

Codex runtime packages come from `llm-agents`: the standalone CLI includes its
matching Code Mode Host and is used by terminals, Improve, and doctor on both
headless and desktop hosts. The desktop launcher selects that CLI through
`CODEX_CLI_PATH`. `codex-base` supplies configuration, Improve, and skills.
Renovate updates these two root inputs separately; after either update, check
the selected runtime against the inherited configuration and workflows. A
running desktop application or SSH App Server keeps its current backend until
restarted.

The default branch should be protected by a ruleset that requires pull requests and requires the `maintenance gate` status check with strict up-to-date checks enabled.

The required `maintenance gate` check summarizes two jobs. `configuration` runs
native flake evaluation, evaluates the synthetic `ci@headless` Home Manager
activation, builds the existing WeChat controller, Codex adapter, and repo-local
skill checks, and runs the shared preflight tests. `cache-preflight` checks the
complete candidate at `github.sha` for `homePC`, `linglong`, and `ci@headless`.
Both jobs use Nix 2.34.7. A failed or inconclusive job blocks the required check.
These checks run in CI; local verification covers the Nu entry point with
`bash scripts/maint/test-cache-preflight.sh --local-maint` and mocked build/sudo.

The preflight reads each target's evaluated cache URLs and trusted public keys.
Targets with identical caches, keys, and policy share one native multi-target
dry-run in a fresh isolated store. Runner-installed packages cannot hide
missing substitutes. Nix plans runtime references and any required build
dependencies; the gate classifies every planned local build. Existing and new
unapproved compilation both block. USTC availability is not required when a
later trusted source can supply the path. There is no base comparison, second
mirror scan, or per-archive HTTP probe.

The preflight requires valid JSON roots covering every target and a complete,
nonempty build/fetch plan from Nix's `internal-json` diagnostics. Truncated or
unknown output, failed queries, and unresolved references cannot pass. A warning
followed by a complete recovered plan does not by itself fail the gate. Results
are `pass`, `blocked`, or `inconclusive`; summaries, full path lists, target/group
mappings, and raw logs are uploaded even on failure. “No usable substitute”
describes the current Nix plan, not proof that every remote cache lacks a path.

This is metadata preflight. It does not download every archive or prove that
those downloads and signature checks will succeed on a host. Actual downloads
and host activation require separate acceptance. Some unfree software has no
redistributable binary cache; it needs a reviewed vendor-binary fetch/wrapper or
remains blocked. CI permits evaluating unfree packages with
`NIXPKGS_ALLOW_UNFREE=1`; that does not exempt source compilation.

The reusable policy lives in `scripts/maint/policy.json`; workstation additions
live in `scripts/maint/policy-workstation.json`. Desktop CI and local
`maint-switch` use the exported `lib.maintenancePolicy`; synthetic headless CI
uses `lib.maintenancePolicyBase` and has no desktop cache additions. Both entry
points share `nix-plan.jq` and `classify-plan.jq`. Downstreams continue to extend
`lib.maintenancePolicyBase` with `lib.extendMaintenancePolicy`. Direct-fetch
leaf restrictions take the intersection with the general direct-fetch policy.

As decided in [#259](https://github.com/bioinformatist/dotfiles/issues/259),
older cached versions are verified and pinned during input updates. The gate
does not search for another version or rewrite the lock file. The application
scope in [#240](https://github.com/bioinformatist/dotfiles/issues/240) remains
separate work.

The marker policy is intentionally empirical. It should be refined from real
misses: broad generated-glue markers such as `unit-`, `-etc-`, and
`nixos-system-` may be tightened if they misclassify a derivation, and new
release-tarball leaves must be declared explicitly before their direct fetches
are allowed.

If a local gate blocks a clearly generated NixOS/Home Manager glue derivation,
such as environment-file or activation glue, treat it as policy drift. Update
the shared base or the owning overlay narrowly; downstream repositories should
refresh their upstream input, not copy the complete policy. Do not bypass the
gate, and do not add heavy components to the allowlist.

Network failures should be diagnosed by fetch path. Nix binary substitution,
GitHub release/direct fetches, npm registry or node-gyp downloads, Cargo
registries, and runtime proxies are different paths; a fix for one should not be
silently generalized to the others.

The required `maintenance gate` check in
`.github/workflows/maintenance-gate.yml` is the whole-host merge decision.
Renovate PRs use the same required check and Renovate's configured merge policy.

Changes to maintenance policy, scripts, workflows, or Renovate configuration
require independent review even when the required gate passes.

If the gate or marker policy itself is broken, the repair can be impossible to
merge through the same gate it is repairing. In that narrow case, use an admin
bootstrap: temporarily disable the main ruleset, merge only the gate or policy
fix, and immediately restore the ruleset. Do not use this path for
package/version updates. This procedure requires explicit operator authorization;
a failed candidate check alone does not authorize changing branch protection.

`.github/workflows/maintenance-gate.yml` also supports the `merge_group` event.
GitHub Merge Queue is not currently enabled here because GitHub only offers it
for public repositories owned by organizations, or private organization
repositories on Enterprise Cloud. If this repository is moved to an organization
owner later, enable Merge Queue in the main ruleset and keep the same
`maintenance gate` check.

## Local `maint-switch`

`maint-switch` has a small local responsibility:

1. Require a clean local repo.
2. Run `git pull --ff-only` by default.
3. Dry-run the complete current system.
4. Stop if the dry-run shows heavy local builds or any unapproved local derivation.
5. Build the target system closure.
6. Activate with `boot` or `switch` depending on kernel/NVIDIA runtime risk.

`maint-switch` reads `dotfiles/maint.nuon` and the two jq helpers from
`XDG_CONFIG_HOME`, or `~/.config` when that variable is unset. Home Manager
installs the helpers and jq; missing files stop maintenance. It uses the
configured repo path unless overridden. For maintenance from a clean worktree,
pass an explicit repo path and skip the built-in pull:

```nu
maint-switch --repo /tmp/dotfiles-clean --no-pull
```

Use this for host-local auto-generated data such as Rime sync files. Do not make
a Rime-only commit just to satisfy the clean-checkout gate.

Pass `--boot` when a reviewed change must be installed as the next booted
generation without activating it in the current desktop session:

```nu
maint-switch --boot
```

This flag still runs the clean-check, optional pull, network gate, and complete
toplevel build. It always calls `nixos-rebuild --no-reexec boot --store-path ...` and reports
that a reboot is required. It is an explicit deferral path for lifecycle changes,
not the day-to-day default; without it, the existing automatic kernel/NVIDIA risk
selection remains in effect.

The local gate uses the running daemon's cache permissions. A valid empty plan
is allowed when the daemon already has the complete closure; CI's cold plan
must be nonempty. Dry-run and the actual build disable fallback and lock-file
writes. Fetching and building finish before `sudo`; activation consumes the
store path with `nixos-rebuild --no-reexec ... --store-path`.

CI can use keys declared by the candidate while an older host daemon still
rejects those keys. An untrusted-cache diagnostic points to the cache-trust
transition tracked in [#205](https://github.com/bioinformatist/dotfiles/issues/205).
Complete that transition through the normal maintenance path before expecting
the new cache to work locally. Do not substitute `sudo build` or expand
`trusted-users` to bypass the boundary.

Default blocking markers include:

- `linux-`, `nvidia-x11`, `mesa-`, `systemd-`
- `hyprland` and related `hypr*` components
- `gcc-`, `xgcc`, `rustc-`, `cargo-vendor`
- `chromium`, `electron`
- `serenityos-emoji-font`, `nanoemoji`

The allowlist covers reviewed generated glue, assembly, linking, and binary
wrappers. It permits Home Manager generations, NixOS activation files, declared
MCP wrappers, and the existing Helix wrapper. Declared vendor downloads can run
through the maintenance proxy. The current ChatGPT package is limited to its
exact reviewed wrapper, unpacking, and deb-fetch derivations; a changed pin or
hash requires another review. Codex source compilation, formatelf, and the
patched linglong power-profiles-daemon are not exempt. A fixed-output derivation
or a familiar package name alone is not evidence that it avoids compilation.

## Concurrency

`maint-switch` uses Nix's own concurrency controls instead of implementing parallel downloads in Nushell. The command-level defaults are:

```text
max-jobs = 4
cores = 2
```

HTTP download concurrency is a restricted Nix daemon setting, so an untrusted user cannot reliably override it with `--option` from `maint-switch`. The NixOS configuration declares:

```text
http-connections = 8
```

## Manual Full Refresh

`nix flake update` is still available for manual maintenance windows, but it is not the day-to-day entry point and does not benefit from Renovate's per-input PR isolation.

```nu
with-env (dotfiles-maint-config) {
  nix flake update
}

git diff
git add flake.lock
git commit -m "chore: update flake inputs"
maint-switch --no-pull
```

`maint-switch` requires a clean checkout, so a manual full refresh must be committed first. Use `--no-pull` to gate and switch that local commit.
