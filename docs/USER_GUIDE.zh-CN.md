# 用户指南：定制化 NixOS 环境

本指南概述了此 NixOS 系统中配置的应用程序和快捷键。

## 🖥️ 主机配置

当前仅定义了一个主机：

| 属性 | 值 |
| :--- | :--- |
| **主机名** | `vm-test`（hostname: `homePC`） |
| **架构** | `x86_64-linux` |
| **用户** | `ysun` |
| **引导** | GRUB（EFI，可移动模式） |
| **根文件系统** | 临时（`tmpfs`），持久化数据位于 `/persist`（btrfs） |
| **时区** | `Asia/Shanghai` |
| **State Version** | `24.11` |

### NixOS 基础设施模块

| 模块 | 用途 |
| :--- | :--- |
| [disko](https://github.com/nix-community/disko) | 声明式磁盘分区（GPT，btrfs 子卷用于 `/nix` 和 `/persist`） |
| [impermanence](https://github.com/nix-community/impermanence) | 临时根文件系统 —— 仅白名单路径在重启后保留 |
| [sops-nix](https://github.com/Mic92/sops-nix) | 声明式密钥管理，使用 Age 加密 |
| [home-manager](https://github.com/nix-community/home-manager) | 用户级配置管理（作为 NixOS 模块集成） |
| `vm-tweaks.nix` | VMware 虚拟机支持，强制软件渲染（`LIBGL_ALWAYS_SOFTWARE=1`） |

### 持久化路径（Impermanence）

**系统级**：`/var/log`、`/var/lib/bluetooth`、`/var/lib/nixos`、`/var/lib/systemd/coredump`、`/etc/NetworkManager/system-connections`、`/var/lib/sops-nix`、`/var/lib/colord`、`/etc/machine-id`、SSH 主机密钥。

**用户（`ysun`）**：`~/github.com`、`~/.config/sops`。

其他所有内容在重启时清除。

---

## 🚀 已安装软件

### 桌面与 GUI

| 应用 | 包 / 来源 | 说明 |
| :--- | :--- | :--- |
| **Hyprland** | `inputs.hyprland`（flake） | 动态平铺 Wayland 合成器，通过 UWSM 启动 |
| **Ghostty** | `pkgs.ghostty` | 现代 GPU 加速终端模拟器（Zig），Linux 上原生 GTK |
| **Google Chrome** | `pkgs.google-chrome` | Web 浏览器 |
| **Clash Verge** | `pkgs.clash-verge-rev` | GUI 代理客户端（灵活网络管理） |
| **Eww** | `pkgs.eww` + Home Manager | 桌面小部件和状态栏 |
| **Dunst** | Home Manager 服务 | 通知守护进程 |
| **swww** | `inputs.swww`（flake） | Wayland 壁纸守护进程，附带多显示器随机轮换脚本 |
| **Antigravity** | `inputs.antigravity`（flake） | IDE |
| **hyprlock** | `pkgs.hyprlock` | Hyprland 原生锁屏 |
| **XDG Desktop Portal** | `xdg-desktop-portal-hyprland` | Hyprland 原生门户（屏幕共享、文件对话框等） |
| **微信** | `pkgs.wechat-uos` | 微信桌面客户端（通过 XWayland 运行） |

### TUI & Shell

| 应用 | 包 / 来源 | 说明 |
| :--- | :--- | :--- |
| **[Nushell](https://www.nushell.sh/)** | `pkgs.nushell`（默认 shell） | 将数据视为结构化表格的现代 Shell |
| **[Starship](https://starship.rs/)** | Home Manager | 极简、极速的跨 Shell 提示符 |
| **[Helix](https://helix-editor.com/)**（`hx`） | Home Manager | 后现代模态文本编辑器（`$EDITOR` / `$VISUAL`） |
| **[Yazi](https://yazi-rs.github.io/)** | `inputs.yazi`（flake） | 极速终端文件管理器（Rust） |
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

### 网络与代理

| 项目 | 详情 |
| :--- | :--- |
| **WiFi** | `wpa_supplicant`，已配置 2 个 SSID |
| **系统代理** | 始终指向 `http://127.0.0.1:7897`（本地回环抽象） |
| **Clash Verge** | 处理实际上游路由（局域网代理、机场、热点等） |
| **Nix Substituters** | USTC 镜像（主）、Hyprland cachix、Yazi cachix |

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
| `SUPER + L` | **锁屏**（hyprlock） |
| `SUPER + R` | 进入**调整大小模式**（方向键调整，`Escape` 退出） |

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

## 🛠 工作流

### 密钥管理
我们使用 **Sops-Nix** 配合 **Age** 密钥。机器专属 SSH 密钥通过声明式管理，但在新物理机上需进行一次性引导。
- 参见：[docs/SECRET_MANAGEMENT.zh-CN.md](./SECRET_MANAGEMENT.zh-CN.md)

### 数据持久化
本系统采用**临时根文件系统**方案。仅特定目录在重启之间保持持久化。
- **已持久化用户路径**：`~/github.com`、`~/.config/sops`。
- 家目录下的其他所有内容在重启时将被清除，以确保干净的状态。

### 软件渲染（VM 调优）
在 GPU 加速不稳定的虚拟机环境中，通过全局设置 `LIBGL_ALWAYS_SOFTWARE=1` 强制使用软件渲染，以确保 Ghostty 等应用程序能可靠启动。

### Sops 首次引导
如果你在新机器上运行 `sops` 时找不到密钥，请在 Nushell 中运行：
```nu
$env.SOPS_AGE_KEY_FILE = ("~/.config/sops/age/keys.txt" | path expand)
```
此设置已在 `config.nu` 中配置，但在未重启或未重新应用配置时可能需要手动执行。

### 网络代理 & 动态路由
系统采用**"本地回环抽象"**策略：
- **NixOS（系统级）**：配置为*始终*信任 `http://127.0.0.1:7897`（本地回环）。切换底层网络时无需更改系统配置。
- **Clash Verge（用户 GUI）**：负责处理实际的上游连接（如局域网代理、机场 WiFi、5G 热点等）。

**如何设置上游局域网代理（例如 `192.168.0.116:7890`）：**
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
