#!/usr/bin/env python3
"""Draw a `fieldc mold` run: the powder at release and at the end, seen from
above (x–y) and from the side (x–z), with the target wells.

    python3 Tools/plot_mold.py <shape> [title]

reads Receipts/mold_<shape>_{grains,targets}.csv, writes shots/mold_<shape>.svg.
Standard library only.
"""
import csv
import sys

shape = sys.argv[1] if len(sys.argv) > 1 else "ring"
title = sys.argv[2] if len(sys.argv) > 2 else f"A single-shot acoustic mold ({shape})"
rows = list(csv.DictReader(open(f"Receipts/mold_{shape}_grains.csv")))
times = sorted({float(r["t_s"]) for r in rows})
t_first, t_last = times[0], times[-1]
frames = {t: [(float(r["x_mm"]), float(r["y_mm"]), float(r["z_mm"])) for r in rows if float(r["t_s"]) == t]
          for t in (t_first, t_last)}
targets = [(float(r["x_mm"]), float(r["y_mm"]), float(r["z_mm"]), int(r["grains"]))
           for r in csv.DictReader(open(f"Receipts/mold_{shape}_targets.csv"))]
span = 12.5                                     # mm, half-width of each panel
size, pad, top = 300, 44, 74
scale = size / (2 * span)
W, H = int(2 * size + 3 * pad), int(top + 2 * size + 30 + 72)
ink, mute = "#1f2328", "#57606a"
out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" '
       f'font-family="-apple-system, Helvetica, Arial, sans-serif">',
       f'<rect width="{W}" height="{H}" fill="#ffffff"/>',
       f'<text x="{pad}" y="28" font-size="15" font-weight="600" fill="{ink}">{title}</text>',
       f'<text x="{pad}" y="48" font-size="11.5" fill="{mute}">Ø40 µm powder released at random, then drifting in one '
       f'compiled field; red rings = the target wells (with the grains each holds at the end)</text>']
panels = [(t_first, 0, 1, "x–y", "released"), (t_first, 0, 2, "x–z", "released"),
          (t_last, 0, 1, "x–y", f"after {t_last:g} s"), (t_last, 0, 2, "x–z", f"after {t_last:g} s")]
for p, (t, a, b, name, when) in enumerate(panels):
    x0 = pad + (p % 2) * (size + pad)
    y0 = top + (p // 2) * (size + 30)
    out.append(f'<rect x="{x0}" y="{y0}" width="{size}" height="{size}" fill="#0d1117"/>')
    for g in frames[t]:
        u, v = g[a], g[b]
        if abs(u) <= span and abs(v) <= span:
            out.append(f'<circle cx="{x0 + (u + span) * scale:.1f}" cy="{y0 + (span - v) * scale:.1f}" r="0.9" '
                       f'fill="#e3b341" fill-opacity="0.75"/>')
    for tx in targets:
        out.append(f'<circle cx="{x0 + (tx[a] + span) * scale:.1f}" cy="{y0 + (span - tx[b]) * scale:.1f}" r="4.5" '
                   f'fill="none" stroke="#ff5555" stroke-width="1.2"/>')
    out.append(f'<text x="{x0 + size / 2:.0f}" y="{y0 + size + 18:.0f}" font-size="12" text-anchor="middle" fill="{ink}">'
               f'{name}, {when} ({2 * span:.0f} mm square)</text>')
filled = sum(1 for t in targets if t[3] > 0)
out.append(f'<text x="{pad}" y="{H - 16}" font-size="11" fill="{mute}">{filled}/{len(targets)} target wells hold '
           f'grains at the end. Exact glass-chamber fields; overdamped grains with gravity; grain–grain contact not modelled.</text>')
out.append('</svg>')
open(f"shots/mold_{shape}.svg", "w").write("\n".join(out))
print(f"wrote shots/mold_{shape}.svg ({len(frames[t_last])} grains at the end)")
