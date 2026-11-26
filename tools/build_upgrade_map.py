#!/usr/bin/env python3
"""Generate the M01-M08 upgrade map fragments in docs/content/upgrades.md.

Source of truth: docs/assets/cad/modules.json (also read by the 3D viewer).
Writes three regions, each between <!-- generated:NAME:begin --> and <!-- generated:NAME:end -->:
  exploded  the exploded Rev S chassis diagram
  ladder    the zero-cables interconnect ladder (M02)
  cards     one swap card per module, Rung 1 -> 2 -> 3

Usage: python3 tools/build_upgrade_map.py [--check]
--check exits 1 if upgrades.md is out of date.
"""
import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODULES = ROOT / 'docs/assets/cad/modules.json'
PAGE = ROOT / 'docs/content/upgrades.md'

COLOR = {'M01': '#186b60', 'M02': '#9a542e', 'M03': '#2f5aa0', 'M04': '#7a4f9a',
         'M05': '#8f6d10', 'M06': '#3f7a28', 'M07': '#55616b', 'M08': '#a83f3f'}
SOFT = {'M01': '#e3efe9', 'M02': '#f4e8dd', 'M03': '#e2e9f5', 'M04': '#eee6f4',
        'M05': '#f3ecd5', 'M06': '#e4eedd', 'M07': '#e8ebed', 'M08': '#f5e1e1'}
BADGE = {'derived': ('Derived', 'bd-derived'), 'simulated': ('Simulated', 'bd-sim'),
         'documented': ('Documented', 'bd-doc'), 'decision': ('Design decision', 'bd-dec'),
         'open': ('Open', 'bd-open'), 'claim': ('Claim', 'bd-claim')}
e = html.escape


def chip(x, y, mid, w=46):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="22" rx="11" fill="{COLOR[mid]}"/>'
            f'<text x="{x + w / 2}" y="{y + 15.5}" text-anchor="middle" font-size="13" font-weight="700" fill="#fff">{mid}</text>')


def label(x, y, mid, line1, line2=None, anchor='start'):
    tx = x + 54 if anchor == 'start' else x - 54
    out = chip(x if anchor == 'start' else x - 46, y, mid)
    out += f'<text x="{tx}" y="{y + 16}" text-anchor="{anchor}" font-size="15" font-weight="600" fill="#173630">{e(line1)}</text>'
    if line2:
        out += f'<text x="{tx}" y="{y + 35}" text-anchor="{anchor}" font-size="13" fill="#4a5a54">{e(line2)}</text>'
    return out


def link(mid, name, inner):
    return f'<a href="#{mid.lower()}" aria-label="{mid} {e(name)}">{inner}</a>'


def exploded(mods):
    n = {m['id']: m['name'] for m in mods}
    s = []
    s.append('<svg viewBox="0 0 1010 740" role="img" aria-labelledby="ex-t ex-d" xmlns="http://www.w3.org/2000/svg" font-family="system-ui,sans-serif">')
    s.append('<title id="ex-t">Rev S pulled apart into the eight modules M01 to M08</title>')
    s.append('<desc id="ex-d">A side view of the Rev S machine pulled apart along its vertical axis. From top to bottom: the head shell (M07), the ceiling plate stack (M01), the glass build cylinder with six rear panels (M05), the mid-plane cassette (M01), the storage bucket (M06), the floor plate stack (M01) and the plinth with the compute bay (M03) and memory bay (M04). On the right a rear spine with the lift and two hard stops (M07), a service channel (M02) that runs up beside it, and sensor and safety points (M08).</desc>')
    s.append('<rect x="0" y="0" width="1010" height="740" fill="#fffefa"/>')
    s.append('<g transform="translate(70 0)">')
    # alignment guide
    s.append('<line x1="330" y1="22" x2="330" y2="722" stroke="#9fb3a8" stroke-width="1.2" stroke-dasharray="3 6"/>')
    s.append('<text x="330" y="16" text-anchor="middle" font-size="12" fill="#68736b">same axis and same seats: every module swaps in place</text>')
    # M07 head shell
    s.append(link('M07', n['M07'], f'<rect x="215" y="34" width="230" height="46" rx="12" fill="{SOFT["M07"]}" stroke="{COLOR["M07"]}" stroke-width="1.6"/><text x="330" y="62" text-anchor="middle" font-size="14" fill="#2f3d46">Head shell and top cap</text>'))
    # M01 stack 3
    s.append(link('M01', n['M01'], f'<ellipse cx="330" cy="140" rx="112" ry="17" fill="{SOFT["M01"]}" stroke="{COLOR["M01"]}" stroke-width="1.8"/><ellipse cx="330" cy="135" rx="112" ry="17" fill="#fff" stroke="{COLOR["M01"]}" stroke-width="1.8"/><text x="330" y="139" text-anchor="middle" font-size="13" fill="#173630">Stack 3 ceiling plate</text>'))
    # build cylinder + M05 panels
    s.append('<rect x="225" y="190" width="210" height="150" rx="6" fill="#eaf3f6" fill-opacity=".75" stroke="#8aa9b5" stroke-width="1.5"/>')
    s.append('<text x="330" y="356" text-anchor="middle" font-size="12" fill="#68736b">glass build cylinder (M07) with the six rear panels (M05)</text><text x="330" y="369" text-anchor="middle" font-size="12" fill="#68736b">drawn as seen from the front</text>')
    bars = ''.join(f'<rect x="{240 + i * 31}" y="204" width="22" height="122" rx="3" fill="{SOFT["M05"]}" stroke="{COLOR["M05"]}" stroke-width="1.4"/>' for i in range(6))
    s.append(link('M05', n['M05'], bars))
    # M01 stack 2 cassette with lift-out arrow
    s.append(link('M01', n['M01'], f'<ellipse cx="330" cy="415" rx="112" ry="17" fill="{SOFT["M01"]}" stroke="{COLOR["M01"]}" stroke-width="1.8"/><ellipse cx="330" cy="410" rx="112" ry="17" fill="#fff" stroke="{COLOR["M01"]}" stroke-width="1.8"/><text x="330" y="414" text-anchor="middle" font-size="13" fill="#173630">Stack 2 mid-plane cassette</text>'))
    s.append('<text x="330" y="446" text-anchor="middle" font-size="12" fill="#186b60" font-weight="600">↑ lifts out by hand</text>')
    # M06 bucket
    s.append(link('M06', n['M06'], f'<rect x="228" y="462" width="204" height="86" rx="8" fill="{SOFT["M06"]}" fill-opacity=".8" stroke="{COLOR["M06"]}" stroke-width="1.8"/><text x="330" y="510" text-anchor="middle" font-size="14" fill="#26441a">Storage bucket (glass)</text>'))
    # M01 stack 1
    s.append(link('M01', n['M01'], f'<ellipse cx="330" cy="610" rx="112" ry="17" fill="{SOFT["M01"]}" stroke="{COLOR["M01"]}" stroke-width="1.8"/><ellipse cx="330" cy="605" rx="112" ry="17" fill="#fff" stroke="{COLOR["M01"]}" stroke-width="1.8"/><text x="330" y="609" text-anchor="middle" font-size="13" fill="#173630">Stack 1 floor plate</text>'))
    # plinth
    s.append(f'<rect x="190" y="645" width="280" height="76" rx="12" fill="{SOFT["M07"]}" stroke="{COLOR["M07"]}" stroke-width="1.6"/>')
    s.append(link('M03', n['M03'], f'<rect x="204" y="662" width="110" height="46" rx="6" fill="{SOFT["M03"]}" stroke="{COLOR["M03"]}" stroke-width="1.6"/><text x="259" y="689" text-anchor="middle" font-size="13" fill="#1d3a6b">compute bay</text>'))
    s.append(link('M04', n['M04'], f'<rect x="326" y="662" width="130" height="46" rx="6" fill="{SOFT["M04"]}" stroke="{COLOR["M04"]}" stroke-width="1.6" stroke-dasharray="5 3"/><text x="391" y="689" text-anchor="middle" font-size="13" fill="#4d2f66">memory bay</text>'))
    # M07 spine
    s.append(link('M07', n['M07'], f'<rect x="504" y="70" width="24" height="650" rx="9" fill="{SOFT["M07"]}" stroke="{COLOR["M07"]}" stroke-width="1.6"/><rect x="498" y="592" width="36" height="9" rx="2" fill="{COLOR["M07"]}"/><text x="516" y="586" text-anchor="middle" font-size="12" fill="{COLOR["M07"]}">stops</text>'))
    # M02 channel
    s.append(link('M02', n['M02'], f'<path d="M559 690 V76" stroke="{COLOR["M02"]}" stroke-width="3" stroke-dasharray="9 6" fill="none"/>'
                  + ''.join(f'<path d="M559 {y} H452" stroke="{COLOR["M02"]}" stroke-width="2" stroke-dasharray="4 4" fill="none"/>' for y in (610, 410, 245, 135))))
    # M08 sensors
    dots = [(430, 262, 'air sensors'), (432, 540, 'bucket camera'), (470, 654, 'head-down switch'), (330, 626, 'echo test')]
    s.append(''.join(link('M08', n['M08'], f'<circle cx="{x}" cy="{y}" r="6" fill="{COLOR["M08"]}"/>') for x, y, _ in dots))
    s.append('<defs><marker id="ar" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8 Z" fill="#186b60"/></marker></defs>')
    s.append('</g>')
    # left labels with leaders: (chip y, module, line1, line2, leader to x at chip centre)
    L = [(43, 'M07', 'Head shell', 'moving head, 6.28 kg moves', 215), (121, 'M01', 'Boundary stacks', 'three swappable cartridges', 222),
         (241, 'M05', 'Rear active panels', 'six strips inside the glass', 240), (481, 'M06', 'Lower bucket and feed', 'holds the matter to build from', 228),
         (651, 'M03', 'Compute core', 'plug-in card on the plinth', 204), (702, 'M04', 'Pattern memory', 'bay still being drawn (#132)', 391)]
    s.append('<g stroke="#b9c4bb" stroke-width="1" fill="none">')
    for y, mid, a, b, xo in L:
        s.append(f'<path d="M262 {y + 10} H{xo + 70}"/>' if mid != 'M04' else f'<path d="M262 {y + 10} H{391 + 70} V709"/>')
    s.append('</g>')
    for y, mid, a, b, xo in L:
        s.append(label(34, y, mid, a, b))
    # right labels
    R = [(700, 'M07', 'Rear spine, lift and stops', 'brake-free: rests on 240.00 mm stops', 300),
         (700, 'M02', 'Service channel', 'copper now, fibre next, none last', 420),
         (700, 'M08', 'Sensors and safety', 'dots: air, camera, switch, echo test', 540)]
    for x, mid, a, b, y in R:
        s.append(label(x, y, mid, a, b))
    s.append('</svg>')
    return '\n'.join(x for x in s if x)


def ladder(mods):
    s = []
    s.append('<svg viewBox="0 0 900 400" role="img" aria-labelledby="lad-t lad-d" xmlns="http://www.w3.org/2000/svg" font-family="system-ui,sans-serif">')
    s.append('<title id="lad-t">The zero-cables ladder for module M02</title>')
    s.append('<desc id="lad-d">Three panels show the same machine skeleton, a plinth at the bottom, a spine and, at the top, the stacks and rear panels. In Rung 1 a copper loop and pogo pins link them. In Rung 2 a tube of optical fibres links them. In Rung 3 there is no cable: small optical waveguide chips pass light across gaps.</desc>')
    s.append('<rect width="900" height="400" fill="#fffefa"/>')
    heads = [('Rung 1 · copper', 'Derived (CAD)', '#9a542e'), ('Rung 2 · fibre bundles', 'Design decision; link budget Open', '#2f7a72'), ('Rung 3 · no cables', 'Claim', '#55616b')]
    for i, (t, bd, col) in enumerate(heads):
        x0 = 12 + i * 296
        s.append(f'<rect x="{x0}" y="12" width="280" height="376" rx="10" fill="#f7f7f2" stroke="#dce1d7"/>')
        s.append(f'<text x="{x0 + 14}" y="38" font-size="16" font-weight="700" fill="{col}">{t}</text>')
        s.append(f'<text x="{x0 + 14}" y="56" font-size="13" fill="#68736b">{bd}</text>')
        # skeleton
        s.append(f'<rect x="{x0 + 24}" y="300" width="90" height="38" rx="6" fill="{SOFT["M03"]}" stroke="{COLOR["M03"]}" stroke-width="1.4"/><text x="{x0 + 69}" y="323" text-anchor="middle" font-size="13" fill="#1d3a6b">plinth bays</text>')
        s.append(f'<rect x="{x0 + 150}" y="84" width="104" height="34" rx="6" fill="{SOFT["M01"]}" stroke="{COLOR["M01"]}" stroke-width="1.4"/><text x="{x0 + 202}" y="105" text-anchor="middle" font-size="13" fill="#173630">stacks M01</text>')
        s.append(f'<rect x="{x0 + 150}" y="170" width="104" height="34" rx="6" fill="{SOFT["M05"]}" stroke="{COLOR["M05"]}" stroke-width="1.4"/><text x="{x0 + 202}" y="191" text-anchor="middle" font-size="13" fill="#5c4609">panels M05</text>')
        s.append(f'<rect x="{x0 + 150}" y="250" width="104" height="34" rx="6" fill="{SOFT["M01"]}" stroke="{COLOR["M01"]}" stroke-width="1.4"/><text x="{x0 + 202}" y="271" text-anchor="middle" font-size="13" fill="#173630">stacks M01</text>')
        s.append(f'<rect x="{x0 + 130}" y="76" width="8" height="262" rx="3" fill="#dfe3e6" stroke="#9aa6ad"/>')
        s.append(f'<text x="{x0 + 126}" y="214" text-anchor="end" font-size="12" fill="#68736b">spine</text>')
    # rung 1 copper
    x0 = 12
    s.append(f'<path d="M{x0 + 114} 319 H{x0 + 134} V101 H{x0 + 150} M{x0 + 134} 187 H{x0 + 150} M{x0 + 134} 267 H{x0 + 150}" stroke="#b9602f" stroke-width="4.5" fill="none" stroke-linejoin="round"/>')
    for y in (101, 187, 267):
        s.append(f'<circle cx="{x0 + 150}" cy="{y}" r="4.5" fill="#fff" stroke="#9a542e" stroke-width="2"/>')
    s.append(f'<text x="{x0 + 14}" y="362" font-size="13" fill="#33443f">Flexible copper loop and spring</text><text x="{x0 + 14}" y="377" font-size="13" fill="#33443f">pogo pins at every cartridge rim.</text>')
    # rung 2 fibre
    x0 = 308
    s.append(f'<path d="M{x0 + 114} 319 H{x0 + 134} V101 H{x0 + 150} M{x0 + 134} 187 H{x0 + 150} M{x0 + 134} 267 H{x0 + 150}" stroke="#bfe0da" stroke-width="12" fill="none" stroke-linejoin="round" stroke-linecap="round"/>')
    for k, dx in enumerate((-3, -1, 1, 3)):
        s.append(f'<path d="M{x0 + 114} {319 + dx} H{x0 + 134 + dx} V101 H{x0 + 150} M{x0 + 134 + dx} 187 H{x0 + 150} M{x0 + 134 + dx} 267 H{x0 + 150}" stroke="#1f7a6f" stroke-width="1.3" fill="none"/>')
    s.append(f'<text x="{x0 + 14}" y="362" font-size="13" fill="#33443f">One fibre bundle in the same channel.</text><text x="{x0 + 14}" y="377" font-size="13" fill="#33443f">Light carries clock, pages and sensing.</text>')
    # rung 3 free space
    x0 = 604
    for y in (101, 187, 267):
        s.append(f'<rect x="{x0 + 146}" y="{y - 6}" width="8" height="12" rx="2" fill="#55616b"/>')
    s.append(f'<rect x="{x0 + 114}" y="313" width="8" height="12" rx="2" fill="#55616b"/>')
    s.append(f'<path d="M{x0 + 122} 319 C{x0 + 140} 300 {x0 + 144} 120 {x0 + 146} 104" stroke="#2f7a72" stroke-width="2" stroke-dasharray="3 5" fill="none"/>')
    s.append(f'<path d="M{x0 + 122} 319 C{x0 + 138} 290 {x0 + 142} 210 {x0 + 146} 190" stroke="#2f7a72" stroke-width="2" stroke-dasharray="3 5" fill="none"/>')
    s.append(f'<path d="M{x0 + 122} 319 C{x0 + 134} 300 {x0 + 140} 280 {x0 + 146} 270" stroke="#2f7a72" stroke-width="2" stroke-dasharray="3 5" fill="none"/>')
    s.append(f'<text x="{x0 + 14}" y="362" font-size="13" fill="#33443f">Waveguide chips and small mirrors pass</text><text x="{x0 + 14}" y="377" font-size="13" fill="#33443f">light across gaps. No cable at all.</text>')
    s.append('</svg>')
    return '\n'.join(s)


def badge_html(keys):
    return ''.join(f'<span class="bd {BADGE[k][1]}">{BADGE[k][0]}</span>' for k in keys)


def cards(mods):
    out = ['<div class="mod-grid">']
    for m in mods:
        col = COLOR[m['id']]
        out.append(f'<section class="mod-card" id="{m["id"].lower()}" style="--mc:{col}">')
        out.append(f'<header><span class="mod-chip">{m["id"]}</span><h3>{e(m["name"])}</h3></header>')
        out.append(f'<p class="mod-kid">{e(m["kid"])}</p>')
        out.append('<div class="mod-rungs">')
        for i, r in enumerate(m['rungs'], 1):
            out.append(f'<div class="mod-rung r{i}"><span class="mod-rn">Rung {i} · {e(r["title"])}</span>{badge_html(r["badges"])}<p>{e(r["text"])}</p></div>')
        out.append('</div>')
        links = ' · '.join(f'<a href="{e(h)}">{e(t)}</a>' for t, h in m['links'])
        out.append(f'<p class="mod-fixed"><strong>Stays fixed:</strong> {e(m["fixed"])}. <strong>Read more:</strong> {links}</p>')
        out.append('</section>')
    out.append('</div>')
    return '\n'.join(out)


def region(text, name, body):
    pat = re.compile(rf'(<!-- generated:{name}:begin -->\n).*?(<!-- generated:{name}:end -->)', re.S)
    if not pat.search(text):
        raise SystemExit(f'marker for {name} missing in {PAGE}')
    return pat.sub(lambda m: m.group(1) + body + '\n' + m.group(2), text)


def main():
    mods = json.loads(MODULES.read_text())['modules']
    text = PAGE.read_text()
    new = text
    new = region(new, 'exploded', '<div class="diagram">\n' + exploded(mods) + '\n<p>The Rev S machine pulled apart along its axis. Click a coloured label or shape to jump to that module\'s swap card. The picture is a schematic, not to scale. The 3D model on the <a href="cad-3d.html">CAD page</a> has the real geometry.</p>\n</div>')
    new = region(new, 'ladder', '<div class="diagram">\n' + ladder(mods) + '\n<p>The same machine skeleton three times. Rung 1 is the CAD design. Rung 2 is a design decision whose link budget is not yet calculated. Rung 3 is a claim.</p>\n</div>')
    new = region(new, 'cards', cards(mods))
    if '--check' in sys.argv:
        sys.exit(0 if new == text else 1)
    PAGE.write_text(new)
    print('upgrades.md regenerated from modules.json')


if __name__ == '__main__':
    main()
