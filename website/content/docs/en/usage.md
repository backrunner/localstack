---
title: Menu bar and daily use
description: Search, open, copy, and safely stop local sites from the native macOS menu bar.
order: 2
image: /brand/social.png
---

Click the LocalStack menu bar icon to see verified, active services. Each service occupies one compact row. Automatic discovery and explicit registrations share the same list, without separate source badges. Up to eight rows are visible; longer lists scroll with edge fades.

## Find and open a site

Search by name, URL, port, or project path. Use a row's open action to launch the verified URL in your default browser. Its other actions let you copy the URL and inspect details.

| Shortcut | Action |
| --- | --- |
| `⌘ F` | Focus search |
| `⌘ R` | Refresh services |
| `Return` | Open the selected service or first search result |
| `Delete` | Request confirmation to stop the selected service |

Shortcuts apply while the LocalStack panel has focus.

## Stop one or several services

The stop button is available directly in each row. Use selection mode to select several services and request a batch stop. The confirmation identifies the affected services and processes. Services belonging to the same process are stopped together.

Before signaling a process, the Coordinator checks its PID, user, start time, and owned ports again. Normal stops use `SIGTERM`. A process that keeps listening can be force-stopped only after another explicit confirmation. A delayed confirmation never authorizes signaling a replacement process that reused the PID.

Closed listeners disappear from the panel even while their process is finishing cleanup. A partial failure leaves still-running services available and reports the failure.

## Native appearance

The app uses SwiftUI and AppKit, follows macOS light and dark appearances, and supports Liquid Glass on macOS 26 with system materials on macOS 15.

The GitHub DMG includes the menu bar app and its embedded Coordinator. It **does not include the standalone CLI or Widget extension**. WidgetKit code exists as a separate Xcode target, but is not a feature of the downloadable DMG. The app supports `localstack://` service deep links.

## Settings and updates

Settings contain login-at-startup and update controls. macOS may require approval for a login item. Signed installations check GitHub Releases for updates; installation requires clicking **Restart and update**. See [Automatic updates](/docs/updates).
