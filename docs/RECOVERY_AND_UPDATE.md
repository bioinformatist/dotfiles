# System Recovery, Updates & Maintenance

This guide explains how to **update all system packages**, **rescue a broken system**, or **apply configuration updates** (like password changes) **without wiping your disk**.

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
# If this fails, it means you lost your key and need to re-create it (see SECRET_MANAGEMENT.md)
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

## 7. Daily System Update (On a Running System)

This section covers the normal workflow for **updating all packages** on an already-installed, running system. No ISO or reinstallation is needed.

> **Shell Note**: Sections 1–6 run in the ISO installer environment using **bash**.
> This section runs on the configured system using **Nushell**. The syntax differs.

### China Network Note

The update process involves **two types** of network requests, each requiring a different acceleration method:

| Request Type | Purpose | Acceleration |
|---|---|---|
| **GitHub source fetching** | `nix flake update` pulls flake inputs (HTTPS tarballs) | Requires a **proxy**; USTC mirror cannot help |
| **Binary cache download** | `nixos-rebuild` downloads pre-built packages from cache | Use **USTC mirror** (`--option substituters`) |

> **Why does the proxy work?** Nix uses **libcurl** under the hood for HTTP requests. libcurl natively
> supports `http_proxy`/`https_proxy` environment variables. `nix flake update` downloads tarballs via
> HTTPS for `github:` inputs (not `git clone`), so it automatically picks up the proxy.

Therefore, a full update requires **both** a proxy and the USTC mirror.

**Set proxy** (Nushell syntax, LAN or localhost proxy):
```nu
# Replace with your actual proxy address
# Localhost example: http://127.0.0.1:7890
# LAN proxy example: http://192.168.1.100:7890
$env.http_proxy = "http://<proxy-address>:<port>"
$env.https_proxy = "http://<proxy-address>:<port>"
```

### Step 1: Update Flake Inputs (`flake.lock`)

This fetches the latest versions of all dependencies from GitHub (nixpkgs, home-manager, hyprland, etc.).

```nu
cd /path/to/dotfiles   # e.g., ~/github.com/bioinformatist/dotfiles

# Ensure proxy is set (see above)
nix flake update
```

This modifies `flake.lock` — you should commit it afterward.

### Step 2: Rebuild & Switch

Apply the updated packages to the running system.

> **Important**: `sudo` **strips** environment variables (including `http_proxy`/`https_proxy`) by default.
> You must use `sudo -E` (`--preserve-env`) to keep your proxy settings, otherwise packages that need to fetch source from GitHub during build will fail.
> Variables set via Nushell's `$env` are passed to child processes, so `sudo -E` inherits them correctly.

```nu
# Replace <host> with your host name: vm-test, workstation, etc.
# -E preserves proxy env vars; --option substituters uses USTC binary cache mirror
sudo -E nixos-rebuild switch --flake $".#<host>" --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org"
```

If you don't need a proxy (network is fine), you can omit `-E` and the proxy setup:
```nu
sudo nixos-rebuild switch --flake $".#<host>"
```

### Step 3: Commit the Lock File

```nu
git add flake.lock
git commit -m "chore: update flake inputs"
git push
```

### (Optional) Preview Changes Before Switching

If you want to **build without activating** (to check for build errors first):

```nu
sudo -E nixos-rebuild build --flake $".#<host>" --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org"
```

Or use `test` to activate temporarily (reverts on next reboot):

```nu
sudo -E nixos-rebuild test --flake $".#<host>" --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org"
```
