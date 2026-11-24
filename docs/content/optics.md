# Optics and optical metamaterials

In the prototype, light has one job: it measures. A ring of small laser diodes looks across the chamber and reports where material is and what the sound field is doing, without cameras. In the long-term design, light also switches the acoustic elements, cures and heats material, and handles particles too small for sound.

Optics shares one coordinate frame with [acoustics](acoustics.html) and [electromagnetic control](electromagnetics.html). The machine as a whole is described in [Desktop Replicator](desktop-replicator.html).

## Coherent self-mixing optical readout

**A laser diode can be its own interferometer.** When a little of a laser's light is reflected back into the laser, it interferes with the light inside the cavity and changes the output power. The size of the change depends on the phase of the returning light, and so on the optical length of the path it travelled. This is self-mixing interferometry (SMI), also called optical feedback interferometry. The photodiode that most laser diode packages already contain reads the power change, so no beam splitter, reference arm or camera is needed.

For weak feedback the output power follows the round-trip phase φ:

    P = P₀ · (1 + m · cos φ),    φ = 4π · n · L / λ

Here L is the one-way distance to the reflector, n is the refractive index of the air on the path, λ is the laser wavelength and m is a small modulation depth set by how much light returns. One full fringe corresponds to a change of λ/2 in optical path.

The readout gives two signals at once.

- **Shadow.** An object in the beam removes returning light. The steady signal level drops.
- **Sound.** Pressure changes the refractive index of air, so a sound wave crossing the beam modulates φ at the acoustic frequency. This was demonstrated for ultrasound fields with a self-mixing laser by [Bertling et al., 2014](https://doi.org/10.1364/OE.22.030346) (Documented).

For sound, the phase change over one pass of the beam is (Derived, adiabatic air):

    Δφ = k · (n₀ − 1) / (γ · P₀) · ∫ p dx

with k = 2π/λ, n₀ − 1 ≈ 2.8 × 10⁻⁴ for air, γ = 1.4 and P₀ atmospheric pressure. At {{c:mosquito_smi.laser_wavelength_nm}} nm the coefficient is {{c:mosquito_smi.lightread_coef_rad_per_pa_m}} radians per pascal-metre.

**Worked number.** Assume a path of about 200 mm one way, so 400 mm there and back. Light makes the round trip in 1.3 ns, far less than the 6 µs period of the highest drive tone, so both passes see the same sound field and their phase shifts add. A pressure amplitude of 1,000 Pa that keeps one sign over 5 mm of the beam (about half a wavelength of sound at 32 kHz) gives 0.019 × 1,000 × 0.005 ≈ 0.09 rad per pass, or about 0.19 rad in total. The beam integrates along its length, so neighbouring pressure lobes of opposite sign cancel. One beam measures a line integral, not a point value.

The fringe also drifts. With L = 200 mm, φ is about 3.9 million radians, and the index of air falls by roughly one part in a million per kelvin, so a 1 K change in air temperature along the path moves the fringe by about half a cycle (Derived). In an open chamber the readout has to tolerate draughts.

Cameras are not a substitute: they record at most about a thousand frames per second and cannot follow sound at {{c:desktop_geometry.comb_tones_hz|khz}} kHz.

## In the Desktop Replicator

The prototype uses {{c:mosquito_smi.total_ommatidia}} laser diodes at {{c:mosquito_smi.laser_wavelength_nm}} nm, nicknamed the mosquito eye.

- **Layout.** The diodes sit on two strips beside the rear tower, at azimuth ±{{c:mosquito_smi.window_azimuth_deg}}°. Each beam crosses the chamber to a retro-reflective strip on a post on the far side, at ∓{{c:mosquito_smi.retro_azimuth_deg}}°, and returns into the laser it came from. The two sets of beams cross in the work volume and give two viewing directions. That is two shadow projections, not a three-dimensional image.
- **Detector.** Each diode is a standard three-pin package with a built-in monitor photodiode. The photodiode signal is amplified and read by the same 1-bit converter scheme used for the piezo discs. The electronics are described in [Compute, sensing and control](compute-control.html).
- **What is not there.** The prototype has no cameras, no beam splitters, no diffractive or nanoimprinted facets and no ultraviolet cure module. The wafers are undrilled, so no beam passes through a plate.

Three items are unsettled and are stated here plainly.

1. **Signal size is Open.** Earlier estimates of 50 µV to 1 mV at the diode terminals per fringe ([Giuliani et al., 2002](https://doi.org/10.1088/1464-4258/4/6/371) for the method) assumed a 50 mm path. The path is now of the order of 200 mm one way. The light returned by a retro-reflective strip, the feedback strength and the fringe voltage must all be derived again for that distance. Whether a 0.1 rad acoustic signal is resolvable is not established.
2. **Laser safety is Open.** The chamber wall is clear glass, which does not enclose the beams. An interlock switches the lasers off when the head is raised. The candidate diodes are rated up to 5 mW each and no part has been selected. The laser class of the assembled machine has not been determined, and no enclosure or interlock is in the model. Both must be settled before the lasers are operated.
3. **Amplifier bandwidth is Open.** A single amplifier stage with the planned gain would roll off below the highest drive tone; see [Compute, sensing and control](compute-control.html).

Inside opaque powder the beams see nothing, and acoustic sensing through the piezo discs takes over. The retired earlier optical layout is listed in [Desktop Replicator](desktop-replicator.html).

## Toroidal optical pulses

A toroidal pulse, or "flying doughnut", is a short, broadband electromagnetic pulse whose field lines form a ring around the direction of travel. The field is zero on the axis, and the pulse's shape in space cannot be separated from its shape in time. Such pulses are published physics. Their use in this machine is not.

| Source | What it showed | What it did not show |
|---|---|---|
| [Zdagkas et al., Nature Photonics 16, 523–528 (2022)](https://doi.org/10.1038/s41566-022-01028-5) | Generation and measurement of toroidal pulses at optical and terahertz frequencies (Documented) | Any force on matter, any sensing use, any operation inside a cavity |
| [Wang et al., 2024](https://doi.org/10.1038/s42005-024-01850-z) | A microwave experiment that used toroidal pulses for positioning at centimetre scale (Documented) | Optical operation, or accuracy and speed adequate for closed-loop control |
| [Vignjevic et al., preprint](https://arxiv.org/abs/2509.10924) | A route to few-cycle toroidal pulses with a segmented waveplate (Claim until peer reviewed) | Use outside an optics laboratory |

The microwave ranging result cannot be carried over to an optical servo without a dedicated optical experiment.

**Prototype hook.** Because the wafers are undrilled, a conductor pattern can sit directly on the glass. The CAD model can add a rim-fed, twelve-arm spiral of copper or indium tin oxide, about {{c:dissolve_and_toroidal.borofloat_chiral_spiral_trace_thickness_um}} µm thick, intended as a launcher for such pulses. It is a geometry placeholder and is off by default. Whether it launches a useful pulse in this chamber is Open. No drive electronics for it exist in the design.

**Model limit.** Every solver the project has today is continuous-wave: it computes steady single-frequency fields. None models a pulse, so no statement about toroidal pulses in the chamber is a simulation result.

**Long-term interest.** The on-axis null would leave a channel for material while light travels around it; the prototype has no bore, and any bore belongs to the long-term design only. The pulse's ring topology might also serve as a label that survives scattering in a reverberant chamber. Both uses are Open.

Toroidal light pulses, toroidal coils and speculative force claims are three different things. [Electromagnetic control](electromagnetics.html#toroidal-and-pulsed-fields) keeps them apart.

## Long-term direction

In the long-term design, optics does five things that the prototype does not attempt.

- **Switching the acoustic surface.** Roughly 100,000 acoustic elements are addressed by light, not by wires. See [Architecture](architecture.html).
- **Patterned illumination.** A reconfigurable metasurface modulator shapes light for curing and heating. [Fan et al., 2026](https://doi.org/10.1038/s41565-026-02128-x) demonstrated visible holography with an optically addressed metasurface at 756 nm pixel pitch (Documented). Pitch is a property of the modulator. It is not a guaranteed resolution in the chamber.
- **Optical handling of small particles.** Sound places objects down to fractions of a millimetre. Optical gradient traps could take over for particles below about a micrometre. Trap stiffness, heating and the hand-over from sound to light are Open.
- **Light-to-sound coupling.** Patterned light absorbed at a surface launches sound (photoacoustics). It is a candidate for trimming and for independently checking the acoustic field.
- **Passive optical processing.** A patterned optic applies a fixed spatial transform to light before detection, with no electrical power. Diffractive facets in front of the laser ring are a later upgrade of this kind.

### Fabricating the next optical module

The first machine cannot make sub-wavelength optical structures, and asking it to would be circular. Optical modules therefore start as bought optics or externally made masters. Working copies can then be replicated by nanoimprint into high-index nanoparticle resin, following a published protocol ([Direct printing of metasurfaces](https://doi.org/10.1038/s41596-026-01407-0), Documented).

The tolerance that matters is surface height. A height error δh on a transmissive element of index n produces a phase error δφ:

    δh = λ · δφ / (2π · |n − 1|)

For λ = 650 nm, n = 1.5 and an allowed phase error of 0.1 rad, the height must be right to about 21 nm (Derived). Each optical upgrade records insertion loss, height error and defect yield, as described in [The upgrade loop](upgrades.html).

## Open questions

| Question | Who answers it |
|---|---|
| What fringe signal does a retro-reflective strip return over a path of about 200 mm? | Optical derivation, then first bench test |
| What laser class is the machine with a clear glass wall, and is the interlock sufficient? | Safety review against the standard |
| Do {{c:mosquito_smi.total_ommatidia}} line integrals in two directions constrain the sound field usefully, given draughts? | Simulation, then bench test |
| Does the spiral conductor launch a useful pulse, and what would drive it? | Pulse-capable simulation, which does not exist yet |

Related reading: [Compute, sensing and control](compute-control.html), [Digital twin](digital-twin.html), [Architecture](architecture.html) and the historical long-form notes in [The Photons](../papers/replicator_photons.html).
