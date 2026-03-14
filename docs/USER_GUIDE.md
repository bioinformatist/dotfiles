# User Guide: Tailored NixOS Environment

This guide provides an overview of the applications and keybindings configured in this NixOS system.

## 🖥️ Host Configuration

This repository supports multiple host configurations, sharing common settings via modules (`nixos/common.nix`, `nixos/desktop.nix`):

| Property | `vm-test` | `workstation` |
| :--- | :--- | :--- |
| **Hostname** | `homePC` | `homePC` |
| **Architecture** | `x86_64-linux` | `x86_64-linux` |
| **User** | `ysun` | `ysun` |
| **Boot** | GRUB (EFI, removable) | systemd-boot |
| **Root FS** | Ephemeral (`tmpfs`), persistent at `/persist` | Same |
| **Networking** | `wpa_supplicant` (hardcoded SSIDs) | `NetworkManager` |
| **GPU** | Software rendering (`vm-tweaks.nix`) | Hardware accelerated |
| **Timezone** | `Asia/Shanghai` | `Asia/Shanghai` |

### NixOS Infrastructure Modules

| Module | Purpose |
| :--- | :--- |
| [disko](https://github.com/nix-community/disko) | Declarative disk partitioning (GPT, btrfs subvolumes for `/nix` and `/persist`) |
| [impermanence](https://github.com/nix-community/impermanence) | Ephemeral root — only whitelisted paths survive reboot |
| [sops-nix](https://github.com/Mic92/sops-nix) | Declarative secret management with Age encryption (same key shared across machines) |
| [home-manager](https://github.com/nix-community/home-manager) | User-level configuration (integrated as NixOS module) |
| `vm-tweaks.nix` | `vm-test` only: VMware guest support, forces software rendering |

### Persisted Paths (Impermanence)

**System**: `/var/log`, `/var/lib/bluetooth`, `/var/lib/nixos`, `/var/lib/systemd/coredump`, `/etc/NetworkManager/system-connections`, `/var/lib/sops-nix`, `/var/lib/colord`, `/etc/machine-id`, SSH host keys. `workstation` additionally persists `/var/lib/NetworkManager`.

**User (`ysun`)**: `~/github.com`, `~/.config/sops`, `~/.config/nushell`, `~/.local/share/io.github.clash-verge-rev.clash-verge-rev`. `workstation` additionally persists `~/Downloads`, `~/Documents`, `~/.mozilla`.

Everything else is wiped on reboot.

---

## 🚀 Installed Software

### Desktop & GUI

| Application | Package / Source | Description |
| :--- | :--- | :--- |
| **Hyprland** | `inputs.hyprland` (flake) | Dynamic tiling Wayland compositor, launched via UWSM |
| **Ghostty** | `pkgs.ghostty` | Modern GPU-accelerated terminal emulator (Zig), native GTK on Linux |
| **Google Chrome** | `pkgs.google-chrome` | Web browser |
| **Clash Verge** | `programs.clash-verge` (NixOS module) | GUI proxy client (network flexibility) |
| **Eww** | `pkgs.eww` + Home Manager | Desktop widgets and status bar |
| **Dunst** | Home Manager service | Notification daemon |
| **swww** | `inputs.swww` (flake) | Wayland wallpaper daemon with custom multi-monitor rotation script |
| **Antigravity** | `inputs.antigravity` (flake) | IDE |
| **hyprlock** | `pkgs.hyprlock` | Hyprland-native lock screen |
| **XDG Desktop Portal** | `xdg-desktop-portal-hyprland` | Hyprland-native portal for screen sharing, file dialogs, etc. |
| **WeChat** | `pkgs.wechat-uos` | WeChat desktop client (runs via XWayland) |

### TUI & Shell

| Application | Package / Source | Description |
| :--- | :--- | :--- |
| **[Nushell](https://www.nushell.sh/)** | `pkgs.nushell` (default shell) | Modern shell treating data as structured tables |
| **[Starship](https://starship.rs/)** | Home Manager | Minimal, blazing-fast cross-shell prompt |
| **[Helix](https://helix-editor.com/)** (`hx`) | Home Manager | Post-modern modal text editor (`$EDITOR` / `$VISUAL`) |
| **[Yazi](https://yazi-rs.github.io/)** | `inputs.yazi` (flake) | Blazing fast terminal file manager (Rust) |
| **[Zellij](https://zellij.dev/)** | Home Manager | Terminal multiplexer with panes and tabs |
| **[ripgrep](https://github.com/BurntSushi/ripgrep)** (`rg`) | Home Manager | Recursive regex search tool |

### System Utilities

| Package | Description |
| :--- | :--- |
| `git` | Version control |
| `wl-clipboard` | Wayland clipboard utilities (`wl-copy` / `wl-paste`) |
| `proxychains` | Force any program through SOCKS5/HTTP proxy (`127.0.0.1:7897`) |
| `nix-ld` | Dynamic linker for unpatched binaries |

### Input Method

| Component | Description |
| :--- | :--- |
| **Fcitx5** (system) | Input method framework, Wayland frontend enabled |
| **Fcitx5** (user / Home Manager) | Addons: `fcitx5-rime`, `fcitx5-gtk`, `fcitx5-chinese-addons`, `fcitx5-configtool` |

### Fonts

| Font | Usage |
| :--- | :--- |
| Sarasa Gothic | Default sans-serif (CJK) |
| Noto Sans/Serif CJK SC | Fallback CJK fonts |
| JetBrains Mono | Default monospace |

### Services & Security

| Item | Detail |
| :--- | :--- |
| **PipeWire** | Audio server (ALSA + PulseAudio compat, 32-bit support) |
| **OpenSSH** | SSH daemon enabled |
| **ssh-agent** | User-level SSH agent (Home Manager service) |
| **rtkit** | Realtime scheduling for PipeWire |
| **sudo** | `ysun` has passwordless `NOPASSWD` sudo |

### Networking & Proxy

| Item | Detail |
| :--- | :--- |
| **WiFi** | `vm-test`: `wpa_supplicant`; `workstation`: `NetworkManager` |
| **System Proxy** | Always points to `http://127.0.0.1:7897` (localhost abstraction) |
| **Clash Verge** | Handles actual upstream routing (LAN proxy, airport, hotspot, etc.) |
| **Nix Substituters** | USTC mirror (primary), Hyprland cachix, Yazi cachix |

---

## ⌨️ Keybindings (Hyprland)

The **SUPER** key (Windows key) is the primary modifier for most shortcuts.

### System Actions
| Command | Action |
| :--- | :--- |
| `SUPER + SHIFT + Q` | **Force Logout** (Kill Hyprland session) |
| `SUPER + C` | **Kill** Active Window |
| `SUPER + V` | Toggle **Floating** |
| `SUPER + F` | Toggle **Fullscreen** |
| `SUPER + Return` | Launch **Terminal** (Ghostty) |
| `SUPER + B` | Launch **Browser** (Chrome) |
| `SUPER + SHIFT + G` | Launch **Antigravity IDE** |
| `SUPER + SHIFT + P` | Launch **Proxy Client** (Clash Verge) |
| `SUPER + W` | Launch **WeChat** |
| `SUPER + L` | **Lock Screen** (hyprlock) |
| `SUPER + R` | Enter **Resize Mode** (arrow keys to resize, `Escape` to exit) |

### Window & Workspace Management
| Command | Action |
| :--- | :--- |
| `SUPER + Arrow Keys` | Move focus between windows |
| `SUPER + SHIFT + Arrow Keys` | Move/swap window position |
| `SUPER + [1-0]` | Switch to **Workspace** 1-10 |
| `SUPER + SHIFT + [1-0]` | Move active window to **Workspace** 1-10 |
| `SUPER + S` | Toggle **Special Workspace** (Scratchpad) |
| `SUPER + SHIFT + S` | Move window to **Special Workspace** |
| `SUPER + G` | Toggle Group (Tabs) |
| `SUPER + A` | Change active window within Group |
| `SUPER + P` | Pseudo-tile (Dwindle layout) |
| `SUPER + J` | Toggle split direction (Dwindle layout) |
| `SUPER + Mouse LMB` | Drag to move window |
| `SUPER + Mouse RMB` | Drag to resize window |

### Multimedia Keys
- **Volume**: `XF86AudioRaiseVolume` / `LowerVolume` / `Mute`
- **Brightness**: `XF86MonBrightnessUp` / `Down`
- **Playback**: `XF86AudioPlay` / `Next` / `Prev` (Requires `playerctl`)

---

## 🛠 Workflows

### Secret Management
We use **Sops-Nix** with **Age** keys. Machine-specific SSH keys are managed declaratively but must be bootstrapped once on new physical machines.
- See: [docs/SECRET_MANAGEMENT.md](./SECRET_MANAGEMENT.md)

### Data Persistence
This system uses an **ephemeral root** approach. Only specific directories are persisted between reboots.
- **Persisted User Paths**: `~/github.com`, `~/.config/sops`.
- Everything else in the Home directory is wiped on reboot to ensure a clean state.

### Software Rendering (VM Only)
In VM environments where GPU acceleration is unstable, software rendering is forced globally via `LIBGL_ALWAYS_SOFTWARE=1`. The physical machine (`workstation`) does not include this setting.

### Sops Bootstrapping (First Time)
If you are on a new machine and `sops` fails to find your keys, run this in Nushell:
```nu
$env.SOPS_AGE_KEY_FILE = ("~/.config/sops/age/keys.txt" | path expand)
```
This is already configured in `config.nu`, but may be needed if you haven't rebooted or re-applied the configuration.

### Network Proxy & Dynamic Routing
The system follows a **"Localhost Abstraction"** strategy:
- **NixOS (System-wide)**: Configured to *always* trust `http://127.0.0.1:7897` (localhost). You never need to change system config when moving underlying networks.
- **Clash Verge (User GUI)**: Handles the actual upstream connection (e.g., your LAN proxy, airport Wi-Fi, 5G hotspot).

**How to set up an upstream LAN proxy (e.g. `192.168.0.116:7890`):**
1.  Launch **Clash Verge** (`SUPER + SHIFT + P`).
2.  Go to **Profiles** -> **New Local Profile**.
3.  Right-click the new profile -> **Edit File**.
4.  Add your LAN proxy as a "Proxy" node:
    ```yaml
    proxies:
      - name: "My LAN Proxy"
        type: http # or socks5
        server: 192.168.0.116
        port: 7890
    
    proxy-groups:
      - name: Proxy
        type: select
        proxies:
          - "My LAN Proxy"
    ```
5.  Select this profile to activate it. The system will automatically route traffic through it via the localhost interface.

**How to import a subscription from sops (first-time setup on a new machine):**

The subscription URL is stored encrypted in the repository via sops-nix (see [SECRET_MANAGEMENT.md § 7](./SECRET_MANAGEMENT.md)). After `nixos-rebuild switch`, import it into Clash Verge:

1.  Read the decrypted URL:
    ```bash
    cat /run/secrets/clash-subscription-url
    ```
2.  Launch **Clash Verge** (`SUPER + SHIFT + P`).
3.  Go to the **Profiles** page.
4.  Paste the URL into the input box at the top and click **Import**.
5.  Click the imported profile to **activate** it.

> This only needs to be done once per machine. The profile data is persisted at `~/.local/share/io.github.clash-verge-rev.clash-verge-rev/` and survives reboots. Clash Verge will also auto-update the subscription periodically.

---

## 💻 Physical Machine First-Time Deployment

Install the `workstation` configuration on a new physical machine. This section provides two paths — choose the one that fits your situation.

### Prerequisites (Both Paths)

Before starting, prepare the **Age private key** (`key.txt`). Both machines share the same key.

> Your Age private key is stored in the VM at `/persist/var/lib/sops-nix/key.txt`.
> Copy it to a USB drive, transfer via SSH, or any method you prefer.
> If you don't have a key at all, see [Secret Management § 2](./SECRET_MANAGEMENT.md) to generate one.

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
mkdir -p ~/.config/nix
cat > ~/.config/nix/nix.conf << 'EOF'
substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
extra-experimental-features = nix-command flakes
EOF
```

#### B.3 Clone the Repository

```bash
nix-shell -p git
git clone -b feat/ephemeral-root https://github.com/bioinformatist/dotfiles /tmp/dotfiles
cd /tmp/dotfiles
```

#### B.4 Partition

Run disko to partition and mount according to `disko-config.nix`.

> ⚠️ **This erases ALL data on `/dev/sda`!** Verify the disk device is correct.

```bash
sudo nix run github:nix-community/disko -- \
  --mode disko ./hosts/workstation/disko-config.nix
```

After completion, `/mnt` layout:
- `/mnt` — tmpfs (ephemeral root)
- `/mnt/boot` — ESP partition (vfat)
- `/mnt/nix` — btrfs subvolume
- `/mnt/persist` — btrfs subvolume (persistent data)

#### B.5 Generate Hardware Configuration

With partitions mounted, generate the real hardware config to replace the placeholder:

```bash
nixos-generate-config --root /mnt --show-hardware-config \
  > ./hosts/workstation/hardware-configuration.nix
```

#### B.6 Deploy sops Key

During installation, sops-nix needs the key to decrypt passwords. Place it in **two** locations:

```bash
# ① Persistent location (survives reboot)
sudo mkdir -p /mnt/persist/var/lib/sops-nix
sudo cp <path/to/your/key.txt> /mnt/persist/var/lib/sops-nix/key.txt
sudo chmod 600 /mnt/persist/var/lib/sops-nix/key.txt

# ② Temporary root location (installer looks here under /mnt)
sudo mkdir -p /mnt/var/lib/sops-nix
sudo cp /mnt/persist/var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/key.txt
```

> Why two copies? The root is tmpfs and vanishes on reboot. After boot, impermanence bind-mounts the persistent path to `/var/lib/sops-nix`. But **during installation**, impermanence isn't active yet, so the installer needs the key directly at `/mnt/var/lib/sops-nix/`.

#### B.7 Install

```bash
sudo nixos-install --flake .#workstation --no-root-passwd \
  --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store"
```

- `--no-root-passwd`: Skip the interactive root password prompt (user password is managed by sops).
- `--option substituters ...`: Ensure downloads go through the USTC mirror.

#### B.8 Reboot

```bash
sudo reboot
```

Remove the USB drive and boot from the hard disk.

---

### After First Boot

1. **Login**: Use username `ysun` with the password set in `secrets.yaml`. If login fails, see [Recovery Guide § 6](./RECOVERY_AND_UPDATE.md) to troubleshoot.

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

