# User Guide: Tailored NixOS Environment

This guide provides an overview of the applications and keybindings configured in this NixOS system.

---

## 🚀 Core Applications

### Desktop & GUI
- **Compositor**: [Hyprland](https://hyprland.org/) - A dynamic tiling Wayland compositor that is smooth and highly customizable.
- **Terminal**: [Kitty](https://sw.kovidgoyal.net/kitty/) - A fast, feature-rich, GPU-based terminal emulator.
- **Browser**: Google Chrome - Stabilized and ready for common web tasks.
- **Proxy Client**: Clash Verge - Managed proxy connections for network flexibility.
- **Input Method**: Fcitx5 - Configured for multilingual support.
- **Widgets & Bar**: [Eww](https://elkowar.github.io/eww/) - Powering the bar and system widgets.
- **Wallpaper**: `swww` with a custom randomization script (`swww_randomize_multi`) that rotates backgrounds across multiple monitors.

### TUI & Shell
- **Shell**: [Nushell](https://www.nushell.sh/) - A modern shell that treats data as structured tables.
- **Editor**: [Helix](https://helix-editor.com/) (`hx`) - A post-modern modal text editor (configured as the default for `$EDITOR` and `$VISUAL`).
- **File Manager**: [Yazi](https://yazi-rs.github.io/) - A blazing fast terminal file manager written in Rust.
- **Multiplexer**: [Zellij](https://zellij.dev/) - A terminal workspace with panes and tabs, designed for productivity.

---

## ⌨️ Keybindings (Hyprland)

The **SUPER** key (Windows key) is the primary modifier for most shortcuts.

### System Actions
| Command | Action |
| :--- | :--- |
| `SUPER + Q` | **Logout** (Stop session via uwsm) |
| `SUPER + C` | **Kill** Active Window |
| `SUPER + F` | Toggle **Fullscreen** or Floating |
| `SUPER + K` | Launch **Terminal** (Kitty) |
| `SUPER + B` | Launch **Browser** (Chrome) |
| `SUPER + G` | Launch **Antigravity IDE** |
| `SUPER + SHIFT + P` | Launch **Proxy Client** (Clash Verge) |

### Window & Workspace Management
| Command | Action |
| :--- | :--- |
| `SUPER + Arrow Keys` | Move focus between windows |
| `SUPER + [1-0]` | Switch to **Workspace** 1-10 |
| `SUPER + SHIFT + [1-0]` | Move active window to **Workspace** 1-10 |
| `SUPER + S` | Toggle **Special Workspace** (Scratchpad) |
| `SUPER + SHIFT + S` | Move window to **Special Workspace** |
| `SUPER + G` | Toggle Group (Tabs) |
| `SUPER + A` | Change active window within Group |
| `SUPER + P` | Pseudo-tile (Dwindle layout) |
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
In VM environments where GPU acceleration is unstable, software rendering is forced globally via `LIBGL_ALWAYS_SOFTWARE=1` to ensure applications like Kitty launch reliably.

### Sops Bootstrapping (First Time)
If you are on a new machine and `sops` fails to find your keys, run this in Nushell:
```nu
$env.SOPS_AGE_KEY_FILE = ("~/.config/sops/age/keys.txt" | path expand)
```
This is already configured in `config.nu`, but may be needed if you haven't rebooted or re-applied the configuration.
