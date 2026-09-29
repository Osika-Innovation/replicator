# field-compiler — RSW-1

Native macOS implementation of the Field Compiler.
Spec: [`papers/replicator_field_compiler.html`](../papers/replicator_field_compiler.html) (v0.8).
CAD: [`CAD.md`](CAD.md) — the free-standing RH-1 as a parametric solid model inside the twin.

## Build and run

No Xcode required — Command Line Tools only.

```sh
swift build -c release
./.build/release/fieldc test              # unit suite (58 tests; FIELDC_VERBOSE=1 prints every measured value)
./.build/release/fieldc gate --receipt    # physics acceptance gates, writes Receipts/
./.build/release/fieldc machine           # the simulated machine: RH-1 free-standing, room air (--desktop: frozen v0.3)
./.build/release/fieldc focus             # compile a centre trap on the full chamber (GPU port fields)
./.build/release/fieldc gpu               # Metal propagator + port-field kernel vs CPU reference
./.build/release/fieldc drift --receipt   # how fast a compiled trap goes stale as the air warms
./.build/release/fieldc forcetrap --receipt   # compile for force vs GS-PAT: unique trap? thermal hold? (--glass)
./.build/release/fieldc tonesweep --receipt   # glass chamber: sibling ratio vs number of tones (--target, --liner)
./.build/release/fieldc wallsweep --receipt   # glass liner / plate reflection grid (--plates)
./.build/release/fieldc levitate --receipt    # the drive to hold PLA / aluminium / steel against gravity, in SI
./.build/release/fieldc carry --receipt       # pick up, carry 5 mm up and 5 mm across, place (G-P1)
./.build/release/fieldc render iso a.png  # offscreen machine render, no window server
./.build/release/fieldc shot --all        # every UI scene, both themes + contact sheet
./.build/release/fieldc broadband         # channel-count study: free field vs cavity+chord
./.build/release/fieldc cad check --rules  # the RH-1 solid model: CAD gates + design rules
./.build/release/fieldc cad render --all   # iso, front, section, detail, plate, storage, top
./.build/release/fieldc cad export         # STL per part, OBJ+MTL, params, BOM, GA drawing
./.build/release/fieldc cad step           # B-rep STEP assembly via CadQuery, volume-gated
./.build/release/fieldc plates             # can 6 throat gates hold a trap? (model study)
```

## Status — honest

**2026-09-28 — the machine exists as CAD, and the physics reads it.** The
twin now carries the free-standing RH-1 (Ø460 × 1650, three plate assemblies,
four radiating faces, two chambers, rotating glass, arcade, six photonic bays)
as a parametric solid model built from the newest sources — etherworks.io
(2026-08-10), mech §3c (2026-08-03), spec v0.4 — with every number's
provenance and nine documented conflicts resolved in code (see
[`CAD.md`](CAD.md)). 92 closed solids, 9 CAD gates + 25 design rules, a shaded
section-cut Machine tab, STL/OBJ/STEP exports with a cross-kernel volume gate.
A new preset, `RH1Freestanding`, takes its acoustic apertures from the CAD's
plate faces and its gates from the throat piezos; the desktop preset (`RH1`,
24 panel gates) is FROZEN: it backs the historical solver gates below and
replays old receipts, nothing else.

**2026-09-29 — every mode now simulates the free-standing machine, in real
air.** Compile/Build/Inspect, the viewport chrome, `focus` and `render` run on
`RH1Freestanding.standard()`: 6 throat gates, 17 184 virtual apertures, both
plates as walls, humid air at 20 °C / 50 % RH. See "Round 6" below.

**2026-09-29, later — the glass chamber, exactly, and unique traps inside it.**
The build chamber is modelled as the glass cylinder it is (bare or lined), and
a force compiler that works in its speckle holds one trap with 3–10 tones, on
axis and off. A liner is not the lever; temperature tracking is. See "Round 7".

**2026-09-29, evening — how hard to drive, and a carried bead.** In SI units a
PLA bead needs ~160 dB and steel ~168 dB in the glass chamber (MODEL: the horn
is a stub), and the twin carries a trap 5 mm up and 5 mm across on its point,
downhill every step (G-P1). See "Round 8".

**Implemented and gated:** FieldCore (pure Swift, zero dependencies) —
complex/vector math, RH-1 geometry, mesh + voxelizer, T0 Rayleigh–Sommerfeld
propagator with exact adjoint, T1 acoustic FDTD, T2 Gor'kov radiation force,
the inverse solver (IBP / GS-PAT / Diff-PAT), gate framework and receipts.

**FieldGPU (Metal):** runtime-compiled shaders, GPU propagator validated against
the CPU reference to 3.8e-6, scene geometry for the RH-1 machine, an orbit camera,
and offscreen rendering to CGImage — the viewport half of the screenshot harness,
working with no window server.

**FieldUI (SwiftUI):** the slicer shell — mode tabs, object rail, viewport pane
with overlay chips, inspector, transport bar — as a pure function of `AppState`
(law L1). Dark and light themes. An 8-scene registry and a contact-sheet
generator; `fieldc shot --all` produces 16 PNGs plus two contact sheets headlessly.

**Machine model now carries the two levers a plain-array model lacks:** cavity
walls (axial image sources) and per-tone rainbow gate→element weights.

**Scan pipeline (M7) — wired end to end, physics PARTLY validated.**
`fieldc scan` runs: FDTD pulse-echo with a scatterer → empty-chamber reference →
differential → real S[rx][tx] scattering matrix → matrix pencil → chords →
`.pattern` → Machine View L0 → gates. Working and gated: `.pattern` round trip
bit-exact (G11), reciprocity QC on a genuine scattering matrix (G15, 0.001), and
**L1 DORT correctly REFUSES to image without a measured Green's function** — the
guard that stops a confident, sharp, meaningless picture reaching a `.pattern`.
Chord extraction recovers a pole at **10.68 kHz against a 10.72 kHz drive**,
which says the pencil is finding real physics.

**Not yet built / not yet working:** T0.5 BEM, T1f CBS, T3 consolidation,
`.fcode` I/O, Machine View L2–L3, golden-image *diffing* (screenshots generate
but are not compared against committed goldens), live MTKView interaction.

So: **M0–M2 and M4 done and gated; M1 done for geometry and viewport; M7 wired
with two known defects (below); M3, M5, M6, M8, M9 not.**

## Gate results (Apple M5)

All 10 gates pass. `G9b` reports informational — see below.

| gate | measures | result |
|---|---|---|
| G1 | voxelizer volume vs 4/3πr³ | 0.40% (bar 2%) |
| G2 | energy drift, lossless, 10k steps | 0.71% (bar 1%) |
| G3 | axial round-trip time of flight | 0.44% (bar 2%) |
| G6 | standing-wave node spacing vs λ/2 | 2.5e-5 (bar 1%) |
| G7 | Gor'kov numeric vs closed form | 3.6e-7 (bar 2%) |
| G9a | lateral focus placement, single plate | 1.79 mm (bar 2.64 mm) |
| G9c | best method vs IBP focusing gain | 1.00× (bar > 0.98) |

## Round 8 — how hard to drive, and how to carry (2026-09-29)

**Placement is pinned.** A force-compiled well now sits within λ/8 (≈ 1 mm) of
the requested point, positions sub-grid (a parabola per axis). The price in the
glass chamber at 10 tones: sibling ratio 0.24 → 0.36, still unique.

**`fieldc levitate` — the drive to hold a bead, in SI.** The rows are pressure
per unit aperture velocity (Pa per m/s), so a compiled drive is a set of
aperture velocities at horn coupling 1. The horn is still a stub, so these are
MODEL numbers until bench G-A0 measures the throat → aperture gain. The study
reads the largest upward force the trap's well offers along a 20 µm vertical
line, and scales the drive until that force carries the bead's weight. Force
and weight both scale as a³, so in the Rayleigh limit the answer depends on the
material, not the size. Hardest-driven gate, velocity amplitude (receipt):

| trap | PLA | aluminium | steel | field peak, PLA / steel |
|---|---|---|---|---|
| plates only, 5 tones | 25.5 m/s | 37.7 m/s | 64.2 m/s | 160 / 168 dB |
| glass chamber, 5 tones | 10.1 m/s | 15.0 m/s | 25.5 m/s | 163 / 171 dB |
| glass chamber, 10 tones | 4.5 m/s | 6.6 m/s | 11.3 m/s | 160 / 168 dB |

* The glass keeps the energy in: the same trap needs 2.5–6× less drive than the
  plates alone.
* PLA needs a ~160 dB field — the level working acoustic levitators use. Steel
  needs ~168–171 dB, where the air turns nonlinear (shock distance ~6 cm at
  160 dB) and streaming drag on fine powder rivals its weight. That is where
  the next physics layers — nonlinearity and streaming — stop being optional.
* Lateral stiffness is weak: 4–26 Hz for PLA at the holding drive.

**`fieldc carry` — pick up, carry, place (G-P1).** Re-compiling at each step of a
path either kept the old well while the target moved away (three steps) or
hopped 4.5 mm to another. Placing the well by Newton alone kept it on the point
while the rivals grew until the trap was lost (0.43 → 0.97 in four steps). The
carry step does both at once:

* a Newton step on ∇U(x) = 0 — the smallest drive change that puts the well on
  the point (`ForceCompiler.moveWell`);
* a rival-suppression step projected onto that constraint's null space, so it
  does not move the well (`ForceCompiler.carryStep`).

In the bare glass chamber with 10 tones, the trap was carried 5 mm up and 5 mm
across in 40 steps of 0.25 mm. Every step was within 0.17 mm of its point,
continuous, and downhill from the old well. The bead's well stayed the deepest
throughout, never below 0.71 of its starting depth. 36 of 40 steps were also
globally unique (worst 0.72, the first). Global uniqueness is the loading
criterion; a bead already in its well needs its own well and a clear path.

**Not modelled yet:** the transient between steps (drives switch instantly;
the chamber rings for ~10 ms, so a step takes at least that); the bead's own
dynamics (inertia, drag, streaming); sag under the scaled drive; the horn.

## Round 7 — the glass chamber (2026-09-29)

**The build chamber is a glass cylinder, and the twin now has it.**
`CylinderCavity` solves the chamber as an exact modal sum: the rear glass
(Ø444 OD, 4 mm wall → a = 218 mm) between the two plates, 460 mm apart.

    p = Σ_mn J_m(γr) e^{imφ} [W0 Z0(z) + WL ZL(z)]

Along z the plate images are summed in closed form; across the chamber every
glass reflection is exact (4 mm glass is a mirror: 69–83 dB transmission loss
at 40–200 kHz). At 40 kHz ~9 000 mode coefficients per gate stand in for
17 184 apertures × 7 image paths — the chamber's screen, made literal. One
Miller table serves every Bessel order; `CavityFieldsGPU` runs the sum on Metal.

**A lined glass wall, exactly.** A liner of specific admittance β sets
∂p/∂r = ikβp on the wall. Each mode's zero is continued from its rigid j′ₘₙ to
the root of x J′ₘ(x) = i(kaβ) Jₘ(x), and Jₘ at the complex argument is read off
the same real table by the multiplication theorem (DLMF 10.23.1), on the CPU
and in the kernel. Low modes graze the wall and turn pressure-release-like
with little loss; modes that meet it head-on are the ones a liner kills. (The
first-order perturbation this replaced fails once kaβ ≳ j′ — β ≈ 0.05 at
40 kHz already.)

| gate | checks | result |
|---|---|---|
| G-CYL1 | far wall absorbing → the half-space Rayleigh field | < 5e-3 |
| G-CYL2 | closed rigid cylinder rings at its analytic (0,0,1), (1,1,0) frequencies | pass |
| G-CYL3 | plate-mounted sources: 16-order image series = the cavity's plate series | 1.1e-5 |
| G-CYL4 | lined-wall zeros vs 30-digit mpmath continuations | 2e-9 |
| G-CYL5 | lossless air, lined wall: power in = power into the liner | 1.1e-6 |
| G-CYL6 | lined field: Helmholtz / wall condition / gradient vs finite differences | 1.1e-4 / 2e-10 / 1e-5 |
| G-GPU-CYL, -lined | Metal vs CPU, p and ∇p, bare and lined | 8.3e-6 / 8.5e-6 |

**A bug the cavity caught.** The image model placed a plate-mounted aperture
between the walls and then added that plate's own image at the source point —
but the Rayleigh prefactor already baffles it, so every image came twice and
the field was (1 + R) = 1.9× too strong. Up to the last truncated image that is
a uniform scale, so ratios barely moved, but absolute pressure was 1.9× high,
which matters the moment drives are in SI units. Fixed on the CPU (2fbccfb);
`fieldc gpu` then caught the Metal kernels still doing it (G-GPU-FS read 0.90),
fixed in 50eb595.

**A force compiler that works in speckle.** In the glass chamber the heuristic
refinement (penalise the 24 deepest siblings) returned its GS-PAT start
unchanged: hundreds of speckle wells, and with five tones it scored worse than
one tone can — which no optimum can. `ForceCompiler.smooth` minimises the
softmax of every rival well's depth over the target well's with Adam on the
unit sphere of drives, from an exact adjoint (checked against finite
differences, 1.5e-9); a chord starts from each tone compiled alone (equal,
quality-weighted, and the best tone alone). Everything below uses it.

**What the glass does to a trap, and what brings it back** (`fieldc forcetrap
[--glass]`, `fieldc tonesweep`, `fieldc wallsweep`; receipts at 00bcc24).
Sibling ratio, force compiler (< 0.5 = one trap; siblings above half depth in
brackets):

| chamber, target | 1 tone | 3 tones | 5 tones | 10 tones | 20 tones |
|---|---|---|---|---|---|
| plates only, mid-plane | 0.91 | | **0.25** (0), G-F1 | | |
| plates only, 100 mm above the lower face | 0.90 | | **0.31** (0) | | |
| bare glass, mid-plane (30–70 kHz grid) | 0.88 | | **0.42** (0) | | |
| bare glass, mid-plane (tonesweep spacing) | 1.06 | **0.44** (0) | 0.70 | **0.24** (0) | **0.16** (0) |
| bare glass, 60 mm off-axis | | | **0.49** (0) | **0.22** (0) | **0.18** (0) |
| bare glass, 100 mm above the lower face | | | **0.36** (0) | | |
| GS-PAT chords only, mid-plane | 6.91 | 1.22 | 4.20 | 0.69 | 0.92 → 0.50 at 80 tones |

* **Glass turns the field into speckle**, and a pressure-objective chord needs
  ~80 tones to find its way back to one trap. **Force-compiled, 3–10 tones
  suffice**, on axis and off it — the time–bandwidth argument (I1 below) holds
  in the exact chamber. Tones are drives.
* **A liner is not the lever.** With the force compiler the 5-tone chord reads
  0.42 with bare glass, 0.42 / 0.48 / 0.53 / 0.64 behind liners of normal-
  incidence R = 0.9 / 0.7 / 0.5 / 0.3, and 0.36 behind a ρc-matched one. A
  locally reacting wall reflects grazing waves whatever its β —
  R(θ) = (cos θ − β)/(cos θ + β) → −1 — and a partial liner's reflection phase
  turns with angle, which scrambles the field further. (An absorber that
  works at grazing incidence — thick, bulk-reacting — is not modelled.)
* **Temperature decides how often to re-compile.** In the glass chamber a held
  5-tone drive stops being unique by +0.1 K (0.60) and loses the trap by +0.3 K
  (1.13); re-compiled at the true temperature it is unique again — 0.44, 0.48,
  0.29 at +0.1 / 0.3 / 1 K — and through +0.3 K it has not moved. So the twin
  must track the air to ~0.1 K and recompile, which is what the fast compiler is
  for. (`fieldc drift`, GS-PAT traps: the glass decorrelates a held trap within
  +0.1 K; a ρc liner makes the drift smooth — 137 / 368 / 496 / 705 µm at
  +0.1 / 0.3 / 1 / 3 K — but does not stop it.)
* **Placement is loose.** A force-compiled well may sit up to λ/4 from the
  requested point (1.9 mm on the plate-only chord); building needs it on the
  point. Next: pin the target in the objective.

## Round 6 — temperature, port fields, and the free-standing machine (2026-09-29)

Prompted by two external reviews of the chamber-engine plan (Kin note "The
twin's chamber engine: two reviews checked…").

**Air is a model input now.** `Medium.air(temperatureC:humidity:pressure:)` gives
sound speed and density from an ideal-gas mixture of dry air and water vapour,
and absorption from ISO 9613-1: 343.87 m/s at 20 °C / 50 % RH, **+0.182 %/K**;
4.66 dB/km at 1 kHz (the ISO table value), 1.32 / 3.28 / 8.23 dB/m at 40 / 100
/ 200 kHz. Absorption acts on every path, images included; the horn channels
hold the same air (c/√τ), so they drift too. The fixed §12 media are unchanged,
so every earlier receipt still replays.

**Port fields on the GPU.** `PortFieldsGPU` builds the gate-granular operator for
any preset — horn couplings, wall images, absorption — and hands the CPU
pipeline a `Propagator(precomputedH:)`. The whole chamber at λ/2 (792 100 points
× 6 gates, 17 184 apertures × 7 wall paths ≈ 10¹¹ terms) builds in **3.3 s**;
after that every drive is a six-column sum. **G-GPU-FS** holds it to the CPU
reference: 1.3e-5 at 40 kHz, 5.3e-5 at 100 kHz (bar 1e-4).

**How fast a compiled trap goes stale** (`fieldc drift`, receipt): compile a twin
trap at 20 °C, hold the drive, warm the air.
* Direct paths only, the node moves by d·Δc/c (d = distance from the mid-plane):
  **G-T1** passes, +340 µm vs +329 µm closed form and −775 vs −712 µm at +3 K.
* With both plates as mirrors (3 image orders, R = 0.9), multipath turns the
  drift into decorrelation: at 40 kHz the trap moves 40–900 µm within +0.3 K,
  and at 100–200 kHz 0.1 K is enough for a sibling well to take over.
* Re-solving the drive at the TRUE temperature pulls on-axis traps back 2–4×
  with direct paths, but in the reverberant case it lands in a different well:
  the pressure-objective twin trap is not unique with 6 drives. So modelling
  temperature is necessary, not sufficient — the force compiler (Gor'kov
  potential as a quadratic form in the gate vector, sibling wells penalised)
  comes before thermal correction can work.

The live Compile shows the same thing honestly: all 4 000 wells lie within 45 %
of the deepest, median miss 10 mm.

**The force compiler** (`ForceCompiler`, `fieldc forcetrap`). Per tone the Gor'kov
potential is an exact quadratic form in the gate drive, U(x) = gᴴK(x)g, built
from the port-field rows and their analytic gradients (a GPU kernel,
**G-GPU-FS-grad** 1.4e-5). The gradients now include the piston directivity's
angular slope — the old "locally constant" shortcut missed 1–2 % of the lateral
gradient at ka ≈ 1.8 — so rows match finite differences to 1e-8. A well's depth
(shell mean − centre) is then a quadratic form too; the compiler maximises the
target's depth and penalises every competing well deeper than half of it, from
several starts (eigenvector, GS-PAT), warm-starting when the room changes.
* One tone, 6 drives: no unique trap anywhere (sibling ratio 0.94, 8–32 wells
  above half depth). Contrast is capped near the number of drives.
* **Five-tone chord (30 drives) at the mid-plane: G-F1 passes — sibling ratio
  0.43, no competing well within ±17 mm above half the target's depth, 0.6 mm
  from the requested point.** The first unique trap the twin has produced on the
  plate machine; the GS-PAT chord makes no well at the target at all. Warming
  with the drive held, it does not move (0 µm through +1 K); it stays unique to
  +0.3 K (0.49) and loosens by +1 K (0.66).
* 100 mm above the lower face the chord reaches 0.80 — the same as GS-PAT: the
  plate's own standing wave keeps 22 siblings there.

**Still missing** for these numbers to be the machine's: the glass cylinder
(the walls are the two plates only — added in Round 7), the horn (a labelled
stub), and SI drive units.

## Round 5 — what building the machine found (2026-09-28)

Building the geometry surfaced design facts no paper had written down, and
two physics bugs that had been shaping documented results.

**Design findings** (details and reconciliation table in [`CAD.md`](CAD.md)):
only **128 of the 380** sunflower sites can be drilled — 252 fall inside a
spiral slot or its web; per face the slots are **34,600 mm² open against
~2,700 mm²** of micro-horn faces (12.8×), so if the slots are open voids they
*are* the acoustic aperture — **operator ruling needed: open or
dielectric-filled?**; the "21 × 34" parastichies are the mid-field reading
(13 × 21 inside, 34 × 55 at the rim); three Ø25 throat piezos on r = 18 reach
0.5 mm into the Ø12 bore (model uses Ø20); the spec's storage chamber and its
own middle stack overlap (the site's layout is the one that closes); the
model weighs ≈69 kg against the spec's "≈50 kg class".

**Bugs, continuing the numbering:**

15. **Wall image series wrong beyond first order.** Every extra order re-added
    the two first-order images (so they carried R + R² + R³ = 2.44 instead of
    0.9) and put fourth-order images where third-order ones belong. The series
    is now derived per bounce count and pinned by a test against an explicit
    alternating-reflection recursion.
16. **The inverse solver optimized a different machine.** Its control matrix
    re-walked the elements in free field with no wall images, no element
    weights and no couplings — so every "walls" and "rainbow" condition solved
    its drive for a machine it was not then evaluated on. With the image
    series corrected, the walls + rainbow condition turned **NaN**, which is
    how it was found. The control matrix now comes from `Propagator.gateRow`,
    the same path as the cached operator.
17. **Point evaluators ignored walls, weights and couplings** — `pressure(at:)`
    and `velocity(at:)` could silently disagree with `forward`. One code path
    now; a test checks agreement with walls and complex couplings on.
18. **The drilled-hole set depended on display tessellation** (200 vs 400
    slot samples changed which sites a slot swallowed). Design facts are now
    decided at a fixed fine resolution; the unit suite caught it.
19. **An 8-sided winding carried 90 % of the round wire's copper**, which the
    STEP cross-check would have reported as a kernel disagreement. Wire
    polygons now use an area-equivalent circumradius.

**G9d / I1 re-run on the corrected model** — the retraction below stands,
now for the right reasons:

| condition | RH-1 | dense | RH-1 relative |
|---|---|---|---|
| 1 tone, free field | 1.088 | 1.097 | 0.99× |
| 1 tone, walls | 1.136 | 1.094 | 1.04× |
| 5 tones, walls | 1.052 | 1.231 | 0.85× |
| 5 tones, walls + rainbow | 1.093 | 1.305 | 0.84× |

**First study of the plate-primary machine** (`fieldc plates`, receipt
`plates_*.json`). Six throat gates, phase-conjugate drive at the chamber
centre, the two plates as walls. MODEL numbers — the throat → aperture
transfer is the `HornModel` stub:

| condition | apertures | focus contrast | parasitic/main |
|---|---|---|---|
| 1 tone, free field, slots open | 3,688 | 9.3 | 1.05 |
| 1 tone, walls, slots open | 3,688 | 9.5 | 1.02 |
| 5 tones, walls, slots open | 3,688 | 7.0 | 1.00 |
| 1 tone, walls, slots closed | 256 | 14.8 | 1.00 |
| 5 tones, walls, slots closed | 256 | 7.3 | 1.00 |

Read it plainly: the plates do focus (focus contrast = peak intensity over
the mean of a ±3λ neighbourhood; not comparable to the desktop's whole-volume
amplitude gain), and open slots cost a third of the single-tone contrast. But
parasitic/main sits at 1.0 in every condition: a point-conjugate drive
between two facing apertures makes an axial standing wave whose λ/2 nodes
are equally deep, and neither more tones nor the rainbow selects one of
them. Holding *one* grain needs a trap signature (twin, vortex, bottle) or
face-to-face amplitude asymmetry — that is the next study, not a verdict on
the machine.

## Four bugs the gates caught

Recorded because they are the argument for gate-first development.

1. **Gor'kov closed form wrong by −3.** The literature's
   `F = 4πa³kE_acΦsin(2kz)` uses the Settnes–Bruus contrast factor (Φ_B = Φ/3)
   *and* a cos() pressure convention. Against a sin() field the correct form is
   `F = −(4/3)πa³kE_acΦsin(2kz)`. Getting this wrong **inverts the trap** —
   nodes become antinodes — and produces a plausible-looking levitation sim that
   is wrong everywhere. Verified by symbolic differentiation. Spec corrected.
2. **FDTD energy measured at the wrong point in the leapfrog cycle.** The
   discrete invariant pairs *consecutive half-step* velocities; squaring one of
   them drifts at O(dt²). Energy is now sampled after the velocity update and
   before the pressure update, where p^n, v^{n−1/2} and v^{n+1/2} are all in hand.
3. **The propagator was element-granular.** Elements are the discretization of
   the radiating surface; **gates** are what the electronics can drive. An
   element-granular operator over a 2.5M-point lattice is ~470 GB and was killed
   by the OOM killer. Gate-granular it is ~100 MB — and it is also the correct
   control granularity.
4. **Diff-PAT was mis-scaled by orders of magnitude.** H carries physical units,
   so |Hu| at unit drive is ~10³ while the nominal target is 1; Adam drove the
   solution toward zero chasing an unreachable target, scoring 0.20× against
   IBP's 10.77× — the "optimizer" made it 50× worse. Targets are now rescaled to
   what the aperture can deliver.

Two more were *metric* bugs, not physics bugs, and equally instructive: the
evaluation lattice initially included the transducer planes (where 1/r diverges,
so the field maximum is always a source), and the sidelobe metric flood-filled
to −6 dB and then measured the first voxel outside, which by construction
returns −6 dB regardless of beam quality.

## Open issues

- **G9b sidelobe bar not met and escalated, not ratcheted.** The spec's −10 dB
  was written without a reference configuration. Measured: −9.0 dB on-axis
  (16×16, f/0.62), −7.6 (f/1.24), −8.6 (24×24), −9.1 (32×32); −7.2 dB off-axis.
  The textbook −13.2 dB is a *continuous* aperture in the *far* field and does
  not apply to a discrete λ/2 array focusing in the Fresnel zone. Lateral
  placement is exact, so the solver is sound and the bar was wrong. Per §20 law
  L5 this reports informational and **needs an operator ruling**, rather than
  being edited quietly to whatever was measured.
- **Drive amplitudes are not physical in `fieldc focus`.** `maxAmplitude` is
  dimensionless there, so "holds 200 µm PLA: no" is not a real result. The
  force compiler's drives ARE in SI (aperture velocity, m/s) — see `fieldc
  levitate`, Round 8 — but the horn coupling behind them is a stub.
- **`I1` RETRACTED as originally stated — do not send it to the hardware lane.**
  The first pass measured RH-1's 24 channels at 10.8× focusing gain vs a
  512-channel array's 18.0× and read it as "24 DOF cannot focus". That number
  came from a **free-field, monochromatic, pressure-domain** model, which assumes
  away three designed-in precision levers of this machine:
  1. **The cavity is the aperture.** Rayleigh–Sommerfeld is open air; RH-1 is a
     closed high-Q cavity. Time-reversal focusing *through* the multipath means
     controllable DOF scale with the time–bandwidth product B·τ_reverb, not with
     channel count — published down to single-channel focusing in chaotic
     cavities. This is the same multi-bounce lever ranked first for imaging in
     §18, applied to transmit by reciprocity.
  2. **The spectrum is the address bus.** The printed holograms steer by
     frequency, so a chord is 24 DOF *per tone with per-tone aperture patterns*,
     not the same 24 DOF louder. A frequency-flat gate→element map models a plain
     array, not RH-1.
  3. **Force, not spot size.** For well-separated tones the cross terms
     time-average out, so per-tone Gor'kov potentials add — co-locate the main
     lobes and the sidelobes land elsewhere and average down.

  Now implemented: cavity walls (axial image sources) and per-tone rainbow
  gate→element weights in the machine model, and a force-level gate **G9d —
  parasitic-to-main trap depth ratio under an N-tone chord**. `fieldc broadband`
  reruns 24-vs-dense at **equal time–bandwidth** across four conditions.

  **Result — the original finding does not survive.** Parasitic/main trap depth
  ratio (lower is better), RH-1 24-ch vs a dense 200-ch array:

  | condition | RH-1 | dense | RH-1 relative |
  |---|---|---|---|
  | 1 tone, free field *(the old model)* | 1.088 | 1.097 | 0.99× |
  | 1 tone, walls | 1.088 | 1.073 | 1.01× |
  | 5 tones, walls | 1.055 | 1.231 | 0.86× |
  | 5 tones, walls + rainbow | 1.073 | 1.071 | 1.00× |

  24 channels are **within ±14% of a 200-channel array on the force-level
  metric in every condition** — nowhere near the 2× that would justify escalating
  a channel-count finding. **Nothing goes to the hardware lane.**

  Read this as a *retraction*, not as a new positive claim. Two honest caveats:
  the absolute ratio sits near 1.0 for **both** apertures, which may mean a
  single-point conjugate drive leaves comparably deep competing traps regardless
  of channel count (real physics — the λ/2 lobe structure) *or* that the metric
  does not yet discriminate; and the walls are axial image sources only (the two
  caps), not the full cavity. Distinguishing those needs a multi-point drive and
  T1 walls, and is not done.

## Principles alignment round

Four gaps against `replicator_principles.html` v1.0, all now built and tested.

**§3 — chord-valued drive.** The drive was `[Complex]`: one number per gate at
one implied frequency, expressing 2 of the 11 knobs in the §3 table and unable
to represent a chord at all. `ChordDrive` is a set of tones, each with its own
per-gate vector, plus orbital order — so "send a chord" and "frequency is the
address" are expressible rather than aspirational. Power is shared across tones,
not stacked.

**§5 — Dissolve, the missing verb.** *"Assemble and dissolve are the same drive
separated by one sign flip."* Now literally true: `.dissolve` conjugates every
gate amplitude. But the claim is about ENERGY FLOW, so it is tested as one — the
net acoustic intensity through a box around the workpiece must **reverse sign**
between the verbs. A sign flip that doesn't reverse the flux is a relabelled
pump.

**§6 — call-and-response.** The build was open-loop: solve once, emit, stop. The
giveaway was an asymmetry — the chord list was only ever an *output* of scan,
never an *input* to build. `CallAndResponse` makes it the input, the target and
the stopping test, with a "rings true" tolerance, a stall detector, and an error
metric where a **missing** resonance costs as much as a wrong one (otherwise a
workpiece ringing at nothing scores perfectly).

**§4 — `Z(r)`, the compiler's second output.** `SurfaceHologram` implements
`Z(r) = X₀ + M·Re{Ψ*ref·Ψobj}`, deliberately machine-agnostic per Memory &
Compute's "one toolchain, three back-ends". Tested by reconstruction: replaying
the reference must concentrate at the target, not merely produce a texture.

Three more bugs, all caught by writing the tests rather than the code:

12. **Twin-image convention in the hologram.** Storing the *diverging* wave a
    target would radiate puts the focus on the real twin image — measured 23 mm
    off target with no concentration at all (0.94× the plane mean). An emitting
    aperture must store the **converging** wave; then the focus lands on the
    |R|² term where it belongs.
13. **I expected dissolve to match assemble in magnitude.** It doesn't, and the
    reason is physics: conjugating the *drive* is not time-reversing the
    *problem* — the Green's function still radiates outward. A finite boundary
    recaptures only the fraction it subtends, which is exactly why the papers
    insist CPA needs conjugate control of both counter-propagating channels.
    Asserting equal magnitude would have been asserting a perfect absorber.
14. **A converging test case that diverged.** My loop test had the measured
    weight decreasing *past* the target, so the error grew and the loop correctly
    reported a stall. The test was wrong, not the loop.

## Audit round — what the gates found

**G5 (the keystone) now passes at 0.042 against a 0.05 bar**, and a resolution
sweep shows textbook second-order convergence — 0.159 / 0.088 / 0.057 / 0.042 at
λ/6, λ/8, λ/10, λ/12, against predicted (Δ)² ratios of 1.78 / 1.56 / 1.44. So the
residual is **FDTD grid dispersion in the reference solver**, not an error in the
propagator: T0 is validated, and every field slice, trap and particle in the
viewport rests on something now checked rather than asserted.

Four bugs surfaced getting there:

8. **Time-convention mismatch in G5.** T0 writes outgoing waves as `exp(+ikr)`,
   which is outgoing only under `exp(-iωt)`. The phasor extractor assumed
   `exp(+iωt)`, so the gate compared an outgoing wave against an **incoming**
   one; they differ by a distance-dependent phase `2kr` that no single complex
   scale can absorb, and the residual pinned at 0.989.
9. **Coverage asked the wrong question.** It summed `cos θ` over gates that could
   see a *location* — but every interior point is visible to some gate, so it
   returned ~1 everywhere and reported **0.0% of the volume unobserved for a
   12-gate ring**. Specularity is about *orientation*: a facet is measurable only
   if some (Tx,Rx) bisector is parallel to its normal. Rewritten as bisector
   coverage of the orientation sphere, with the acceptance angle derived from
   facet size (`asin(λ/2D)`) rather than picked. Honest answer for this ring:
   **coverage p10 0.24, median 0.37, p90 0.48** — it catches about a third of
   facet orientations.
10. **G10 truncated a joint fit.** Each chord's amplitude was solved with the
    others present, so dropping chords leaves the survivors mis-weighted — the
    error curve came out non-monotone (K2 worse than K1, K16 worse than K8),
    which reads as an extractor fault but is an invalid comparison. Refitting per
    subset makes it exactly monotone.
11. **G5's domain was fixed in cells, not wavelengths.** Refining the grid shrank
    the physical domain, moving the sample annulus toward the source and sponge —
    a resolution sweep read non-monotonically (0.130 at λ/8 but 0.076 at λ/16)
    and would have been misread as the propagator failing at high resolution.

## Known defects in the scan pipeline — do not trust these outputs yet

1. ~~Chord amplitude fit does not reconstruct.~~ **Fixed** — shifted QR,
   model-order sweep, DC-artifact rejection. G18 passes at 0.122.
2. ~~Coverage is too generous.~~ **Fixed** — see the audit round above.
3. **G14a/G14b still report IoU 0.** The reconstruction is a reflectivity image
   thresholded at 0.35 of peak, which does not align with the object's occupancy
   at this scan resolution. The gates are informational by design (a bar there
   would reward hallucination), but the numbers are not yet meaningful.
4. **Drive amplitudes are still not in SI**, so no force or stiffness number is
   quotable and G8 stays blocked.

## Three more bugs the gates caught this round

5. **Scattering matrix was a Gram matrix.** The scan summed all drives into one
   record set, which destroys the per-drive structure. `S = Σᵢdᵢdⱼ` is symmetric
   *by construction*, so the reciprocity QC read exactly 0.0000 and was testing
   nothing. Now keeps `S[rx][tx]` per drive; reciprocity reads 0.001 and is a
   real measurement.
6. **FDTD ran at λ/2.1.** The scan drove 40 kHz on a 4 mm grid — well below the
   λ/5 the spec itself requires (§12), so the propagating wave was numerically
   garbage. The drive frequency now follows the grid (`c/8dx`).
7. **Unshifted QR cannot resolve complex-conjugate eigenvalues.** The pencil's
   `Z` is real, so its eigenvalues come in conjugate pairs, and unshifted QR
   provably stalls leaving 2×2 blocks — reading the diagonal returned only real
   numbers, so **every chord came out at f = 0 Hz**. Now reads the
   quasi-triangular form and solves each 2×2 block's quadratic.

## Toolchain constraints (verified on this machine)

- **No Xcode**, CommandLineTools only. SwiftUI/Metal/MetalKit still compile.
- **`XCTest` is unavailable** without Xcode, so `swift test` cannot build. The
  suite runs through a ~60-line harness in `FieldCore/Testing` via `fieldc test`.
  Consequence: tests run anywhere Swift does, including bare CI containers.
- Metal shaders must be compiled **at runtime** from source
  (`makeLibrary(source:)`); the offline `metal` compiler needs Xcode. This also
  makes kernels hot-reloadable.
