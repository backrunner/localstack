import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / 'Scripts/generate_update_manifest.py'


class UpdateManifestTests(unittest.TestCase):
    def test_manifest_describes_exact_final_dmg_and_signed_bundle_version(self):
        for version, channel in [('0.2.3', 'stable'), ('0.2.3-beta.10', 'beta')]:
            with self.subTest(version=version), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                app = root / 'LocalStack.app'
                (app / 'Contents').mkdir(parents=True)
                with (app / 'Contents/Info.plist').open('wb') as file:
                    plistlib.dump({'LocalStackReleaseVersion': version, 'CFBundleVersion': '5.2',
                                   'CFBundleIdentifier': 'com.localstack.app', 'LSMinimumSystemVersion': '15.0'}, file)
                dmg = root / f'LocalStack-{version}.dmg'
                dmg.write_bytes(b'final image bytes after stapling')
                output = root / 'LocalStack-update.json'
                subprocess.run([sys.executable, str(SCRIPT), str(app), str(dmg), '--team', 'ABCDEFGHIJ', '--output', str(output)],
                               check=True, capture_output=True)
                manifest = json.loads(output.read_text())
                self.assertEqual(manifest['version'], version)
                self.assertEqual(manifest['channel'], channel)
                self.assertEqual(manifest['buildNumber'], '5.2')
                self.assertEqual(manifest['fileName'], dmg.name)
                self.assertEqual(manifest['size'], dmg.stat().st_size)
                self.assertEqual(manifest['sha256'], hashlib.sha256(dmg.read_bytes()).hexdigest())
                wrong = root / 'LocalStack-other.dmg'
                wrong.write_bytes(dmg.read_bytes())
                result = subprocess.run([sys.executable, str(SCRIPT), str(app), str(wrong), '--team', 'ABCDEFGHIJ', '--output', str(output)],
                                        capture_output=True)
                self.assertNotEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main()
