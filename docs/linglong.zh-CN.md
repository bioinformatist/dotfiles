# Linglong 便携主机

本页记录玲珑键盘电脑的声明式安装边界。官方产品页标称配置包括 AMD Ryzen 7 8840U、AMD Radeon 780M、Wi-Fi 6、Bluetooth 5.2 和约 59Wh 电池；最终硬件配置仍以实机探测为准。

## 配置边界

`linglong` 是 `homePC` 的便携日常桌面变体：

- 继承 `profiles.workstation`、Hyprland、PipeWire、Fcitx5/Rime、中文字体和日常 GUI 工具。
- 继承中国网络/代理设置、Clash Verge、GitHub SSH、公司 SSH、Codex GitHub/Context7 token。
- 使用 `nixosModules.amdMobile` 提供 AMD 图形、固件、电池、电源 profile、fwupd 和硬件诊断工具。
- 启用 `bolt` 管理 USB4/Thunderbolt 扩展坞授权，并持久化 `/var/lib/boltd`；不预设 AR 眼镜或具体外接显示器布局。
- 使用导出的共享 Noctalia v5 桌面壳，通过原生面板使用 NetworkManager、BlueZ、PipeWire、UPower 和 power-profiles-daemon 后端。
- 不继承 NVIDIA、Steam/Gamemode、Mudfish、ZeroClaw、D2R。

## 安装前检查

安装策略是整盘 NixOS/disko，会擦除出厂 Windows 和目标磁盘上的所有数据。

1. 在安装环境中确认目标磁盘：
   ```bash
   ls -l /dev/disk/by-id/
   ```
2. 确认 `hosts/linglong/disko-config.nix` 指向实机 NVMe：`/dev/disk/by-id/nvme-eui.00000000000000006479a79d2a30174b`。
3. 确认 `hosts/linglong/hardware-configuration.nix` 已使用实机生成结果，initrd 模块包含 `thunderbolt`。
4. 将 sops age key 放到目标系统的 `/persist/var/lib/sops-nix/key.txt`。

## 首次启动验收

重建并启动后，检查：

- `hostname` 输出 `linglong`。
- Noctalia 原生网络和蓝牙面板可配置 Wi-Fi、蓝牙电源和设备配对。
- USB4/Thunderbolt 扩展坞的 USB、网口、供电和外接显示正常。
- 每台已连接显示器上都有带轮廓和辉光的 Noctalia 状态栏，空工作区 1–10 清晰可见。
- Noctalia 原生音频、通知、控制中心和会话面板可用，主音量不会超过 100%。
- Noctalia 显示电池，并在支持时提供亮度和电源 profile；硬件或后端缺失时不显示损坏控件。
- `powerprofilesctl get` 能返回当前电源 profile，Noctalia 原生客户端能切换守护进程报告的 profile。
- `vulkaninfo --summary` 和 `vainfo` 能看到 AMD/Mesa 能力。
- Noctalia 的 GPU 数值在驱动暴露 telemetry 时显示，否则安全降级。
- `ssh 116` 使用 `~/.ssh/id_ed25519_sctmes_ops`。
- GitHub SSH、`gh auth status`、Codex GitHub MCP 和 Context7 MCP 可用。
- Hyprland 光标、外接显示器、挂起/恢复、亮度键、音量键正常。

Linglong 继续使用主机专属的窄化 power-profiles-daemon 补丁：它只忽略厂商固件对
per-policy boost 写入返回的 `G_IO_ERROR_INVALID_ARGUMENT`。Noctalia 只是该后端的
原生客户端；补丁内容和主机专属边界不因桌面壳迁移而扩大。
