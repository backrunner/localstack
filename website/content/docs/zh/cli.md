---
title: CLI 与 MCP
description: 从终端管理 LocalStack，并为支持 MCP 的编程助手提供已验证的本地服务。
order: 5
image: /brand/social.png
---

Rust CLI 和 stdio MCP server 共用 `localstack` 可执行文件。它们连接本地 Coordinator，不需要远程账户或 API 密钥。

## 安装 CLI

目前 CLI 从源码安装，需要 Rust 工具链。在仓库根目录执行：

```bash
make install-local
```

可执行文件会安装到 `~/.local/bin/localstack`。确保 `~/.local/bin` 位于 `PATH` 中，并先启动 LocalStack 应用。

## 常用命令

```bash
localstack status
localstack list
localstack --json list
localstack --help
```

`--json` 可用于结构化输出，方便脚本读取。注册与终止命令的参数分别见 `localstack register --help` 与 `localstack terminate --help`。

## 安装 MCP 配置

LocalStack 支持自动配置 Codex、Claude Code 和 Cursor。安装命令会修改对应客户端的本地 MCP 配置：

```bash
localstack mcp install --target auto
localstack --json mcp doctor
```

也可以显式指定 `--target codex`、`--target claude` 或 `--target cursor`。安装后重新加载相应客户端的 MCP 服务。

手动配置时，使用 `localstack` 可执行文件的绝对路径，参数为 `mcp serve`：

```json
{
  "mcpServers": {
    "localstack": {
      "command": "/absolute/path/to/localstack",
      "args": ["mcp", "serve"]
    }
  }
}
```

以上展示通用 JSON 配置形状。请替换绝对路径；不同客户端的配置格式可能不同，优先使用自动安装命令。

## 提供的工具

| MCP 工具 | 用途 |
| --- | --- |
| `localstack_list_services` | 列出通过验证、可打开的本地服务 |
| `localstack_register_service` | 提交 PID、端口与可选元数据，交由 Coordinator 验证 |
| `localstack_terminate_service` | 按精确 service ID 停止服务，默认使用 `SIGTERM` |

MCP 停止操作仍需经过 Coordinator 的进程验证。MCP 客户端应根据自身权限策略决定是否执行有副作用的操作。

卸载 LocalStack 的 MCP 配置：

```bash
localstack mcp uninstall --target auto
```

## 独立运行 Coordinator

桌面应用通常会内嵌启动 Coordinator。后台使用可以在仓库根目录安装当前用户的 LaunchAgent：

```bash
make install-coordinator
```

使用 `make uninstall-coordinator` 移除；开发时也可以直接运行 `swift run LocalStackCoordinator`。
