# field-compiler — RSW-1

Native macOS implementation of the Field Compiler.
Spec: [`papers/replicator_field_compiler.html`](../papers/replicator_field_compiler.html) (v0.8).

## Build and run

No Xcode required — Command Line Tools only.

```sh
swift build -c release
./.build/release/fieldc test              # unit suite (19 tests)
./.build/release/fieldc gate --receipt    # physics acceptance gates, writes Receipts/
./.build/release/fieldc machine           # describe the RH-1 preset
./.build/release/fieldc focus             # compile a centre trap, compare solvers
./.build/release/fieldc gpu               # Metal propagator vs CPU reference
./.build/release/fieldc render iso a.png  # offscreen machine render, no window server
./.build/release/fieldc shot --all        # every UI scene, both themes + contact sheet
./.build/release/fieldc broadband         # channel-count study: free field vs cavity+chord
```

## Status — honest

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
- **Drive amplitudes are not physical.** `maxAmplitude` is dimensionless, so
  `fieldc focus` reporting "holds 200 µm PLA: no" is not a real result — it
  compares a normalized field against real gravity. Drive needs to be specified
  as surface velocity or source pressure in SI before any levitation claim.
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
