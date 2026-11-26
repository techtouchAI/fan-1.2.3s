#!/usr/bin/env python3
"""Validate curated exam supplements against the bundled curriculum.

The verifier checks provenance, identities, coverage and answer structure.
It does not replace human review of the wording and distractors.
"""
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def verify(bank, curriculum):
    if bank.get('version') != 1 or not isinstance(bank.get('questions'), list):
        raise ValueError('Invalid bank version or question list')
    units = {unit['id']: unit for unit in curriculum['units']}
    expected = {(u['id'], t['id']) for u in units.values()
                if u['sectionId'] in {'g1', 'g2', 'g3'} for t in u['topics']}
    seen, coverage = set(), Counter()
    for row in bank['questions']:
        uid, tid, qid = row['unitId'], row['topicId'], row['id']
        key = (uid, tid)
        if key not in expected or not qid.startswith('curated-') or (uid, qid) in seen:
            raise ValueError(f'Invalid topic or duplicate identity: {uid}/{qid}')
        seen.add((uid, qid))
        unit = units[uid]
        if qid in {question['id'] for question in unit['questions']}:
            raise ValueError(f'Conflicting original question id: {uid}/{qid}')
        topic = next(t for t in unit['topics'] if t['id'] == tid)
        if row.get('answerSupport') not in topic.get('bullets', []):
            raise ValueError(f'Missing source evidence: {uid}/{qid}')
        if not isinstance(row.get('prompt'), str) or not row['prompt'].strip():
            raise ValueError(f'Empty question: {uid}/{qid}')
        kind = row.get('kind')
        if kind == 'trueFalse':
            if row.get('answer') is not False:
                raise ValueError(f'Invalid false answer: {uid}/{qid}')
        elif kind == 'choice':
            options, answer = row.get('options'), row.get('answerIndex')
            if (not isinstance(options, list) or len(options) < 2 or
                any(not isinstance(option, str) or not option.strip() for option in options) or
                len(set(options)) != len(options) or type(answer) is not int or
                not 0 <= answer < len(options)):
                raise ValueError(f'Invalid choices: {uid}/{qid}')
        else:
            raise ValueError(f'Unexpected question kind: {uid}/{qid}')
        coverage[(uid, tid, kind)] += 1
    for uid, tid in expected:
        for kind in ('trueFalse', 'choice'):
            if coverage[(uid, tid, kind)] < 1:
                raise ValueError(f'Missing {kind} for {uid}/{tid}')
    return len(expected), len(bank['questions'])


def main():
    bank = json.loads((ROOT / 'assets/question_bank/curated.json').read_text(encoding='utf-8'))
    curriculum = json.loads((ROOT / 'assets/content/curriculum.json').read_text(encoding='utf-8'))
    topics, questions = verify(bank, curriculum)
    print(f'Curated question bank verified: {topics} grade topics, {questions} questions')


if __name__ == '__main__':
    main()
