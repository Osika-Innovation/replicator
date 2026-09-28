#!/usr/bin/env python3
"""RH-1 STEP generator — the B-rep twin of the fieldc solid model.

Reads the parameter file written by `fieldc cad params` (the design, the four
faces, the horn/cone profiles, every sunflower site and slot outline) and
builds each part as an OpenCascade solid with CadQuery, then:

  * saves one STEP assembly with named, coloured components (imports into
    Fusion 360 / SolidWorks / FreeCAD as components, not loose bodies);
  * cross-checks every part's exact B-rep volume against the Swift mesh
    volume recorded in the parameter file — two independent geometry kernels
    agreeing is the gate (G-STEP), not either one alone.

Usage:  python3 rh1_step.py rh1_params.json rh1.step [--no-windings] [--report out.json]
Requires CadQuery 2.5 (OCP). Units mm, frame: floor z = 0, axis z, front +x.
"""
import json
import math
import sys
import time

import cadquery as cq
from cadquery import Vector as V

# material colours (spec §8 finishes) — mirrors CADMaterial.rgba in Swift
COLORS = {
    "anodized": (0.80, 0.73, 0.60, 1.0), "plateMetal": (0.19, 0.20, 0.22, 1.0),
    "columnMetal": (0.14, 0.14, 0.16, 1.0), "ceramic": (0.80, 0.75, 0.64, 1.0),
    "copper": (0.86, 0.47, 0.27, 1.0), "bronze": (0.66, 0.50, 0.26, 1.0),
    "pzt": (0.74, 0.75, 0.78, 1.0), "glass": (0.78, 0.90, 0.88, 0.25),
    "photonic": (0.42, 0.66, 0.72, 0.5), "former": (0.16, 0.15, 0.14, 1.0),
    "fr4": (0.16, 0.30, 0.20, 1.0), "polymer": (0.10, 0.10, 0.11, 1.0),
    "emissive": (1.00, 0.94, 0.82, 1.0), "placeholder": (0.46, 0.48, 0.52, 0.5),
}


def revolve_rz(pts, a0=0.0, sweep=360.0):
    """Revolve a closed (r, z) polygon about z; sectors start at azimuth a0."""
    w = cq.Wire.makePolygon([V(r, 0, z) for r, z in pts], close=True)
    s = cq.Solid.revolve(w, [], sweep, V(0, 0, 0), V(0, 0, 1))
    if a0:
        s = s.rotate(V(0, 0, 0), V(0, 0, 1), a0)
    return s


def tube(r0, r1, z0, z1, a0=0.0, sweep=360.0):
    if sweep >= 360.0 and r0 <= 0:
        return cq.Solid.makeCylinder(r1, z1 - z0, V(0, 0, z0), V(0, 0, 1))
    if sweep >= 360.0:
        outer = cq.Solid.makeCylinder(r1, z1 - z0, V(0, 0, z0), V(0, 0, 1))
        inner = cq.Solid.makeCylinder(r0, z1 - z0 + 2, V(0, 0, z0 - 1), V(0, 0, 1))
        return outer.cut(inner)
    return revolve_rz([(max(r0, 0), z0), (r1, z0), (r1, z1), (max(r0, 0), z1)], a0, sweep)


def box(cx, cy, cz, sx, sy, sz, az_deg):
    b = cq.Solid.makeBox(sx, sy, sz, V(-sx / 2, -sy / 2, -sz / 2))
    b = b.rotate(V(0, 0, 0), V(0, 0, 1), az_deg)
    return b.translate(V(cx, cy, cz))


def cylinder_axis(base, axis, radius, length):
    return cq.Solid.makeCylinder(radius, length, V(*base), V(*axis))


def build_plate(d, sites, slot_lines):
    """Ø410 × 12 face plate: collar hole, 12 slots, drilled biconical horns."""
    R, t = d["plateDiameter"] / 2, d["plateThickness"]
    plate = cq.Solid.makeCylinder(R, t, V(0, 0, 0), V(0, 0, 1))
    tools = [cq.Solid.makeCylinder(d["boreTubeOD"] / 2, t + 2, V(0, 0, -1), V(0, 0, 1))]
    for line in slot_lines:
        tools.append(slot_prism(line, -1.0, t + 2))
    for x, y, fr, tr, sub, _ in sites:
        if sub:
            continue
        prof = [(0, -0.5), (fr, -0.5), (fr, 0), (tr, t / 2), (fr, t), (fr, t + 0.5), (0, t + 0.5)]
        tools.append(revolve_rz(prof).translate(V(x, y, 0)))
    return plate.cut(cq.Compound.makeCompound(tools)), len(tools)


def slot_prism(line, z0, h, stride=4):
    """A spiral slot as 4 faces: two offset B-splines and two end arcs.

    The Swift mesh uses the same offset construction as a polygon; here the
    edges are splines through every `stride`-th offset point, which keeps a
    slot at 4 faces instead of ~420 and the STEP an order of magnitude smaller.
    """
    c = [V(x, y, z0) for x, y, _ in line]
    w = [ww for _, _, ww in line]
    n = len(c)
    left, right = [], []
    for i in range(n):
        tng = (c[min(n - 1, i + 1)] - c[max(0, i - 1)]).normalized()
        nrm = V(-tng.y, tng.x, 0)
        left.append(c[i] + nrm * (w[i] / 2))
        right.append(c[i] - nrm * (w[i] / 2))
    idx = list(range(0, n, stride))
    if idx[-1] != n - 1:
        idx.append(n - 1)
    e_left = cq.Edge.makeSpline([left[i] for i in idx])
    e_right = cq.Edge.makeSpline([right[i] for i in reversed(idx)])
    t_end = (c[-1] - c[-2]).normalized()
    t_start = (c[0] - c[1]).normalized()
    e_end = cq.Edge.makeThreePointArc(left[-1], c[-1] + t_end * (w[-1] / 2), right[-1])
    e_start = cq.Edge.makeThreePointArc(right[0], c[0] + t_start * (w[0] / 2), left[0])
    wire = cq.Wire.assembleEdges([e_left, e_end, e_right, e_start])
    return cq.Solid.extrudeLinear(wire, [], V(0, 0, h))


def winding_point(Rt, aw, zc, turns, hand, t):
    q = turns * t
    rr = Rt + aw * math.cos(q)
    return V(rr * math.cos(t), rr * math.sin(t), zc + hand * aw * math.sin(q))


def build_winding(Rt, aw, zc, turns, hand, radius, per_turn=16, turns_per_body=4):
    """A contrawound helix as end-to-end swept bodies.

    OCCT will not sweep one closed 44-turn periodic spine into a valid solid
    (MakePipeShell fails, Frenet/discrete-trihedron variants return invalid
    shapes at ~68% of the true volume), and fusing the open pieces back
    together fails at the tangent joints. Open multi-turn segments sweep
    cleanly and exactly, so each winding is a component of valid bodies.
    """
    nseg = max(1, turns // turns_per_body) if turns % turns_per_body == 0 else turns
    bodies = []
    for k in range(nseg):
        a, b = 2 * math.pi * k / nseg, 2 * math.pi * (k + 1) / nseg
        n = per_turn * turns // nseg
        pts = [winding_point(Rt, aw, zc, turns, hand, a + (b - a) * i / n) for i in range(n + 1)]
        e = cq.Edge.makeSpline(pts)
        prof = cq.Wire.makeCircle(radius, e.positionAt(0), e.tangentAt(0))
        bodies.append(cq.Solid.sweep(prof, [], cq.Wire.assembleEdges([e]), makeSolid=True))
    return cq.Compound.makeCompound(bodies)


def main():
    args = sys.argv[1:]
    if len(args) < 2:
        print(__doc__)
        return 2
    params_path, out_path = args[0], args[1]
    with_windings = "--no-windings" not in args
    report_path = args[args.index("--report") + 1] if "--report" in args else None
    P = json.load(open(params_path))
    d = P["design"]
    t0 = time.time()
    parts = []   # (key, name, material, shape, location or None)

    def add(asm, name, mat, solid, loc=None):
        parts.append((f"{asm}/{name}", name, mat, solid, loc))

    R = d["bodyDiameter"] / 2
    Ri = R - d["shellWall"]
    cap = d["overallHeight"] - d["crownCapThickness"]
    add("body", "bottom closure", "anodized", tube(0, R, 0, d["shellWall"]))
    add("body", "lower body tube", "anodized", tube(Ri, R, d["shellWall"], d["lowerBodyTop"]))
    add("body", "top band", "anodized", tube(Ri, R, d["chamberCeiling"], d["topBandTop"]))
    add("body", "crown", "anodized", tube(Ri, R, d["topBandTop"], cap))
    add("body", "crown cap", "anodized", tube(0, R, cap, d["overallHeight"]))
    storage_ceiling = [f for f in P["faces"] if f["id"] == "mid-down"][0]["faceZ"]
    l0 = d["storageLinerID"] / 2
    add("storage", "storage chamber liner", "anodized",
        tube(l0, l0 + d["storageLinerWall"], d["storageFloor"], storage_ceiling))

    tp = time.time()
    plate0, ntools = build_plate(d, P["sites"], P["slotCenterlines"])
    print(f"  face plate: {ntools} cutting tools, {time.time() - tp:.1f}s")
    pzt0 = cq.Solid.makeCylinder(d["pztDiameter"] / 2, d["pztThickness"], V(0, 0, 0), V(0, 0, 1))
    horn = [(r, dd) for r, dd in P["hornProfileRD"]]
    cone = [(r, dd) for r, dd in P["coneProfileRD"]]
    for f in P["faces"]:
        asm = f"plate.{f['id']}"
        zlo, zhi = min(f["faceZ"], f["backZ"]), max(f["faceZ"], f["backZ"])
        behind = 1.0 if f["facing"] == "down" else -1.0
        zb = lambda dd: f["backZ"] + behind * dd
        add(asm, f"face plate {f['id']}", "plateMetal", plate0, cq.Location(V(0, 0, zlo)))
        add(asm, f"carrier ring {f['id']}", "anodized",
            tube(d["plateDiameter"] / 2, d["carrierOD"] / 2, zlo, zhi))
        add(asm, f"gyroid horn {f['id']}", "ceramic", revolve_rz([(r, zb(dd)) for r, dd in horn]))
        add(asm, f"inner cone {f['id']}", "copper", revolve_rz([(r, zb(dd)) for r, dd in cone]))
        pz = min(zb(d["hornThroatDepth"]), zb(d["hornThroatDepth"] + d["pztThickness"]))
        for k in range(d["pztCount"]):
            az = math.radians(d["pztFirstAzimuthDeg"] + 360 * k / d["pztCount"])
            c = (d["pztPitchRadius"] * math.cos(az), d["pztPitchRadius"] * math.sin(az), pz)
            add(asm, f"throat piezo {f['id']}.{k + 1}", "pzt", pzt0, cq.Location(V(*c)))
        r0z, r1z = zb(d["rimDepthFrom"]), zb(d["rimDepthTo"])
        add(asm, f"rim electronics {f['id']}", "fr4",
            tube(d["rimInnerRadius"], d["rimOuterRadius"], min(r0z, r1z), max(r0z, r1z)))

    Rt, at = d["torusMajorDiameter"] / 2, d["torusTubeDiameter"] / 2
    winding0 = {}
    former0 = cq.Solid.makeTorus(Rt, at, V(0, 0, 0), V(0, 0, 1)).cut(
        cq.Solid.makeTorus(Rt, at - d["torusFormerWall"], V(0, 0, 0), V(0, 0, 1)))
    if with_windings:
        tw = time.time()
        for hand, gap in [(1, d["windingInnerLayerGap"]), (-1, d["windingOuterLayerGap"])]:
            winding0[hand] = build_winding(Rt, at + gap, 0.0, d["windingTurns"], hand,
                                           d["windingWireDiameter"] / 2)
        print(f"  windings: {time.time() - tw:.1f}s (2 prototypes, instanced ×3)")
    for a in P["assemblies"]:
        asm = f"torus.{a['id']}"
        loc = cq.Location(V(0, 0, a["torusZ"]))
        add(asm, f"torus former {a['id']}", "former", former0, loc)
        if with_windings:
            add(asm, f"winding {a['id']} CW (feed A)", "copper", winding0[1], loc)
            add(asm, f"winding {a['id']} CCW (feed B)", "bronze", winding0[-1], loc)

    faces = {f["id"]: f for f in P["faces"]}
    br0, br1 = d["boreDiameter"] / 2, d["boreTubeOD"] / 2
    top_end = faces["top"]["torusZ"] + at + 1
    add("bore", "bore collar top", "plateMetal", tube(br0, br1, faces["top"]["faceZ"], top_end))
    add("bore", "bore collar middle", "plateMetal",
        tube(br0, br1, faces["mid-down"]["faceZ"], faces["mid-up"]["faceZ"]))
    deck_bottom = faces["deck"]["torusZ"] - at - 36
    add("bore", "bore feed tube deck", "plateMetal", tube(br0, br1, deck_bottom, faces["deck"]["faceZ"]))

    # enclosure
    rg1 = d["rearGlassOD"] / 2
    add("enclosure", "rear glass (fixed)", "glass",
        tube(rg1 - d["glassWall"], rg1, d["chamberFloor"], d["chamberCeiling"], 90, 180))
    door = d["doorAngleDeg"]
    fg1 = d["frontGlassOD"] / 2
    bh = d["endBandHeight"]
    fz0, fz1 = d["chamberFloor"] + 1 + bh, d["chamberCeiling"] - 1 - bh
    add("enclosure", "front glass (rotating)", "glass",
        tube(fg1 - d["glassWall"], fg1, fz0, fz1, -90 + door, 180))
    b0, b1 = d["trackRingOuter"] + 0.5, fg1 + 1
    add("enclosure", "front glass lower end-band", "anodized", tube(b0, b1, fz0 - bh, fz0, -90 + door, 180))
    add("enclosure", "front glass upper end-band", "anodized", tube(b0, b1, fz1, fz1 + bh, -90 + door, 180))
    tr0, tr1, th = d["trackRingInner"], d["trackRingOuter"], d["trackRingHeight"]
    add("enclosure", "V-groove track lower", "anodized", tube(tr0, tr1, d["chamberFloor"], d["chamberFloor"] + th))
    add("enclosure", "V-groove track upper", "anodized", tube(tr0, tr1, d["chamberCeiling"] - th, d["chamberCeiling"]))
    rr = d["rollerDiameter"] / 2
    rmid = (tr0 + tr1) / 2
    for zc, label in [(d["chamberFloor"] + th + rr, "lower"), (d["chamberCeiling"] - th - rr, "upper")]:
        for k, rel in enumerate([-60.0, 0.0, 60.0]):
            az = math.radians(door + rel)
            dirv = (math.cos(az), math.sin(az), 0)
            base = (dirv[0] * (rmid - d["rollerWidth"] / 2), dirv[1] * (rmid - d["rollerWidth"] / 2), zc)
            add("enclosure", f"V-roller {label} {k + 1}", "polymer",
                cylinder_axis(base, dirv, rr, d["rollerWidth"]))

    # arcade and photonic bays
    ch = d["chamberCeiling"] - d["chamberFloor"]
    cr = d["columnInnerRadius"] + d["columnRadial"] / 2
    for k in range(d["columnCount"]):
        azd = 90 + d["columnPitchDeg"] * k
        az = math.radians(azd)
        add("arcade", f"arcade column {k + 1}", "columnMetal",
            box(cr * math.cos(az), cr * math.sin(az), d["chamberFloor"] + ch / 2,
                d["columnRadial"], d["columnTangential"], ch, azd))
        sr = d["columnInnerRadius"] - 0.35
        sh = ch - 2 * d["rxStripInset"]
        add("arcade", f"RX / status strip {k + 1}", "emissive",
            box(sr * math.cos(az), sr * math.sin(az), d["chamberFloor"] + ch / 2,
                0.7, d["rxStripWidth"], sh, azd))
    tm = d["tileOuterPlane"] - d["tileThickness"] / 2
    th2 = ch - 2 * d["tileMargin"]
    for k in range(d["tileCount"]):
        azd = 105 + d["columnPitchDeg"] * k
        az = math.radians(azd)
        add("photonic", f"photonic bay tile {k + 1}", "photonic",
            box(tm * math.cos(az), tm * math.sin(az), d["chamberFloor"] + ch / 2,
                d["tileThickness"], 2 * d["tileHalfWidth"], th2, azd))
    lz1 = d["chamberCeiling"] - d["ledGap"]
    add("body", "LED status ring", "emissive", tube(d["ledInnerRadius"], d["ledOuterRadius"], lz1 - d["ledHeight"], lz1))

    # envelopes (placeholders — dimensioned nowhere, shown for layout only)
    add("base", "air intake filter", "placeholder", tube(200, 224, 8, 48))
    add("base", "water reservoir", "placeholder", box(-60, -90, 150, 120, 110, 180, 0))
    add("base", "graphite block bay", "placeholder", box(80, -80, 130, 100, 100, 120, 0))
    add("base", "power supply", "placeholder", box(-80, 90, 100, 150, 90, 70, 0))
    add("base", "compute + router", "placeholder", box(80, 90, 110, 140, 100, 40, 0))
    add("base", "feed pump", "placeholder", cylinder_axis((15, 10, 60), (0, 0, 1), 25, 70))
    add("base", "cartridge circle", "placeholder", tube(40, 150, 270, 300))
    add("crown", "optical stem head", "placeholder", tube(0, 30, top_end + 2, top_end + 32))
    sweep = math.degrees(155 / R)
    add("crown", "touch UI 7in", "placeholder", tube(R, R + 2, 1540, 1627, -sweep / 2, sweep))

    build_s = time.time() - t0
    # cross-check against the Swift mesh volumes
    ref = P["partVolumesMm3"]
    rows, worst, worst_key, missing = [], 0.0, "", []
    for key, name, mat, s, _ in parts:
        v = s.Volume()
        m = ref.get(key)
        if m is None:
            missing.append(key)
            continue
        e = abs(v - m) / max(abs(v), 1e-9)
        rows.append({"part": key, "brep_mm3": v, "mesh_mm3": m, "rel": e})
        tol = 0.03 if "winding" in key else 0.015
        if e / tol > worst:
            worst, worst_key = e / tol, key
    assy = cq.Assembly(name="RH-1")
    for key, name, mat, s, loc in parts:
        r, g, b, a = COLORS[mat]
        assy.add(s, name=key.replace("/", "__").replace(" ", "_"), loc=loc,
                 color=cq.Color(r, g, b, a))
    assy.export(out_path, exportType="STEP")
    total = time.time() - t0
    print(f"  {len(parts)} B-rep parts built in {build_s:.1f}s; STEP written in {total:.1f}s -> {out_path}")
    worst_rows = sorted(rows, key=lambda r: -r["rel"])[:5]
    for r in worst_rows:
        print(f"    {r['part']:<48} B-rep {r['brep_mm3']:12.1f}  mesh {r['mesh_mm3']:12.1f}  Δ {100 * r['rel']:.3f}%")
    ok = worst <= 1.0 and not missing
    print(f"  G-STEP B-rep vs mesh volume: worst {worst_key} at {worst:.2f}× its tolerance "
          f"({'PASS' if ok else 'FAIL'}; 1.5% solids, 3% swept windings)"
          + (f"; unmatched: {missing}" if missing else ""))
    if report_path:
        json.dump({"parts": rows, "worstRatio": worst, "worstPart": worst_key,
                   "missing": missing, "seconds": total, "passed": ok}, open(report_path, "w"), indent=1)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
