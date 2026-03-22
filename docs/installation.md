# Installation Guide

#### [中文](installation.zh-CN.md) | English

This guide covers deploying NixOS from scratch — either in a VM or on a physical machine.

## Prerequisites

*   **China Network**: Configure USTC mirrors to speed up downloads.
*   **Sops Keys**: You must have generated Age keys and configured secrets before installing.
    *   👉 See [secret-management.md](./secret-management.md) for details.
*   **Rescue & Updates**: If you need to fix a broken system without wiping data:
    *   👉 See [recovery.md](./recovery.md) for incremental update instructions.

---

## VM Installation (Quick Start)

Boot into the [NixOS Minimal ISO](https://nixos.org/download.html) and run:

### Step 0: Boost Network (China)
```bash
mkdir -p ~/.config/nix
echo "substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org" >> ~/.config/nix/nix.conf
```

### Step 1: Clone Repository
```bash
git clone https://github.com/bioinformatist/dotfiles /tmp/dotfiles
cd /tmp/dotfiles
git checkout feat/ephemeral-root
```

### Step 2: Partition & Format (Disko)
**WARNING: Wipes the disk!**
```bash
sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ./hosts/vm-test/disko-config.nix
```

### Step 3: Deploy Secrets (Sops)
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

### Step 4: Install System
```bash
sudo nixos-install --flake .#vm-test --no-root-passwd --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store"
```

### Step 5: Reboot
```bash
sudo reboot
```

---

## Physical Machine Deployment

Install the `workstation` configuration on a new physical machine. Choose the path that fits your situation.

### Prerequisites (Both Paths)

Prepare the **Age private key** (`key.txt`). Both machines share the same key.

> Your Age private key is stored in the VM at `/persist/var/lib/sops-nix/key.txt`.
> Copy it to a USB drive, transfer via SSH, or any method you prefer.
> If you don't have a key at all, see [Secret Management § 2](./secret-management.md) to generate one.

---

### Path A: Remote Install from Another Machine (nixos-anywhere)

**When to use**: You have a machine with Nix and good network (e.g., the VM), and can SSH as root to the physical machine (running NixOS Live CD or any Linux).

**Where to run**: All commands on the VM.

```bash
# ① Prepare sops key directory (nixos-anywhere copies this to /mnt on the target)
mkdir -p /tmp/extra/persist/var/lib/sops-nix
cp /persist/var/lib/sops-nix/key.txt /tmp/extra/persist/var/lib/sops-nix/key.txt

# ② Enter the dotfiles repo
cd ~/github.com/bioinformatist/dotfiles

# ③ Single command does everything:
#    - SSH into the physical machine
#    - Run disko partitioning (⚠️ erases /dev/sda)
#    - Generate real hardware-configuration.nix on the target
#    - Run nixos-install
#    - Copy sops key to persistent storage
nix run github:nix-community/nixos-anywhere -- \
  --flake .#workstation \
  --extra-files /tmp/extra \
  --generate-hardware-config nixos-generate-config \
    ./hosts/workstation/hardware-configuration.nix \
  root@<PHYSICAL_MACHINE_IP>
```

After completion the machine reboots automatically. Jump to [After First Boot](#after-first-boot).

---

### Path B: USB Boot Manual Install

**When to use**: The physical machine is not SSH-accessible, or you prefer to work locally on it.

#### B.1 Create USB Boot Drive

1. Download the NixOS minimal ISO:
   - Official: `https://channels.nixos.org/nixos-25.11/latest-nixos-minimal-x86_64-linux.iso`
   - USTC mirror (China): `https://mirrors.ustc.edu.cn/nixos-channels/nixos-25.11/latest-nixos-minimal-x86_64-linux.iso`
2. Write to USB with [Rufus](https://rufus.ie) (Windows): select **GPT + UEFI**.
3. Boot the physical machine from the USB drive.

#### B.2 Configure Nix Mirrors (Mainland China)

The live environment defaults to official substituters, which are very slow in China. **Do this before anything else**:

```bash
# Configure for both current user and root (subsequent commands use sudo nix)
for dir in ~/.config/nix /root/.config/nix; do
  sudo mkdir -p "$dir"
  sudo tee "$dir/nix.conf" > /dev/null << 'EOF'
substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
extra-experimental-features = nix-command flakes
EOF
done
```

#### B.3 Clone the Repository

```bash
nix-shell -p git
git clone -b feat/ephemeral-root --depth 1 https://github.com/bioinformatist/dotfiles /tmp/dotfiles
cd /tmp/dotfiles
```

#### B.4 Partition

Run disko to partition and mount according to `disko-config.nix`.

> ⚠️ **This erases ALL data on `/dev/sda`!** Verify the disk device is correct.

```bash
sudo nix run github:nix-community/disko -- \
  --mode disko ./hosts/workstation/disko-config.nix

# If you get 'experimental feature nix-command is disabled', add the flag manually:
# sudo nix --extra-experimental-features 'nix-command flakes' \
#   run github:nix-community/disko -- --mode disko ./hosts/workstation/disko-config.nix
```

After completion, `/mnt` layout:
- `/mnt` — tmpfs (ephemeral root)
- `/mnt/boot` — ESP partition (vfat)
- `/mnt/nix` — btrfs subvolume
- `/mnt/persist` — btrfs subvolume (persistent data)

#### B.5 Generate Hardware Configuration

With partitions mounted, generate the real hardware config to replace the placeholder:

```bash
sudo nixos-generate-config --root /mnt --no-filesystems --show-hardware-config \
  > ./hosts/workstation/hardware-configuration.nix
```

> `--no-filesystems`: Skip filesystem/mount detection. These are managed declaratively by disko — letting `nixos-generate-config` also generate them would cause conflicts.

#### B.6 Deploy sops Key

During installation, sops-nix needs the key to decrypt passwords. The key must be placed in **two** locations.

First, on the **VM**, view the key content (a single line starting with `AGE-SECRET-KEY-`):
```bash
sudo cat /persist/var/lib/sops-nix/key.txt
```

Then on the **physical machine**, write it in (paste the content from the cat above):
```bash
# ① Persistent location (survives reboot)
sudo mkdir -p /mnt/persist/var/lib/sops-nix
sudo tee /mnt/persist/var/lib/sops-nix/key.txt << 'EOF'
AGE-SECRET-KEY-xxxxx (replace with your actual key)
EOF
sudo chmod 600 /mnt/persist/var/lib/sops-nix/key.txt

# ② Temporary root location (installer looks here under /mnt)
sudo mkdir -p /mnt/var/lib/sops-nix
sudo cp /mnt/persist/var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/key.txt
```

> Why two copies? The root is tmpfs and vanishes on reboot. After boot, impermanence bind-mounts the persistent path to `/var/lib/sops-nix`. But **during installation**, impermanence isn't active yet, so the installer needs the key directly at `/mnt/var/lib/sops-nix/`.

#### B.7 Install

If a LAN proxy is available (e.g., Clash), set the proxy environment variables first. The USTC mirror only accelerates nixpkgs NAR packages, but flake inputs (Hyprland source, etc.) are downloaded directly from GitHub, which is very slow in China:

```bash
# Optional: set LAN proxy (replace with your proxy address)
export http_proxy=http://192.168.x.x:7890
export https_proxy=http://192.168.x.x:7890

# Install (sudo -E preserves proxy env vars)
sudo -E nixos-install --flake .#workstation --no-root-passwd \
  --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store"
```

- `sudo -E`: Pass `http_proxy`/`https_proxy` to the root process.
- `--no-root-passwd`: Skip the interactive root password prompt (user password is managed by sops).
- `--option substituters ...`: Ensure NAR package downloads go through the USTC mirror.

#### B.8 Reboot

```bash
sudo reboot
```

Remove the USB drive and boot from the hard disk.

---

### After First Boot

1. **Login**: Use username `ysun` with the password set in `secrets.yaml`. If login fails, see [Recovery § Troubleshooting](./recovery.md) to troubleshoot.

2. **Connect WiFi** (via NetworkManager):
   ```bash
   nmcli device wifi connect <SSID> password <password>
   ```

3. **Import Clash Verge Subscription**:
   ```bash
   cat /run/secrets/clash-subscription-url
   ```
   Launch Clash Verge (`SUPER + SHIFT + P`) → Profiles → Paste URL → Import → Activate.

4. **Commit the generated hardware config** (Path B only — the hardware config only exists in `/tmp/dotfiles` during install):
   ```bash
   cd ~/github.com/bioinformatist/dotfiles
   git add hosts/workstation/hardware-configuration.nix
   git commit -m "feat: add real hardware-configuration for workstation"
   git push
   ```
