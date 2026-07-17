# 维护指南

#### 中文 | [English](maintenance.md)

推荐的日常维护入口仍然只有一个：

```nu
maint-switch
```

但更新提议不再由本机脚本生成。根目录 `flake.lock` 输入更新由 Renovate 提出；GitHub Actions 只维护固定的 release-pin leaves。本机只消费已经进入 `main` 的状态，并做最后的中国大陆网络门控和系统切换。

## 声明式网络配置

`homePC` 和 `linglong` 默认选择中国大陆网络 profile：

```nix
dotfiles.nixNetwork.profile = "china";
```

这会使用 USTC Nix cache 镜像进行二进制替代，不保留官方 `cache.nixos.org` 作为后备。workstation 模块也窄幅声明了 Anyrun、Hyprland 和 Noctalia 的额外 Cachix substituter，因为这些快速变动的桌面输入确实有可用的上游缓存。本地代理 URL 也在 NixOS 配置中声明：

```nix
dotfiles.nixNetwork.proxy = {
  enable = true;
  url = "http://127.0.0.1:7897";
};
```

该代理只作用于 Nix 维护路径：它会注入 `nix-daemon`，同时写入 `/etc/dotfiles/nix-network.json` 供 `maint-switch` 读取。它不是桌面/session 级代理。

## 自动更新 PR

`renovate.json` 让 Renovate 按每个根 flake input 单独提出 PR：

| Leaf | Policy | 更新内容 |
|---|---|---|
| `anyrun` | `tools` | `anyrun` flake input |
| `nixpkgs-tools` | `tools` | `nixpkgs-tools` flake input |
| `wechat` | `tools` | `nixpkgs-wechat` flake input |
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

不在表中的根 input，目前是 `fieldcraft`、`mattpocock-skills` 和 `swww`，暂时不由 Renovate 自动更新；只有当它们被提升到显式 policy 后再纳入。
Renovate 的 `lockFileMaintenance` 被关闭，因为 whole-lock refresh 会把多个
leaf 混进同一个 PR，削弱 cache miss 归因。

`.github/workflows/maintenance-leaf.yml` 只保留 Renovate 暂时不管理的非标准 release-pin leaves：

| Leaf | Policy | 更新内容 |
|---|---|---|
| `codex` | `tools-fast` | Codex release pin |
| `orca` | `tools-fast` | Orca ADE AppImage release pin |
| `zeroclaw` | `tools` | ZeroClaw release pin |

Codex 和 Orca 每 4 小时检查一次，因为它们是交互式工具，新 release 应该更快进入机器。ZeroClaw 仍然每天一次。release-pin workflow 会先检查上游 release；只有这一步实际改动文件时，才继续跑 dry-run 和 China gate。

每个 release-pin leaf 最多一个 open PR；下一次尝试会更新同一个 `maint/<leaf>` 分支，不会开新 PR。Renovate 和 release-pin 维护 PR 暂时都不设置全局 open PR 上限。

仓库设置：为本仓库安装/启用 Renovate GitHub App。默认 workflow token 权限保持
`read`，并添加一个只授权本仓库的 fine-grained PAT，作为 `MAINTENANCE_PAT`
repository secret。release-pin workflow 会用这个 token push `maint/<leaf>` 分支
并创建/更新 PR，这样 required `pull_request` maintenance gate 会自动运行，不会
卡在手动批准 workflow 的状态。如果缺少这个 secret，workflow 会回退到
`GITHUB_TOKEN`，但生成的 PR checks 可能需要人工批准。还需要启用仓库
auto-merge。默认分支应通过 ruleset 保护：要求 PR，并要求 `maintenance gate`
状态检查，且启用 strict up-to-date checks。

PR 会跑两类 dry-run：

- `global-*`：GitHub runner 默认网络下的基本 dry-run，同时显式加入 Anyrun、Hyprland 和 Noctalia Cachix。
- `china-gate-*`：使用声明式中国维护 cache 集合：USTC 加 Anyrun/Hyprland/Noctalia Cachix，并清空未声明的 `extra-substituters`。

required gate 还会 dry-run 一个合成的 `ci@headless` Home Manager 配置。这个配置
消费 downstream 仓库使用的导出 headless 开发模块，因此共享工具输入不仅要对
`homePC` 和 `linglong` 安全，也要对可复用 headless consumer 保持 cache-safe。
这项检查并入同一套 base-vs-head China gate；当 synthetic profile 已经进入
`main` 后，新的 headless-only cache miss 会阻塞 PR，既有 baseline debt 只作为
诊断信息保留。

China gate 会同时记录更新后 head closure 的完整结果，以及相对 `main`
的差分。auto-merge 准入以 delta 为准：GitHub 冷 runner 暴露出来的无关
full-head miss 是诊断用 baseline debt，不应冻结每个 leaf PR。固定输出 release
直连 fetch 只有在维护 policy 中声明过 marker 时才允许，目前是 Codex、Orca 和
ZeroClaw。

可复用的 marker 基线放在 `scripts/maint/policy.json`，GUI 专属增量放在
`scripts/maint/policy-workstation.json`。flake 将两者合成为
`lib.maintenancePolicy`，本机 `maint-switch` 和 GitHub China gate 都求值目标
flake 的这个值。下游仓库只用窄 overlay 扩展 `lib.maintenancePolicyBase`，不再
转发整份文件。生成的 `maint.nuon` 只保存 repo 路径、host、并发和可选 extra
marker 这类机器本地设置，不 snapshot 有效 policy。GitHub leaf workflow 和
required gate workflow 共享
`scripts/maint/evaluate-china-gate.sh` 里的 head-vs-base China gate 评估，
避免 PR 元数据和 required `maintenance gate` 状态漂移。flake-input 的 policy
分组和调度放在 `renovate.json`；release-pin leaves 保留在
`.github/workflows/maintenance-leaf.yml`。这些属于 workflow 编排，不属于 gate
policy。

base 和 head dry-run 也共用 `scripts/maint/china-gate.sh`。每次运行都会显式传入
对应的 flake root，并求值该 root 的 `lib.maintenancePolicy`。这样 workflow 的
当前工作目录或 PR 内的 policy 变更就不会悄悄重新分类 base closure；host 配置与
`ci@headless` 使用同一分类实现。

workflow 还会运行一个非 required 的 `china delta shadow` job。它先在本地生成
base 和 head derivation 图，再比较实际需要的 `(derivation, output)` 对。policy
已经允许本地构建的 glue derivation 不会发起 cache 查询；其余 output 先查询
Cachix，再查询 USTC，并从后续请求中移除已经命中的路径。marker policy 发生变化、
图格式不受支持或包含动态 output、cache metadata 无法查询或通过信任验证时，
shadow 结果为 inconclusive，完整 gate 继续作为权威结果。shadow 不修改 Nix HTTP
连接设置，也不替换 required gate；在考虑切换前，只用它积累两种分类器的一致性
样本。

marker policy 是经验性边界，应该在真实 miss 中持续收紧：`unit-`、
`-etc-`、`nixos-system-` 这类较宽的生成式 glue marker 如果误分类
derivation，就应收紧；新的 release tarball leaf 也必须显式声明后才允许
direct fetch。

如果本机 gate 拦住的是明确的 NixOS/Home Manager 生成式 glue derivation，
例如环境文件或 activation glue，应把它当作 policy 漂移处理：窄幅更新共享基线
或负责该行为的 overlay；下游只刷新 upstream input，不复制整份 policy。不要绕过
gate，也不要把重组件加入 allowlist。

网络失败需要按 fetch 路径拆分诊断。Nix 二进制替代、GitHub release/direct fetch、
npm registry 或 node-gyp 下载、Cargo registry、运行时代理是不同路径；一个路径
的修复不应被默默推广到其他路径。

只有 required `maintenance gate` check 通过的 PR 才有资格进入 auto-merge。
release-pin PR 还会把 preflight 结果同步到 `global-*` 和 `china-gate-*` label，
并在 PR 正文记录 full-head miss 供诊断。Renovate PR 则依赖 required check 和
Renovate 自己的 auto-merge 状态，而不是这些 release-pin label。leaf workflow
不再发布自己的 required status；唯一 required 的 `maintenance gate` check 来自
`.github/workflows/maintenance-gate.yml`，因此生成 PR 元数据和 required check
使用同一个 delta gate。

如果生成的 release-pin 更新触碰 maintenance policy、gate 脚本、maintenance
workflow 或 Renovate config，即使技术 gate 通过，也不会交给 auto-merge；这类
PR 会保留为 draft/manual-review。原因是 policy 变更不应该只用它自己刚修改过的
policy 来证明自己合理。

如果 gate 或 marker policy 自身坏掉，修复可能无法通过正在被它修复的同一个
gate 合入。这种窄场景可以使用 admin bootstrap：临时关闭 main ruleset，只合入
gate 或 policy 修复，然后立刻恢复 ruleset。不要用这条路径合入包版本更新。

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

当已审查变更必须安装为下次启动的 generation，但不应在当前桌面会话中激活时，
显式传入 `--boot`：

```nu
maint-switch --boot
```

该标志仍会执行 clean-check、可选 pull、网络门控和完整 toplevel 构建，然后固定调用
`nixos-rebuild boot --store-path ...`，并提示必须重启。它是有意延后激活的显式路径，
不是日常默认；不传该标志时，现有 kernel/NVIDIA 风险自动选择保持不变。

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

`nix flake update` 仍可用于人工维护窗口中的全量刷新，但它不是日常入口，也不享受 Renovate per-input PR 的隔离。

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
