# The engineering twin

The digital twin connects CAD geometry, first-principles physics solvers, neural warm-starts (`Cadence`), machine wire programs (`.fcode`, `.pattern`), and experimental receipts into one versioned system of truth.

## Four linked descriptions

| Description | Contents |
|---|---|
| **Module (`CAD` &amp; `body-response/0.1`)** | Geometry, constitutive properties, locating datums, ports, frequency response `H(f)`, and revision ID |
| **Response** | Analytical/FEM model or bench measurement, band, thermal drift, uncertainty, and provenance |
| **Process** | Feedstock state, `.fcode` actions, joining/consolidation recipe, and inspection criteria |
| **Evidence** | Git revision, numerical gate oracle, calibration matrix, and measured vs. inferred split |

Exact parametric CAD (`STEP` / `STL`) and spatial continuum fields remain complementary—never interchangeable.

---

## Charter, linear-first solver and verification gates (`twin/`)

Designed under strict software minimalism (`twin/CHARTER.md`, `twin/ENGINE.md`, `twin/CAD.md` — inspired by single-address-space discipline with an explicit line-count ceiling targeting `< 17,500` lines of dependency-free Swift and Metal):

1. **One linear-first physical insight:** The fluid between plates is linear, so acoustic pressure is linear in complex drive (`p = H(f)u`), time-averaged Gor'kov radiation force is a pure **quadratic form (`U(x) = Σ_f g_fᴴ K_f(x) g_f`)**, overdamped powder settling follows steepest-descent **basins (`BasinMap` &amp; `FlowMap`)**, and scanning is the transposed matched filter. Inverse compiles turn from billion-evaluation grid searches into compact generalized eigenvalue and quadratic optimizations.
2. **Matrix-free Metal GPU kernels gated by `Double` CPU oracles:** No gate passes on self-agreement alone:
   * `G-A1` (`OpenAirField` vs. CPU reference `< 1e-4`), `G-A2` (piston element vs. numerical Rayleigh integral `< 1%`), `G-A3` (matrix-free gradient `< 1e-3`), `G-A4` (`PartFieldGPU` scattered bead adjoint `~8e-7`).
   * `G-P1` / `G-P2` (`carry` and `fly` with steer-first continuation holding `≥ 99%` trap depth across `0.25 mm` steps; `build` and `build --shape tetra` touching placement under `15.4×` bead weight force limits in `G-B1` / `G-B2`).
   * **Solid structural coupling (`acbody` / `AC-03a`):** Coupled PZT + horn/disc solid finite elements (Gmsh / CalculiX) cross-checked against reduced plate approximations prior to machining `K-PORT+`.
3. **CAD-to-physics identity (`G-CAD9` &amp; `G-STEP`):** The simulation engine's radiating site list (`PlateArray`) and the CAD model's hole geometry derive from the exact same parametric coordinates within `< 1e-6 mm` (`G-CAD9`), while OpenCascade exact B-rep volumes cross-check every Swift solid mesh (`G-STEP`).
4. **Emulator = hardware (`MachineBackend`):** Both virtual runs (`EmulatedBackend`) and physical bench links (`SerialBackend` streaming to Prototype `RP2350B` hardware) consume identical binary `FCD1`/`.fcode` streams without special-case simulation code paths.

```sh
swift build -c release
./.build/release/fieldc test
./.build/release/fieldc cad check --rules
```

Additional active-branch work covers coupled solid bodies, contactless exciter sweeps (`X-EM`), and prototype controller firmware (`p0`); see [Current state](status.html) for what is published vs. in active bench qualification.

---

## Around-the-clock co-design and multi-island optimization (`holo/`)

To reduce human design iteration time, autonomous research runs (`holo/autoresearch.py`) optimize disparate plate and chamber topologies in parallel on Apple Silicon GPU memory (`bare_borosilicate`, `toroidal_coprime`, `toroidal_369`, `vogel`, `cartesian`, `icosa_12port`, `ha0_boro12`) against simultaneous **5-waypoint carry error, streaming vortex stability, `6`-stroke Platonic `SO(3)` form-drawing, ring mold contrast, and SVD effective rank**, validating champions cleanly on uncached `48³` / `13³` grids before exporting `body-response/0.1` packages.

---

## Learning and control

The twin mirrors real machine observables directly: differential BVD piezo states (`V(t)`, `I(t)`, `C₀(T) dV/dt`, `Θ ẋ(t)`), `τ_inertia = L / v_D` crystal bandwidth, passive cavity `Q_cav`, true Beer–Lambert opacity + `LightRead` acoustic phase across valid `HA-0` sightlines, and sparse `.pattern` chords (no artificial X-ray Radon cameras or brute-force `1 Tbit/s` streams).

Complex Hermitian `Cadence` connectomes (`W_fb = W_fwdᴴ`, `||W||₂ ≤ 1`, fitting `< 60 kB` `5%–10%` sparse `int8` in Prototype `RP2350B` SRAM for `~8–15 ms` settles vs. `~220–300 ms` dense) are benchmarked head-to-head against the direct physics solver (`NOWS`) across **four hardware-realism tiers**—`ideal_fp32`, `rp2350_ganglia_q8` (`75 MSa/s` `1-bit ΣΔ` + `C₀(T)` drift + `SMI` noise), `fpga_int8_sparse`, and `optical_pcm_analog`—validating prototype bench coupons `K-HAPTIC-PZT` and `K-MOSQUITO-SMI` prior to soldering ([Cadence, memory and wave compute](cadence-memory.html); [Compute, sensing and control](compute-control.html)).

---

## Show what is known (the three-layer epistemic viewport)

Every visualization and exported report separates three layers strictly (`Field Compiler §16.2`):

1. **Design intent:** Target STL geometry and ideal boundary tolerances.
2. **Simulated predictions (`SIMULATED`):** Model-derived pressure, Gor'kov force, flow basins, and temperature carrying explicit solver assumptions.
3. **Measured vs. Inferred (`MEASURED` / `INFERRED`):** Raw boundary observations tagged distinct from interior reconstructions synthesized by neural or geometric priors (`inferredBy`). An imported response or passing simulation receipt never substitutes for bench verification.

Read [Compute, sensing and control](compute-control.html), [Cadence, memory and wave compute](cadence-memory.html), [Scan, recover and matter stores](matter-loop.html), and [Current state](status.html).
