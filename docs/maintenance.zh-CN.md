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
- Codex release hash 直接来自 GitHub release asset digest，因此更新函数不会为了计算 hash 再下载 tarball
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
- 每次都先执行 `maint-check`，再决定是否执行 `maint-switch`。
- 如果 `maint-check` 检测到 `will be built`，优先选择暂缓更新，而不是本地编译。

## 更新命令

### `maint-update-tools`

更新相对低风险的工具层：

- flake inputs：`zeroclaw`、`antigravity`、`yazi`、`anyrun`、`sops-nix`、`impermanence`、`disko`
- 本地声明的 Codex release pin： [home/programs/codex/default.nix](/home/ysun/github.com/bioinformatist/dotfiles/home/programs/codex/default.nix)

当你主要想让 Codex、ZeroClaw、Antigravity、Yazi、Anyrun 这些日常工具尽量新时，应优先使用这个入口。

```nu
maint-update-tools
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

这是风险最高的一类更新，因为它最容易牵动新的内核 / NVIDIA 组合。

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

基于当前仓库状态执行真正的 rebuild 和 switch。

```nu
maint-switch
```

`maint-switch` 不会隐式更新任何 input；它只应用当前仓库里已经记录好的状态。

## 典型工作流

### 工具层刷新

当你主要关心 Codex、ZeroClaw、Antigravity、Yazi、Anyrun 这些工具时，使用：

```nu
maint-update-tools
maint-check
maint-switch
```

如果 `maint-check` 检测到 `will be built`，就停在这一步，不要继续。

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

如果检查结果里出现 `nvidia-x11`、`linux-` 或其他重型组件进入 `will be built`，建议先取消这次更新。

## 说明

- `claude-code` 走的是 `pkgs.claude-code`，因此它随 `nixpkgs` 更新，属于 `maint-update-base`，而不是 `maint-update-tools`。
- 这些维护函数默认面向当前这台 `homePC`。
- `workstation` 已持久化 `~/.config/nix/`，因此 `local-proxy.nuon` 创建后可跨重启保留。
