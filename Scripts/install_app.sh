#!/bin/zsh
set -euo pipefail
ROOT_DIR="${0:A:h}/.."
cd "$ROOT_DIR"
if [[ "${SKIP_BUILD:-0}" != "1" ]]; then Scripts/package_app.sh; fi
# Uses exactly the same verified, transactional installer as double-clicking the app in a DMG.
open -W -n "$ROOT_DIR/build/LocalStack.app" --args --install --enable-login
