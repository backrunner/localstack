# LocalStack 工程蓝图

## 产品定义

LocalStack 是一个仅在本机运行的 macOS 开发服务管理器。它以菜单栏、托盘面板和桌面 Widget 展示当前可在浏览器中打开的本地开发站点，并让用户安全地打开或停止对应进程。

服务只能通过以下两条路径进入列表：

1. **本地探测**：发现当前用户启动且处于监听状态的 TCP 端口，验证其在 loopback 地址上可返回可浏览的 HTML 页面。
2. **主动注册**：开发服务器通过 SDK、首期的 unplugin，或本地 MCP 服务提交 PID、端口和元数据；Coordinator 仍会独立验证该服务与进程，不能绕过校验。

本产品不是通用端口管理器，也不是 API 调试工具。只返回 JSON、纯文本、gRPC、数据库或其他没有可浏览 HTML 页面的端口不出现在默认服务列表中。

## 设计前提

- 平台：macOS；UI 采用 SwiftUI + AppKit 互操作，最低系统版本在工程立项时确定。以 macOS Tahoe 26+ 的 Liquid Glass 为主体验，并为更低版本提供语义等价的系统材质降级。
- 作用域：仅当前登录用户、仅本机 loopback。不会扫描局域网、不会上传端口、标题、favicon 或命令行信息。
- 安全模型：同一 macOS 用户内的本地工具互信，但所有会影响进程的操作都必须在 Coordinator 中重新验证 PID、启动时间、端口归属和用户身份。
- 事实来源：`LocalStackCoordinator` 是服务注册、探测、存活和终止的唯一所有者；App、Widget、SDK 和 MCP 都是它的客户端。

## 文档导航

| 文档 | 用途 |
| --- | --- |
| [architecture.md](architecture.md) | 模块边界、进程拓扑、数据模型、本地 IPC 与 MCP/CLI 设计 |
| [service-lifecycle.md](service-lifecycle.md) | 发现、页面验证、合并、健康检查、注销和终止状态机 |
| [implementation-roadmap.md](implementation-roadmap.md) | 目录结构、阶段性交付、测试矩阵和验收条件 |

## 术语

| 术语 | 含义 |
| --- | --- |
| Candidate | 从监听端口或注册请求得到、尚未验证的候选服务。 |
| Service | 已通过页面和进程验证、可在列表中显示的逻辑服务。 |
| Registration | 一个主动上报来源持有的服务声明；同一 Service 可有多个来源。 |
| Endpoint | 可访问 URL 与监听端口的组合；首期限制为 `localhost`、`127.0.0.1` 或 `::1`。 |
| PID fingerprint | `pid + uid + processStartTime`，用于阻断 PID 复用后误杀其他进程。 |
| Lease | 注册来源持有的短期凭据；用于 heartbeat、更新和注销，避免一个客户端修改另一个客户端的注册。 |

## 非目标

- 不代理、不隧道、不反向代理本地服务。
- 不列出纯 API、数据库、消息队列或仅有 TCP 协议的服务。
- 不以端口号猜测产品名称作为唯一依据。
- 不在无验证、PID 已复用、端口归属不一致时终止进程。
- 不在 Widget 中直接执行无法二次确认的破坏性操作。
