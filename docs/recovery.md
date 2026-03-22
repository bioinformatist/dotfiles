# System Recovery

#### [中文](recovery.zh-CN.md) | English

This guide explains how to **rescue a broken system** or **apply configuration updates** (like password changes) **without wiping your disk**, by booting from the NixOS installation ISO.

## 1. Boot & Network (China Optimized)
Boot into the NixOS Installation ISO.

**CRITICAL**: Configure the USTC mirror immediately to avoid slow downloads and timeouts.
```bash
mkdir -p ~/.config/nix
echo "substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org" >> ~/.config/nix/nix.conf
```

## 2. Mount Existing Disk (Do NOT Wipe)
Instead of re-partitioning (which wipes data), we use `disko` to simply **mount** your existing partitions.
```bash
# Clone your repo to a temporary location
rm -rf /tmp/dotfiles
git clone https://github.com/bioinformatist/dotfiles /tmp/dotfiles
cd /tmp/dotfiles
git checkout feat/ephemeral-root

# Mount the disks using disko (Mode Mount)
sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode mount ./hosts/vm-test/disko-config.nix
```

## 3. Deploy Secrets to Ephemeral Root
Since we are in the installer environment, we must manually ensure the secret key is available to Sops.
The key should already exist in `/mnt/persist`. We just need to mirror it to the ephemeral root.

```bash
# Create destination directory
sudo mkdir -p /mnt/var/lib/sops-nix

# Copy key from persistent storage
# If this fails, it means you lost your key and need to re-create it (see secret-management.md)
sudo cp /mnt/persist/var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/key.txt
```

## 4. Re-Install (Incremental)
Run the install command. verify that it uses the USTC mirror.
Files already in `/mnt/nix/store` will be reused, making this process very fast.

```bash
# Note replacing 'homePC' with 'vm-test' as per new structure
sudo nixos-install --flake .#vm-test --no-root-passwd --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store"
```

## 5. Reboot
```bash
sudo reboot
```

## 6. Troubleshooting: Verify Secrets (If Login Fails)
If you cannot log in, verify that the key on the disk matches the encrypted secrets.

1.  **Boot ISO & Network**: Follow Step 1 above.
2.  **Mount Persistence Partition**:
    ```bash
    # Identify your persist partition (usually largest btrfs partition)
    lsblk
    sudo mkdir -p /mnt/verify
    # Mount the /persist subvolume. Adjust /dev/sda2 if needed.
    sudo mount -o subvol=persist /dev/sda2 /mnt/verify
    ```
3.  **Check Key Existence**:
    ```bash
    ls -l /mnt/verify/var/lib/sops-nix/key.txt
    ```
4.  **Test Decryption**:
    ```bash
    # Use sops to try decrypting your secrets file using the key on disk
    cd /tmp/dotfiles # Ensure you have cloned the repo as in Step 2

    # Set proxy if needed
    export https_proxy=http://127.0.0.1:7890

    echo "Trying to decrypt..."
    # Must use sudo because key.txt is owned by root (600)
    sudo -E nix-shell --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store" -p sops --run "SOPS_AGE_KEY_FILE=/mnt/verify/var/lib/sops-nix/key.txt sops -d secrets/secrets.yaml"
    ```
    *   **Success**: Prints the decrypted YAML content (yay!).
    *   **Failure**: `MacError` or `Failed to decrypt`. This means the key in `/mnt/verify/...` is NOT the one that encrypted `secrets.yaml`.

### Fixing Key Mismatch
If decryption failed, you must align the keys:

1.  **On Local Machine (Where you have sops/age)**:
    *   Get your **Current** Public Key:
        ```bash
        nix-shell -p age --run "age-keygen -y ~/.config/sops/age/keys.txt"
        # Output example: age1...
        ```
    *   Edit `.sops.yaml` and update the key to match this output.
    *   **Re-encrypt** the secrets file with the new key:
        ```bash
        # Set proxy if in China
        export https_proxy=http://127.0.0.1:7890
        nix-shell -p sops --run "sops updatekeys secrets/secrets.yaml"
        ```
    *   Commit and Push: `git add . && git commit -m "fix: rotate sops key" && git push`

2.  **In VM (ISO)**:
    *   **Pull latest code**: `cd /tmp/dotfiles && git pull`
    *   **Overwrite the key** on disk with your **Local Private Key** (content of `~/.config/sops/age/keys.txt`):
        ```bash
        # Create directory first
        sudo mkdir -p /mnt/verify/var/lib/sops-nix

        # Overwrite persistent key
        sudo sh -c 'echo "YOUR-LOCAL-PRIVATE-KEY-CONTENT" > /mnt/verify/var/lib/sops-nix/key.txt'
        # Mirror to ephemeral location
        sudo mkdir -p /mnt/var/lib/sops-nix
        sudo cp /mnt/verify/var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/key.txt
        ```
    *   **Re-install**:
        ```bash
        sudo nixos-install --flake .#vm-test --no-root-passwd --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store"
        ```
