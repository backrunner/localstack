#!/usr/bin/env python3
"""Describe the final signed and notarized DMG for the in-app updater."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('app', type=Path)
    parser.add_argument('dmg', type=Path)
    parser.add_argument('--team', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    with (args.app / 'Contents/Info.plist').open('rb') as file:
        info = plistlib.load(file)
    version = info['LocalStackReleaseVersion']
    if not re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-beta\.[1-9][0-9]*)?', version):
        parser.error('Updater releases must use X.Y.Z or X.Y.Z-beta.N.')
    if info['CFBundleIdentifier'] != 'com.localstack.app' or args.dmg.name != f'LocalStack-{version}.dmg':
        parser.error('App identity, version, and DMG filename must agree.')
    if not re.fullmatch(r'[A-Z0-9]{10}', args.team):
        parser.error('Expected a 10-character Apple Developer Team ID.')
    with args.dmg.open('rb') as file:
        hasher = hashlib.sha256()
        for chunk in iter(lambda: file.read(1024 * 1024), b''):
            hasher.update(chunk)
        digest = hasher.hexdigest()
    manifest = {
        'schemaVersion': 1,
        'version': version,
        'channel': 'beta' if '-beta.' in version else 'stable',
        'buildNumber': info['CFBundleVersion'],
        'bundleIdentifier': info['CFBundleIdentifier'],
        'teamIdentifier': args.team,
        'minimumSystemVersion': info['LSMinimumSystemVersion'],
        'fileName': args.dmg.name,
        'size': args.dmg.stat().st_size,
        'sha256': digest,
    }
    args.output.write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Updater manifest: {args.output}')


if __name__ == '__main__':
    main()
