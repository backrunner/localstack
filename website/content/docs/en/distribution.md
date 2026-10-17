---
title: Distribution and App Store status
description: Free downloads, what the DMG includes, and current Mac App Store readiness.
order: 8
image: /brand/social.png
---

LocalStack is free and MIT licensed. Its supported release is a universal, Developer ID-signed and Apple-notarized **GitHub DMG** for macOS 15+. It includes the menu bar app and embedded Coordinator. The Rust CLI and Widget extension are separate source targets.

The stable release continues through GitHub DMG so that automatic discovery and process management remain available. Mac App Store distribution is deferred.

## Mac App Store status

As of October 18, 2026, LocalStack has **not been submitted to or approved for the Mac App Store**. Free pricing is possible, but the current direct-download build is not ready for submission.

- The app is not sandboxed. Automatic inspection of other processes and process-stop actions need an on-device sandbox feasibility study.
- The GitHub updater and self-replacing installer must be excluded from an App Store build.
- A dedicated Xcode archive, distribution signing, provisioning, privacy disclosures, and store materials are still required.
- First-launch login-item registration needs an explicit opt-in flow for a store build.

These are source-review findings, not an Apple rejection. Notarization is a separate direct-distribution security check and does not constitute App Store approval. Read the [dated readiness assessment](https://github.com/backrunner/localstack/blob/main/docs/app-store-readiness.md) for evidence and the proposed store path.

Apple permits free app pricing; Apple Developer Program membership normally costs 99 USD per year or the local equivalent. See [Apple's pricing instructions](https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price/) and [membership details](https://developer.apple.com/programs/whats-included/).

## Support

Installation and usage help is available in [the documentation](/docs). Report problems through [GitHub Issues](https://github.com/backrunner/localstack/issues). See [Privacy and security](/docs/privacy) for local storage and network behavior.
