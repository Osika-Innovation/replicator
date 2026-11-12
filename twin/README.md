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
./.build/release/fieldc test                 # 59 tests (FIELDC_VERBOSE=1 prints every measured value)
./.build/release/fieldc gpu --receipt        # GPU kernels against their CPU reference (G-A1, G-A3)
./.build/release/fieldc mold --receipt       # powder → shape (--shape ring|tetra, --stl file.stl, --feedback n, --rotate deg, --fcode out.fcode)
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
./.build/release/fieldc cad check --rules    # CAD gates + design rules
./.build/release/fieldc cad pack             # the manufacturing pack
./.build/release/fieldc p0 cad | link | job | matrix | body   # the P0 platform: frame parts, controller link, hold / move / release, the matrix, reference body files
./.build/release/fieldc upgrades             # the upgrade dependency graph, checked
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

`--elements N` and `--band lo-hi` (kHz) change the resonant plate's element
count and tones. `--array disc` is the face of 2026-11-10 (192 directly radiating Ø5 discs per
face, ideal broadband pistons to the engine); `--array p0` is the platform's
first configuration (`--side`, `--gap`, `--reflect`); `--array ideal | microhorn` and
`--per-plate N` are the earlier ones. The default everywhere is the machine's own, `PlateArray.rh1`.

## Status — 2026-11-12 (evening)

Two configurations share this engine: the **RH-1** column, and **P0**, the
first configuration of the platform the brief asks for
([`../ENGINEERING_MANAGEMENT.md`](../ENGINEERING_MANAGEMENT.md)). Neither is
a hardware release: nothing has been built, bought or measured.

### RH-1

Two plates in open air, 460 mm apart. Each face carries **2,560 resonant
transmitters**, each tuned to one of nine tones (52.8–97.2 kHz) and driven by
its own channel, on a golden-angle spiral relaxed until every pair of holes
keeps 1 mm of metal (r 13–195 mm): the bought 40 kHz open-type part scaled to
each tone, Ø7.6 mm down to Ø4.1 mm. 49 % of the face radiates. The CAD draws
exactly the array the engine drives (gate G-CAD9, to 1e-6 mm).

**This face is a proposal.** The operator's rulings stand at: redraw the face
for the elements (2026-11-10); keep 192 per face (2026-11-11), both made
while the engine drove ideal pistons. Why 2,560: the drive a mold asks of
each element falls as 1/N until the face is full, while what shapes the plate
can make stops improving near 550 elements (`ENGINE.md`, "How many
elements"). What it costs: four faces × 2,560 channels; the twelve light
slots; and **an element no catalogue sells** — a custom part whose
specification is `../cad/rh1-freestanding/TRANSDUCER_SPEC.md`.

Every row was run on the 2,560-element plate (receipts `*rh1x2560t9*`); G-E1
holds the drive to what an element can give.

| verb | result | gates |
|---|---|---|
| `mold` tetrahedron frame | 100 % on the frame, 5.5–13.3 % per site (fair 10 %), hardest element at 54 % of its ceiling. On 1,536 it asked 1.13× | G-M1, G-M2, G-B0, G-B1, G-E1 0.54 |
| `mold` ring | drive is ample (0.57) but **one site of sixteen stays empty** (0.0–11.5 %, fair 6.25 %) | G-M2, G-B0, G-B1, G-E1 pass; **G-M1 fails** |
| `mold` ring `--feedback 2` | two rounds of basin-map feedback fill it: 5.4–7.5 % per site, lift contrast 2.82 | G-M1, G-M2, G-E1 0.66 |
| `mold --stl` ring.stl (the app's object) | sixteen sites on the same circle, read off the STL: sites empty at the default compile (0.0–14.6 %) **and with two feedback rounds** (12 of 16 filled) | **G-M1 fails**; G-E1 0.55 |
| `scan3d` | a wire ring imaged by time-gated pulse-echo through the elements' resonance curves: 98 % of the voxels above half the peak within 2 mm of the object, 100 % recall, AUC 0.980 | SCAN, SCAN-AUC (informational) |
| `replicate` | scan a ring, read its 12 sites, mold a copy (7.2–9.4 % per site, fair 8.3 %), re-scan it (correlation 0.80, bar 0.70). On 1,536 the copy's mold asked 1.04× | G-R1–3, G-M1, G-M2, G-E1 0.60 |
| `levitate` | one Ø200 µm PLA bead held with the hardest element at 41 % of its ceiling; aluminium 60 %; steel would ask 1.03× | G-E1 0.41 |
| `carry` `fly` | the bead carried 5 mm up and 5 mm across on its point (worst 0.04 mm off); an integrated bead rides it; 2× holding asks 0.58 | G-P1, G-P2 |
| `build` | five beads placed in a touching row, four as a tetrahedron, at 4× holding (1.5× was all 1,536 could give) | G-B1, G-B2, G-E1 0.82 |
| `backend` `fcode` `play` | a job as a `.fcode` stream, a CRC-checked frame log, an emulated machine behind `MachineBackend` | G-FC1–5 |
| `windings` | exact Biot–Savart on the CAD's winding centrelines | G-EM1–3 |
| `cad` | 84 closed solids, 24 design rules, STEP export volume-gated against the mesh, a manufacturing pack. No horn, cone or throat piezos on this face (`CAD.md`) | G-CAD1–5, 7–9, G-STEP |

`fieldc status --plate rh1x2560t9` prints every gate of the newest receipts.
What still fails is evenness, not drive: how evenly sixteen sites fill is
the compile's doing. Feedback fixes the analytic ring and not the ring read
from the STL; the default compile is unchanged. The newest ring receipts are
the feedback runs.

**What a build must hold** (study S5, `fieldc tolerance`). The open-loop half
of the study — the drawing's drive on random builds — says nothing new on
this plate, because the drawing's own ring already leaves a site empty. The
calibrated half does: one build with assembly-grade errors (gain ±10 %, phase
±20°, position ±0.2 mm, resonance ±0.3 %, 2 % of the elements dead) taken as
the machine, the mold compiled on it as measured (all sixteen sites, 5.3–7.1 %,
G-E1 0.68), then played on what calibration leaves unmeasured:

| what calibration leaves unmeasured | the mold on the machine |
|---|---|
| gain ±1 %, phase ±2°, air 0.05 K | holds (sites 0.83–1.13 of a fair share) |
| gain ±2 %, phase ±5°, air 0.1 K | holds (0.76–1.19) |
| gain ±5 %, phase ±10°, air 0.3 K | fails (a site empties) |

**The requirement, unchanged from the 1,536 plate:** assembly may be loose;
calibration must reach gain ±2 % and phase ±5° per element, and the machine
must know its air to 0.1 K while it molds — with about 90 W of heat going
into the plates beside that air.

### P0, the first platform configuration

Two 4 × 4 plates of the bought 40 kHz transmitter on four threaded rods,
46 mm apart, one tone, 32 channels, a probe receiver for calibration
(`P0Design`, `PlateArray.p0`, `P0Model`). The order pack — parts with prices
read on 2026-11-12, printable files, wiring, budgets, calibration, a fixed
acceptance protocol and its blockers — is
[`../cad/p0-platform/ORDER_PACK.md`](../cad/p0-platform/ORDER_PACK.md).

| verb | result | gates |
|---|---|---|
| `p0 cad` | 13 closed solids, ten fit checks, STL and a drawing of the aperture plate | G-P0C1–3 |
| `p0 link` | the controller's firmware core (`Firmware/p0/fcore.c`), compiled for this computer and driven over a pipe by `SerialBackend`, returns the emulated machine's records within 0.06 % and 0.04° for the same frame log | G-HW1–3 |
| `p0 job` | calibrate (one plate at a time, then a side reference pass for the phase between them) → compile hold, 5 mm up, 5 mm across, hold, release → check it under the frozen planner policy → play, or decline | G-P0a, G-P0b; P0-ABS (placement, no bar) |
| `p0 matrix` | that session over gaps, plate reflections, image orders, builds and calibration disturbances, one CSV row each. Under `P0-planner/2`: 96 of 105 pass, 4 refused, 5 played and failed. At 46 mm: 18 of 18 two-pass, 17 of 18 with the reference. Window at reflection 0.9: 45–46.5 mm. Travel error 0.08–0.51 mm where it passes; absolute placement 0.06–0.70 mm. Record: [`Design/P0_CALIBRATION_MARGIN.md`](Design/P0_CALIBRATION_MARGIN.md) | P0-MX (informational) |
| `p0 job --body file.json` | the same session on a body-response file — a few inputs driving whole radiating faces ([`Design/BODY_INTERFACE.md`](Design/BODY_INTERFACE.md)). P0 written as a 32-input body gives the native result (travel 0.14 against 0.13 mm); a made-up six-input set calibrates and the planner declines its job | — |
| `p0 job --port /dev/cu.usbmodem…` | the same calls to a controller on USB. The firmware compiles for the RP2350B (`Firmware/p0/FIRMWARE.md`) and has **never been flashed** | — |
| `build --array p0` | **fails** on this aperture (and on a 6 × 6 of the same part): a second bead lands 1–2 mm off. A limit of those two configurations; the remedy is open | G-B1, G-B2 fail |
| `upgrades` | the dependency graph (`Design/upgrade_graph.json`): the first self-made part is an origin fiducial (one bead bonded on a printed post); placing a bead beside a bead is an open requirement with four candidate routes, none chosen. Acyclic; every made or measured record names its tolerance and inspection | G-UP1–2 |

### What the studies say

* Control saturates near 550 elements per face; drive only when the face is
  full. Tones buy confinement and evenness; elements buy power (S1, and the
  count study of 2026-11-12).
* A real element plays one tone. Nine tones sharing the face cost about √9
  in drive against one. The two one-tone apertures tried (4 × 4, 6 × 6 at
  40 kHz) do not place beads touching; what would is not established.
* A small machine is ruled by its gap and its plates' reflection (P0: 46 mm
  works across reflection 0–0.9, 44 mm does not at 0.9).
* A mold must be judged on the traced flow (`FlowMap`), which agrees with
  stepped grains to within 2 % of the powder per site.
* The windings put 0.48 mT in the chamber at 63 A: ~100× too little current
  to induction-levitate a Ø2 mm aluminium grain. The bore lift of ruling R10
  is OPEN as dimensioned.
* The St. Clair patent claims were tested as referents and none adopted
  (table in `ENGINE.md`).

### Open

* **No hardware has been measured.** The RH-1 transmitters are the 40 kHz
  part's datasheet scaled to nine other tones, and no such part is sold. The
  plates' reflection (0.9) is a bare metal face's. Cross-talk between
  elements and their electrical response beyond one resonance curve (Q 25,
  assumed) are not modelled.
* **For the operator:** 2,560 resonant elements per face against the ruling
  of 192; the light slots against the powder mold; the rear stack's removal;
  the P0 pack's blockers and whether to order.
* **Evenness is not solved.** The default compile leaves a site empty on the
  ring; two feedback rounds fix the analytic ring and leave four sites of the
  STL ring empty. The app's default object therefore still fails G-M1.
* `mold`, `scan3d`, `replicate` and the RH-1 placing verbs still build their
  own fields; `play` and the whole P0 path (`link`, `job`) run through
  `MachineBackend`.
* The P0 controller's firmware compiles for its board and has never run on one.
* P0 as drafted is a reference and test bed, not the selected prototype: the
  preferred study is a few strong piezo inputs into printed bodies (another
  session's). The platform takes such a body as a `body-response/0.1` file;
  calibration and the job use its first frequency only.
* The app molds and scans; the bead-placing verbs, `replicate` and P0 are not in it.
* The mold volume is a 24 mm cube and a mold is 16 sites.
* The RH-1 base's contents, controller, fasteners, gaskets, cabling and plate
  cooling are envelopes or absent (`fieldc cad pack` lists them).
* `Sources/` is about 18,000 lines, over the charter's proposed cap of 17,500.
  Five unreferenced functions and the unused complex linear algebra were
  removed on 2026-11-12; the micro-horn face and its rear stack are kept.

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
