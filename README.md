# LocalStack

**A focused macOS control surface for local web development.**

LocalStack finds the HTML services running on your Mac, verifies that each page is reachable, and puts the useful actions in one quiet menu bar panel. Register a dev server from an SDK, Vite plugin, CLI, or MCP and it appears alongside automatically discovered services.

![LocalStack menu bar panel](Resources/Brand/TrayTemplate.png)

## Why LocalStack

- **Only useful pages** — loopback listeners are shown after an independent HTML probe. JSON APIs, databases, and opaque TCP ports stay out of the default list.
- **One local source of truth** — the Coordinator owns discovery, registration, health checks, persistence, and process safety.
- **Native macOS experience** — SwiftUI/AppKit menu bar app, Liquid Glass presentation, dark and light appearances, keyboard shortcuts, WidgetKit snapshots, and `localstack://` deep links.
- **Safe process actions** — stopping a service requires a fresh PID, user, start-time, and port validation. The normal action sends `SIGTERM`; force is explicit.
- **Automation friendly** — Unix-socket JSON-RPC powers the app, Rust CLI, MCP server, TypeScript SDK, and Vite integration.

## Project layout

| Path | Purpose |
| --- | --- |
| `Sources/LocalStackApp` | Menu bar app, panel UI, settings, deep links, previews |
| `Sources/LocalStackCore` | Coordinator, discovery, probing, registry, IPC, process validation |
| `Sources/LocalStackShared` | Shared models and JSON-RPC types |
| `Sources/LocalStackWidget*` | WidgetKit extension and shared snapshots |
| `cli` | Rust CLI and stdio MCP server |
| `packages/unplugin-localstack` | TypeScript SDK and Vite plugin |
| `Scripts` | Asset generation, packaging, installation, and LaunchAgent helpers |

## Requirements

- macOS 15 or newer
- Xcode 26 or newer (Swift 6.2+, matching `Package.swift`)
- Rust toolchain for the CLI
- Node.js 20+ for the TypeScript package

## Build and test

```bash
swift build
swift test
cargo test --manifest-path cli/Cargo.toml
npm --prefix packages/unplugin-localstack test
```

Build the menu bar app and open it:

```bash
Scripts/compile_and_run.sh
```

Create a local app bundle or DMG:

```bash
make package-app
make package-dmg
```

The packaging scripts use an available Developer ID certificate when present. For a local ad-hoc build, set `SIGN_IDENTITY=-`.

For distribution, `make release-dmg` requires Developer ID signing and Apple
notarization for both the universal app and DMG. The **Release DMG** GitHub Actions
workflow builds tagged versions and assembles a verified draft release. See
[macOS release setup](docs/macos-release.md) for secrets, local commands, and verification.

## Use the CLI

```bash
cargo run --manifest-path cli/Cargo.toml -- status
cargo run --manifest-path cli/Cargo.toml -- list
cargo run --manifest-path cli/Cargo.toml -- --json status
```

Install the CLI locally with `make install-local`. The CLI can also install and diagnose the LocalStack MCP server for supported agent configurations:

```bash
localstack mcp install --target auto
localstack --json mcp doctor
```

## Register a Vite server

```ts
import LocalStack from "unplugin-localstack/vite";

export default {
  plugins: [
    LocalStack({
      name: "Console",
      projectRoot: process.cwd(),
    }),
  ],
};
```

Registration is fail-open: if the Coordinator is unavailable, the development server continues to start. The Coordinator still verifies the process and page before showing it in LocalStack.

## Run a standalone Coordinator

The app normally embeds the Coordinator. For a background-only setup, install the current-user LaunchAgent:

```bash
make install-coordinator
make uninstall-coordinator
```

Or run it directly during development:

```bash
swift run LocalStackCoordinator
```

## Design and security

LocalStack is intentionally local. It scans the current user's loopback listeners, stores its registry in the user's private application-support directory, and communicates over a user-owned Unix socket. It does not scan the LAN or upload service names, ports, titles, or page contents.

The design notes in [`.agents`](.agents/README.md) describe the architecture, service lifecycle, protocol, and implementation roadmap.

## License

MIT
