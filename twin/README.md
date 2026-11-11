# field-compiler — the digital twin

The twin is the Replicator with emulated plates: the CAD, the physics and the
machine's software in one Swift package, no dependencies.

* [`CHARTER.md`](CHARTER.md) — what belongs in the twin and what does not.
* [`ENGINE.md`](ENGINE.md) — the physics the engine rests on, and why.
* [`CAD.md`](CAD.md) — the free-standing RH-1 as a parametric solid model.
* [`../papers/twin_rounds.md`](../papers/twin_rounds.md) — the round-by-round
  diary: every finding, bug and number behind the status below.

## Build and run

Command Line Tools only; no Xcode.

```sh
swift build -c release
./.build/release/fieldc test                 # 63 tests (FIELDC_VERBOSE=1 prints every measured value)
./.build/release/fieldc gpu --receipt        # GPU kernels against their CPU reference (G-A1, G-A3)
./.build/release/fieldc mold --receipt       # powder → shape (--shape ring|tetra, --rotate deg, --band lo-hi, --fcode out.fcode)
./.build/release/fieldc scan3d --object ring --receipt   # gated pulse-echo scan (point | ring | tetra | R)
./.build/release/fieldc replicate --receipt  # scan → read the shape → mold a copy → scan the copy
./.build/release/fieldc arraysweep --receipt # what the element count and the tones buy (study S1)
./.build/release/fieldc levitate --receipt   # the drive to hold one bead against gravity
./.build/release/fieldc carry --receipt      # pick up, carry, place (G-P1)
./.build/release/fieldc fly --receipt        # a bead integrated through the carry (G-P2)
./.build/release/fieldc build --receipt      # beads placed in a touching row (G-B1); --shape tetra (G-B2)
./.build/release/fieldc windings --receipt   # the contrawound windings' fields (G-EM1–3)
./.build/release/fieldc backend --receipt    # .fcode, frame log, emulated machine (G-FC1–5)
./.build/release/fieldc fcode demo --out demo.fcode
./.build/release/fieldc play demo.fcode --object ring
./.build/release/fieldc cad check --rules    # CAD gates + design rules
./.build/release/fieldc cad export | step | render --all | drawing | bom | params
./.build/release/fieldc shot --all --compare # every UI scene against its golden in shots/
```

`--array ideal | microhorn` and `--per-plate N` swap the plate for the earlier
ones; the default everywhere is the machine's own, `PlateArray.rh1`.

## Status — 2026-11-11

**The machine.** Two plates in open air, 460 mm apart. Each face carries 192
independently driven Ø5 mm elements on a golden-angle spiral (r 12–196.5 mm),
the twelve light slots cut into dashes around them. The CAD draws exactly the
array the engine drives (gate G-CAD9, to 1e-6 mm). Operator rulings: redraw
the face for the elements (2026-11-10); keep 192 per face (2026-11-11).

**What the twin does on that machine, gated:**

| verb | result | gates |
|---|---|---|
| `mold` | Ø40 µm powder ends 100 % on a 16-site ring, 5.9–6.7 % per site (fair 6.25 %); the ring turned 5° and 11.25° and a tetrahedron frame pass too. 9 tones over 50–100 kHz, 3.0 m/s rms per element, ~126 W acoustic | G-M1, G-M2, G-B0, G-B1 |
| `scan3d` | a wire ring imaged by time-gated pulse-echo: 100 % recall within 2 mm, object voxels outrank background voxels 0.990 (AUC) | SCAN, SCAN-AUC (informational) |
| `replicate` | scan a ring, read its 12 sites to 0.56 mm, mold a copy (median 0.35 mm from the original), re-scan it (correlation 0.751, bar 0.70); 355 s | G-R1–3 |
| `levitate` `carry` `fly` | one bead held, carried 10 mm on its point, and ridden by an integrated PLA bead | G-P1, G-P2 |
| `build` | five beads placed in a touching row; four as a tetrahedron | G-B1, G-B2, G-A4 |
| `backend` `fcode` `play` | a job as a `.fcode` stream, a CRC-checked binary frame log, an emulated machine behind `MachineBackend` | G-FC1–5 |
| `windings` | exact Biot–Savart on the CAD's winding centrelines | G-EM1–3 |
| `cad` | 100 closed solids, STEP export volume-gated against the mesh | G-CAD1–9, 26 design rules |

Receipts for every row are in `Receipts/`; each names the commit that made it.

**What the studies say.**

* Tones buy confinement and evenness; elements buy power. One tone never
  makes a unique trap. Nine tones fill every site at 2 × 48 elements already;
  192 is kept for the 3.5× lower drive per element (S1, 2026-11-10).
* A mold must be judged on the traced flow (`FlowMap`), which agrees with
  stepped grains to within 2 % of the powder per site. The 26-neighbour
  lattice map misreports per-site shares.
* The mold band is 50–100 kHz because sites 3.1 mm apart are not resolved at
  30–70 kHz.
* The windings put 0.48 mT in the chamber at 63 A. That is ~100× too little
  current to induction-levitate a Ø2 mm aluminium grain: the bore lift of
  ruling R10 is OPEN as dimensioned. A Ø20 mm bore coil of 376 amp-turns
  would hold mm-size shot at 100 kHz, not powder.
* The St. Clair patent claims were tested as referents and none adopted
  (table in `ENGINE.md`).

**Open.**

* No hardware has been measured. Every number above is a model of ideal
  pistons in linear air; the elements' electrical response, their reach to
  100 kHz and 3 m/s, and plate cross-talk are not modelled.
* Only `play` runs through `MachineBackend`. `mold`, `scan3d`, `replicate`
  and the placing verbs still build their own fields (charter rule 2).
* The SwiftUI app (`FieldCompilerApp`) still simulates the earlier six-gate
  machine; it stays until it is rebuilt on the plates (ruled 2026-11-11).
  `fieldc shot` renders its scenes.
* The CAD has no wiring layer for the 4 × 192 elements, and the horns, cones
  and throat piezos behind the faces no longer drive the sound: their role
  is undecided.
* Reading small 3D wireframes from a scan (the tetrahedron) does not work
  yet; the ring does.
* `Sources/` is 18,112 lines against the charter's proposed cap of 17,500.

## Layout

| target | what |
|---|---|
| `FieldCore` | pure Swift: geometry, CAD, solvers, force compiler, `.fcode`, backend, gates, tests |
| `FieldGPU` | Metal: the matrix-free array field and its adjoint, the part field, rendering |
| `FieldUI` | the SwiftUI shell and the screenshot harness |
| `fieldc` | the CLI: one verb per line above |
| `FieldCompilerApp` | the app |

Toolchain notes (Swift 6.2, Command Line Tools, runtime-compiled Metal) are at
the end of the diary.
