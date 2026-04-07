# NixOS Dotfiles

## Critical Non-Obvious Behaviors

### Rime Input Method Data (`rime-sync/nixos-ysun/`)

Auto-generated files updated constantly by the input method. Include with regular commits — no need to mention in commit message. Conflicts are expected and trivial: always keep the newer timestamp.

### Nushell Proxy Wrapper

`claude-proxy` wraps Claude Code to inject proxy environment variables from `~/.config/claude/proxy.nuon`. Check `home/shell/nushell/config.nu` if Claude Code network issues occur.

## Key Constraints

- Shell is Nushell — all commands must use Nushell syntax (not bash)
- Secrets must go through sops-nix (see `docs/secret-management.md`)
- Changes are verified manually by the user after rebuild
- System rebuild command:
  ```nushell
  with-env { HTTP_PROXY: "http://192.168.0.116:7890", HTTPS_PROXY: "http://192.168.0.116:7890" } { sudo --preserve-env=HTTP_PROXY,HTTPS_PROXY nixos-rebuild switch --flake .#homePC --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org" }
  ```

## Documentation

Detailed guides in `docs/` — reference them instead of duplicating:
- Installation / deployment
- Daily usage / keybindings
- Secret management
- Recovery procedures
