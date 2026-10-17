---
title: Automatic updates
description: Choose Stable or Beta updates and understand download verification and user-confirmed installation.
order: 6
image: /brand/social.png
---

Since **0.2.3-beta.2**, the signed GitHub distribution includes a native updater. Installed signed apps check releases from the same GitHub repository. This is the direct-download updater; there is currently no App Store distribution.

## Choose a channel

| Channel | Eligible releases |
| --- | --- |
| Stable | Newer stable releases |
| Beta | Newer betas and newer stable releases |

A first beta installation selects Beta. Settings preserve your selection across subsequent installations. Switching channels never downgrades: switching from a newer beta to Stable waits for an eligible newer stable version. GitHub draft releases are excluded.

## Check and install

1. Automatic checks run at most once per 24 hours for each channel. Manual checks are also available.
2. Automatic download is on by default. Turning it off preserves checks and notifications.
3. The updater verifies package size, SHA-256, Developer ID signature, signing team, Bundle ID, version, and notarization.
4. The app replaces itself and relaunches only after you click **Restart and update**.

Quitting normally does not install updates. Updating LocalStack does not stop your development servers.

## Migrate from beta.1

`0.2.3-beta.1` has no updater. [Download and install](/docs) the current version once to enable future in-app updates.

## If an update fails

Check GitHub connectivity and write access to the installation directory. Wait if GitHub rate-limits requests; manual checks are at least 60 seconds apart. Do not bypass signature or checksum failures. Report problems through [GitHub Issues](https://github.com/backrunner/localstack/issues).

Developers can read the repository's [updater implementation guide](https://github.com/backrunner/localstack/blob/main/docs/auto-updates.md).
