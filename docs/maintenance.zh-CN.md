# 维护指南

#### 中文 | [English](maintenance.md)

推荐的日常维护入口仍然只有一个：

```nu
maint-switch
```

根目录 `flake.lock` 输入更新由 Renovate 提出。变更进入 `main` 后，`maint-switch` 执行最后的中国大陆网络门控和系统切换。

## 声明式网络配置

`homePC` 和 `linglong` 默认选择中国大陆网络 profile：

```nix
dotfiles.nixNetwork.profile = "china";
```

Nix 依次尝试 USTC（`priority=10`）、官方 `cache.nixos.org`（`priority=40`），
再尝试当前目标声明的第三方缓存（`priority=60`）。数字越小越优先；同级缓存之间
不约定顺序。共享 headless profile 为 `llm-agents.nix` 包加入 Numtide 缓存；
workstation 另加 Anyrun、Hyprland 和 Noctalia Cachix。URL 和公开签名密钥
统一维护在 `lib/nix-caches.nix`；global profile 使用官方主缓存。

保留 Nix 默认的元数据查询有效期。`fallback=false` 防止替代下载失败后自动转为
源码构建，签名校验继续启用。本地代理 URL 在 NixOS 配置中声明：

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
| `nixpkgs-desktop` | `desktop` | 固定的 `nixpkgs-desktop` 输入中的 Hyprland 及配套 portal |
| `noctalia` | `desktop` | Noctalia 稳定版输入 |
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

Codex 运行包来自 `llm-agents`：独立 CLI 包含配套的 Code Mode Host，供 headless
和桌面主机的终端、Improve、doctor 使用。桌面启动器通过 `CODEX_CLI_PATH` 选择
同一个 CLI。`codex-base` 提供配置、Improve 和 skills。
Renovate 分别更新这两个根输入；任一更新后，都需要检查所选运行包与继承配置、
工作流的兼容性。运行中的桌面应用或 SSH App Server 后台需要重启才会切换版本。

默认分支应通过 ruleset 保护：要求 PR，并要求 `maintenance gate` 状态检查，且启用
strict up-to-date checks。

required `maintenance gate` check 汇总两个 job。`configuration` 运行原生
flake 求值、合成的 `ci@headless` Home Manager activation 求值，以及已有的
WeChat 控制、Codex adapter、repo-local skills 轻量检查和共享预检测试。
`cache-preflight` 检查 `github.sha` 对应的完整候选，覆盖 `homePC`、`linglong`
和 `ci@headless`。两个 job 均使用 Nix 2.34.7；失败或无法判断都会阻止 required
check 通过。这些检查交给 CI；本地用
`bash scripts/maint/test-cache-preflight.sh --local-maint` 验证 Nu 入口，模拟
build/sudo，不实际构建或激活。

预检读取每个目标求值后的缓存 URL 和信任公钥。缓存、密钥及策略相同的目标
合并为一次原生多目标 dry-run，使用本次新建的隔离 store，避免 runner 已安装
的包掩盖替代缺口。Nix 负责规划运行时引用和必要构建依赖，门禁对全部待本地
构建产物分类。已有与新增的未批准编译都会阻塞；后续受信任来源能提供产物时，
不强制 USTC 命中。不再比较 base，也不二次扫描镜像或逐个探测压缩包。

预检要求 JSON 根目标有效且覆盖全部请求目标，并从 Nix `internal-json` 诊断中
得到完整、非空的 build/fetch 计划。截断、未知输出、查询失败及未解决引用均不能
通过；warning 后成功恢复并得到完整计划，不会仅因该 warning 失败。结果分为
`pass`、`blocked`、`inconclusive`；无论成功失败，均上传摘要、完整路径列表、
目标分组映射及原始日志。“无可用替代”只描述当前 Nix 计划，不证明每个远端
缓存都没有该产物。

这是元数据预检，不会逐个下载压缩包，也不证明主机上的下载和签名校验必然成功。
实际下载及主机激活分别验收。部分 unfree 软件没有可分发的二进制缓存，只有
经过审查的厂商二进制下载／包装可以放行，否则保持阻塞。CI 通过
`NIXPKGS_ALLOW_UNFREE=1` 允许求值，不因此豁免源码编译。

共享策略在 `scripts/maint/policy.json`，workstation 增量在
`scripts/maint/policy-workstation.json`。桌面 CI 和本机 `maint-switch` 使用
`lib.maintenancePolicy`；合成 headless CI 使用 `lib.maintenancePolicyBase`，
不带桌面缓存。两端共用 `nix-plan.jq` 和 `classify-plan.jq`。下游继续通过
`lib.extendMaintenancePolicy` 扩展 `lib.maintenancePolicyBase`。leaf 直连下载
权限仍与一般 direct-fetch 策略取交集。

按照 [#259](https://github.com/bioinformatist/dotfiles/issues/259) 的决策，
需要旧版缓存时，在输入更新阶段验证并固定版本；门禁不动态选版或改写锁文件。
[#240](https://github.com/bioinformatist/dotfiles/issues/240) 的应用范围另行处理。

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
check 是 whole-host 合入决策。Renovate PR 也依赖同一 required check 和 Renovate
配置的合并策略。

maintenance policy（含 workstation 增量）、maintenance 脚本、maintenance
workflow 或 Renovate config 的变更，即使 required gate 通过，也需独立审查。

如果 gate 或 marker policy 自身坏掉，修复可能无法通过正在被它修复的同一个
gate 合入。这种窄场景可以使用 admin bootstrap：临时关闭 main ruleset，只合入
gate 或 policy 修复，然后立刻恢复 ruleset。不要用这条路径合入包版本更新。
该操作需要操作人明确授权；候选检查失败本身不授权修改分支保护。

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

`maint-switch` 从 `XDG_CONFIG_HOME` 读取 `dotfiles/maint.nuon` 和两个 jq
辅助文件；未设置该变量时使用 `~/.config`。Home Manager 安装辅助文件和 jq，
缺失时停止维护。默认使用配置中的 repo 路径；需要从 clean worktree 维护时，
可以显式传入 repo 路径并跳过内置 pull：

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
`nixos-rebuild --no-reexec boot --store-path ...`，并提示必须重启。它是有意延后激活的显式路径，
不是日常默认；不传该标志时，现有 kernel/NVIDIA 风险自动选择保持不变。

本机门禁使用运行中 daemon 的缓存权限。daemon 已持有完整 closure 时，合法
空计划允许通过；CI 的冷计划必须非空。dry-run 和实际 build 都禁用 fallback
及锁文件写入。下载和构建在 `sudo` 前完成，激活只消费已生成的 store path，
使用 `nixos-rebuild --no-reexec ... --store-path`。

CI 可以使用候选声明的新密钥，而旧主机 daemon 可能尚未信任它们。出现不信任
缓存的诊断时，按 [#205](https://github.com/bioinformatist/dotfiles/issues/205)
先通过正常维护路径完成缓存信任迁移，再验收新缓存的本机行为；不通过
`sudo build` 或扩大 `trusted-users` 绕过边界。

默认阻断标记包括：

- `linux-`、`nvidia-x11`、`mesa-`、`systemd-`
- `hyprland` 和 `hypr*` 相关组件
- `gcc-`、`xgcc`、`rustc-`、`cargo-vendor`
- `chromium`、`electron`
- `serenityos-emoji-font`、`nanoemoji`

允许列表覆盖已审查的生成、组装、链接和二进制包装，包括 Home Manager
generation、NixOS activation 文件、已声明的 MCP wrapper 和现有 Helix 包装。
声明过的厂商下载可通过维护代理执行。当前 ChatGPT 仅放行已核对的精确包装、
解包和 deb 下载 derivation；pin 或 hash 改变后需要重新审查。Codex 源码编译、
formatelf 和 linglong 补丁版 power-profiles-daemon 不获豁免。固定输出 derivation
或熟悉的软件名称，本身都不能证明没有编译。

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
