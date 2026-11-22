# RESULTS HE-1e — a ranking-aware rule

- Pre-registration: `holo/HE1E_PREREG_2026-11-22.md`, committed with the script in 47b9446, before the run.
- Receipt: `holo/runs/he1e_receipt.json`
- Register: SIMULATED. The score is a pressure-node proxy on the closed Rev F chamber, 7³ sites.
- One run over 65 pairs (5 wafers × 13 shapes). No threshold or code changes were made.

## Gates

| Gate | Result | Numbers |
|---|---|---|
| E1 · the gap closes | **PASS** | Median IoU(R1+)/IoU(ceiling) = **0.86**. Per wafer: 0.86, 0.93, 0.83, 0.86, 1.00. |
| E2 · the rule's start matters | **FAIL** | Mean IoU(R1+) − IoU(Rand+) = **−0.04**. The random start is ahead on 32 pairs and behind on 18. |
| E3 · it works almost everywhere | **PASS** | R1+ beats chance on **65/65** pairs. |
| E4 · the polish helps | **PASS** | Mean gain over bare R1 = **+0.33** (0.33 → 0.65). |

Reported:
- Mean IoU: R1 0.33, R1+ 0.65, Rand+ 0.70, ceiling 0.74.
- Median Rand+/ceiling = 1.00.
- A polish used about 6,200 loss evaluations: 30 iterations with finite-difference gradients over 120 reals.

## What the run shows

1. **A short ranking-aware polish closes the gap.**
   - Thirty iterations of the rank surrogate, on the chamber's own calibration, reach a median 86 % of the full optimiser.
   - They beat chance on every pair.
   - The thin targets that defeated bare inversion are fixed: the rod goes from 0.02 to 0.80, the waveguide from 0.06 to 0.48 and the sphere from 0.18 to 0.72.
2. **Inversion is not a useful starting point.**
   - From random drives, the same budget does at least as well (median 100 % of the full optimiser).
   - The inversion start lands in a slightly worse basin on most bulky shapes: cube and dodecahedron 0.71 against 0.85, horn 0.73 against 0.83.
   - So in this chamber the landscape is easy: one short run from noise reaches what four long restarts reach.
   - The value is in the ranking objective plus a fresh calibration, not in the inversion rule.
3. **What the `.holo` should hold, refined.**
   - The equation is the *objective*: the target set and the rank criterion "make these sites the quietest".
   - At write time it is evaluated on the chamber's freshly measured transfer by a short optimisation.
   - A stored table of drives does not transfer between chambers (HE-1c), and none is needed: the drives are computed in a few thousand evaluations of a 5 × 12 × 343 forward model.
   - With an analytic gradient, the same 30 iterations would be about 30 evaluations.

## Caveats

- The "ceiling" is the HE-1 optimiser (4 restarts × 300 iterations), not a proven optimum. On 9 of 65 pairs R1+ exceeds it.
- The proxy has no Gor'kov gradient terms, and the 7³ grid makes the cube and dodecahedron identical. The ease of the landscape may not hold on a finer grid or with the full force model.

## Next (each needs its own pre-registration)

- The same comparison on a finer grid (at least 11³) with the Gor'kov potential, where the landscape may be harder and a good start may matter.
- An analytic gradient, giving the write-time compute in evaluations rather than wall time.
