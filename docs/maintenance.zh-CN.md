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

这会使用 USTC Nix cache 镜像进行二进制替代，不保留官方 `cache.nixos.org` 作为后备。workstation 模块也窄幅声明了 Anyrun 和 Hyprland 的额外 Cachix substituter，因为这些快速变动的桌面输入确实有可用的上游缓存。本地代理 URL 也在 NixOS 配置中声明：

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
| `orca` | `tools` | Orca ADE AppImage release pin |
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

仓库设置：默认 workflow token 权限保持 `read`，但需要打开 GitHub Actions 的
"Allow GitHub Actions to create and approve pull requests"。同时需要启用仓库
auto-merge。默认分支应通过 ruleset 保护：要求 PR，并要求 `maintenance gate`
状态检查，且启用 strict up-to-date checks。

PR 会跑两类 dry-run：

- `global-*`：GitHub runner 默认网络下的基本 dry-run，同时显式加入 Anyrun 和 Hyprland Cachix。
- `china-gate-*`：使用声明式中国维护 cache 集合：USTC 加 Anyrun/Hyprland Cachix，并清空未声明的 `extra-substituters`。

China gate 会同时记录更新后 head closure 的完整结果，以及相对 `main`
的差分。delta miss 只用于归因；auto-merge 准入以完整更新后的 head 为准。
这样 GitHub gate 和本机 `maint-switch` 保持一致：如果完整当前系统会在本机
被拦住，对应 PR 就不能自动进入 `main`。新增的固定输出 release 直连 fetch
只有在 leaf 明确声明该路线时才允许，目前是 Codex、Orca 和 ZeroClaw。

门控 marker policy 统一放在 `scripts/maint/policy.json`；本机
`maint-switch` 和 GitHub China gate 都从当前 repo checkout 读取同一组
marker。生成的 `maint.nuon` 只保存 repo 路径、host、并发和可选 extra marker
这类机器本地设置，不再 snapshot 主 marker policy，因此 repo 里的 policy 收紧会在下一次 switch 前生效。GitHub leaf workflow 和 required gate workflow 共享
`scripts/maint/evaluate-china-gate.sh` 里的 head-vs-base China gate 评估，
避免 PR 元数据和 required `maintenance gate` 状态漂移。leaf 队列本身继续保留在 `.github/workflows/maintenance-leaf.yml`；
leaf 名称、policy 分组、调度、flake input 和 update hook 属于 workflow
编排，不属于 gate policy。

marker policy 是经验性边界，应该在真实 miss 中持续收紧：`unit-`、
`-etc-`、`nixos-system-` 这类较宽的生成式 glue marker 如果误分类
derivation，就应收紧；新的 release tarball leaf 也必须显式声明后才允许
direct fetch。

如果本机 gate 拦住的是明确的 NixOS/Home Manager 生成式 glue derivation，
例如环境文件或 activation glue，应把它当作 policy 漂移处理：窄幅更新
`scripts/maint/policy.json`，再让下游仓库继承或转发该 policy。不要绕过 gate，
也不要把重组件加入 allowlist。

网络失败需要按 fetch 路径拆分诊断。Nix 二进制替代、GitHub release/direct fetch、
npm registry 或 node-gyp 下载、Cargo registry、运行时代理是不同路径；一个路径
的修复不应被默默推广到其他路径。

只有 `global-pass` 且 full-head `china-gate-pass` 的 PR 才有资格进入
GitHub auto-merge。PR 正文仍记录 delta miss 供归因。leaf workflow 不再发布
自己的 required status；唯一 required 的 `maintenance gate` check 来自
`.github/workflows/maintenance-gate.yml`，因此 `main` 不会自动前进到本机
`maint-switch` 会拒绝的状态。`global-pass` 但 `china-gate-miss` 的 PR
只保留为人工可见的候选，不进入 `main`。

如果 `main` 已经因为 cache 漂移而被 gate 拦住，gate 或 marker policy
修复可能无法通过正在被它修复的同一个 gate 合入。这种窄场景可以使用 admin
bootstrap：临时关闭 main ruleset，只合入 gate 或 policy 修复，然后立刻恢复
ruleset。不要用这条路径合入包版本更新。

`.github/workflows/maintenance-gate.yml` 也支持 `merge_group` 事件。当前没有
真正启用 GitHub Merge Queue，因为 GitHub 只把该功能提供给组织拥有的 public
repo，或 Enterprise Cloud 组织拥有的 private repo。如果以后把本仓库迁移到
organization owner，再在 main ruleset 中启用 Merge Queue，并继续使用同一个
`maintenance gate` check。

## 本机 `maint-switch`

`maint-switch` 做的事情很少：

1. 要求本地 repo clean。
2. 默认执行 `git pull --ff-only`。
3. 对当前 `main` 状态做完整系统 dry-run。
4. 如果 dry-run 显示重型本地构建或未批准的本地 derivation，停止。
5. 构建目标 system closure。
6. 根据 kernel/NVIDIA 风险选择 `boot` 或 `switch` 激活。

默认情况下，`maint-switch` 使用 `~/.config/dotfiles/maint.nuon` 里生成的
repo 路径。需要从 clean worktree 维护时，可以显式传入 repo 路径并跳过内置
pull：

```nu
maint-switch --repo /tmp/dotfiles-clean --no-pull
```

这适用于 Rime sync 文件这类主机本地自动生成数据；不要为了通过 clean-checkout
门控而创建 Rime-only commit。

默认阻断标记包括：

- `linux-`、`nvidia-x11`、`mesa-`、`systemd-`
- `hyprland` 和 `hypr*` 相关组件
- `gcc-`、`xgcc`、`rustc-`、`cargo-vendor`
- `chromium`、`electron`
- `serenityos-emoji-font`、`nanoemoji`

允许列表只覆盖生成式 glue 和轻量包装：Home Manager 文件/ generation、NixOS unit/restart/activation 文件、生成的 manifest、repo-local Codex skill packaging，以及已声明的 MCP wrapper derivation 可以继续。Codex、Orca 和 ZeroClaw 这种已声明的固定输出 release 直连 fetch 也可以通过已配置的维护代理继续。其他本地构建会被当作门控失败处理；kernel、Mesa、systemd package、Hyprland package、GCC/Rust toolchain、Chromium/Electron 和大型字体流水线仍然会被拦截。

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
