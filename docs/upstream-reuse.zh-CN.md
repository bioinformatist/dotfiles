# 上游复用

本仓库现在显式提供一个稳定的上游复用边界，供下游 dotfiles 或产品仓库引用。

## 对外 outputs

下游仓库只应消费这些 flake outputs：

- `profiles.headless`
- `profiles.ai-serving`
- `profiles.workstationCn`
- `nixosModules.{headless,ai-serving,nixProxy,nvidiaDesktop,workstationCn}`
- `homeManagerModules.{core,tui,codex,devHeadless,workstationCn}`
- `overlays`
- `packages`
- `templates.workstation-cn`

不要在下游直接 import 本仓库内部路径，例如 `./nixos/*.nix`、`./home/*.nix` 或 `./hosts/*`。

## Profile 边界

`profiles.headless` 提供可复用的基础层：

- Nix 设置与缓存公钥
- OpenSSH 与 GitHub SSH host policy
- 由 `specialArgs.username` 定义的普通用户
- sudo 策略与核心系统默认项
- 如果 `sops.secrets` 下存在 `${username}-password`，会自动接上用户密码文件

它不包含：

- Hyprland 或 GUI 应用
- PipeWire、Bluetooth、输入法
- 公司 secrets
- 具体业务服务

`profiles.ai-serving` 只提供 GPU 宿主机能力：

- NVIDIA 驱动宿主机支持
- Docker
- Docker 的 NVIDIA Container Toolkit
- `/var/lib/ai-serving` 下的通用运行目录

它不包含 CUDA userspace，也不包含具体模型服务栈。

`profiles.workstationCn` 提供中国大陆开发工作站系统层：

- `profiles.headless`
- 中国大陆 Nix substituter / DNS 默认项
- Nix daemon 代理入口
- Hyprland / PipeWire / Fcitx5 + Rime / 中文字体
- Clash Verge、WeChat、截图工具、基础 GUI 工具

它不包含：

- 磁盘布局
- sops secrets
- 具体用户名之外的个人账号内容
- NVIDIA 桌面补丁
- ZeroClaw、D2R、公司 SSH、业务服务

NVIDIA 桌面机器应额外叠加 `nixosModules.nvidiaDesktop`。

## 当前本仓库主机组合

本仓库里的个人主机继续通过额外本地模块保持完整能力：

- `homePC`：`profiles.workstationCn` + NVIDIA 桌面集成 + 个人 Home Manager 层
- `vm-test`：`profiles.headless` + proxy + desktop + VM tweaks

## 下游示例

```nix
{
  inputs.upstream.url = "github:bioinformatist/dotfiles";

  outputs = { self, nixpkgs, upstream, ... }: {
    nixosConfigurations."116" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        username = "ops";
      };
      modules = [
        upstream.profiles.headless
        upstream.profiles.ai-serving
        ./hosts/116
      ];
    };
  };
}
```

如果下游仓库使用 `sops-nix`，那么只要声明 `sops.secrets."ops-password"`，`profiles.headless` 就会自动把它接到用户密码上。否则，下游需要自己用别的方式设置用户密码。

## 116 的上下游分工

本仓库负责可复用的 headless 层和 GPU 宿主机层。

公司下游仓库负责：

- `116` host module
- 系统 SSD 的 `disko` 布局
- `/data1` 的 mdraid 组装与挂载声明
- sops secrets 与访问策略
- `jarvis*` 的 Docker 服务定义
- `nixos-anywhere` 安装编排

## 116 安装形态

116 在下游仓库中的目标安装流程是：

1. 通过 SSH 连到现有机器
2. 运行 `nixos-anywhere`
3. 只对系统 SSD 执行 `disko` 重建
4. 保留并重新挂载现有 `/data1`
5. 将 sops age key 同时放到 `/mnt/persist/var/lib/sops-nix/key.txt` 和 `/mnt/var/lib/sops-nix/key.txt`

第一阶段里，下游仓库只需要把 `/data1` 作为“组装和挂载”层声明式接管，不要尝试重建 RAID 拓扑。
