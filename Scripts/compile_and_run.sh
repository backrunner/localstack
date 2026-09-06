#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h}/.."
"$ROOT_DIR/Scripts/package_app.sh"
open "$ROOT_DIR/build/LocalStack.app"
