# Daily Usage Guide

#### [中文](daily-usage.zh-CN.md) | English

An overview of applications, keybindings, and day-to-day workflows configured in this NixOS system.

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

**User (`ysun`)**: `~/github.com`, `~/.config/sops`, `~/.config/nushell`, `~/.config/google-chrome`, `~/.local/share/io.github.clash-verge-rev.clash-verge-rev`, `~/.local/share/fcitx5`, `~/.gemini`, `~/xwechat_files`, `~/.ssh/known_hosts`. `workstation` additionally persists `~/Downloads`, `~/Documents`, `~/.mozilla`.

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
| **grim** + **slurp** | `pkgs.grim`, `pkgs.slurp` | Wayland screen capture + region selector |
| **satty** | `pkgs.satty` | Screenshot annotation editor (arrows, text, blur, brush) |

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
| `ALT + A` | **Screenshot** region → annotate (satty) → clipboard |
| `Print` | **Screenshot** region → annotate (satty) → clipboard |
| `SUPER + Print` | **Screenshot** full screen → annotate (satty) → clipboard |

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

## 🔄 Daily System Update

This section covers the normal workflow for **updating all packages** on an already-installed, running system. No ISO or reinstallation is needed.

> **Shell Note**: This section runs on the configured system using **Nushell**. The syntax differs from bash.

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

---

## 🌐 Network Proxy & Dynamic Routing

The system follows a **"Localhost Abstraction"** strategy:
- **NixOS (System-wide)**: Configured to *always* trust `http://127.0.0.1:7897` (localhost). You never need to change system config when moving underlying networks.
- **Clash Verge (User GUI)**: Handles the actual upstream connection (e.g., your LAN proxy, airport Wi-Fi, 5G hotspot).

| Item | Detail |
| :--- | :--- |
| **WiFi** | `vm-test`: `wpa_supplicant`; `workstation`: `NetworkManager` |
| **System Proxy** | Always points to `http://127.0.0.1:7897` (localhost abstraction) |
| **Clash Verge** | Handles actual upstream routing (LAN proxy, airport, hotspot, etc.) |
| **Nix Substituters** | USTC mirror (primary), Hyprland cachix, Yazi cachix |

### Setting up an Upstream LAN Proxy

For example, `192.168.0.116:7890`:

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

### Importing a Subscription from Sops (First-Time)

The subscription URL is stored encrypted in the repository via sops-nix (see [Secret Management § Clash Subscription](./secret-management.md)). After `nixos-rebuild switch`, import it into Clash Verge:

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

## 🛠 Tips & Tricks

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
