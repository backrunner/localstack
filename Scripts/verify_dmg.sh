#!/bin/zsh
set -euo pipefail
ROOT_DIR="${0:A:h}/.."
cd "$ROOT_DIR"
source Scripts/swift_env.sh
source Scripts/release_env.sh
[[ $# == 1 ]] || release_fail "Usage: Scripts/verify_dmg.sh <dmg>"
DMG_PATH="${1:A}"
[[ -f "$DMG_PATH" ]] || release_fail "DMG does not exist: $DMG_PATH"
hdiutil verify "$DMG_PATH"
if [[ "$NOTARIZE" == 1 ]]; then
  verify_signature "$DMG_PATH" dmg
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"
elif codesign --display "$DMG_PATH" >/dev/null 2>&1; then
  verify_signature "$DMG_PATH" dmg
fi
MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/localstack-dmg-check.XXXXXX")"
MOUNTED=0
cleanup() {
  local result=$?
  trap - EXIT INT TERM
  if [[ "$MOUNTED" == 1 ]]; then
    local detached=0
    for attempt in 1 2 3; do
      if hdiutil detach "$MOUNT_DIR"; then detached=1; break; fi
      sleep 2
    done
    if [[ "$detached" == 0 ]]; then
      print -u2 -- "Unable to detach verification volume: $MOUNT_DIR"
      exit 1
    fi
  fi
  # Never recursively delete a mountpoint, even when attach or detach fails.
  rmdir "$MOUNT_DIR" || result=1
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
hdiutil attach "$DMG_PATH" -readonly -nobrowse -noautoopen -mountpoint "$MOUNT_DIR"
MOUNTED=1
[[ -L "$MOUNT_DIR/Applications" && "$(readlink "$MOUNT_DIR/Applications")" == /Applications ]] || release_fail "Missing Applications shortcut."
[[ -s "$MOUNT_DIR/.DS_Store" ]] || release_fail "Missing Finder layout."
# Read dmgbuild's saved settings directly; CI does not need Finder automation access.
build/dmg-tools/bin/python Scripts/verify_dmg_layout.py "$MOUNT_DIR"
Scripts/verify_app.sh "$MOUNT_DIR/LocalStack.app"
print "Verified DMG contents, layout, architectures, and signatures: $DMG_PATH"
