# NixOS Dotfiles

## Critical Non-Obvious Behaviors

### Rime Input Method Data (`rime-sync/nixos-ysun/`)

Auto-generated files may change while the user is typing. Treat them as local user data and follow the Rime boundary in root `AGENTS.md`.

## Key Constraints

- Shell is Nushell — all commands must use Nushell syntax (not bash)
- Secrets must go through sops-nix (see `docs/secret-management.md`)
- Changes are verified manually by the user after rebuild
- System rebuild command:
  ```nushell
  maint-switch
  ```

## Documentation

Detailed guides in `docs/` — reference them instead of duplicating:
- Installation / deployment
- Daily usage / keybindings
- Secret management
- Recovery procedures
