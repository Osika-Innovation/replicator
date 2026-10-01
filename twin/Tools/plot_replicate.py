#!/usr/bin/env python3
"""Draw a `fieldc replicate` run: the scan of the original, the shape read off
it with the powder copy molded on it, and the scan of the copy — top view
(x–y) and side view (x–z).

    python3 Tools/plot_replicate.py <object> [title]

reads Receipts/replicate_<object>_{scan0_mip,scan1_mip,grid,object,sites,copy}.csv,
writes shots/replicate_<object>.svg. Standard library only.
"""
import csv
import sys

name = sys.argv[1] if len(sys.argv) > 1 else "ring"
title = sys.argv[2] if len(sys.argv) > 2 else f"The replicator's loop in the twin: scan, read, mold, scan ({name})"
base = f"Receipts/replicate_{name}"
h, n = [float(v) for v in open(base + "_grid.csv").read().split(",")]
n = int(n)


def mips(path):
    out = {}
    for r in csv.DictReader(open(path)):
        out.setdefault(r["view"], {})[(int(r["i"]), int(r["j"]))] = float(r["value"])
    return out


def points(path, extra=None):
    rows = list(csv.DictReader(open(path)))
    return [(float(r["x_mm"]), float(r["y_mm"]), float(r["z_mm"])) + ((int(r[extra]),) if extra else ()) for r in rows]


scan0, scan1 = mips(base + "_scan0_mip.csv"), mips(base + "_scan1_mip.csv")
obj, sites, copy = points(base + "_object.csv"), points(base + "_sites.csv", "grains"), points(base + "_copy.csv")


def colour(v):
    stops = [(0.0, (8, 10, 30)), (0.35, (30, 70, 170)), (0.6, (40, 170, 200)), (0.85, (240, 220, 80)), (1.0, (255, 255, 255))]
    v = max(0.0, min(1.0, v))
    for (a, ca), (b, cb) in zip(stops, stops[1:]):
        if v <= b:
            t = (v - a) / (b - a)
            return "#%02x%02x%02x" % tuple(int(ca[k] + t * (cb[k] - ca[k])) for k in range(3))
    return "#ffffff"


cell = 260.0 / n
size = cell * n
pad, top = 40, 84
W = int(3 * size + 4 * pad)
H = int(top + 2 * (size + 34) + 60)
ink, mute = "#1f2328", "#57606a"
out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" '
       f'font-family="-apple-system, Helvetica, Arial, sans-serif">',
       f'<rect width="{W}" height="{H}" fill="#ffffff"/>',
       f'<text x="{pad}" y="28" font-size="15" font-weight="600" fill="{ink}">{title}</text>',
       f'<text x="{pad}" y="48" font-size="11.5" fill="{mute}">left: the scan of the original (white dots: the object). '
       f'middle: sites read off that scan (red) and the powder molded on them (gold).</text>',
       f'<text x="{pad}" y="64" font-size="11.5" fill="{mute}">right: the scan of the copy. Images are maximum-intensity '
       f'projections of the matched field, 30–100 kHz, the plate array in open air.</text>']
views = [("xy", 0, 1, "x–y"), ("xz", 0, 2, "x–z")]
for row, (view, a, b, label) in enumerate(views):
    y0 = top + row * (size + 34)
    for col in range(3):
        x0 = pad + col * (size + pad)
        if col in (0, 2):
            for (i, j), v in (scan0 if col == 0 else scan1)[view].items():
                out.append(f'<rect x="{x0 + i * cell:.1f}" y="{y0 + (n - 1 - j) * cell:.1f}" width="{cell + 0.3:.1f}" '
                           f'height="{cell + 0.3:.1f}" fill="{colour(v)}"/>')
            if col == 0:
                out.append('<g fill="#ffffff" fill-opacity="0.9" stroke="#000000" stroke-width="0.3">')
                for o in obj:
                    out.append(f'<circle cx="{x0 + (o[a] / h + 0.5) * cell:.1f}" cy="{y0 + (n - 1 - o[b] / h + 0.5) * cell:.1f}" r="1.3"/>')
                out.append('</g>')
        else:
            out.append(f'<rect x="{x0}" y="{y0}" width="{size:.0f}" height="{size:.0f}" fill="#0d1117"/>')
            out.append('<g fill="#e3b341" fill-opacity="0.6">')
            for g in copy:
                out.append(f'<circle cx="{x0 + (g[a] / h + 0.5) * cell:.1f}" cy="{y0 + (n - 1 - g[b] / h + 0.5) * cell:.1f}" r="0.8"/>')
            out.append('</g><g fill="none" stroke="#ff5555" stroke-width="1.1">')
            for s in sites:
                out.append(f'<circle cx="{x0 + (s[a] / h + 0.5) * cell:.1f}" cy="{y0 + (n - 1 - s[b] / h + 0.5) * cell:.1f}" r="4"/>')
            out.append('</g>')
        caption = ["scan of the original", "shape read + powder copy", "scan of the copy"][col]
        out.append(f'<text x="{x0 + size / 2:.0f}" y="{y0 + size + 16:.0f}" font-size="11.5" text-anchor="middle" fill="{ink}">'
                   f'{caption}, {label} ({(n - 1) * h:.0f} mm)</text>')
out.append(f'<text x="{pad}" y="{H - 18}" font-size="11" fill="{mute}">{len(sites)} sites read; {len(copy)} grains in the copy. '
           f'Open air, two plates of N elements; powder Ø40 µm PLA, gravity on, fallen grains sprinkled in again.</text>')
out.append('</svg>')
open(f"shots/replicate_{name}.svg", "w").write("\n".join(out))
print(f"wrote shots/replicate_{name}.svg ({len(sites)} sites, {len(copy)} grains)")
