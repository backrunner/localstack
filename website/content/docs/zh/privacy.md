---
title: 隐私与安全
description: LocalStack 的本地数据、进程操作、更新请求、保留与删除方式及支持渠道。
order: 7
image: /brand/social.png
---

更新于 2026 年 10 月 18 日，适用于 LocalStack macOS 开发服务管理工具及本官网。

## 本地数据

服务发现仅限当前 macOS 用户的 loopback 服务，不扫描局域网，不上传服务名称、项目路径、端口、页面标题、favicon 或页面内容。应用没有账户系统、广告或嵌入式行为分析。

Coordinator 会请求本地 HTTP 页面，并将服务记录保存在 `~/Library/Application Support/LocalStack/services.json`，目录和文件仅供当前用户访问。记录可能包含本地 URL、进程身份、项目路径及页面元数据。App、CLI、MCP 和 SDK 通过用户拥有的 `coordinator.sock` Unix socket 通信；同一 macOS 用户下的工具共享此信任边界。

## 进程操作

停止前会重新验证 PID、用户、启动时间和端口归属。常规停止使用 `SIGTERM`；应用中的强制停止需要单独确认。批量停止会逐一验证各个独立进程，及时移除已关闭端口，保留仍在监听的服务。

CLI 和 MCP 由各自客户端明确发起操作。DMG 只包含应用与内嵌 Coordinator，不包含 Widget 扩展或独立 CLI。

## 数据保留与删除

本地服务记录随服务状态更新，偏好设置会保留至重置或删除。下载的更新保存在应用缓存中，更新器会清理过期的准备文件。

删除本地数据前，先退出应用和另行安装的独立 Coordinator，再按需移除 `~/Library/Application Support/LocalStack`、`~/Library/Caches/com.localstack.app/updates`，并重置 `com.localstack.app` 偏好设置。应用支持目录可能包含自行保存的备份，删除前请保留需要的文件。此操作不会停止开发服务器，也不会删除项目。

## GitHub 更新请求

签名安装版本会请求 GitHub Releases 元数据并下载 DMG。GitHub 及其分发服务会收到正常 HTTP 连接信息，例如 IP 地址和请求头；请求不包含本地服务清单。详见 [GitHub 隐私声明](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement)。

安装前验证包大小、SHA-256、Developer ID、签名团队、Bundle ID、版本及公证。重启安装由你确认，详见 [自动更新](/docs/updates)。

## 官网

官网由 Cloudflare 托管，需要处理正常的网站 HTTP 请求。未嵌入第三方行为分析脚本；文档搜索在浏览器本地完成。下载与源代码链接会前往 GitHub。详见 [Cloudflare 隐私政策](https://www.cloudflare.com/privacypolicy/)。

## 支持与隐私问题

通过 [GitHub Issues](https://github.com/backrunner/localstack/issues) 提交使用或隐私问题。公开报告中请勿包含私人项目路径、令牌或其他敏感数据。具体实现可查看 MIT 许可的 [源代码](https://github.com/backrunner/localstack)。
