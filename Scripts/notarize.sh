#!/bin/zsh
set -euo pipefail
ROOT_DIR="${0:A:h}/.."
cd "$ROOT_DIR"
source Scripts/swift_env.sh
export NOTARIZE=1
source Scripts/release_env.sh
[[ $# == 1 ]] || release_fail "Usage: Scripts/notarize.sh <app or dmg>"
TARGET="${1:A}"
[[ -e "$TARGET" ]] || release_fail "Notarization target does not exist: $TARGET"
case "$TARGET" in
  *.app) KIND=app ;;
  *.dmg) KIND=dmg ;;
  *) release_fail "Notarization supports .app and .dmg targets." ;;
esac
configure_notary
verify_signature "$TARGET" "$KIND"

# Keep separate reports for the app and DMG, including Apple's rejection details.
LOG_DIR="$ROOT_DIR/build/notary/$VERSION/$KIND"
mkdir -p "$LOG_DIR"
rm -f "$LOG_DIR/log.json"
WORK_DIR="$(mktemp -d "$ROOT_DIR/build/notary-upload.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
UPLOAD="$TARGET"
if [[ "$KIND" == app ]]; then
  UPLOAD="$WORK_DIR/LocalStack.app.zip"
  ditto -c -k --keepParent "$TARGET" "$UPLOAD"
fi
SUBMIT_EXIT=0
xcrun notarytool submit "$UPLOAD" "${NOTARY_ARGS[@]}" \
  --wait --timeout "${NOTARY_TIMEOUT:-30m}" --output-format json > "$LOG_DIR/submission.json" || SUBMIT_EXIT=$?
cat "$LOG_DIR/submission.json"
SUBMISSION_ID="$(python3 - "$LOG_DIR/submission.json" <<'PY'
import json, sys
try:
    print(json.load(open(sys.argv[1])).get('id', ''))
except (ValueError, OSError):
    pass
PY
)"
if [[ -n "$SUBMISSION_ID" ]]; then
  # A timeout leaves the submission running at Apple; its ID is retained for recovery.
  xcrun notarytool log "$SUBMISSION_ID" "${NOTARY_ARGS[@]}" "$LOG_DIR/log.json" || true
fi
[[ "$SUBMIT_EXIT" == 0 ]] || release_fail "Notarization submission failed or timed out; see $LOG_DIR."
[[ -n "$SUBMISSION_ID" ]] || release_fail "Apple returned no submission ID; see $LOG_DIR."
python3 - "$LOG_DIR/submission.json" <<'PY'
import json, sys
result = json.load(open(sys.argv[1]))
if result.get('status') != 'Accepted':
    sys.exit(f"Apple did not accept the submission: {result.get('status', 'unknown')}. See the notary log.")
PY

# Ticket propagation can lag behind Accepted. Retry stapling, never resubmit the upload.
STAPLED=0
for attempt in 1 2 3 4 5; do
  if xcrun stapler staple "$TARGET"; then STAPLED=1; break; fi
  if [[ "$attempt" != 5 ]]; then sleep 15; fi
done
[[ "$STAPLED" == 1 ]] || release_fail "Unable to staple the accepted ticket to $TARGET."
xcrun stapler validate "$TARGET"
verify_signature "$TARGET" "$KIND"
if [[ "$KIND" == app ]]; then
  spctl --assess --type execute --verbose=4 "$TARGET"
else
  spctl --assess --type open --context context:primary-signature --verbose=4 "$TARGET"
fi
