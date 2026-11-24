#!/usr/bin/env python3
"""Summarise `fieldc p0 matrix` CSV receipts (Receipts/p0_*.csv) as a Markdown table.
   usage: Tools/p0_matrix_summary.py Receipts/p0_p2-*.csv"""
import csv, sys, collections

def rng(v, fmt="%.2f"):
    return "—" if not v else (fmt + "–" + fmt) % (min(v), max(v))

print("| run | calibration | gap mm | reflection | images | pass | refused | played and failed | travel error mm | absolute mm | plates left apart ° |")
print("|---|---|---:|---:|---:|---:|---:|---:|---|---|---|")
for path in sys.argv[1:]:
    groups = collections.OrderedDict()
    for r in csv.DictReader(open(path)):
        groups.setdefault((r["gap_mm"], r["reflection"], r["image_order"], r["calibration"], r["policy"]), []).append(r)
    name = path.split("/")[-1].replace("p0_", "").replace(".csv", "")
    for (gap, R, order, cal, policy), rows in groups.items():
        n = collections.Counter(r["outcome"] for r in rows)
        tr = [float(r["travel_mm"]) for r in rows if r["travel_mm"]]
        ab = [float(r["absolute_mm"]) for r in rows if r["absolute_mm"]]
        bp = [abs(float(r["between_plates_deg"])) for r in rows]
        print(f"| {name} ({policy.split('/')[-1]}) | {cal} | {float(gap):g} | {float(R):g} | {order} | {n['pass']} of {len(rows)} | {n['refused']} | {n['lost'] + n['off']} | {rng(tr)} | {rng(ab)} | {rng(bp, '%.1f')} |")
