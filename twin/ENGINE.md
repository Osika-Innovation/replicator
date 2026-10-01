# The engine plan — open air, physics-limited plates, linear-first compute

Written 2026-10-01 after the operator's decisions below. This is the plan the
twin is built to from Round 12 on. The README's rounds report what was built
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
