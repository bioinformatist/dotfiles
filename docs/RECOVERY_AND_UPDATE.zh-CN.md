# 系统恢复、更新与维护

本指南介绍如何**更新系统全部软件包**、**修复损坏的系统**或**应用配置更新**（如密码更改）——**无需擦除磁盘**。

## 1. 启动 & 网络（中国大陆优化）
从 NixOS 安装 ISO 启动。

**关键步骤**：立即配置 USTC 镜像以避免下载缓慢和超时。
```bash
mkdir -p ~/.config/nix
echo "substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org" >> ~/.config/nix/nix.conf
```

## 2. 挂载现有磁盘（不要擦除）
无需重新分区（这会擦除数据），我们使用 `disko` 仅**挂载**现有分区。
```bash
# 将仓库克隆到临时位置
rm -rf /tmp/dotfiles
git clone https://github.com/bioinformatist/dotfiles /tmp/dotfiles
cd /tmp/dotfiles
git checkout feat/ephemeral-root

# 使用 disko 挂载磁盘（挂载模式）
sudo nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- --mode mount ./hosts/vm-test/disko-config.nix
```

## 3. 将密钥部署到临时根目录
因为当前处于安装器环境中，我们必须手动确保 Sops 能访问到密钥。
密钥应该已存在于 `/mnt/persist` 中。我们只需将其镜像到临时根目录。

```bash
# 创建目标目录
sudo mkdir -p /mnt/var/lib/sops-nix

# 从持久化存储复制密钥
# 如果此步骤失败，说明密钥已丢失，需要重新创建（参见 SECRET_MANAGEMENT.zh-CN.md）
sudo cp /mnt/persist/var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/key.txt
```

## 4. 重新安装（增量）
运行安装命令。确认使用了 USTC 镜像。
`/mnt/nix/store` 中已有的文件将被复用，因此此过程会非常快。

```bash
# 注意将 'homePC' 替换为 'vm-test'（按照新结构）
sudo nixos-install --flake .#vm-test --no-root-passwd --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store"
```

## 5. 重启
```bash
sudo reboot
```

## 6. 故障排除：验证密钥（如果无法登录）
如果无法登录，请验证磁盘上的密钥是否与加密的密钥一致。

1.  **启动 ISO & 网络**：按上述第 1 步操作。
2.  **挂载持久化分区**：
    ```bash
    # 识别你的持久化分区（通常是最大的 btrfs 分区）
    lsblk
    sudo mkdir -p /mnt/verify
    # 挂载 /persist 子卷。如需要请调整 /dev/sda2。
    sudo mount -o subvol=persist /dev/sda2 /mnt/verify
    ```
3.  **检查密钥是否存在**：
    ```bash
    ls -l /mnt/verify/var/lib/sops-nix/key.txt
    ```
4.  **测试解密**：
    ```bash
    # 使用磁盘上的密钥，通过 sops 尝试解密密钥文件
    cd /tmp/dotfiles # 确保已按第 2 步克隆仓库
    
    # 如需要，设置代理
    export https_proxy=http://127.0.0.1:7890
    
    echo "尝试解密..."
    # 必须使用 sudo，因为 key.txt 属于 root（权限 600）
    sudo -E nix-shell --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store" -p sops --run "SOPS_AGE_KEY_FILE=/mnt/verify/var/lib/sops-nix/key.txt sops -d secrets/secrets.yaml"
    ```
    *   **成功**：打印解密后的 YAML 内容（成功了！）。
    *   **失败**：`MacError` 或 `Failed to decrypt`。这意味着 `/mnt/verify/...` 中的密钥不是加密 `secrets.yaml` 时使用的那个。

### 修复密钥不匹配
如果解密失败，你必须对齐密钥：

1.  **在本地机器上（你有 sops/age 的那台）**：
    *   获取你的**当前**公钥：
        ```bash
        nix-shell -p age --run "age-keygen -y ~/.config/sops/age/keys.txt"
        # 输出示例：age1...
        ```
    *   编辑 `.sops.yaml` 并更新密钥以匹配此输出。
    *   使用新密钥**重新加密**密钥文件：
        ```bash
        # 如果在中国大陆，设置代理
        export https_proxy=http://127.0.0.1:7890
        nix-shell -p sops --run "sops updatekeys secrets/secrets.yaml"
        ```
    *   提交并推送：`git add . && git commit -m "fix: rotate sops key" && git push`

2.  **在虚拟机中（ISO 环境）**：
    *   **拉取最新代码**：`cd /tmp/dotfiles && git pull`
    *   用你本地的**私钥**（`~/.config/sops/age/keys.txt` 的内容）**覆盖**磁盘上的密钥：
        ```bash
        # 先创建目录
        sudo mkdir -p /mnt/verify/var/lib/sops-nix
        
        # 覆盖持久化密钥
        sudo sh -c 'echo "YOUR-LOCAL-PRIVATE-KEY-CONTENT" > /mnt/verify/var/lib/sops-nix/key.txt'
        # 镜像到临时位置
        sudo mkdir -p /mnt/var/lib/sops-nix
        sudo cp /mnt/verify/var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/key.txt
        ```
    *   **重新安装**：
        ```bash
         sudo nixos-install --flake .#vm-test --no-root-passwd --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store"
        ```

## 7. 日常系统更新（在运行中的系统上）

本节适用于**已安装并正常运行的系统**上的日常包更新流程。无需 ISO 或重新安装。

> **Shell 说明**：第 1–6 节在 ISO 安装器环境中操作，使用 **bash**。
> 本节在已配置好的系统上操作，使用 **Nushell**。语法有所不同。

### 中国大陆网络须知

更新过程中有**两类**网络请求，加速方式不同：

| 请求类型 | 用途 | 加速方式 |
|---|---|---|
| **GitHub 源码获取** | `nix flake update` 拉取 flake inputs（HTTPS tarball） | 必须走**代理**，USTC 镜像无法加速 |
| **二进制缓存下载** | `nixos-rebuild` 从 cache 下载预编译包 | 使用 **USTC 镜像**（`--option substituters`） |

> **为什么代理能生效？** Nix 底层使用 **libcurl** 进行 HTTP 请求，libcurl 原生支持
> `http_proxy`/`https_proxy` 环境变量。`nix flake update` 对 `github:` 类型的 input
> 是通过 HTTPS 下载 tarball（而非 `git clone`），因此会自动使用代理。

因此，完整更新需要**同时**配置代理和 USTC 镜像。

**设置代理**（Nushell 语法，局域网代理或本机代理均可）：
```nu
# 将地址替换为你的实际代理地址
# 本机代理示例：http://127.0.0.1:7890
# 局域网代理示例：http://192.168.1.100:7890
$env.http_proxy = "http://<代理地址>:<端口>"
$env.https_proxy = "http://<代理地址>:<端口>"
```

### 第 1 步：更新 Flake 输入（`flake.lock`）

此命令从 GitHub 拉取所有依赖的最新版本（nixpkgs、home-manager、hyprland 等）。

```nu
cd /path/to/dotfiles   # 例如 ~/github.com/bioinformatist/dotfiles

# 确保已设置代理（见上方）
nix flake update
```

此操作会修改 `flake.lock` 文件——之后应提交该文件。

### 第 2 步：重建并切换

将更新后的软件包应用到运行中的系统。

> **重要**：`sudo` 默认会**丢弃**当前用户的环境变量（包括 `http_proxy`/`https_proxy`）。
> 必须使用 `sudo -E`（`--preserve-env`）来保留代理设置，否则构建过程中需要从 GitHub 拉取源码的包会失败。
> Nushell 通过 `$env` 设置的变量会被传递给子进程，因此 `sudo -E` 可以正确继承它们。

```nu
# 将 <host> 替换为你的主机名：vm-test、workstation 等
# -E 保留代理环境变量；--option substituters 使用 USTC 二进制缓存镜像
sudo -E nixos-rebuild switch --flake $".#<host>" --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org"
```

如果不需要代理（网络畅通），可以省略 `-E` 和代理设置：
```nu
sudo nixos-rebuild switch --flake $".#<host>"
```

### 第 3 步：提交锁文件

```nu
git add flake.lock
git commit -m "chore: update flake inputs"
git push
```

### （可选）切换前预览变更

如果想**只构建不激活**（先检查是否有构建错误）：

```nu
sudo -E nixos-rebuild build --flake $".#<host>" --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org"
```

或使用 `test` 临时激活（下次重启后恢复）：

```nu
sudo -E nixos-rebuild test --flake $".#<host>" --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org"
```
