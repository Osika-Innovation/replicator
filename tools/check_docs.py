#!/usr/bin/env python3
"""Validate generated pages, links, anchors, source identity and public scope."""
from html.parser import HTMLParser
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '_site'


class Page(HTMLParser):
    def __init__(self):
        super().__init__(); self.ids = set(); self.duplicate = []; self.links = []; self.title = False
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'title': self.title = True
        ident = attrs.get('id') or (attrs.get('name') if tag == 'a' else None)
        if ident:
            if ident in self.ids: self.duplicate.append(ident)
            self.ids.add(ident)
        for attr in ('href', 'src'):
            if attrs.get(attr): self.links.append(attrs[attr])


def main():
    errors = []
    pages = {}
    for path in OUT.rglob('*.html'):
        text = path.read_text(); page = Page(); page.feed(text); pages[path.resolve()] = page
        if not page.title: errors.append(f'{path.name}: no title')
        if page.duplicate: errors.append(f'{path.name}: duplicate IDs {page.duplicate}')
        if '{{' in text: errors.append(f'{path.name}: unexpanded template')
    for path, page in pages.items():
        for value in page.links:
            u = urlsplit(value)
            if u.scheme or value.startswith('//'): continue
            target = (path.parent / unquote(u.path)).resolve() if u.path else path
            if not target.is_relative_to(OUT.resolve()):
                errors.append(f'{path.name}: escaped build root {value}'); continue
            if target.is_dir(): target = target / 'index.html'
            if not target.exists(): errors.append(f'{path.name}: missing {value}'); continue
            if u.fragment and target in pages and unquote(u.fragment) not in pages[target].ids:
                errors.append(f'{path.name}: missing anchor {value}')
    cat = json.loads((OUT / 'catalog.json').read_text())
    docs = cat['documents']
    if len({d['id'] for d in docs}) != len(docs): errors.append('Duplicate document IDs')
    known = {d['id'] for d in docs}
    for d in docs:
        for related in d['related']:
            if related not in known: errors.append('Unknown related ID: ' + related)
        if not (OUT / d['url']).is_file(): errors.append('Unbuilt catalog document: ' + d['id'])
    for p in OUT.rglob('*'):
        if p.is_file() and p.suffix in {'.html', '.json', '.txt', '.md'}:
            t = p.read_text()
            if re.search(r'file://|/Users/|/private/tmp/|\.codex/attachments|research/intake/', t):
                errors.append('Private/local provenance in public output: ' + p.name)
    index = json.loads((OUT / 'document-index.json').read_text())
    if {d['id'] for d in index} != known: errors.append('Search index differs from catalog')
    if errors:
        print('\n'.join(errors)); raise SystemExit(1)
    print(f'PASS: {len(pages)} HTML pages; local links/anchors, catalog/search agreement and public-scope checks.')


if __name__ == '__main__':
    main()
