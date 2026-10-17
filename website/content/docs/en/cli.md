---
title: CLI and MCP
description: Manage verified local services from the terminal and MCP-capable coding assistants.
order: 5
image: /brand/social.png
---

The Rust CLI and stdio MCP server share the `localstack` executable. They connect to the local Coordinator without a remote account or API key. The GitHub DMG does not bundle this executable.

## Install the CLI

Install from source with a Rust toolchain. From the repository root:

```bash
make install-local
```

This installs `~/.local/bin/localstack`. Add `~/.local/bin` to your `PATH` and start the LocalStack app.

## Common commands

```bash
localstack status
localstack list
localstack --json list
localstack --help
```

Use `--json` for structured output. Registration and process-stop options are documented by `localstack register --help` and `localstack terminate --help`.

## Configure MCP

Automatic configuration supports Codex, Claude Code, and Cursor. The following command modifies their local MCP configuration:

```bash
localstack mcp install --target auto
localstack --json mcp doctor
```

You can select `--target codex`, `--target claude`, or `--target cursor`. Reload the client's MCP services afterward.

For manual configuration, use the absolute executable path and `mcp serve` arguments:

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

This is a generic JSON example. Client formats differ, so prefer the automatic installer when supported.

## Available tools

| MCP tool | Purpose |
| --- | --- |
| `localstack_list_services` | List verified, browsable local services |
| `localstack_register_service` | Submit a PID, port, and optional metadata for validation |
| `localstack_terminate_service` | Stop an exact service ID; defaults to `SIGTERM` |

Process stops still require Coordinator validation. The MCP client must apply its own permission policy before operations with side effects.

Remove LocalStack's MCP configuration with:

```bash
localstack mcp uninstall --target auto
```

## Background-only Coordinator

The app normally hosts the Coordinator. For background-only use, install a user LaunchAgent from the repository root:

```bash
make install-coordinator
```

Remove it with `make uninstall-coordinator`. During development, use `swift run LocalStackCoordinator` instead. The LaunchAgent is an optional source installation, separate from the app's login item.
