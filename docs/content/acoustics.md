# Acoustics

The acoustic subsystem makes the force that holds and moves material. Two facing plates radiate ultrasound into the chamber, the sound forms a standing pattern, and small objects settle into its quiet pockets. The same sources also listen, so the subsystem senses what it is holding. Everything here is design, derivation or simulation.

## The physics that matters

### Why sound carries the force

An absorbed wave pushes with a force equal to its power divided by its speed. One watt of sound in air pushes with 2.9 mN, one watt of light with 3.3 nN (Derived). Sound also has millimetre wavelengths at frequencies that ordinary electronics handle easily. [Architecture](architecture.html#two-carriers-five-wavelength-decades-and-volume-crossings) compares the two carriers.

### Bending waves in a plate

A small piezoelectric disc bonded to a thin plate does not radiate much sound itself. It bends the plate, and the bending (flexural) wave spreads across the plate and radiates from the whole face. For a thin plate of thickness h, density ρ and bending stiffness D, the bending wavenumber k at angular frequency ω is

    k⁴ = ρ h ω² / D        D = E h³ / 12(1 − ν²)

so the wave speed rises with the square root of frequency. That frequency dependence is called dispersion.

Worked numbers for a {{c:desktop_geometry.wafer_thickness_mm}} mm borosilicate plate (D about 5.5 N·m, 2.23 kg/m², thin-plate theory, Derived):

| Tone | Bending wavelength | Bending wave speed | Wavelength in air |
|---|---|---|---|
| 32 kHz | 17.5 mm | 560 m/s | 10.7 mm |
| 96 kHz | 10.1 mm | 970 m/s | 3.6 mm |
| 160 kHz | 7.8 mm | 1,250 m/s | 2.1 mm |

Above about 12 kHz the bending wave in this plate is faster than sound in air. Such a wave radiates efficiently, at an angle from the plate normal whose sine is the ratio of the two speeds: about 38° at 32 kHz and 16° at 160 kHz.

### Why a few sources give many patterns

Each source sets up a standing bending pattern over the whole plate, shaped by reflections from the rim. Because of dispersion, the pattern at 64 kHz is not the 32 kHz pattern scaled down. Each tone radiates a differently shaped sound field. Flats cut into the wafer rim and off-centre source positions break the symmetry that would otherwise make sources redundant. Six sources and five tones on one plate therefore give thirty distinct radiated fields rather than six.

Distinct is not the same as sufficient; see [Known limits](#known-limits).

### The radiation force and where traps sit

A particle much smaller than the wavelength feels a time-averaged force that is the downhill slope of the Gor'kov potential (Gor'kov, 1962):

    U = 2π a³ [ f₁ ⟨p²⟩ / (3 ρ₀ c₀²) − f₂ ρ₀ ⟨v²⟩ / 2 ]        F = −∇U

Here a is the particle radius, ⟨p²⟩ and ⟨v²⟩ are the mean-square sound pressure and air velocity, and ρ₀ and c₀ are the density and sound speed of air. The factors f₁ and f₂ compare the particle's stiffness and density with the air's. For any solid or liquid in air both are close to 1.

The first term is positive, so the particle is pushed away from loud places. The second is negative, so it is drawn to where the air moves most. In a standing wave those are the same places: the pressure nodes. Nodes along the axis between the plates are half a wavelength apart, 5.4 mm at 32 kHz and 1.1 mm at 160 kHz.

Three consequences shape the design.

- **The force depends on squared amplitudes.** Reversing the sign or the phase of a holding pattern gives the same force. It cannot push material out or take a joined part apart. Removal needs a different mechanism, described in [Scan, recover and matter stores](matter-loop.html).
- **Tones add as forces, not as pressures (Derived).** The cross terms between two different tones oscillate at their difference frequency and average to zero. The total potential is the sum of one potential per tone. The tones are whole multiples of 32 kHz so that the mixing products created by nonlinear air at high level fall on multiples of 32 kHz instead of spreading between the tones.
- **The formula has a size limit (Derived).** It assumes a particle much smaller than the wavelength. At 160 kHz the wavelength is 2.1 mm, so the Ø1 to 2 mm calibration spheres are outside that assumption at the upper tones. Forces on them need a full scattering calculation (Open).

Holding a stationary object does no mechanical work. The power needed is what the chamber loses: stored energy times angular frequency divided by the chamber's quality factor.

### How fine the field can be

At the top tone of 160 kHz the smallest pressure feature is half a wavelength, 1.1 mm. The smallest force feature is about half of that, 0.5 mm, because force follows squared pressure (Derived). A trap can still be moved in steps much smaller than a wavelength, because its position follows the drive phases continuously. How small in practice depends on calibration and noise (Open). Finer features, as opposed to finer placement, need a higher frequency.

<a id="simultaneous-two-terminal-haptic-self-sensing"></a>

### Self-sensing on the same two wires

A piezoelectric disc that pushes on the plate is pushed back by it, and that reaction appears in its current. The disc can therefore be a sensor while it is a source, with no separate listening interval ([Dosch, Inman &amp; Garcia, 1992](https://doi.org/10.1177/1045389X9200300109), Documented). In the standard lumped model of a piezo element:

    m ẍ + c ẋ + k x = Θ V(t) + F_echo(t)
    I(t) = C₀ dV/dt + Θ ẋ(t)

V is the drive voltage, I the current, x the displacement of the disc face, Θ the electromechanical coupling, C₀ the capacitance of the disc and F_echo the force returned by the plate and chamber. The first part of the current charges the capacitance and carries no information. The second is proportional to face velocity and contains the echo.

The difficulty is the ratio. The echo from a 2 mm droplet is estimated at 60 to 80 dB below the drive current, and C₀ drifts by about {{c:haptic_pzt.c0_tempco_pct_per_c}} % per kelvin, a larger change than the echo (Derived). The design subtracts the current of an identical disc that is bonded to nothing, which drifts the same way and hears nothing, then measures the remainder at all five tones at once. The converter is described in [Desktop Replicator](desktop-replicator.html#electronics). Whether it reaches the required dynamic range with five tones present is an open simulation gate.

## In the Desktop Replicator

The prototype has two identical acoustic bodies, one in the floor of the chamber and one in the ceiling, {{c:desktop_geometry.gap_mm}} mm apart. The full description is in [Desktop Replicator](desktop-replicator.html).

- **Plates.** Each is an undrilled Ø{{c:desktop_geometry.wafer_diameter_mm}} × {{c:desktop_geometry.wafer_thickness_mm}} mm borosilicate wafer ({{c:desktop_geometry.wafer_material}}) held only at its rim in a soft silicone ring, with Ø{{c:desktop_geometry.clear_glass_diameter_mm}} mm of glass free to vibrate.
- **Sources.** {{c:desktop_geometry.ports_per_plate}} discs of the hard piezoceramic PZT-8, Ø{{c:desktop_geometry.pzt_diameter_mm}} × {{c:desktop_geometry.pzt_thickness_mm}} mm, are bonded to the back of each wafer at different radii. There are 12 in total.
- **Tones.** {{c:desktop_geometry.comb_tones_hz|khz}} kHz, driven together.
- **Surface.** Bare glass by default. A printed phase lens on the chamber face is an option.
- **Behind the plate.** A {{c:desktop_geometry.moth_absorber_thickness_mm}} mm absorbing layer damps reflections from the cavity behind the wafer. The drive and sense electronics sit within millimetres of the discs.
- **Small preset.** `boro12` uses Ø{{c:desktop_geometry.boro12_reducer_wafer_mm}} mm wafers {{c:desktop_geometry.boro12_gap_mm}} mm apart with Ø{{c:desktop_geometry.boro12_pzt_diameter_mm}} mm discs and tones of {{c:desktop_geometry.boro12_comb_tones_hz|khz}} kHz.

The plate spacing is 17 wavelengths at 32 kHz and 84 at 160 kHz.

**What the rest of the machine sees.** The acoustic bodies are handed to the planner as a response: at each frequency f, the sound pressure p in the chamber is a fixed linear map H of the drive amplitudes u,

    p(f) = H(f) u(f)

The map is stored in a response file ([Architecture](architecture.html#interfaces-that-survive-upgrades)). Today it comes from a reduced thin-plate model. It will be replaced by measurement once a machine exists.

**Why plates and not an array of emitters.** In an earlier simulated study of a larger design, small ceramic discs radiating directly into air reached 0.16 m/s of face velocity where the field needed 4.75 m/s. Closing that gap with resonant emitters took about 1,500 separately wired elements (Simulated and Derived). Plates driven in bending give a large radiating face from few wires. Bolt-clamped Langevin horn transducers are parked: they are narrow-band, so they cannot play several tones or change pattern quickly.

## Known limits

None of these limits is yet resolved for the Desktop Replicator.

**Control rank (Derived).** At one frequency the field is p = H·u, so N sources give at most N independent field patterns, whatever the plate does. A plate with many vibration modes does not add controls. The prototype has 12 sources and 5 tones, which is 60 complex amplitudes. Across tones the fields do not add coherently: the force is a sum of one squared term per tone, which is more constrained than adding pressures. Sixty controls is the budget for every trap, every unwanted well and every correction.

**Parasitic wells (Simulated, earlier six-source study).** Single-frequency fields from six sources held one foam bead well but left 8 to 26 unwanted wells in the working region. That is single-bead manipulation. It is not powder handling, several independent traps or fabrication. Whether 12 sources and 5 tones remove the unwanted wells in the Desktop Replicator is Open.

**Source size (Derived).** A bonded disc drives bending efficiently only if it is smaller than half the bending wavelength. Beyond that, parts of the disc push against each other. For the {{c:desktop_geometry.wafer_thickness_mm}} mm wafer, half the bending wavelength is about 4.4 mm at 128 kHz and 3.9 mm at 160 kHz. The Ø{{c:desktop_geometry.pzt_diameter_mm}} mm disc adopted on 18 November 2026 is several times larger than that. The solid finite-element model, which supersedes this rule of thumb, shows the larger disc delivers more pressure per volt at every tone. Whether pattern control survives with discs this large has not been checked (Open).

**Air temperature (Derived).** The speed of sound changes by about 0.17 % per kelvin. Across the {{c:desktop_geometry.gap_mm}} mm spacing at 160 kHz that is roughly 70° of phase per kelvin, and about 14° at 32 kHz. A calibration therefore goes stale at the top tone when the air changes by a few tenths of a kelvin. The estimated rise of the air inside the enclosure is about 5 K, and how much of that reaches the open chamber is not modelled. Temperature tracking is part of calibration, not an extra.

**Ring-down bounds time-sharing (Simulated, earlier study).** Switching between patterns faster than the source and plate ring down loses the held object. In the earlier study, sources with a quality factor near 500 rang for 4.5 ms and dropped the bead at every switch. Sources with a quality factor near 50 worked, at about ten times the power. The ceramic itself responds in well under a microsecond, so the structure sets the limit. The ring-down time of the prototype wafer is Open.

**Plate spacing changed (Open).** The spacing was raised from 120 to {{c:desktop_geometry.gap_mm}} mm. Simulated results for the earlier spacing do not carry over, and the field at the new spacing has not been studied.

**The reduced plate model is contradicted by the solid model (Simulated).** The plate response used for planning is thin-plate theory with idealised sources and a rim that absorbs. A three-dimensional solid finite-element model of the wafer, discs and rim seal (Gmsh and CalculiX) was completed on 18 November 2026. Its bending wavelength agrees with plate theory to within 2.4 % across the drive tones. Its field does not agree with the planning file:

- **The plate rings.** The planning model lets a wave die out over about 45 mm. In the solid model the wave loses little on each crossing (its decay length is about 1.25 m), so it reflects from the rim many times and the plate behaves as a resonator.
- **The shipped plate-response file is uncorrelated with the solid model.** The correlation of the two radiated fields is 0.06, which is chance level. Results planned from that file, including design-search rankings, do not carry over.
- **The patches are too coarse.** Even the solid field, sampled on the file's 96 patches per plate, reproduces its own radiated field at only 0.21. A correlation of 0.95 needs patches about 6 mm apart at 32 kHz and 1.5 mm apart at 160 kHz.
- **The response cannot be predicted in advance.** A change equivalent to 0.5 % in plate thickness drops the field correlation to 0.55. Each plate's response therefore has to be measured in the chamber after assembly. The soft rim seal behaves like a free edge; a rigid clamp would change the response completely.
- **Control is not the limit.** All 60 independent drive settings (twelve sources at five tones) remain independent on this plate.

**Drive strength is the limit, and the glass sets it (Simulated).** With all twelve sources phased onto one point, the Ø{{c:desktop_geometry.pzt_diameter_mm}} × {{c:desktop_geometry.pzt_thickness_mm}} mm discs give {{c:haptic_pzt.drive_authority_pa_per_volt|and}} Pa per volt at the five tones. The Ø4.6 × 0.8 mm discs they replaced gave 0.21 to 0.97. Holding a solid polystyrene bead needs about 0.9 to 2.0 kPa. Larger discs lower the voltage needed but do not change the underlying limit: a bending wave stresses the glass by about 21 MPa for each metre per second of plate velocity, whatever the frequency or thickness (Derived). The pressure that holds solid polystyrene puts 15 to 21 MPa in the plates, above an assumed design limit of {{c:desktop_geometry.plate_bending_stress_limit_mpa}} MPa (the glass maker's characteristic strength is {{c:desktop_geometry.plate_characteristic_strength_mpa}} MPa), and dissipates 11 to 15 W in them. More sources, a stronger plate or lighter feedstock are the ways around it.

**A foam bead is the first test particle (Simulated).** A bead of 30 kg/m³ needs about one sixth of the pressure, which keeps glass stress at 2.5 to 4 MPa. The computed recipe is a Ø{{c:desktop_geometry.pzt_diameter_mm}} × {{c:desktop_geometry.pzt_thickness_mm}} mm piezo disc, a single tone at 128 or 160 kHz, and a {{c:haptic_pzt.bridge_rail_v}} V supply: that gives {{c:haptic_pzt.max_drive_v_peak_single_tone}} V at the disc. With the present glass cylinder the simulated lift at 160 kHz is about 1.2 times the bead's weight in the median position. On the earlier 12 V supply it failed. The design constants adopted this recipe on 18 November 2026. It has not been checked for pattern control with the larger discs, which exceed the half-wavelength rule above.

**The glass cylinder helps modestly (Simulated).** Closing the chamber with the glass cylinder raises the pressure by {{c:desktop_geometry.chamber_gain_closed_nominal|and}} times at the five tones for the nominal spacing, and by {{c:desktop_geometry.chamber_gain_closed_gap_median|range}} times as the median over a ±20 % range of spacing. These figures are for the present cylinder, {{c:desktop_geometry.glass_cylinder_id_od_mm|x}} mm inside and outside diameter. An open chamber gives 1.01 to 1.08. A simple mirror estimate had suggested a factor of eight; the plate radiates 16° to 38° off its normal and the beam walks off the opposite plate.

**One tone lifts; several tones clean (Simulated).** The five tones share one supply. Driven together, each gets a fifth of the voltage and a twenty-fifth of the power, and the twelve sources then lift only about 7 % of a foam bead's weight. One tone at full voltage lifts 10 to 20 times more. The five-tone drive is still needed, at lower level, to remove unwanted traps and to listen. A build therefore alternates between the two. Raising the count to 18 sources per plate would lift about 11 times the bead's weight in the same model; that is a possible upgrade, not the present design.

**Calibration goes stale quickly (Simulated).** In the closed chamber the measured response stays valid (correlation 0.97) after a 0.1 K change in air temperature or a 50 µm change in spacing. After 0.5 K it falls to 0.63, and after 200 µm to 0.65. The response therefore has to be re-measured or tracked after every head lift and every few tenths of a kelvin.

**Unwanted traps (Simulated).** All 60 drive settings stay independent, but one tone from twelve sources leaves 10 to 17 % of the work volume above 70 % of the target amplitude, against a limit of 2 %. Filling four sites at once is even to 0.79 to 0.93 in the median case and 0.53 to 0.71 in the worst tenth, against a target of 0.8. This gate fails.

<a id="ultimate-vs-prototype-acoustic-apertures"></a>

## Long-term direction

The long-term acoustic surface is not a plate with a few discs. The comparison with the prototype is in [Architecture](architecture.html#long-term-architecture-and-the-desktop-replicator). The main elements, all Open as an integrated design:

- **Optically addressed aperture.** A continuous piezoelectric film carries a few shared drive lines at fixed phases. A light-sensitive electrode layer selects which phase reaches each of about 100,000 small regions, so no region needs its own wire. This lifts the control-rank limit above. See [The Acoustic Hologram](../papers/replicator_acoustic_hologram.html#s10).
- **Impedance matching.** A piezoceramic has an acoustic impedance near 30 MRayl and air about 415 Rayl, so only about 0.006 % of the power crosses a bare interface (Derived). Structures that taper the impedance gradually are the intended remedy.
- **Higher frequency.** Working near 1 MHz, where half a wavelength in gas is under 0.2 mm, is a candidate for finer features.

## Open questions

| Question | Who answers it |
|---|---|
| What combination of resonant tones, source size, drive voltage and bead density reaches a holding pressure on the Ø{{c:desktop_geometry.wafer_diameter_mm}} mm wafer? | Simulation, then design |
| How is each plate's response measured in the chamber, and at what patch spacing? | Simulation and calibration design |
| At the {{c:desktop_geometry.gap_mm}} mm spacing, do 12 sources and 5 tones hold one object without unwanted wells nearby? | Simulation, then in-chamber calibration |
| How much drive is lost at 128 and 160 kHz because the disc is oversized? | Simulation |
| How long does the wafer ring, and how fast can patterns change? | Simulation, then in-chamber calibration |
| How is air temperature tracked during a job, and how often is recalibration needed? | Control design |
| What is the force on a sphere comparable in size to the wavelength? | Simulation |
| Does self-sensing resolve the echo with five tones present? | Simulation |

Related: [Compute, sensing and control](compute-control.html), [Digital twin](digital-twin.html) and the [Glossary](glossary.html).
