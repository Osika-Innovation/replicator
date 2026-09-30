#!/usr/bin/env python3
"""Draw a `fieldc scan3d` image: three maximum-intensity projections of the
matched-field image, with the true object's points on top.

    python3 Tools/plot_scan.py <object> [title]

reads Receipts/scan3d_<object>_{mip,object,grid}.csv, writes shots/scan_<object>.svg.
Standard library only.
"""
import csv
import sys

name = sys.argv[1] if len(sys.argv) > 1 else "tetra"
title = sys.argv[2] if len(sys.argv) > 2 else f"The twin scans a 3D object ({name}) from the six gates, 30–100 kHz"
h, n = [float(v) for v in open(f"Receipts/scan3d_{name}_grid.csv").read().split(",")]
n = int(n)
mips = {}
for r in csv.DictReader(open(f"Receipts/scan3d_{name}_mip.csv")):
    mips.setdefault(r["view"], {})[(int(r["i"]), int(r["j"]))] = float(r["value"])
obj = [(float(r["x_mm"]), float(r["y_mm"]), float(r["z_mm"])) for r in csv.DictReader(open(f"Receipts/scan3d_{name}_object.csv"))]


def colour(v):
    # A dark-to-bright ramp (black → blue → cyan → yellow → white).
    stops = [(0.0, (8, 10, 30)), (0.35, (30, 70, 170)), (0.6, (40, 170, 200)), (0.85, (240, 220, 80)), (1.0, (255, 255, 255))]
    v = max(0.0, min(1.0, v))
    for (a, ca), (b, cb) in zip(stops, stops[1:]):
        if v <= b:
            t = (v - a) / (b - a)
            return "#%02x%02x%02x" % tuple(int(ca[k] + t * (cb[k] - ca[k])) for k in range(3))
    return "#ffffff"


cell = max(3.0, 300.0 / n)
size = cell * n
pad, top = 50, 70
W = int(3 * size + 4 * pad)
H = int(top + size + 80)
out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" '
       f'font-family="-apple-system, Helvetica, Arial, sans-serif">',
       f'<rect width="{W}" height="{H}" fill="#ffffff"/>',
       f'<text x="{pad}" y="28" font-size="15" font-weight="600" fill="#1f2328">{title}</text>',
       f'<text x="{pad}" y="48" font-size="11.5" fill="#57606a">maximum-intensity projections of the matched-field image '
       f'(brighter = more likely an object there); white dots = the true object</text>']
views = [("xy", 0, 1, "x", "y"), ("xz", 0, 2, "x", "z"), ("yz", 1, 2, "y", "z")]
for p, (view, ax, ay, lx, ly) in enumerate(views):
    x0 = pad + p * (size + pad)
    for (i, j), v in mips[view].items():
        out.append(f'<rect x="{x0 + i * cell:.1f}" y="{top + (n - 1 - j) * cell:.1f}" width="{cell + 0.3:.1f}" '
                   f'height="{cell + 0.3:.1f}" fill="{colour(v)}"/>')
    for o in obj:
        u, w = o[ax] / h, o[ay] / h
        out.append(f'<circle cx="{x0 + (u + 0.5) * cell:.1f}" cy="{top + (n - 1 - w + 0.5) * cell:.1f}" r="1.6" '
                   f'fill="#ffffff" fill-opacity="0.9" stroke="#000000" stroke-width="0.4"/>')
    out.append(f'<text x="{x0 + size / 2:.0f}" y="{top + size + 18:.0f}" font-size="12" text-anchor="middle" fill="#1f2328">'
               f'{lx}–{ly} ({(n - 1) * h:.0f} mm square)</text>')
out.append(f'<text x="{pad}" y="{H - 16}" font-size="11" fill="#57606a">Exact glass-chamber fields, six gates, every '
           f'gate pair, point scatterers (Born); the chamber-only transfer is calibrated away; measurement noise added.</text>')
out.append('</svg>')
open(f"shots/scan_{name}.svg", "w").write("\n".join(out))
print(f"wrote shots/scan_{name}.svg ({n}³ grid, {len(obj)} object points)")
