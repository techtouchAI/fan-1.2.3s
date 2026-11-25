"""Byte-for-byte regression guard for the design-only migration.

The baseline was captured from 067fdf1, before presentation changes. A digest of
an entire JSON payload protects text, answers, options AND array/question order.
Art assets are included so a design transfer cannot replace subject imagery.
Update this explicit snapshot only after an intentional curriculum review.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def verify():
    baseline = json.loads((ROOT / 'test/fixtures/design_content_baseline.json').read_text())
    expected = baseline['sha256']
    actual_paths = {
        str(path.relative_to(ROOT))
        for folder in ('assets/content', 'assets/illustrations', 'assets/images')
        for path in (ROOT / folder).rglob('*')
        if path.is_file()
    }
    errors = []
    if actual_paths != set(expected):
        errors.append(f'Asset set changed: {actual_paths ^ set(expected)}')
    for name, digest in expected.items():
        path = ROOT / name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            errors.append(f'Content/order/image changed: {name}')
    if errors:
        raise SystemExit('\n'.join(errors))
    print(f'Design content snapshot passed: {len(expected)} assets identical to {baseline["base"]}')


if __name__ == '__main__':
    verify()
