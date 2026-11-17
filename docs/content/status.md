# Current state

**Reviewed November 17, 2026.** This checkpoint separates the **Ultimate Architecture (long-horizon physical limits)**, the **Bootstrap Prototype (`P0` / `HA-0` workshop seed)**, and **verified code vs. pending bench gates**. No passing simulation or CAD export constitutes a hardware procurement or physical proof.

## Programme tracks: Ultimate targets vs. Prototype bootstrap

| Area | Ultimate architecture target | Prototype bootstrap (`P0` / `HA-0`) &amp; current record | Next physical / verification gate |
|---|---|---|---|
| **Engineering handbook &amp; code** | Self-contained canonical architecture across coordinated physics and closed manufacturing loops | `docs/content/*.md` owns current specifications (superseding standalone HTML papers); public `twin/` baseline at `1b708a2` with active branches for solid bodies (`acbody`), `X-EM`, and firmware (`p0`) | Keep handbook, `catalog.json`, and active receipts synchronized across releases |
| **System architecture** | Coordinated 3D acoustic, EM, and optical wavefields with zero moving parts and zero internal tools | Two-carrier contract (`p(f) = H(f)u(f)`), `Ø12 mm` bore + `270°` clear radial sightlines, identical `.fcode`/`.pattern` wire protocol | Validate coordinated module datums on initial assembly (`CAD-01`) |
| **Acoustics** | Continuous optically-addressed `PMN-PT`/photoconductor film (`~10⁵` pixels) over phase-conjugate multimode fiber; graded phononic tapers; argon rung to `1 MHz` | `3 + 3` / `6 + 6` low-inertia broadband PZT patches (`τ_inertia = L / v_D`) on supersonic plates + SLA modulo-`2π` phase ring + `1.2 mm` PCB backing absorber; Langevin retained as CW comparator | Bench-measure cartridge + `Ø10` horn + `Ø120` Al blank against solid finite elements (`K-PORT+`); test `K-HAPTIC-PZT` |
| **Compute, sensing &amp; control** | Passive optical facets, fiber tomography, and near-zero-electricity wave compute (`EML` diodes + `Sb₂S₃` holograms + `Open` excitable neural-gel wave substrates) | **Prototype scaffolding only:** collocated `RP2350B` `75 MSa/s` `1-bit ΣΔ` + `XOR` lock-in ganglia on shared `XIN`/`SYNC`, `< 60 kB` `5–10%` sparse `int8` SRAM Brain Slot (or optional `SoC-FPGA`), Ring-0 bare-metal executive | Simulate `75 MSa/s` `1-bit ΣΔ` under `0.3%/°C` `C₀` drift &amp; `−70 dB` echoes, then bench-verify `K-HAPTIC-PZT` &amp; `K-MOSQUITO-SMI` |
| **Cadence &amp; holographic memory** | `W_fb = Wᴴ` physical reciprocity (`ε = εᵀ`), 2-beam interference `ΔW`, volumetric `Sb₂S₃`/`Sb₂Se₃` chord memory (`η = (M#/M)²`) | Complex Hermitian `EqProp` trained offline on Apple Silicon (`MLX` + chaotic Metal kernels) against `NOWS` and Core-13 / `HA-0` STL parts with 2D OPH quarantine | Pass `rp2350_ganglia_q8` &amp; `optical_pcm_analog` benchmarks; verify `Sb₂S₃` `M#` &amp; write endurance |
| **Optics &amp; metamaterials** | Bidirectional toroidal-pulse stem (`space ⊗ pol ⊗ spectrum` tomography), `756 nm` metasurface SLM, `OAM`/skyrmion modes, optical tweezer fingertips | Nanoimprinted `TiO₂` diffractive facets + `3`-pin TO-can `SMI` laser diodes (`SOT-23 ×200` AC gain + `1-bit ΣΔ`) across `HA-0` clear sightlines | Verify `0.1 rad` `LightRead` ultrasonic phase SNR alongside `Ø1 mm` DC occlusion on `K-MOSQUITO-SMI` |
| **Electromagnetics** | Containerless `J × B` melt shaping, magnetic inclusion orientation, `m/q` ion sort, and traveling-wave axial bore lift (`R10`) | `em-integration` study recommends no EM process coil in first acoustic seed build (`9 × 10⁸×` short at `0.3 m` standoff); lossless flat-coil exciter `X-EM` proposed for blank metrology | Run `X-EM` calibration sweep on `K-PORT+` aluminum disc blank |
| **Manufacturing, scan &amp; stores** | Non-moving full-sphere `S(f)`, combined-field recipes, mirrored `R9` active sort/reclaim chamber fed by Salt/Ash/C/H₂O/Air/Noble-Gas stores | `95%` CF / `5%` Golomb-FM + `SMI` scans validated via `G17` (`measured`/`inferred`), `G18` held-out gates, `G19` static phantoms; indexed `ha0_septum_cap` vials | Demonstrate repeatable hold/move/release, then build &amp; qualify first upgrade part (`FAB-01`) |
| **Physics framework** | Unifying [OPH](oph.html) &amp; material response chain from atomic spectra to continuous field operators | Formal OPH carrier algebra + refined Gauss/Green atomic checks (`check_physics_derivations.py`) | Map candidate wave-substrate hypotheses cleanly to measurable response laws |
| **Hardware evidence** | — | No integrated multi-carrier Replicator bench demonstration is established yet in this review | Execute `K-PORT+`, `K-HAPTIC-PZT`, `K-MOSQUITO-SMI`, and `FAB-01` receipts |

Detailed simulation receipts and branch studies retain their exact scope; nothing in the active table clears physical purchasing or hardware release without review.

---

## Evidence vocabulary

| Label | Meaning |
|---|---|
| Design decision | The direction or requirement the programme has chosen |
| Derived | A calculation with stated assumptions and units |
| Simulated | A result from a specified numerical model |
| Published experiment | A result reported by an identified external source |
| Bench measured | A project measurement with apparatus, calibration and raw records |
| Research hypothesis | A proposed mechanism or explanatory model with a discriminating test |

Writing should be direct: state whether an item belongs to the **Ultimate Architecture** or the **Prototype Bootstrap**, name its evidence class, and identify its decisive next test.

## Promotion gates

A source enters the library with its identity and review depth. A model earns use through independent verification (`G-A1`–`G-B2`, `NOWS` comparisons). Hardware earns a capability through repeatable manipulation and metrology (`G17–G19`, `FAB-01`). An upgrade earns adoption through a before-and-after measured improvement on the same machine task.

Published experimental results remain strictly attributed to their external authors; literature demonstrations and internal bench measurements are never interchangeable.

## Maintenance

Update this page whenever a subsystem milestone or prototype-vs-ultimate boundary changes. The [agent guide](agents.html) defines lane ownership, and [catalog.json](../catalog.json) assigns every document a stable ID.
