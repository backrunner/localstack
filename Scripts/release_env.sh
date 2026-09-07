#!/bin/zsh
# Shared by the packaging and verification entry points (all run from the repo root).
release_fail() { print -u2 -- "Error: $*"; exit 1; }

VERSION="${VERSION:-$(sed -n 's/^    MARKETING_VERSION: //p' project.yml)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(sed -n 's/^    CURRENT_PROJECT_VERSION: //p' project.yml)}"
ARCHS="${ARCHS:-arm64 x86_64}"
RELEASE="${RELEASE:-0}"
NOTARIZE="${NOTARIZE:-${NOTARY_PROFILE:+1}}"
NOTARIZE="${NOTARIZE:-$RELEASE}"
export VERSION BUILD_NUMBER ARCHS RELEASE NOTARIZE

[[ "$RELEASE" == [01] && "$NOTARIZE" == [01] ]] || release_fail "RELEASE and NOTARIZE must be 0 or 1."
[[ "$RELEASE" != 1 || "$NOTARIZE" == 1 ]] || release_fail "Release builds require notarization."
python3 - <<'PY'
import os, re, sys
version = os.environ['VERSION']
if not re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-beta\.[1-9][0-9]*)?', version):
    sys.exit('VERSION must use X.Y.Z or X.Y.Z-beta.N, e.g. 0.2.3 or 0.2.3-beta.1.')
if not re.fullmatch(r'[1-9][0-9]*(\.[0-9]+){0,2}', os.environ['BUILD_NUMBER']):
    sys.exit('BUILD_NUMBER must contain one to three numeric components, starting with a positive integer.')
archs = os.environ['ARCHS'].split()
if not archs or len(set(archs)) != len(archs) or set(archs) - {'arm64', 'x86_64'}:
    sys.exit('ARCHS must contain arm64, x86_64, or both without duplicates.')
if os.environ['RELEASE'] == '1' and set(archs) != {'arm64', 'x86_64'}:
    sys.exit('Release builds must include both arm64 and x86_64.')
PY

if [[ "$RELEASE" == 1 || "$NOTARIZE" == 1 ]]; then
  [[ -n "${APPLE_TEAM_ID:-}" ]] || release_fail "APPLE_TEAM_ID is required for release/notarized builds."
fi

configure_signing() {
  local identities
  identities="$(security find-identity -v -p codesigning)"
  SIGN_IDENTITY="${SIGN_IDENTITY:-${APPLE_SIGNING_IDENTITY:-}}"
  if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="$(print -r -- "$identities" | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -1)"
    SIGN_IDENTITY="${SIGN_IDENTITY:--}"
  fi
  if [[ "$SIGN_IDENTITY" == '-' ]]; then
    [[ "$RELEASE" != 1 && "$NOTARIZE" != 1 ]] || release_fail "A Developer ID Application certificate is required; ad-hoc signing is not allowed."
  else
    [[ "$SIGN_IDENTITY" == 'Developer ID Application: '* ]] || release_fail "SIGN_IDENTITY must be a Developer ID Application certificate name."
    [[ "$identities" == *"\"$SIGN_IDENTITY\""* ]] || release_fail "The requested signing identity is not available in the keychain."
    if [[ -n "${APPLE_TEAM_ID:-}" ]]; then
      [[ "$SIGN_IDENTITY" == *" (${APPLE_TEAM_ID})" ]] || release_fail "Signing identity does not match APPLE_TEAM_ID."
    fi
  fi
  export SIGN_IDENTITY
}

configure_notary() {
  NOTARY_ARGS=()
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
    if [[ -n "${NOTARY_KEYCHAIN:-}" ]]; then NOTARY_ARGS+=(--keychain "$NOTARY_KEYCHAIN"); fi
  elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
    NOTARY_ARGS=(--apple-id "$APPLE_ID" --password "$APPLE_PASSWORD" --team-id "$APPLE_TEAM_ID")
  else
    release_fail "Configure APPLE_ID, APPLE_PASSWORD (an app-specific password), and APPLE_TEAM_ID, or a local NOTARY_PROFILE."
  fi
}

verify_architectures() {
  local arch
  # One architecture per call also works with Xcode 27's lipo argument parser.
  for arch in ${=ARCHS}; do lipo "$1" -verify_arch "$arch"; done
}

verify_signature() {
  local target="$1" kind="$2" details
  codesign --verify --deep --strict --verbose=2 "$target"
  details="$(codesign --display --verbose=4 "$target" 2>&1)"
  if [[ "$RELEASE" == 1 || "$NOTARIZE" == 1 || -n "${APPLE_TEAM_ID:-}" ]]; then
    [[ "$details" == *$'\nAuthority=Developer ID Application: '* ]] || release_fail "Missing Developer ID signature: $target"
    [[ "$details" == *$'\nTeamIdentifier='"${APPLE_TEAM_ID}"$'\n'* ]] || release_fail "Signature TeamIdentifier does not match APPLE_TEAM_ID: $target"
    [[ "$details" == *$'\nTimestamp='* ]] || release_fail "Missing secure signing timestamp: $target"
    if [[ "$kind" == app ]]; then
      [[ "$details" == *'(runtime)'* ]] || release_fail "Hardened Runtime is not enabled: $target"
    fi
  fi
}
