# 0.2.3 stable readiness review

Reviewed October 18, 2026. The distribution decision is to preserve the complete native feature set in the free, Developer ID-signed and Apple-notarized GitHub DMG. Mac App Store work is deferred.

## Decision and fixes

The review found issues to fix before promoting beta.3. After those fixes, the local functional review supports a 0.2.3 stable release, subject to the CI and signed-release gates below. This is a bounded release assessment, not a claim that the software has no defects.

| Finding | Change and evidence |
| --- | --- |
| Port ownership did not distinguish IPv4 from IPv6 | A native IPv6-only listener was accepted as the owner of an IPv4 URL before probing. The new regression test failed against the old code. Ownership now includes the actual loopback address in registration, discovery, open, health checks, and stop confirmation. Separate processes sharing a numeric port in different families keep separate records |
| `localhost` could reach the other process on the same port | Resolve it to a numeric loopback address served by the claimed PID, preserving path/query/fragment. Kernel IPv4 capability flags preserve IPv6 wildcard dual-stack support; IPv6-only listeners are not treated as IPv4 owners |
| Explicit row-menu Open changed selection in multi-select mode | Route that menu action through the explicit page-open callback. Selection still belongs to the row's selection action |
| Updater task lifetime on completion or rejection was implicit | Explicitly cancel HTTP byte-stream tasks on exit from metadata fetch and image download, matching the bounded page probe's cleanup pattern |
| MCP health checks returned method-not-found | Handle `ping` with an empty JSON-RPC result. A real subprocess stdio test checks initialization, notification suppression, ping, tool listing, malformed input, and unknown methods. CLI version is 0.1.1, derived from Cargo package metadata |

The MCP response follows the [protocol's ping requirements](https://modelcontextprotocol.io/specification/2025-06-18/basic/utilities/ping). The process and endpoint findings are reproduced against local native sockets and owned fixture processes, rather than inferred from port numbers alone.

## Functional evidence

- **Discovery and HTTP:** Swift tests cover real TCP listeners, HTML validation, rejection of non-loopback targets, same-origin redirects and their limit, cancellation, response-size limits, timeouts, rejection backoff, lifetime Surge suppression, and process-bound workerd exclusions.
- **Identity and stopping:** A real IPv4 HTTP server and an independent IPv6-only HTTP server share a port. Both are discovered and opened over the real Unix JSON-RPC client/server. A wrong-family registration is rejected. Stopping the IPv4 server leaves the IPv6 service reachable. Existing tests exercise graceful cleanup, partial listener shutdown, delayed force confirmation, PID reuse, and process deduplication in batch stops. Tests stop only their own fixtures.
- **Registration and storage:** Tests cover registry persistence, startup readiness, duplicate leases, URL updates, source cleanup, and maintaining active-socket ownership. Endpoint keys are computed from stored URLs, so the change does not require a registry schema migration. A process exposing both families on the same port still has one process/port record.
- **SDK and Vite:** Real Unix-socket tests verify registration, heartbeat and unregister credentials. The Vite adapter uses its actual listening port, re-registers after a lost lease, unregisters the current lease, and stops sending requests on close. Node.js 20 and 22 run these tests in CI.
- **CLI and MCP:** Rust unit and subprocess tests verify tool discovery, configuration handling, and stdio protocol behavior. These run in CI alongside the SDK jobs. The CLI remains a separately installed source target.
- **App and updates:** Source review covers list/search, single and batch stops, force confirmation, deep links, settings, backend recovery, and updater cancellation/state handling. Fresh universal app builds verify both architectures and signatures. The release workflow independently validates notarized replacement and relaunch at both supported installation locations while preserving a running HTTP server.
- **Website:** The existing svedocs 0.3.0/SvelteKit 3 site is updated for stable. Checks cover both locales, content/translations, build, desktop/mobile navigation, search, anchors, 404s, SEO/agent endpoints, and current download links. Production checks run after deployment.

Local commands include `swift test` with the repository's Swift environment, `cargo test --locked --manifest-path cli/Cargo.toml`, `npm --prefix packages/unplugin-localstack test`, and `python3 -m unittest discover -s Tests/PackagingTests -v`. Website commands are in `website/package.json`.

## Release acceptance

1. Native tests, packaging failure gates, CLI tests, and SDK/Vite tests must pass, including Node.js 20/22 CI jobs.
2. Website type/content checks, production build, and browser tests must pass.
3. The stable tag is **v0.2.3**, without a prerelease suffix. The signed bundle retains the full version `0.2.3`; the manifest declares `channel: stable`.
4. GitHub Actions must produce and verify a universal, signed, notarized and stapled app and DMG, then pass the actual update replacement/relaunch smoke test.
5. Download the draft's assets independently; verify SHA-256, size, signatures/team/Bundle ID, version/build, both architectures, stapled tickets, and Gatekeeper before publication.
6. Publish as the latest stable GitHub Release, deploy the website, and verify anonymous downloads and live browser behavior. Both Stable and Beta updater channels must select the stable promotion for eligible older beta installations. Channel preferences are preserved.

## Limits and remaining risks

- Local native testing uses the current Apple Silicon Mac. CI uses macOS 26/Xcode 26. Both CPU slices compile, but this review does not establish execution on a physical Intel Mac or a separate macOS 15 machine.
- Automated native tests exercise the backend and real processes; deterministic native previews and source review do not constitute complete interactive GUI automation. The installed menu-bar app's UI is not exposed to the available automation surface in this session.
- Two Swift tests requiring separately supplied notarized artifacts skip during ordinary local runs; the signed-release workflow has its own notarized update installation gate. Passing local tests alone is not sufficient to publish.
- Website dependency audit still reports 15 transitive advisories (4 high, 7 moderate, 4 low), documented in `website/README.md`. The site uses repository-owned content, and no website JavaScript or npm dependencies ship in the native DMG. The website audit is not clean and this does not establish that every advisory is unreachable.
- The GitHub DMG contains the menu-bar app and embedded Coordinator. It does not ship the CLI or Widget extension. No App Store submission, sandbox feature-parity claim, or App Review approval is implied.
