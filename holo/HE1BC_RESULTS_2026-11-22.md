# RESULTS HE-1b and HE-1c

- Pre-registration: `holo/HE1BC_PREREG_2026-11-22.md`, committed with the script in dc188cd, before the run.
- Receipt: `holo/runs/he1bc_receipt.json`
- Register: SIMULATED. The score is a pressure-node proxy on the closed Rev F chamber, 7³ sites.
- One run. No threshold or code changes were made. The post-run diagnostic below is read-only and changes no gate.

## Gates

| Gate | Result | Numbers |
|---|---|---|
| B0 · the joint model can write the targets | **PASS** | R0j beats chance on 13/13. |
| B1 · the joint listen rule nearly matches lookup | **FAIL** | Median IoU(R3j)/IoU(R0j) = 0.05 |
| B1w · the joint listen rule works | **FAIL** | R3j beats chance on 3/13. |
| B2 · the swamping is fixed | **FAIL** | On/off < 1 on only 9/13. |
| **C1** · a calibrated rule beats a stored lookup | **PASS** | Mean IoU difference over 52 pairs = **+0.29**: R1 re-derived scores 0.32, the stored lookup 0.036. R1 is ahead on 43/52 pairs. |
| **C2** · the calibrated rule still works | **PASS** | R1 re-derived beats chance on **44/52** pairs (the bar was 37). |
| **C3** · the rule's quality transfers | **PASS** | Median IoU(R1 re-derived)/IoU(R0 refit) = **0.47**, against 0.40 on the nominal wafer in HE-1. The refit ceiling averages 0.72. |
| C1j · the same comparison for R3j | FAIL | Mean difference +0.02 |

## What the run shows

1. **Rule plus calibration works, and a stored lookup does not.**
   - On the four detuned wafers, the stored per-shape lookup scores at chance (mean IoU 0.036).
   - The chamber-inversion rule (Gerchberg–Saxton), re-derived from each wafer's own transfer matrix, scores a mean of 0.32. It beats chance on 44 of 52 pairs.
   - It keeps about half of what a fresh per-wafer optimisation reaches (median ratio 0.47).
   - It does well on the bulky shapes: cube, dodecahedron and horn at a mean of 0.55; octahedron, icosahedron and triad at 0.40–0.43.
   - It fails on the thinnest targets: the rod (5 sites) and the waveguide (8 sites) are at chance, and the sphere (7 sites) is mixed.
2. **The listen family is the wrong criterion for writing.** The mechanism comes from the read-only post-run diagnostic.
   - As stated in advance, the joint eigenvector picks a single tone, so all its power goes to one tone.
   - With 12 ports, one tone has 12 complex degrees of freedom and cannot null more than 11 sites.
   - Above that, minimising the *energy ratio* Σ_S I / Σ_N I is achieved by making a few off-target hot spots loud, not by making the target the quietest set.
   - Writing needs the target to be the k quietest sites, which is a ranking criterion. That is why GS, which matches the field site by site, works and the energy-ratio routes do not.
   - When k < 12 (the rod), the null space of A_S is degenerate. The solver returns an arbitrary nulling vector, and in finite precision the on/off ratio lands above 1. The ring (on/off 0.10) shows the rule working when the geometry suits one tone.
3. **For the paper:** a `.holo` "equation" is a chamber-inversion rule run on a fresh in-chamber calibration of H. The listen (DORT) route is retired as a writer. It stays useful for *reading* (finding scatterers), not for writing shapes.

## Next (each needs its own pre-registration)

- A ranking-aware rule: GS with soft-rank target amplitudes, or a few iterations of R0 warm-started from R1. Does it close the gap from 0.47 to the ceiling?
- Thin targets: more tones or ports, or targets thicker than one site.
- A finer grid of at least 11³, which needs new operators.
