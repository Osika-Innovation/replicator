# The twin's charter

Status: **proposal, 2026-11-10** — not yet ruled on by the operator. The numbers
in "Where the twin stands" are measured; the caps and budgets are proposed.

TempleOS had a charter: a short list of limits its author would not cross
(100,000 lines, one resolution, one font, no layers between the user and the
machine). The limits were the design. This is the same thing for the twin.

## What the twin is

The twin is the machine with emulated plates. It rests on one fact
([`ENGINE.md`](ENGINE.md)): the air between the plates is linear, so the field
is a fixed linear response to the drive and the force on a grain is a quadratic
form in the drive. Code that does not follow from that sentence, or check it
against a measurement, does not belong here.

## The rules

1. **One machine.** Two plates of independently driven elements in open air
   (`PlateArray`). Earlier machines (the desktop preset, the glass cylinder,
   the six throat gates, FDTD) live in git under a tag, not in the tree. A
   receipt names the commit that produced it, so nothing is lost.
2. **One line to the machine.** Everything above the plates talks through
   `MachineBackend` (describe, calibrate, play, listen) and `.fcode`. A program
   that runs on the emulator runs on the hardware unchanged. No command builds
   its own field.
3. **A line cap.** `Sources/` (Swift and Metal) may not exceed the cap. The cap
   is lowered when code is deleted and never raised. A round that adds lines
   removes at least as many. Proposed: **17,500 after the first cut, 15,000
   once the old machines are untangled** (see the measurements below).
4. **No dependencies.** Foundation, Metal and the system frameworks only, as
   today. `Tools/` (plots, STEP export) is outside the twin: nothing in
   `Sources/` may need it.
5. **Verbs are functions.** `main.swift` parses arguments and calls one library
   function per verb; proposed limit 500 lines for the file, 40 per command. A
   job is a `.fcode` stream or a short list of verbs, not a new subcommand.
6. **Constants, not flags.** When a sweep has answered its question, the answer
   becomes a constant with the receipt's name beside it, and the sweep leaves
   the tree.
7. **A time budget.** On the operator's laptop: clean release build, the full
   test suite, and one `replicate`, each within the budget below. A change that
   breaks the budget is a regression like a failing gate.
8. **One reference per kernel.** Each GPU kernel has one CPU reference in
   Double. The reference exists to gate the kernel; it is not a second engine
   with its own commands.
9. **The document is the run.** `Receipts/` keeps the latest receipt per gate;
   history is git's. The README's status section is generated from those
   receipts and stays under 150 lines; the round-by-round diary moves to
   `papers/`.

## What is deliberately not taken from TempleOS

* **Isolation from hardware.** TempleOS had no networking and almost no
  drivers. The twin exists to be calibrated against real plates; the
  measurement path (rule 2) is the centre of it.
* **No verification.** The gates, the receipts and the MEASURED / DERIVED /
  OPEN register stay. They get shorter, not optional.
* **The system as the goal.** The cap serves getting the first prototype
  built. If a rule here blocks a bench measurement, the rule loses.

## Where the twin stands — measured 2026-11-10

Working tree at `1b708a2` plus the uncommitted changes of that day.

| what | today | proposed |
|---|---|---|
| `Sources/`, Swift + Metal | 21,229 lines, 5 targets, no third-party dependencies | cap 17,500, then 15,000 |
| `main.swift` | 2,639 lines, 26 commands in one `switch`; `build` alone is 671 | ≤ 500 |
| clean release build | 74 s | ≤ 60 s |
| `fieldc test` (69 tests) | 102 s | ≤ 30 s |
| `fieldc replicate` (ring) | 282 s wall, 17 s of CPU: the time is spent on or waiting for the GPU | ≤ 60 s |
| `Receipts/` | about 150 files, 5.6 MB | latest per gate |
| `README.md` | 1,112 lines | status ≤ 150 |

**What rule 1 would remove.** Counted by following type references from the
open-air commands (`test`, `mold`, `arraysweep`, `scan3d`, `replicate`, `cad`,
`windings`, `shot`) and the machine line (`MachineBackend`, `FCode`). This is a
static count; nothing was deleted or compiled without the code.

* **First cut, no refactoring: 3,900–5,000 lines (18–23 %).**
  * 2,105 lines of `main.swift`: the 18 commands outside that set (`build`
    671, `gpu` 202, `fly` 187, `tonesweep` 145, `forcetrap` 138, `levitate`
    135, `carry` 116, `scan` 102, `drift` 97, `wallsweep` 91, `render` 90 and
    seven smaller ones). `gpu` also holds the open-air kernel check G-A1; that
    part would move, not go.
  * 10 files nothing in the set reaches, 1,576 lines: `MachineView`,
    `BroadbandGate`, `ThermalDrift`, `PlateApertureStudy`, `SurfaceHologram`,
    `ChordField`, `CallAndResponse`, `PropagatorGPU`, `LightRead`, `Rainbow`.
    Three more (1,060 lines) if the SwiftUI app goes too: `LiveViewport`,
    `Pattern`, `FieldCompilerApp/main`.
  * 190–244 lines of tests that exercise those files.
* **Second cut, needs untangling: up to about 2,600 more.** `CylinderCavity`,
  `CavityFieldsGPU`, `PortFieldsGPU`, `FDTD`, `G5`, `RH1`, `ScanRunner`,
  `MatrixPencil`, `PhysicsGates` and `propagator.metal` are old-machine code
  that the open-air path still pulls in through two knots: `FieldLattice` is
  declared in `Propagator.swift`, which carries an optional `CylinderCavity`;
  and room air is a constant on `RH1Freestanding`. This figure is an upper
  bound, not a count of provably dead lines.

Both cuts together bring `Sources/` to roughly 14,000–15,000 lines.

## Bead placing, ported to the open-air machine — 2026-11-10

Rule 1 had a cost: holding, carrying and placing beads (`levitate`, `carry`,
`fly`, `build`: gates G-P1, G-P2, G-B1, G-B2) existed only on the
glass-chamber model. The operator's decision was to port before deleting. The
four verbs now run on `PlateArray` (the glass originals went in the first cut,
below):

| verb | gate | open air, 2 × 192 elements, 10 tones | wall time |
|---|---|---|---|
| `levitate` | — | one trap, sibling ratio 0.03; PLA Ø200 µm needs 2.1 m/s on the hardest element, field peak 157 dB; steel 5.2 m/s, 165 dB | 50 s |
| `carry` | G-P1 pass | 40 steps of 0.25 mm; worst offset 0.04 mm; never below 0.99 of the starting depth; worst sibling ratio 0.30 | 84 s |
| `fly` | G-P2 pass | carried at all 12 combinations of drive (2×, 4×, 8× holding) and step time (10–80 ms) | 124 s |
| `build` | G-B1 pass | 5 of 5 beads in a touching row; sites missed by 20–27 µm before the grip; placed beads pushed ≤ 15.4 × weight | 263 s |
| `build --shape tetra` | G-B2 pass | base of three touching, the fourth resting on all three | 233 s |
| `build --check-part` | G-A4 pass | the part field's adjoint vs central differences: 8e-7 | seconds |

No receipts were written for these runs: the tree was uncommitted. Re-run with
`--receipt` after a commit.

What the port needed, beyond swapping the field:

* `ForceCompiler.moveWell`, `carryStep` and `stiffen` take any `ForceField`;
  the stored-row forms forward to them. The glass `carry` reproduces its
  receipt of 2026-10-01 to the printed digits.
* A carry step re-aims the array first (`PlaceRig.steer`: every element's
  phase turned by the change in its path to the point). The glass-era
  continuation alone kept the well on its point but lost 4 % of its depth per
  step, 0.11 of it left after 10 mm.
* `carryStep(rivalsBelow:)`: the rival descent is skipped while the moved trap
  is already unique.
* `PartFieldGPU`: the placed beads' scattering on top of the matrix-free
  array field, with its adjoint (G-A4).
* The tetrahedron's top bead hovers at the lowest height where the trap keeps
  half its sideways stiffness with the part in the field (0.75 mm here; 0.5 mm
  in the glass chamber). Between the plates the trap is soft sideways (about
  12 Hz at the build's drive) and at 0.5 mm the base beads' scattering made it
  a saddle.

The port adds 1,165 lines (`PlaceCore`, `BuildCore`, `PartFieldGPU`). The four
glass commands it supersedes are 1,109 lines of `main.swift` inside the first
cut above, so the first cut can now go ahead without losing a gate.

## The first cut, made — 2026-11-10

Approved by the operator after the port. The tree before the cut is the tag
`twin-before-first-cut` (commit `bf514d6`): every command and file removed
here is in it unchanged, and so are the glass forms of the four placing verbs.

| what | before | after |
|---|---|---|
| `Sources/`, Swift + Metal | 23,486 lines | 19,774 |
| `main.swift` | 2,672 lines, 29 cases | 635 lines, 12 cases |
| `fieldc test` | 79 tests | 74 tests, all passing |

Removed:

* 17 commands from `main.swift`: `g5`, `gate`, both `machine` forms, `plates`,
  `focus`, `drift`, `tonesweep`, `wallsweep`, `forcetrap`, `render`, `scan`,
  `broadband`, and the glass `build`, `fly`, `carry`, `levitate`. `gpu` keeps
  only the open-air kernel checks (G-A1, G-A3); its glass and port-field
  checks went with their machines.
* 9 files, 1,498 lines: `MachineView`, `BroadbandGate`, `ThermalDrift`,
  `PlateApertureStudy`, `SurfaceHologram`, `ChordField`, `CallAndResponse`,
  `PropagatorGPU`, `Rainbow`. `LightRead` stays: `mold` now uses it.
* 5 tests that exercised those files.

Still passing after the cut: the 74 tests (the physics gates run inside
them), G-A1, G-A3, G-A4, G-P1 and the seven machine-program gates (G-FC1…5).

Not done:

* The line count is 19,774, above the proposed cap of 17,500. The tree grew
  by about 2,300 lines (Rounds 13–16 and the port) between the measurement
  above and the cut. Reaching the cap needs the second cut.
* `main.swift` is 635 lines, above the proposed 500: `mold`, `arraysweep`,
  `scan3d` and `replicate` are still written inline.
* The SwiftUI app (`LiveViewport`, `Pattern`, `FieldCompilerApp`) is kept; no
  decision was made on it.
* `README.md` and the other documents still describe the removed commands.

## The second cut, first part: the glass cylinder — 2026-11-10

Approved by the operator the same day. The tag `twin-before-first-cut` still
holds everything removed here.

| what | before | after |
|---|---|---|
| `Sources/`, Swift + Metal | 19,774 lines | 18,535 |
| `main.swift` | 635 lines | 623 |
| `fieldc test` | 74 tests | 67 tests, all passing |

Removed: `CylinderCavity` and `CavityFieldsGPU` (653 lines), the cavity
kernel in `propagator.metal`, the cavity hooks in `Propagator`,
`RH1Freestanding.chamber`, `--chamber glass` in `mold` and `scan3d` (with the
six-gate `scanImage`), and the 7 cavity tests.

Checked after the cut: the 67 tests, G-A1, G-A3, `mold --per-plate 48`
(G-M1, G-M2, G-B0, G-B1 pass) and `scan3d --object point`, whose output is
the same as before the cut.

What is left of the old machines, and why it is still here:

* The SwiftUI app (`LiveViewport`, `Pattern`, `FieldCompilerApp`, 1,057
  lines) simulates the six-gate machine. It is the last user outside the
  tests of `RH1Freestanding.standard`, `PortFieldsGPU.propagator`,
  `InverseSolver`, `MatrixPencil`, `Scan` and `PatternFile`. **Ruled
  2026-11-11: the app stays.** The code it uses stays with it until the app
  is rebuilt on `PlateArray`.
* `FDTD`, `G5`, `RH1`, `TestPresets` and `PhysicsGates` are reached only
  from the test suite (the physics gates G1–G15 run inside `fieldc test`).
  Which of those gates still guard the open-air machine has not been sorted.
* `FieldLattice` still lives in `Propagator.swift` and room air on
  `RH1Freestanding`. Moving them saves no lines until the files around them
  can go, so they were left.

The line count is 18,535 against the proposed 17,500.

## The README, cut to the status — 2026-11-11

Rule 9, done by the session that wrote Rounds 13–16. `README.md` went from
1,371 lines to 108: what the twin is, the current commands, the gated results
on the open-air machine, what the studies say, what is open. The
round-by-round diary moved unchanged to `papers/twin_rounds.md`, with a note
naming the commands that now exist only in the tag. The status is written by
hand, not yet generated from the receipts.

## The test-only old code, sorted — 2026-11-11

Proposal; nothing here has been deleted. Traced by following who calls what
in the tree at `9ddba61`.

| code | lines | what it checks | guards the open-air machine? | proposed |
|---|---|---|---|---|
| G7, Gor'kov force vs closed form | 30 | `Gorkov`, which `ForceCompiler` uses for every force | yes | keep |
| G1, voxelizer volume | 25 | `Voxelizer`, which the CAD gates use | yes | keep |
| `TestPresets` | 73 | small arrays for the propagator's adjoint, gradient and absorption tests; `PlateArray` builds its CPU reference from `Propagator` | yes | keep |
| G9a–c, inverse solver | ~170 | `InverseSolver`, used only by the app | no, the app | stays with the app; its `RH1.preset` section goes with `RH1` |
| G15, reciprocity of a matrix | 20 | a helper only the tests call; the backend has its own reciprocity gate (G-FC) | no | go |
| G6, node spacing | 36 | adds two plane waves in a loop; calls no engine code | no | go |
| `FDTD` + G2 + G3 | 183 + ~75 | the time-domain solver against itself | no | go with G5 |
| G5, propagator vs FDTD | 145 | the free-space kernel e^(ikr)/r against a wave-equation solver | weakly: the kernel is exact, and the open-air element is gated against the Rayleigh integral (G-A2) and the sphere series (G-S1) | operator's call |
| `RH1` (desktop preset) + 4 tests | 139 + ~30 | the frozen v0.3 machine | no | go |
| `Scan.run` in `ScanRunner.swift` | ~120 | — | **dead**: its only caller was `fieldc scan`, removed in the first cut. The app uses only the type `Scan.Gate` | go |

If every "go" row and G5 go: about 790 lines, which brings `Sources/` to
roughly 17,750. That is still about 250 above the proposed 17,500 with the
app kept. Without G5 and `FDTD` it is about 390 lines.

The one loss worth weighing is G5 with `FDTD`: it is the only solver in the
tree that does not assume the answer's form. Nothing on the open-air path
uses it today, but it is what an independent check of the time-gated scan
would be built on.
