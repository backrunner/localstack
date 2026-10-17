---
title: 下载与安装
description: 在 macOS 上安装 LocalStack，自动发现并打开你的本地开发站点。
order: 1
image: /brand/social.png
---

LocalStack 是一个原生 macOS 菜单栏工具：把正在运行、能够在浏览器中打开的本地开发站点集中到一个面板里。

## 下载 LocalStack

当前公开版本为 **0.2.3**，支持 **macOS 15 或更新版本**。同一个 DMG 包含 Apple Silicon 与 Intel 通用应用。使用应用不需要安装 Xcode、Rust 或 Node.js。

[下载 macOS 通用版 DMG](https://github.com/backrunner/localstack/releases/download/v0.2.3/LocalStack-0.2.3.dmg) · [查看发布记录与校验文件](https://github.com/backrunner/localstack/releases/tag/v0.2.3)

1. 下载并打开 DMG。
2. 将 LocalStack 安装到「应用程序」，然后启动。也可以在 DMG 内双击应用，使用内置安装器。
3. 点击菜单栏里的三层堆叠图标，打开服务面板。
4. 照常启动一个本地开发服务器，例如运行项目自己的 `npm run dev`。

LocalStack 验证页面和进程后，站点会出现在列表里。首次使用不需要为项目添加配置。

当前通过 GitHub DMG 分发，尚无 Mac App Store 版本。详见 [分发与商店状态](/docs/distribution)。

## 接下来

- [认识菜单栏面板](/docs/usage)：搜索、打开、复制地址、停止服务和快捷键。
- [自动发现如何工作](/docs/discovery)：了解哪些服务会进入列表，以及缺失服务的排查方式。
- [接入 Vite 或 TypeScript SDK](/docs/vite)：自定义服务名称与项目路径。
- [使用 CLI 与 MCP](/docs/cli)：把本地服务接入终端、脚本和编程助手。
- [管理自动更新](/docs/updates)：选择 Stable 或 Beta 通道。

## 从源码构建

开发需要 Xcode 26+、Swift 6.2+，构建 CLI 需要 Rust，构建 TypeScript 包需要 Node.js 20+，官网需要 Node.js 22.17+。

```bash
git clone https://github.com/backrunner/localstack.git
cd localstack
Scripts/compile_and_run.sh
```

使用 `make package-app` 构建应用包，或使用 `make package-dmg` 构建磁盘映像。本地临时签名可通过 `SIGN_IDENTITY=-` 指定。完整发布与公证流程见仓库的 [macOS 发布文档](https://github.com/backrunner/localstack/blob/main/docs/macos-release.md)。
