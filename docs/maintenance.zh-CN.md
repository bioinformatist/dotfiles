# 维护指南

#### 中文 | [English](maintenance.md)

本指南说明这套系统的**推荐维护流程**：

- 日常工具尽量保持较新
- 尽量避免本地编译
- 将 `hyprland` 和 `nixpkgs` 视为单独、高风险的更新类别

下面的命令都由 [home/shell/nushell/config.nu](/home/ysun/github.com/bioinformatist/dotfiles/home/shell/nushell/config.nu) 中定义的 Nushell 函数提供。

## 本地代理配置

现在所有维护命令和 `nix-daemon` 都统一从下面这个本地文件读取网络配置：

`~/.config/nix/local-proxy.nuon`

该文件刻意不纳入 git。示例：

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

含义如下：

- 维护函数访问 GitHub API 时使用这个文件
- Codex 和 ZeroClaw release hash 直接来自 GitHub release asset digest，因此更新函数不会为了计算 hash 再下载 tarball
- `nix-daemon` 也使用同一个文件里的代理、`NO_PROXY` 和 `substituters`
- 以后代理地址变化时，只需要改这一个文件

修改该文件后，重启一次 daemon 才会让 daemon 侧的新配置生效：

```nu
sudo systemctl restart nix-daemon
```

## 原则

- 不要把 `nix flake update` 当成日常一把梭的更新命令。
- 工具层更新应与 `hyprland` 更新分开。
- `hyprland` 更新应与系统底座（`nixpkgs` / `home-manager`）更新分开。
- Home Manager 的 release 分支应与当前 Nixpkgs 的 release 号对齐。本系统可以使用
  `nixos-unstable`，但如果 Nixpkgs 报告 `26.05`，Home Manager 就应使用
  `release-26.05`，而不是 `master`。不要用
  `home.enableNixpkgsReleaseCheck = false` 消掉 release mismatch warning。
- 每次都先执行 `maint-check`，再决定是否执行 `maint-switch`。
- 如果 `maint-check` 检测到 `will be built`，优先选择暂缓更新，而不是本地编译。

## 更新命令

### `maint-update-tools`

更新相对低风险的工具层：

- flake input：`nixpkgs-wechat`，用于微信
- flake input：`anyrun`，用于 Anyrun
- 本地声明的 Codex release pin： [home/programs/codex/default.nix](/home/ysun/github.com/bioinformatist/dotfiles/home/programs/codex/default.nix)
- 本地声明的 ZeroClaw release pin： [home/programs/zeroclaw/default.nix](/home/ysun/github.com/bioinformatist/dotfiles/home/programs/zeroclaw/default.nix)

当你主要想让二进制友好的工具保持较新时，应优先使用这个入口。微信使用独立的 nixpkgs input，因此可以单独更新。Anyrun 使用自己的上游 flake input，因此可以独立更新并使用上游 binary cache。Yazi 跟随 `nixpkgs-tools`。

```nu
maint-update-tools
```

### `maint-update-infra`

更新低频基础设施输入：

- `sops-nix`
- `impermanence`
- `disko`

这一路径可能触发本地 helper 程序构建，所以应放在基础设施维护窗口中执行，而不是日常工具刷新。

```nu
maint-update-infra
```

### `maint-update-hyprland`

只更新独立的 `hyprland` flake input。

```nu
maint-update-hyprland
```

### `maint-update-base`

只更新系统底座输入：

- `nixpkgs`
- `home-manager`

这是风险最高的一类更新，因为它最容易牵动新的内核 / NVIDIA 组合。更新这一层时，Home Manager 分支应与目标系统报告的 Nixpkgs release 对齐，例如 `26.05` Nixpkgs 对应 `release-26.05`。

```nu
maint-update-base
```

### `maint-check`

对下面这个目标执行 dry-run 构建：

```text
.#nixosConfigurations.homePC.config.system.build.toplevel
```

然后在输出最后追加一段 summary。

```nu
maint-check
```

summary 只关注两类信息：

- 是否检测到 `will be built`
- 是否命中高风险标记，例如 `nvidia-x11`、`linux-`、`hyprland`

如果检测到 `will be built`，summary 会明确提示**不建议继续重建**。

### `maint-switch`

基于当前仓库状态构建目标系统，然后选择安全的激活方式。

```nu
maint-switch
```

`maint-switch` 不会隐式更新任何 input；它只应用当前仓库里已经记录好的状态。

激活前，它会比较目标系统和当前 booted system：

- 如果 booted kernel 会变化，执行 `nixos-rebuild boot` 并提示重启。
- 如果 NVIDIA userspace 会变化，同样执行 `nixos-rebuild boot` 并提示重启。
- 否则才执行普通的 `nixos-rebuild switch`。

这样可以避免在正在运行的 Wayland 会话中热切换到 kernel / NVIDIA /
Hyprland 混合版本状态。

## 典型工作流

### 工具层刷新

当你主要关心 Codex、ZeroClaw、微信、Anyrun 这类二进制友好的工具 pin 时，使用。Yazi 跟随 `nixpkgs-tools`。

```nu
maint-update-tools
maint-check
maint-switch
```

如果 `maint-check` 检测到 `will be built`，就停在这一步，不要继续。

### 基础设施刷新

当你明确想更新 secrets、持久化或分区相关基础设施时，使用：

```nu
maint-update-infra
maint-check
maint-switch
```

如果 `maint-check` 显示你暂时不想接受的本地 helper 构建，就停在这一步。

### Hyprland 刷新

当你明确想跟进 Hyprland 时，使用：

```nu
maint-update-hyprland
maint-check
maint-switch
```

如果检查结果里出现大量 `hypr*` 本地构建，就先停下，等 cache 更成熟再试。

### 系统底座刷新

当你明确想更新 `nixpkgs` / `home-manager` 时，使用：

```nu
maint-update-base
maint-check
maint-switch
```

如果检查结果里出现 `nvidia-x11`、`linux-` 或其他重型组件进入 `will be built`，而你暂时不想接受这些更新，就先取消这次更新。如果继续，`maint-switch` 会在 kernel 或 NVIDIA 变化时自动使用 boot activation，而不是热切换。

## 说明

- 这些维护函数默认面向当前这台 `homePC`。
- `homePC` 已持久化 `~/.config/nix/`，因此 `local-proxy.nuon` 创建后可跨重启保留。
