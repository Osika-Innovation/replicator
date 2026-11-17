# Optics and optical metamaterials

Optical-wavelength metamaterials and structured light form a co-equal lane alongside acoustics and electromagnetics. Spending design effort on diffractive geometry and material dispersion converts passive patterned optics into real-time field synthesizers, parallel spatial inner-product sensors, and precision sub-micron manipulators. Optics and [electromagnetic control](electromagnetics.html) remain separate engineering lanes sharing one coordinate frame.

## What the optical subsystem does

| Function | Ultimate capability | Bootstrap prototype (`HA-0` / `K-MOSQUITO-SMI`) | Deciding measurements |
|---|---|---|---|
| **Holographic illumination &amp; curing** | `756 nm`-pitch optically-addressed metasurface SLM ([Fan et al., 2026](https://doi.org/10.1038/s41565-026-02128-x)) + end-to-end photonic stem | Commodity collimated UV/visible cure LEDs or patterned projector through `270°` clear window | Wavefront contrast, power budget, cure depth, registration |
| **Optical chamber readout** | Real-time bidirectional toroidal-pulse stem performing quantum-inspired `space ⊗ pol ⊗ spectrum` density-matrix RX tomography (depolarization = roughness) | Passive nanoimprinted diffractive facets + `3`-pin TO-can laser diodes (`SMI` + `SOT-23 ×200` + `RP2350B` `1-bit ΣΔ` PIO on `XIN`/`SYNC`) | Dual DC occlusion &amp; `0.1 rad` `LightRead` ultrasonic phase SNR (`K-MOSQUITO-SMI`) |
| **Optical manipulation ("fingertips")** | Holographic optical gradient tweezers steering sub-µm to tens-of-nm payloads delivered by acoustic "hands" (down toward plasmonic near-field `Open`) | Deferred past macroscopic `P0`/`HA-0` acoustic placement | Trap stiffness, optical heating (`ΔT`), hand-off capture rate |
| **Light–sound boundary &amp; volume coupling** | Photoacoustic patterned launch (`R2` Hadamard basis, not point-scanning) &amp; acousto-optic trim (`~10⁻⁴ rad` air / melt GRIN) | Optical schlieren / `LightRead` witness verification of acoustic cavity field | Independently photographed field `p(x)` vs. twin prediction |

The existing [photon mechanism paper](../papers/replicator_photons.html#s3) retains historical long-form mechanism notes; this chapter and [Compute, sensing and control](compute-control.html) own the current optical architecture.

---

## Optical-wavelength metasurfaces and fabrication ladder

A passive metasurface executes an exact spatial/polarization transformation (`Gabor`, `Hermite-Gauss`, or vortex `OAM` kernel) at the speed of light (`0 W` compute) before light strikes silicon or re-enters a diode cavity. Reconfiguration enters through structured illumination or an active metasurface SLM ([Fan et al., 2026](https://doi.org/10.1038/s41565-026-02128-x) demonstrated visible complex holography at `756 nm` supercell pitch, `2.3 × 10¹² px·s⁻¹·cm⁻²`; note pitch is a modulator parameter, not a guaranteed chamber voxel resolution).

### Fabricating the next optical module

Rather than asking the initial acoustic seed machine to fabricate sub-wavelength lithographic features directly (circular bootstrap violation), start with externally fabricated masters or bought optics and use replicated working facets via published soft-mold / high-index nanoparticle-resin nanoimprint protocols ([Direct printing of metasurfaces](https://doi.org/10.1038/s41596-026-01407-0)), characterizing insertion loss, figure error (`δh = λ δφ / (2π |n − 1|)`), and defect yield at each upgrade ([Upgrade loop](upgrades.html)).

---

## Toroidal optical pulses

Structured **toroidal ("flying doughnut")** electromagnetic pulses and **topological registers (`R13`)** satisfy space–time nonseparability (`Derived` + `Published experiments`: [Zdagkas et al., 2022](https://doi.org/10.1038/s41566-022-01028-5) at optical/THz frequencies; few-cycle segmented-waveplate synthesis by [Vignjevic et al., preprint](https://arxiv.org/abs/2509.10924) without a gradient metasurface). Three geometric features motivate them in the **Ultimate Architecture**:

1. **On-axis field null:** Leaves a coaxial channel down the center of the beam, matching the Replicator's `Ø12 mm` bore ("light around, matter through").
2. **Isodiffraction &amp; self-healing:** Each spectral band maintains matched divergence radius and reconstructs around partial obstructions.
3. **Topographic encoding (`R13`):** Integer **orbital angular momentum (`OAM`, `e^{ilφ}`)** and skyrmion topological registers carry mode labels resilient across reverberant chaos (microwave positioning precedent: [Wang et al., 2024](https://doi.org/10.1038/s42005-024-01850-z); note microwave cm-scale ranging accuracy cannot be extrapolated unverified to an optical servo without dedicated optical latency benchmarks).

Notice the strict boundary: toroidal light pulses, contrawound toroidal coils, and hypothetical metric/gravito-magnetic mechanisms are unrelated physical domains ([Electromagnetics](electromagnetics.html#toroidal-and-pulsed-fields)).

---

## Coherent self-mixing optical readout

Conventional `60–1,000 fps` CMOS cameras cannot resolve `24–200 kHz` acoustic waves without slow stroboscopic aliasing, and standard photodiodes measure only intensity (`|E|²`), remaining blind to acousto-optic refractive-index phase modulation (`Δφ(t) = k_L ((n₀ − 1)/(γ P₀)) ∫ p dx`) unless paired with bulky external Mach-Zehnder reference arms.

**Physical mechanism (`Published experiment`):** Pairing passive diffractive facets across the chamber's real CAD sightlines (`270°` clear radial windows + `Ø12 mm` bore; strictly zero sightlines through opaque rear pinna walls) with threshold-biased commodity laser diodes uses **Self-Mixing / Optical Feedback Interferometry (`SMI`)** inside the laser cavity ([Bertling et al., 2014](https://doi.org/10.1364/OE.22.030346)) to read **both** DC Beer–Lambert matter shadow and `24–200 kHz` air-phase sound waves simultaneously—requiring zero external beam splitters or CMOS cameras. Acoustic `HAPTIC` sensing takes over smoothly inside optically opaque powders.

**Prototype electronic front-end (`Derived`, `K-MOSQUITO-SMI` pending):** Across `50 mm` of air off a passive retro-reflector, weak feedback shifts diode terminal voltage by only `ΔV ≈ 50 µV – 1 mV` per `2π` fringe (`~5–100 µV` for `0.1 rad` ultrasound; [Giuliani et al., 2002](https://doi.org/10.1088/1464-4258/4/6/371)). Bare microcontroller Schmitt inputs (`~200 mV` hysteresis, `6.67 ns` PIO ticks) cannot see `~0.1 ps` slew shifts on `2 V` DC. In the **Prototype (`HA-0`)**, reading the standard 3-pin diode's built-in **monitor photodiode** (or AC-coupling the anode) through **one SOT-23 op-amp (`×200` AC gain) + `1-bit ΣΔ` comparator** into an `RP2350B` PIO locked onto `XIN`/`SYNC` preserves every optical simplification while reliably resolving `0.1 rad` acoustic fringes ([Compute, sensing and control](compute-control.html#optical-mosquito-eye-diffractive-facets-and-self-mixing-interferometry)).

---

## Twin and integration contract

Every optical module records its calibrated `3D` sightline vectors, Beer–Lambert transmittance vs. true ray obstacles (never synthetic X-ray Radon projections), wavelength dispersion, damage threshold, and fabrication tolerance (`δh` phase budget). Co-design optical phase profiles `φ_opt(x, y)` directly inside the twin alongside [combined field recipes](manufacturing.html#a-candidate-combined-field-recipe).

Read [Architecture](architecture.html), [Compute, sensing and control](compute-control.html), [Cadence, memory and wave compute](cadence-memory.html), [Digital twin](digital-twin.html), and [The Photons](../papers/replicator_photons.html).
