# Optics and optical metamaterials

Light has two jobs in the machine. The first is to measure: a ring of small laser diodes looks across the chamber and reports where material is and what the sound field is doing. The second is to lock: after sound has gathered matter into the programmed 3D shape, patterned light fixes it in place in one exposure. Sound is far stronger per watt, so it does the moving ([Acoustics](acoustics.html#why-sound-carries-the-force)). Light is too weak to move grains larger than about 10 µm, but it is precise, so it does the fixing. In the long-term design, light also switches the acoustic elements and handles particles too small for sound. Measuring is in the Desktop Replicator's CAD. Locking is a Design decision with no simulation yet (Open).

Optics shares one coordinate frame with [acoustics](acoustics.html) and [electromagnetic control](electromagnetics.html). The whole machine is in [Desktop Replicator](desktop-replicator.html).

## Coherent self-mixing optical readout

**A laser diode can be its own measuring instrument.** Send a laser beam at a reflector. A little light comes back into the laser and changes its output power. How much depends on the phase (the timing within one wave) of the returning light, and so on the length of the path. This is [self-mixing interferometry](glossary.html) (SMI). Most laser diode packages already contain a photodiode, a small light sensor, that reads the power change. No beam splitter, reference arm or camera is needed.

For weak feedback the power follows the round-trip phase φ:

    P = P₀ · (1 + m · cos φ),    φ = 4π · n · L / λ

L is the one-way distance to the reflector. n is the refractive index of the air, which says how much the air slows light. λ is the laser wavelength. m is a small depth set by how much light returns. One full bright-dark cycle, called a fringe, is a change of λ/2 in path length.

The readout gives two signals.

- **Shadow.** An object in the beam blocks returning light. The steady signal level drops.
- **Sound.** Pressure changes the refractive index of air. A sound wave crossing the beam therefore wobbles φ at the sound's frequency. [Bertling et al., 2014](https://doi.org/10.1364/OE.22.030346) showed this for ultrasound fields (Documented).

For sound, the phase change over one pass of the beam is (Derived, for air squeezed too fast to exchange heat):

    Δφ = k · (n₀ − 1) / (γ · P₀) · ∫ p dx

Here k = 2π/λ, n₀ − 1 ≈ 2.8 × 10⁻⁴ for air, γ = 1.4 and P₀ is atmospheric pressure. The integral adds up the sound pressure p along the beam. At {{c:mosquito_smi.laser_wavelength_nm}} nm the coefficient is {{c:mosquito_smi.lightread_coef_rad_per_pa_m}} radians per pascal-metre.

**Worked number.** Assume a path of about 200 mm one way. Light makes the round trip in 1.3 ns. The highest drive tone has a period of 6 µs. Both passes therefore see the same sound field and their phase shifts add. Take 1,000 Pa of pressure amplitude that keeps one sign over 5 mm of the beam, about half a wavelength of sound at 32 kHz. That gives 0.019 × 1,000 × 0.005 ≈ 0.09 rad per pass, or about 0.19 rad in total. Lobes of opposite sign cancel: one beam measures a sum along a line, not a value at a point.

**Fast light, slower sensor.** The delay is set by how long the detector collects light and how long the sums take, not by the flight time (Derived). A clean signal can locate one small thing much more finely than a wavelength. It cannot separate two close things that finely.

**The fringe drifts.** With L = 200 mm, φ is about 3.9 million radians. The index of air falls by roughly one part in a million per kelvin. A 1 K change in air temperature along the path therefore moves the fringe by about half a cycle (Derived). The glass cylinder keeps draughts out, but the warmest internal air is 12.7 K above ambient (Derived, see [Heat](desktop-replicator.html#heat)). The readout has to tolerate that slow drift.

Cameras are not a substitute. They record at most about a thousand frames per second and cannot follow sound at {{c:desktop_geometry.comb_tones_hz|khz}} kHz.

## In the Desktop Replicator

The prototype uses {{c:mosquito_smi.total_ommatidia}} laser diodes at {{c:mosquito_smi.laser_wavelength_nm}} nm, nicknamed the mosquito eye.

- **Layout.** The diodes sit on two strips beside the rear tower, at azimuth ±{{c:mosquito_smi.window_azimuth_deg}}°. Each beam crosses the chamber to a retro-reflective strip, which sends light back the way it came, on a post at ∓{{c:mosquito_smi.retro_azimuth_deg}}°. The two sets of beams cross in the work volume. That gives two shadow views, not a three-dimensional image.
- **Detector.** Each diode is a standard three-pin package with a built-in monitor photodiode. Its signal is amplified and read by a fast comparator ({{c:mosquito_smi.comparator_mpn}}), a part that reports only "above" or "below". The piezo discs no longer use this 1-bit scheme: it failed its simulated test there and was replaced by a 16-bit converter. See [Laser readout electronics](compute-control.html#laser-readout-electronics).
- **The six flat panels.** In revision S, six flat aluminium panels, each about 57 mm wide and 2.5 mm thick, line the rear half of the inside of both glass cylinders. They carry the air-temperature and humidity sensors and sound-absorbing baffles. Two panels are left open over the laser band. Sensors inside the glass avoid the lens effect of the curved 5 mm wall. The panels are plain today. Later rungs can swap in active light or sound tiles without changing the glass (Derived from CAD).
- **What is not there.** No cameras, facets or ultraviolet cure module. The wafers are undrilled, so no beam passes through a plate.

**Laser safety.** The clear glass wall lets laser light out, so it is not a laser enclosure. A hardware safety switch sits in series with the laser supply and the supply that enables the drive stages. With the head up, the lasers are off and the drive stages are disconnected. Firmware also refuses to drive ([Thermal and safety](subsystems.html#s11-thermal-and-safety)). The candidate diodes are rated up to 5 mW each and none is selected. The laser class is Open and must be settled before the lasers are operated.

### Locking the shape in one shot

**What others have shown (Documented).** A computed pattern of light can harden a 3D object all at once instead of point by point. [Wang, Dai et al., *Nature* 2026](https://doi.org/10.1038/s41586-026-10114-5) printed millimetre parts in 0.6 s with 19 µm detail across 1 cm of depth, also inside a liquid channel ([Proven in the lab](evidence.html)). Sound and light together, one to arrange and one to harden, has been done in liquid resin ([Greenhall and Raeymaekers, 2017](https://doi.org/10.1002/admt.201700122)).

**What the machine plans (Design decision; Open).** After the sound field has gathered the feedstock, light shone through the clear cylinder wall and the six panels' windows sets the shape in one exposure. The medium would be a liquid or slurry whose density matches the feedstock, and it must also be a material that light hardens. None of this is in the CAD or the simulations yet. It is queued as part of S-VOL1.

**What decides it (Open).** The light dose has to reach the whole shape through a curved glass wall and a cloudy slurry. A part that has been hardened must also be recoverable, because the machine has to be able to take it apart again ([Removal and recovery](matter-loop.html)).

Signal size and amplifier bandwidth are also [Open](#open-questions). Inside opaque powder the beams see nothing, and [acoustic sensing through the piezo discs](acoustics.html#self-sensing-on-the-same-two-wires) takes over. The retired optical layout is listed in [Desktop Replicator](desktop-replicator.html#what-this-design-replaced).

## Toroidal optical pulses

A toroidal pulse, or "flying doughnut", is a very short burst of electromagnetic waves. Its field lines form a ring around the direction of travel. The field is zero on the axis. Its colour mix changes from the middle of the ring to the edge, so its shape in space cannot be separated from its shape in time. The pulses are published physics. Their use in this machine is Open.

| Source (Documented) | What it showed | What it did not show |
|---|---|---|
| [Zdagkas et al., 2022](https://doi.org/10.1038/s41566-022-01028-5) | Toroidal pulses made and measured at optical and terahertz frequencies | Any force on matter, any sensing use, any operation inside a cavity |
| [Wang et al., 2024](https://doi.org/10.1038/s42005-024-01850-z) | A microwave experiment in which one antenna used toroidal pulses to locate targets at centimetre scale | Optical operation, or accuracy and speed good enough for closed-loop control. It cannot be carried over to an optical servo without an optical experiment |
| [Vignjevic et al., 2026](https://doi.org/10.1088/2040-8986/ae36bf) | Optical toroidal pulses a few wave cycles long, with a full measurement of the pulse's state | Use outside an optics laboratory. It scans one projection at a time, too slow for a control loop |
| [Shi et al., 2026](https://doi.org/10.1038/s42005-026-02699-0) | Single-cycle microwave toroidal pulses with a controllable twist, launched from one horn and a spiral grating | Optical operation |

**Prototype hook.** The CAD model can add a rim-fed, twelve-arm spiral of copper or indium tin oxide, about {{c:dissolve_and_toroidal.borofloat_chiral_spiral_trace_thickness_um}} µm thick, intended as a launcher for such pulses. It is a geometry placeholder, off by default, with no drive electronics (Open).

**Why a spiral.** A shape drawn only with angles looks the same at every size, so it works over a very wide band of frequencies ([Rumsey, 1957](https://doi.org/10.1109/IRECON.1957.1150565), Documented; real spirals are cut off at both ends, which sets their band). A flat spiral also radiates backwards. A patterned backing surface keeps a thin spiral wide-band ([Luadang et al., 2025](https://doi.org/10.1038/s41598-025-96381-0), Documented for a radio antenna). Neither is modelled for the glass wafer (Open).

**Model limit.** Every project solver is continuous-wave: it computes steady fields at a single frequency. None models a pulse, so no statement about toroidal pulses in the chamber is a simulation result.

**Long-term interest (Open).** The dark axis would leave a channel for material while light travels around it. The prototype has no bore. The ring shape might also serve as a [topological label](#topological-labels).

Toroidal light pulses are not toroidal coils. [Electromagnetic control](electromagnetics.html#toroidal-and-pulsed-fields) keeps them apart.

## Topological labels

Some wave patterns carry a whole-number tag, such as how many times the field wraps around. A small disturbance cannot change a whole number a little, so the tag can survive a messy, echoing path. A skyrmion number is one such tag.

| Step | Published result (Documented) | Status here |
|---|---|---|
| Read the tag | Methods for working out a skyrmion number from noisy measurements ([Peters et al., 2026](https://doi.org/10.1117/1.ap.8.2.023001)) | Not used yet |
| Send the tag | A programmable microwave surface that writes skyrmion patterns and uses them to carry data and to sense ([Chen et al., 2026](https://doi.org/10.1038/s41928-026-01611-6)) | Open |
| Print the tag | Skyrmions stored in how a structured material bends polarised light ([Zhang et al., 2026](https://doi.org/10.1038/s41377-026-02307-4)) | Open. Test: write one label and read it back at print quality |
| Scale reference | One flat printed optic that made a very large array of light traps for single atoms ([Holman et al., 2026](https://doi.org/10.1038/s41586-025-09961-5)) | For cold atoms in vacuum. It shows the principle only |

"Topologically protected" describes the pattern. It does not promise that the pattern is stable in this chamber (Open).

## Long-term direction

- **Switching the acoustic surface.** Light, not wires, selects what each element of the light-switched surface does. See [Acoustics](acoustics.html#long-term-direction).
- **Patterned illumination.** A reconfigurable [metasurface](glossary.html) modulator shapes light for locking and heating. [Fan et al., 2026](https://doi.org/10.1038/s41565-026-02128-x) showed visible holography with an optically addressed metasurface at 756 nm pixel pitch (Documented). Pitch is a property of the modulator. It is not a guaranteed resolution in the chamber.
- **Small particles.** Light takes over below the sizes sound can place. See [The size ladder for optical traps](#the-size-ladder-for-optical-traps).
- **Light-to-sound coupling.** Patterned light absorbed at a surface heats it, and the swelling launches sound (photoacoustics). It is a candidate for trimming the sound field and checking it independently. Each lit spot is a sound source in a new place, which adds views to a [scan](matter-loop.html#scan-non-moving-3d-tomography-and-scattering) with no extra transducers. Half-on, half-off patterns give less noisy readings than one moving dot (Claim; use in the chamber is Open).
- **Passive optical processing.** A patterned piece of glass rearranges light before the detector. It does one fixed sum and uses no electricity. Diffractive facets in front of the laser ring are a later upgrade of this kind.
- **Energy recovery.** Antennas with rectifiers and cells tuned to heat glow could take back part of the energy put into the chamber, never more than was put in. See [The long-term machine](ultimate-replicator.html).

How sound and light act on each other: [Architecture](architecture.html#cross-carrier-verbs-inside-the-work-volume).

### The size ladder for optical traps

A tightly focused beam pulls a small clear particle toward its brightest point. This is an optical tweezer ([Ashkin et al., 1986](https://doi.org/10.1364/OL.11.000288), Documented for micrometre particles in water).

| Tool | Particle size it suits | Why it stops there |
|---|---|---|
| Sound | Millimetres down to about a micrometre | Sound pushes far harder per watt ([Acoustics](acoustics.html#why-sound-carries-the-force)), but its features cannot be [finer than half a wavelength](acoustics.html#how-fine-the-field-can-be) |
| Optical tweezer | About 10 µm down to about 10 nm | The trap is about half a light wavelength wide. Forces are piconewtons (a millionth of a millionth of a newton). Positioning reaches nanometres |
| Near-field trap | Below a few tens of nanometres | The pull shrinks with the particle's volume. For tiny particles, heat jiggling beats a plain trap |

One computed hologram can make many traps and steer each one ([Grier, 2003](https://doi.org/10.1038/nature01935), Documented). At the extreme, [Holman et al., *Nature* 2026](https://doi.org/10.1038/s41586-025-09961-5) trapped single atoms in a flat metasurface's array of about 360,000 traps, so the hologram is the machine for atoms and very small particles (Documented; the long-term rung, not the desktop). The plan is that sound carries a piece into reach and light does the last alignment. Trap stiffness, heating and the hand-over are Open. No published work shows the two working together in one chamber. Nanometre-scale building is not claimed.

### Printed radiating surfaces

A printed surface can shape a wave with no electronics in each cell. Three ideas are Documented at microwave or millimetre-wave frequencies. Using any of them in this machine is Open.

| Idea | What it does | Limit |
|---|---|---|
| Leaky trapped wave | A perfectly even pattern traps a wave so it never escapes. A small planned unevenness lets it leak at a chosen rate. The surface then sets the beam shape by geometry alone ([Xu et al., 2023](https://doi.org/10.1038/s41467-023-39818-2)) | Fixed once printed |
| Slow surface-wave feed | A grooved feed makes a slow wave that hugs the surface. A slower wave has a shorter wavelength, so the surface holds more independent cells. The pattern can also make corkscrew (circularly polarised) waves ([Zohrevand et al., 2025](https://doi.org/10.1038/s41598-025-85300-y)) | Fixed once printed. Needs a clean feed |
| Time-switched surface | Switching each cell in time shifts a wave to a new frequency, so one antenna sets strength, timing and frequency ([Wu et al., 2025](https://doi.org/10.1126/sciadv.adx7090)) | Every cell needs a fast switch and a drive wire. It shifts frequency within the electromagnetic band only. It does not turn sound into light |

**Rule (Design decision).** Use a fixed printed surface where one fixed job is enough. Pay for a switched surface only where changing frequency is worth the wiring.

### Fabricating the next optical module

Crystals made of light patterns, such as an opal or a hologram stored in a lithium niobate crystal, are covered in [Crystals](crystals.html#rung-2-crystals-of-light).

The first machine cannot make structures finer than a light wavelength. Optical modules therefore start as bought optics or outside-made masters. Copies can then be made by nanoimprint, which presses the pattern into a resin loaded with high-index nanoparticles ([published protocol](https://doi.org/10.1038/s41596-026-01407-0), Documented).

The tolerance that matters is surface height. A height error δh on a clear element of index n gives a phase error δφ:

    δh = λ · δφ / (2π · |n − 1|)

For λ = 650 nm, n = 1.5 and an allowed phase error of 0.1 rad, the height must be right to about 21 nm (Derived). Each optical upgrade records light lost in the part, height error and the share of parts without defects ([The upgrade loop](upgrades.html)).

## Rear panels, by rung

The six rear panels are the optical seat of the machine (module M05). Today they are passive aluminium baffles with temperature and humidity sensors and clear windows, inside the glass so the curved wall cannot bend the light (Derived). The next step is fibre-fed projectors that lock a whole shape in one exposure, a design decision that rests on lab results from others ([Wang et al. 2026](https://doi.org/10.1038/s41586-026-10114-5) (`R083`), [Lin et al. 2026](https://doi.org/10.1126/sciadv.aec3536) (`R151`)). The target is a programmable metasurface panel (Claim; [Holman et al. 2026](https://doi.org/10.1038/s41586-025-09961-5), `R141`). The fibre feed is a plan, with no link budget yet ([upgrade map](upgrades.html#m05)).

## Open questions

| Question | Who answers it |
|---|---|
| What fringe signal does a retro-reflective strip return over a path of about 200 mm? Earlier estimates of 50 µV to 1 mV per fringe assumed 50 mm (method: [Giuliani et al., 2002](https://doi.org/10.1088/1464-4258/4/6/371)). Can a 0.1 rad sound signal be resolved? | Optical derivation, then first bench test |
| Which amplifier design keeps its gain up to the highest drive tone? A single stage with the planned gain does not | Circuit design ([Laser readout electronics](compute-control.html#laser-readout-electronics)) |
| What laser class is the machine with a clear glass wall, and is the safety switch sufficient? | Safety review against the standard |
| Do {{c:mosquito_smi.total_ommatidia}} line sums in two directions constrain the sound field usefully, given temperature drift in the closed chamber? | Simulation, then bench test |
| Does the spiral conductor launch a useful pulse, and what would drive it? | Pulse-capable simulation, which does not exist yet |
| Can a whole-number label be written and read back in this chamber? | A model, then a write-and-read test |

Related: [Digital twin](digital-twin.html) and [Proven in the lab](evidence.html).
