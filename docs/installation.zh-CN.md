# 安装指南

#### 中文 | [English](installation.md)

本指南介绍如何从零部署 NixOS —— 包括虚拟机和物理机。

## 前置条件

*   **中国大陆网络**：请务必配置 USTC 镜像以加速下载。
*   **Sops 密钥**：安装前必须已生成 Age 密钥并配置好密钥文件。
    *   👉 详见 [secret-management.zh-CN.md](./secret-management.zh-CN.md)
*   **修复 & 更新**：如需在不擦除数据的情况下修复损坏的系统：
    *   👉 详见 [recovery.zh-CN.md](./recovery.zh-CN.md)

---

## 虚拟机安装（快速开始）

从 [NixOS Minimal ISO](https://nixos.org/download.html) 启动后执行：

### 第 0 步：加速网络（中国大陆）
```bash
mkdir -p ~/.config/nix
echo "substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org" >> ~/.config/nix/nix.conf
```

### 第 1 步：克隆仓库
```bash
git clone https://github.com/bioinformatist/dotfiles /tmp/dotfiles
cd /tmp/dotfiles
git checkout feat/ephemeral-root
```

### 第 2 步：分区 & 格式化（Disko）
**警告：会擦除磁盘！**
```bash
sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./hosts/vm-test/disko-config.nix
```

### 第 3 步：部署密钥（Sops）
必须手动放置 **Age 私钥**，以便安装器能解密用户密码。

```bash
# 1. 创建持久化目录
sudo mkdir -p /mnt/persist/var/lib/sops-nix

# 2. 写入密钥（将内容替换为你实际的密钥字符串 `age1...`）
sudo sh -c 'echo "AGE-SECRET-KEY-..." > /mnt/persist/var/lib/sops-nix/key.txt'
sudo chmod 600 /mnt/persist/var/lib/sops-nix/key.txt

# 3. 镜像到临时根目录（首次安装激活时必需）
sudo mkdir -p /mnt/var/lib/sops-nix
sudo cp /mnt/persist/var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/key.txt
```

### 第 4 步：安装系统
```bash
sudo nixos-install --flake .#vm-test --no-root-passwd --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store"
```

### 第 5 步：重启
```bash
sudo reboot
```

---

## 物理机部署

将 `workstation` 配置安装到一台新物理机上。本节提供两条路线，选择适合你的情况的一条。

### 前置准备（两条路线都需要）

在开始安装之前，你需要准备好 **Age 私钥**（`key.txt`）。两台机器共享同一把密钥。

> 你的 Age 私钥存放在 VM 的 `/persist/var/lib/sops-nix/key.txt`。
> 将它复制到 U 盘、通过 SSH 传输、或任何你方便的方式带到安装环境中。
> 如果你完全没有密钥，请参阅 [密钥管理指南 § 2](./secret-management.zh-CN.md) 生成一把新密钥。

---

### 路线 A：从已有机器远程安装（nixos-anywhere）

**适用场景**：你有一台已安装 Nix 且网络通畅的机器（如 VM），并且能通过 SSH 以 root 身份访问物理机（物理机上有 NixOS Live CD 或任意 Linux）。

**操作位置**：在 VM 上执行所有命令。

```bash
# ① 准备 sops 密钥目录（nixos-anywhere 会把这个目录复制到目标机的 /mnt）
mkdir -p /tmp/extra/persist/var/lib/sops-nix
cp /persist/var/lib/sops-nix/key.txt /tmp/extra/persist/var/lib/sops-nix/key.txt

# ② 进入 dotfiles 仓库
cd ~/github.com/bioinformatist/dotfiles

# ③ 一条命令完成全部安装
#    - 自动 SSH 到物理机
#    - 执行 disko 分区（⚠️ 擦除 /dev/sda 全部数据）
#    - 在目标机上生成真实的 hardware-configuration.nix
#    - 执行 nixos-install
#    - 将 sops 密钥复制到持久化目录
nix run github:nix-community/nixos-anywhere -- \
  --flake .#workstation \
  --extra-files /tmp/extra \
  --generate-hardware-config nixos-generate-config \
    ./hosts/workstation/hardware-configuration.nix \
  root@<物理机IP>
```

完成后物理机会自动重启，跳到 [首次启动后](#首次启动后) 章节。

---

### 路线 B：USB 启动盘手动安装

**适用场景**：物理机无法被 SSH 访问，或你更倾向于在物理机上本地操作。

#### B.1 制作 USB 启动盘

1. 下载 NixOS 最小化 ISO（选一个可用的地址）：
   - 官方：`https://channels.nixos.org/nixos-25.11/latest-nixos-minimal-x86_64-linux.iso`
   - USTC 镜像：`https://mirrors.ustc.edu.cn/nixos-channels/nixos-25.11/latest-nixos-minimal-x86_64-linux.iso`
2. 使用 [Rufus](https://rufus.ie)（Windows）写入 U 盘，选择 **GPT + UEFI**。
3. 物理机 BIOS 设置为从 U 盘启动，开机进入 NixOS Live 环境。

#### B.2 配置 Nix 镜像（中国大陆必需）

Live 环境默认从官方源下载，在大陆极慢。**先配置 USTC 镜像再做任何事**：

```bash
# 为当前用户和 root 都配置（后续命令会用 sudo nix）
for dir in ~/.config/nix /root/.config/nix; do
  sudo mkdir -p "$dir"
  sudo tee "$dir/nix.conf" > /dev/null << 'EOF'
substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
extra-experimental-features = nix-command flakes
EOF
done
```

#### B.3 克隆仓库

```bash
nix-shell -p git
git clone -b feat/ephemeral-root --depth 1 https://github.com/bioinformatist/dotfiles /tmp/dotfiles
cd /tmp/dotfiles
```

#### B.4 分区

使用 disko 按照 `disko-config.nix` 自动分区并挂载。

> ⚠️ **此操作会擦除 `/dev/sda` 上的所有数据！** 确认磁盘设备正确。

```bash
sudo nix run github:nix-community/disko -- \
  --mode disko ./hosts/workstation/disko-config.nix

# 如果报错 experimental feature 'nix-command' is disabled，手动加参数：
# sudo nix --extra-experimental-features 'nix-command flakes' \
#   run github:nix-community/disko -- --mode disko ./hosts/workstation/disko-config.nix
```

执行完毕后，`/mnt` 下的挂载布局为：
- `/mnt` — tmpfs（临时根）
- `/mnt/boot` — ESP 分区（vfat）
- `/mnt/nix` — btrfs 子卷
- `/mnt/persist` — btrfs 子卷（持久化数据）

#### B.5 生成硬件配置

在分区挂载后，生成此物理机的真实硬件配置并替换占位文件：

```bash
sudo nixos-generate-config --root /mnt --no-filesystems --show-hardware-config \
  > ./hosts/workstation/hardware-configuration.nix
```

> `--no-filesystems`：跳过文件系统/挂载点检测。这些由 disko 声明式管理，如果让 `nixos-generate-config` 也生成一份会产生冲突。

#### B.6 部署 sops 密钥

安装过程中 sops-nix 需要读取密钥来解密用户密码等。密钥需要放在两个位置。

先在 **VM** 上查看密钥内容（一行文本，以 `AGE-SECRET-KEY-` 开头）：
```bash
sudo cat /persist/var/lib/sops-nix/key.txt
```

然后在**物理机**上写入（把上面 cat 出来的内容粘贴进去）：
```bash
# ① 持久化位置（重启后保留）
sudo mkdir -p /mnt/persist/var/lib/sops-nix
sudo tee /mnt/persist/var/lib/sops-nix/key.txt << 'EOF'
AGE-SECRET-KEY-xxxxx（替换为你的实际密钥）
EOF
sudo chmod 600 /mnt/persist/var/lib/sops-nix/key.txt

# ② 临时根位置（安装器在 /mnt 下寻找密钥）
sudo mkdir -p /mnt/var/lib/sops-nix
sudo cp /mnt/persist/var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/key.txt
```

> 为什么需要复制两份？因为根目录是 tmpfs，重启后消失。持久化目录在重启后会被 impermanence 绑定挂载到 `/var/lib/sops-nix`。但**安装阶段** impermanence 还没生效，所以安装器需要在 `/mnt/var/lib/sops-nix/` 直接找到密钥。

#### B.7 安装

如果局域网中有代理（如 Clash），先设置代理环境变量。USTC 镜像只加速 nixpkgs 的 NAR 包，但 flake inputs（Hyprland 源码等）仍从 GitHub 直接下载，在大陆极慢：

```bash
# 可选：设置局域网代理（替换为你的代理地址）
export http_proxy=http://192.168.x.x:7890
export https_proxy=http://192.168.x.x:7890

# 安装（sudo -E 保留代理环境变量）
sudo -E nixos-install --flake .#workstation --no-root-passwd \
  --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store"
```

- `sudo -E`：将 `http_proxy`/`https_proxy` 传递给 root 进程。
- `--no-root-passwd`：跳过设置 root 密码的交互提示（用户密码由 sops 管理）。
- `--option substituters ...`：确保 NAR 包下载走 USTC 镜像。

#### B.8 重启

```bash
sudo reboot
```

拔掉 U 盘，从硬盘启动。

---

### 首次启动后

1. **登录**：使用用户名 `ysun`，密码为你在 `secrets.yaml` 中设置的密码。如果无法登录，参见 [恢复指南 § 排查密钥](./recovery.zh-CN.md) 排查问题。

2. **连接 WiFi**（通过 NetworkManager）：
   ```bash
   nmcli device wifi connect <SSID> password <密码>
   ```

3. **导入 Clash Verge 订阅**：
   ```bash
   cat /run/secrets/clash-subscription-url
   ```
   启动 Clash Verge（`SUPER + SHIFT + P`）→ Profiles → 粘贴链接 → Import → 激活。

4. **将生成的硬件配置提交到仓库**（如果走路线 B，硬件配置只存在于安装时的 `/tmp/dotfiles`，需要手动提交）：
   ```bash
   cd ~/github.com/bioinformatist/dotfiles
   git add hosts/workstation/hardware-configuration.nix
   git commit -m "feat: add real hardware-configuration for workstation"
   git push
   ```
