# 密钥管理指南（Sops + Age）

本仓库使用 [sops-nix](https://github.com/Mic92/sops-nix) 对密钥（如用户密码、API Key）进行声明式管理。我们使用 **Age** 进行加密。

## 1. 前置条件
你需要安装 `sops` 和 `age`。
如果你使用 NixOS 或已安装 Nix，可以通过设置代理变量来获取软件包（请将端口替换为你的代理端口，如 7897）：
```bash
# 为当前 shell 会话设置代理以获取软件包
export https_proxy=http://127.0.0.1:7890
export http_proxy=http://127.0.0.1:7890
nix-shell -p sops age
```

### 备选方案：手动安装 Sops 二进制文件
如果 Nix 无法构建 sops（在中国大陆因 Go 依赖拉取失败较为常见），可直接下载二进制文件：
1.  从 [GitHub Releases](https://github.com/getsops/sops/releases) 下载 `sops`。
2.  `chmod +x sops-v* && sudo mv sops-v* /usr/local/bin/sops`
3.  若缺少 `mkpasswd`，使用 Python 生成密码哈希：
    ```bash
    python3 -c 'import crypt; print(crypt.crypt("YOUR_PASSWORD", crypt.mksalt(crypt.METHOD_SHA512)))'
    ```

## 2. 密钥生成（一次性设置）
为你的用户生成一个集中式 Age 密钥。
```bash
mkdir -p ~/.config/sops/age
# 生成私钥
age-keygen -o ~/.config/sops/age/keys.txt
```
**重要提示**：请将 `~/.config/sops/age/keys.txt` 备份到密码管理器中！如果丢失此文件，你将无法访问所有密钥。

获取你的**公钥**：
```bash
age-keygen -y ~/.config/sops/age/keys.txt
# 输出示例：age1...
```
此公钥必须添加到仓库根目录的 `.sops.yaml` 中。

## 3. 配置（.sops.yaml）
`.sops.yaml` 文件定义了哪些密钥可以解密哪些文件。
```yaml
keys:
  - &my_key age1... (你的公钥)
creation_rules:
  - path_regex: secrets/.*
    key_groups:
      - age:
          - *my_key
```

## 4. 管理密钥
要创建或编辑密钥文件：
```bash
# 确认你已在 ~/.config/sops/age/keys.txt 放置了私钥
sops secrets/secrets.yaml
```

### 重置用户密码
要更改用户登录密码：
1.  生成新密码的 SHA-512 哈希（使用 Python 3）：
    ```bash
    python3 -c 'import crypt; print(crypt.crypt("YOUR_PASSWORD", crypt.mksalt(crypt.METHOD_SHA512)))'
    # 将 YOUR_PASSWORD 替换为你的实际密码
    # 复制输出的哈希值（以 $6$... 开头）
    ```
2.  编辑密钥文件：
    ```bash
    sops secrets/secrets.yaml
    ```
3.  更新 `ysun-password` 字段：
    ```yaml
    ysun-password: "YOUR_NEW_HASH_HERE"
    ```

## 5. 部署（新机器）
在新机器上安装时（或临时根文件系统设置），系统在获得私钥之前无法解密密钥。

**安装期间（如 Live ISO 环境）**：
你必须手动假定目标系统的身份。
```bash
# 1. 为密钥创建持久化目录
sudo mkdir -p /mnt/persist/var/lib/sops-nix

# 2. 将你的私钥内容写入
sudo sh -c 'echo "AGE-SECRET-KEY-..." > /mnt/persist/var/lib/sops-nix/key.txt'
sudo chmod 600 /mnt/persist/var/lib/sops-nix/key.txt

# 3. 关键步骤（擦除式安装必需）：
# 镜像到临时根目录以便 sops-install-secrets 在安装期间能找到它
sudo mkdir -p /mnt/var/lib/sops-nix
sudo cp /mnt/persist/var/lib/sops-nix/key.txt /mnt/var/lib/sops-nix/key.txt
```

## 6. 添加新设备 SSH 密钥
要为新机器（如 `vm-test`）分配 GitHub 访问使用的独立密钥：

1.  **生成密钥**：
    ```bash
    # 生成新的 ed25519 密钥（无密码，因为在存储层已由 sops 加密）
    ssh-keygen -t ed25519 -C "ysun@vm-test" -N ""
    ```

2.  **添加到密钥库**：
    确保你的主身份密钥位于 `~/.config/sops/age/keys.txt`。
    
    使用临时 shell 运行 `sops`（无需全局安装）：
    ```bash
    nix shell nixpkgs#sops --command sops secrets/secrets.yaml
    ```
    
    在新键名下添加密钥内容（如 `github-ssh-key-vm-test`）：
    ```yaml
    github-ssh-key-vm-test: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      ... (~/.ssh/id_ed25519 的内容) ...
      -----END OPENSSH PRIVATE KEY-----
    ```
    *注意：请正确缩进密钥内容。*

3.  **清理**：
    确认密钥已存入 sops 后，删除生成的密钥文件（`~/.ssh/id_ed25519` 和 `.pub`）。系统将在下次重建时自动将其配置到 `~/.ssh/` 目录下。
