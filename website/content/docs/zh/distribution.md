---
title: 分发与商店状态
description: 免费下载、DMG 包含的功能，以及当前 Mac App Store 上架准备情况。
order: 8
image: /brand/social.png
---

LocalStack 免费、采用 MIT 许可证。当前通过 **GitHub DMG** 分发，支持 macOS 15+、Apple Silicon 与 Intel，使用 Developer ID 签名与 Apple 公证。安装包包含菜单栏应用及内嵌 Coordinator；Rust CLI 和 Widget 扩展是独立源码目标。

## Mac App Store 状态

截至 2026 年 10 月 18 日，LocalStack **尚未提交或通过 Mac App Store 审核**。可以选择免费定价，但当前直接下载构建尚不满足提交条件。

- 应用尚未沙盒化；跨进程自动发现和停止操作需要在真实沙盒构建中验证可行性。
- 商店构建需要排除 GitHub 更新器和自行替换应用的安装器。
- 需要独立 Xcode 归档、商店分发签名、描述文件、隐私申报与商店材料。
- 商店构建需要将首次登录项注册改为明确的用户主动选择。

这些是代码审查发现，并非 Apple 拒审结论。公证是直接分发的安全检查，不代表 App Store 审核通过。证据及商店版本路线见仓库的 [上架准备评估](https://github.com/backrunner/localstack/blob/main/docs/app-store-readiness.md)。

Apple 允许免费定价；Apple Developer Program 通常仍需每年 99 美元或当地等值会员费。参阅 [定价说明](https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price/) 和 [会员说明](https://developer.apple.com/programs/whats-included/)。

## 获取帮助

安装与使用说明见 [文档](/docs)，问题可提交至 [GitHub Issues](https://github.com/backrunner/localstack/issues)。数据处理方式见 [隐私与安全](/docs/privacy)。
