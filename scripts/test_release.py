"""Regression checks for rejecting stale or altered release inputs (not physics tests)."""
from copy import deepcopy
from pathlib import Path
import subprocess
import tempfile
import unittest
from release_utils import current_commit, demo_hashes, file_sha256, source_digest, validate_release_inputs


class ReleaseEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='moondeform-evidence-')
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / 'moon.mod').write_text('name = "example/library"\nversion = "0.1.0"\nlicense = "MIT"\nrepository = "https://github.com/example/library"\n')
        (self.root / '.gitignore').write_text('dist/\nartifacts/\n')
        (self.root / 'library.mbt').write_text('// fixture\n')
        subprocess.run(['git', 'init', '-q'], cwd=self.root, check=True)
        subprocess.run(['git', 'add', '.'], cwd=self.root, check=True)
        subprocess.run(['git', '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.test', 'commit', '-qm', 'fixture'], cwd=self.root, check=True)
        (self.root / 'dist').mkdir()
        for name in ('index.html', 'solver.js', 'MoonDeform-demo.html'):
            (self.root / 'dist' / name).write_text('fixture-' + name)
        (self.root / 'artifacts').mkdir()
        archive = self.root / 'artifacts/registry.zip'
        archive.write_bytes(b'synthetic audited bytes')
        # Synthetic successful records isolate the cross-stage binding checks.
        self.core = {
            'schema_version': 1, 'status': 'passed', 'passed': [['fixture']],
            'commit': current_commit(self.root), 'source_sha256': source_digest(self.root),
            'demo_sha256': demo_hashes(self.root),
        }
        self.package = {
            'schema_version': 1, 'kind': 'registry-package',
            'module': 'example/library', 'version': '0.1.0',
            'source_sha256': self.core['source_sha256'], 'archive': 'artifacts/registry.zip',
            'sha256': file_sha256(archive), 'clean_consumer_targets': ['native', 'js'],
            'clean_demo_bridge': 'passed',
        }
        self.browser = {
            'schema_version': 1, 'status': 'passed', 'commit': self.core['commit'],
            'source_sha256': self.core['source_sha256'], 'demo_sha256': deepcopy(self.core['demo_sha256']),
            'browser': 'fixture-browser', 'scenarios': ['desktop-static', 'mobile-standalone'],
        }

    def validate(self, browser=None, require_browser=False):
        return validate_release_inputs(self.root, self.core, self.package, browser, require_browser)

    def test_local_candidate_may_explicitly_lack_browser_evidence(self):
        self.assertEqual(self.validate()['commit'], self.core['commit'])

    def test_ci_candidate_requires_browser_evidence(self):
        with self.assertRaisesRegex(ValueError, 'real-browser evidence'):
            self.validate(require_browser=True)

    def test_matching_browser_evidence_is_accepted(self):
        self.assertEqual(self.validate(self.browser, True)['metadata']['version'], '0.1.0')

    def test_another_browser_commit_is_rejected(self):
        self.browser['commit'] = '0' * 40
        with self.assertRaisesRegex(ValueError, 'Browser evidence'):
            self.validate(self.browser, True)

    def test_another_browser_demo_is_rejected(self):
        self.browser['demo_sha256']['solver.js'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'Browser evidence'):
            self.validate(self.browser, True)

    def test_source_change_invalidates_evidence(self):
        (self.root / 'library.mbt').write_text('// changed after checks\n')
        with self.assertRaisesRegex(ValueError, 'Core evidence'):
            self.validate(self.browser, True)

    def test_compiled_demo_change_invalidates_evidence(self):
        (self.root / 'dist/solver.js').write_text('changed after browser checks')
        with self.assertRaisesRegex(ValueError, 'Demo changed'):
            self.validate(self.browser, True)

    def test_registry_archive_change_invalidates_audit(self):
        (self.root / 'artifacts/registry.zip').write_bytes(b'changed after audit')
        with self.assertRaisesRegex(ValueError, 'Registry archive changed'):
            self.validate(self.browser, True)


if __name__ == '__main__':
    unittest.main()
