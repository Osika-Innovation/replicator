# Pre-registration: Icosahedral-quasicrystal volumetric array vs periodic vs random

Date frozen: 2026-08-01 (before any simulation run).
Lane: replicator / field compiler.
Origin: Winter audit Addendum 3 (memory
`project_winter_phase_conjugation_audit_2026-07-30.md`) — the
crystallographic-restriction fork: A₅ order in flat 3D forces
φ-inflation quasiperiodicity; candidate canonical 3D extension of the
cap's 2D Fibonacci/Vogel mesh (R1–R12 rulings).
Sim: `scripts/quasicrystal_array_prereg_sim.py` (this doc's RESULTS
section is empty until the sim has run once; nothing above the RESULTS
heading may be edited after the first run).

## Question

For a volumetric point set of N isotropic monochromatic sources (Born
equivalent: weak scatterers) phased to steer a far-field beam, does an
Ammann–Kramer icosahedral quasicrystal arrangement (a) suppress grating
lobes like a random array, and (b) beat the random array on *isotropy*
of sidelobe performance across steering directions?

## Arms (point sets, all ~N=800 in the unit sphere, equal density)

- **SC** — simple-cubic lattice, spacing tuned to hit N in sphere.
- **FCC** — face-centred-cubic lattice, same tuning (second periodic
  arm, so a periodic-arm failure can't be blamed on SC being a strawman).
- **RND** — uniform (Poisson) points in the sphere; 3 seeds
  (20260801, 20260802, 20260803), each reported.
- **QC** — Ammann–Kramer icosahedral quasicrystal by cut-and-project:
  Z⁶, par/perp stars = icosahedron vertex vectors (1, φ, 0)-family and
  their Galois conjugates (φ → −1/φ), acceptance window = perp-space
  zonotope (rhombic triacontahedron) with generic phason offset
  γ = (0.0131, 0.0237, 0.0347, 0.0453, 0.0561, 0.0673); global scale
  tuned to hit N in sphere.

## Physics and metrics (frozen)

Far-field array factor, conjugate phasing at steering direction u:
F(v) = (1/N) Σ_j exp(i k r_j·(v−u)); |F(u)| = 1 by construction.

- Characteristic spacing d_c = (V_sphere/N)^{1/3}, identical across
  arms by construction. Three wavelength regimes s = d_c/λ ∈
  {0.6, 1.0, 1.6} (sub-grating, onset, super-grating).
- Steering set: 48 Fibonacci-sphere directions. Evaluation grid: 16384
  Fibonacci-sphere directions.
- Main-lobe exclusion cone: angle < 3λ/D around u, D = 2·max|r_j|.
- **PSL(u)** = 20·log₁₀ max_{v outside cone} |F(v)|  [dB, ≤ 0].
- Per arm & regime: **median PSL** over the 48 steerings (lobe
  suppression), **std PSL** and **worst-case (max) PSL** (isotropy).

## Frozen predictions

- **P1 (control / sanity):** at s ≥ 1.0 the periodic arms (SC and/or
  FCC) show grating lobes: worst-case PSL > −3 dB at some steering.
  QC and RND stay below −3 dB worst-case at s = 1.0.
- **P2 (lobe suppression):** QC median PSL is within 3 dB of the RND
  median PSL in every regime. (If QC shows strong Bragg lobes that
  break this, the Winter-salvage quasicrystal candidate **dies** and
  the 2D-only Fibonacci-mesh ruling stands unchanged.)
- **P3 (isotropy — the actual bet):** std of PSL across steerings is
  smaller for QC than for every RND seed in every regime, and
  worst-case PSL for QC is no worse than the worst RND seed.

Decision rule: P2 AND P3 pass in ≥ 2 of 3 regimes → adopt the doctrine
sentence "A₅ on the boundary, φ-quasicrystal in the volume" as a
*candidate* geometry ruling for volumetric scatterer/perforation
layouts (still subject to a full-wave check in the compiler). Any P2
fail → candidate dead, log the negative. P2 pass + P3 fail → QC is
merely "as good as random," no reason to prefer it except determinism;
log as neutral.

## Declared limitations

Linear, far-field, isotropic point sources, Born single-scattering, no
element factor, no multiple scattering, no enclosure walls. This is an
array-factor screen, the same fidelity class as the 07-30 φ-comb PSR
screen — a gate for compiler-level follow-up, not a chamber verdict
(cf. `feedback_mdd_envelope_is_not_chamber_verdict`).

---

## RESULTS (append-only below this line; frozen text above)

Run 1, 2026-08-01, first execution of the sim after freezing.
Raw JSON: scratchpad `qc_prereg_results.json`; console table below.
Sanity: RND sidelobe floor matches the analytic peak-of-M-samples
prediction 10·log₁₀(ln M / N) ≈ −19.2 dB; SC/FCC grating lobes appear
exactly at s ≥ 1.0 as required. (numpy emitted spurious Accelerate
matmul RuntimeWarnings on macOS; outputs contain no NaN/Inf.)

| arm | s=0.6 med/std/worst | s=1.0 med/std/worst | s=1.6 med/std/worst |
|-----|--------------------|--------------------|--------------------|
| SC  | −6.5 / 8.7 / −0.1  | −1.4 / 3.1 / −0.03 | −0.5 / 0.7 / −0.07 |
| FCC | −5.3 / 6.5 / −0.1  | −1.7 / 4.4 / −0.03 | −0.6 / 1.4 / −0.00 |
| QC  | −6.9 / 1.9 / −5.9  | −3.7 / 2.4 / −1.0  | −2.9 / 1.4 / −1.1  |
| RND (3 seeds, range) | −19.8…−19.2 / ≤0.8 / ≤−18.1 | −19.2…−19.1 / ≤0.6 / ≤−17.3 | −19.2…−18.9 / ≤0.7 / ≤−17.4 |

**P1: PASS for periodic arms** (grating lobes at s ≥ 1.0, worst ≈ 0 dB)
**but the QC sub-condition FAILS** — QC worst at s=1.0 is −1.0 dB, i.e.
QC itself grows near-full-strength lobes past the grating onset.
**P2: FAIL in all three regimes** — QC median is 12–16 dB *worse* than
random, not within 3 dB.
**P3: FAIL** — QC std (1.4–2.4 dB) exceeds every RND seed (≤ 0.8 dB).

**Verdict per frozen decision rule: the candidate is DEAD.** The
"A₅ on the boundary, φ-quasicrystal in the volume" doctrine sentence is
rejected. Physical reading (post-hoc, marked as such): quasicrystals
have *pure-point* diffraction — that is literally how Shechtman found
them — so an AK array concentrates sidelobe energy into sharp
icosahedrally-arranged Bragg lobes instead of spreading it into a
diffuse floor. Aperiodicity alone is not the virtue; **spectral
diffuseness** is. This *refines* rather than threatens the 07-30 2D cap
ruling: the Vogel/golden-angle mesh is aperiodic *with a diffuse
spectrum* (no Bragg peaks), which is why it works — it is not a
quasicrystal. Candidate for a future pre-reg (NOT tested here): 3D
blue-noise / Poisson-disk point sets as the volumetric extension —
random's diffuse spectrum plus a minimum-spacing guarantee. Winter
salvage #2 (quasicrystal volumetric geometry) is now measured-dead;
salvage #1 (χ²-mixing φ-comb closure) remains open, blocked on the
nonlinear lane.
