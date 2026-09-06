#!/bin/zsh
set -euo pipefail
ROOT_DIR="${0:A:h}/.."
cd "$ROOT_DIR"
source Scripts/swift_env.sh
VERSION="${VERSION:-0.2.2}"
if [[ "${SKIP_BUILD:-0}" != "1" ]]; then Scripts/package_app.sh; fi
APP_DIR="$ROOT_DIR/build/LocalStack.app"
codesign --verify --deep --strict "$APP_DIR"
# Pin the small Finder-layout toolchain; no Finder automation permission is needed.
if [[ ! -x build/dmg-tools/bin/dmgbuild ]]; then
  python3 -m venv build/dmg-tools
  build/dmg-tools/bin/pip install -r Scripts/dmg-requirements.txt
fi
DMG_PATH="$ROOT_DIR/build/LocalStack-${VERSION}.dmg"
build/dmg-tools/bin/dmgbuild -s Scripts/dmg_settings.py -D app="$APP_DIR" "LocalStack" "$DMG_PATH"
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -1)}"
if [[ -n "$IDENTITY" && "$IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$IDENTITY" "$DMG_PATH"
fi
# Submitting the DMG notarizes its nested app as well. Staple the DMG for offline distribution.
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
else
  print "Developer ID signed DMG created. For public Gatekeeper distribution, run again with NOTARY_PROFILE=<keychain-profile>."
fi
hdiutil verify "$DMG_PATH"
(cd "$ROOT_DIR/build" && shasum -a 256 "${DMG_PATH:t}" > "${DMG_PATH:t}.sha256")
print "DMG: $DMG_PATH"
