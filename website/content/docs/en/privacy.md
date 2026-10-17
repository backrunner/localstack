---
title: Privacy and security
description: How LocalStack handles local service data, process actions, update requests, retention, and support.
order: 7
image: /brand/social.png
---

Updated October 18, 2026. This policy covers the LocalStack macOS development-service manager and this website.

## Local data

Discovery is limited to the current macOS user's loopback services. LocalStack does not scan the LAN or upload service names, project paths, ports, page titles, favicons, or page contents. It has no account system, advertising, or embedded behavioral analytics.

The Coordinator probes local HTTP pages and stores service records in `~/Library/Application Support/LocalStack/services.json`, with a private user-owned directory and file. Records can contain local URLs, process identities, project paths, and page metadata. App, CLI, MCP, and SDK clients communicate through the user-owned `coordinator.sock` Unix socket. Tools running as the same macOS user share that trust boundary.

## Process actions

Before stopping a service, LocalStack rechecks PID, user, start time, and port ownership. Normal stops use `SIGTERM`; forcing a stop requires another explicit confirmation in the app. Batch stops validate every distinct process. Closed listeners are removed while remaining live services are retained.

CLI and MCP users explicitly initiate operations through their respective clients. The DMG contains the app and embedded Coordinator, without a Widget extension or bundled CLI.

## Retention and deletion

Local service records are updated as services change. Preferences remain until reset or removed. Downloaded updates are stored in the app cache; obsolete prepared downloads are pruned by the updater.

To remove local data, quit the app and any separately installed Coordinator first. Remove `~/Library/Application Support/LocalStack` and `~/Library/Caches/com.localstack.app/updates` if present, and reset the `com.localstack.app` preferences. This also removes any backups you stored under that application-support directory. Back up anything you want to keep before removing it. Removing data does not stop your development servers or delete their projects.

## GitHub update requests

Signed installations contact GitHub Releases for update metadata and DMG downloads. These requests expose normal HTTP connection information, such as the IP address and request headers, to GitHub and its delivery providers. They do not include your local service registry. See [GitHub's privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).

Installation checks size, SHA-256, Developer ID, signing team, Bundle ID, version, and notarization. You decide when to restart and install. See [Automatic updates](/docs/updates).

## Website

Cloudflare hosts this site and processes ordinary HTTP requests needed to serve it. No third-party behavioral analytics scripts are embedded. Documentation search runs in your browser. Download and source links take you to GitHub. See [Cloudflare's privacy policy](https://www.cloudflare.com/privacypolicy/).

## Support and privacy questions

Use [GitHub Issues](https://github.com/backrunner/localstack/issues) for support and privacy questions. Avoid posting private project paths, tokens, or other sensitive data in public reports. The MIT-licensed [source code](https://github.com/backrunner/localstack) documents the implementation.
