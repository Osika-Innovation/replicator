# Optics and optical metamaterials

Optical-wavelength metamaterials are a core design lane for the Replicator. We aim to encode useful field transformations in material structure: control phase, amplitude, polarization and dispersion with compact surfaces, then combine illumination and readout in the shared work volume. This extends the same design principle as the acoustic body: spend computation on geometry and material response to obtain more function from fewer parts.

Optics and [electromagnetic control](electromagnetics.html) have separate engineering ownership because their sources, fabrication scales, models and instruments differ. They share electromagnetic physics and a common machine coordinate system.

## What the optical subsystem does

| Function | Design objective | Deciding measurements |
|---|---|---|
| Holographic illumination | Produce the spatial and spectral patterns a material process needs | Wavefront, efficiency, contrast, bandwidth and stability |
| Material processing | Deliver a specified exposure or absorbed energy distribution | Dose, absorption, temperature, cure/ablation depth and finished-part quality |
| Optical manipulation | Apply suitable gradient and radiation forces to small payloads | Force, trap stiffness, heating, usable volume and position error |
| Optical readout | Recover the observations needed for feedback and inspection | Resolution, sensitivity, calibration, latency and reconstruction uncertainty |
| Light–sound coupling | Excite or observe mechanical response through a qualified optical interaction | Transduction response, heat, signal-to-noise and timing |

The existing [photon mechanism paper](../papers/replicator_photons.html#s3) develops a bidirectional holographic port, structured pulses and optical placement. It remains the deeper design record; this guide sets the current subsystem scope.

## Optical-wavelength metasurfaces

A metasurface controls light through a patterned interface; a bulk metamaterial uses structure through a volume. The design variables include geometry, complex refractive index, feature pitch and height, anisotropy, layer arrangement, illumination and fabrication variation. Specify the required wavelength band, numerical aperture, polarization response, efficiency and optical-power budget before selecting a cell family.

A passive surface implements a designed transformation. Reconfiguration comes from its illumination or an explicitly tunable material/device. An optically addressed metasurface spatial light modulator has demonstrated visible complex-amplitude holography and three-dimensional focusing with a 756 nm supercell pitch. That is a concrete route to programmable optical boundaries; pitch is a device parameter, not a guaranteed workpiece resolution. [Fan et al., 2026](https://doi.org/10.1038/s41565-026-02128-x).

The twin must model dispersion, loss, scattering and thermal response as well as the intended phase profile. Optical material selection and tolerances are part of CAD. A THz or microwave result supplies a mechanism to investigate; an optical implementation requires its own material and fabrication calculation.

## Toroidal optical pulses

Toroidal pulses have a structured electromagnetic field whose spatial and temporal dependence cannot generally be separated. The optical programme includes their synthesis and measurement, alongside simpler wavefronts for tasks where those suffice.

Zdagkas and colleagues reported toroidal-pulse generation at optical and terahertz frequencies. Vignjevic and colleagues subsequently reported few-cycle optical pulses using pulse compression, a segmented waveplate and spatial filtering, providing a synthesis route without a gradient metasurface. These results make pulse shape, polarization and spectrum concrete design variables. [Zdagkas et al., 2022](https://doi.org/10.1038/s41566-022-01028-5), [Vignjevic et al., preprint](https://arxiv.org/abs/2509.10924).

The separate Wang positioning demonstration operates at microwave frequencies. Its position errors and measurement speed cannot be carried directly into an optical servo specification. Optical readout needs its own calibrated response, detection bandwidth and latency. [Microwave positioning experiment](https://doi.org/10.1038/s42005-024-01850-z).

Toroidal pulse structure, toroidal coil geometry and a proposed gravitational mechanism are distinct concepts. The [electromagnetic guide](electromagnetics.html#toroidal-and-pulsed-fields) identifies their separate engineering questions.

## Fabricating the next optical module

Use a purchased SLM, optic or externally fabricated master where it removes the initial fabrication bottleneck. A published protocol makes optical metasurfaces through a master, soft mold and nanoimprinting of formulated high-index optical material. This supplies a concrete replication route for future machine-made optics. [Direct printing of metasurfaces](https://doi.org/10.1038/s41596-026-01407-0).

For each candidate, specify master accuracy, feature dimensions, index and absorption, shrinkage, surface roughness, alignment, defects and damage threshold. Measure the optical transformation and its manufacturing-task benefit. A successfully replicated surface becomes an upgrade only when its response meets that specification.

The first useful optical upgrade might be a qualified beam-shaping insert, replicated holographic surface or calibration optic. Select it by the human effort saved and capability gained, with seed fabrication and metrology explicitly included.

## Coherent self-mixing optical readout

Conventional `60–1,000 fps` CMOS cameras miss `24–200 kHz` ultrasonic oscillations, and bare photodiodes detect intensity (`|E|²`) rather than pure acousto-optic refractive-index phase modulation (`Δφ(t) = k_L ((n_0 − 1)/(γ P_0)) ∫ p dx`) without external Mach-Zehnder reference arms or knife-edge optics.

Pairing passive replicated diffractive facets across the chamber's radial windows and coaxial `Ø12 mm` bore with threshold-biased commodity laser diodes uses **Self-Mixing / Optical Feedback Interferometry (`SMI`)** inside the laser cavity to read both DC Beer-Lambert matter shadows and `24–200 kHz` ultrasonic wave phase simultaneously ([Bertling et al., 2014](https://doi.org/10.1364/OE.22.030346), `Published experiment`). Because weak `50 mm` air-path retro-reflection modulates diode terminal voltage by only `~50 µV – 1 mV` per `2π` fringe (`~5–100 µV` at `0.1 rad`; [Giuliani et al., 2002](https://doi.org/10.1088/1464-4258/4/6/371)), bare MCU Schmitt GPIOs (`~200 mV` hysteresis, `6.67 ns` ticks) cannot resolve air-path fringes directly. Reading the 3-pin diode's built-in monitor photodiode (or AC-coupled anode) through one SOT-23 AC op-amp (`×200` gain) and a `75 MSa/s` `1-bit` sigma-delta comparator into an `RP2350B` PIO (`XIN`/`SYNC` locked to the acoustic comb) retains zero beam splitters and zero cameras while complementing acoustic `HAPTIC` sensing inside optically opaque powder ([Compute, sensing and control](compute-control.html#optical-mosquito-eye-diffractive-facets-and-self-mixing-interferometry); bench coupon `K-MOSQUITO-SMI` open).

## Twin and integration contract

Publish geometry, optical constants over the operating band, input/output field conventions, illumination, power limits, calibrated response and fabrication tolerances. Register the optical aperture and observations to the acoustic and electromagnetic coordinate frame. The process controller schedules exposure, field-driven arrangement and readout against the same evolving material state.

A forward-propagation model is appropriate for the structures it resolves. Resonant, near-field or strongly scattering structures need their corresponding boundary, feedback and loss models. Co-design source, surface, detector and material interaction around the [combined manufacturing recipe](manufacturing.html#a-candidate-combined-field-recipe).

Read [Architecture](architecture.html), [Compute, sensing and control](compute-control.html), [Materials and modes](materials.html), [Digital twin](digital-twin.html) and the [photon mechanism paper](../papers/replicator_photons.html).
