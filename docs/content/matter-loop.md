# Scan, recover and matter stores

<div class="lead">A self-upgrading manufacturer must close all three modes—seeing what exists (Scan), building under continuous closed-loop verification (Assemble), and separating reusable feedstock (Recover)—around stable chemical stores and honest provenance tracking.</div>

Both the **Ultimate Architecture** and the **Bootstrap Prototype (`P0` / `HA-0`)** share the same conservation laws and `.pattern` data contracts, while differing cleanly in how apertures, optical paths, and feedstock vials are realized today versus at the physical limit.

---

## Scan: non-moving 3D tomography and scattering

Every scan populates the machine's multi-port **scattering matrix `S(f)`**: given boundary drive `a`, the boundary returns `b = S(f) a`. Three spectral eigenspaces carry distinct physical information:

* **Zeros of `S(f)`:** Drive states completely absorbed by the object (coherent perfect absorption).
* **Eigenvectors of `S(f)`:** Characteristic modes scattered back into themselves up to a phase shift.
* **Poles of `S(f)`:** Natural complex resonances whose ring-down spectrum (`f_n`, linewidths, extracted via matrix-pencil methods) fingerprints geometry and material stiffness.

### Zero moving parts is Plan A (`Design decision`)

Object turntables and internal mechanical scanners are removed from the baseline architecture (`Field Compiler §18`). Static reconstruction closes the **specular gap** (facets whose surface normal never satisfies any `(Tx, Rx, f)` bistatic bisector) in strict priority order:

| Rank | Static diversity mechanism | Motion required? | Engineering condition |
|---:|---|---|---|
| **1** | **Calibrated multi-bounce wall virtual mirrors** | None | Known wall reflections act as virtual apertures (`Zhang / Wilcox / Drinkwater 2010`), **gated strictly behind a measured empty-chamber Green's function `H(f)`**—never a purely analytic assumption |
| **2** | **Broadband frequency comb diversity** | None | Each harmonic line reshapes diffraction geometry and yields up to `~Q × B` independent spatial views |
| **3** | **Side panels / segmented boundary electrodes** | None (`door sweep` free if fitted) | Closes the equatorial blind band left between two opposing polar plates |

### Two-polarisation Born scattering and ring-down colour (`Derived`)

In a linear weakly scattering field (`f(θ) ∝ k² [γ_κ − γ_ρ cos θ]`), placing two plates opposite each other separates material contrasts at a single frequency: **forward scatter** (`θ = π`) reads `γ_κ − γ_ρ`, whereas **backscatter** (`θ = 0`) reads `γ_κ + γ_ρ`, separating compressibility (`Δκ`) from density (`Δρ`).

Two honest limits govern interpretation in air (`Derived` + `Open`):

1. **Solid impedance saturation:** Because solids (`~10–46 MRayl`) mismatch air (`415 Rayl`) by `~10⁴`, rigid boundaries reflect ~`99.996%` cleanly, giving sharp **silhouettes and multi-bounce shadows** (`R12`) while saturating Born `Δκ/Δρ` contrast. Moderate contrasts (foams, droplets, gels, curing polymers) separate directly; rigid solids rely on **ring-down spectroscopy** (`~√(E/ρ)/L`, `Open` in-chamber bench check) to distinguish stiff vs. compliant materials.
2. **Equatorial missing wedge:** Two opposing polar plates leave the equatorial plane poorly resolved until side optical/acoustic sightlines or reflective chamber panels close the view sphere.

### Reconstruction honesty and static validation (`G17`, `G18`, `G19`)

* **Adjoint vs. inverse:** Delay-and-sum beamforming and coherence-factor / DMAS filters act strictly as display layers (`Machine View`); never feed nonlinear display cosmetics into reconstruction as restored k-space.
* **Mandatory provenance (`G17`):** Every `.pattern` chord must explicitly state `"provenance": "measured" | "inferred"` with **no default** (readers reject missing tags) and mandatory `"inferredBy"` naming the neural or geometric prior whenever shape interior is guessed (`Cadence`, `AssociativeChordBank`).
* **Held-out cross-validation without a turntable (`G18` & `G19`):** Validate the calibrated Green's function by withholding physical gates or frequency lines (`G18`)—a wrong forward model cannot predict measurements it never saw—and verify absolute dimensional error against a static precision-machined reference phantom (`G19`).

### Prototype vs. Ultimate sensing execution

| Capability | Prototype bootstrap (`P0` / `HA-0`) | Ultimate architecture (`Rung 2+`) |
|---|---|---|
| **Acoustic probing** | Collocated `RP2350B` `75 MSa/s` `1-bit ΣΔ` `HAPTIC` self-sensing (`I − C₀ dV/dt`); `95%` constant-frequency hold interleaved with `5%` `200 µs` Doppler-invariant hyperbolic FM chirps (`50×` faster than `10 ms` particle inertia); `18`-tone non-aliasing Golomb comb (`20–198 kHz`); micro-Doppler Kelvin–Rayleigh–Lamb `l = 2` sidebands tracking droplet cure/gelation (`Simulated` in `biosonar`) | Dense phase-conjugate optically-addressed piezo films (`~10⁵` pixels) over multimode fiber; calibrated full `k`-sphere polarimetry |
| **Optical chamber eye** | Nanoimprinted diffractive facets on `270°` radial windows + `Ø12 mm` bore feeding 3-pin TO-can laser diodes (`SMI` + `SOT-23 ×200` AC gain + `1-bit ΣΔ` locked via `XIN`/`SYNC`); reads DC Beer–Lambert shadow + `24–200 kHz` air sound (`K-MOSQUITO-SMI` open) | Coherent quantum-inspired `space ⊗ polarization ⊗ spectrum` density-matrix RX tomography across the optical stem (`Published` components; `Open` real-time chamber loop), measuring roughness via depolarization purity deficit |

---

## Recover (Dissolve): material-specific separation and reuse

Reversing a holographic drive waveform (`REMOVE = conj(a)`) is **not** a magic undo button for chemistry or bonding. Time-reversal acoustics ([Fink](https://pubmed.ncbi.nlm.nih.gov/18267667/)) and Coherent Perfect Absorption ([Chong et al., 2010](https://doi.org/10.1103/PhysRevLett.105.053901); [Wan et al., 2011](https://doi.org/10.1126/science.1200735/)) control **where wave energy is deposited or drained**—they do not un-react thermosets, undo metallic diffusion, or sort mixed alloys automatically.

Physical recovery is therefore designed at fabrication time (`Design for Recovery`) and executes through a least-disruptive hierarchy:

| Route priority | Target recovery action | Required process & metrology qualification |
|---:|---|---|
| **1 · Joint release** | Unlatch a reversible fastener, wax, solder, or soluble binder bond to recover whole modules intact | Localized thermal or chemical release threshold; post-release damage and contamination check |
| **2 · Soften or remelt** | Return compatible thermoplastics or low-melt metals to usable droplet/powder stock | Thermal history, oxidation control, viscosity, and solidification verification |
| **3 · Acoustic / mechanical separation** | Disaggregate loosely bound composites, powders, or embrittled phases | Particle size distribution, wear contamination, and collection yield |
| **4 · Chemical / selective separation** | Reclaim pure elements from alloyed, cured, or multi-material scrap into oxidized brine/ash stock | Reagent selectivity, side-products, energy balance, and lot-purity assay |

Every recovery run updates an explicit **mass-and-energy conservation ledger** tracking input part mass, added process media, usable recovered stock, losses/emissions, and electrical/thermal energy spent—closing the first prototype loop (`§6` demonstration gate) by building a second inspected part from recovered material.

---

## The Stores: pattern library vs. matter pantry

Separating information storage from atomic inventory prevents recurring architectural confusion:

| Store | Holds | Governing physical constraint | Prototype (`P0` / `HA-0`) | Ultimate architecture |
|---|---|---|---|---|
| **Pattern store** | Geometry chords, calibrated `H(f)`, `Cadence` weights, verified build recipes (`.pattern`, `.fcode`) | Holographic dynamic range `η = (M#/M)²` and `measured`/`inferred` provenance | Host SSD + `< 60 kB` flash/SRAM on embedded Brain Slot | Volumetric low-loss `Sb₂S₃`/`Sb₂Se₃` optical holographic store (`~10⁵–10⁶` pages/cm³) |
| **Matter stores** | Raw elements and qualified feed materials (`water`, `carbon`, `air`, `mineral salt/ash`, `trace rack`) | Baryon conservation, chemical stability (`store oxidized`), safety, and thermal/redox cost | Sealed `Ø22.8 mm` septum vials & manual lot-checked powder/resin hoppers | Lower mirrored instrument chamber (`R9`) providing continuous acoustophoretic sorting and incoming scan QC |

### The "store oxidized, never atomized" chemistry rule (`Derived`)

Keeping bulk shelves as fine pure metal powders or loose reactive atoms turns inventory into a fire hazard and shelf-life liability (oxidized metal is thermodynamic ground state; pure reduced powder should only be generated at build time when needed). Reactivity and solubility divide mineral stores cleanly into **Salt** and **Ash**:

* **Why reactive metals cannot sit in water as metal powder:** Per kilogram contacting water, finely divided `Li` evolves `1,762 L` of `H₂`, `Al` `1,359 L`, `Mg` `1,006 L`, `Fe` `657 L`, `Ca` `610 L`, and `Na` `532 L` (with ignition).
* **The Salt / Ash resolution:** Those same alkali and alkaline-earth metals form highly water-soluble chlorides (`LiCl ≈ 830 g/L`, `CaCl₂ ≈ 745`, `MgCl₂ ≈ 540`, `NaCl ≈ 360`), which ride cleanly as safe, pumpable aqueous **brine**, while insoluble refractory oxides (`SiO₂`, `Al₂O₃`, `Fe₂O₃`, `CaO`) form the inert solid **ash** loop—paired with **water** (`H, O`), solid **graphite** (`C`), and filtered atmospheric **air** (`N₂`, `O₂`, plus `0.93% Ar` at ambient intake).
* **200-bar Noble-Gas Cartridge (`He, Ne, Kr, Xe`):** Because dissolution in water captures only `0.06% Xe` by mass (`1.5–578 mg/L` across `He–Xe`), and liquefaction from trace air requires `~2,140 m³` air (`~714 kWh/g` for `Xe`), ambient `200 bar` steel cartridges win by `3,900–21,000×` density over water without cryogenic boil-off (`Peng–Robinson` at `20 °C` puts `Xe` supercritical above `16.58 °C` at `2,281 g/L` and `Kr` at `978 g/L`).
* **Strict store firewalls:**
  * *Polar trace-rack geometry is organizational only:* Keying element vials by periodic-table radius and group helps optical/mechanical inventory and prevents wrong-slot insertion; a pre-registered calibration test (`Test 0`) confirmed zero physical addressing signal beyond standard chemistry.
  * *No energetic/exotic states on the shelf:* Hypothetical ultradense matter claims (`H(0)`) and Rydberg states are firewalled completely outside feedstock storage.

### Ultimate active instrument chamber vs. Prototype septum feeds

In the **Ultimate Architecture** (`R9` three-plate symmetric stack), the middle bulkhead houses back-to-back arrays facing **up** into the build volume and **down** into an active storage chamber. Incoming or reclaimed material undergoes **acoustophoretic `Δκ/Δρ` sorting**, full-volume tomography QC, and field-driven axial lift (`R10`) up the bore. In the **Bootstrap Prototype (`P0` / `HA-0`)**, this entire subsystem stays modular and low-effort: indexed septum vials (`ha0_septum_cap`), calibrated dispenser tips, and direct witness measurements qualify feedstock lots without waiting for an automated chemical refinery.

Read [Architecture](architecture.html), [Manufacturing](manufacturing.html), [Cadence, memory and wave compute](cadence-memory.html), and [Material recovery](../papers/replicator_dissolve.html).
