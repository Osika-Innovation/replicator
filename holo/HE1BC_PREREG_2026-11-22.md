# PREREG HE-1b and HE-1c — the joint listen rule, and rule plus calibration vs a stored lookup

- Date: 2026-11-22
- Task: hub #46 (lane `sim`), agent `claude-replicator-paper`. Follows HE-1 (#42, commits 9b677cf and 6333344).
- Script: `holo/he1bc_holo_equation.py`. It imports the HE-1 functions read-only.
- Receipt: `holo/runs/he1bc_receipt.json`
- Register: SIMULATED. The score is the same pressure-node proxy as HE-1. No bench claim.
- This file and the script are committed **before** the first run.

## Why

HE-1 found two things:

1. A per-shape lookup (R0) writes well on the nominal wafer but falls to chance on wafers detuned by 0.5 %.
2. The listen rule (R3) failed. The cause was its specification: five tones were solved independently, each at unit norm, and then summed, so the high-gain tones swamped the suppression.

HE-1b fixes the specification. HE-1c tests the reading the paper now gives, that "an equation is a rule plus an in-chamber calibration".

## Fixed inputs

These are identical to HE-1:
- `cadence_closed_chamber_ops.npz` (H: 5 members × 5 tones × 12 ports × 343 sites);
- the 13 curriculum shapes, sampled and binarised the same way;
- the same exclusion rule (none were excluded in HE-1).

## Write models

- **Per-tone model** (HE-1, unchanged): each tone's 12-vector has unit norm, and I_i = Σ_t |u_t·H_t,i|².
- **Joint model** (new): the stacked 60-vector U has unit norm, so tones may be weighted or switched off. I_i is the same sum.

In both models the predicted set is the k = |S| lowest-I sites, and the score is IoU.

## HE-1b — joint listen rule

| Route | Definition |
|---|---|
| **R3j** | A_S = Σ_{i∈S} M_i and A_N = Σ_{i∉S} M_i, where M_i is the 60×60 block-diagonal matrix with blocks h_t,i h_t,iᴴ. U is the generalised eigenvector of (A_S, A_N + 10⁻⁹·tr(A_N)/60·I) with the smallest eigenvalue, scored under the joint model. |
| **R0j** | Lookup under the joint model. The optimiser, loss, iteration count and seeds 0–3 are those of HE-1's R0; only the normalisation is joint. |
| **Chance-j** | 1,000 random unit 60-vectors per shape (seed 7); the 95th percentile. |

Expected from the mathematics, stated in advance: A_S and A_N are block-diagonal, so the minimising eigenvector lies in a single tone block. R3j therefore selects the one tone with the best suppression ratio and switches the other four off. That is a valid and very short rule ("the best tone and its eigenvector").

| Gate | Statement | Pass | Prior |
|---|---|---|---|
| **B0** (sanity) | The joint model can write the targets | R0j > chance-j on ≥ 10/13. If it fails, B1 and B2 are NOT EVALUABLE. | 85% |
| **B1** (an equation matches lookup) | The joint listen rule nearly matches lookup | Median IoU(R3j)/IoU(R0j) ≥ 0.90 **and** R3j > chance-j on ≥ 9/13 | 20% |
| **B1w** (the equation works) | The joint listen rule writes recognisable targets | R3j > chance-j on ≥ 9/13 | 55% |
| **B2** (the swamping is fixed) | Suppression survives the joint score | Mean I on S < mean I off S for R3j on ≥ 12/13 | 90% |

## HE-1c — rule plus calibration vs a stored lookup

For each detuned wafer j = 1…4 and each shape (52 pairs):

| Arm | Definition |
|---|---|
| **Stored lookup** | HE-1's R0 drives, fitted on member 0 and recomputed deterministically with the HE-1 function, then evaluated on H_j (per-tone model). The same is done for R0j under the joint model. |
| **Rule + calibration** | R1 (Gerchberg–Saxton) re-derived from H_j and evaluated on H_j (per-tone model). R3j is re-derived from H_j likewise (joint model). |
| **Ceiling** | R0 refit on H_j with the HE-1 function (per-tone model, seeds 0–3). |
| **Chance** | Per pair, 1,000 random per-tone unit drives (seed 7) on H_j; the 95th percentile. |

| Gate | Statement | Pass | Prior |
|---|---|---|---|
| **C1** (calibrated rule beats stored lookup) | The rule is portable; the lookup is not | Mean over the 52 pairs of IoU(R1 on H_j) − IoU(stored R0 on H_j) ≥ 0.10 | 80% |
| **C2** (the calibrated rule still works) | Re-derivation reproduces HE-1's nominal behaviour | R1 on H_j > chance on ≥ 37/52 pairs (70 %) | 65% |
| **C3** (quality transfers) | The rule keeps its fraction of the ceiling | Median IoU(R1 on H_j)/IoU(R0 refit on H_j) ≥ 0.30. HE-1's nominal value was 0.40. | 55% |
| **C1j** (secondary) | The same as C1 for R3j vs stored R0j, joint model | Mean difference ≥ 0.10 | 45% |

## Honesty clauses

- The pressure-node proxy has no Gor'kov gradient terms, as in HE-1.
- The joint model is a change of write model, so B gates are not comparable one-to-one with HE-1's H gates. R0j is refit to keep the comparison within the model.
- The 7³ grid still gives the cube and dodecahedron identical targets. A finer grid needs new operators and is out of scope.
- No threshold changes after the first run. A rerun for a bug is disclosed with its diff in the results file.
