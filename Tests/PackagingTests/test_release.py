"""Exercise release failure gates without Apple credentials or network access."""
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
IDENTITY = 'Developer ID Application: Packaging Test (ABCDEFGHIJ)'
FAKE_TOOL = r'''#!/usr/bin/env python3
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['TOOL_LOG'], 'a') as f:
    f.write(json.dumps([name, *args]) + '\n')
if name == 'security':
    print('  1) AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA "Developer ID Application: Packaging Test (ABCDEFGHIJ)"')
elif name == 'codesign':
    if '--display' in args:
        if os.environ.get('ADHOC') == '1':
            print('Signature=adhoc\nTeamIdentifier=not set\n', file=sys.stderr)
        else:
            print('Executable=test\nCodeDirectory flags=0x10000(runtime)\nAuthority=Developer ID Application: Packaging Test (ABCDEFGHIJ)\nTimestamp=Jan 1, 2026\nTeamIdentifier=' + os.environ.get('SIGNED_TEAM', 'ABCDEFGHIJ') + '\nSealed Resources version=2\n', file=sys.stderr)
    elif os.environ.get('BAD_SIGNATURE') == '1':
        sys.exit(1)
elif name == 'xcrun':
    if args[:2] == ['notarytool', 'submit']:
        if os.environ.get('NOTARY_MALFORMED') == '1':
            print('not JSON')
        else:
            print(json.dumps({'id': 'test-submission', 'status': os.environ.get('NOTARY_STATUS', 'Accepted')}))
        sys.exit(int(os.environ.get('NOTARY_EXIT', '0')))
    elif args[:2] == ['notarytool', 'log']:
        pathlib.Path(args[-1]).write_text('{"issues": []}')
    elif args[:2] == ['stapler', 'staple'] and os.environ.get('STAPLE_FAIL') == '1':
        sys.exit(1)
    elif args[:2] == ['stapler', 'validate'] and os.environ.get('MISSING_TICKET') == '1':
        sys.exit(1)
elif name == 'spctl':
    sys.exit(int(os.environ.get('GATEKEEPER_EXIT', '0')))
elif name == 'lipo' and os.environ.get('MISSING_ARCH') == '1':
    sys.exit(1)
'''


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='localstack-packaging-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        shutil.copytree(ROOT / 'Scripts', self.root / 'Scripts')
        shutil.copyfile(ROOT / 'project.yml', self.root / 'project.yml')
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        for name in ('security', 'codesign', 'xcrun', 'lipo', 'spctl', 'ditto', 'sleep'):
            tool = self.bin / name
            tool.write_text(FAKE_TOOL)
            tool.chmod(0o755)
        self.log = self.root / 'tools.jsonl'
        self.env = {
            k: v for k, v in os.environ.items()
            if not k.startswith(('APPLE_', 'NOTARY_', 'SIGN_', 'CSC_'))
            and k not in ('VERSION', 'BUILD_NUMBER', 'RELEASE', 'NOTARIZE', 'ARCHS', 'SKIP_BUILD')
        }
        self.env.update({
            'PATH': str(self.bin) + os.pathsep + os.environ['PATH'],
            'TOOL_LOG': str(self.log), 'VERSION': '0.2.3-beta.1', 'BUILD_NUMBER': '12.1',
            'APPLE_TEAM_ID': 'ABCDEFGHIJ', 'SIGN_IDENTITY': IDENTITY,
            'APPLE_ID': 'packaging@example.invalid', 'APPLE_PASSWORD': 'test-password',
            'RELEASE': '1', 'ARCHS': 'arm64 x86_64',
        })
        self.app = self.root / 'build/LocalStack.app'
        executable = self.app / 'Contents/MacOS/LocalStack'
        executable.parent.mkdir(parents=True)
        executable.touch(mode=0o755)
        self.info = {
            'CFBundleIdentifier': 'com.localstack.app', 'CFBundleExecutable': 'LocalStack',
            'CFBundleShortVersionString': '0.2.3', 'CFBundleVersion': '12.1',
            'LocalStackReleaseVersion': '0.2.3-beta.1',
        }
        self.write_info()

    def write_info(self):
        with (self.app / 'Contents/Info.plist').open('wb') as f:
            plistlib.dump(self.info, f)

    def run_script(self, script, *args, success=True, **env):
        result = subprocess.run(
            ['zsh', str(self.root / 'Scripts' / script), *map(str, args)],
            cwd=self.root, env=self.env | env, text=True, capture_output=True, timeout=60,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def assert_not_submitted(self):
        self.assertFalse(any(call[:3] == ['xcrun', 'notarytool', 'submit'] for call in self.calls()))

    def test_release_cannot_disable_notarization(self):
        self.run_script('package_dmg.sh', success=False, NOTARIZE='0')
        self.assertEqual(self.calls(), [])

    def test_release_cannot_use_adhoc_signing(self):
        self.run_script('package_dmg.sh', success=False, SIGN_IDENTITY='-')
        self.assert_not_submitted()

    def test_release_requires_both_architectures(self):
        self.run_script('package_dmg.sh', success=False, ARCHS='arm64')
        self.assertEqual(self.calls(), [])

    def test_missing_credentials_fail_before_build(self):
        for env in ({'APPLE_ID': ''}, {'APPLE_PASSWORD': ''}, {'APPLE_TEAM_ID': ''}):
            with self.subTest(env=env):
                self.run_script('package_dmg.sh', success=False, **env)
        self.assert_not_submitted()

    def test_wrong_team_rejected_before_submission(self):
        self.run_script('notarize.sh', self.app, success=False, SIGNED_TEAM='WRONGTEAM1')
        self.assert_not_submitted()

    def test_adhoc_app_rejected_before_submission(self):
        self.run_script('notarize.sh', self.app, success=False, ADHOC='1')
        self.assert_not_submitted()

    def test_modified_app_rejected_before_submission(self):
        self.run_script('notarize.sh', self.app, success=False, BAD_SIGNATURE='1')
        self.assert_not_submitted()

    def test_rejected_or_pending_submission_never_stapled(self):
        for status in ('Invalid', 'In Progress', 'Rejected'):
            with self.subTest(status=status):
                self.log.unlink(missing_ok=True)
                self.run_script('notarize.sh', self.app, success=False, NOTARY_STATUS=status)
                self.assertFalse(any(call[:2] == ['xcrun', 'stapler'] for call in self.calls()))
                self.assertTrue((self.root / 'build/notary/0.2.3-beta.1/app/log.json').exists())

    def test_timeout_or_malformed_result_never_stapled(self):
        for env in ({'NOTARY_EXIT': '1'}, {'NOTARY_MALFORMED': '1'}):
            with self.subTest(env=env):
                self.log.unlink(missing_ok=True)
                self.run_script('notarize.sh', self.app, success=False, **env)
                self.assertFalse(any(call[:2] == ['xcrun', 'stapler'] for call in self.calls()))

    def test_accepted_app_is_stapled_and_assessed(self):
        self.run_script('notarize.sh', self.app)
        calls = self.calls()
        self.assertTrue(any(call[:2] == ['ditto', '-c'] for call in calls))
        self.assertIn(['xcrun', 'stapler', 'staple', str(self.app)], calls)
        self.assertIn(['xcrun', 'stapler', 'validate', str(self.app)], calls)
        self.assertTrue(any(call[:4] == ['spctl', '--assess', '--type', 'execute'] for call in calls))

    def test_accepted_dmg_gets_open_assessment(self):
        dmg = self.root / 'build/LocalStack.dmg'
        dmg.touch()
        self.run_script('notarize.sh', dmg)
        self.assertTrue(any(call[:4] == ['spctl', '--assess', '--type', 'open'] for call in self.calls()))
        self.assertFalse(any(call[0] == 'ditto' for call in self.calls()))

    def test_stapling_failure_does_not_resubmit(self):
        self.run_script('notarize.sh', self.app, success=False, STAPLE_FAIL='1')
        calls = self.calls()
        self.assertEqual(sum(call[:3] == ['xcrun', 'notarytool', 'submit'] for call in calls), 1)
        self.assertEqual(sum(call[:3] == ['xcrun', 'stapler', 'staple'] for call in calls), 5)
        self.assertFalse(any(call[0] == 'spctl' for call in calls))

    def test_gatekeeper_rejection_fails_notarization_step(self):
        self.run_script('notarize.sh', self.app, success=False, GATEKEEPER_EXIT='1')

    def test_stale_app_cannot_be_reused(self):
        for key, value in (('CFBundleVersion', '11'), ('LocalStackReleaseVersion', '0.2.2')):
            with self.subTest(key=key):
                original = self.info[key]
                self.info[key] = value
                self.write_info()
                self.run_script('package_dmg.sh', success=False, SKIP_BUILD='1')
                self.info[key] = original
        self.assert_not_submitted()

    def test_missing_architecture_or_ticket_blocks_packaging(self):
        for env in ({'MISSING_ARCH': '1'}, {'MISSING_TICKET': '1'}):
            with self.subTest(env=env):
                self.run_script('package_dmg.sh', success=False, SKIP_BUILD='1', **env)
        self.assert_not_submitted()

    def test_prerelease_bundle_uses_numeric_short_version(self):
        self.run_script('verify_app.sh', self.app)

    def test_apple_id_credentials_are_passed_to_notarytool(self):
        self.run_script('notarize.sh', self.app)
        submit = next(call for call in self.calls() if call[:3] == ['xcrun', 'notarytool', 'submit'])
        for flag, value in (('--apple-id', 'packaging@example.invalid'),
                            ('--password', 'test-password'), ('--team-id', 'ABCDEFGHIJ')):
            self.assertEqual(submit[submit.index(flag) + 1], value)

    def test_ci_validates_credentials_without_printing_values(self):
        result = self.run_script('validate_release_secrets.sh',
                        APPLE_CERTIFICATE='dummy', APPLE_CERTIFICATE_PASSWORD='dummy',
                        APPLE_SIGNING_IDENTITY=IDENTITY)
        self.assertNotIn('packaging@example.invalid', result.stdout + result.stderr)
        self.assertNotIn('test-password', result.stdout + result.stderr)

    def test_ci_requires_both_apple_id_secrets(self):
        for name in ('APPLE_ID', 'APPLE_PASSWORD'):
            with self.subTest(name=name):
                result = self.run_script('validate_release_secrets.sh', success=False,
                                        APPLE_CERTIFICATE='dummy', APPLE_CERTIFICATE_PASSWORD='dummy',
                                        APPLE_SIGNING_IDENTITY=IDENTITY, **{name: ''})
                self.assertIn(f'Missing GitHub secret: {name}', result.stderr)

    def test_local_keychain_profile_remains_supported(self):
        self.run_script('notarize.sh', self.app, NOTARY_PROFILE='packaging-test',
                        APPLE_ID='', APPLE_PASSWORD='')
        submit = next(call for call in self.calls() if call[:3] == ['xcrun', 'notarytool', 'submit'])
        self.assertEqual(submit[submit.index('--keychain-profile') + 1], 'packaging-test')
        self.assertNotIn('--apple-id', submit)


if __name__ == '__main__':
    unittest.main()
