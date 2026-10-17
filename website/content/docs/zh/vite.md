---
title: Vite 与 TypeScript SDK
description: 将开发服务器注册到 LocalStack，自定义名称和项目路径，并了解 SDK 的租约生命周期。
order: 4
image: /brand/social.png
---

自动发现不需要插件。`unplugin-localstack` 为需要自定义名称、URL 或项目路径的开发服务器提供可选集成。

## 安装仓库内的包

该包目前尚未发布到 npm，需要先从源码构建。以下命令将仓库放在当前项目的同级目录；如果已经克隆，请使用实际路径。

```bash
git clone https://github.com/backrunner/localstack.git ../localstack
npm --prefix ../localstack/packages/unplugin-localstack ci
npm --prefix ../localstack/packages/unplugin-localstack run build
npm install --save-dev ../localstack/packages/unplugin-localstack
```

TypeScript 包需要 Node.js 20+，Vite 集成要求 Vite 5+。

## 接入 Vite

在现有插件列表中加入 LocalStack：

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

插件读取服务器实际监听的端口，所以 Vite 自动切换端口后仍可正确注册。注册失败不会阻止开发服务器启动；Coordinator 恢复后插件会重试。

| 配置 | 用途 |
| --- | --- |
| `name` | 在列表中显示的名称 |
| `projectRoot` | 项目根目录 |
| `url` | 自定义本地 HTTP 页面 URL；默认使用 `127.0.0.1` 和实际端口 |
| `coordinatorSocket` | 覆盖默认 Unix socket 路径 |
| `heartbeatIntervalMs` | 自定义 heartbeat 间隔；默认 15 秒 |
| `quiet` | 隐藏插件警告 |

## 直接使用 SDK

在非 Vite 的 Node.js 开发服务器中，可以直接导入 SDK。在 HTTP 服务器开始监听、HTML 页面可访问之后调用 `register`：

```ts
import { register, heartbeat, unregister } from 'unplugin-localstack';

const lease = await register({
  port: 3000,
  displayName: 'My dashboard',
  projectRoot: process.cwd(),
});

// 在服务运行期间定期续约。
await heartbeat(lease);

// 在服务正常关闭时注销。
await unregister(lease);
```

这是生命周期调用示例，不是完整的服务器实现。直接使用 SDK 时需要自行安排周期续约，并处理连接失败和租约失效后的重新注册。`pid` 默认为当前 Node.js 进程；如果监听者是子进程，请显式传入监听进程的 PID。

默认 socket 为 `~/Library/Application Support/LocalStack/coordinator.sock`。也可以通过 `LOCALSTACK_SOCKET` 环境变量覆盖。
