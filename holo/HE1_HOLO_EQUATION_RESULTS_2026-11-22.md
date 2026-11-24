# RESULTS HE-1 — Is a `.holo` an equation?

- Pre-registration: `holo/HE1_HOLO_EQUATION_PREREG_2026-11-22.md`, committed with the script in 9b677cf, before the run.
- Receipt: `holo/runs/he1_holo_equation_receipt.json`.
- Register: SIMULATED. The score is a pressure-node proxy on the closed Rev F chamber, 7³ sites.
- One run. No threshold or code changes were made.

## Gates

| Gate | Result | Numbers |
|---|---|---|
| H0 · the chamber can write the targets | **PASS** | R0 beats chance-95 on 13/13 shapes. Its IoU is 0.60–1.00, against chance-95 of 0.05–0.11. |
| H1 · a universal rule writes nearly as well as lookup (R3, listen) | **FAIL** | Median IoU(R3)/IoU(R0) = 0.06. R3 beats chance on 3/13. |
| H1b · the same for R1 (invert the chamber) | **FAIL** | Median IoU(R1)/IoU(R0) = 0.40. R1 beats chance on 11/13. |
| H2 · the equation is short (R2) | **FAIL** | No shape reaches 0.95 × IoU(R0) at any m. |
| H3 · a rule survives wafer detuning better than a lookup | PASS as worded; **uninformative** | Mean drop R0 = 0.76, R3 = 0.03. R3 had almost nothing to lose. |

## What the run shows

1. **A lookup works, but only on the chamber it was fitted to.**
   - Per-shape optimisation of all 120 drive numbers writes every shape well (IoU 0.6–1.0) on the nominal wafer.
   - On the four detuned wafers, the same drives fall to chance (mean IoU ≈ 0.04).
   - This is the finding INS-05 predicted: the transfer decorrelates at a 0.5 % thickness detune. A `.holo` lookup is therefore a property of one chamber, not of the object.
2. **Inverting the chamber is a partial equation.**
   - Gerchberg–Saxton with only the target as input beats chance on 11 of 13 shapes.
   - It reaches 0.67–0.69 IoU on the cube, dodecahedron and horn, and 40 % of lookup quality at the median.
   - That is a rule with zero free numbers per object that already writes recognisable outlines.
3. **The listen route (R3) failed as frozen, and the cause is identified.**
   - Each tone alone works. On the cube, tone 0 alone holds 0.46 times the off-target intensity on the target sites.
   - The pre-registered write model sums intensity over five tones, each at unit drive norm. Tones with larger chamber gain then dominate the sum and erase the suppression. The summed on/off ratio is 0.98.
   - This is a flaw in how R3 was specified (independent per-tone solutions under a joint score), not a code bug. The same result holds in complex128 precision; the run's complex64 matmul warnings are spurious.
4. **Duplicate targets.** On the 7³ grid the cube and dodecahedron sample to the same 27 sites, so they score identically. The grid is coarse for shape discrimination.

## Next (not part of HE-1; each needs its own pre-registration)

- **HE-1b:** R3 solved jointly across tones, as one generalised eigenproblem on the stacked 60-dimensional drive.
- **HE-1c:** routes 1 and 3 re-derived per wafer from that wafer's measured H. This is the practical form of "an equation": one rule plus an in-chamber calibration. It tests whether the rule plus calibration beats a stored lookup across detuning.
- A finer site grid (at least 11³) so that Platonic solids are distinguishable.
