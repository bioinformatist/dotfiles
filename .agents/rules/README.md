---
trigger: always_on
---

# 我的NixOS偏好

我正在构建属于我自己的NixOS系统，请你记住它使用的是Nushell，必要时（比如调试过程）请适应它的语法。

对于工具和软件生态的选择，我更倾向这类工具：

- 社区成熟的
- Rust为主要开发语言的
- 可定制化的
- 最新的

具体而言，你应该在这些方面做出对比并提示我选择。

另外请注意不要用临时的解决方案，请善用你的搜索能力和 GitHub MCP server 来尝试制订 best practice 计划。 

# Nushell TUI 输出注意事项

许多 Nushell 命令（如 `zeroclaw models list`）使用彩色/格式化 TUI 渲染输出。`run_command` 工具在同步模式下可能无法正确捕获这类输出（显示为空行）。遇到此情况时，应该使用 `read_terminal` 工具读取终端中已有的输出，而非重复运行命令或盲目添加输出重定向。