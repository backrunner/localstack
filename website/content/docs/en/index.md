---
title: Download and install
description: Install LocalStack on macOS and discover your local development sites.
order: 1
image: /brand/social.png
---

LocalStack is a free, MIT-licensed macOS menu bar app for local development sites.

## Download LocalStack

The current release is **0.2.3-beta.3**, for **macOS 15 or newer**. The universal DMG supports Apple Silicon and Intel. Xcode, Rust, and Node.js are not required to run the app.

[Download the universal macOS DMG](https://github.com/backrunner/localstack/releases/download/v0.2.3-beta.3/LocalStack-0.2.3-beta.3.dmg) · [Release notes and checksums](https://github.com/backrunner/localstack/releases/tag/v0.2.3-beta.3)

1. Download and open the DMG.
2. Move LocalStack to Applications and launch it, or double-click the app in the DMG to use its installer.
3. Click the stack icon in the menu bar.
4. Start a local development server with your project's usual command, such as `npm run dev`.

After LocalStack verifies its HTML page and process, the site appears in the panel. No project plugin is required.

The DMG is the supported distribution. There is currently **no Mac App Store release**. See [Distribution and App Store status](/docs/distribution).

## Next steps

- [Use the menu bar panel](/docs/usage): search, open, copy URLs, and stop one or several services.
- [Understand discovery](/docs/discovery): validation, exclusions, and troubleshooting.
- [Add Vite or SDK metadata](/docs/vite): customize service names and project paths.
- [Use CLI and MCP](/docs/cli): connect your terminal, scripts, and coding assistants.
- [Manage updates](/docs/updates): choose the Stable or Beta channel.

## Build from source

The app requires Xcode 26+ and Swift 6.2+. The CLI requires Rust; the TypeScript package requires Node.js 20+. The website requires Node.js 22.17+.

```bash
git clone https://github.com/backrunner/localstack.git
cd localstack
Scripts/compile_and_run.sh
```

`make package-app` builds the app and `make package-dmg` builds a disk image. Use `SIGN_IDENTITY=-` for a local ad-hoc build. The default release version is kept in `project.yml`; a release tag supplies the version in CI. See the [macOS release guide](https://github.com/backrunner/localstack/blob/main/docs/macos-release.md) for signing and notarization.
