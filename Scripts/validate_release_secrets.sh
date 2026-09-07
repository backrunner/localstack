#!/bin/zsh
# Validate the GitHub release secrets without printing or writing their values.
set -euo pipefail
ROOT_DIR="${0:A:h}/.."
cd "$ROOT_DIR"
source Scripts/release_env.sh
for name in APPLE_CERTIFICATE APPLE_CERTIFICATE_PASSWORD APPLE_SIGNING_IDENTITY APPLE_TEAM_ID APPLE_ID APPLE_PASSWORD; do
  [[ -n "${(P)name:-}" ]] || release_fail "Missing GitHub secret: $name"
done
[[ "$APPLE_SIGNING_IDENTITY" == 'Developer ID Application: '*" (${APPLE_TEAM_ID})" ]] || release_fail "APPLE_SIGNING_IDENTITY must be a Developer ID Application identity for APPLE_TEAM_ID."

print 'Release signing secrets and Apple ID notarization credentials are configured.'
