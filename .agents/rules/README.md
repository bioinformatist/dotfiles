---
trigger: always_on
---

# 系统环境：强制规则（CRITICAL RULES）

> 这些规则是**硬性约束**，不得以任何理由绕过或忽略。

## 🔴 Shell：Nushell 优先

本系统的**默认 Shell 是 Nushell（nu）**，而非 Bash 或 POSIX sh。

### 强制行为

- 所有命令示例、脚本片段**必须使用 Nushell 语法**书写
- 运行命令前，**先确认该命令在 Nushell 中的正确写法**
- Nushell 不支持 POSIX 语法（如 `export FOO=bar`、`$(...)` 命令替换、`&&` 链式）

### ❌ 禁止（常见错误示例）

```bash
# 错误：Bash 风格，在 Nushell 中无法执行
export PATH=$PATH:/new/path
echo $HOME && ls
FOO=$(cat file.txt)
```

### ✅ 正确（Nushell 风格）

```nu
# 正确：Nushell 语法
$env.PATH = ($env.PATH | append "/new/path")
echo $env.HOME; ls
let foo = (open file.txt)
```

---

## 🔴 TUI 输出捕获规则

许多命令（如 `zeroclaw models list`）使用彩色 TUI 渲染输出。

### 强制行为

- `run_command` 在同步模式下**无法正确捕获**彩色/TUI 输出（会显示为空行）
- 遇到此情况时，**必须使用 `read_terminal` 工具**读取终端已有输出
- **禁止**因为输出为空而反复重跑命令，或盲目添加 `| str collect` / `2>&1` 等重定向

---

## 🟠 解决方案质量：拒绝临时方案

### 强制行为

- **禁止**使用 workaround、hack、临时补丁（如 `chmod 777`、hardcoded path、shell alias 绕过）
- 每个解决方案必须是**可复现、版本化、声明式**的
- 解决问题前，**必须先用搜索工具或 GitHub MCP server 调研 best practice**，再制订方案

---

# 技术栈偏好（PREFERENCES）

> 在工具/库选型时，优先考虑以下属性，并**主动对比候选项后提示用户选择**。

## 工具选型标准（按优先级排序）

| 优先级 | 属性 | 说明 |
|--------|------|------|
| 1 | **社区成熟** | 有活跃维护、Issue 响应及时、广泛被采用 |
| 2 | **Rust 实现** | 性能、内存安全、现代工具链 |
| 3 | **高度可定制** | 支持配置文件、插件机制或模块化设计 |
| 4 | **紧跟上游** | 优先使用最新稳定版，避免过时 API |

### 强制行为

- 当存在多个候选工具时，**必须列出对比表格**（功能、社区活跃度、维护状态、Rust/非 Rust）
- **禁止**只给出单一选项而不作任何比较
- 对于 NixOS 生态，优先检查 `nixpkgs` 或 `nur` 中的可用性

---

# 工作流规范（WORKFLOW）

## 调试与命令执行

1. 运行命令前，先检查：该命令是否在 Nushell 中有效？
2. 输出为空时，**不要重跑**——改用 `read_terminal` 读取 TUI 输出
3. 需要调试 Nix 构建时，使用 `nix log` 或 `nix build --show-trace`

## 任务规划

1. 复杂任务必须先研究 → 制订方案 → 请用户确认 → 再执行
2. 研究阶段**必须使用** `search_web` 和 `mcp_github_*` 工具
3. 不得跳过研究阶段而直接给出"常见做法"

## NixOS 特定规则

- 所有配置变更**必须通过 Nix 声明式管理**（flake / Home Manager / NixOS modules）
- 禁止建议使用 `nix-env -i`（命令式安装）
- 优先使用 `pkgs.writeShellScriptBin` 等纯函数式方式封装脚本