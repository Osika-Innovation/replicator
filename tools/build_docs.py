#!/usr/bin/env python3
"""Build the explicitly selected public handbook. No sibling-repo discovery."""
import hashlib
import html
import json
import os
from pathlib import Path
import posixpath
import re
import shutil
import subprocess
from urllib.parse import quote, unquote, urlsplit, urljoin

import markdown

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '_site'
CAT = json.loads((ROOT / 'docs/catalog.json').read_text())
DOCS = CAT['documents']
REPO = CAT['repository']
SOURCE_MAP = {d['source']: d['url'] for d in DOCS}
# Source papers link to the maintainable Markdown guides.
SOURCE_MAP.update({f"docs/guides/{Path(d['source']).stem}.md": d['url']
                   for d in DOCS if d['type'] == 'guide'})
SOURCES = json.loads((ROOT / 'docs/sources.json').read_text())
TEMPLATE = (ROOT / 'docs/theme/shell.html').read_text()
MISSING = {}
LINK_NOTES = []
INDEX = []


def esc(value):
    return html.escape(str(value), quote=True)


def relative(target, current):
    return posixpath.relpath(target, posixpath.dirname(current) or '.')


def sidebar(current):
    groups = {}
    for d in DOCS:
        if d['type'] == 'guide':
            groups.setdefault(d['group'], []).append(d)
    result = []
    for group, docs in groups.items():
        links = ''.join(f'<li><a href="{esc(relative(d["url"], current))}"'
                        + (' aria-current="page"' if d['url'] == current else '')
                        + f'>{esc(d["title"])}</a></li>' for d in docs)
        result.append(f'<section><h2>{esc(group)}</h2><ul>{links}</ul></section>')
    return ''.join(result)


def shell(title, description, content, url, source, toc='', status='Current guide'):
    values = {'TITLE': esc(title), 'DESCRIPTION': esc(description),
              'BASE': './' if '/' not in url else '../', 'CONTENT': content,
              'SIDEBAR': sidebar(url), 'TOC': toc,
              'META': f'<span class="status">{esc(status)}</span><span>Reviewed {CAT["updated"]}</span>',
              'SOURCE_URL': esc(f'{REPO}/blob/main/{source}')}
    rendered = TEMPLATE
    for key, value in values.items():
        rendered = rendered.replace('{{' + key + '}}', value)
    return rendered


def missing_reference(original, current):
    name = Path(urlsplit(original).path).name or 'reference'
    key = re.sub(r'[^a-z0-9]+', '-', name.lower()).strip('-')
    MISSING.setdefault(key, {'name': name, 'pages': set()})['pages'].add(current)
    LINK_NOTES.append({'page': current, 'reference': name, 'action': 'reference-availability notice'})
    return relative('references.html', current) + '#' + key


def rewrite_paper_links(text, d):
    def replace(match):
        attr, delim, raw = match.groups()
        value = html.unescape(raw)
        parsed = urlsplit(value)
        if not value or value.startswith('#') or parsed.scheme or value.startswith('//'):
            return match.group(0)
        path = posixpath.normpath(posixpath.join(posixpath.dirname(d['source']), unquote(parsed.path)))
        if path in SOURCE_MAP:
            target = relative(SOURCE_MAP[path], d['url'])
            if parsed.fragment:
                target += '#' + parsed.fragment
        elif not path.startswith('../') and (ROOT / path).is_file():
            ext = Path(path).suffix.lower()
            if attr.lower() == 'src' and ext in {'.png', '.jpg', '.jpeg', '.svg', '.webp', '.gif'}:
                digest = hashlib.sha256(path.encode()).hexdigest()[:12]
                dest = 'assets/papers/' + digest + ext
                (OUT / dest).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / path, OUT / dest)
                target = relative(dest, d['url'])
            else:
                target = REPO + '/blob/main/' + quote(path, safe='/')
                if parsed.fragment:
                    target += '#' + parsed.fragment
        else:
            target = missing_reference(value, d['url'])
        return attr + '=' + delim + esc(target) + delim
    return re.sub(r'\b(href|src)\s*=\s*([\"\'])(.*?)\2', replace, text, flags=re.I)


def text_content(content):
    content = re.sub(r'<(script|style|svg)\b.*?</\1>', ' ', content, flags=re.S | re.I)
    return re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', content))).strip()


def agent_text(text, url):
    """Make exported text independently navigable at every entry point."""
    base = CAT['site_url'] + url
    def md_link(m):
        target = m.group(2)
        return m.group(1) + urljoin(base, target) + ')'
    text = re.sub(r'(\]\()([^\s)]+)\)', md_link, text)
    text = re.sub(r'href="([^\"]+)"', lambda m: 'href="' + esc(urljoin(base, html.unescape(m.group(1)))) + '"', text)
    return 'Canonical page: ' + base + '\n\n' + text


def write(url, value):
    p = OUT / url
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(value)


def build():
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir()
    shutil.copytree(ROOT / 'docs/assets', OUT / 'assets')
    source_hashes = {}
    for d in DOCS:
        source = ROOT / d['source']
        if not source.is_file() or not source.resolve().is_relative_to(ROOT.resolve()):
            raise ValueError('Invalid public source: ' + d['source'])
        raw = source.read_text()
        source_hashes[d['source']] = hashlib.sha256(raw.encode()).hexdigest()
        if d['type'] == 'guide':
            raw = re.sub(r'^---\n.*?\n---\n', '', raw, count=1, flags=re.S)
            if d['id'] == 'research':
                rows = ['| Paper | Role | Current use |', '|---|---|---|']
                for paper in [p for p in DOCS if p['type'] == 'paper']:
                    rows.append(f'| [{paper["title"]}]({relative(paper["url"], d["url"])}) | {paper["status"]} | {paper["summary"]} |')
                raw = raw.replace('<!-- PAPER_TABLE -->', '\n'.join(rows))
                rows = ['| ID / primary source | Engineering use | Review depth |', '|---|---|---|']
                for e in SOURCES['entries']:
                    title = e['title'].replace('|', '/')
                    note = e['possible_insight'].replace('|', '/')
                    rows.append(f'| {e["id"]} · [{title}]({e["canonical_url"]}) | {note} | {e["review_status"].replace("_", " ")} |')
                raw = raw.replace('<!-- SOURCE_TABLE -->', '\n'.join(rows))
            md = markdown.Markdown(extensions=['tables', 'fenced_code', 'toc', 'sane_lists'])
            body = md.convert(raw)
            output = shell(d['title'], d['summary'], body, d['url'], d['source'], md.toc)
            write('text/' + d['id'] + '.md', agent_text(raw, d['url']))
        else:
            output = rewrite_paper_links(raw, d)
            review = ('Updated engineering prose; see source for scope.' if d['status'] == 'Editorially updated'
                      else 'Preserved research/design paper. Use the handbook for the current configuration and implementation state.')
            nav = f'''<nav class="handbook-return" aria-label="Handbook navigation"><a href="../index.html">← Replicator Handbook</a><a href="../guides/research.html">Paper library</a><a href="../guides/architecture.html">Current architecture</a><a href="../guides/status.html">Current state</a></nav>
<aside class="handbook-context"><strong>{esc(d['status'])}</strong> · {esc(d['owner'])}<br>{esc(review)}<br><small>Navigation reviewed {d['reviewed']}. <a href="{REPO}/blob/main/{d['source']}">Source and history</a></small></aside>'''
            style = '<style>.handbook-return{display:flex;flex-wrap:wrap;gap:8px 20px;padding:14px 0;border-bottom:1px solid #ccd6cf;font:14px system-ui,sans-serif}.handbook-return a{color:#165f55}.handbook-return + .handbook-context + .banner{margin-top:0}.handbook-context{margin:18px 0;padding:15px 18px;background:#eef4ef;border-left:3px solid #186b60;font:14px/1.6 system-ui,sans-serif;color:#173630}</style>'
            output = output.replace('</head>', style + '</head>', 1)
            output = re.sub(r'(<body\b[^>]*>)', lambda m: m.group(1) + nav, output, count=1, flags=re.I)
            if '<meta name="viewport"' not in output:
                output = output.replace('</head>', '<meta name="viewport" content="width=device-width, initial-scale=1"></head>', 1)
        write(d['url'], output)
        INDEX.append({k: d[k] for k in ('id', 'title', 'summary', 'url', 'topics', 'type', 'status')} | {'text': text_content(raw)})

    sections = ['<h1>Companion references</h1><p>These references occur in the preserved papers but are outside this public release. The handbook supplies the current engineering explanation. No private source is copied into this site.</p>']
    for key, ref in sorted(MISSING.items()):
        sections.append(f'<section id="{esc(key)}"><h2>{esc(ref["name"].replace("_", " "))}</h2><p>Companion source not included in the public corpus.</p><p><a href="guides/research.html">Research library</a> · <a href="guides/materials.html">Materials and modes</a> · <a href="guides/architecture.html">Architecture</a></p></section>')
    write('references.html', shell('Companion references', 'Availability of companion sources', ''.join(sections), 'references.html', 'docs/catalog.json', status='Reference availability'))
    not_found = shell('Page not found', 'Return to the handbook', '<h1>Find your way back.</h1><p>This address is not in the current handbook. <a href="index.html">Start at the project map</a> or search for a topic.</p>', '404.html', 'docs/catalog.json')
    # Pages serves this document at the missing URL, including nested paths.
    write('404.html', not_found.replace('<head>', '<head><base href="' + esc(CAT['site_url']) + '">', 1))

    # Repair historical fragments by linking to the existing owning document.
    from html.parser import HTMLParser
    class IDs(HTMLParser):
        def __init__(self):
            super().__init__(); self.ids = set()
        def handle_starttag(self, tag, attrs):
            a = dict(attrs)
            if a.get('id'): self.ids.add(a['id'])
            if tag == 'a' and a.get('name'): self.ids.add(a['name'])
    ids = {}
    for p in OUT.rglob('*.html'):
        parser = IDs(); parser.feed(p.read_text()); ids[p.relative_to(OUT).as_posix()] = parser.ids
    for d in [p for p in DOCS if p['type'] == 'paper']:
        p = OUT / d['url']; data = p.read_text()
        def fragment(m):
            val = html.unescape(m.group(2)); u = urlsplit(val)
            if u.scheme or not u.fragment: return m.group(0)
            target = posixpath.normpath(posixpath.join(posixpath.dirname(d['url']), u.path)) if u.path else d['url']
            if target in ids and unquote(u.fragment) not in ids[target]:
                LINK_NOTES.append({'page': d['url'], 'reference': val, 'action': 'removed stale fragment; retained owning document'})
                return 'href=' + m.group(1) + esc(u.path or Path(d['url']).name) + m.group(1)
            return m.group(0)
        p.write_text(re.sub(r'href=([\"\'])(.*?)\1', fragment, data))

    write('catalog.json', json.dumps(CAT, indent=2, ensure_ascii=False) + '\n')
    write('sources.json', json.dumps(SOURCES, indent=2, ensure_ascii=False) + '\n')
    write('document-index.json', json.dumps(INDEX, ensure_ascii=False) + '\n')
    llms = ['# Etherworks Replicator Handbook', '', '> One enduring modular platform; minimum human engineering time; progressively self-made upgrades.', '', 'Read current-state, architecture and agent guidance before using a historical specification.', 'Evidence classes: design decision, derived, simulated, published experiment, bench measured, research hypothesis.', '', '## Documents']
    for d in DOCS:
        llms.append(f'- [{d["title"]}]({CAT["site_url"]}{d["url"]}): {d["summary"]} [{d["status"]}]')
    write('llms.txt', '\n'.join(llms) + '\n')
    write('llms-full.txt', '\n\n'.join((OUT / ('text/' + d['id'] + '.md')).read_text() for d in DOCS if d['type'] == 'guide'))
    write('sitemap.xml', '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' + ''.join('<url><loc>' + esc(CAT['site_url'] + d['url']) + '</loc><lastmod>' + d['reviewed'] + '</lastmod></url>' for d in DOCS) + '</urlset>\n')
    write('.nojekyll', '')
    try:
        revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    except subprocess.CalledProcessError:
        revision = 'unknown'
    receipt = {'revision': revision, 'documents': len(DOCS), 'sources': len(SOURCES['entries']), 'source_hashes': source_hashes, 'reference_adjustments': LINK_NOTES}
    write('build-manifest.json', json.dumps(receipt, indent=2) + '\n')
    print(f'Built {len(DOCS)} documents and {len(SOURCES["entries"])} sources; {len(MISSING)} unavailable companion references have explicit notices.')


if __name__ == '__main__':
    build()
