# User Guide: Tailored NixOS Environment

This guide provides an overview of the applications and keybindings configured in this NixOS system.

## 🖥️ Host Configuration

Currently only one host is defined:

| Property | Value |
| :--- | :--- |
| **Host Name** | `vm-test` (hostname: `homePC`) |
| **Architecture** | `x86_64-linux` |
| **User** | `ysun` |
| **Boot** | GRUB (EFI, removable) |
| **Root FS** | Ephemeral (`tmpfs`), persistent data at `/persist` (btrfs) |
| **Timezone** | `Asia/Shanghai` |
| **State Version** | `24.11` |

### NixOS Infrastructure Modules

| Module | Purpose |
| :--- | :--- |
| [disko](https://github.com/nix-community/disko) | Declarative disk partitioning (GPT, btrfs subvolumes for `/nix` and `/persist`) |
| [impermanence](https://github.com/nix-community/impermanence) | Ephemeral root — only whitelisted paths survive reboot |
| [sops-nix](https://github.com/Mic92/sops-nix) | Declarative secret management with Age encryption |
| [home-manager](https://github.com/nix-community/home-manager) | User-level configuration (integrated as NixOS module) |
| `vm-tweaks.nix` | VMware guest support, forces software rendering (`LIBGL_ALWAYS_SOFTWARE=1`) |

### Persisted Paths (Impermanence)

**System**: `/var/log`, `/var/lib/bluetooth`, `/var/lib/nixos`, `/var/lib/systemd/coredump`, `/etc/NetworkManager/system-connections`, `/var/lib/sops-nix`, `/var/lib/colord`, `/etc/machine-id`, SSH host keys.

**User (`ysun`)**: `~/github.com`, `~/.config/sops`, `~/.local/share/io.github.clash-verge-rev.clash-verge-rev` (proxy subscriptions).

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
| **WiFi** | `wpa_supplicant` with 2 pre-configured SSIDs |
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

### Software Rendering (VM Tweak)
In VM environments where GPU acceleration is unstable, software rendering is forced globally via `LIBGL_ALWAYS_SOFTWARE=1` to ensure applications like Ghostty launch reliably.

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
