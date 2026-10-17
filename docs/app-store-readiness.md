# Mac App Store readiness assessment

Reviewed on October 18, 2026 against the current source and Apple's published requirements. This is a technical readiness assessment, not an App Review decision or legal clearance. No App Store Connect upload, pricing change, or submission was performed.

## Decision

**The existing Developer ID DMG is not ready for Mac App Store submission.** It can continue to be distributed free through GitHub. Free App Store pricing is supported, but does not waive sandbox, signing, privacy, or review requirements. Apple Developer Program membership normally costs 99 USD per year or the local equivalent. Sources: [app pricing](https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price/) and [membership](https://developer.apple.com/programs/whats-included/).

The central engineering question is whether LocalStack's useful behavior can be preserved inside App Sandbox. Adding an entitlement alone does not establish this. The current app enumerates other user processes and their sockets, probes local pages, and sends stop signals to those processes. These must be tested in a real sandboxed, signed archive before promising store feature parity.

## Findings and evidence

| Area | Current evidence | Readiness |
| --- | --- | --- |
| Free pricing and business model | MIT license; no account, advertising, subscription, StoreKit payment, or remote service requirement in the app | Compatible with a free product. Free pricing has not been configured in App Store Connect |
| Sandbox | `Resources/LocalStack.entitlements` contains only an App Group. `Scripts/package_app.sh` signs the SwiftPM executable without App Sandbox entitlements | **Submission blocker**. Developer ID and Hardened Runtime are not App Sandbox |
| Process discovery | `ProcessSockets.swift` uses `proc_listpids`, `proc_pidinfo`, and `proc_pidfdinfo`; `ProcessInspector.swift` reads process identity, executable paths, and launch arguments | **Feasibility gate**. Public APIs do not imply sandbox permission to inspect arbitrary peer processes |
| Stopping services | `ProcessInspector.terminate` uses `kill` with `SIGTERM` or `SIGKILL` after fingerprint checks | **Feasibility gate**. Safe identity validation is valuable, but does not grant cross-process signaling rights inside the sandbox |
| Network and IPC | HTTP probes connect to loopback; `UnixJSONRPCServer` binds a user-owned socket under Application Support | Store networking entitlements and container-compatible IPC are unimplemented. Validate CLI/SDK access, socket permissions, IPv4/IPv6, and HTTP behavior in the archive |
| App updates and installation | `AppUpdater.swift`, `AppInstaller.swift`, and `AppBundleInstallation.swift` download GitHub DMGs and replace the app bundle | **Submission blocker**. A store build must exclude this updater and installer, and receive updates through the store |
| Login startup | `AppModel.configureFirstLaunch()` registers the login item on the first installed launch; `Scripts/install_app.sh` also passes `--enable-login` | **Consent gap**. A store build should start with an explicit opt-in action; system approval status alone is not evidence of the user's prior consent |
| Build and signing | `.github/workflows/release.yml` produces a universal Developer ID DMG with notarization; `project.yml` has no store distribution configuration | **Submission blocker**. Need a dedicated sandboxed Xcode archive/export, appropriate distribution signing and provisioning, and upload validation |
| Privacy policy and support | Website has a localized privacy policy and GitHub support links; `SettingsView.swift` has update/startup/shortcut sections but no policy or support link | Add easily accessible in-app policy and support links before store submission |
| Privacy manifests | No `PrivacyInfo.xcprivacy` exists. `AppUpdater.swift` uses `UserDefaults` and cached-file modification dates; IPC uses `lstat` | Audit required-reason API coverage and declare applicable approved reasons in the final bundle; validate the actual archive and privacy report |
| Privacy labels | Source review found no analytics/account SDK or upload of the local registry; update downloads contact GitHub | Reconcile final SDK inventory, network behavior, policy, and App Store Connect privacy answers. No label was submitted or certified |
| Shipped features | SwiftPM packaging includes one app with its embedded Coordinator; it does not bundle the CLI or Widget extension | Document the actual DMG contents. A store version needs its own accurate feature list and screenshots |
| Metadata and beta status | Public versions are beta releases; store materials, age rating, review notes, and a store product record are not present in this repository | Prepare a final store release and real app screenshots. Do not submit a beta-labelled direct-download package as a finished store app |
| Name and rights | README/website already distinguish this project from the unrelated LocalStack cloud emulator | Verify store name availability and naming/asset rights before submission. MIT licensing of this repository does not grant third-party trademark rights |
| Account and territories | No account agreements, membership state, trader status, or regional eligibility were inspected | Account Holder must verify agreements, contact details, and territory-specific requirements. No assumption of account readiness |

Apple's [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) cover sandbox and store-only updating in 2.4.5, startup consent in 2.4.5(iii), finished app submissions in 2.1–2.2, accurate metadata in 2.3, support in 1.5, privacy policy access in 5.1.1, and intellectual property in 5.2. These requirements make the current bundle unsuitable for submission. Sandbox compatibility of this particular app remains an engineering inference to be resolved by testing, rather than a claimed Apple prohibition on all developer tools. See also [App Sandbox](https://developer.apple.com/documentation/security/app-sandbox), [required-reason API declarations](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), and [app privacy details](https://developer.apple.com/app-store/app-privacy-details/).

## Proposed route to a free store release

1. **Prove a useful sandboxed product.** Create a separate store configuration and test discovery, local HTTP requests, process metadata, stop actions, and IPC against real servers owned by the user. Include another process reusing a port/PID and denied-access cases. Record the sandbox entitlements, device/OS, logs, and resulting feature behavior.
2. **Choose the store feature set from that evidence.** If broad discovery or cross-process stopping cannot work, evaluate explicit registration and cooperative server shutdown. Describe any reduction honestly. Do not assume an external unsandboxed helper or temporary entitlement will be approved, or silently require a separate download to supply advertised core features.
3. **Separate distribution paths at build time.** Exclude GitHub update/download/install UI and code from the store archive, use store-managed updates, move data/IPC into supported containers, and retain the complete DMG feature set in the direct channel.
4. **Finish product and privacy details.** Make startup opt-in; add in-app privacy/support links, applicable privacy manifests, retention/deletion information, and accurate disclosures. Verify keyboard access, VoiceOver, both appearances, minimum/current macOS, and all advertised features in the actual store artifact.
5. **Prepare the submission.** Use a final numeric store version, the correct Bundle ID/capabilities, production signing/provisioning, real screenshots, category, age rating, support/privacy URLs, and detailed reviewer instructions that work without a preconfigured developer workspace. Confirm naming rights and account/territory obligations. Set the price to Free when the product is ready.
6. **Validate and submit.** Validate/upload the archive, resolve processing feedback, and use TestFlight where appropriate. Only an actual App Review approval establishes store availability.

## What this release establishes

`0.2.3-beta.3` remains the free GitHub direct-download channel. Its website documents compact service rows, batch stopping, lifetime Surge exclusion, internal workerd filtering, the separate CLI/Widget targets, and this readiness status. The website uses svedocs 0.3.0 with SvelteKit 3. It does not present an App Store badge or claim approval.

Release acceptance requires the Swift and packaging tests, universal app/DMG signing, Apple notarization and stapled tickets, Gatekeeper checks, update-manifest/checksum verification, and the existing real update-install smoke test in GitHub Actions. Website acceptance requires type/content checks, production build, browser checks for both locales and mobile navigation, and live endpoint checks after deployment. Passing these checks does not resolve the store blockers above.
