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

这会使用 USTC Nix cache 镜像进行二进制替代，不保留官方 `cache.nixos.org` 作为后备。共享 headless profile 为 `llm-agents.nix` 包加入 Numtide 官方缓存（`https://cache.numtide.com`）及其公开签名公钥；workstation 模块另外声明 Anyrun、Hyprland 和 Noctalia Cachix 缓存。本地代理 URL 也在 NixOS 配置中声明：

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
| `codex-base` | `tools` | Codex Base 配置、Improve 和全局 skills |
| `llm-agents` | `tools` | 社区独立 CLI 和桌面包 |
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
| `zeroclaw` | `tools` | ZeroClaw release pin |

ZeroClaw 每天检查一次。release-pin workflow 检查上游 release、更新版本和哈希；生成的 PR 由 required maintenance gate 检查。

Codex 运行包来自 `llm-agents`：独立 CLI 包含配套的 Code Mode Host，供 headless
和桌面主机的终端、Improve、doctor 使用。桌面启动器通过 `CODEX_CLI_PATH` 选择
同一个 CLI。`codex-base` 提供配置、Improve 和 skills。
Renovate 分别更新这两个根输入；任一更新后，都需要检查所选运行包与继承配置、
工作流的兼容性。运行中的桌面应用或 SSH App Server 后台需要重启才会切换版本。

每个 release-pin leaf 最多一个 open PR；下一次尝试会更新同一个 `maint/<leaf>` 分支，不会开新 PR。Renovate 和 release-pin 维护 PR 暂时都不设置全局 open PR 上限。

仓库设置：为本仓库安装/启用 Renovate GitHub App。默认 workflow token 权限保持
`read`，并添加一个只授权本仓库的 fine-grained PAT，作为 `MAINTENANCE_PAT`
repository secret。release-pin workflow 会用这个 token push `maint/<leaf>` 分支
并创建/更新 PR，这样 required `pull_request` maintenance gate 会自动运行，不会
卡在手动批准 workflow 的状态。如果缺少这个 secret，workflow 会回退到
`GITHUB_TOKEN`，但生成的 PR checks 可能需要人工批准。还需要启用仓库
auto-merge。默认分支应通过 ruleset 保护：要求 PR，并要求 `maintenance gate`
状态检查，且启用 strict up-to-date checks。

required `maintenance gate` check 汇总两个 job。`configuration` 运行原生 flake
求值、合成的 `ci@headless` Home Manager activation 求值，以及已有的 WeChat
控制、Codex adapter 和 repo-local skills 轻量检查；还运行缓存预检封装测试。
`cache-preflight` 对 `homePC`、`linglong` 和 `ci@headless` 比较 base/head。
两个 job 均使用 Nix 2.34.7；失败或无法判断都会阻止 required check 通过。

预检在隔离的冷 store 中用 Nix dry-run 生成计划，显式使用官方缓存、Numtide 和
Anyrun/Hyprland/Noctalia Cachix。未经批准的本地构建是上游缺口。USTC 检查
先比较 base/head 去重后的待替代路径，只查询新增且由官方缓存提供的产物；未变路径
不新增缓存或压缩包探测。Nix 元数据查询限制为一个 HTTP 连接；NAR HEAD 请求
串行执行，curl 原生限速为每秒最多一次，并使用原生重试/退避；遇到无法判断的响应
即停止后续请求。元数据缺失或压缩包返回 404/410 是确定的新增缺口；请求失败、
输出格式错误和异常响应为无法判断。报告不代表完整 head 的 USTC 就绪状态。
比较以完整 store path 为身份，保留现有直连下载 marker 和 leaf 限制。日志保留
原始 Nix 与 HTTP 结果；环境故障后由人工重跑 workflow。

可复用 marker 基线位于 `scripts/maint/policy.json`，GUI 增量位于
`scripts/maint/policy-workstation.json`。flake 将两者合成为
`lib.maintenancePolicy`；预检分别读取 base/head 的值，本机 `maint-switch` 也
使用有效 policy。下游用窄 overlay 扩展 `lib.maintenancePolicyBase`。
flake-input 的 policy 分组和调度位于 `renovate.json`；release-pin leaves
保留在 `.github/workflows/maintenance-leaf.yml`。

实验性的 China delta shadow 已退役：2026-07-13 至 2026-09-29 共有 169 次可读
分类，其中 52 次通过、4 次 miss、113 次 inconclusive。两次 miss 与通过的正式 gate
结论不同，且来自同一 PR 的两个 revision；历史原因尚未查明。该实验也没有保留
Nix 对依赖的 cache-aware 剪枝。
[代表性运行记录](https://github.com/bioinformatist/dotfiles/actions/runs/29306294755)
展示了诊断输出。新的 required 预检取代了该 gate。

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

`.github/workflows/maintenance-gate.yml` 中 required 的 `maintenance gate`
check 是 whole-host 合入决策。普通 release-pin PR 请求 GitHub auto-merge，
由该检查和分支保护决定何时合入。leaf workflow 在 PR 正文列出 leaf、policy
和是否需要人工审查，并指向 Checks 中的 configuration 和 cache preflight 结果。
Renovate PR 也依赖同一 required check 和 Renovate 自己的 auto-merge 状态。

如果生成的 release-pin 更新触碰 maintenance policy（含 workstation 增量）、
maintenance 脚本、maintenance workflow 或 Renovate config，即使 required gate
通过，也不会交给 auto-merge；这类 PR 会保留为 draft/manual-review，并需独立审查。

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

允许列表只覆盖生成式 glue 和轻量包装：Home Manager 文件/ generation、NixOS unit/restart/activation 文件、生成的 manifest、repo-local Codex skill packaging，以及已声明的 MCP wrapper derivation 可以继续。Codex、Playwright CLI 和 ZeroClaw 这种已声明的固定输出 release 直连 fetch 也可以通过已配置的维护代理继续。其他本地构建会被当作门控失败处理；kernel、Mesa、systemd package、Hyprland package、GCC/Rust toolchain、Chromium/Electron 和大型字体流水线仍然会被拦截。

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
