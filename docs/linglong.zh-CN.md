# Linglong 便携主机

本页记录玲珑键盘电脑的声明式安装边界。官方产品页标称配置包括 AMD Ryzen 7 8840U、AMD Radeon 780M、Wi-Fi 6、Bluetooth 5.2 和约 59Wh 电池；最终硬件配置仍以实机探测为准。

## 配置边界

`linglong` 是 `homePC` 的便携日常桌面变体：

- 继承 `profiles.workstation`、Hyprland、PipeWire、Fcitx5/Rime、中文字体和日常 GUI 工具。
- 继承中国网络/代理设置、Clash Verge、GitHub SSH、公司 SSH、Codex GitHub/Context7 token。
- 使用 `nixosModules.amdMobile` 提供 AMD 图形、固件、电池、电源 profile、fwupd 和硬件诊断工具。
- 启用 `bolt` 管理 USB4/Thunderbolt 扩展坞授权，并持久化 `/var/lib/boltd`；不预设 AR 眼镜或具体外接显示器布局。
- 使用导出的共享 Eww 状态栏；它会为任意数量的 Hyprland 显示器创建相同布局，并由系统托盘中的 NetworkManager 与 Blueman 提供网络和蓝牙配置。
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
- Eww 系统托盘中的 NetworkManager 与 Blueman 可配置 Wi-Fi、蓝牙电源和设备配对。
- USB4/Thunderbolt 扩展坞的 USB、网口、供电和外接显示正常。
- 每台已连接显示器上都有相同的 Eww 状态栏；热插拔不会移除其他显示器上的实例。
- Eww 状态栏显示电池；GPU telemetry 不可用、Clash 未运行时，对应控件会隐藏；D2R 居中内容保持关闭。
- Eww 音频弹窗的 **Open mixer** 能启动 Pavucontrol。
- `powerprofilesctl get` 能返回当前电源 profile。
- `vulkaninfo --summary` 和 `vainfo` 能看到 AMD/Mesa 能力。
- EWW sysinfo 的 GPU 数值能在 Radeon 780M 上显示，或在驱动未暴露 telemetry 时安静隐藏。
- `ssh 116` 使用 `~/.ssh/id_ed25519_sctmes_ops`。
- GitHub SSH、`gh auth status`、Codex GitHub MCP 和 Context7 MCP 可用。
- Hyprland 光标、外接显示器、挂起/恢复、亮度键、音量键正常。
