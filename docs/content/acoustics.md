# Acoustic bodies

Sound is the Replicator's **muscle**: at fixed power, a phonon carries `~10⁵–10⁶×` more momentum than a photon (`E/v` vs. `E/c`) while fitting millimeter wavelengths into kilohertz–megahertz electronics. Using dispersive geometry and electrical bandwidth headroom extracts thousands of effective field degrees of freedom from few physical inputs.

## Ultimate vs. prototype acoustic apertures

| Feature | Ultimate architecture (`Rung 2+`) | Bootstrap prototype (`P0` / `HA-0` / `AC-03`) |
|---|---|---|
| **Radiating aperture** | Continuous thin piezo film + amorphous-silicon photoconductive gate electrode; global quadrature electrical buses (`0°/90°/180°/270°`) gated spatially by light across `~10⁵` pixels with zero per-pixel copper wires ([Acoustic Hologram §10](../papers/replicator_acoustic_hologram.html#s10)) | Opposed `3 + 3` or `6 + 6` thin broadband piezoelectric elements (`≤ 5 mm` patches/annuli) bonded onto `1–1.5 mm` borosilicate/aluminum supersonic plates + replaceable SLA modulo-`2π` phase ring / chaotic scatterer around `Ø12 mm` coaxial bore |
| **Acoustic backbone &amp; matching** | Single-crystal relaxors (`PMN-PT` / `PIN-PMN-PT`, `k² ≈ 0.9`), graded phononic impedance tapers overcoming the `−42 dB` piezo-to-air reflection cliff (`30 MRayl → 415 Rayl`) without narrowband `λ/4` layers, and tonotopic "reverse-cochlea" plates (`λ_B ∝ 1/√f`); argon rung up to `1 MHz` (`λ = 0.17 mm`) | Purchased/stock `PZT-8` / `1–3` piezocomposite / `AlN` elements (`τ_inertia ≈ 90–285 ns`); `1.2 mm` 10-resonator moth-scale FR-4 metamaterial backing absorber (`biosonar` suppressing ghost reflections); preloaded Langevin horns retained only as CW baseline (`K-PORT+`) |
| **Signal transport &amp; sensing** | Bidirectional phase-conjugate **multimode optical fiber** (`0.4–1 mm` core carries `~7×10⁴–4×10⁵` spatial modes, unscrambling bending distortion by optical reciprocity; interferometric strain readout) | Prototype collocated `RP2350B` head PCB (`< 2 pF` trace vs. `C₀ ≈ 171 pF`) running `75 MSa/s` `1-bit ΣΔ` `HAPTIC` self-sensing (`K-HAPTIC-PZT` pending) over shared `XIN`/`SYNC` bus |

### Hardware scaling reality check (`ENGINE.md` &amp; `AC-03a`)

Early simulations driving ideal velocity pistons made few-channel direct discs look easier than physical hardware permits (`Simulated` + `Derived`):

* **Direct non-resonant discs hit an electro-mechanical ceiling:** A bare `Ø5 × 2 mm` `PZT-8` disc driven directly across `50–100 kHz` sits far below its fundamental thickness resonance (`~468 kHz`), moving only `d₃₃·V ≈ 0.16 m/s` at `97 kHz` vs. `4.75 m/s` required for the open-air ring mold (`310×` short on hardware gate `G-E1`).
* **Single-tone resonant array alternative vs. dispersive SIMO plates:** Packing individual `40 kHz`-style scaled bimorphs (one tone per element) into the full RH-1 annulus requires `~1,536–2,560` separately wired channels to bring `G-E1` below `1` (`0.96` at `1,536` elements, `~159 W` electrical), deleting slots and complicating wiring. That physical check motivated evaluating **supersonic dispersive plates** (`f_c ≈ 6–12 kHz`), **replaceable SLA scatterers**, and **multi-tone harmonic combs** on a compact `3 + 3` / `6 + 6` head before freezing prototype hardware.
* **Next decisive bench test (`K-PORT+`):** Measure one real preloaded cartridge, a `Ø10` stud horn, and a plain `Ø120 mm` aluminum blank against solid-element finite-element models before committing custom discs.

---

## First-principles crystal inertia vs. cavity Q

Physical piezoelectric switching is bounded by longitudinal acoustic transit across the crystal thickness (`τ_inertia = L / v_D`), **not** by room-air cavity decay (`T_60 ≈ 20–50 ms`). For a `1 mm` thin plate, `τ_inertia` spans `~91 ns` (`AlN/ScAlN`), `~136–174 ns` (`LiNbO₃` / quartz), `~217–245 ns` (`PMN-PT` / `PZT`), and `~255–285 ns` (`1–3` piezocomposite). Air `T_60` sets passive chamber energy storage (`Q_cav`) rather than an actuator frame clock.

Bolt-clamped `Q ≈ 500` steel Langevin dumbbells (`~4.5 ms` ring-down, `~1–2 kHz` usable band) remain useful reference hardware for narrowband CW power comparison (`K-PORT+`), not the broadband multi-tone holographic default.

---

## Simultaneous two-terminal HAPTIC self-sensing

Drive and observe continuously across both terminals of every piezoelectric element through a differential bridge (`+V_bus` expand, `−V_bus` contract, `0 V` brake, `Hi-Z` float) with `10–50×` electrical timing headroom ([Dosch, Inman &amp; Garcia, 1992](https://doi.org/10.1177/1045389X9200300109)). From linear coupled Butterworth–Van Dyke dynamics:

    m ẍ + c ẋ + k x = Θ V(t) + F_echo(t)
    I(t) = C₀(T) · dV/dt + Θ · ẋ(t)

Subtracting dielectric slewing current `C₀(T) dV/dt` against a matched uncoupled **`C₀` reference piezo** recovers strain `x(t)`, crystal velocity `ẋ(t)`, and returning echo loading `F_echo(t)` continuously during drive with zero blind TX/RX switching dead time.

**Prototype electronic bridge (`RP2350B` `1-bit ΣΔ`, `K-HAPTIC-PZT` pending):** Across a `24–200 kHz` harmonic comb, a `2 mm` droplet echo sits `−60 to −80 dB` below drive current while `PZT-8` `C₀(T)` drifts `~0.3% / °C` (`−50 dB`), defeating bare zero-crossing comparators (`< 0.2 ns` shift; `2` crossings/period cannot separate `5` tones = `10` I/Q unknowns). In the bootstrap prototype, closing a **`75 MSa/s` `1-bit ΣΔ` loop** (`1` comparator + `2R/1C` across two `RP2350B` PIO pins, `OSR = 250` → `12–16` ENOB / `74–96 dB` dynamic range) with multiplier-free bitwise `XOR + popcount` lock-in demodulates all comb lines simultaneously at `< 2 pF` trace capacitance ([Compute, sensing and control](compute-control.html#acoustic-lamina-75-msas-1-bit-sigma-delta-piezo-haptic)).

---

## Harmonic comb closure and the resolution honesty ladder

Driving at high SPL makes air nonlinear, generating intermodulation (`f_a ± f_b`). An arbitrary carrier set spreads energy across dense intermodulation noise, whereas a **harmonic comb `f₀, 2f₀, 3f₀, …`** (`f₀ ≈ 25 kHz`, harmonics `1–8` spanning `25–200 kHz` in `3` octaves) stays **closed under mixing** (`nf₀ ± mf₀` lands back on the comb). Time-averaged Gor'kov cross terms between distinct comb lines integrate to multiples of `f₀` rather than DC, so individual tone traps add cleanly (`Derived`).

Sweep width in air does **not** sharpen pressure features finer than the shortest wavelength (`λ_min / 2`); wideband chirps instead add axial range resolution (`c / 2B`), speckle averaging, and spatial DOF across `Q × B`:

| Physical observable (`200 kHz` air) | Governing bound | Value at `200 kHz` | What governs it (`Derived`) |
|---|---|---|---|
| **Pressure field feature** | `λ_min / 2` | `0.85 mm` | Linear acoustic diffraction limit |
| **Gor'kov force pixel** | `~λ_min / 4` | `~0.4 mm` | Quadratic pressure/velocity energy (`⟨p²⟩`, `⟨v²⟩`) doubles spatial bandwidth |
| **Axial range resolution** | `c / 2B` | `~1 mm` | Chirp bandwidth `B ≈ 160–175 kHz` |
| **Continuous trap placement** | `~λ / 100` (SNR-limited) | `~10 µm` | Smooth boundary phase ramping shifts trapped particles continuously below wavelength scale |

Finer *features* (not just finer placement) require raising carrier frequency—via millimeter-scale work distances, dense arrays, or an **argon rung (`1 MHz`, `λ ≈ 0.17 mm`)**.

---

## Coupled-cavity equilibrium and sparse chords

Stationary levitation against gravity performs zero mechanical work (`F · ż = 0`). High air–solid impedance mismatch (`415 Rayl` vs. `46 MRayl`, `99.996%` reflection) means dense inclusions (such as steel at `7.85 g/cm³`, up to `22.6 g/cm³` iridium in published 1-D art) resonate in **coupled chamber-plus-object air eigenmodes** rather than internal solid modes. Locking onto the target harmonic chord allows continuous feedback to throttle toward passive cavity loss (`P_hold = ω E_stored / Q_cav`). Objects are represented cleanly as compact sparse `.pattern` chord lists (`kB` scale) rather than raw gigabyte voxel streams ([Matter loop](matter-loop.html)); extending 1-D dense-metal resonant holding to closed-loop 3-D multi-tone dispersive plates remains `Open`.

## Response as the handover (`p(f) = H(f) u(f)`)

Every acoustic module exposes its calibrated frequency-dependent linear operator `H(f)` mapping accessible physical drives `u(f)` to chamber pressure/patches, separating input channel count from output grid count and transferring directly into `body-response/0.1` for `Cadence` and `NOWS` optimization ([Digital twin](digital-twin.html)).

See [Compute, sensing and control](compute-control.html), [Cadence, memory and wave compute](cadence-memory.html), [Manufacturing](manufacturing.html), [Scan, recover and matter stores](matter-loop.html), and [The Acoustic Hologram](../papers/replicator_acoustic_hologram.html).
