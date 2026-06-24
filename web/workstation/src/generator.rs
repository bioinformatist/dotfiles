use std::io::{Cursor, Write};

use serde_json::{json, Value};
use sha_crypt::{sha512_crypt_b64, Sha512Params, ROUNDS_DEFAULT};
use zip::write::SimpleFileOptions;

const ROOT_FLAKE_LOCK: &str = include_str!("../../../flake.lock");
pub const UPSTREAM_REV: &str = env!("DOTFILES_GENERATOR_UPSTREAM_REV");
const UPSTREAM_LAST_MODIFIED: &str = env!("DOTFILES_GENERATOR_UPSTREAM_LAST_MODIFIED");
const UPSTREAM_NAR_HASH: &str = env!("DOTFILES_GENERATOR_UPSTREAM_NAR_HASH");
const DISK_PLACEHOLDER: &str = "/dev/disk/by-id/REPLACE_ME_BEFORE_INSTALL";

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum NetworkMode {
    China,
    Global,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ProductSpec {
    pub host_name: String,
    pub username: String,
    pub ssh_public_key: String,
    pub initial_password: String,
    pub password_salt: String,
    pub git_name: String,
    pub git_email: String,
    pub disk_path: String,
    pub nvidia: bool,
    pub network_mode: NetworkMode,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct DerivedState {
    pub errors: Vec<IssueCode>,
    pub warnings: Vec<IssueCode>,
    pub notices: Vec<IssueCode>,
    pub can_download: bool,
    pub can_install: bool,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum IssueCode {
    HostNameInvalid,
    UsernameInvalid,
    LoginMethodMissing,
    SshPublicKeyInvalid,
    InitialPasswordTooShort,
    DiskMissing,
    DiskPathUnstable,
    ChinaNetwork,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct GeneratedFile {
    pub path: String,
    pub contents: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct GeneratedProject {
    pub files: Vec<GeneratedFile>,
}

impl ProductSpec {
    pub fn normalized_disk_path(&self) -> Option<String> {
        let trimmed = self.disk_path.trim();
        if trimmed.is_empty() {
            None
        } else {
            Some(trimmed.to_owned())
        }
    }

    fn has_ssh_key(&self) -> bool {
        !self.ssh_public_key.trim().is_empty()
    }

    fn has_initial_password(&self) -> bool {
        !self.initial_password.is_empty()
    }
}

pub fn derive_state(spec: &ProductSpec) -> DerivedState {
    let mut errors = Vec::new();
    let mut warnings = Vec::new();
    let mut notices = Vec::new();

    if !is_valid_hostname(spec.host_name.trim()) {
        errors.push(IssueCode::HostNameInvalid);
    }

    if !is_valid_username(spec.username.trim()) {
        errors.push(IssueCode::UsernameInvalid);
    }

    if !spec.has_ssh_key() && !spec.has_initial_password() {
        errors.push(IssueCode::LoginMethodMissing);
    }

    if spec.has_ssh_key() && !is_plausible_ssh_public_key(spec.ssh_public_key.trim()) {
        errors.push(IssueCode::SshPublicKeyInvalid);
    }

    if spec.has_initial_password() && spec.initial_password.len() < 8 {
        errors.push(IssueCode::InitialPasswordTooShort);
    }

    let disk_path = spec.normalized_disk_path();
    let disk_is_installable = match disk_path.as_deref() {
        None => {
            warnings.push(IssueCode::DiskMissing);
            false
        }
        Some(path) if path.starts_with("/dev/disk/by-id/") => true,
        Some(_) => {
            errors.push(IssueCode::DiskPathUnstable);
            false
        }
    };

    if spec.network_mode == NetworkMode::China {
        notices.push(IssueCode::ChinaNetwork);
    }

    let can_download = errors.is_empty();
    let can_install = can_download && disk_is_installable;

    DerivedState {
        errors,
        warnings,
        notices,
        can_download,
        can_install,
    }
}

pub fn generate(spec: &ProductSpec) -> Result<GeneratedProject, String> {
    let state = derive_state(spec);
    if !state.can_download {
        return Err("configuration has validation errors".to_owned());
    }

    let host_name = spec.host_name.trim();
    let username = spec.username.trim();
    let disk_path = spec
        .normalized_disk_path()
        .unwrap_or_else(|| DISK_PLACEHOLDER.to_owned());

    let files = vec![
        GeneratedFile {
            path: "flake.nix".to_owned(),
            contents: render_flake_nix(spec),
        },
        GeneratedFile {
            path: "flake.lock".to_owned(),
            contents: render_flake_lock()?,
        },
        GeneratedFile {
            path: format!("hosts/{host_name}/configuration.nix"),
            contents: render_configuration(spec)?,
        },
        GeneratedFile {
            path: format!("hosts/{host_name}/hardware-configuration.nix"),
            contents: render_hardware_configuration(),
        },
        GeneratedFile {
            path: format!("hosts/{host_name}/disko-config.nix"),
            contents: render_disko_config(&disk_path),
        },
        GeneratedFile {
            path: format!("users/{username}/home.nix"),
            contents: render_home(spec),
        },
        GeneratedFile {
            path: "README.zh-CN.md".to_owned(),
            contents: render_readme(spec, &state),
        },
    ];

    Ok(GeneratedProject { files })
}

pub fn zip_project(project: &GeneratedProject) -> Result<Vec<u8>, String> {
    let mut writer = zip::ZipWriter::new(Cursor::new(Vec::new()));
    let options = SimpleFileOptions::default().unix_permissions(0o644);

    for file in &project.files {
        writer
            .start_file(&file.path, options)
            .map_err(|err| err.to_string())?;
        writer
            .write_all(file.contents.as_bytes())
            .map_err(|err| err.to_string())?;
    }

    writer
        .finish()
        .map(|cursor| cursor.into_inner())
        .map_err(|err| err.to_string())
}

fn render_flake_nix(spec: &ProductSpec) -> String {
    let host_name = spec.host_name.trim();
    let username = spec.username.trim();
    let nvidia_module = if spec.nvidia {
        "          upstream.nixosModules.nvidiaDesktop\n"
    } else {
        ""
    };

    format!(
        r#"{{
  description = "Generated NixOS workstation";

  inputs = {{
    upstream.url = "github:bioinformatist/dotfiles?rev={UPSTREAM_REV}";
  }};

  outputs =
    inputs@{{ upstream, ... }}:
    let
      system = "x86_64-linux";
      username = "{username}";
    in
    {{
      nixosConfigurations."{host_name}" = upstream.lib.mkWorkstationSystem {{
        inherit system;
        inherit username;
        modules = [
{nvidia_module}          ./hosts/{host_name}/configuration.nix
        ];
        homeModules = [
          ./users/{username}/home.nix
        ];
      }};
    }};
}}
"#
    )
}

fn render_configuration(spec: &ProductSpec) -> Result<String, String> {
    let host_name = spec.host_name.trim();
    let username = spec.username.trim();
    let login_config = render_login_config(spec)?;
    let network_config = render_network_config(spec.network_mode);

    Ok(format!(
        r#"{{ ... }}:

let
  username = "{username}";
in
{{
  imports = [
    ./hardware-configuration.nix
    ./disko-config.nix
  ];

  networking = {{
    hostName = "{host_name}";
    networkmanager.enable = true;
  }};

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  users.users.${{username}} = {{
{login_config}  }};

{network_config}
}}
"#
    ))
}

fn render_login_config(spec: &ProductSpec) -> Result<String, String> {
    let mut lines = Vec::new();

    if spec.has_ssh_key() {
        lines.push(format!(
            r#"    openssh.authorizedKeys.keys = [
      "{}"
    ];"#,
            escape_nix_string(spec.ssh_public_key.trim())
        ));
    }

    if spec.has_initial_password() {
        let salt = if spec.password_salt.trim().is_empty() {
            "dotfiles"
        } else {
            spec.password_salt.trim()
        };
        let hash = initial_password_hash(&spec.initial_password, salt)?;
        lines.push(format!(
            r#"    initialHashedPassword = "{}";"#,
            escape_nix_string(&hash)
        ));
    }

    Ok(lines.join("\n"))
}

fn render_network_config(mode: NetworkMode) -> String {
    match mode {
        NetworkMode::China => r#"  dotfiles.workstation.clash.enable = true;
  dotfiles.nixNetwork = {
    profile = "china";
    proxy = {
      enable = true;
      url = "http://127.0.0.1:7897";
    };
  };
"#
        .to_owned(),
        NetworkMode::Global => r#"  dotfiles.workstation.clash.enable = false;
"#
        .to_owned(),
    }
}

fn render_disko_config(disk_path: &str) -> String {
    format!(
        r#"{{
  disko.devices = {{
    disk.main = {{
      type = "disk";
      device = "{disk_path}";
      content = {{
        type = "gpt";
        partitions = {{
          ESP = {{
            size = "1G";
            type = "EF00";
            content = {{
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            }};
          }};
          root = {{
            size = "100%";
            content = {{
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            }};
          }};
        }};
      }};
    }};
  }};
}}
"#
    )
}

fn render_hardware_configuration() -> String {
    r#"{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];
}
"#
    .to_owned()
}

fn render_home(spec: &ProductSpec) -> String {
    let git_name = spec.git_name.trim();
    let git_email = spec.git_email.trim();

    if git_name.is_empty() && git_email.is_empty() {
        return r#"{ ... }:
{
  programs.git.enable = true;
}
"#
        .to_owned();
    }

    let mut options = Vec::new();
    if !git_name.is_empty() {
        options.push(format!(
            r#"  programs.git.userName = "{}";"#,
            escape_nix_string(git_name)
        ));
    }
    if !git_email.is_empty() {
        options.push(format!(
            r#"  programs.git.userEmail = "{}";"#,
            escape_nix_string(git_email)
        ));
    }

    format!(
        r#"{{ ... }}:
{{
  programs.git.enable = true;
{}
}}
"#,
        options.join("\n")
    )
}

fn render_readme(spec: &ProductSpec, state: &DerivedState) -> String {
    let host_name = spec.host_name.trim();
    let username = spec.username.trim();
    let disk = spec
        .normalized_disk_path()
        .unwrap_or_else(|| DISK_PLACEHOLDER.to_owned());
    let install_command = if state.can_install {
        format!(
            "nix run github:nix-community/nixos-anywhere -- --flake .#{host_name} root@<target-ip>"
        )
    } else {
        "先把 hosts/<host>/disko-config.nix 中的目标磁盘占位符替换为 /dev/disk/by-id/... 后再运行安装命令。".to_owned()
    };
    let network_section = match spec.network_mode {
        NetworkMode::China => {
            r#"
## 中国大陆网络模式

本配置会安装 Clash Verge，并让 `nix-daemon` 默认走 `http://127.0.0.1:7897`。
首次启动后必须立刻配置 Clash 订阅；否则 `nix flake update` 和 `nixos-rebuild`
无法正常拉取依赖。
"#
        }
        NetworkMode::Global => "",
    };

    format!(
        r#"# NixOS workstation

本配置由 `bioinformatist/dotfiles` workstation 生成器创建。

- hostName: `{host_name}`
- username: `{username}`
- 目标磁盘: `{disk}`
- upstream revision: `{UPSTREAM_REV}`

## 安装前提

表单中的 SSH public key 或初始密码用于安装完成后的新 NixOS 用户。
运行 `nixos-anywhere` 前，你仍需要让目标机进入可 SSH 的 installer/Linux 环境，并能从当前机器登录 `root@<target-ip>`。

## 安装

```bash
{install_command}
```
{network_section}
## 磁盘风险

危险：`disko` 会清空并重新分区目标系统盘，该磁盘上的所有现有数据都会被销毁。
第一版不支持保留现有分区、双系统或迁移已有 Linux。
"#
    )
}

fn render_flake_lock() -> Result<String, String> {
    let mut lock: Value = serde_json::from_str(ROOT_FLAKE_LOCK).map_err(|err| err.to_string())?;
    let last_modified = UPSTREAM_LAST_MODIFIED.parse::<u64>().unwrap_or(0);

    let root_inputs = lock
        .pointer("/nodes/root/inputs")
        .cloned()
        .ok_or_else(|| "root flake.lock missing root inputs".to_owned())?;
    let nodes = lock
        .get_mut("nodes")
        .and_then(Value::as_object_mut)
        .ok_or_else(|| "flake.lock missing nodes".to_owned())?;

    nodes.insert(
        "upstream".to_owned(),
        json!({
            "inputs": root_inputs,
            "locked": {
                "lastModified": last_modified,
                "narHash": UPSTREAM_NAR_HASH,
                "owner": "bioinformatist",
                "repo": "dotfiles",
                "rev": UPSTREAM_REV,
                "type": "github"
            },
            "original": {
                "owner": "bioinformatist",
                "repo": "dotfiles",
                "rev": UPSTREAM_REV,
                "type": "github"
            }
        }),
    );

    lock["nodes"]["root"]["inputs"] = json!({
        "upstream": "upstream"
    });

    serde_json::to_string_pretty(&lock).map_err(|err| err.to_string())
}

fn initial_password_hash(password: &str, salt: &str) -> Result<String, String> {
    let params = Sha512Params::new(ROUNDS_DEFAULT).map_err(|err| format!("{err:?}"))?;
    let hash = sha512_crypt_b64(password.as_bytes(), salt.as_bytes(), &params)
        .map_err(|err| format!("{err:?}"))?;
    Ok(format!("$6${salt}${hash}"))
}

fn is_valid_hostname(value: &str) -> bool {
    is_dns_label(value)
}

fn is_valid_username(value: &str) -> bool {
    let mut chars = value.chars();
    matches!(chars.next(), Some(ch) if ch.is_ascii_lowercase() || ch == '_')
        && chars.all(|ch| ch.is_ascii_lowercase() || ch.is_ascii_digit() || ch == '_' || ch == '-')
        && value.len() <= 32
}

fn is_dns_label(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 63
        && value
            .chars()
            .all(|ch| ch.is_ascii_lowercase() || ch.is_ascii_digit() || ch == '-')
        && !value.starts_with('-')
        && !value.ends_with('-')
}

fn is_plausible_ssh_public_key(value: &str) -> bool {
    let mut parts = value.split_whitespace();
    let Some(kind) = parts.next() else {
        return false;
    };
    let Some(key) = parts.next() else {
        return false;
    };

    matches!(
        kind,
        "ssh-ed25519"
            | "ssh-rsa"
            | "ecdsa-sha2-nistp256"
            | "ecdsa-sha2-nistp384"
            | "ecdsa-sha2-nistp521"
            | "sk-ssh-ed25519@openssh.com"
            | "sk-ecdsa-sha2-nistp256@openssh.com"
    ) && key.len() > 32
        && key
            .chars()
            .all(|ch| ch.is_ascii_alphanumeric() || ch == '+' || ch == '/' || ch == '=')
}

fn escape_nix_string(value: &str) -> String {
    value.replace('\\', "\\\\").replace('"', "\\\"")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn base_spec() -> ProductSpec {
        ProductSpec {
            host_name: "workstation".to_owned(),
            username: "alice".to_owned(),
            ssh_public_key:
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"
                    .to_owned(),
            initial_password: String::new(),
            password_salt: "testsalt".to_owned(),
            git_name: String::new(),
            git_email: String::new(),
            disk_path: "/dev/disk/by-id/nvme-Test".to_owned(),
            nvidia: false,
            network_mode: NetworkMode::Global,
        }
    }

    #[test]
    fn requires_login_method() {
        let mut spec = base_spec();
        spec.ssh_public_key.clear();
        let state = derive_state(&spec);
        assert!(!state.can_download);
        assert!(state.errors.contains(&IssueCode::LoginMethodMissing));
    }

    #[test]
    fn missing_disk_allows_download_but_not_install() {
        let mut spec = base_spec();
        spec.disk_path.clear();
        let state = derive_state(&spec);
        assert!(state.can_download);
        assert!(!state.can_install);
        assert!(state.warnings.contains(&IssueCode::DiskMissing));
    }

    #[test]
    fn unstable_disk_path_is_rejected() {
        let mut spec = base_spec();
        spec.disk_path = "/dev/sda".to_owned();
        let state = derive_state(&spec);
        assert!(!state.can_download);
        assert!(state.errors.contains(&IssueCode::DiskPathUnstable));
    }

    #[test]
    fn china_mode_generates_proxy_config() {
        let mut spec = base_spec();
        spec.network_mode = NetworkMode::China;
        let project = generate(&spec).expect("valid project");
        let config = project
            .files
            .iter()
            .find(|file| file.path.ends_with("configuration.nix"))
            .expect("configuration")
            .contents
            .as_str();
        assert!(config.contains("profile = \"china\""));
        assert!(config.contains("http://127.0.0.1:7897"));
    }

    #[test]
    fn password_mode_uses_initial_hashed_password() {
        let mut spec = base_spec();
        spec.ssh_public_key.clear();
        spec.initial_password = "correct horse battery staple".to_owned();
        let project = generate(&spec).expect("valid project");
        let config = project
            .files
            .iter()
            .find(|file| file.path.ends_with("configuration.nix"))
            .expect("configuration")
            .contents
            .as_str();
        assert!(config.contains("initialHashedPassword"));
        assert!(!config.contains("correct horse battery staple"));
    }

    #[test]
    fn git_identity_uses_home_manager_git_options() {
        let mut spec = base_spec();
        spec.git_name = "Alice Example".to_owned();
        spec.git_email = "alice@example.com".to_owned();
        let project = generate(&spec).expect("valid project");
        let home = project
            .files
            .iter()
            .find(|file| file.path.ends_with("home.nix"))
            .expect("home")
            .contents
            .as_str();
        assert!(home.contains("programs.git.userName"));
        assert!(home.contains("programs.git.userEmail"));
        assert!(!home.contains("programs.git.settings"));
    }

    #[test]
    fn generated_flake_inherits_upstream_workstation_builder() {
        let project = generate(&base_spec()).expect("valid project");
        let flake = project
            .files
            .iter()
            .find(|file| file.path == "flake.nix")
            .expect("flake")
            .contents
            .as_str();
        assert!(flake.contains("upstream.lib.mkWorkstationSystem"));
        assert!(!flake.contains("github:NixOS/nixpkgs"));
        assert!(!flake.contains("github:nix-community/home-manager"));
        assert!(!flake.contains("github:nix-community/disko"));
    }

    #[test]
    fn nvidia_desktop_patch_adds_upstream_module() {
        let mut spec = base_spec();
        spec.nvidia = true;
        let project = generate(&spec).expect("valid project");
        let flake = project
            .files
            .iter()
            .find(|file| file.path == "flake.nix")
            .expect("flake")
            .contents
            .as_str();
        assert!(flake.contains("upstream.nixosModules.nvidiaDesktop"));
    }

    #[test]
    fn generated_host_does_not_set_state_version() {
        let project = generate(&base_spec()).expect("valid project");
        let config = project
            .files
            .iter()
            .find(|file| file.path.ends_with("configuration.nix"))
            .expect("configuration")
            .contents
            .as_str();
        assert!(!config.contains("stateVersion"));
    }

    #[test]
    fn generated_lock_pins_only_upstream() {
        let lock: Value = serde_json::from_str(&render_flake_lock().expect("flake.lock"))
            .expect("valid flake.lock json");
        assert_eq!(
            lock.pointer("/nodes/root/inputs").expect("root inputs"),
            &json!({ "upstream": "upstream" })
        );
        assert_ne!(
            lock.pointer("/nodes/upstream/locked/narHash")
                .and_then(Value::as_str),
            Some("sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
        );
        assert!(lock
            .pointer("/nodes/upstream/locked/rev")
            .and_then(Value::as_str)
            .is_some());
    }
}
