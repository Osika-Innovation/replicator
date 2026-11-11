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
./.build/release/fieldc test                 # 58 tests (FIELDC_VERBOSE=1 prints every measured value)
./.build/release/fieldc gpu --receipt        # GPU kernels against their CPU reference (G-A1, G-A3)
./.build/release/fieldc mold --receipt       # powder → shape (--shape ring|tetra, --stl file.stl, --rotate deg, --fcode out.fcode)
./.build/release/fieldc tolerance --receipt  # what a build must hold: the mold played on random builds (study S5)
./.build/release/fieldc scan3d --object ring --receipt   # gated pulse-echo scan (point | ring | tetra | R)
./.build/release/fieldc replicate --receipt  # scan → read the shape → mold a copy → scan the copy
./.build/release/fieldc arraysweep --receipt # what the element count and the tones buy on ideal pistons (study S1)
./.build/release/fieldc levitate --receipt   # the drive to hold one bead against gravity
./.build/release/fieldc carry --receipt      # pick up, carry, place (G-P1)
./.build/release/fieldc fly --receipt        # a bead integrated through the carry (G-P2)
./.build/release/fieldc build --receipt      # beads placed in a touching row (G-B1); --shape tetra (G-B2)
./.build/release/fieldc windings --receipt   # the contrawound windings' fields (G-EM1–3)
./.build/release/fieldc backend --receipt    # .fcode, frame log, emulated machine (G-FC1–5)
./.build/release/fieldc fcode demo --out demo.fcode
./.build/release/fieldc play demo.fcode --object ring
./.build/release/fieldc cad check --rules    # CAD gates + 28 design rules
./.build/release/fieldc cad pack             # the manufacturing pack
./.build/release/fieldc cad export | step | render --all | drawing | bom | params
./.build/release/fieldc shot --all --compare # every UI scene against its golden in shots/
```

The app (same engine, same plates):

```sh
sh Tools/make_app.sh && open ".build/Field Compiler.app"   # --args --compile | --scan | --stl file.stl | --machine
```

It opens on `Samples/ring.stl`. **Compile** makes a mold of the loaded object
on the plates (about five minutes) and steps the powder through it; **Build**
plays that powder frame by frame; **Scan** runs the plates' pulse-echo scan of
the object; **Inspect** shows the compile's gates; **Machine** is the CAD. An
STL larger than the mold volume (a 24 mm cube at the chamber centre) is scaled
down to fit and the status line says so.

`--array disc` is the face of 2026-11-10 (192 directly radiating Ø5 discs per
face, ideal broadband pistons to the engine); `--array ideal | microhorn` and
`--per-plate N` are the earlier ones; `--elements N` changes the count. The
default everywhere is the machine's own, `PlateArray.rh1`.

## Status — 2026-11-12

**The machine.** Two plates in open air, 460 mm apart. Each face carries
**1,536 resonant transmitters**, each tuned to one of nine tones
(52.8–97.2 kHz) and driven by its own channel, on a golden-angle spiral
(r 13–195 mm): the bought 40 kHz open-type part scaled to each tone, Ø7.6 mm
down to Ø4.1 mm. The CAD draws exactly the array the engine drives (gate
G-CAD9, to 1e-6 mm).

**This face is a proposal.** The operator's rulings stand at: redraw the face
for the elements (2026-11-10); keep 192 per face (2026-11-11). Both were made
while the engine drove ideal pistons. On 2026-11-12 the elements got a
hardware model, and the 192 directly radiating discs turned out to give a
three-hundredth of what the mold asks (gate G-E1 = 310; [`ENGINE.md`](ENGINE.md),
"The elements are hardware"). 1,536 resonant elements per face is the first
plate on which a mold passes with every element inside what it can deliver.
What it costs: four faces × 1,536 channels; the twelve light slots (no room
between the holes); and it rests on a transmitter nobody has measured.

**What the twin does on that machine, gated.** Every row below was run on the
1,536-element plate; G-E1 holds the drive to the elements' ceiling.

| verb | result | gates |
|---|---|---|
| `mold` ring | Ø40 µm PLA powder ends 100 % on a 16-site ring, 5.2–7.2 % per site (fair 6.25 %), lift contrast 2.22, at 1.15× holding. The hardest-driven element is at 96 % of its ceiling; 48 W acoustic, 159 W electrical | G-M1, G-M2, G-B0, G-B1, **G-E1 0.96** |
| `mold` tetrahedron frame | 100 % on the frame, 4.7–13.3 % per site (fair 10 %) — but it asks the elements for 1.13× what they can give | G-M1, G-M2, G-B0, G-B1 pass; **G-E1 fails (1.13)** |
| `mold --stl` ring.stl (the app's object) | 100 % on the ring, but one site of sixteen stays empty (0.0–12.6 % per site), with two feedback rounds as well; the analytic ring above, 16 sites on the same circle, fills evenly | G-M2, G-B0, G-B1, G-E1 0.91 pass; **G-M1 fails** |
| `scan3d` | a wire ring imaged by time-gated pulse-echo through the elements' resonance curves: every voxel above half the peak is within 2 mm of the object, 100 % recall, object voxels outrank background 0.984 (AUC) | SCAN, SCAN-AUC (informational) |
| `replicate` | scan a ring, read its 12 sites (worst 0.50 mm off), mold a copy (median 0.33 mm from the original), re-scan it (correlation 0.852, bar 0.70); 600 s. The copy's mold asks 1.04× what the elements give | G-R1–3, G-M1, G-M2 pass; **G-E1 fails (1.04)** |
| `levitate` | one Ø200 µm PLA bead held with the hardest element at 73 % of its ceiling. Aluminium would ask 1.08×, steel 1.84× | G-E1 0.73 |
| `carry` `fly` | the bead carried 5 mm up and 5 mm across on its point (worst 0.03 mm off); an integrated bead rides the carry at 1.25× and 1.5× holding. 2× asks 1.04× | G-P1, G-P2 |
| `build` | five beads placed in a touching row, four as a tetrahedron, at 1.5× holding (the drive was 4× on ideal pistons) | G-B1, G-B2, G-E1 0.90 |
| `backend` `fcode` `play` | a job as a `.fcode` stream, a CRC-checked binary frame log, an emulated machine behind `MachineBackend` that sends and hears through the elements' resonance curves | G-FC1–5 |
| `windings` | exact Biot–Savart on the CAD's winding centrelines | G-EM1–3 |
| `cad` | 104 closed solids, 28 design rules, STEP export volume-gated against the mesh, a manufacturing pack | G-CAD1–9, G-STEP |

`fieldc status --plate rh1x1536t9` prints every gate of the newest receipts.
The plate is at its limit. The ring passes with 4 % in hand; a shape that
needs more drive than the ring does not pass G-E1, and how evenly the sites
fill is not robust: one of the five molds above leaves a site empty.

Receipts for every row are in `Receipts/`; each names the commit that made it.

**What a build must hold** (study S5, `fieldc tolerance`: the compiled ring
mold played, at the drawing's power, on random builds of the plates; a build
passes when every site still holds a quarter of its fair share and 95 % of
the powder ends on the shape):

| what the build is off by | open loop: the drawing's drive on it | |
|---|---|---|
| element gain | ±10 % | holds |
| element phase | ±5° already empties a site | fails |
| element position | ±0.2 mm | holds |
| resonance frequency | ±0.1 % holds, ±0.3 % fails | |
| dead elements | 0.5 % holds, 2 % fails | |
| air temperature | 0.1 K holds, 0.3 K fails; at 1 K the powder falls | |
| all of an assembled machine's errors together | | fails |

So a machine is **calibrated** before it molds: with the chamber empty every
element is played alone and heard by the others (`MachineBackend.calibrate`),
and the mold is compiled on the machine as measured. Taking one build with
assembly-grade errors as that machine (gain ±10 %, phase ±20°, position
±0.2 mm, resonance ±0.3 %, 2 % of the elements dead), the mold compiled on it
passes its gates (sites 4.3–8.3 %, G-E1 0.93), and then:

| what calibration leaves unmeasured | the mold on the machine |
|---|---|
| gain ±1 %, phase ±2°, air 0.05 K | holds (sites 0.70–1.33 of a fair share) |
| gain ±2 %, phase ±5°, air 0.1 K | holds (0.67–1.31) |
| gain ±5 %, phase ±10°, air 0.3 K | fails (a site empties; the weakest site lifts 0.99× a grain) |

**The requirement:** assembly may be loose; calibration must reach gain ±2 %
and phase ±5° per element, and the machine must know its air to 0.1 K while
it molds — with about 100 W of heat going into the plates beside that air.

**What the studies say.**

* A real element plays one tone, and the plate needs about a third of its
  face radiating at 2 m/s to mold PLA powder at 230 mm. The drive a mold
  needs falls as 1/N; at a fixed share of the face radiating it falls as
  f^1.5 (study of 2026-11-12, `ENGINE.md`).
* Tones buy confinement and evenness; elements buy power. One tone never
  makes a unique trap (S1, on ideal pistons).
* A mold must be judged on the traced flow (`FlowMap`), which agrees with
  stepped grains to within 2 % of the powder per site.
* The mold band is 50–100 kHz because sites 3.1 mm apart are not resolved at
  30–70 kHz.
* The windings put 0.48 mT in the chamber at 63 A. That is ~100× too little
  current to induction-levitate a Ø2 mm aluminium grain: the bore lift of
  ruling R10 is OPEN as dimensioned.
* The St. Clair patent claims were tested as referents and none adopted
  (table in `ENGINE.md`).

**Open.**

* **No hardware has been measured.** The transmitters are the 40 kHz part's
  datasheet scaled to nine other tones on the assumption that the face
  velocity carries over. The plates' reflection (0.9) is a bare metal face's;
  cross-talk between elements and their electrical response beyond one
  resonance curve (Q 25, assumed) are not modelled.
* **No margin.** The ring mold runs the hardest-driven element at 96 % of its
  ceiling, on a face that cannot hold more elements.
* **For the operator:** 1,536 resonant elements per face against the ruling
  of 192; the light slots against the powder mold; what the horn, cone and
  throat piezos behind each plate are for now.
* Only `play` runs through `MachineBackend`. `mold`, `scan3d`, `replicate`
  and the placing verbs still build their own fields (charter rule 2). The
  emulated machine does carry the elements' resonance curves and build
  errors.
* The app molds and scans; the bead-placing verbs and `replicate` are not in
  it.
* The mold volume is a 24 mm cube and a mold is 16 sites. Larger or finer
  objects are scaled and sampled down to that, not built at size.
* The base's contents, the controller, fasteners, gaskets and cabling are
  envelopes or absent (`fieldc cad pack` lists them).
* `Sources/` is 17,315 lines, under the charter's proposed cap of 17,500.

## Layout

| target | what |
|---|---|
| `FieldCore` | pure Swift: geometry, CAD, solvers, force compiler, `.fcode`, backend, gates, tests |
| `FieldGPU` | Metal: the matrix-free array field and its adjoint, the part field, rendering; `Engine/`: the mold and the scan as library functions the CLI and the app both call |
| `FieldUI` | the SwiftUI shell and the screenshot harness |
| `fieldc` | the CLI: one verb per line above |
| `FieldCompilerApp` | the app: the same engine behind a window |

Toolchain notes (Swift 6.2, Command Line Tools, runtime-compiled Metal) are at
the end of the diary.
