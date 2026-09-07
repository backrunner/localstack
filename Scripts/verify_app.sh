#!/bin/zsh
set -euo pipefail
ROOT_DIR="${0:A:h}/.."
cd "$ROOT_DIR"
source Scripts/swift_env.sh
source Scripts/release_env.sh
[[ $# == 1 ]] || release_fail "Usage: Scripts/verify_app.sh <app>"
APP_DIR="${1:A}"
[[ -x "$APP_DIR/Contents/MacOS/LocalStack" ]] || release_fail "Missing LocalStack executable."
python3 - "$APP_DIR/Contents/Info.plist" <<'PY'
import os, plistlib, sys
with open(sys.argv[1], 'rb') as f:
    info = plistlib.load(f)
expected = {
    'CFBundleIdentifier': 'com.localstack.app',
    'CFBundleExecutable': 'LocalStack',
    'CFBundleShortVersionString': os.environ['VERSION'].split('-')[0],
    'CFBundleVersion': os.environ['BUILD_NUMBER'],
    'LocalStackReleaseVersion': os.environ['VERSION'],
}
for key, value in expected.items():
    if info.get(key) != value:
        sys.exit(f'{key}: expected {value!r}, found {info.get(key)!r}. Rebuild the app before packaging.')
PY
verify_architectures "$APP_DIR/Contents/MacOS/LocalStack"
verify_signature "$APP_DIR" app
if [[ "$NOTARIZE" == 1 ]]; then
  xcrun stapler validate "$APP_DIR"
  spctl --assess --type execute --verbose=4 "$APP_DIR"
fi
