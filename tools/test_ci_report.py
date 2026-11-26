#!/usr/bin/env python3
"""Regression tests for diagnostics from concurrent Flutter test files."""
import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path

from ci_report import report_test


class TestReporter(unittest.TestCase):
    def test_prints_follow_event_owner_not_last_started_test(self):
        events = [
            {"type": "testStart", "test": {"id": 1, "name": "first"}},
            {"type": "testStart", "test": {"id": 2, "name": "second"}},
            {"type": "print", "testID": 1, "message": "Expected: saved text Actual: empty"},
            {"type": "testDone", "testID": 1, "result": "failure", "hidden": False},
            {"type": "testDone", "testID": 2, "result": "success", "hidden": False},
        ]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "tests.json"
            path.write_text("\n".join(json.dumps(event) for event in events), encoding="utf-8")
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                report_test(path, 1)
        self.assertIn("first :: Expected: saved text Actual: empty", output.getvalue())
        self.assertNotIn("second ::", output.getvalue())
        self.assertIn("2 finished, 1 failing", output.getvalue())


if __name__ == "__main__":
    unittest.main()
