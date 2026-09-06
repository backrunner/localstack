#!/bin/zsh
set -euo pipefail

LABEL="com.localstack.coordinator"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"
launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
if [ -f "$PLIST_PATH" ]; then
  rm -f "$PLIST_PATH"
fi
echo "Uninstalled $LABEL"
