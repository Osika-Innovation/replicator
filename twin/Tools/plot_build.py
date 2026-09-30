#!/usr/bin/env python3
"""Draw a `fieldc build`: the beads' paths and where they came to rest.

Reads Receipts/build_trajectories.csv and Receipts/build_placed.csv (written
by `fieldc build --receipt`) and writes shots/build_row.svg — a side view
(x–z, equal scales, so beads are round) of every bead's path from the pick-up
down onto the support, and a top view (x–y) of the finished row. Standard
library only.

    python3 Tools/plot_build.py [trajectories.csv] [placed.csv] [out.svg]
"""
import csv
import sys

traj_src = sys.argv[1] if len(sys.argv) > 1 else "Receipts/build_trajectories.csv"
placed_src = sys.argv[2] if len(sys.argv) > 2 else "Receipts/build_placed.csv"
dst = sys.argv[3] if len(sys.argv) > 3 else "shots/build_row.svg"

paths = {}
for r in csv.DictReader(open(traj_src)):
    paths.setdefault(int(r["bead"]), []).append((float(r["x_mm"]), float(r["y_mm"]), float(r["z_mm"])))
placed = [(int(r["bead"]), float(r["x_mm"]), float(r["y_mm"]), float(r["z_mm"]), int(r["on"]))
          for r in csv.DictReader(open(placed_src))]
radius = 0.1                                   # mm (Ø200 µm PLA)
support = min(p[3] for p in placed) - radius   # the plane the beads rest on

colours = ["#0969da", "#1a7f37", "#bf8700", "#8250df", "#cf222e", "#1b7c83", "#953800", "#bc4c00"]
ink, grid = "#1f2328", "#d0d7de"

# Side view: x from the pick-up to past the last bead, z from below the support to above the pick-up.
x0, x1 = -0.4, max(p[1] for p in placed) + 0.5
z0, z1 = support - 0.3, 0.4
scale = 330.0                                  # px per mm, both axes
W1, H1 = (x1 - x0) * scale, (z1 - z0) * scale
left, top = 70, 58
sx = lambda x: left + (x - x0) * scale
sz = lambda z: top + (z1 - z) * scale

# Top view of the row, zoomed.
xs = [p[1] for p in placed]
tx0, tx1 = min(xs) - 0.25, max(xs) + 0.25
ty0, ty1 = -0.25, 0.25
tscale = 520.0
W2, H2 = (tx1 - tx0) * tscale, (ty1 - ty0) * tscale
left2 = left + W1 + 60
tsx = lambda x: left2 + (x - tx0) * tscale
tsy = lambda y: top + (ty1 - y) * tscale

W = int(left2 + W2 + 30)
H = int(top + max(H1, H2) + 70)
out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" '
       f'font-family="-apple-system, Helvetica, Arial, sans-serif">',
       f'<rect width="{W}" height="{H}" fill="#ffffff"/>',
       f'<text x="{left}" y="26" font-size="15" font-weight="600" fill="{ink}">The twin\'s first build: '
       f'{len(placed)} Ø200 µm PLA beads laid in a row in the glass chamber</text>',
       f'<text x="{left}" y="44" font-size="11.5" fill="{ink}">side view (mm from the pick-up trap) — each bead\'s '
       f'path from the pick-up down onto the support</text>',
       f'<text x="{left2}" y="44" font-size="11.5" fill="{ink}">top view of the finished row (mm)</text>']
# Side view frame and grid.
out.append(f'<rect x="{left}" y="{top}" width="{W1:.0f}" height="{H1:.0f}" fill="none" stroke="{grid}"/>')
v = -2.5
while v <= z1:
    if v >= z0:
        out.append(f'<line x1="{left}" x2="{left + W1:.0f}" y1="{sz(v):.1f}" y2="{sz(v):.1f}" stroke="{grid}" stroke-width="0.6"/>')
        out.append(f'<text x="{left - 8}" y="{sz(v) + 4:.1f}" font-size="11" text-anchor="end" fill="{ink}">{v:g}</text>')
    v += 0.5
v = 0.0
while v <= x1:
    out.append(f'<text x="{sx(v):.1f}" y="{top + H1 + 16:.0f}" font-size="11" text-anchor="middle" fill="{ink}">{v:g}</text>')
    v += 0.5
# Support.
out.append(f'<rect x="{left}" y="{sz(support):.1f}" width="{W1:.0f}" height="{(support - z0) * scale:.1f}" fill="#eaeef2"/>')
out.append(f'<line x1="{left}" x2="{left + W1:.0f}" y1="{sz(support):.1f}" y2="{sz(support):.1f}" stroke="#57606a" stroke-width="1.4"/>')
out.append(f'<text x="{left + W1 - 6:.0f}" y="{sz(support) + 16:.1f}" font-size="11" text-anchor="end" fill="{ink}">support</text>')
# Pick-up.
out.append(f'<circle cx="{sx(0):.1f}" cy="{sz(0):.1f}" r="4" fill="none" stroke="{ink}" stroke-width="1.2"/>')
out.append(f'<text x="{sx(0) + 8:.1f}" y="{sz(0) - 8:.1f}" font-size="11" fill="{ink}">pick-up</text>')
# Paths, then beads.
for k, pts in sorted(paths.items()):
    c = colours[k % len(colours)]
    d = " ".join(f"{sx(p[0]):.1f},{sz(p[2]):.1f}" for p in pts)
    out.append(f'<polyline points="{d}" fill="none" stroke="{c}" stroke-width="1.2" stroke-opacity="0.8"/>')
for k, x, y, z, on in placed:
    c = colours[k % len(colours)]
    out.append(f'<circle cx="{sx(x):.1f}" cy="{sz(z):.1f}" r="{radius * scale:.1f}" fill="{c}" fill-opacity="0.85" stroke="{ink}" stroke-width="0.8"/>')
    out.append(f'<text x="{sx(x):.1f}" y="{sz(z) + 4:.1f}" font-size="11" font-weight="600" text-anchor="middle" fill="#ffffff">{k}</text>')
# Top view.
out.append(f'<rect x="{left2:.0f}" y="{top}" width="{W2:.0f}" height="{H2:.0f}" fill="#eaeef2" stroke="{grid}"/>')
for k, x, y, z, on in placed:
    c = colours[k % len(colours)]
    out.append(f'<circle cx="{tsx(x):.1f}" cy="{tsy(y):.1f}" r="{radius * tscale:.1f}" fill="{c}" fill-opacity="0.85" stroke="{ink}" stroke-width="0.8"/>')
    out.append(f'<text x="{tsx(x):.1f}" y="{tsy(y) + 4:.1f}" font-size="12" font-weight="600" text-anchor="middle" fill="#ffffff">{k}</text>')
for v in (tx0 + 0.05, (tx0 + tx1) / 2, tx1 - 0.05):
    out.append(f'<text x="{tsx(v):.1f}" y="{top + H2 + 16:.0f}" font-size="11" text-anchor="middle" fill="{ink}">{v:.2f}</text>')
gaps = [((placed[i][1] - placed[i - 1][1]) ** 2 + (placed[i][2] - placed[i - 1][2]) ** 2) ** 0.5 * 1000 - 2 * radius * 1000
        for i in range(1, len(placed))]
out.append(f'<text x="{left2:.0f}" y="{top + H2 + 38:.0f}" font-size="11.5" fill="{ink}">gaps between neighbours: '
           + ", ".join(f"{g:.0f} µm" for g in gaps) + '</text>')
out.append(f'<text x="{left}" y="{H - 14}" font-size="11" fill="#57606a">Gor\'kov force from the exact glass-chamber modes '
           f'(10 tones, 4× holding drive), gravity, air drag; beads fuse where they first touch. Not modelled: scattering by the '
           f'support and placed beads, streaming.</text>')
out.append('</svg>')
open(dst, "w").write("\n".join(out))
print(f"wrote {dst}: {len(placed)} beads, {sum(len(p) for p in paths.values())} path samples")
