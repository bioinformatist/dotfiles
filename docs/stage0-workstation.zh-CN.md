# Stage 0 工作站交付包

Stage 0 的目标是内部交付：快速为自己、朋友、同事或新电脑生成一套可维护的 NixOS 开发工作站配置。

## 模块边界

- `profiles.headless`：最小系统基础，用户、SSH、Nix、sudo。
- `profiles.ai-serving`：GPU / Docker 宿主能力，继续服务服务器和 116。
- `profiles.workstationCn`：中国大陆开发工作站系统层。
- `nixosModules.nvidiaDesktop`：NVIDIA + Wayland 桌面补丁，按需叠加。
- `homeManagerModules.workstationCn`：通用桌面用户层。
- `users/ysun`：个人 Git、SSH、Rime sync、ZeroClaw、D2R、Codex trust。

## 新机器模板

```bash
mkdir my-workstation
cd my-workstation
nix flake init -t github:bioinformatist/dotfiles#workstation-cn
```

必须先替换：

- `flake.nix` 里的 `username` 和 `hostName`
- `hosts/workstation/disko-config.nix` 里的 `/dev/disk/by-id/REPLACE_ME`
- `flake.nix` 里的 SSH public key 和临时密码
- `users/changeme/home.nix` 里的 Git identity

## 验收

```bash
nix flake show
nix eval .#nixosConfigurations.workstation.config.system.build.toplevel.drvPath
```

如果修改了 `hostName`，把 `workstation` 替换成新的 host 名。

## 安装

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#workstation \
  root@<target-ip>
```

模板第一版不强制 sops-nix 或 impermanence；需要擦除式根目录和 secret 管理时，再按本仓库正式安装文档迁移。

## 兼容性规则

第一轮 Stage 0 不迁移 `sctmes/dotfiles`。116 继续消费 `headless`、`ai-serving`、`nixProxy` 和 `devHeadless`，本仓库改动后只用本地 upstream override 做 eval 验收。
