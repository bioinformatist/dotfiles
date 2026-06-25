# Context

This file records domain language for agents working in this dotfiles repo.
Keep operational rules in `AGENTS.md`; keep this file focused on glossary
terms and durable architectural vocabulary.

## Glossary

- **Upstream base**: This reusable dotfiles repo. It exports shared modules,
  profiles, overlays, packages, and library helpers for personal and downstream
  machines.
- **Downstream consumer**: A separate repo or host configuration that consumes
  this repo through public flake outputs instead of importing internal paths.
- **Host configuration**: A concrete NixOS system assembled from a host
  directory, shared profiles, Home Manager modules, overlays, and user config.
- **homePC**: The maintained personal workstation host exposed by this repo.
- **Profile**: A reusable flake output that groups host capabilities without
  hardcoding a concrete user, machine, or company environment.
- **Proxy boundary**: The separation between proxy settings used by Nix and
  maintenance tooling, and the desktop/session environment. Keep the terms
  distinct when discussing rebuild or network behavior.
- **Vendored skill**: A repo-local Codex skill copied into `.agents/skills` from
  a pinned external flake input so it is reviewable and checked with the repo.
- **Generated Rime data**: Input-method sync data under `rime-sync/nixos-ysun/`
  that changes outside normal source editing and should be treated as generated
  user data.
