# 日常使用指南

#### 中文 | [English](daily-usage.md)

本指南概述了此 NixOS 系统中配置的应用程序、快捷键和日常工作流。

## 🖥️ 主机配置

本仓库支持多主机配置，通过共享模块（`nixos/common.nix`、`nixos/desktop.nix`）复用通用配置：

| 属性 | `vm-test` | `workstation` |
| :--- | :--- | :--- |
| **主机名** | `homePC` | `homePC` |
| **架构** | `x86_64-linux` | `x86_64-linux` |
| **用户** | `ysun` | `ysun` |
| **引导** | GRUB（EFI，可移动模式） | systemd-boot |
| **根文件系统** | 临时（`tmpfs`），持久化于 `/persist` | 同左 |
| **网络** | `wpa_supplicant`（硬编码 SSID） | `NetworkManager` |
| **GPU** | 软件渲染（`vm-tweaks.nix`） | 硬件加速 |
| **时区** | `Asia/Shanghai` | `Asia/Shanghai` |

### NixOS 基础设施模块

| 模块 | 用途 |
| :--- | :--- |
| [disko](https://github.com/nix-community/disko) | 声明式磁盘分区（GPT，btrfs 子卷用于 `/nix` 和 `/persist`） |
| [impermanence](https://github.com/nix-community/impermanence) | 临时根文件系统 —— 仅白名单路径在重启后保留 |
| [sops-nix](https://github.com/Mic92/sops-nix) | 声明式密钥管理，使用 Age 加密（两台机器共享同一 key） |
| [home-manager](https://github.com/nix-community/home-manager) | 用户级配置管理（作为 NixOS 模块集成） |
| `vm-tweaks.nix` | 仅 `vm-test`：VMware 虚拟机支持，强制软件渲染 |

### 持久化路径（Impermanence）

**系统级**：`/var/log`、`/var/lib/bluetooth`、`/var/lib/nixos`、`/var/lib/systemd/coredump`、`/etc/NetworkManager/system-connections`、`/var/lib/sops-nix`、`/var/lib/colord`、`/etc/machine-id`、SSH 主机密钥。`workstation` 额外持久化 `/var/lib/NetworkManager`。

**系统级**：

| 路径 | 用途 |
| :--- | :--- |
| `/var/log` | 系统日志 |
| `/var/lib/bluetooth` | 蓝牙设备配对信息 |
| `/var/lib/nixos` | NixOS 状态（UID/GID 映射） |
| `/var/lib/systemd/coredump` | 崩溃转储文件 |
| `/etc/NetworkManager/system-connections` | 已保存的 Wi-Fi / VPN 配置（仅 `workstation`） |
| `/var/lib/NetworkManager` | NetworkManager 运行时状态（仅 `workstation`） |
| `/var/lib/sops-nix` | 用于解密 secrets 的 Age 密钥 |
| `/var/lib/colord` | 颜色配置文件校准数据 |
| `/etc/machine-id` | 机器唯一标识（systemd / journald 所需） |
| `/etc/ssh/ssh_host_*` | SSH 主机密钥（避免重启后 known_hosts 警告） |

**用户（`ysun`）**：

| 路径 | 用途 |
| :--- | :--- |
| `~/github.com` | 所有源码和 dotfiles |
| `~/.config/sops` | sops 解密所需的 Age 私钥 |
| `~/.config/nushell` | Nushell 用户配置（env.nu、config.nu） |
| `~/.config/google-chrome` | Chrome 配置（书签、密码、扩展） |
| `~/.config/Antigravity` | Antigravity IDE 登录与会话状态（仅 `workstation`） |
| `~/.config/claude` | Claude Code 凭据（`proxy.nuon`） |
| `~/.claude` | Claude Code 记忆、对话历史、会话数据 |
| `~/.local/share/io.github.clash-verge-rev.clash-verge-rev` | Clash Verge 代理配置和设置 |
| `~/.local/share/fcitx5` | Rime 用户词典和学习数据 |
| `~/.local/share/TelegramDesktop` | Telegram 登录会话和聊天缓存（仅 `workstation`） |
| `~/.local/share/Steam` | Steam 游戏、Proton 前缀、存档（仅 `workstation`） |
| `~/.cargo/registry` | Cargo 包缓存（加速 Rust 构建，仅 `workstation`） |
| `~/.gemini` | Antigravity IDE 知识库和对话数据（仅 `workstation`） |
| `~/xwechat_files` | 微信聊天记录和文件 |
| `~/Downloads` | 下载目录（仅 `workstation`） |
| `~/Documents` | 文档目录（仅 `workstation`） |
| `~/.ssh/known_hosts` | SSH 已知主机（以文件而非目录形式持久化，详见配置注释） |
| `~/.config/hypr/monitors.conf` | nwg-displays 写入的显示器布局 |
| `~/.zeroclaw/active_workspace.toml` | ZeroClaw 工作区标记 |
| `~/.zeroclaw/estop-state.json` | ZeroClaw 紧急停止状态 |
| `~/.zeroclaw/memory.sqlite` | ZeroClaw 对话记忆数据库 |

其他所有内容在重启时清除。

---

## 🚀 已安装软件

### 桌面与 GUI

| 应用 | 包 / 来源 | 说明 |
| :--- | :--- | :--- |
| **Hyprland** | `inputs.hyprland`（flake） | 动态平铺 Wayland 合成器，通过 UWSM 启动 |
| **Ghostty** | `pkgs.ghostty` | 现代 GPU 加速终端模拟器（Zig），Linux 上原生 GTK |
| **Google Chrome** | `pkgs.google-chrome` | Web 浏览器 |
| **Clash Verge** | `programs.clash-verge`（NixOS 模块） | GUI 代理客户端（灵活网络管理） |
| **Eww** | `pkgs.eww` + Home Manager | 桌面小部件和状态栏 |
| **Dunst** | Home Manager 服务 | 通知守护进程 |
| **swww** | `inputs.swww`（flake） | Wayland 壁纸守护进程，附带多显示器随机轮换脚本 |
| **Antigravity** | `inputs.antigravity`（flake） | IDE |
| **hyprlock** | `pkgs.hyprlock` | Hyprland 原生锁屏 |
| **XDG Desktop Portal** | `xdg-desktop-portal-hyprland` | Hyprland 原生门户（屏幕共享、文件对话框等） |
| **微信** | `pkgs.wechat-uos` | 微信桌面客户端（通过 XWayland 运行） |
| **grim** + **slurp** | `pkgs.grim`、`pkgs.slurp` | Wayland 屏幕截图 + 区域选择器 |
| **satty** | `pkgs.satty` | 截图标注编辑器（箭头、文字、模糊、画笔） |

### TUI & Shell

| 应用 | 包 / 来源 | 说明 |
| :--- | :--- | :--- |
| **[Nushell](https://www.nushell.sh/)** | `pkgs.nushell`（默认 shell） | 将数据视为结构化表格的现代 Shell |
| **[Starship](https://starship.rs/)** | Home Manager | 极简、极速的跨 Shell 提示符 |
| **[Helix](https://helix-editor.com/)**（`hx`） | Home Manager | 后现代模态文本编辑器（`$EDITOR` / `$VISUAL`） |
| **[Yazi](https://yazi-rs.github.io/)** (`y`) | `inputs.yazi`（flake） | 极速终端文件管理器（Rust）。使用 `y`（而非 `yazi`）——shell 封装器在退出时会自动切换工作目录 |
| **[Zellij](https://zellij.dev/)** | Home Manager | 终端复用器（窗格 + 标签页） |
| **[ripgrep](https://github.com/BurntSushi/ripgrep)**（`rg`） | Home Manager | 递归正则表达式搜索工具 |

### 系统工具

| 包 | 说明 |
| :--- | :--- |
| `git` | 版本控制 |
| `wl-clipboard` | Wayland 剪贴板工具（`wl-copy` / `wl-paste`） |
| `proxychains` | 强制任何程序通过 SOCKS5/HTTP 代理（`127.0.0.1:7897`） |
| `nix-ld` | 未打补丁二进制文件的动态链接器 |

### 输入法

| 组件 | 说明 |
| :--- | :--- |
| **Fcitx5**（系统级） | 输入法框架，已启用 Wayland 前端 |
| **Fcitx5**（用户级 / Home Manager） | 插件：`fcitx5-rime`、`fcitx5-gtk`、`fcitx5-chinese-addons`、`fcitx5-configtool` |

### 字体

| 字体 | 用途 |
| :--- | :--- |
| Sarasa Gothic（更纱黑体） | 默认无衬线字体（CJK） |
| Noto Sans/Serif CJK SC | CJK 回退字体 |
| JetBrains Mono | 默认等宽字体 |

### 服务与安全

| 项目 | 详情 |
| :--- | :--- |
| **PipeWire** | 音频服务器（ALSA + PulseAudio 兼容，32 位支持） |
| **OpenSSH** | SSH 守护进程已启用 |
| **ssh-agent** | 用户级 SSH Agent（Home Manager 服务） |
| **rtkit** | PipeWire 实时调度 |
| **sudo** | `ysun` 拥有免密码 `NOPASSWD` sudo |

---

## ⌨️ 快捷键（Hyprland）

**SUPER** 键（Windows 键）是大多数快捷键的主修饰符。

### 系统操作
| 快捷键 | 操作 |
| :--- | :--- |
| `SUPER + SHIFT + Q` | **强制注销**（终止 Hyprland 会话） |
| `SUPER + C` | **关闭**当前窗口 |
| `SUPER + V` | 切换**浮动** |
| `SUPER + F` | 切换**全屏** |
| `SUPER + Return` | 启动**终端**（Ghostty） |
| `SUPER + B` | 启动**浏览器**（Chrome） |
| `SUPER + SHIFT + G` | 启动 **Antigravity IDE** |
| `SUPER + SHIFT + P` | 启动**代理客户端**（Clash Verge） |
| `SUPER + W` | 启动**微信** |
| `SUPER + L` | **锁屏**（hyprlock） |
| `SUPER + R` | 进入**调整大小模式**（方向键调整，`Escape` 退出） |
| `ALT + A` | **截图**选区 → 标注（satty） → 剪贴板 |
| `Print` | **截图**选区 → 标注（satty） → 剪贴板 |
| `SUPER + Print` | **截图**全屏 → 标注（satty） → 剪贴板 |

### 窗口 & 工作区管理
| 快捷键 | 操作 |
| :--- | :--- |
| `SUPER + 方向键` | 在窗口之间移动焦点 |
| `SUPER + SHIFT + 方向键` | 移动/交换窗口位置 |
| `SUPER + [1-0]` | 切换到**工作区** 1-10 |
| `SUPER + SHIFT + [1-0]` | 将当前窗口移至**工作区** 1-10 |
| `SUPER + S` | 切换**特殊工作区**（暂存区） |
| `SUPER + SHIFT + S` | 将窗口移至**特殊工作区** |
| `SUPER + G` | 切换分组（标签页模式） |
| `SUPER + A` | 在分组内切换活动窗口 |
| `SUPER + P` | 伪平铺（Dwindle 布局） |
| `SUPER + J` | 切换分割方向（Dwindle 布局） |
| `SUPER + 鼠标左键` | 拖拽移动窗口 |
| `SUPER + 鼠标右键` | 拖拽调整窗口大小 |

### 多媒体按键
- **音量**：`XF86AudioRaiseVolume` / `LowerVolume` / `Mute`
- **亮度**：`XF86MonBrightnessUp` / `Down`
- **播放控制**：`XF86AudioPlay` / `Next` / `Prev`（需要 `playerctl`）

---

## 🔄 日常系统更新

本节适用于**已安装并正常运行的系统**上的日常包更新流程。无需 ISO 或重新安装。

> **Shell 说明**：本节在已配置好的系统上操作，使用 **Nushell**。语法有所不同。

### 中国大陆网络须知

更新过程中有**两类**网络请求，加速方式不同：

| 请求类型 | 用途 | 加速方式 |
|---|---|---|
| **GitHub 源码获取** | `nix flake update` 拉取 flake inputs（HTTPS tarball） | 必须走**代理**，USTC 镜像无法加速 |
| **二进制缓存下载** | `nixos-rebuild` 从 cache 下载预编译包 | 使用 **USTC 镜像**（`--option substituters`） |

> **为什么代理能生效？** Nix 底层使用 **libcurl** 进行 HTTP 请求，libcurl 原生支持
> `http_proxy`/`https_proxy` 环境变量。`nix flake update` 对 `github:` 类型的 input
> 是通过 HTTPS 下载 tarball（而非 `git clone`），因此会自动使用代理。

因此，完整更新需要**同时**配置代理和 USTC 镜像。

**设置代理**（Nushell 语法，局域网代理或本机代理均可）：
```nu
# 将地址替换为你的实际代理地址
# 本机代理示例：http://127.0.0.1:7890
# 局域网代理示例：http://192.168.1.100:7890
$env.http_proxy = "http://<代理地址>:<端口>"
$env.https_proxy = "http://<代理地址>:<端口>"
```

### 第 1 步：更新 Flake 输入（`flake.lock`）

此命令从 GitHub 拉取所有依赖的最新版本（nixpkgs、home-manager、hyprland 等）。

```nu
cd /path/to/dotfiles   # 例如 ~/github.com/bioinformatist/dotfiles

# 确保已设置代理（见上方）
nix flake update
```

此操作会修改 `flake.lock` 文件——之后应提交该文件。

### 第 2 步：重建并切换

将更新后的软件包应用到运行中的系统。

> **重要**：`sudo` 默认会**丢弃**当前用户的环境变量（包括 `http_proxy`/`https_proxy`）。
> 必须使用 `sudo -E`（`--preserve-env`）来保留代理设置，否则构建过程中需要从 GitHub 拉取源码的包会失败。
> Nushell 通过 `$env` 设置的变量会被传递给子进程，因此 `sudo -E` 可以正确继承它们。

```nu
# 将 <host> 替换为你的主机名：vm-test、workstation 等
# -E 保留代理环境变量；--option substituters 使用 USTC 二进制缓存镜像
sudo -E nixos-rebuild switch --flake $".#<host>" --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org"
```

如果不需要代理（网络畅通），可以省略 `-E` 和代理设置：
```nu
sudo nixos-rebuild switch --flake $".#<host>"
```

### 第 3 步：提交锁文件

```nu
git add flake.lock
git commit -m "chore: update flake inputs"
git push
```

### （可选）切换前预览变更

如果想**只构建不激活**（先检查是否有构建错误）：

```nu
sudo -E nixos-rebuild build --flake $".#<host>" --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org"
```

或使用 `test` 临时激活（下次重启后恢复）：

```nu
sudo -E nixos-rebuild test --flake $".#<host>" --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org"
```

---

## 🌐 网络代理 & 动态路由

系统采用**"本地回环抽象"**策略：
- **NixOS（系统级）**：配置为*始终*信任 `http://127.0.0.1:7897`（本地回环）。切换底层网络时无需更改系统配置。
- **Clash Verge（用户 GUI）**：负责处理实际的上游连接（如局域网代理、机场 WiFi、5G 热点等）。

| 项目 | 详情 |
| :--- | :--- |
| **WiFi** | `vm-test`: `wpa_supplicant`；`workstation`: `NetworkManager` |
| **系统代理** | 始终指向 `http://127.0.0.1:7897`（本地回环抽象） |
| **Clash Verge** | 处理实际上游路由（局域网代理、机场、热点等） |
| **Nix Substituters** | USTC 镜像（主）、Hyprland cachix、Yazi cachix |

### 设置上游局域网代理

例如 `192.168.0.116:7890`：

1.  启动 **Clash Verge**（`SUPER + SHIFT + P`）。
2.  进入 **Profiles** -> **New Local Profile**。
3.  右键新配置文件 -> **Edit File**。
4.  将局域网代理添加为"Proxy"节点：
    ```yaml
    proxies:
      - name: "My LAN Proxy"
        type: http # 或 socks5
        server: 192.168.0.116
        port: 7890

    proxy-groups:
      - name: Proxy
        type: select
        proxies:
          - "My LAN Proxy"
    ```
5.  选择此配置文件激活。系统将自动通过本地回环接口路由流量。

### 从 sops 导入订阅（新机器首次设置）

订阅链接通过 sops-nix 加密存储在仓库中（参见 [密钥管理指南 § Clash 订阅](./secret-management.zh-CN.md)）。执行 `nixos-rebuild switch` 后，将其导入 Clash Verge：

1.  读取解密后的订阅链接：
    ```bash
    cat /run/secrets/clash-subscription-url
    ```
2.  启动 **Clash Verge**（`SUPER + SHIFT + P`）。
3.  进入 **Profiles** 页面。
4.  将链接粘贴到顶部输入框并点击 **Import**。
5.  点击导入的配置文件以**激活**。

> 每台机器只需执行一次。配置文件数据持久化在 `~/.local/share/io.github.clash-verge-rev.clash-verge-rev/` 中，重启后保留。Clash Verge 也会按设定间隔自动更新订阅。

---

## 🎮 游戏

### Battle.net 安装（Steam + Proton）

Battle.net 作为**非 Steam 游戏**添加到 Steam，通过 Proton 兼容层运行。

1. 下载 `Battle.net-Setup.exe`（官网检测到 Linux UA 会屏蔽下载按钮，用 `curl` 绕过）：
   ```nushell
   # 国服（中国大陆）
   curl -L -o Battle.net-Setup-CN.exe "https://downloader.battlenet.com.cn/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live"
   # 国际服（备用）
   curl -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -L -o Battle.net-Setup.exe "https://www.battle.net/download/getInstallerForGame?os=win&locale=enUS&version=LIVE&gameProgram=BATTLENET_APP"
   ```
2. Steam → **游戏库** → 左下角**添加游戏** → **添加非 Steam 游戏**，选择下载的安装程序
3. 右键该条目 → **属性** → **兼容性** → 勾选"强制使用特定 Steam Play 兼容工具" → 选择 **Proton-GE**
4. 启动，完成 Battle.net 安装流程
5. 安装完成后，将 **Battle.net.exe**（路径在前缀的 `drive_c/Program Files (x86)/Battle.net/Battle.net.exe`）重新添加为非 Steam 游戏，同样配置 Proton-GE
6. 通过 Battle.net 安装并启动 D2R

> Steam 为每个非 Steam 游戏创建独立的 Proton prefix，存储在 `~/.local/share/Steam/steamapps/compatdata/<数字ID>/`。

### D2R Mod 安装

**第一步：找到 D2R 所在的 Proton 前缀**

```nushell
glob "~/.local/share/Steam/steamapps/compatdata/*/pfx/drive_c/Program Files (x86)/Diablo II Resurrected"
```

记录输出路径中的数字 ID（即 `compatdata/<ID>`）。

**第二步：放入 mod 文件**

D2R mod 目录结构（以 `ProjectDiablo2` 为例）：

```
<D2R安装目录>/
└── mods/
    └── ProjectDiablo2/        ← 目录名 = mod 名
        └── ProjectDiablo2.mpq  ← .mpq 文件名 = mod 名
```

```nushell
let d2r = $"($env.HOME)/.local/share/Steam/steamapps/compatdata/<PREFIX_ID>/pfx/drive_c/Program Files (x86)/Diablo II Resurrected"
mkdir $"($d2r)/mods/ProjectDiablo2"
cp ProjectDiablo2.mpq $"($d2r)/mods/ProjectDiablo2/"
```

**第三步：设置启动参数**

在 Battle.net → D2R **游戏设置 → 其他参数** 中添加：
```
-mod ProjectDiablo2 -txt
```

> `-mod` 指定 mod 名（与 `mods/` 下子目录名一致），`-txt` 允许 mod 覆盖文本文件（部分 mod 必需）。

---

## 🛠 注意事项

### 数据持久化
本系统采用**临时根文件系统**方案。仅特定目录在重启之间保持持久化，详见上方"持久化路径"表格。

### 软件渲染（仅 VM）
在 GPU 加速不稳定的虚拟机环境中，通过全局设置 `LIBGL_ALWAYS_SOFTWARE=1` 强制使用软件渲染。物理机（`workstation`）不包含此设置。

### Fcitx5 重启后无响应（Ctrl+Space 失效）

在非正常关机或重启后，fcitx5 可能正常启动但 Wayland 前端未能正确初始化。症状：`Ctrl+Space` 无反应，`fcitx5-remote` 输出 `0`（无法连接）。

修复方法——在 Hyprland 的 Wayland 上下文中重启 fcitx5：

```nu
pkill fcitx5
hyprctl dispatch exec "fcitx5 -d --replace"
```

根本原因：在 Hyprland 进程树之外启动 fcitx5（例如从终端直接运行）会导致其缺少有效的 Wayland IM 连接。始终通过 `hyprctl dispatch exec` 重启。

### Claude Code（`claude-proxy`）

Claude Code 通过 `claude-proxy` Nushell wrapper 启动，该 wrapper 从 `~/.config/claude/proxy.nuon`（不被 git 追踪）读取凭据和代理配置并注入为环境变量。所有子进程（包括 MCP server）都会继承这些变量。

**`proxy.nuon` 格式：**
```nushell
{
  ANTHROPIC_BASE_URL: "http://<api-relay>:<port>/",
  ANTHROPIC_AUTH_TOKEN: "sk-...",
  ANTHROPIC_MODEL: "claude-...",
  HTTP_PROXY: "http://<lan-proxy>:<port>",
  HTTPS_PROXY: "http://<lan-proxy>:<port>"
}
```

当局域网代理地址变更时，只需更新此文件中的 `HTTP_PROXY`/`HTTPS_PROXY`，无需修改任何 MCP 或 shell 配置。

### Sops 首次引导
如果你在新机器上运行 `sops` 时找不到密钥，请在 Nushell 中运行：
```nu
$env.SOPS_AGE_KEY_FILE = ("~/.config/sops/age/keys.txt" | path expand)
```
此设置已在 `config.nu` 中配置，但在未重启或未重新应用配置时可能需要手动执行。
