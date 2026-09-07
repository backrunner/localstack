# macOS DMG release

The release pipeline follows AIPass's Developer ID and Apple notarization setup.
It builds a universal SwiftPM app (`arm64` + `x86_64`), signs it with Hardened
Runtime and a secure timestamp, submits a ZIP of the app to Apple, and staples
the accepted ticket to the app **before** creating the DMG. It then signs,
notarizes, and staples the DMG separately. Both tickets travel with the download
for offline Gatekeeper verification, including after copying the app out of the DMG.

The current SwiftPM package contains the menu bar app with its in-process
Coordinator. It does not bundle the standalone CLI or the Xcode Widget extension.
This distribution does not require App Group entitlements or a provisioning
profile. The Xcode Widget targets retain their separate entitlement setup.

## GitHub Actions setup

Configure these repository secrets under **Settings → Secrets and variables →
Actions**. The names match `aipass`; secrets in that repository are not inherited.

| Secret | Value |
| --- | --- |
| `APPLE_CERTIFICATE` | Base64 of the exported **Developer ID Application** certificate and private key (`.p12`) |
| `APPLE_CERTIFICATE_PASSWORD` | Password protecting the `.p12` |
| `APPLE_SIGNING_IDENTITY` | Full identity, e.g. `Developer ID Application: Your Name (ABCDEFGHIJ)` |
| `APPLE_TEAM_ID` | Apple Developer Team ID, checked against both signatures |
| `APPLE_ID` | Apple ID used for notarization |
| `APPLE_PASSWORD` | App-specific password for that Apple ID |

`CSC_LINK` and `CSC_KEY_PASSWORD` are accepted as fallbacks for the first two
secrets. `CSC_LINK` must contain base64 `.p12` data, not a URL or local path.

Notarization uses `APPLE_ID` and `APPLE_PASSWORD`, together with the signing
team's `APPLE_TEAM_ID`. Generate the app-specific password at
[account.apple.com](https://account.apple.com/) under **Sign-In and Security →
App-Specific Passwords**; use it instead of the account login password.
These secret references are ready to fill in before running the release workflow.
Incomplete credentials fail before compilation. Signing uses the temporary
keychain managed and cleaned up by `apple-actions/import-codesign-certs`.
No private keys enter artifacts.

Push a tag such as `v0.2.3` or `v0.2.3-beta.1`, or dispatch **Release DMG** with an
existing tag. The tag supplies the version; the Actions run number and attempt
supply the build number. Prereleases use the numeric base version in Apple's
`CFBundleShortVersionString`, with the complete version retained in
`LocalStackReleaseVersion` and the DMG filename.

The workflow creates an Actions artifact and a **draft GitHub Release** containing
`LocalStack-<version>.dmg`, its `.sha256` checksum, and `LocalStack-update.json`.
The update manifest describes the final notarized image and signed bundle version.
Prerelease tags are marked
as prereleases. Review the draft and publish it in GitHub when ready. Reruns may
replace draft assets; published releases are never overwritten.

Pull requests and pushes to `main` run **Validate macOS packaging**, which builds
and inspects a universal ad-hoc DMG without signing secrets. Both workflows use
macOS 26 and the newest installed Xcode 26.x (Swift 6.2+); the app's deployment
target remains macOS 15.

In-app update behavior and stable/beta channel rules are documented in
[DMG automatic updates](auto-updates.md). Release tags use only `vX.Y.Z` or
`vX.Y.Z-beta.N`; both channels compare complete versions without downgrading.

## Local commands

Local builds default to the version and build number in `project.yml`. They use
an available Developer ID certificate, falling back to ad-hoc signing if none is
available. Select ad-hoc signing explicitly with:

```sh
SIGN_IDENTITY=- make package-dmg
```

For public distribution, set `APPLE_ID` and `APPLE_PASSWORD` in your environment,
using the same Apple ID and app-specific password as CI. Then run:

```sh
VERSION=0.2.3 BUILD_NUMBER=5 \
APPLE_TEAM_ID=ABCDEFGHIJ \
SIGN_IDENTITY='Developer ID Application: Your Name (ABCDEFGHIJ)' \
make release-dmg
```

`APPLE_SIGNING_IDENTITY` is an alias for `SIGN_IDENTITY`. Keep secrets out of the repo.
Local builds also support storing the same Apple ID credentials in the macOS
keychain. `notarytool` prompts for the app-specific password:

```sh
xcrun notarytool store-credentials localstack-notary \
  --apple-id 'you@example.com' --team-id 'ABCDEFGHIJ'
APPLE_TEAM_ID=ABCDEFGHIJ NOTARY_PROFILE=localstack-notary make release-dmg
```

`NOTARY_KEYCHAIN` optionally selects the keychain containing `NOTARY_PROFILE`.

`make release-dmg` always requires Developer ID signing, both architectures,
Team ID verification, and successful notarization. It cannot be downgraded with
`SIGN_IDENTITY=-` or `NOTARIZE=0`. `NOTARY_PROFILE` also enables notarization for
ordinary `make package-app` / `make package-dmg` invocations; direct credentials
require `NOTARIZE=1` or the `release-dmg` target.

`SKIP_BUILD=1` reuses `build/LocalStack.app` only after checking the version,
build number, architectures, signature, and (for releases) its stapled ticket.
Use the same environment as the original build. A failure leaves the previous
DMG and checksum in place. Successful builds replace them only after verification.

## Verification and failures

The pipeline runs Swift tests and `make test-packaging`, checks code signatures
with `codesign --verify --deep --strict`, and checks Gatekeeper with `spctl` for
both the app and DMG. It mounts the finished image read-only and verifies the
contained app, Applications shortcut, background bytes, saved Finder window
settings, and icon positions. Layout validation reads `.DS_Store` directly and
does not need Finder automation permission. SHA-256 is calculated after stapling.

Apple submission results and diagnostic logs are saved in
`build/notary/<version>/{app,dmg}/` and uploaded separately in Actions, including
on failure. The workflow requires an explicit `Accepted` result. A timeout
defaults to 30 minutes (`NOTARY_TIMEOUT` overrides it); Apple may keep processing
the recorded submission ID. Inspect it before rerunning:

```sh
xcrun notarytool info '<submission-id>' --keychain-profile localstack-notary
xcrun notarytool log '<submission-id>' --keychain-profile localstack-notary
```

Stapling retries briefly for ticket propagation without resubmitting the binary.
No release artifacts are uploaded unless all signing, notarization, ticket,
Gatekeeper, and mounted-image checks pass. A clean Mac installation smoke test
is still useful before publishing the draft.
