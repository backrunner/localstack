#!/bin/zsh
set -euo pipefail
ROOT_DIR="${0:A:h}/.."
cd "$ROOT_DIR"
source Scripts/swift_env.sh
source Scripts/release_env.sh
configure_signing
if [[ "$NOTARIZE" == 1 ]]; then configure_notary; fi
APP_DIR="$ROOT_DIR/build/LocalStack.app"
BUILD_ARGS=(-c release --product LocalStackApp)
for arch in ${=ARCHS}; do BUILD_ARGS+=(--arch "$arch"); done
mkdir -p build
Scripts/generate_assets.sh
swift build "${BUILD_ARGS[@]}" > build/release-build.log 2>&1 || { tail -60 build/release-build.log; exit 1; }
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
STAGE="$(mktemp -d "$ROOT_DIR/build/package.XXXXXX")/LocalStack.app"
trap 'rm -rf "${STAGE:h}"' EXIT
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources"
cp "$BIN_DIR/LocalStackApp" "$STAGE/Contents/MacOS/LocalStack"
cp Resources/AppIcon.icns "$STAGE/Contents/Resources/"
cp Resources/Brand/TrayTemplate.png "$STAGE/Contents/Resources/"
export LS_PACKAGE_STAGE="$STAGE" LS_VERSION="$VERSION" LS_BUILD_NUMBER="$BUILD_NUMBER"
python3 - <<'PY'
import os, plistlib
plist = {
 'CFBundleDevelopmentRegion':'zh_CN', 'CFBundleDisplayName':'LocalStack',
 'CFBundleExecutable':'LocalStack', 'CFBundleIdentifier':'com.localstack.app',
 'CFBundleInfoDictionaryVersion':'6.0', 'CFBundleName':'LocalStack',
 'CFBundlePackageType':'APPL', 'CFBundleShortVersionString':os.environ['LS_VERSION'].split('-')[0],
 'LocalStackReleaseVersion':os.environ['LS_VERSION'],
 'CFBundleVersion':os.environ['LS_BUILD_NUMBER'], 'CFBundleIconFile':'AppIcon',
 'LSMinimumSystemVersion':'15.0', 'LSUIElement':True, 'NSHighResolutionCapable':True,
 'NSHumanReadableCopyright':'LocalStack',
 'CFBundleURLTypes':[{'CFBundleURLName':'LocalStack Service Deep Link', 'CFBundleURLSchemes':['localstack']}]
}
with open(os.path.join(os.environ['LS_PACKAGE_STAGE'],'Contents/Info.plist'),'wb') as f: plistlib.dump(plist, f)
PY
# The SwiftPM bundle contains one statically linked executable and no Widget extension.
# It needs no restricted App Group entitlement or provisioning profile.
verify_architectures "$STAGE/Contents/MacOS/LocalStack"
SIGN_ARGS=(--force --options runtime --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then SIGN_ARGS+=(--timestamp); fi
codesign "${SIGN_ARGS[@]}" "$STAGE"
verify_signature "$STAGE" app
if [[ "$NOTARIZE" == 1 ]]; then Scripts/notarize.sh "$STAGE"; fi
BACKUP="${STAGE:h}/LocalStack.previous.app"
if [[ -e "$APP_DIR" ]]; then
  mv "$APP_DIR" "$BACKUP"
fi
if ! mv "$STAGE" "$APP_DIR"; then
  if [[ -e "$BACKUP" ]]; then mv "$BACKUP" "$APP_DIR"; fi
  exit 1
fi
print "Packaged: $APP_DIR ($ARCHS), version $VERSION"
print "Signed with: $SIGN_IDENTITY"
