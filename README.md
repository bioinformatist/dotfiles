# dotfiles

My NixOS Settings.

## 📖 Reference
*   👉 **[User Guide: Programs & Keybindings](docs/USER_GUIDE.md)**: What's inside and how to use it.
*   👉 **[Secret Management](docs/SECRET_MANAGEMENT.md)**: SSH keys, Sops-Nix, and Age keys.
*   👉 **[Recovery & Updates](docs/RECOVERY_AND_UPDATE.md)**: Fixing a broken system or incremental updates.

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
