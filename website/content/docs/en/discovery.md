---
title: Discovery and page verification
description: Learn which local HTML services are discovered, which endpoints are excluded, and how to troubleshoot missing sites.
order: 3
image: /brand/social.png
---

LocalStack lists local development pages that you can open in a browser. Both discovery and explicit registration go through independent Coordinator validation.

## Automatic discovery

1. Read TCP listeners belonging to the current macOS user.
2. Probe candidate HTTP pages through loopback addresses.
3. Verify that the response is browsable HTML and that the process owns the listener.
4. Merge verified services into the registry and monitor their health.

The discovery code reads process and socket metadata directly; it does not launch `lsof` for every port. An HTTP server that returns HTML can be discovered regardless of framework. JSON-only APIs, databases, and other TCP services stay out of the list.

## IPv4 and IPv6 ownership

The Coordinator verifies the listening address, not just the port number. Separate IPv4 and IPv6 processes can share a port and appear as separate services. A `localhost` registration is pinned to a numeric loopback address actually served by the claimed process, preserving its path and query. Servers that restrict the HTTP Host header must allow that loopback address.

## Quiet exclusions

When the executable is identified as **Surge**, automatic page probes and health checks remain suppressed for that exact process lifetime. Suppression is tied to PID, user, and process start time. It survives a temporary listener disappearance and ends when that process exits; a new owner of the port is evaluated normally.

Wrangler/workerd internal development endpoints are filtered using their current process arguments and listener identity. This does not exclude every service simply because it uses workerd. A restarted process or a changed port owner is checked again.

## Explicit registration

The [Vite plugin and SDK](/docs/vite), [CLI, and MCP](/docs/cli) can submit a PID, port, name, and project path. Registration never bypasses page or process validation.

SDK registrations use expiring leases. The Vite plugin renews them, retries after Coordinator restarts, and attempts to unregister on server shutdown.

## Why is a site missing?

- Open the local HTTP URL in your browser and verify that startup has finished.
- Verify that it returns HTML, rather than only JSON or another protocol.
- Check that the server runs as the current macOS user.
- Use a loopback URL: `http://localhost`, `http://127.0.0.1`, or `http://[::1]`. LAN and remote URLs are excluded; HTTPS registration is unsupported.
- Check whether the endpoint belongs to Surge or an internal workerd listener.
- Start the LocalStack app. If the CLI is installed, `localstack status` checks Coordinator connectivity.

Use `⌘ R` in the panel to refresh. For custom names or non-root paths, use the [Vite integration](/docs/vite).
