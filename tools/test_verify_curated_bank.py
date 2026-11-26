import copy
import json
import unittest
from pathlib import Path

from verify_curated_bank import verify

ROOT = Path(__file__).resolve().parents[1]


class CuratedBankTest(unittest.TestCase):
    def setUp(self):
        self.bank = json.loads((ROOT / 'assets/question_bank/curated.json').read_text())
        self.curriculum = json.loads((ROOT / 'assets/content/curriculum.json').read_text())

    def test_valid_bank_covers_all_topics(self):
        self.assertEqual(verify(self.bank, self.curriculum), (28, 56))

    def test_unknown_evidence_is_rejected(self):
        self.bank['questions'][0]['answerSupport'] = 'not in the source'
        with self.assertRaisesRegex(ValueError, 'evidence'):
            verify(self.bank, self.curriculum)

    def test_duplicate_and_bad_answer_are_rejected(self):
        self.bank['questions'].append(copy.deepcopy(self.bank['questions'][0]))
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            verify(self.bank, self.curriculum)
        self.bank['questions'].pop()
        self.bank['questions'][1]['answerIndex'] = 99
        with self.assertRaisesRegex(ValueError, 'choices'):
            verify(self.bank, self.curriculum)

    def test_incomplete_coverage_is_rejected(self):
        self.bank['questions'].pop(0)
        with self.assertRaisesRegex(ValueError, 'Missing'):
            verify(self.bank, self.curriculum)


if __name__ == '__main__':
    unittest.main()
