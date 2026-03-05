# Secret Management Guide (Sops + Age)

This repository uses [sops-nix](https://github.com/Mic92/sops-nix) to manage secrets (like user passwords, API keys) declaratively. We use **Age** for encryption.

## 1. Prerequisites
You need `sops` and `age` installed.
If you are on NixOS or have Nix installed, try running with proxy variables (replace port with your proxy, e.g., 7897):
```bash
# Set proxy for the shell session to fetch packages
export https_proxy=http://127.0.0.1:7890
export http_proxy=http://127.0.0.1:7890
nix-shell -p sops age
```

### Alternative: Install Sops Binary Manually
If Nix fails to build sops (common in China due to Go dependency fetch failures), download the binary directly:
1.  Download `sops` from [GitHub Releases](https://github.com/getsops/sops/releases).
2.  `chmod +x sops-v* && sudo mv sops-v* /usr/local/bin/sops`
3.  Use Python to generate password hash if `mkpasswd` is missing:
    ```bash
    python3 -c 'import crypt; print(crypt.crypt("YOUR_PASSWORD", crypt.mksalt(crypt.METHOD_SHA512)))'
    ```

## 2. Key Generation (One-Time Setup)
Generate a centralized Age key for your user.
```bash
mkdir -p ~/.config/sops/age
# Generate the private key
age-keygen -o ~/.config/sops/age/keys.txt
```
**IMPORTANT**: Backup `~/.config/sops/age/keys.txt` to a password manager! If you lose this file, you lose access to all secrets.

Get your **Public Key**:
```bash
age-keygen -y ~/.config/sops/age/keys.txt
# Output example: age1...
```
This public key must be added to `.sops.yaml` in the repository root.

## 3. Configuration (.sops.yaml)
The `.sops.yaml` file defines which keys can decrypt which files.
```yaml
keys:
  - &my_key age1... (Your Public Key)
creation_rules:
  - path_regex: secrets/.*
    key_groups:
      - age:
          - *my_key
```

## 4. Managing Secrets
To create or edit the secrets file:
```bash
# Verify you have the private key at ~/.config/sops/age/keys.txt
sops secrets/secrets.yaml
```

### Resetting User Password
To change the user login password:
1.  Generate a SHA-512 hash of your new password (using Python 3):
    ```bash
    python3 -c 'import crypt; print(crypt.crypt("YOUR_PASSWORD", crypt.mksalt(crypt.METHOD_SHA512)))'
    # Replace YOUR_PASSWORD with your actual password
    # Copy the output hash (starts with $6$...)
    ```
2.  Edit the secrets file:
    ```bash
    sops secrets/secrets.yaml
    ```
3.  Update the `ysun-password` field:
    ```yaml
    ysun-password: "YOUR_NEW_HASH_HERE"
    ```

## 5. Deployment (New Machine)
When installing on a new machine (or Ephemeral Root setup), the system cannot decrypt secrets until it has the private key.

**During Installation (e.g., Live ISO)**:
You must assume the identity of the target system manually.
```bash
# 1. Create the persistent directory for the key
sudo mkdir -p /mnt/persist/var/lib/sops-nix

# 2. Copy your private key content into it
sudo sh -c 'echo "AGE-SECRET-KEY-..." > /mnt/persist/var/lib/sops-nix/key.txt'
sudo chmod 600 /mnt/persist/var/lib/sops-nix/key.txt

# 3. CRITICAL for Wipe-on-Install:
# Mirror it to the ephemeral root so sops-install-secrets can see it during install
sudo mkdir -p /mnt/var/lib/sops-nix
sudo cp /mnt/persist/var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/key.txt
```

## 6. Adding a New Device SSH Key
To give a new machine (like `vm-test`) access to GitHub using a unique key:

1.  **Generate the Key**:
    ```bash
    # Generate a new ed25519 key (no passphrase, as it's encrypted at rest by sops)
    ssh-keygen -t ed25519 -C "ysun@vm-test" -N ""
    ```

2.  **Add to Secrets**:
    Ensure your master identity key is at `~/.config/sops/age/keys.txt`.
    
    Use a temporary shell with `sops` (no need to install it globally):
    ```bash
    nix shell nixpkgs#sops --command sops secrets/secrets.yaml
    ```
    
    Add the key content under a new key (e.g., `github-ssh-key-vm-test`):
    ```yaml
    github-ssh-key-vm-test: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      ... (content of ~/.ssh/id_ed25519) ...
      -----END OPENSSH PRIVATE KEY-----
    ```
    *Note: Indent the key content correctly.*

3.  **Cleanup**:
    Delete the generated key files (`~/.ssh/id_ed25519` and `.pub`) after verifying they are in sops. The system will auto-provision them to `~/.ssh/` on next rebuild.

## 7. Managing Clash Subscription URL
The Clash proxy subscription URL is stored as an encrypted secret so it can be version-controlled safely.

1.  **Add/Update the URL**:
    ```bash
    sops secrets/secrets.yaml
    ```
    Add or update the `clash-subscription-url` field:
    ```yaml
    clash-subscription-url: "https://your-provider.com/subscribe?token=xxxxx"
    ```

2.  **Runtime Access**:
    After `nixos-rebuild switch`, the decrypted URL is available at:
    ```
    /run/secrets/clash-subscription-url
    ```
    This file is on `tmpfs` and only accessible by the `ysun` user.

3.  **First-Time Import into Clash Verge**:
    See [USER_GUIDE.md § Network Proxy](./USER_GUIDE.md) for step-by-step instructions on importing the subscription into Clash Verge GUI.
