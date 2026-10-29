# 维护指南

#### 中文 | [English](maintenance.md)

需要升级时更新指定的 flake input，查看并提交差异，再运行 `maint-switch`
构建和应用当前 checkout。input 是 flake 的依赖输入；一个 input 可能提供多个组件，
更新它不保证只改变一个软件。

## 按需更新

`renovate.json` 已停用 Renovate。配置进入默认分支后，Renovate 不再提出更新，
后续运行会执行其自身对已有机器人工作的一次性清理。

先选定要更新的 input。如果 `flake.nix` 中的 URL 固定了 revision 或 tag，先修改
该 pin。以下以 `nixpkgs-tools` 为例：

```nu
cd /path/to/dotfiles
with-env (dotfiles-maint-config) {
  nix flake update nixpkgs-tools
}

git diff -- flake.nix flake.lock
git add flake.nix flake.lock
git commit -m "chore: update nixpkgs-tools input"
maint-switch
```

更新其他输入时，使用 `nix flake update INPUT`，将 `INPUT` 替换为输入名。
只暂存预期改动。激活前提交有助于识别和撤销变更；`maint-switch` 不强制检查
checkout 是否干净，也不会创建提交、拉取 Git 更新或更新 inputs。

Codex 运行时来自 `llm-agents`：独立 CLI 包含配套的 Code Mode Host，供终端、
Improve 和 doctor 使用。桌面启动器通过 `CODEX_CLI_PATH` 选择该 CLI。
`codex-base` 提供配置、Improve 和技能。更新其中任一输入后，应检查运行时与
继承配置是否适配。已运行的桌面应用或 SSH App Server 会保留原后端，直到重启。

## 缓存与代理配置

`homePC` 和 `linglong` 使用适合中国大陆网络的配置：

```nix
dotfiles.nixNetwork.profile = "china";
```

Nix 依次尝试 USTC（`priority=10`）、官方 `cache.nixos.org`（`priority=40`），
以及目标已声明的第三方缓存（`priority=60`）。数字越小越优先，同级缓存不保证顺序。
共享 headless 配置为 `llm-agents.nix` 加入 Numtide 缓存；桌面配置另外加入
Anyrun、Hyprland 和 Noctalia Cachix 缓存。URL 与签名公钥集中在
`lib/nix-caches.nix`；global profile 使用官方主缓存。

Nix 使用原生缓存选择和默认元数据有效期。没有可用替代时允许源码编译。
`fallback=false` 仍阻止缓存下载失败后静默转为源码编译，签名校验保持启用。
维护流程不再运行缓存预检或编译分类门禁。

本地代理在 NixOS 配置中声明：

```nix
dotfiles.nixNetwork.proxy = {
  enable = true;
  url = "http://127.0.0.1:7897";
};
```

代理只供 `nix-daemon` 和 `/etc/dotfiles/nix-network.json` 使用，后者由
`dotfiles-maint-config` 读取。USTC 位于 `NO_PROXY` 中，使用直连。
维护命令只在构建期间应用这些值，激活在该环境作用域之外执行；桌面会话不继承
这组代理。手动更新 inputs 使用上面的局部 `with-env` 命令。能直连配置源时，
维护命令不要求必须存在代理。

网络失败应按获取路径诊断：Nix 缓存替代、GitHub 源码或发行包下载、npm/node-gyp、
Cargo 和应用运行时流量各有路径，不能用其中一条路径的修复推断其他失败的原因。

## 本机 `maint-switch`

```nu
maint-switch
maint-switch --repo /path/to/another/checkout
maint-switch --boot
```

命令从 `XDG_CONFIG_HOME` 下读取 `dotfiles/maint.nuon`；未设置该变量时使用
`~/.config`。Home Manager 在此写入 repo、host 和 parallel 设置。
`--repo` 只覆盖本次调用的 checkout 路径。

命令只构建选定主机一次，显示构建日志并禁止更新锁文件。构建成功且返回唯一的
非空目标路径后，才用该路径调用 `sudo nixos-rebuild --no-reexec … --store-path`。
构建失败不会激活；激活失败会向调用者报告。命令不修改 checkout 中的文件，
因此不必为了维护而单独提交主机上的 Rime 数据。

`--boot` 将配置设为下次启动生效，并提示重启。不加该参数时，如果目标内核与
当前启动内核不同，或 NVIDIA 用户态程序发生变化，会自动使用 `boot`；其他变化
使用 `switch` 立即切换。

命令级默认并发为 `max-jobs=4`、`cores=2`，可通过维护设置覆盖。
HTTP 下载并发属于 daemon 设置，NixOS 配置使用 `http-connections=8`。

## CI 与下游接口

`.github/workflows/maintenance-gate.yml` 中唯一的 `maintenance gate` job
使用 Nix 2.34.7 和 `NIXPKGS_ALLOW_UNFREE=1` 检查 `github.sha`。它预求值
Hyprland 源码，运行 `flake check --no-build`，求值合成的 `ci@headless`
Home Manager activation，并构建既有的 WeChat controller、Codex adapter 和
repo-local skill 检查。这些工作交给 CI；通过不代表完整系统构建或主机激活已通过。

工作流保留 pull request、merge group 和手动触发。调整工作流时保留现有的
required check 名称。工作流和 Renovate 配置变更需要人工审查；本次不调整分支保护。

`lib.maintenancePolicyBase` 和 `lib.extendMaintenancePolicy` 继续服务下游，
基础数据来自 `scripts/maint/policy.json`。上游 CI 与 `maint-switch` 不再消费它们。
桌面 policy 和组合导出 `lib.maintenancePolicy` 已删除。下游采用新版 helper 时，
需从手动示例中删除 `--no-pull`；新版始终应用当前 checkout。

## 首次采用与恢复

从新 checkout source `home/shell/nushell/maint.nu` 只替换 shell 入口。
首次构建仍使用运行中 daemon 的缓存配置和信任，新优先级与签名公钥在系统激活后
才生效。信任迁移见 [#205](https://github.com/bioinformatist/dotfiles/issues/205)；
不要用 `sudo build`、临时增加信任或扩大 `trusted-users` 绕过这一步。

撤销仓库变更可恢复旧代码；已经激活的系统可选择上一代 NixOS 配置恢复。
[#259](https://github.com/bioinformatist/dotfiles/issues/259) 的按需维护决定替代了
此前禁止无缓存编译的要求。[#240](https://github.com/bioinformatist/dotfiles/issues/240)
的应用范围仍是独立工作。
