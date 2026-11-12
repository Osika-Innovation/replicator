# The engine plan — open air, physics-limited plates, linear-first compute

Written 2026-10-01 after the operator's decisions below. This is the plan the
twin is built to from Round 12 on. The diary's rounds ([`../papers/twin_rounds.md`](../papers/twin_rounds.md)) report what was built
and measured against it.

## Decisions (operator, 2026-10-01)

1. **Chamber: keep the cylinder, drop the glass.** Two Ø410 mm plates, 460 mm
   apart, with open air between them, as the first prototypes will be. The
   glass-cylinder model (`CylinderCavity`, Rounds 7–11) stays as an option,
   not the default.
2. **Plates: specified by physics, not by "three horns per face".** Each plate
   is a holographic acoustic surface; the design target is the point where
   physics (wavelength, bandwidth, the air's nonlinearity) limits it, not the
   engineering.
3. **Compute: make the engine efficient before spending compute on it.** Heavy
   runs stay at `taskpolicy -c utility`, sequentially.

## Why the twin was heavy

A mold run as of Round 11 (40 tones, glass chamber):

| stage | what it does | why it is heavy |
|---|---|---|
| fields | each tone's six gate fields (p and ∇p) at ~60,000 grid points, each a sum of 10,000–20,000 cavity modes | ~10¹⁰ mode evaluations; rebuilt from scratch by every command |
| compile | Adam, 400–800 sweeps; every sweep evaluates the force at all 60,000 points × 40 tones and its gradient | ~1 GB of rows streamed through the CPU in double precision per sweep |
| powder | 3,000 grains × 16,000 time steps | 48 M steps |
| scan | 90 frequencies × the field build again, on the image grid | the field build × 90 |

Nothing is reused between runs, and only the field build uses the GPU.

## The one fact the engine is built on

The air between the plates is linear. The field is a fixed linear response to
the drive, and the time-averaged force on a small grain is a quadratic form in
the drive, U(x) = Σ_f g_fᴴ K_f(x) g_f. So:

* the response is computed, not simulated: in open air it is closed-form
  (piston elements plus their images in the plates);
* every objective the compiler uses — the lift at a site, the depth of a well,
  the most any other point can lift — is a quadratic form in the drive, so the
  compile is linear algebra on a few hundred numbers, not a search over a grid;
* overdamped powder only slides downhill, so where it ends is a property of the
  landscape (its basins), not of a trajectory;
* a scan is the transpose of the same response (the matched filter).

## The plates, limited by physics

For the RH-1 geometry: Ø410 mm plates, 460 mm apart, a ±12 mm work volume at
the mid-plane, 230 mm from each plate.

| limit | set by | number |
|---|---|---|
| finest pattern | λ/2; finer detail does not propagate | 2.5 mm at 70 kHz, 4.3 mm at 40 kHz |
| channels that matter | the independent field patterns a ±12 mm volume can hold, ~(kR)², from the ~25 % of directions two Ø410 plates cover | ~60–200 per tone |
| layout | sparse aperiodic array: a Vogel spiral (golden angle) puts every element at a unique radius, so no grating lobes | already the cap-and-stack ruling |
| element size | ≲ λ at the top frequency, so an edge element still reaches the centre (it sees it 42° off its normal) | ~5 mm at 70 kHz |
| bandwidth | pulses and range resolution | 30–100 kHz → 2.5 mm |
| loudness | the air turns nonlinear (shocks within centimetres) | ~160–165 dB |
| gain | at fixed power the focal pressure grows as √N with the channel count | 200 channels vs 6: ~6× |

The open air gives up the glass's resonant gain (2.5–6×, Round 8); the channel
count wins it back, and the field is clean: no glass speckle, fast settling,
less thermal drift. A full λ/2 grid would be ~7,000–22,000 elements per plate;
the study below finds how many independently driven elements are worth having.
Space–time coding (1-bit switching with timing, as in the PCB holographic
transducer paper §9.3) gives each element amplitude and phase cheaply.

## The engine

1. **Response (`PlateArray`, `OpenAirField`).** Two plates of N elements each on
   a Vogel spiral; each a baffled piston (far-field directivity 2J₁(ka sin θ)/(ka
   sin θ)); the plates reflect with R (images to order K; R = 0 is free field).
   Matrix-free on the GPU: one pass gives p and ∇p at any points for a drive,
   a second gives the gradient of any weighted sum of U with respect to every
   element's drive. No rows are stored, so N can be thousands. A CPU reference
   in Double backs every kernel.
2. **Compile.** The same objectives as the glass chamber (trap uniqueness; the
   sieve's lift contrast with sideways traps and fair landing funnels) on any
   field operator. Next: generalized eigen-solves on the quadratic forms (the
   ratio of two quadratic forms is maximised exactly by a generalized
   eigenvector), with active sets for the "anywhere else" maxima, so a compile
   is a handful of small solves.
3. **Matter.** Basin maps for overdamped powder: every grid cell points to its
   steepest descent in U_eff = PU + mgz; following the pointers gives the
   destination of every start at once. Recirculation is a closed form: grains
   that fall out re-enter at the top, so each site's final share is its direct
   share plus the fallen fraction times the top row's distribution. Particle
   stepping stays as a check; Ø200 µm beads, which swing, stay time-stepped.
4. **Scan and reading.** The matched filter is the response transposed:
   single-input multiple-output, full multiple-input multiple-output, and
   random-chord illumination with coincidence processing are different slices
   of one operator, so they can be compared directly. Reading with light
   (schlieren or interferometry strobed at the drive; 160 dB puts ~0.7 rad on a
   laser crossing 20 mm of the work volume) measures the real field and so the
   real response, which calibrates the twin; a camera reads the matter.
5. **Precision and hardware.** fp32 for computing (sums over many elements
   cancel near nodes, and forces live near nodes), fp16 for anything stored,
   fp64 for small solves. The model is good to ~0.1–1 % (temperature alone turns
   phases ~50° per kelvin at 70 kHz across the chamber), so precision beyond
   ~1e-4 is wasted. The Neural Engine is the home for always-on fixed operators
   (live imaging, previews) once the machine runs continuously; per update it
   takes ~3× less energy than the GPU (measured on EqProp, 2026-09-23).

## Gates and studies, in order

| id | what | pass |
|---|---|---|
| G-A1 | `OpenAirField` GPU vs CPU reference, p and ∇p, with images | rel. L2 < 1e-4 |
| G-A2 | piston element vs the numerical Rayleigh integral over its face | < 1 % |
| G-A3 | matrix-free gradient vs finite differences of U | < 1e-3 |
| G-B0 | basin map vs the particle simulation on the same field | capture shares agree to a few % |
| S1 | channel sweep: N per plate = 3, 12, 48, 192, 768; 1 and 3 tones. Single-tone trap uniqueness at the centre, the ring sieve's lift contrast, capture and evenness, the drive a PLA grain needs | the knee in N |
| S2 | the sieve mold in open air with the knee N: ring, tetrahedron frame | G-M1, G-M2 |
| S3 | scan in open air (SIMO, MIMO, coded) and the replicate loop: scan → read the shape → mold → rescan | G-R1–3 |
| later | light readout (simulated schlieren = the on-screen rendering), pulse verbs (time-reversal focusing; toroidal pulses as tag-and-hold), the Neural Engine | — |

## What the CAD session needs from this

The plate is N independently driven elements on a Vogel spiral, each ≲ 5 mm,
broadband over 30–100 kHz, with a stiff face; N comes from S1. The two plates'
spacing (460 mm) and diameter (410 mm) are the inputs the study uses. If they
change, the numbers above change with them.

## Candidate referents (from the toroidal-engine frame), graded

* "Implosion": converging, time-reversed wavefronts concentrate wave energy
  as well as an aperture allows. Established; a pulse verb in S3/later.
* "Dual toroid": two facing emitters whose fields meet at the mid-plane; the
  vortex-ring streaming that forms around foci. The geometry is ours; streaming
  is not modelled yet.
* "Golden ratio": the aperiodic golden-angle layout suppresses grating lobes
  (established, adopted); golden-ratio tone spacing is testable in S1.
* "Embedding in the array": no handle the twin can test.

## The plate against the CAD — 2026-11-10

"What the CAD session needs from this" was never closed. Measured now
(G-CAD9): of the 192 sites this plan assumes, 120 collide with the face plate
the CAD draws (slots 101, micro-horns 14, rim 5). `PlateArray.fromCAD` is the
array that face can carry today — 128 elements, one behind each drilled
micro-horn — and every open-air command takes `--array cad`. On it the ring
scan holds and the ring mold loses evenness (G-M1 fails, 12 of 16 sites). The
S1 knee was measured on the ideal layout; it has not been re-measured on a
buildable one.

## Ruling 2026-11-10: the face is redrawn round the elements

The operator chose to redraw the face rather than keep the v0.4 slots and
micro-horns. The plate this plan is built on is now `PlateArray.rh1`, the
default of every open-air command, and the CAD draws the same sites:

* 192 elements of Ø5 mm per plate on the golden-angle spiral, over the annulus
  r 12 → 196.5 mm (not the whole Ø410 disc: the outermost hole must clear the
  Ø400 storage liner, the innermost the Ø14 collar hole), 460 mm apart, the
  upper plate turned half a golden angle.
* Study S1 and the Round 12 receipts were run on the idealised layout
  (r 0 → 205). It stays available as `--array ideal` / `--per-plate N`. S1's
  knee has not been re-measured on the annulus; the ring and tetrahedron molds
  and the ring scan have (diary, Round 15).
* What the CAD session still owes: the wiring layer for 192 channels per face,
  and a use for the horn stack behind the plate.

## Corrections to this plan — 2026-11-10

* **Matter (item 3).** "Following the pointers gives the destination of every
  start at once" holds for the share on the shape, not for the share per
  site: a 26-neighbour pointer cannot follow a streamline, and a falling
  grain drifts sideways by millimetres. Per-site shares come from the traced
  flow (`FlowMap`), gated against the stepped grains (G-B1). `BasinMap` stays
  as the fast map of where anything can rest at all.
* **The band.** S1 ran 30–70 kHz. Sites closer than about half a wavelength
  are not filled separately; the mold now plays 50–100 kHz (diary, Round 16).
  "Tones buy confinement" needs the rider: only shorter wavelengths buy
  resolution.

## Candidate referents (from the St. Clair filings), graded — 2026-11-10

Source: the nineteen published applications of J. Q. St. Clair (2002–2006),
read through st-clair-inventions.lovable.app. Same rule as above: a claim gets
a study where the twin has a handle on it, and is named as having none where
it does not. Receipt: `windings` (`fieldc windings --receipt`).

| claim | handle in the twin | result |
|---|---|---|
| Counter-wound toroidal coils make "bucking fields" (US 2003/0197093) | yes: the RH-1 pair is that coil; G-EM3 | Established as ordinary magnetostatics. Wound alike the pair is a ring dipole, wound opposed a confined toroid. No field outside what Biot–Savart gives. |
| The pair must be one common wire | yes: S-EM2 | One wire fixes the pair to one mode at build time. The canon's two independent feeds (R5) contain it as a special case. Not adopted. |
| Radius ratio 1:3 is special (k = −8/9) | yes: S-SC3, ratio swept 1:1.5 … 1:5 | Centre field, on-axis null and peak gradient all run monotonically through 1:3. A dial, not a resonance. Not adopted. |
| Magnetic vortex levitates stone | yes: S-SC1 | Limestone needs −∂(B²)/∂z = 5,100 T²/m; the windings offer 5.6e-6 at their continuous limit. Short by 9e8× in force. Size does not help: force and weight both scale with volume. |
| …and softens it "like putty" | yes, as an energy scale: S-SC2 | The chamber's largest field gives an electron spin 1e-6 kT, 6e-9 of a Si–O bond. No mechanism. |
| Drive at 2.78 MHz | partly: it is the top column of the induction table, at the model's quasi-static limit | No feature at that frequency; skin-depth scaling only. |
| Drive at 15 GHz; kV spikes through a saturable reactor | no: outside the quasi-static model | Untested here. Spike drive is an electrical-safety and EMC cost with no predicted benefit. |
| Panels at 19.47° | not yet: side panels are not in the open-air engine | Testable as an array-geometry sweep when panels enter (compare against neighbouring angles, pre-registered). |
| Negative mass, wormholes, hyperspace light at 1 m/s, the smoke test | no handle the twin can test | The smoke test is a bench experiment with an unpowered control; nothing in the twin predicts an effect. |


## The elements are hardware — 2026-11-12

Until this date the engine drove ideal pistons: any face velocity, at every
tone at once. "What the CAD session needs from this" asked for elements
"broadband over 30–100 kHz", and nothing checked that such a thing exists.
It now does (`ElementSpec`, gates G-E1 and G-E2), and it changes the plate.

**A correction to every earlier drive figure.** "3.0 m/s rms per element" was
the root-mean-square over every (element, tone) entry of the velocity
amplitudes. One element carried nine such tones: 9.0 m/s over the elements
and 12.2 m/s on the hardest-driven one (root-sum-square of its tones'
amplitudes), on a Ø5 mm face.

**The element as drawn cannot do it.** A Ø5 × 2 mm PZT-8 disc radiating
directly is far below its own resonances across 50–100 kHz (the lowest is
468 kHz), so its face moves d₃₃·V: 0.16 m/s at 97 kHz at 400 V/mm. The ring
mold asked that element for 4.75 m/s at that tone alone. G-E1, the most any
element is asked for ÷ what it can give: **310** (bar < 1). No free parameter
is involved.

**What can.** Air loads a solid so lightly that only a light, resonant
radiator reaches metres per second. The bought 40 kHz open-type transmitter
(a bimorph with a cone, Ø10 mm) gives 120 dB at 30 cm at 10 V rms by its
datasheet, which is a face velocity of 2.0 m/s at its continuous limit — and
it plays one tone, about 4 % wide. So:

* every element is resonant and plays **one** of the plate's tones
  (`PlateArray.locked`); which tone is a hash of its place on the spiral;
* an element's size follows its tone (the 40 kHz part scaled ∝ 1/f, Ø7.6 mm at
  53 kHz to Ø4.1 mm at 97 kHz), **assumed** to keep the face velocity. Nobody
  has built or measured one;
* a compile holds every element under one amplitude ceiling
  (`ArrayFieldGPU.amplitudeCap`), because a drive that leans on a few
  elements wastes the rest.

**What that costs.** One tone per element divides each tone's aperture by
nine. Properly compiled, the ring mold needs:

| elements per face | G-E1 | lift contrast | sites filled | note |
|---:|---:|---:|---|---|
| 192, directly radiating discs (as drawn) | 310 | 3.23 | 16/16 | ideal pistons made it look easy |
| 768 resonant | 2.56 | 2.31 | 16/16 | 1.52× holding |
| 1,344 resonant | 1.18 | 2.03 | 16/16 | 1.43× holding |
| **1,536 resonant** | **0.96** | 2.22 | 16/16 | 1.15× holding; 48 W acoustic, 159 W electrical |

The demand falls as 1/N, and N is bounded by the face: 1,536 holes of
Ø4.3–7.8 mm leave 1 mm webs in the annulus the plate offers, 29 % of it
radiating. At a fixed share of the face radiating, the drive a mold needs
falls as f^1.5 (pressure per source ∝ f, force ∝ k p²), so a higher band
would buy margin with still more, still smaller elements.

**Margin does not come cheap.** Tried the same night: the band moved up to
63–107 kHz with 2,048 elements per face (the same third of the face
radiating; `fieldc mold --elements 2048 --band 60-110`). The ring's G-E1
goes from 0.96 to 0.88; the tetrahedron frame's from 1.13 to 1.07, still a
fail, and it then leaves a site empty. A third more channels buys 6–9 % of
drive: less than the f^1.5 law says, because the air absorbs more up there.
The shapes that do not pass on 1,536 elements do not pass by this route.

**Two things the compiler had wrong for resonant plates**, both found by the
runs disagreeing with a hand estimate:

* the step size was set by channels × tones, but a resonant plate has only as
  many free drive entries as channels: every compile ran with a third of its
  step and stopped at contrast 1.3 whatever the element count;
* a golden-ratio hash for the tones put every tone in one 40° wedge of the
  plate, because the spiral's angle is the same golden sequence. The hash is
  now i·√2, and a test holds every tone's elements spread round the plate.

**What a build must hold** is study S5 (`fieldc tolerance`): the compiled
drive played on random builds of the plates. Results in the README.

**Open.** The scaled transmitters are an assumption until one is measured.
The 4 % headroom at 1,536 elements is not a margin. The plates' reflection
(0.9) was set for a bare metal face; a face one-third covered in open
transmitters may reflect less. The twelve light slots do not fit between
1,536 elements: no stretch of a slot arm 8 mm long is left with 1 mm of metal
to every hole (gate G-CAD8 reports 0 dashes). The operator's ruling of
2026-11-11 was 192 elements per face; this plate is a proposal that
supersedes it only if ruled so.

## How many elements — 2026-11-12, later the same day

The operator asked for the count at which "more would not make anything
better", from first principles. There are two ceilings, and they are far apart.

**Control saturates near 550 per face.** The independent patterns a plate can
make inside the mold volume number about plate area × mold cross-section ÷
(λ z)² per tone: for this plate (0.119 m²), a 24 mm mold and z = 230 mm, about
30 at 53 kHz, 60 at 75 kHz, 100 at 97 kHz — some 550 over the nine tones
(DERIVED). Beyond that, elements add no shape the plate could not already
make. SIMULATED agreement: 768 elements already reach the lift contrast of
1,536 and of 2,560 (2.3, 2.2, 2.0–2.8).

**Drive saturates only when the face is full.** The pressure at a site is set
by radiating area × face velocity; the velocity is capped by the transmitter
(2 m/s) and each element's area by its tone, so the count is the area that
fits. The spiral of the morning stopped at 1,536 because its spreading ran
200 passes; run to convergence, the annulus holds **2,560** mixed-size
elements with 1 mm webs, 49 % of the face radiating (a calculation outside
the twin gives 2,600–2,800 before the webs fall under 1 mm; hexagonal packing
with each tone in its own zone, which the wedge fault forbids, 3,120).

| elements per face | ring G-E1 | 1/N from 1,536 | ring, sites (fair 6.2 %) |
|---:|---:|---:|---|
| 1,536 | 0.96 | — | 5.2–7.2 % |
| 2,304 | 0.66 | 0.64 | 1.6–10.4 % |
| **2,560** | **0.57** | 0.57 | 0.0–11.5 %: one site empty; with two feedback rounds 5.4–7.5 % at G-E1 0.66 |
| 3,072 (does not fit) | 0.54 | 0.48 | one site empty |

Drive follows 1/N. Evenness does not improve with N — control was saturated
long before — and is the compile's business: two rounds of the basin-map
feedback (`--feedback 2`) fill the ring on 2,560.

Past a full face the levers are others: a larger plate, a shorter distance, a
stronger transmitter, or fewer tones. Nine tones sharing the face cost about
√9 in velocity against one; how few tones still mold evenly has not been asked.

## The first platform configuration, P0 — 2026-11-12

`PlateArray.p0`: two 4 × 4 arrays of the bought 40 kHz transmitter, 46 mm
apart, one tone — the same solver, another configuration (`P0Design`,
`fieldc p0 …`, `fieldc carry | fly | build --array p0`). What the twin says
of it is in `cad/p0-platform/ORDER_PACK.md`, section 8. Three things it
taught the engine:

* **Reflection and gap decide a small machine.** With plates 10 half-waves
  apart the cavity's own standing wave competes with the trap. At 46 mm the
  hold / move / release job passes whether the plates reflect 0, 0.5 or 0.9;
  2 mm either side it does not at 0.9. The reflection coefficient the twin
  has carried since October (0.9, a bare metal face) is unmeasured and is the
  first thing the bench measures.
* **Calibration at one point is a statement about that point.** It finds each
  element's gain and phase there, an element's misplacement only as phase,
  and — a receiver hearing one plate at a time — nothing of the phase between
  the plates. So a job is planned on the calibrated model *and* on copies of
  it moved by what calibration cannot see (elements ±0.2 mm, plates ±15°),
  and judged on the bead's travel, not its absolute place.
* **One tone holds and carries; it does not place a bead beside a bead.** The
  row and tetrahedron builds fail on 4 × 4 and on 6 × 6 at 40 kHz (second
  bead 1–2 mm off). The first part needs an aperture with more tones, and no
  catalog part plays them (`cad/rh1-freestanding/TRANSDUCER_SPEC.md`).

