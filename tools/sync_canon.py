#!/usr/bin/env python3
"""Refresh docs/canon.json from the engineering checkout.

    python3 tools/sync_canon.py [--from PATH_TO_ENGINEERING_CHECKOUT]

Reads coordination/system_constants.json and coordination/insights.json and audits
the insight register with that checkout's own tools/hub.py. Plain-language notes
written for the handbook (docs/canon.json -> insights.notes) are kept; an insight
without a note falls back to its register title and is reported.
Nothing else is read, and no file outside this worktree is written.
"""
import argparse
from datetime import datetime, timezone
import importlib.util
import json
import os
from pathlib import Path

import canon

DEFAULT = Path(os.environ.get('REPLICATOR_CANON', canon.ROOT.parent.parent / 'replicator'))


def audit(source):
    spec = importlib.util.spec_from_file_location('replicator_hub', source / 'tools/hub.py')
    hub = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(hub)
    return hub.evaluate_insights()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--from', dest='source', type=Path, default=DEFAULT)
    args = ap.parse_args()
    source = args.source.resolve()
    constants = json.loads((source / 'coordination/system_constants.json').read_text())
    constants.pop('_meta', None)
    current = canon.load() if canon.CANON_PATH.exists() else {'insights': {'notes': {}}, 'rules': {'forbidden': [], 'required': []}}
    notes = current['insights'].get('notes', {})
    result = audit(source)
    items, unnoted = [], []
    for ins in result['insights']:
        note = notes.get(ins['id'])
        if not note:
            unnoted.append(ins['id'])
        items.append({
            'id': ins['id'],
            'summary': (note or {}).get('summary', ins['title']),
            'effect': (note or {}).get('effect', ins['bottleneck_removed']),
            'evidence': ins['epistemic_tag'],
            'implemented': ins['implemented_count'],
            'surfaces': ins['total_count'],
        })
    counts = result['counts']
    out = {
        'schema_version': '1.0',
        'synced_at': datetime.now(timezone.utc).strftime('%Y-%m-%d'),
        'constants': constants,
        'insights': {
            'implemented_surfaces': counts['IMPLEMENTED'],
            'total_surfaces': counts['total_surfaces'],
            'items': items,
            'notes': notes,
        },
        'rules': current['rules'],
    }
    canon.CANON_PATH.write_text(json.dumps(out, indent=2, ensure_ascii=False) + '\n')
    print(f"Synced {len(items)} insights ({counts['IMPLEMENTED']}/{counts['total_surfaces']} surfaces) and constants.")
    if unnoted:
        print('No plain-language note yet for: ' + ', '.join(unnoted))


if __name__ == '__main__':
    main()
