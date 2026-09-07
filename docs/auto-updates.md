# DMG 自动更新与发布通道

LocalStack 使用原生更新器，直接消费同一仓库的 GitHub Releases，并复用已签名、公证的 universal DMG。检查和下载在后台运行；安装由用户点击“重启并更新”开始。

## 版本与通道

| 用户选择 | 可接收的版本 | 默认选择 |
| --- | --- | --- |
| 正式版（`stable`） | 仅 `X.Y.Z`，GitHub Release 必须为正式发布 | 首次安装正式版 |
| Beta（`beta`） | `X.Y.Z-beta.N` 和更新的正式版 | 首次安装 beta |

首次安装时确定的通道和后续显式选择均保存在用户偏好中，不随安装的版本改变。更新到正式版本后，Beta 通道的用户仍继续接收后续 Beta。

更新顺序按完整版本号比较，与 GitHub 发布时间、列表顺序和 Actions 构建号无关：

```text
0.2.3-beta.1 < 0.2.3-beta.2 < 0.2.3-beta.10 < 0.2.3 < 0.2.4-beta.1
```

- 正式版 `0.2.3` 可以更新到 `0.2.4-beta.1`，前提是用户已选择 Beta。
- `0.2.3-beta.10` 可以更新到 `0.2.3` 正式版。
- 从 `0.3.0-beta.1` 切回正式通道时，不安装较旧的 `0.2.3`，而是等待更高的正式版本。
- 相同版本不重复安装。已公开发布的版本不替换资产；修复内容必须使用新版本号。
- 切换通道取消旧请求、清除待安装缓存，并重新检查。旧通道的异步结果不能覆盖新通道状态。

`LocalStackReleaseVersion` 保存完整版本，设置页也显示这个值。`CFBundleShortVersionString` 保留数字版本，`CFBundleVersion` 保留构建号；这两个字段不用于判断 beta/正式版本的前后关系。

## 检查、下载与安装

已安装的签名发行版启动后，在后台按每个通道至多每 24 小时检查一次；失败可在后续轮询重试。手动检查之间至少间隔 60 秒，以避免触发 GitHub 的匿名 API 限流。设置中的“自动下载更新”默认开启，关闭后保留自动检查，仅提示可用更新。

更新器分页读取公开 Releases，排除 draft、不匹配的 prerelease 标记、其他预发布命名和缺少更新清单的版本，再选择当前通道中更高且兼容当前 macOS 的版本。读取设置上限，超出目录范围或遇到限流时明确失败，不把不完整结果当作最新版本。

下载经过大小限制，写入当前用户的私有缓存目录。更新器依次：

1. 校验最终 DMG 的大小和 SHA-256。
2. 校验 DMG 的 Developer ID 证书类型、当前 App 的 Apple Team、签名和公证票据，通过 Gatekeeper 后才只读挂载。
3. 校验 DMG 内 App 的签名、公证、Bundle ID、完整版本、构建号和最低 macOS 版本。
4. 使用 `ditto` 将 App 复制到缓存，重新验证，再卸载 DMG。
5. 保存待安装信息，在设置页显示“重启并更新”。正常退出不会自动安装；再次启动可以恢复待安装状态。
6. 用户确认后，再次验证缓存 App，然后启动其安装入口；新 App 验证源与目标、通道和升级方向，等待旧 App 退出后执行事务式替换，再打开安装位置的新版本。

更新不终止用户启动的开发服务器。文件复制或阶段校验失败时，事务式安装保留原有安装。当前实现沿用已有安装器的当前用户目录权限，不请求提权；权限不足时报告失败。

待安装包在正常退出后保留；其他超过七天的缓存会在启动时清理。清理跳过带有挂载目录的缓存，避免遍历未能卸载的卷。

更新清单与 SHA-256 用于描述和校验下载内容；最终执行许可始终依赖同一 Apple Team 的 Developer ID 签名、公证和签名包内的版本信息。清单不能授权执行未签名、临时签名、其他 Team 或其他 Bundle ID 的 App。

客户端通过系统 `codesign`、`spctl`、`hdiutil` 和 `ditto` 完成检查与复制，要求 Gatekeeper 明确给出 `Notarized Developer ID`。用户的 Mac 不需要安装 Xcode 或 `notarytool`；独立的 `stapler validate` 检查保留在发布 CI 中。

## 发布清单

在 App 和 DMG 的签名、公证、票据及挂载验证全部成功后，管线生成 `LocalStack-update.json`：

```json
{
  "schemaVersion": 1,
  "version": "0.2.3-beta.2",
  "channel": "beta",
  "buildNumber": "2.1",
  "bundleIdentifier": "com.localstack.app",
  "teamIdentifier": "<Apple Team ID>",
  "minimumSystemVersion": "15.0",
  "fileName": "LocalStack-0.2.3-beta.2.dmg",
  "size": 1234567,
  "sha256": "<final DMG SHA-256>"
}
```

每次 Release 一并上传 DMG、`.sha256` 和清单。清单中的哈希在最终票据装订之后计算。GitHub Release 仍先生成草稿；只有正式公开发布后，客户端才能发现它。Beta 标记与 tag 不一致时客户端拒绝该条目。更新资产的 URL 限定为 `backrunner/localstack` 对应 tag 下的精确文件路径。

GitHub 的 `/releases/latest` 不包含 beta，所以客户端不以该端点作为双通道来源；也不创建可覆盖的滚动 beta tag。

## 首次迁移与验证

已经发布的 `0.2.3-beta.1` 没有内置更新器，无法通过服务端清单补上客户端能力。用户需要手动安装一次包含更新器的新版本，后续才可使用应用内更新。不要覆盖已发布的 beta.1。

自动化测试覆盖版本排序、通道隔离、正式版接替 beta、拒绝降级、draft/资产/清单验证、校验和失败和未签名代码拒绝。可用已发布的公证 DMG 验证真实挂载、签名、票据及复制流程：

```sh
LOCALSTACK_UPDATER_TEST_DMG="$PWD/build/releases/v0.2.3-beta.1/LocalStack-0.2.3-beta.1.dmg" \
  swift test --filter publishedDMGStaging
```

Release CI 会额外构建并公证一个仅用于测试的 `0.0.0-beta.1` App，其中包含当前源码的更新器。`Scripts/test_update_installation.sh` 使用它与待发布的真实 DMG，在临时 runner 的 `/Applications` 和 `~/Applications` 中验证签名、替换、旧进程退出、新版本重新启动及 HTTP 服务进程保留。测试不得覆盖已有安装，也不会把测试版本上传到 Release。失败会阻止发布草稿生成。

版本与通道单元测试、事务式安装失败测试和这项真实升级测试共同作为发布检查。下载中切换通道、辅助功能操作和权限提示仍需人工交互回归；CI 的安装交接测试直接调用应用内更新使用的安装入口，不模拟点击设置页按钮。
