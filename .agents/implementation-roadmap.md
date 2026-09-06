# 实现路线图与验收标准

## 建议目录结构

```text
LocalStack/
  LocalStack.xcodeproj
  Packages/
    LocalStackShared/             # DTO、schema、错误码、URL/PID 值类型
    LocalStackCoordinatorKit/     # registry、scheduler、IPC server
    LocalStackDiscoveryKit/       # socket 枚举、ProcessInspector、PageProbe
    LocalStackClientKit/          # App/SDK 的 IPC client
  Apps/
    LocalStackApp/                # SwiftUI 菜单栏 app、TrayPanel、Settings
    LocalStackCoordinator/        # SMAppService LaunchAgent entrypoint
    LocalStackWidget/             # WidgetKit extension + App Intents
  Tests/
    SharedTests/
    CoordinatorTests/
    DiscoveryTests/
    UITests/
  cli/
    Cargo.toml
    crates/
      localstack-cli/             # clap commands、agent config adapters
      localstack-mcp/             # stdio MCP tools、Coordinator client
      localstack-protocol/        # Rust DTO/schema compatibility
  packages/
    unplugin-localstack/          # TypeScript unplugin，Vite first
  .agents/
```

API schema 使用一份版本化 JSON Schema（例如 `protocol/v1/*.json`）作为 Swift DTO、Rust DTO、TypeScript client 的兼容性契约。三种语言分别生成或手写小型类型层都可以，但协议 fixture 必须共用，不能靠文档复制字段。

## 交付阶段

### Phase 0：工程契约与可验证基座

目标：在 UI 开发前锁定协议、身份和可测环境。

- 建立 Swift Package/Xcode workspace、Rust workspace、TypeScript package 和统一格式化/CI 入口。
- 定义 `v1` JSON Schema、错误码、服务快照和 PID fingerprint 的序列化格式。
- 实现 Coordinator 启动、私有 socket 创建、当前用户私有目录权限校验和版本化 JSON 注册表。
- 建立可注入的 `Clock`、`ProcessInspector`、`PortDiscovery`、`HTTPTransport`，测试不依赖开发机真实端口。
- 定义 fixture：HTML SPA、无 title HTML、JSON API、慢响应、外部重定向、PID 复用、端口易主。

验收：Swift/Rust 对同一注册/list fixture 互通；socket 拒绝非当前用户或不兼容协议；Coordinator 重启后不会信任未经重新验证的记录。

### Phase 1：发现、验证与安全注册表

目标：得到可靠的、只含可打开页面的服务列表。

- 实现当前用户 TCP 监听端口枚举、loopback 规范化和 10 秒 diff 排程。
- 实现受限 HTML probe：2xx、HTML、同源 loopback 重定向、512 KiB、超时、favicon/title 提取。
- 实现原子 JSON `ServiceRecord`、来源合并、generation 防竞争和 Widget 安全快照导出。
- 实现主动注册、lease heartbeat、注销和恢复时的 PID/socket/page 三重验证。
- 实现三段健康检查、Degraded grace、自动注销及本地审计。

验收：

- Vite/Next 静态 HTML dev server 被发现并显示；纯 JSON server 永不显示。
- 相同端口的 `localhost`/`127.0.0.1` 只有一条记录。
- 修改 PID 或让另一个进程复用端口后，旧服务在下一轻检查中消失。
- 页面热重启短暂失败不闪烁；连续三次不可达后从 App Group snapshot 移除。

### Phase 2：菜单栏体验与 Widget

目标：让服务列表成为日常开发中无需思考的入口。

- 构建菜单栏图标、可固定的托盘面板、服务列表、搜索、刷新、详情与空态。
- 实现打开前再验证和默认浏览器打开；打开失败有明确、非阻塞反馈。
- 实现 `prepareTermination`、原生二次确认、`SIGTERM` 等待与可选二次强制停止流。
- 构建 Small/Medium Widget，使用最小安全快照和 App Intent 深链。
- 完成 Liquid Glass 分层、浅/深色、降低透明度、对比度、VoiceOver 和键盘操作。

验收：

- 默认单击、Enter 和 Widget 点击都能打开同一服务；失活服务不会被打开。
- Delete 永远先打开确认；取消不产生 signal；确认时 PID 已复用则什么也不杀。
- Widget 不包含 PID/路径/lease，停止入口不会后台结束进程。
- 在 macOS Tahoe 26+ 使用系统 Liquid Glass；目标系统较低时视觉层级和操作语义一致。

### Phase 3：unplugin 与 SDK 首发集成

目标：让前端项目在开发服务器启动时稳妥地注册自身。

- 开发 `unplugin-localstack` Vite adapter，监听实际 `listening` 端口，注册、heartbeat、close 注销。
- 添加 webpack、Rspack、Rollup、esbuild adapter 的契约测试，按实际生命周期逐个启用。
- 提供少量 SDK API：`register`、`heartbeat`、`unregister`；客户端不可用时 fail-open。
- 输出清晰诊断，区分未安装 App、Coordinator 未运行、端口不匹配、页面非 HTML 和权限问题。

验收：插件不会改变 dev server 监听行为、退出码或 HMR；Coordinator 无法连接时项目仍正常启动；页面仍必须通过 Coordinator probe 才出现。

### Phase 4：Rust CLI 与 MCP

目标：agent 能安全地管理真实本地开发服务。

- 实现 `localstack mcp serve`、`status`、`doctor` 和版本协商。
- 实现三个 MCP 工具并复用 `localstack-protocol` 客户端，不绕过 socket。
- 为 Codex、Claude Code、Cursor 等分别实现 MCP config adapter；支持 `install`、`uninstall`、`--target auto`、备份和幂等更新。
- 增加错误到 MCP response 的稳定映射，避免把 socket 路径、token 或 HTML 内容泄露给 agent。

验收：从全新 agent 配置安装后可列出服务；注册 JSON API 端口返回结构化拒绝；终止只接受精确 service ID 并经同一 PID 重验证；坏配置文件不会被覆盖。

### Phase 5：发布质量与运行维护

目标：把“本地工具”做成可靠的长期后台组件。

- 对 Coordinator migration、LaunchAgent 更新/卸载、socket 遗留文件、App 升级进行恢复测试。
- 加入性能采样：扫描、probe、注册表、内存、Widget snapshot；为端口数、并发数、图标缓存设置硬上限。
- 添加日志导出与一键清除本地诊断；审查隐私清单和网络权限说明。
- 完成 notarization、签名、Sparkle/受控更新（若采用）、崩溃报告的显式同意流程。

验收：100 个监听端口下扫描不会明显阻塞 UI；Coordinator 异常重启后不留下假服务；退出/升级不会误终止用户开发进程。

## 测试矩阵

| 层级 | 关注点 | 示例 |
| --- | --- | --- |
| 单元测试 | 规范化、合并、状态机、错误映射 | `localhost`/IPv6、lease 到期、generation 过期回调 |
| 集成测试 | Coordinator + 临时 HTTP server + 原子 JSON 注册表 | HTML 通过、JSON 拒绝、重定向拒绝、端口易主 |
| 进程安全测试 | fingerprint 与 signal 护栏 | 已退出 PID、PID 重用、非当前 UID、Coordinator 自身 |
| 协议契约测试 | Swift/Rust/TS 请求响应 | v1 fixture、未知字段、主版本不兼容 |
| UI 测试 | 打开、确认、键盘、空态 | Cancel 不 kill、Degraded 提示、VoiceOver label |
| Widget 测试 | Snapshot 最小化、深链 | 不暴露 PID，点击转入正确 App 流程 |
| 性能/稳定性 | 端口规模、重启、泄漏 | 100 端口、并发 4、连续 24 小时探活 |

## 关键技术决策记录

| 决策 | 理由 | 后果 |
| --- | --- | --- |
| Coordinator 是独立 LaunchAgent | App/Widget/MCP 生命周期不同，需要唯一事实源 | 需要安装、升级、恢复和签名方案 |
| 只枚举实际监听 socket | 不扫描全端口，能关联 PID，资源可控 | 受系统权限限制时跳过不可见进程 |
| HTML 2xx 是显示门槛 | 服务列表保持“点开即可用”的承诺 | 纯 API 不会被列出，这是产品刻意取舍 |
| PID fingerprint 而非 PID | 阻断 PID 复用导致误杀 | 需使用 macOS 进程启动时间 API |
| MCP 经 CLI/Coordinator 转发 | Rust 工具和 Swift registry 不产生双写 | MCP 依赖 App/Coordinator 运行 |
| Widget 只读快照 + 深链 | 避免扩展持有敏感进程控制能力 | Widget 的停止操作多一次 App 跳转 |

## 上线前阻断项

以下任一项未满足，不应发布带终止能力的版本：

1. 终止前无法验证 `pid + uid + startTime + port ownership`。
2. 验证器会把 JSON、错误页面或外部重定向列为可打开服务。
3. 应用/Coordinator 重启后持久化服务可跳过重新验证。
4. Widget 或 MCP 能在没有精确服务标识和服务端重验证时结束进程。
5. CLI installer 会覆写未知或损坏的 agent 配置。
6. 浅色/深色、降低透明度、提高对比度和 VoiceOver 未通过人工验证。
