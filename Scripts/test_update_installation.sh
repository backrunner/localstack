#!/bin/zsh
set -euo pipefail
ROOT_DIR="${0:A:h}/.."
cd "$ROOT_DIR"
source Scripts/swift_env.sh
source Scripts/release_env.sh
[[ "${GITHUB_ACTIONS:-}" == true && "$RELEASE" == 1 ]] || release_fail "Installation smoke tests require a disposable release runner."

# Preserve the exact public release bundle and artifacts. The older fixture is
# private to this job and contains the updater from the same source revision.
SMOKE_DIR="$(mktemp -d "$ROOT_DIR/build/update-install.XXXXXX")"
mv build/LocalStack.app "$SMOKE_DIR/Release.app"
restore_release_app() {
  if [[ -d "$SMOKE_DIR/Release.app" ]]; then
    rm -rf build/LocalStack.app
    mv "$SMOKE_DIR/Release.app" build/LocalStack.app
  fi
  rm -rf "$SMOKE_DIR"
}
trap restore_release_app EXIT
VERSION=0.0.0-beta.1 BUILD_NUMBER=1 Scripts/package_app.sh
mv build/LocalStack.app "$SMOKE_DIR/Fixture.app"
mv "$SMOKE_DIR/Release.app" build/LocalStack.app
LOCALSTACK_UPDATE_INSTALL_FIXTURE="$SMOKE_DIR/Fixture.app" \
LOCALSTACK_UPDATE_INSTALL_DMG="$ROOT_DIR/build/LocalStack-$VERSION.dmg" \
LOCALSTACK_UPDATE_INSTALL_MANIFEST="$ROOT_DIR/build/LocalStack-update.json" \
  swift test --filter notarizedUpdateInstallation
