---
title: Vite and TypeScript SDK
description: Register development servers with custom names and project paths using Vite or the TypeScript SDK.
order: 4
image: /brand/social.png
---

Automatic discovery needs no plugin. `unplugin-localstack` is optional when you want custom names, URLs, or project metadata.

## Install the repository package

The package is **not published on npm**. Build it from source first. These commands clone the repository beside your current project; use the actual path if you already have a checkout.

```bash
git clone https://github.com/backrunner/localstack.git ../localstack
npm --prefix ../localstack/packages/unplugin-localstack ci
npm --prefix ../localstack/packages/unplugin-localstack run build
npm install --save-dev ../localstack/packages/unplugin-localstack
```

The TypeScript package requires Node.js 20+. Vite integration requires Vite 5+.

## Add to Vite

Add LocalStack to your existing plugins:

```ts
import { defineConfig } from 'vite';
import LocalStack from 'unplugin-localstack/vite';

export default defineConfig({
  plugins: [
    LocalStack({
      name: 'Console',
      projectRoot: process.cwd(),
    }),
  ],
});
```

The plugin reads the server's actual listening port, including a port chosen after a conflict. Registration failures do not stop the development server; the plugin retries when the Coordinator becomes available.

| Option | Purpose |
| --- | --- |
| `name` | Display name in the service list |
| `projectRoot` | Project root directory |
| `url` | Custom loopback HTTP page URL; defaults to `127.0.0.1` and the actual port |
| `coordinatorSocket` | Override the Coordinator's Unix socket path |
| `heartbeatIntervalMs` | Renewal interval; defaults to 15 seconds |
| `quiet` | Suppress plugin warnings |

## Use the SDK directly

For a non-Vite Node.js server, import the lifecycle API. Call `register` after the HTTP server starts listening and its HTML page is reachable:

```ts
import { register, heartbeat, unregister } from 'unplugin-localstack';

const lease = await register({
  port: 3000,
  displayName: 'My dashboard',
  projectRoot: process.cwd(),
});

// Renew periodically while the server is running.
await heartbeat(lease);

// Unregister during normal server shutdown.
await unregister(lease);
```

This shows lifecycle calls, not a complete server. Schedule recurring renewal, handle connection failures, and register again after an expired lease. `pid` defaults to the current Node.js process; pass the listening child's PID explicitly when a child process owns the port.

The default socket is `~/Library/Application Support/LocalStack/coordinator.sock`. Override it with `LOCALSTACK_SOCKET` when needed. All registrations remain subject to independent process, page, and listener validation.
