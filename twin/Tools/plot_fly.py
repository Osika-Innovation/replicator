#!/usr/bin/env python3
"""Plot a `fieldc fly` trajectory: the bead against the well it is carried in.

Reads Receipts/fly_trajectory_4x_40ms.csv (written by `fieldc fly --receipt`)
and writes shots/fly_4x_40ms.svg: height and sideways position of the bead
and of the target well against time. Standard library only.

    python3 Tools/plot_fly.py [csv] [svg]
"""
import csv
import sys

src = sys.argv[1] if len(sys.argv) > 1 else "Receipts/fly_trajectory_4x_40ms.csv"
dst = sys.argv[2] if len(sys.argv) > 2 else "shots/fly_4x_40ms.svg"

rows = list(csv.DictReader(open(src)))
t = [float(r["t_s"]) for r in rows]
series = {
    "bead z": [float(r["z_mm"]) for r in rows],
    "well z": [float(r["well_z_mm"]) for r in rows],
    "bead x": [float(r["x_mm"]) for r in rows],
    "well x": [float(r["well_x_mm"]) for r in rows],
}

W, H = 1040, 470
left, right, top, gap, panel = 64, 24, 48, 40, 160
t0, t1 = min(t), max(t)
ink, grid, bead, well = "#1f2328", "#d0d7de", "#0969da", "#cf222e"


def panel_svg(y0, key_bead, key_well, label):
    ys = series[key_bead] + series[key_well]
    lo, hi = min(ys) - 0.3, max(ys) + 0.3
    sx = lambda v: left + (v - t0) / (t1 - t0) * (W - left - right)
    sy = lambda v: y0 + panel - (v - lo) / (hi - lo) * panel
    out = [f'<rect x="{left}" y="{y0}" width="{W - left - right}" height="{panel}" fill="none" stroke="{grid}"/>']
    step = 1 if hi - lo > 4 else 0.5
    v = step * int(lo / step)
    while v <= hi:
        if v >= lo:
            out.append(f'<line x1="{left}" x2="{W - right}" y1="{sy(v):.1f}" y2="{sy(v):.1f}" stroke="{grid}" stroke-width="0.6"/>')
            out.append(f'<text x="{left - 8}" y="{sy(v) + 4:.1f}" font-size="11" text-anchor="end" fill="{ink}">{v:g}</text>')
        v += step
    for key, colour, dash in ((key_well, well, "6 4"), (key_bead, bead, "")):
        pts = " ".join(f"{sx(a):.1f},{sy(b):.2f}" for a, b in zip(t, series[key]))
        d = f' stroke-dasharray="{dash}"' if dash else ""
        out.append(f'<polyline points="{pts}" fill="none" stroke="{colour}" stroke-width="1.6"{d}/>')
    out.append(f'<text x="{left + 8}" y="{y0 + 16}" font-size="12" fill="{ink}">{label} (mm from the pick-up)</text>')
    return "\n".join(out)


axis_y = top + 2 * panel + gap + 18
ticks = []
tick = 0.0
while tick <= t1 + 1e-9:
    x = left + (tick - t0) / (t1 - t0) * (W - left - right)
    ticks.append(f'<text x="{x:.1f}" y="{axis_y}" font-size="11" text-anchor="middle" fill="{ink}">{tick:.1f}</text>')
    tick += 0.25
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="-apple-system, Helvetica, Arial, sans-serif">
<rect width="{W}" height="{H}" fill="#ffffff"/>
<text x="{left}" y="24" font-size="14" font-weight="600" fill="{ink}">A 200 µm PLA bead carried 5 mm up and 5 mm across · glass chamber, 10 tones, 4× holding drive, 40 ms per 0.25 mm step</text>
{panel_svg(top, "bead z", "well z", "height")}
{panel_svg(top + panel + gap, "bead x", "well x", "sideways")}
{"".join(ticks)}
<text x="{(W + left) / 2:.0f}" y="{axis_y + 18}" font-size="11" text-anchor="middle" fill="{ink}">time (s): gentle loading, carry up, carry across, hold</text>
<line x1="{W - 250}" x2="{W - 220}" y1="{H - 14}" y2="{H - 14}" stroke="{bead}" stroke-width="2"/>
<text x="{W - 214}" y="{H - 10}" font-size="11" fill="{ink}">bead (integrated)</text>
<line x1="{W - 110}" x2="{W - 80}" y1="{H - 14}" y2="{H - 14}" stroke="{well}" stroke-width="2" stroke-dasharray="6 4"/>
<text x="{W - 74}" y="{H - 10}" font-size="11" fill="{ink}">target well</text>
</svg>
'''
open(dst, "w").write(svg)
print(f"wrote {dst} ({len(rows)} samples, {t0:.2f}–{t1:.2f} s)")
