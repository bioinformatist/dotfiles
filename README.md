# dotfiles

My NixOS Settings.

## 📖 Reference
*   👉 **[User Guide: Programs & Keybindings](docs/USER_GUIDE.md)**: What's inside and how to use it.
*   👉 **[Secret Management](docs/SECRET_MANAGEMENT.md)**: SSH keys, Sops-Nix, and Age keys.
*   👉 **[Recovery & Updates](docs/RECOVERY_AND_UPDATE.md)**: Fixing a broken system or incremental updates.

### 🇨🇳 中文文档
*   👉 **[用户指南：程序与快捷键](docs/USER_GUIDE.zh-CN.md)**
*   👉 **[密钥管理](docs/SECRET_MANAGEMENT.zh-CN.md)**
*   👉 **[系统恢复与增量更新](docs/RECOVERY_AND_UPDATE.zh-CN.md)**

## Installation Guide (VM / Fresh Install)

### 1. Pre-requisites
*   **China Network**: Ensure you configure USTC mirrors to speed up downloads.
*   **Sops Keys**: You must have generated Age keys and configured secrets before installing.
    *   👉 **See [docs/SECRET_MANAGEMENT.md](docs/SECRET_MANAGEMENT.md) for details on generating keys and resetting passwords.**
*   **Rescue & Updates**: If you need to fix a broken system without wiping data:
    *   👉 **See [docs/RECOVERY_AND_UPDATE.md](docs/RECOVERY_AND_UPDATE.md) for incremental update instructions.**

### 2. Quick Start (VM Replication)

Boot into the [NixOS Minimal ISO](https://nixos.org/download.html) and run:

#### Step 0: Boost Network (China)
```bash
mkdir -p ~/.config/nix
echo "substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org" >> ~/.config/nix/nix.conf
```

#### Step 1: Clone Repository
```bash
git clone https://github.com/bioinformatist/dotfiles /tmp/dotfiles
cd /tmp/dotfiles
git checkout feat/ephemeral-root
```

#### Step 2: Partition & Format (Disko)
**WARNING: Wipes the disk!**
```bash
sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./hosts/vm-test/disko-config.nix
```

#### Step 3: Deploy Secrets (Sops)
You must manually place the **Private Age Key** so the installer can decrypt the user password.

```bash
# 1. Create persistent directory
sudo mkdir -p /mnt/persist/var/lib/sops-nix

# 2. Write key (Replace CONTENT with your actual key string `age1...`)
sudo sh -c 'echo "AGE-SECRET-KEY-..." > /mnt/persist/var/lib/sops-nix/key.txt'
sudo chmod 600 /mnt/persist/var/lib/sops-nix/key.txt

# 3. Mirror to ephemeral root (Required for initial install activation)
sudo mkdir -p /mnt/var/lib/sops-nix
sudo cp /mnt/persist/var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/key.txt
```

#### Step 4: Install System
```bash
sudo nixos-install --flake .#vm-test --no-root-passwd --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store"
```

#### Step 5: Reboot
```bash
sudo reboot
```

---

## 安装指南（虚拟机 / 全新安装）

### 1. 前置条件
*   **中国大陆网络**：请务必配置 USTC 镜像以加速下载。
*   **Sops 密钥**：安装前必须已生成 Age 密钥并配置好密钥文件。
    *   👉 **详见 [docs/SECRET_MANAGEMENT.zh-CN.md](docs/SECRET_MANAGEMENT.zh-CN.md)**
*   **修复 & 更新**：如需在不擦除数据的情况下修复损坏的系统：
    *   👉 **详见 [docs/RECOVERY_AND_UPDATE.zh-CN.md](docs/RECOVERY_AND_UPDATE.zh-CN.md)**

### 2. 快速开始（虚拟机复制）

从 [NixOS Minimal ISO](https://nixos.org/download.html) 启动后执行：

#### 第 0 步：加速网络（中国大陆）
```bash
mkdir -p ~/.config/nix
echo "substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org" >> ~/.config/nix/nix.conf
```

#### 第 1 步：克隆仓库
```bash
git clone https://github.com/bioinformatist/dotfiles /tmp/dotfiles
cd /tmp/dotfiles
git checkout feat/ephemeral-root
```

#### 第 2 步：分区 & 格式化（Disko）
**警告：会擦除磁盘！**
```bash
sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./hosts/vm-test/disko-config.nix
```

#### 第 3 步：部署密钥（Sops）
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

#### 第 4 步：安装系统
```bash
sudo nixos-install --flake .#vm-test --no-root-passwd --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store"
```

#### 第 5 步：重启
```bash
sudo reboot
```
