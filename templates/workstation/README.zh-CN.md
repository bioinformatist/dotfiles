# workstation starter

这是 NixOS 开发工作站模板。它通过 `github:bioinformatist/dotfiles` 暴露的 `lib.mkWorkstationSystem` 继承上游 Nixpkgs、Home Manager、disko 和 stateVersion 策略。

## 必改项

1. 在 `flake.nix` 中替换 `username` 和 `hostName`。
2. 在 `hosts/workstation/disko-config.nix` 中把 `/dev/disk/by-id/REPLACE_ME` 改成目标磁盘。
3. 在 `flake.nix` 中替换 SSH public key。
4. 在 `users/changeme/home.nix` 中替换 Git 用户名和邮箱。

## 验证

```bash
nix flake show
nix eval .#nixosConfigurations.workstation.config.system.build.toplevel.drvPath
```

## 安装

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#workstation \
  root@<target-ip>
```

模板第一版不强制 sops-nix 或 impermanence；需要擦除式根目录和 secret 管理时，再按本仓库文档迁移。
