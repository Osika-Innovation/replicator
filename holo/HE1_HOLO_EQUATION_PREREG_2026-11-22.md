# PREREG HE-1 — Is a `.holo` an equation?

- Date: 2026-11-22
- Task: hub #42 (lane `sim`), agent `claude-replicator-paper`
- Origin: `karma-is-all-you-need/papers/final_replicator.html` draft 0.9, Sheet D §5.3
- Script: `holo/he1_holo_equation.py`
- Receipt: `holo/runs/he1_holo_equation_receipt.json`
- Register: SIMULATED. No bench claim.
- This file and the script are committed **before** the first run. Results go in a later commit.

## Question

A `.holo` file (`holo-field/0.1`) is a lookup table. For each shape it stores drives learned shape by shape. The Jen Han log (p. 234) describes "frequency keys" as "geometrical algorithms embedded in a carrier frequency". That would be one rule for the chamber plus a few numbers per object.

HE-1 asks: in the simulated closed chamber, does a universal rule, given only the target shape, write as well as per-shape optimisation? And how short can the per-object description be?

## Fixed inputs (read-only)

- **Chamber.** `holo/runs/cadence_closed_chamber_ops.npz`.
  - `H` has shape (5 wafer members, 5 tones of 32–160 kHz, 12 ports, 343 sites). The sites form a 7³ grid over ±12 mm.
  - Member 0 is the nominal wafer. Members 1–4 are detuned wafers, used only for H3.
- **Targets.** The 13 shapes of `holo.curriculum.build_curriculum_volumes(grid_size=28, half_extent=0.012, poly_mode="solid", rotations=None)`.
  - Each volume is sampled at the 343 sites by nearest grid index, `round((x + 0.012)/0.024 · 27)`, and binarised at ≥ 0.35. That gives the target set S.
  - A shape is excluded, and reported, if |S| < 5 or |S| > 171.
- **Write model.**
  - Drives u: one complex 12-vector per tone, each normalised to unit norm.
  - Field: p_t = u_t · H_t. Intensity: I_i = Σ_t |p_t,i|².
  - The predicted written set is the k = |S| sites with the lowest I, i.e. the pressure nodes, where dense particles collect.
  - Score: IoU of the predicted set with S.

## Routes

| Route | What it is | Free numbers per object |
|---|---|---|
| **R0 · lookup** | Per-shape numerical optimum of all 5 × 12 complex drives (120 real). Loss: softplus rank surrogate, `Σ_S softplus((ℓ_i − ℓ̄)/0.25) + Σ_notS softplus((ℓ̄ − ℓ_i)/0.25)` with ℓ = log I. Optimiser: L-BFGS-B, finite-difference gradient, maxiter 300, 4 restarts (seeds 0–3), best loss kept. | 120 |
| **R1 · invert the chamber** | Per tone, Gerchberg–Saxton phase retrieval. Target amplitude is 0 on S and 1 off S. Start with phase 0; run 100 iterations of least-squares u_t, then set the phase from p. | 0 (rule + target) |
| **R3 · listen (DORT)** | Per tone: A_S = H_t[:,S] H_t[:,S]ᴴ (the time-reversal operator of point scatterers at S) and A_N the same off S. u_t is the generalised eigenvector of (A_S, A_N + 10⁻⁹·tr(A_N)/12 · I) with the smallest eigenvalue. | 0 (rule + measured operator) |
| **R2 · shortest** | R3 restricted to the top m left-singular vectors of H_t, for m ∈ {1, 2, 4, 8, 12} per tone. | 10·m real |
| **Chance** | 1000 random unit drives per shape (seed 7); the 95th-percentile IoU. | — |

## Hypotheses and gates (frozen)

| Gate | Statement | Pass | Prior |
|---|---|---|---|
| **H0** (sanity) | The chamber can write the targets at all | R0 IoU > chance-95 on ≥ 10 of the included shapes. If it fails, H1–H3 are NOT EVALUABLE. | 85% |
| **H1** (an equation exists) | A universal rule writes nearly as well as lookup | Median over shapes of IoU(R3)/IoU(R0) ≥ 0.90, **and** R3 > chance-95 on ≥ 9 included shapes. R1 is scored the same way and reported as H1b. | 50% |
| **H2** (the equation is short) | Few chamber modes suffice | The median shape reaches 0.95 × IoU(R0) in R2 with m ≤ 4 per tone. | 40% |
| **H3** (equations generalise) | A rule survives wafer detuning better than a lookup | With drives fixed from member 0 and evaluated on members 1–4, the mean IoU drop of R3 is at least 0.02 smaller than that of R0. | 55% |

Exploratory, not scored:
- a comparison with Cadence's learned `.holo` drives, which live in a different basis;
- a symmetry (irrep) decomposition of the R3 drives;
- per-shape tables.

## Honesty clauses

- The write model ranks pressure nodes only. Gor'kov gradient terms are not in the ops file (`H` holds pressure only), so this is a proxy for where dense particles collect, not a levitation-force claim.
- R3 optimises a ratio that is close to, but not the same as, the IoU score. If R3 beats R0, the R0 optimiser was weak; that will be reported, not read as "the equation beats lookup".
- No threshold changes after the first run. Any rerun for a bug is disclosed in the results file with its diff.
