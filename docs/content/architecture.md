# Architecture

The Replicator coordinates acoustic, electric/magnetic, and optical wavefields inside one shared, tool-free three-dimensional work volume. CAD, wave solvers, sensor calibration, and machine execution share one coordinate frame, material state, and `.fcode`/`.pattern` wire contract across both the **Ultimate Architecture** and the **Bootstrap Prototype (`P0` / `HA-0`)**.

<div class="diagram">
<svg viewBox="0 0 880 550" role="group" aria-labelledby="architecture-title architecture-desc" xmlns="http://www.w3.org/2000/svg">
<title id="architecture-title">Coordinated fields in one Replicator work volume</title>
<desc id="architecture-desc">The twin and planner command coordinated control and power for acoustic, electric and magnetic, and optical modules. All three act in one shared work volume where material is arranged, oriented, joined and inspected. Feedstock enters that volume, measurements return to the twin, and frame, metrology and utilities support the process.</desc>
<defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8" fill="#186b60"/></marker></defs>
<rect x="205" y="300" width="650" height="125" rx="12" fill="#e2ede5" stroke="#186b60" stroke-width="1.5"/>
<g fill="#f2f5ef" stroke="#186b60" stroke-width="1.5">
<a href="digital-twin.html" aria-label="Digital twin and planner"><rect x="220" y="20" width="440" height="62" rx="9"/></a>
<a href="compute-control.html" aria-label="Coordinated control and power"><rect x="250" y="110" width="380" height="54" rx="9"/></a>
<a href="acoustics.html" aria-label="Acoustic fields"><rect x="145" y="205" width="190" height="58" rx="9"/></a>
<a href="electromagnetics.html" aria-label="Electric and magnetic fields"><rect x="355" y="205" width="190" height="58" rx="9"/></a>
<a href="optics.html" aria-label="Optical fields"><rect x="565" y="205" width="190" height="58" rx="9"/></a>
<a href="matter-loop.html#the-stores-pattern-library-vs-matter-pantry" aria-label="Feedstock"><rect x="20" y="345" width="165" height="60" rx="9"/></a>
<a href="manufacturing.html#a-candidate-combined-field-recipe" aria-label="Arrange and orient material"><rect x="220" y="345" width="190" height="60" rx="9"/></a>
<a href="manufacturing.html" aria-label="Join and transform material"><rect x="435" y="345" width="190" height="60" rx="9"/></a>
<a href="matter-loop.html" aria-label="Observe and inspect material"><rect x="650" y="345" width="190" height="60" rx="9"/></a>
<a href="architecture.html#interfaces-that-survive-upgrades" aria-label="Frame, metrology and utilities"><rect x="220" y="475" width="635" height="58" rx="9"/></a>
</g>
<g pointer-events="none" fill="#173630" font-family="system-ui,sans-serif" text-anchor="middle" font-size="17">
<text x="440" y="47">Digital twin + planner + Cadence</text><text x="440" y="69" font-size="13">CAD · coupled models · EqProp · upgrade graph</text>
<text x="440" y="143">Coordinated control + wave equilibrium</text>
<text x="240" y="240">Acoustic fields</text><text x="450" y="240">Electric + magnetic</text><text x="660" y="240">Optical fields</text>
<text x="530" y="326" font-size="16" font-weight="600">ONE SHARED 3D WORK VOLUME</text>
<text x="102" y="370">Feedstock</text><text x="102" y="392" font-size="13">Salt / Ash / C / H₂O</text>
<text x="315" y="370">Arrange + orient</text><text x="315" y="392" font-size="13">hands + fingertips</text>
<text x="530" y="370">Join + transform</text><text x="530" y="392" font-size="13">weld · soften · melt</text>
<text x="745" y="370">Observe + recover</text><text x="745" y="392" font-size="13">S(f) · SMI · reclaim</text>
<text x="537" y="500">Frame, metrology and utilities</text><text x="537" y="522" font-size="13">shared datums · access · sensors · cooling · protection</text>
</g>
<g fill="none" stroke="#186b60" stroke-width="2" marker-end="url(#arrow)">
<path d="M440 82 V110"/>
<path d="M440 164 V184 H240 V205"/><path d="M440 184 H450 V205"/><path d="M450 184 H660 V205"/>
<path d="M240 263 V300"/><path d="M450 263 V300"/><path d="M660 263 V300"/>
<path d="M185 375 H220"/><path d="M410 375 H435"/><path d="M625 375 H650"/>
<path d="M855 360 H868 V51 H660"/><path d="M537 475 V425"/>
</g>
<text x="780" y="105" fill="#186b60" font-family="system-ui,sans-serif" font-size="13" text-anchor="middle">measurements</text>
</svg>
</div>

The process stages share one work volume. A recipe can overlap or sequence them; the diagram does not require separate stations or every field to be active continuously.

## One work volume, coordinated fields

Design the fields around their combined action on the same material: acoustic radiation pressure arranges feedstock (`sound is the hands`), electric or magnetic interactions apply material-selective forces, torques, or localized heating, and optical fields supply high-resolution addressing, wavefront readout, curing, and sub-micron gradient trapping (`light is the fingertips`). Optics is electromagnetic physics; the separate module names distinguish operating bands and hardware.

A candidate combined recipe integrates acoustic particle arrangement, magnetic orientation of anisotropic inclusions, and optical curing ([Manufacturing](manufacturing.html#a-candidate-combined-field-recipe)). Common coordinate timing does not require carrier phase coherence between unrelated acoustic and optical beams unless an interferometric cross-carrier measurement explicitly locks them.

---

## Two carriers, five wavelength decades and volume crossings

Because photon speed (`3 × 10⁸ m/s`) exceeds sound speed (`~343 m/s` in air, `~5,000 m/s` in solids) by roughly **five orders of magnitude**, a phonon carries `~10⁵–10⁶×` more momentum per unit energy (`E/v` vs. `E/c`) while having `~10⁵×` shorter wavelength at equal frequency (`Derived`):

| Frequency | Photon wavelength | Sound in air | Sound in solid | Consequences for machine division of labor |
|---|---|---|---|---|
| `1 kHz` | `300 km` | `343 mm` | `5 m` | Acoustic cavity modes start at millimeter–meter building blocks |
| `1 MHz` | `300 m` | `343 µm` | `5 mm` | MHz ultrasound in melt/argon reaches sub-mm features with strong force |
| `1 GHz` | `300 mm` | `343 nm` | `5 µm` | Solid GHz phonons match visible light wavelength—acting as dynamic Bragg gratings |

**Asymmetric degrees of freedom (`Derived`):** Photons carry `2` transverse spin polarization states (`SAM = ±ħ`), unbounded orbital angular momentum (`OAM`), continuous amplitude/phase/frequency, and space–time nonseparability (toroidal pulses). Phonons carry `1` longitudinal branch in fluids and `3` branches (`1L + 2T` shear) in solids, rich surface waves (Rayleigh, Lamb, Love), structured-sound acoustic spin, `OAM` torque, strong quadratic nonlinearity, and engineerable band-gap dispersion. Every photon–phonon interaction obeys energy (`ω_out = ω_in ± Ω`), momentum (`k_out = k_in ± q`), and angular-momentum (`l_out = l_in ± l_ac`) conservation, enabling sound to write topological charge onto light.

### Cross-carrier verbs inside the work volume

Beyond crystal transducers at the walls, sound and light interact parametrically inside the gas or melt volume itself—never as bulk power transfer (the **parametric bound** preserves Ruling R1), always as addressing, trim, and independent witness verification:

| Volume crossing | Mechanism & physical numbers | Engineering machine verb & status |
|---|---|---|
| **Light reads sound** | Acousto-optic Gladstone–Dale shift (`n − 1 = 2.9 × 10⁻⁴` in air): `155 dB` (`1.13 kPa`) → `Δn = 2.3 × 10⁻⁶` (`1.38` waves over `300 mm`); `165 dB` → `4.37` waves; `175 dB` → `13.8` waves (`θ ≈ 1.6 × 10⁻⁴ – 1.6 × 10⁻³ rad`, `Derived`) | Independent optical tomography (`LightRead`, `SMI` / schlieren) measuring the real chamber sound field (`Published experiment`; chamber `K-MOSQUITO-SMI` open) |
| **Sound trims light** | Volumetric acoustic field acts as a microsecond-refreshed graded-index optic | Fine `~10⁻⁴ rad` axial sightline trim in air; genuine beam shaping requires liquid/melt at high peak pressure (`M₂ = n⁶ p² / ρv³`)—note at equal Pa, water has lower `Δn` (`~5 × 10⁻⁷` vs. air `7 × 10⁻⁶` at `3.5 kPa`) due to `~10³×` larger `ρc²` (`Published` AOM; melt shaping `Open`) |
| **Light writes sound** | Thermoelastic photoacoustic launch (`Published`): patterned light (Hadamard basis, not point-scanning) absorbed on a workpiece surface | Reprogrammable virtual acoustic source on any illuminated object face with zero moving hardware (`R2`, `Open` in-chamber) |
| **Phonon ↔ photon** | Coherent cavity optomechanics / polaritonic mixing | Quantum/RF-to-optical handoff inside solid interfaces (`Published` component physics; machine integration `Open`) |

---

## Subsystems and ownership

| Subsystem | Functional responsibility (substrate-neutral) | Ultimate realization | Prototype bootstrap (`P0` / `HA-0`) |
|---|---|---|---|
| **Acoustic bodies** | Convert compact electrical/optical inputs into calibrated 3D force and sensing fields (`p(f) = H(f)u(f)`) | Continuous optically-addressed piezo film (`~10⁵` pixels) + graded phononic tapers + tonotopic plates | Opposed `3 + 3` or `6 + 6` thin broadband PZT patches on supersonic plates + SLA phase ring |
| **Electric & magnetic fields** | Apply selective force, torque, induction heating, or field-driven bore transport | Containerless `J × B` melt shaping, `m/q` sorting, and axial bore elevator (`R10`) | Contactless exciter `X-EM` for disc characterization; process EM windings deferred past acoustic seed |
| **Optical fields** | Deliver non-invasive wavefront readout, curing exposure, spectroscopic ID, and sub-µm fingertip traps | `756 nm` optically-addressed metasurface SLM, bidirectional toroidal stem, `space ⊗ pol ⊗ spectrum` tomography | Nanoimprinted diffractive facets + `3`-pin TO-can laser diodes (`SMI` dual DC/`LightRead` AC) on clear CAD windows |
| **Control & equilibrium compute** | Separate nanosecond boundary reflexes, ms pattern relaxation (`Cadence`), and offline design; speak identical `.fcode`/`.pattern` wire verbs | Optical `EML` diode cavities + reciprocal `Sb₂S₃` holograms + candidate minimal-electricity wave/neural-gel media (`Open`) | Collocated `RP2350B` `75 MSa/s` `1-bit ΣΔ` ganglia on `XIN`/`SYNC`, `< 60 kB` sparse `int8` `Cadence` (or `SoC-FPGA`), trained on workstation GPU |
| **Metrology & Scan** | Measure boundary `S(f)`, field phase, thermal drift, and interior inspection without moving parts (`G17–G19`) | Coherent optical + `~10⁵`-pixel acoustic full-sphere scattering + calibration phantoms | Two-terminal `HAPTIC` `XOR` comb lock-in (`K-HAPTIC-PZT`) + `SMI` optical strips (`K-MOSQUITO-SMI`) + phantom calibration |
| **Feed, join & stores** | Store safe oxidized elements (`Salt/Ash/C/H₂O/Noble-Gas`), consolidate parts cleanly, and reclaim material | Mirrored 3-plate active storage chamber (`R9`) with acoustophoretic sorting + closed reclaim chemistry | Sealed septum vials (`ha0_septum_cap`), calibrated dispensers, UV/ultrasonic joining, manual lot balance |
| **Twin & planner** | Co-design geometry, solids, fields, and `Cadence` across hardware realism tiers from one source of truth | Autonomous self-upgrade loop generating inspected machine components | Native Swift/Metal solver (`twin/`), Solid FEM bridges, `Cadence` (`holo/`), producing `body-response/0.1` |

---

## Ultimate architecture vs. bootstrap prototype

To eliminate confusion between **what the machine becomes** and **how we bootstrap the first workshop build**, keep every design review anchored to this boundary:

| Axis | Ultimate architecture | Bootstrap prototype (`P0` / `HA-0`) | Where documented |
|---|---|---|---|
| **Acoustic hardware** | Wire-free optically gated `PMN-PT` / phononic-tapered aperture (`~10⁵` pixels) over multimode fiber; argon rung to `1 MHz` | Thin `0.5–1.5 mm` PZT / composite patches (`τ_inertia ≈ 90–285 ns`) on glass/Al plates or SLA diffusers | [Acoustics](acoustics.html) |
| **Optical sightlines & RX** | Bidirectional toroidal-pulse stem, passive optical-element arrays, quantum-inspired tomography, plasmonic/tweezer fingertips | `36`-ray `SMI` mosquito eye (`×200` SOT-23 AC op-amp + `1-bit ΣΔ`) over `270°` clear window + `Ø12 mm` bore | [Optics](optics.html) · [Control](compute-control.html) |
| **Signal & control electronics** | Analog wave reciprocity directly on optical/crystal fibers; no dense copper bundle or clock-heavy CPU loop | Temporary silicon scaffolding: `RP2350B` `PIO` ganglia locked via CMOS `XIN + SYNC`, optional `SoC-FPGA` card | [Compute, sensing and control](compute-control.html) |
| **Intelligence & memory** | Physical wave-equilibrium media (`EML` threshold diodes, `Sb₂S₃` PCM stores, `Open` minimal-electricity soft-matter / neural-gel compute) | Offline `MLX/Metal` `Cadence` distillation exported to `< 60 kB` `5–10%` sparse `int8` SRAM + host `.pattern` stores | [Cadence, memory and wave compute](cadence-memory.html) |
| **Scanner & recovery** | Zero-turntable multi-bounce virtual apertures, ring-down `Δκ/Δρ` classification, active 3-plate `R9` sort/reclaim chamber | `95%` CF / `5%` Golomb-FM `HAPTIC` + `SMI` scans validated by held-out `G18` and machined phantoms `G19` | [Scan, recover and stores](matter-loop.html) |
| **First self-upgrade gate** | Machine produces precision structural, acoustic, and optical components of its successor (`META-01`) | `FAB-01` repeatable hold/move/release, `FAB-01` fiducial/phase-ring fabrication, `K-HAPTIC-PZT` & `K-MOSQUITO-SMI` | [Upgrade loop](upgrades.html) · [Manufacturing](manufacturing.html) |

## Interfaces that survive upgrades

Every module—prototype or ultimate—carries its identity and revision, coordinate transform, typed signal/power/optical ports, operating limits, material state, and explicit response provenance (`Design intent`, `Simulated`, `Measured` vs. `Inferred`). Changing an acoustic body (`borosilicate_12port` ↔ `ha0_boro12`) or swapping the Brain Slot (`RP2350B` → `SoC-FPGA` → `Optical Core`) changes only the pluggable module and its calibrated `body-response/0.1` operator, leaving the rest of the machine intact.

Read [Compute, sensing and control](compute-control.html), [Cadence, memory and wave compute](cadence-memory.html), [Acoustics](acoustics.html), [Optics and metamaterials](optics.html), [Electromagnetics](electromagnetics.html), [Manufacturing](manufacturing.html), [Scan, recover and matter stores](matter-loop.html), and [Digital twin](digital-twin.html).
