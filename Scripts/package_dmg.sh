#!/bin/zsh
set -euo pipefail
ROOT_DIR="${0:A:h}/.."
cd "$ROOT_DIR"
source Scripts/swift_env.sh
source Scripts/release_env.sh
configure_signing
if [[ "$NOTARIZE" == 1 ]]; then configure_notary; fi
if [[ "${SKIP_BUILD:-0}" != "1" ]]; then Scripts/package_app.sh; fi
APP_DIR="$ROOT_DIR/build/LocalStack.app"
Scripts/verify_app.sh "$APP_DIR"
# Pin the small Finder-layout toolchain; no Finder automation permission is needed.
if [[ ! -x build/dmg-tools/bin/dmgbuild ]]; then
  python3 -m venv build/dmg-tools
  build/dmg-tools/bin/pip install -r Scripts/dmg-requirements.txt
fi
DMG_PATH="$ROOT_DIR/build/LocalStack-${VERSION}.dmg"
STAGE_DIR="$(mktemp -d "$ROOT_DIR/build/dmg-package.XXXXXX")"
trap 'rm -rf "$STAGE_DIR"' EXIT
STAGED_DMG="$STAGE_DIR/${DMG_PATH:t}"
build/dmg-tools/bin/dmgbuild -s Scripts/dmg_settings.py -D app="$APP_DIR" "LocalStack" "$STAGED_DMG"
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$STAGED_DMG"
fi
if [[ "$NOTARIZE" == 1 ]]; then
  Scripts/notarize.sh "$STAGED_DMG"
else
  print "Local DMG only (not notarized), app signed with: $SIGN_IDENTITY"
fi
Scripts/verify_dmg.sh "$STAGED_DMG"
(cd "$STAGE_DIR" && shasum -a 256 "${DMG_PATH:t}" > "${DMG_PATH:t}.sha256")
mv "$STAGED_DMG" "$DMG_PATH"
mv "$STAGE_DIR/${DMG_PATH:t}.sha256" "$DMG_PATH.sha256"
print "DMG: $DMG_PATH"
