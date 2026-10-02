#!/usr/bin/env python3
"""Draw a light view (`fieldc mold --light`): what a laser across the chamber
reads of the compiled field — the rms over tones of the phase each ray picks
up — with the mold's sites on top.

    python3 Tools/plot_light.py <base> [title]

reads Receipts/<base>_light.csv (j,k,rad, plus a header line with n and the
spacing) and Receipts/<base>_targets.csv; writes shots/<base>_light.svg.
Standard library only.
"""
import csv
import sys

base = sys.argv[1] if len(sys.argv) > 1 else "mold_plates192_ring"
title = sys.argv[2] if len(sys.argv) > 2 else "The field as light reads it"
lines = open(f"Receipts/{base}_light.csv").read().splitlines()
meta = dict(kv.split("=") for kv in lines[0].lstrip("# ").split())
n, h, half = int(meta["n"]), float(meta["spacing_mm"]), float(meta["half_mm"])
vals = {}
for r in csv.DictReader(lines[1:]):
    vals[(int(r["j"]), int(r["k"]))] = float(r["rad"])
peak = max(vals.values()) or 1
sites = [(float(r["x_mm"]), float(r["y_mm"]), float(r["z_mm"])) for r in csv.DictReader(open(f"Receipts/{base}_targets.csv"))]


def colour(v):
    stops = [(0.0, (8, 10, 30)), (0.35, (40, 40, 140)), (0.6, (170, 60, 160)), (0.85, (250, 170, 60)), (1.0, (255, 255, 230))]
    v = max(0.0, min(1.0, v))
    for (a, ca), (b, cb) in zip(stops, stops[1:]):
        if v <= b:
            t = (v - a) / (b - a)
            return "#%02x%02x%02x" % tuple(int(ca[q] + t * (cb[q] - ca[q])) for q in range(3))
    return "#ffffe6"


cell = max(2.0, 420.0 / n)
size = cell * n
pad, top = 50, 90
W, H = int(size + 2 * pad + 90), int(top + size + 84)
out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" '
       f'font-family="-apple-system, Helvetica, Arial, sans-serif">',
       f'<rect width="{W}" height="{H}" fill="#ffffff"/>',
       f'<text x="{pad}" y="28" font-size="15" font-weight="600" fill="#1f2328">{title}</text>',
       f'<text x="{pad}" y="47" font-size="11.5" fill="#57606a">a 633 nm laser along x through the chamber, strobed at</text>',
       f'<text x="{pad}" y="61" font-size="11.5" fill="#57606a">each tone: the phase each ray picks up (rms over tones)</text>',
       f'<text x="{pad}" y="75" font-size="11.5" fill="#57606a">peak {peak * 1000:.1f} mrad; '
       f'red circles: the mold\'s sites (y–z projection)</text>']
for (j, k), v in vals.items():
    out.append(f'<rect x="{pad + j * cell:.1f}" y="{top + (n - 1 - k) * cell:.1f}" width="{cell + 0.3:.1f}" '
               f'height="{cell + 0.3:.1f}" fill="{colour(v / peak)}"/>')
out.append('<g fill="none" stroke="#ff4040" stroke-width="1.2">')
for s in sites:
    u, w = (s[1] + half) / h, (s[2] + half) / h
    out.append(f'<circle cx="{pad + (u + 0.5) * cell:.1f}" cy="{top + (n - 1 - w + 0.5) * cell:.1f}" r="4"/>')
out.append('</g>')
out.append(f'<text x="{pad + size / 2:.0f}" y="{top + size + 18:.0f}" font-size="12" text-anchor="middle" fill="#1f2328">'
           f'y (across) – z (up), {2 * half:.0f} mm square</text>')
# colour bar
for i in range(100):
    out.append(f'<rect x="{pad + size + 20}" y="{top + size - (i + 1) * size / 100:.1f}" width="14" '
               f'height="{size / 100 + 0.5:.1f}" fill="{colour(i / 99)}"/>')
out.append(f'<text x="{pad + size + 40}" y="{top + 10}" font-size="10" fill="#1f2328">{peak * 1000:.1f} mrad</text>')
out.append(f'<text x="{pad + size + 40}" y="{top + size}" font-size="10" fill="#1f2328">0</text>')
out.append(f'<text x="{pad}" y="{H - 28}" font-size="11" fill="#57606a">Δφ = k_L (n₀ − 1)/(γ P₀) ∫ p dx: the measurement that calibrates</text>')
out.append(f'<text x="{pad}" y="{H - 14}" font-size="11" fill="#57606a">the twin against the real plates, and a rendering of the field.</text>')
out.append('</svg>')
open(f"shots/{base}_light.svg", "w").write("\n".join(out))
print(f"wrote shots/{base}_light.svg ({n}×{n} rays, peak {peak * 1000:.2f} mrad)")
