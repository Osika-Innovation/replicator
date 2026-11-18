#!/usr/bin/env python3
"""Fail when a current guide contradicts the engineering canon.

1. Every {{c:...}} token in a guide resolves against docs/canon.json.
2. No current guide contains a phrase listed under rules.forbidden (retired
   baselines presented as current, superseded numbers, private names). A rule's
   optional 'unless' pattern excuses a line that states the history explicitly.
3. Every phrase under rules.required is present in its guide.
4. When the engineering checkout is reachable (sibling checkout or
   $REPLICATOR_CANON), the snapshot must equal its live constants and insight
   list. In CI the checkout is absent and this step is skipped.
"""
import json
import os
from pathlib import Path
import re

import canon

ROOT = canon.ROOT
LIVE = canon.LIVE


def main():
    data = canon.load()
    cat = json.loads((ROOT / 'docs/catalog.json').read_text())
    guides = {d['id']: (ROOT / d['source']).read_text() for d in cat['documents'] if d['type'] == 'guide'}
    errors = []
    used = 0
    for ident, text in guides.items():
        for path, flt in canon.tokens(text):
            used += 1
            try:
                canon.render(canon.lookup(data['constants'], path), flt)
            except KeyError as exc:
                errors.append(f'{ident}: {exc.args[0]}')
    for rule in data['rules']['forbidden']:
        pattern = re.compile(rule['pattern'], re.I)
        for ident, text in guides.items():
            if ident in rule.get('allow_in', []):
                continue
            unless = re.compile(rule['unless'], re.I) if rule.get('unless') else None
            for n, line in enumerate(text.splitlines(), 1):
                if pattern.search(line) and not (unless and unless.search(line)):
                    errors.append(f"{ident}:{n}: forbidden /{rule['pattern']}/ — {rule['reason']}")
    private = canon.private_terms()
    if private:
        for ident, text in guides.items():
            for n, line in enumerate(text.splitlines(), 1):
                if private.search(line):
                    errors.append(f'{ident}:{n}: private term in a public guide')
    for rule in data['rules']['required']:
        text = guides.get(rule['doc'])
        if text is None:
            errors.append(f"required rule names unknown guide {rule['doc']}")
        elif not re.search(rule['pattern'], text, re.I | re.S):
            errors.append(f"{rule['doc']}: missing /{rule['pattern']}/ — {rule['reason']}")
    live = 'skipped (engineering checkout not present)'
    constants_path = LIVE / 'coordination/system_constants.json'
    if constants_path.is_file():
        current = json.loads(constants_path.read_text())
        current.pop('_meta', None)
        if current != data['constants']:
            changed = sorted(k for k in set(current) | set(data['constants']) if current.get(k) != data['constants'].get(k))
            errors.append('constants drifted from the engineering checkout in: ' + ', '.join(changed) + ' — run tools/sync_canon.py and re-read the affected guides')
        ids = [i['id'] for i in json.loads((LIVE / 'coordination/insights.json').read_text())['insights']]
        have = [i['id'] for i in data['insights']['items']]
        if ids != have:
            errors.append(f'insight register changed ({len(have)} here, {len(ids)} live) — run tools/sync_canon.py and add notes')
        live = 'matches the engineering checkout'
    missing_notes = [i['id'] for i in data['insights']['items'] if i['id'] not in data['insights']['notes']]
    if missing_notes:
        errors.append('insights without a plain-language note: ' + ', '.join(missing_notes))
    if errors:
        print('\n'.join(errors))
        raise SystemExit(1)
    print(f"PASS: {used} constant tokens, {len(data['rules']['forbidden'])} forbidden and {len(data['rules']['required'])} required rules over {len(guides)} guides; snapshot {live}.")


if __name__ == '__main__':
    main()
