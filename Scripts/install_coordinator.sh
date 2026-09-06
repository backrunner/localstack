#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h}/.."
cd "$ROOT_DIR"

APP_SUPPORT="$HOME/Library/Application Support/LocalStack"
BIN_DIR="$APP_SUPPORT/bin"
LOG_DIR="$APP_SUPPORT/logs"
PLIST_PATH="$HOME/Library/LaunchAgents/com.localstack.coordinator.plist"
LABEL="com.localstack.coordinator"

mkdir -p "$BIN_DIR" "$LOG_DIR" "${PLIST_PATH:h}"
swift build -c release --product LocalStackCoordinator >/dev/null
cp "$(swift build -c release --product LocalStackCoordinator --show-bin-path)/LocalStackCoordinator" "$BIN_DIR/LocalStackCoordinator"
chmod 700 "$BIN_DIR/LocalStackCoordinator"

BIN_SED="${BIN_DIR//\\/\\\\}"
BIN_SED="${BIN_SED//&/\\&}"
BIN_SED="${BIN_SED//|/\\|}"
LOG_SED="${LOG_DIR//\\/\\\\}"
LOG_SED="${LOG_SED//&/\\&}"
LOG_SED="${LOG_SED//|/\\|}"
sed \
  -e "s|__LOCALSTACK_COORDINATOR_BINARY__|$BIN_SED/LocalStackCoordinator|g" \
  -e "s|__LOCALSTACK_LOG_DIR__|$LOG_SED|g" \
  launchd/com.localstack.coordinator.plist > "$PLIST_PATH"
chmod 600 "$PLIST_PATH"

launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$PLIST_PATH"
launchctl enable "gui/$UID/$LABEL" 2>/dev/null || true
echo "Installed and started $LABEL"
