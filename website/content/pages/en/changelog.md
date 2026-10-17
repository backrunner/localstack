---
title: Changelog
description: Public LocalStack releases and update notes.
image: /brand/social.png
---

LocalStack is currently in beta. Downloadable assets and the complete release history are published on [GitHub Releases](https://github.com/backrunner/localstack/releases).

## 0.2.3-beta.3

October 18, 2026 · Beta

- Compact single-line service rows, up to eight visible rows, and scroll-edge fades.
- Direct row stop actions and multi-select batch stopping with per-process confirmation.
- Revalidate process identity on force retries, handle partial listener shutdowns, and prevent stopped rows returning from stale synchronization.
- Suppress Surge probes for the identified process lifetime and filter internal Wrangler/workerd endpoints using live process and listener metadata.
- Publish complete Chinese and English documentation with svedocs 0.3.0 and SvelteKit 3, including distribution and App Store readiness details.

The DMG contains the menu bar app and embedded Coordinator; CLI and Widget targets remain separate.

[Download this release](https://github.com/backrunner/localstack/releases/download/v0.2.3-beta.3/LocalStack-0.2.3-beta.3.dmg) · [Release notes](https://github.com/backrunner/localstack/releases/tag/v0.2.3-beta.3)

## 0.2.3-beta.2

September 7, 2026 · Beta

- Added the native updater with GitHub Releases checks and downloads.
- Added Stable and Beta channels with version-aware upgrade selection.
- Verify DMG size, checksum, Developer ID signature, and notarization before install.
- Restart and install only after explicit user confirmation.

[Download this release](https://github.com/backrunner/localstack/releases/download/v0.2.3-beta.2/LocalStack-0.2.3-beta.2.dmg) · [Release notes](https://github.com/backrunner/localstack/releases/tag/v0.2.3-beta.2)

## 0.2.3-beta.1

September 7, 2026 · Beta

The first signed and notarized universal macOS app release with native menu bar discovery and local service management.
