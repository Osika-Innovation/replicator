#!/usr/bin/env python3
"""Draw a `fieldc mold` run: the powder at release and at the end, seen from
above (x–y) and from the side (x–z), with the shape's sites, and — when the
run logged it — the share of the powder on the shape over time.

    python3 Tools/plot_mold.py <shape> [title] [note]

reads Receipts/mold_<shape>_{grains,targets,capture}.csv, writes
shots/mold_<shape>.svg. Standard library only.
"""
import csv
import math
import os
import sys

shape = sys.argv[1] if len(sys.argv) > 1 else "ring"
title = sys.argv[2] if len(sys.argv) > 2 else f"A single-shot acoustic mold ({shape})"
note = sys.argv[3] if len(sys.argv) > 3 else ""
rows = list(csv.DictReader(open(f"Receipts/mold_{shape}_grains.csv")))
times = sorted({float(r["t_s"]) for r in rows})
t_first, t_last = times[0], times[-1]
frames = {t: [(float(r["x_mm"]), float(r["y_mm"]), float(r["z_mm"])) for r in rows if float(r["t_s"]) == t]
          for t in (t_first, t_last)}
targets = [(float(r["x_mm"]), float(r["y_mm"]), float(r["z_mm"]), int(r["grains"]))
           for r in csv.DictReader(open(f"Receipts/mold_{shape}_targets.csv"))]
cap_src = f"Receipts/mold_{shape}_capture.csv"
capture = [(float(r["t_s"]), float(r["on_shape"])) for r in csv.DictReader(open(cap_src))] if os.path.exists(cap_src) else []

span = 12.5                                     # mm, half-width of each panel
size, pad, top = 300, 44, 74
scale = size / (2 * span)
chart_h = 150
W = int(2 * size + 3 * pad)
H = int(top + 2 * (size + 30) + (chart_h + 60 if capture else 0) + 40)
ink, mute = "#1f2328", "#57606a"
out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" '
       f'font-family="-apple-system, Helvetica, Arial, sans-serif">',
       f'<rect width="{W}" height="{H}" fill="#ffffff"/>',
       f'<text x="{pad}" y="28" font-size="15" font-weight="600" fill="{ink}">{title}</text>',
       f'<text x="{pad}" y="48" font-size="11.5" fill="{mute}">Ø40 µm powder released at random, then moving in one '
       f'compiled field; red rings = the sites (grain counts at the end)</text>']
panels = [(t_first, 0, 1, "x–y", "released"), (t_first, 0, 2, "x–z", "released"),
          (t_last, 0, 1, "x–y", f"after {t_last:g} s"), (t_last, 0, 2, "x–z", f"after {t_last:g} s")]
for p, (t, a, b, name, when) in enumerate(panels):
    x0 = pad + (p % 2) * (size + pad)
    y0 = top + (p // 2) * (size + 30)
    out.append(f'<rect x="{x0}" y="{y0}" width="{size}" height="{size}" fill="#0d1117"/>')
    out.append('<g fill="#e3b341" fill-opacity="0.75">')
    for g in frames[t]:
        u, v = g[a], g[b]
        if abs(u) <= span and abs(v) <= span:
            out.append(f'<circle cx="{x0 + (u + span) * scale:.1f}" cy="{y0 + (span - v) * scale:.1f}" r="0.9"/>')
    out.append('</g><g fill="none" stroke="#ff5555" stroke-width="1.2">')
    for tx in targets:
        out.append(f'<circle cx="{x0 + (tx[a] + span) * scale:.1f}" cy="{y0 + (span - tx[b]) * scale:.1f}" r="4.5"/>')
    out.append('</g>')
    if p == 2:                                  # grain counts beside the sites, top view at the end
        for tx in targets:
            out.append(f'<text x="{x0 + (tx[0] + span) * scale + 7:.1f}" y="{y0 + (span - tx[1]) * scale - 5:.1f}" '
                       f'font-size="9" fill="#ffaaaa">{tx[3]}</text>')
    out.append(f'<text x="{x0 + size / 2:.0f}" y="{y0 + size + 18:.0f}" font-size="12" text-anchor="middle" fill="{ink}">'
               f'{name}, {when} ({2 * span:.0f} mm square)</text>')
y = top + 2 * (size + 30)
if capture:
    # Share of the powder on the shape (within 1 mm of it) against time, log time axis.
    cx0, cy0, cw, ch = pad + 40, y + 20, W - 2 * pad - 50, chart_h
    ts = [c for c in capture if c[0] > 0]
    lo, hi = math.log10(min(t for t, _ in ts)), math.log10(max(t for t, _ in ts))
    sx = lambda t: cx0 + (math.log10(t) - lo) / (hi - lo) * cw
    sy = lambda f: cy0 + ch - f * ch
    out.append(f'<rect x="{cx0}" y="{cy0}" width="{cw}" height="{ch}" fill="none" stroke="#d0d7de"/>')
    for f in (0, 0.25, 0.5, 0.75, 1.0):
        out.append(f'<line x1="{cx0}" x2="{cx0 + cw}" y1="{sy(f):.1f}" y2="{sy(f):.1f}" stroke="#eaeef2"/>')
        out.append(f'<text x="{cx0 - 6}" y="{sy(f) + 4:.1f}" font-size="10" text-anchor="end" fill="{ink}">{int(f * 100)}%</text>')
    for t, _ in ts:
        out.append(f'<text x="{sx(t):.1f}" y="{cy0 + ch + 14}" font-size="10" text-anchor="middle" fill="{ink}">{t:g} s</text>')
    pts = " ".join(f"{sx(t):.1f},{sy(f):.1f}" for t, f in ts)
    out.append(f'<polyline points="{pts}" fill="none" stroke="#0969da" stroke-width="2"/>')
    for t, f in ts:
        out.append(f'<circle cx="{sx(t):.1f}" cy="{sy(f):.1f}" r="3" fill="#0969da"/>')
    out.append(f'<text x="{cx0}" y="{cy0 - 6}" font-size="11.5" fill="{ink}">share of the powder on the shape '
               f'(within 1 mm of it) over time</text>')
    y = cy0 + ch + 30
filled = sum(1 for t in targets if t[3] > 0)
out.append(f'<text x="{pad}" y="{y + 16}" font-size="11" fill="{mute}">{filled}/{len(targets)} sites hold grains at the end. '
           f'{note}</text>')
out.append('</svg>')
open(f"shots/mold_{shape}.svg", "w").write("\n".join(out))
print(f"wrote shots/mold_{shape}.svg ({len(frames[t_last])} grains at the end, {len(capture)} capture points)")
