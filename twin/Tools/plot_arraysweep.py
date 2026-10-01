#!/usr/bin/env python3
"""Draw `fieldc arraysweep` (study S1): what the channel count and the number
of tones buy in open air — the centre trap's uniqueness, where the ring
sieve's powder ends, and the acoustic power it takes.

    python3 Tools/plot_arraysweep.py [Receipts/arraysweep.csv] [shots/arraysweep.svg]

Standard library only.
"""
import csv
import math
import sys

src = sys.argv[1] if len(sys.argv) > 1 else "Receipts/arraysweep.csv"
dst = sys.argv[2] if len(sys.argv) > 2 else "shots/arraysweep.svg"
rows = [{k: float(v) for k, v in r.items()} for r in csv.DictReader(open(src))]
counts = sorted({int(r["per_plate"]) for r in rows})
tones = sorted({int(r["tones"]) for r in rows})
colours = {1: "#cf222e", 3: "#bf8700", 9: "#1a7f37", 20: "#0969da"}
ink, mute, grid = "#1f2328", "#57606a", "#eaeef2"

pw, ph, pad, top = 300, 220, 56, 76
W = 3 * pw + 4 * pad
H = top + ph + 96
out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" '
       f'font-family="-apple-system, Helvetica, Arial, sans-serif">',
       f'<rect width="{W}" height="{H}" fill="#ffffff"/>',
       f'<text x="{pad}" y="28" font-size="15" font-weight="600" fill="{ink}">Two plates in open air: '
       f'what the channel count and the tones buy</text>',
       f'<text x="{pad}" y="48" font-size="11.5" fill="{mute}">Ø410 mm plates 460 mm apart (R 0.9), N Ø5 mm elements per plate '
       f'on Vogel spirals; tones spread over 30–70 kHz; Ø40 µm PLA powder.</text>']


def xpos(x0, n):
    lo, hi = math.log10(min(counts)), math.log10(max(counts))
    return x0 + 20 + (math.log10(n) - lo) / (hi - lo) * (pw - 40)


panels = [
    ("trap_ratio", "centre trap: rival ÷ target well (< 0.5 = unique)", 0, 1.0, False, 0.5),
    ("on_shape", "ring sieve: powder on the ring (basin map)", 0, 1.0, False, 0.95),
    ("acoustic_W", "acoustic power to hold the powder (W)", 1, 10000, True, None),
]
for p, (key, label, ylo, yhi, logy, bar) in enumerate(panels):
    x0 = pad + p * (pw + pad)
    y0 = top

    def ypos(v):
        if logy:
            v = max(v, ylo)
            return y0 + ph - (math.log10(v) - math.log10(ylo)) / (math.log10(yhi) - math.log10(ylo)) * ph
        return y0 + ph - (min(max(v, ylo), yhi) - ylo) / (yhi - ylo) * ph
    out.append(f'<rect x="{x0}" y="{y0}" width="{pw}" height="{ph}" fill="none" stroke="#d0d7de"/>')
    ticks = [1, 10, 100, 1000, 10000] if logy else [0, 0.25, 0.5, 0.75, 1.0]
    for t in ticks:
        out.append(f'<line x1="{x0}" x2="{x0 + pw}" y1="{ypos(t):.1f}" y2="{ypos(t):.1f}" stroke="{grid}"/>')
        txt = f"{t:g}" if logy else f"{t:.2f}"
        out.append(f'<text x="{x0 - 6}" y="{ypos(t) + 4:.1f}" font-size="10" text-anchor="end" fill="{ink}">{txt}</text>')
    if bar is not None:
        out.append(f'<line x1="{x0}" x2="{x0 + pw}" y1="{ypos(bar):.1f}" y2="{ypos(bar):.1f}" stroke="#57606a" '
                   f'stroke-dasharray="4 3"/>')
    for n in counts:
        out.append(f'<text x="{xpos(x0, n):.1f}" y="{y0 + ph + 16}" font-size="10" text-anchor="middle" fill="{ink}">{n}</text>')
    out.append(f'<text x="{x0 + pw / 2}" y="{y0 + ph + 32}" font-size="11" text-anchor="middle" fill="{ink}">elements per plate</text>')
    out.append(f'<text x="{x0}" y="{y0 - 8}" font-size="11.5" fill="{ink}">{label}</text>')
    for t in tones:
        pts = sorted((int(r["per_plate"]), r[key]) for r in rows if int(r["tones"]) == t)
        c = colours.get(t, "#8250df")
        out.append(f'<polyline points="{" ".join(f"{xpos(x0, n):.1f},{ypos(v):.1f}" for n, v in pts)}" fill="none" '
                   f'stroke="{c}" stroke-width="2"/>')
        for n, v in pts:
            out.append(f'<circle cx="{xpos(x0, n):.1f}" cy="{ypos(v):.1f}" r="3" fill="{c}"/>')
# legend
lx = pad
for t in tones:
    c = colours.get(t, "#8250df")
    out.append(f'<line x1="{lx}" x2="{lx + 22}" y1="{H - 30}" y2="{H - 30}" stroke="{c}" stroke-width="2"/>')
    out.append(f'<text x="{lx + 28}" y="{H - 26}" font-size="11" fill="{ink}">{t} tone{"s" if t > 1 else ""}</text>')
    lx += 90
out.append(f'<text x="{lx + 10}" y="{H - 26}" font-size="11" fill="{mute}">Channels buy power; tones buy confinement '
           f'along the axis (the plates make standing waves every λ/2).</text>')
out.append('</svg>')
open(dst, "w").write("\n".join(out))
print(f"wrote {dst}: {len(rows)} points")
