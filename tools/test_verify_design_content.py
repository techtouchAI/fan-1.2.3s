"""Exercise the snapshot guard, including destructive-regression detection."""
import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import verify_design_content as verifier


class DesignContentSnapshotTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.asset = root / 'assets/content/curriculum.json'
        self.asset.parent.mkdir(parents=True)
        self.asset.write_text(json.dumps({'questions': ['first', 'second']}))
        fixture = root / 'test/fixtures/design_content_baseline.json'
        fixture.parent.mkdir(parents=True)
        fixture.write_text(json.dumps({
            'base': 'test-baseline',
            'sha256': {'assets/content/curriculum.json': hashlib.sha256(self.asset.read_bytes()).hexdigest()},
        }))
        patcher = patch.object(verifier, 'ROOT', root)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_unchanged_payload_passes(self):
        verifier.verify()

    def test_reordering_questions_is_rejected(self):
        self.asset.write_text(json.dumps({'questions': ['second', 'first']}))
        with self.assertRaisesRegex(SystemExit, 'Content/order/image changed'):
            verifier.verify()

    def test_editing_question_text_is_rejected(self):
        self.asset.write_text(json.dumps({'questions': ['changed', 'second']}))
        with self.assertRaisesRegex(SystemExit, 'Content/order/image changed'):
            verifier.verify()

    def test_missing_asset_is_rejected(self):
        self.asset.unlink()
        with self.assertRaisesRegex(SystemExit, 'Asset set changed'):
            verifier.verify()

    def test_extra_asset_is_rejected(self):
        self.asset.with_name('imported-arabic-content.json').write_text('{}')
        with self.assertRaisesRegex(SystemExit, 'Asset set changed'):
            verifier.verify()


if __name__ == '__main__':
    unittest.main()
