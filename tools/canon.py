#!/usr/bin/env python3
"""Shared numbers for the handbook.

docs/canon.json holds a snapshot of the engineering constants and of the insight
register. Guides quote a constant with a token instead of typing the number:

    {{c:desktop_geometry.gap_mm}}            -> 180
    {{c:desktop_geometry.envelope_mm|x}}     -> 286 × 268 × 324
    {{c:desktop_geometry.comb_tones_hz|khz}} -> 32, 64, 96, 128 and 160
    {{c:clock_and_bus.xin_hz|mhz}}           -> 12

Filters: x (join with ×), and (join as a list), range (low to high),
khz / mhz (divide, then join as a list), pct (fraction to percent, as a range).
The build fails on an unknown path, so a renamed constant cannot go unnoticed.
"""
import json
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
CANON_PATH = ROOT / 'docs/canon.json'
LIVE = Path(os.environ.get('REPLICATOR_CANON', ROOT.parent.parent / 'replicator'))
TOKEN = re.compile(r'\{\{c:([A-Za-z0-9_.]+)(?:\|([a-z]+))?\}\}')


def load():
    return json.loads(CANON_PATH.read_text())


def num(value):
    if isinstance(value, bool):
        return 'yes' if value else 'no'
    if isinstance(value, (int, float)):
        if float(value).is_integer():
            return f'{int(value):,}' if abs(value) >= 10000 else str(int(value))
        return f'{value:g}'
    return str(value)


def join_and(items):
    items = [num(i) for i in items]
    return items[0] if len(items) == 1 else ', '.join(items[:-1]) + ' and ' + items[-1]


def lookup(constants, path):
    node = constants
    for part in path.split('.'):
        if not isinstance(node, dict) or part not in node:
            raise KeyError(f'Unknown constant {path!r} (see docs/canon.json)')
        node = node[part]
    return node


def render(value, flt=None):
    seq = value if isinstance(value, list) else [value]
    if flt is None:
        return join_and(seq) if isinstance(value, list) else num(value)
    if flt == 'x':
        return ' × '.join(num(v) for v in seq)
    if flt == 'and':
        return join_and(seq)
    if flt == 'range':
        return f'{num(seq[0])} to {num(seq[-1])}'
    if flt == 'khz':
        return join_and([v / 1e3 for v in seq])
    if flt == 'mhz':
        return join_and([v / 1e6 for v in seq])
    if flt == 'pct':
        return ' to '.join(num(round(v * 100, 3)) for v in seq)
    raise KeyError(f'Unknown filter {flt!r}')


def expand(text, canon=None):
    constants = (canon or load())['constants']
    return TOKEN.sub(lambda m: render(lookup(constants, m.group(1)), m.group(2)), text)


def tokens(text):
    return [(m.group(1), m.group(2)) for m in TOKEN.finditer(text)]


EVIDENCE = {
    'DOCUMENTED': 'Documented',
    'DERIVED': 'Derived',
    'SIMULATED': 'Simulated',
    'MEASURED': 'Measured',
    'OPEN': 'Open',
    'CLAIM': 'Claim',
}


def insight_table(canon=None):
    """Markdown table of the insight register for the public insights page."""
    canon = canon or load()
    ins = canon['insights']
    rows = [f"As of {canon['synced_at']}, {ins['implemented_surfaces']} of {ins['total_surfaces']} check points pass across {len(ins['items'])} findings.", '',
            '| ID | Finding | What it changes | Evidence | Carried into code and documents |', '|---|---|---|---|---|']
    for item in canon['insights']['items']:
        done, total = item['implemented'], item['surfaces']
        state = 'Complete' if done == total else f'{done} of {total} places'
        rows.append('| {id} | {summary} | {effect} | {evidence} | {state} |'.format(
            id=item['id'], summary=item['summary'].replace('|', '/'), effect=item['effect'].replace('|', '/'),
            evidence=EVIDENCE.get(item['evidence'], item['evidence']), state=state))
    return '\n'.join(rows)


def private_terms():
    """Codenames that must never be published. The list itself is private, so it
    lives only in the engineering checkout's unpublished intake folder; without
    that checkout (for example in CI) this returns None and the check is skipped."""
    path = LIVE / 'research/intake/private_terms.txt'
    if not path.is_file():
        return None
    terms = [t.strip() for t in path.read_text().splitlines() if t.strip() and not t.startswith('#')]
    return re.compile('|'.join(re.escape(t) for t in terms), re.I) if terms else None
