# 维护指南

#### 中文 | [English](maintenance.md)

推荐的日常维护入口仍然只有一个：

```nu
maint-switch
```

但更新提议不再由本机脚本生成。leaf 级更新由 GitHub Actions 维护固定 PR 队列；本机只消费已经进入 `main` 的状态，并做最后的中国大陆网络门控和系统切换。

## 声明式网络配置

`homePC` 和 `linglong` 默认选择中国大陆网络 profile：

```nix
dotfiles.nixNetwork.profile = "china";
```

这会使用 USTC Nix cache 镜像进行二进制替代，不保留官方 `cache.nixos.org` 作为后备。本地代理 URL 也在 NixOS 配置中声明：

```nix
dotfiles.nixNetwork.proxy = {
  enable = true;
  url = "http://127.0.0.1:7897";
};
```

该代理只作用于 Nix 维护路径：它会注入 `nix-daemon`，同时写入 `/etc/dotfiles/nix-network.json` 供 `maint-switch` 读取。它不是桌面/session 级代理。

## GitHub Leaf PR 队列

`.github/workflows/maintenance-leaf.yml` 负责提出更新。每个 leaf 使用固定分支和固定 PR：

| Leaf | Policy | 更新内容 |
|---|---|---|
| `anyrun` | `tools` | `anyrun` flake input |
| `nixpkgs-tools` | `tools` | `nixpkgs-tools` flake input |
| `wechat` | `tools` | `nixpkgs-wechat` flake input |
| `codex` | `tools` | Codex release pin |
| `zeroclaw` | `tools` | ZeroClaw release pin |
| `hyprland` | `desktop` | `hyprland` flake input |
| `sops-nix` | `infra` | `sops-nix` flake input |
| `impermanence` | `infra` | `impermanence` flake input |
| `disko` | `infra` | `disko` flake input |
| `base` | `core` | `nixpkgs`、`home-manager` |

默认调度：

| Policy | 调度 |
|---|---|
| `tools` | 每天 |
| `desktop` | 每周六 UTC |
| `infra` | 每月 1 日 UTC |
| `core` | 每月 1 日 UTC |

每个 leaf 最多一个 open PR；下一次尝试会更新同一个 `maint/<leaf>` 分支，不会开新 PR。暂时不设置全局 open PR 上限。

仓库设置：默认 workflow token 权限保持 `read`，但需要打开 GitHub Actions 的 "Allow GitHub Actions to create and approve pull requests"。这是创建固定 leaf PR 的前提，和启用 auto-merge 不是同一个开关。

PR 会跑两类 dry-run：

- `global-*`：GitHub runner 默认网络下的基本 dry-run。
- `china-gate-*`：强制只使用 `https://mirrors.ustc.edu.cn/nix-channels/store`，并清空 `extra-substituters` 的中国大陆网络门控。

China gate 会把更新后的 leaf 和 `main` 做差分比较。已有的未命中不会让每个 leaf PR 都失败；新增的未批准本地构建会失败；新增的固定输出 release 直连 fetch 只有在 leaf 明确声明该路线时才允许，目前是 Codex 和 ZeroClaw。

只有 `global-pass` 且 `china-gate-pass` 的 PR 才会尝试 auto-merge。`global-pass` 但 `china-gate-miss` 的 PR 只保留为人工可见的候选，不进入 `main`。

## 本机 `maint-switch`

`maint-switch` 做的事情很少：

1. 要求本地 repo clean。
2. 默认执行 `git pull --ff-only`。
3. 对当前 `main` 状态做完整系统 dry-run。
4. 如果 dry-run 显示重型本地构建或未批准的本地 derivation，停止。
5. 构建目标 system closure。
6. 根据 kernel/NVIDIA 风险选择 `boot` 或 `switch` 激活。

默认阻断标记包括：

- `linux-`、`nvidia-x11`、`mesa-`、`systemd-`
- `hyprland` 和 `hypr*` 相关组件
- `gcc-`、`xgcc`、`rustc-`、`cargo-vendor`
- `chromium`、`electron`
- `serenityos-emoji-font`、`nanoemoji`

允许列表刻意很窄：`hm_*`、`home-manager-path`、`home-manager-generation`、`user-environment`、`system-units`、`etc`、`activate`、`nixos-system-*` 这类 NixOS/Home Manager glue 可以本地构建。Codex 和 ZeroClaw 这种已声明的固定输出 release 直连 fetch 也可以通过已配置的维护代理继续。其他本地构建即使没有命中阻断标记，也会被当作门控失败处理。

## 并发策略

`maint-switch` 使用 Nix 自己的并发控制，不在脚本层手写并发下载。命令级默认参数是：

```text
max-jobs = 4
cores = 2
```

HTTP 下载连接数是 Nix daemon 的 restricted setting，不能可靠地由普通用户在 `maint-switch` 里用 `--option` 覆盖；因此系统配置里声明：

```text
http-connections = 8
```

## 手动全量刷新

`nix flake update` 仍可用于人工维护窗口中的全量刷新，但它不是日常入口，也不享受 leaf 级 PR 队列的隔离。

```nu
with-env (dotfiles-maint-config) {
  nix flake update
}

git diff
git add flake.lock
git commit -m "chore: update flake inputs"
maint-switch --no-pull
```

`maint-switch` 要求 checkout clean；因此手动全量刷新需要先提交，再用 `--no-pull` 针对本地提交执行网络门控和切换。
