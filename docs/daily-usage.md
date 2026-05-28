# Daily Usage Guide

#### [中文](daily-usage.zh-CN.md) | English

An overview of applications, keybindings, and day-to-day workflows configured in this NixOS system.

## 🖥️ Host Configuration

This repository supports multiple host configurations, sharing common settings via reusable base modules:

| Property | `vm-test` | `homePC` |
| :--- | :--- | :--- |
| **Hostname** | `vm-test` | `homePC` |
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

**System**:

| Path | Purpose |
| :--- | :--- |
| `/var/log` | System logs |
| `/var/lib/bluetooth` | Bluetooth device pairings |
| `/var/lib/nixos` | NixOS state (UIDs/GIDs) |
| `/var/lib/systemd/coredump` | Crash dumps |
| `/etc/NetworkManager/system-connections` | Saved Wi-Fi / VPN profiles (`homePC` only) |
| `/var/lib/NetworkManager` | NetworkManager runtime state (`homePC` only) |
| `/var/lib/sops-nix` | Age key for secret decryption |
| `/var/lib/colord` | Color profile calibration data |
| `/etc/machine-id` | Stable machine identity (required by systemd / journald) |
| `/etc/ssh/ssh_host_*` | SSH host keys (prevent known_hosts warnings after reboot) |

**User (`ysun`)**:

| Path | Purpose |
| :--- | :--- |
| `~/github.com` | All source code and dotfiles |
| `~/.config/sops` | Age private key for sops secret decryption |
| `~/.config/nushell` | Nushell user config (env.nu, config.nu) |
| `~/.config/gh` | GitHub CLI auth state |
| `~/.config/google-chrome` | Chrome profile (bookmarks, passwords, extensions) |
| `~/.local/share/io.github.clash-verge-rev.clash-verge-rev` | Clash Verge proxy profiles and settings |
| `~/.local/share/fcitx5` | Rime user dictionary and learned words |
| `~/.local/share/TelegramDesktop` | Telegram login session and chat cache (`homePC` only) |
| `~/.local/share/Steam` | Steam games, Proton prefixes, save data (`homePC` only) |
| `~/.cargo/registry` | Cargo crate cache (speeds up Rust builds) (`homePC` only) |
| `~/.xwechat` | WeChat login and device session state |
| `~/xwechat_files` | WeChat chat history and files |
| `~/Downloads` | Downloads (`homePC` only) |
| `~/Documents` | Documents (`homePC` only) |
| `~/.ssh/known_hosts` | SSH known hosts (persisted as file, not directory — see note in config) |
| `~/.config/hypr/monitors.conf` | Monitor layout written by nwg-displays |
| `~/.zeroclaw/active_workspace.toml` | ZeroClaw workspace marker |
| `~/.zeroclaw/estop-state.json` | ZeroClaw emergency stop state |
| `~/.zeroclaw/memory.sqlite` | ZeroClaw conversation memory database |

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
| **hyprlock** | `pkgs.hyprlock` | Hyprland-native lock screen |
| **XDG Desktop Portal** | `xdg-desktop-portal-hyprland` | Hyprland-native portal for screen sharing, file dialogs, etc. |
| **WeChat** | `nixpkgs-wechat.wechat-uos` | WeChat desktop client (runs via XWayland) |
| **grim** + **slurp** | `pkgs.grim`, `pkgs.slurp` | Wayland screen capture + region selector |
| **satty** | `pkgs.satty` | Screenshot annotation editor (arrows, text, blur, brush) |

### TUI & Shell

| Application | Package / Source | Description |
| :--- | :--- | :--- |
| **[Nushell](https://www.nushell.sh/)** | `pkgs.nushell` (default shell) | Modern shell treating data as structured tables |
| **[Starship](https://starship.rs/)** | Home Manager | Minimal, blazing-fast cross-shell prompt |
| **[Helix](https://helix-editor.com/)** (`hx`) | Home Manager | Post-modern modal text editor (`$EDITOR` / `$VISUAL`) |
| **[Yazi](https://yazi-rs.github.io/)** (`y`) | `pkgs.yazi` | Blazing fast terminal file manager (Rust). Use `y` (not `yazi`) — the shell wrapper changes your cwd on exit |
| **[Zellij](https://zellij.dev/)** | Home Manager | Terminal multiplexer with panes and tabs |
| **[ripgrep](https://github.com/BurntSushi/ripgrep)** (`rg`) | Home Manager | Recursive regex search tool |

### System Utilities

| Package | Description |
| :--- | :--- |
| `git` | Version control |
| `gh` | GitHub CLI |
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
>
> **Maintenance Note**: The preferred day-to-day workflow now lives in the dedicated [Maintenance Guide](maintenance.md). Use this section as background for networking and manual rebuild commands; use `maintenance.md` for the actual maintenance command set.

### China Network Note

The update process involves **two types** of network requests, each requiring a different acceleration method:

| Request Type | Purpose | Acceleration |
|---|---|---|
| **GitHub source fetching** | `nix flake update` pulls flake inputs (HTTPS tarballs) | Requires a **proxy**; USTC mirror cannot help |
| **Binary cache download** | `nixos-rebuild` downloads pre-built packages from cache | Use **USTC mirror** (`--option substituters`) |

> **Why does the proxy work?** Maintenance commands and `nix-daemon` now read proxy settings from
> `~/.config/nix/local-proxy.nuon`. User-side helpers and daemon-side downloads therefore share one
> local source of truth instead of relying on repeated ad-hoc `with-env` wrappers.

Therefore, a full update still relies on **both** a proxy and the USTC mirror, but they are now
configured through `~/.config/nix/local-proxy.nuon`.

**Local proxy config** (`~/.config/nix/local-proxy.nuon`):
```nu
{
  HTTP_PROXY: "http://<proxy-address>:<port>",
  HTTPS_PROXY: "http://<proxy-address>:<port>",
  NO_PROXY: "mirrors.ustc.edu.cn,cache.nixos.org,127.0.0.1,localhost",
  substituters: [
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://cache.nixos.org"
  ]
}
```

### Step 1: Manually Update Flake Inputs (`flake.lock`)

This fetches the latest versions of all dependencies from GitHub (nixpkgs, home-manager, hyprland, etc.).
It is now mainly a **manual full-refresh workflow**, not the preferred day-to-day maintenance path.

```nu
cd /path/to/dotfiles   # e.g., ~/github.com/bioinformatist/dotfiles

# Ensure proxy is set (see above)
# This updates everything at once.
nix flake update
```

This modifies `flake.lock` — you should commit it afterward.

### Step 2: Rebuild & Switch

Apply the updated packages to the running system.

```nu
# Replace <host> with your flake host name: vm-test, homePC, etc.
sudo nixos-rebuild switch --flake $".#<host>"
```

Because `nix-daemon` now reads `~/.config/nix/local-proxy.nuon`, you no longer need the long
`with-env { HTTP_PROXY ... }` wrapper for normal rebuilds.

### Step 3: Commit the Lock File

```nu
git add flake.lock
git commit -m "chore: update flake inputs"
git push
```

### (Optional) Preview Changes Before Switching

If you want to **build without activating** (to check for build errors first):

```nu
sudo nixos-rebuild build --flake $".#<host>"
```

Or use `test` to activate temporarily (reverts on next reboot):

```nu
sudo nixos-rebuild test --flake $".#<host>"
```

---

## 🌐 Network Proxy & Dynamic Routing

The system follows a **"Localhost Abstraction"** strategy:
- **NixOS (System-wide)**: Configured to *always* trust `http://127.0.0.1:7897` (localhost). You never need to change system config when moving underlying networks.
- **Clash Verge (User GUI)**: Handles the actual upstream connection (e.g., your LAN proxy, airport Wi-Fi, 5G hotspot).

| Item | Detail |
| :--- | :--- |
| **WiFi** | `vm-test`: `wpa_supplicant`; `homePC`: `NetworkManager` |
| **System Proxy** | Always points to `http://127.0.0.1:7897` (localhost abstraction) |
| **Clash Verge** | Handles actual upstream routing (LAN proxy, airport, hotspot, etc.) |
| **Nix Substituters** | USTC mirror (primary), Hyprland cachix |

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

## 🎮 Gaming

### Battle.net Installation (Steam + Proton)

Battle.net runs as a **non-Steam game** added to Steam, using the Proton compatibility layer.

1. Download `Battle.net-Setup.exe` - the official site detects Linux UA and hides the download button, use `curl` to bypass:
   ```nushell
   # China mainland (国服)
   curl -L -o Battle.net-Setup-CN.exe "https://downloader.battlenet.com.cn/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=Live"
   # International (备用)
   curl -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" -L -o Battle.net-Setup.exe "https://www.battle.net/download/getInstallerForGame?os=win&locale=enUS&version=LIVE&gameProgram=BATTLENET_APP"
   ```
2. Steam → **Library** → bottom-left **Add a Game** → **Add a Non-Steam Game**, select the installer
3. Right-click the entry → **Properties** → **Compatibility** → check "Force the use of a specific Steam Play compatibility tool" → select **Proton-GE**
4. Launch and complete the Battle.net installation
5. Once installed, **edit the same non-Steam game entry**. Do not keep launching `Battle.net-Setup*.exe`, and do not create a second non-Steam game entry
6. In Nushell, get the installed Battle.net path:
   ```nushell
   d2r-bnet-steam
   ```
7. Copy the output `target` into Steam's **Target** field, and `start_in` into **Start In**. Keep the double quotes in both fields because the path contains spaces and `(x86)`:
   ```text
   Target:
   "/home/ysun/.local/share/Steam/steamapps/compatdata/<ID>/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net.exe"

   Start In:
   "/home/ysun/.local/share/Steam/steamapps/compatdata/<ID>/pfx/drive_c/Program Files (x86)/Battle.net"
   ```
8. In the same Steam entry, set the verified **Launch Options**:
   ```text
   LD_PRELOAD= DISABLE_VK_LAYER_VALVE_steam_overlay_1=1 VK_LOADER_LAYERS_DISABLE='*steam_overlay*' gamemoderun %command%
   ```
   Steam's **Enable the Steam Overlay while in-game** UI toggle is unreliable for this non-Steam Battle.net entry; even when the UI shows it disabled, the runtime can still inject `gameoverlayrenderer.so` and allow `Shift+Tab` to open the overlay. The environment variables hard-disable the Steam overlay, and `gamemoderun` was verified to noticeably reduce D2R CPU usage.
9. Install and launch D2R through Battle.net

`Battle.net-Setup*.exe` is only for the first install. Daily launch must point to `Battle.net.exe` inside the prefix; otherwise Play runs the installer again, which looks like a reinstall or install-then-update cycle. Steam creates a Proton prefix per non-Steam game entry, so creating a new entry can assign a different `compatdata/<ID>`. After installation, prefer editing the original entry.

> Steam creates a separate Proton prefix per non-Steam game at `~/.local/share/Steam/steamapps/compatdata/<numeric-ID>/`.

After D2R starts, minimize the Battle.net main window if possible. Leaving the Chromium/CEF Battle.net UI visible can add CPU/GPU/compositor load on top of D2R.

### D2R Mod Installation

**Step 1 — Find the D2R Proton prefix**

```nushell
glob "~/.local/share/Steam/steamapps/compatdata/*/pfx/drive_c/Program Files (x86)/Diablo II Resurrected"
```

Note the numeric ID in the returned path.

**Step 2 — Drop in mod files**

D2R mods follow a fixed directory layout (using `ProjectDiablo2` as an example):

```
<D2R install dir>/
└── mods/
    └── ProjectDiablo2/        ← dir name = mod name
        └── ProjectDiablo2.mpq  ← .mpq name = mod name
```

```nushell
let d2r = $"($env.HOME)/.local/share/Steam/steamapps/compatdata/<PREFIX_ID>/pfx/drive_c/Program Files (x86)/Diablo II Resurrected"
mkdir $"($d2r)/mods/ProjectDiablo2"
cp ProjectDiablo2.mpq $"($d2r)/mods/ProjectDiablo2/"
```

**Step 3 — Set launch arguments**

In Battle.net → D2R **Game Settings → Additional command line arguments**:
```
-mod ProjectDiablo2 -txt
```

> `-mod` specifies the mod name (must match the subdirectory under `mods/`). `-txt` enables text file overrides required by some mods.

---

## 🛠 Tips & Tricks

### Data Persistence
This system uses an **ephemeral root** approach. Only specific directories are persisted between reboots — see the Persisted Paths table above.

### Software Rendering (VM Only)
In VM environments where GPU acceleration is unstable, software rendering is forced globally via `LIBGL_ALWAYS_SOFTWARE=1`. The physical machine (`homePC`) does not include this setting.

### Fcitx5 Not Responding After Unclean Shutdown (Ctrl+Space Broken)

After a crash or unclean shutdown, fcitx5 may start but fail to initialize its Wayland frontend properly. Symptom: `Ctrl+Space` does nothing, and `fcitx5-remote` prints `0` (unreachable).

Fix — restart fcitx5 via Hyprland:

```nu
pkill fcitx5
hyprctl dispatch exec "fcitx5 -d --replace"
```

> fcitx5 is started via `uwsm app --` in `hyprland.conf`, which ensures it launches only after `graphical-session.target` is reached and the `zwp_input_method_v2` protocol is ready. On a clean boot this is reliable; the above workaround is only needed after an unclean shutdown leaves stale state.

### GitHub CLI Authentication

`gh` is installed declaratively, but its auth state is user-managed. After a fresh install, authenticate once with the GitHub token stored in sops:

```nu
open /run/secrets/github-mcp-token | str trim | ^gh auth login --with-token
^gh config set git_protocol ssh --host github.com
```

On `homePC`, `~/.config/gh` is persisted so this login survives reboot. Do not manage `~/.config/gh/hosts.yml` with Nix or sops; `gh` owns and migrates that file itself.


### Sops Bootstrapping (First Time)
If you are on a new machine and `sops` fails to find your keys, run this in Nushell:
```nu
$env.SOPS_AGE_KEY_FILE = ("~/.config/sops/age/keys.txt" | path expand)
```
This is already configured in `config.nu`, but may be needed if you haven't rebooted or re-applied the configuration.
