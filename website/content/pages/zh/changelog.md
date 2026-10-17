---
title: 版本更新
description: 查看 LocalStack 的公开 Beta 版本和安装更新说明。
image: /brand/social.png
---

LocalStack 0.2.3 是首个正式版本。完整发布内容、DMG 与校验文件以 [GitHub Releases](https://github.com/backrunner/localstack/releases) 为准。

## 0.2.3

2026 年 10 月 18 日 · 正式版

首个正式版本保留完整、免费的 GitHub DMG 体验：原生菜单栏、HTML 页面验证、紧凑列表、批量停止和签名自动更新。

- 按实际监听地址、PID 和端口验证归属；IPv4 与 IPv6 不同进程共用端口时分别保留，停止其中一个不影响另一个
- 将 `localhost` 固定到声明进程实际监听的回环地址，支持 IPv6-only 和双栈监听
- 修正多选模式下服务菜单的「打开页面」动作
- 更新器在下载完成、取消或拒绝响应后显式释放 HTTP 任务
- 补齐 MCP `ping`，实测 stdio 握手、错误响应和工具列表；CLI 更新至 0.1.1
- 新增真实 Unix socket 的 SDK 生命周期和 Vite lease 恢复测试，并在 CI 检查 CLI 与 Node.js 20/22

继续使用 Developer ID 签名、Apple 公证的 GitHub DMG 分发；独立 CLI 与 Widget 扩展仍是源码目标。验证证据与限制见 [稳定性评审](https://github.com/backrunner/localstack/blob/main/docs/stable-readiness.md)。

[下载正式版](https://github.com/backrunner/localstack/releases/download/v0.2.3/LocalStack-0.2.3.dmg) · [完整发布记录](https://github.com/backrunner/localstack/releases/tag/v0.2.3)

## 0.2.3-beta.3

2026 年 10 月 18 日 · Beta

- 服务紧凑单行展示，一屏最多 8 行，长列表提供滚动边缘渐隐
- 每行直接停止，支持多选批量停止并按进程确认
- 强制重试再次验证进程身份，处理部分端口关闭，避免旧同步数据让已停止服务重新出现
- Surge 在同一进程存活期间不再反复探测；根据实时进程与端口信息排除 Wrangler/workerd 内部端点
- 官网升级至 svedocs 0.3.0 与 SvelteKit 3，补齐中英文说明、分发边界与 App Store 上架评估

DMG 包含菜单栏应用与内嵌 Coordinator，CLI 与 Widget 为独立源码目标。

[下载此版本](https://github.com/backrunner/localstack/releases/download/v0.2.3-beta.3/LocalStack-0.2.3-beta.3.dmg) · [完整发布记录](https://github.com/backrunner/localstack/releases/tag/v0.2.3-beta.3)

## 0.2.3-beta.2

2026 年 9 月 7 日 · Beta

- 加入原生自动更新器，通过 GitHub Releases 检查和下载更新。
- 支持 Stable 与 Beta 通道，按版本号选择更新并拒绝降级。
- 安装前验证 DMG 大小、校验和、Developer ID 签名与公证。
- 下载完成后，由用户确认「重启并更新」。

[下载此版本](https://github.com/backrunner/localstack/releases/download/v0.2.3-beta.2/LocalStack-0.2.3-beta.2.dmg) · [完整发布记录](https://github.com/backrunner/localstack/releases/tag/v0.2.3-beta.2)

## 0.2.3-beta.1

2026 年 9 月 7 日 · Beta

公开的签名、公证 macOS 通用应用发行版，提供原生菜单栏、本地站点发现与管理。该版本未包含自动更新器，需要手动安装新版本完成首次迁移。

[发布记录](https://github.com/backrunner/localstack/releases/tag/v0.2.3-beta.1) · [自动更新指南](/docs/updates)
