# dotfiles

My NixOS Settings.

## Installation Guide (VM / Fresh Install)

### 1. Pre-requisites
*   **China Network**: Ensure you configure USTC mirrors to speed up downloads.
*   **Sops Keys**: You must have generated Age keys and configured secrets before installing.
    *   👉 **See [docs/SECRET_MANAGEMENT.md](docs/SECRET_MANAGEMENT.md) for details on generating keys and resetting passwords.**
*   **Rescue & Updates**: If you need to fix a broken system without wiping data:
    *   👉 **See [docs/RECOVERY_AND_UPDATE.md](docs/RECOVERY_AND_UPDATE.md) for incremental update instructions.**

### 2. Manual Installation

Boot into the [NixOS Minimal ISO](https://nixos.org/download.html) and follow these steps.

#### Step 0: Boost Network (China)
```bash
mkdir -p ~/.config/nix
echo "substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org" >> ~/.config/nix/nix.conf
```

#### Step 1: Clone Repository
```bash
# Clone repo directly (git is included in minimal ISO)
git clone https://github.com/bioinformatist/dotfiles /tmp/dotfiles
cd /tmp/dotfiles
git checkout feat/ephemeral-root
```

#### Step 2: Partition & Format
Using `disko` to partition the disk (wipe-on-install setup):
```bash
sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./hosts/vm-test/disko-config.nix
```

#### 3. Deploy Age Key (CRITICAL STEP - Sops)
# We must manually place the private key so the system can decrypt secrets on first boot.
# NOTE: In the installer, the target disk is mounted at /mnt
sudo mkdir -p /mnt/persist/var/lib/sops-nix

# PROMPT: Paste your private key content (AGE-SECRET-KEY-...) below
# Warning: Be careful with spaces when pasting.
sudo sh -c 'echo "AGE-SECRET-KEY-YOUR-KEY-HERE" > /mnt/persist/var/lib/sops-nix/key.txt'

# Set permission to 600 (owner read/write only)
# Sops-nix expects the key here.
sudo chmod 600 /mnt/persist/var/lib/sops-nix/key.txt

# SYSTEM INSTALLATION TRICK:
# During install, 'impermanence' bind mounts don't exist yet. 
# But sops needs the key at /var/lib/sops-nix/key.txt to set user passwords.
# So we MUST mirror it to the ephemeral install root.
sudo mkdir -p /mnt/var/lib/sops-nix
sudo cp /mnt/persist/var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/key.txt

#### Step 4: Install
Using USTC mirror to save proxy traffic:
```bash
sudo nixos-install --flake .#homePC --no-root-passwd --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store"
```

#### Step 5: Verify
Reboot and login with your user `ysun`.
```bash
reboot
```
