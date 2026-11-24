# Acoustics

Sound makes the force that holds and moves material. Two facing plates send ultrasound into the chamber, and small objects settle into the quiet pockets of the standing pattern. The same sources also listen. No figure here is Measured by this project. Every claim has an [evidence label](status.html#evidence-labels).

## The physics that matters

### Why sound carries the force

Per watt, sound in air pushes close to a million times harder than light ([why](architecture.html#two-carriers-five-wavelength-decades-and-volume-crossings), Derived). Its wavelengths are millimetres at frequencies that ordinary electronics handle.

### Why two plates

The machine must hold material in a pattern and take sound energy back out. Two plates are the smallest machine that does both.

- **Holding needs two waves that meet head-on.** A [standing wave](glossary.html) is two waves travelling in opposite directions, and two facing plates are the simplest way to make one (Documented: levitators such as [TinyLev](https://doi.org/10.1063/1.4989995)).
- **Absorbing needs both exits covered.** Sound in the gap leaves upward or downward, and one plate catches only its own half. Full absorption, the first step of [removal](matter-loop.html#the-four-stage-sequence), is Open here.

Two plates control the field well along the line between them and weakly sideways; side-wall sources would complete it (Derived; see [Architecture](architecture.html)).

**Can a plate aim sound at the other plate (Derived).** The Fresnel number answers this:

    N = a² / (λ · L)

Here a is the plate radius, L the gap and λ the wavelength. Well above 1, a beam stays between the plates. Near 1 or below, the wave fills the chamber. For the Desktop Replicator (89.8 mm of free glass radius, {{c:desktop_geometry.gap_mm}} mm gap) N is about 3 at 32 kHz and 16 at 160 kHz. That alone is not enough: these plates send sound out at an angle ([Bending waves in a plate](#bending-waves-in-a-plate)).

### Air sets the top frequency

Air soaks up ultrasound, and high tones fade fastest. The table applies the ISO 9613-1 air-absorption formula (cited in words; no source registered) at 20 °C, 50 % humidity and sea-level pressure, stretched above its tested range, so the figures are Derived estimates. On the [decibel](glossary.html) scale, 3 dB is half the power and 10 dB a tenth.

| Tone | Loss per metre | Loss on one {{c:desktop_geometry.gap_mm}} mm crossing |
|---|---|---|
| 32 kHz | 1.0 dB | 0.2 dB |
| 96 kHz | 3.1 dB | 0.8 dB |
| 160 kHz | 5.9 dB | 1.4 dB |
| 300 kHz | 16 dB | 3.9 dB |
| 1 MHz | 160 dB | 39 dB, about 1 part in 8,000 left |

- **Loss per crossing is what counts.** Up to 200 to 300 kHz a short chamber loses a few dB per crossing. That caps the finest pressure feature in air at roughly 0.6 to 0.9 mm.
- **Megahertz sound belongs to liquids and solids.** Near 1 MHz the sound crosses the air once and is gone.

The machine runs in room air (Design decision), with humidity held at {{c:electrostatics_and_matter_loop.chamber_ambient_rh_pct_range|range}} % to control static charge ([Thermal and safety](subsystems.html#s11-thermal-and-safety)).

### Bending waves in a plate

A small piezo disc (a ceramic that changes shape under voltage) bonded to a thin plate radiates little sound itself. It bends the plate, and the whole face radiates. For a plate of thickness h, density ρ and bending stiffness D, the bending (flexural) wavenumber k at angular frequency ω is

    k⁴ = ρ h ω² / D        D = E h³ / 12(1 − ν²)

The wave speed rises with the square root of frequency. Such a frequency-dependent speed is called dispersion.

For a {{c:desktop_geometry.wafer_thickness_mm}} mm borosilicate plate (D about 5.5 N·m, 2.23 kg/m², thin-plate theory, Derived):

| Tone | Bending wavelength | Bending wave speed |
|---|---|---|
| 32 kHz | 17.5 mm | 560 m/s |
| 96 kHz | 10.1 mm | 970 m/s |
| 160 kHz | 7.8 mm | 1,250 m/s |

Above about 12 kHz, the coincidence frequency, the bending wave outruns sound in air and the plate radiates well with no horn. The sound leaves at an angle from straight ahead: about 38° at 32 kHz and 16° at 160 kHz.

**What the plate has to be (Derived).** The pattern lives in the drive signals; the plate only mixes them.

1. **Radiate.** Work above the coincidence frequency, about c_air² / (1.8 · c · h), with c the speed of stretching waves in the glass (about 5,470 m/s).
2. **Be thin and ring freely.** Thin-plate behaviour holds while the bending wavelength is at least five times the thickness: up to about 400 kHz for 1 mm glass.
3. **Share no symmetry with its sources.** A round plate driven at its centre makes only rings. Sources at different radii avoid this.
4. **Have a soft edge.** A rigid clamp kills the patterns near the rim.

### What a sound hologram is

If the loudness and timing (phase) of a steady tone are known everywhere on a surface that wraps a source-free space, the sound is known everywhere inside (Documented, source not yet registered: the Kirchhoff and Helmholtz result of textbook wave physics). A hologram of an object at one tone is that list of loudness and timing on the plates. Two plates miss the side view. A piezo disc reads both directly, so recording a sound hologram is plain sampling.

**How many numbers a plate can hold (Derived).** A plate of area A can make at most one pattern per half-wavelength square at one tone: N = 4A/λ². For the Ø{{c:desktop_geometry.clear_glass_diameter_mm}} mm of free glass (0.0253 m²) this sample budget is about 900 at 32 kHz and 22,000 at 160 kHz. Twelve sources use little of it.

### Why a few sources give many patterns

Each source sets up a standing bending pattern over the whole plate, shaped by reflections from the rim. Because of dispersion, the pattern at 64 kHz is not the 32 kHz pattern scaled down. Six sources and five tones on one plate therefore give thirty distinct radiated fields, not six. Distinct is not the same as sufficient; see [Known limits](#known-limits). The lower tones add no finer detail. [Scan](matter-loop.html#scan-non-moving-3d-tomography-and-scattering) uses them for a coarse first picture and a size label (Derived).

### The radiation force and where traps sit

A particle much smaller than the wavelength feels a steady force. It is the downhill slope of the Gor'kov potential (Documented: [Bruus, 2012](https://doi.org/10.1039/C2LC21068A); first given by Gor'kov in 1962):

    U = 2π a³ [ f₁ ⟨p²⟩ / (3 ρ₀ c₀²) − f₂ ρ₀ ⟨v²⟩ / 2 ]        F = −∇U

Here a is the particle radius, ⟨p²⟩ and ⟨v²⟩ the mean-square sound pressure and air velocity, and ρ₀ and c₀ the density and sound speed of air. The contrast factors compare the particle with the air: f₁ = 1 − κ_p/κ₀ for squashiness and f₂ = 2(ρ_p − ρ₀)/(2ρ_p + ρ₀) for density. For any solid or liquid in air both are close to 1.

The first term pushes the particle away from loud places. The second draws it to where the air moves most. In a standing wave both are the pressure nodes, the quiet spots, half a wavelength apart: 5.4 mm at 32 kHz and 1.1 mm at 160 kHz.

**One number decides the direction.** Φ = f₁ + (3/2) f₂. If Φ is positive, as for every solid and liquid in air (about 2.5), the particle goes to the quiet spots. A bubble in water has negative Φ and goes to the loud spots.

**The simplest case (Derived).** For a standing wave of pressure P₀ sin(kz) between the plates, the force along the axis is

    F_z = −(4/3) π a³ · k · E · Φ · sin(2kz)        E = P₀² / (4 ρ₀ c₀²)

The force points back to the node and grows with the particle's volume. E is the sound energy per cubic metre.

**A bead is held when the force beats its weight.** The size cancels:

    P₀² > 4 ρ₀ c₀² · ρ_p · g / (k Φ)

With air at 1.204 kg/m³ and 343 m/s and Φ = 2.5, solid polystyrene (1,050 kg/m³) needs about 2.0 kPa at 32 kHz and 0.9 kPa at 160 kHz. A foam bead of 30 kg/m³ needs about 0.34 and 0.15 kPa, one sixth as much.

**A sign trap.** Many papers print this force for a cosine wave, with no minus sign and no one-third. Mixing the conventions swaps quiet and loud spots, so the [digital twin](digital-twin.html) tests its sign against the form above.

Consequences for the design:

- **The force depends on squared amplitudes.** Reversing the sign or phase of a holding pattern gives the same force, so it cannot push material out ([why](matter-loop.html#why-reversing-a-holding-pattern-removes-nothing)). Removal is absorption at a measured resonance, then transport to a crucible (Simulated).
- **Tones add as forces, not as pressures (Derived).** Cross terms between two tones average to zero, so tones cannot cancel each other.
- **Loud sound makes its own overtones (Derived).** A loud tone grows overtones at 2, 3, 4 times its pitch over a distance ρ₀c₀³ / (β ω p), with β = 1.2 for air: at 160 kHz about 270 mm at 0.15 kPa and 45 mm at 0.9 kPa. So the tones are whole multiples of 32 kHz, which mix only into other whole multiples, as do the harmonics of a [square-wave drive](compute-control.html#drive-stage).
- **The formula has a size limit (Derived).** At 160 kHz the wavelength is 2.1 mm, so the Ø1 to 2 mm calibration spheres are not small. Forces on them need a full scattering calculation (Open).
- **Sharing costs force (Derived).** Split a fixed power between N holding sites and the pressure at each falls as 1/√N, the force as 1/N.
- **Holding costs only the losses (Derived).** The power needed is P = ω · E_stored / Q: 2π times the tone, times the sound energy in the chamber, divided by the quality factor Q, the number of cycles the chamber rings.
- **Dense solids are held by the air round them.** Steel reflects 99.996 % of the sound that hits it (Derived). Solid iridium, 22.6 g/cm³, has been levitated in a tuned single-axis levitator ([Xie et al., 2002](https://doi.org/10.1103/PhysRevLett.89.104304), Documented). In three dimensions with several tones it is Open, and the pressure would overstress the prototype's glass ([Drive strength and lift](#drive-strength-and-lift)).

### How fine the field can be

"Precision" is three separate things (Derived). Placement, how finely a trap can be moved, can be far smaller than a wavelength. Stiffness, how hard the trap pulls a bead back, depends on drive level. Selectivity, whether other places also hold material, is the only one set by spot size and stray loud spots.

| Quantity | Limit | Value here | Label |
|---|---|---|---|
| Pressure feature | Half the shortest wavelength | 1.1 mm at 160 kHz | Derived |
| Force feature | About a quarter of the shortest wavelength, because force follows squared pressure | About 0.5 mm | Derived |
| Depth along the axis | Sound speed ÷ (2 × band swept) | About 1 mm for the {{c:desktop_geometry.golomb_band_khz|range}} kHz scan band | Derived |
| Position of one known small object | A small fraction of a wavelength, set by calibration and noise ([resolution ladder](matter-loop.html#scan-non-moving-3d-tomography-and-scattering)) | Not known | Open |

More tones do not make sharper features: a wider band buys depth. Finer features need a higher frequency, and [air caps that](#air-sets-the-top-frequency).

<a id="simultaneous-two-terminal-haptic-self-sensing"></a>

### Self-sensing on the same two wires

A piezo disc that pushes on the plate is pushed back by it, and the reaction shows in its current. So the disc can sense while it drives ([Dosch, Inman &amp; Garcia, 1992](https://doi.org/10.1177/1045389X9200300109), Documented). In the standard lumped model:

    m ẍ + c ẋ + k x = Θ V(t) + F_echo(t)
    I(t) = C₀ dV/dt + Θ ẋ(t)

V is the drive voltage, I the current, x the movement of the disc face, Θ the coupling, C₀ the disc's capacitance ({{c:haptic_pzt.c0_nominal_pf}} pF) and F_echo the force returned by the plate and chamber. Only the second part of the current carries the echo.

The echo from a 2 mm droplet is estimated at 60 to 80 dB below the drive current, and C₀ drifts by about {{c:haptic_pzt.c0_tempco_pct_per_c}} % per kelvin, more than the echo (Derived). The design subtracts the current of an identical disc bonded to nothing. The 1-bit converter first chosen failed its simulated test ({{c:haptic_pzt.sfdr_simulated_dbc}} dB against the {{c:haptic_pzt.sfdr_gate_min_db}} dB required) and is replaced by a 16-bit converter ({{c:haptic_pzt.adc_fallback_mpn}}): see [Compute, sensing and control](compute-control.html#acoustic-lamina-75-msas-1-bit-sigma-delta-piezo-haptic).

## In the Desktop Replicator

Two identical acoustic bodies sit in the floor and ceiling of the chamber, {{c:desktop_geometry.gap_mm}} mm apart, inside a stock glass cylinder that lifts with the head. See [Desktop Replicator](desktop-replicator.html) and the datasheet [S04 Acoustic array](subsystems.html#s04-acoustic-array).

- **Plates.** Each is an undrilled Ø{{c:desktop_geometry.wafer_diameter_mm}} × {{c:desktop_geometry.wafer_thickness_mm}} mm borosilicate wafer ({{c:desktop_geometry.wafer_material}}) held only at its rim in a soft silicone ring, with Ø{{c:desktop_geometry.clear_glass_diameter_mm}} mm of bare glass free to vibrate.
- **Sources.** {{c:desktop_geometry.ports_per_plate}} discs of the hard piezoceramic PZT-8, Ø{{c:desktop_geometry.pzt_diameter_mm}} × {{c:desktop_geometry.pzt_thickness_mm}} mm, are bonded to the back of each wafer at different radii: 12 in total.
- **Tones.** {{c:desktop_geometry.comb_tones_hz|khz}} kHz, driven together. The gap is 22 wavelengths at 32 kHz and 112 at 160 kHz.
- **Behind the plate.** A {{c:desktop_geometry.moth_absorber_thickness_mm}} mm absorbing layer damps reflections from the cavity behind the wafer. The electronics sit within millimetres of the discs.
- **Small preset.** `boro12` uses Ø{{c:desktop_geometry.boro12_reducer_wafer_mm}} mm wafers {{c:desktop_geometry.boro12_gap_mm}} mm apart with Ø{{c:desktop_geometry.boro12_pzt_diameter_mm}} mm discs and tones of {{c:desktop_geometry.boro12_comb_tones_hz|khz}} kHz.

**What the rest of the machine sees.** At each frequency f, the pressure p in the chamber is a fixed linear map H of the drive amplitudes u: p(f) = H(f) u(f). It is stored in a [plate-response file](digital-twin.html#the-plate-response-file). Version `body-response/0.2` adds the receive path and refuses an export sampled more coarsely than half a wavelength at the top tone. Today the map comes from a reduced thin-plate model. An in-chamber measurement of each plate will replace it.

**Why plates, and no narrow-band parts.** Plates driven in bending give a large radiating face from few wires. A resonant part can couple strongly or over a wide band, not both: the Bode–Fano limit (Documented, source not yet registered). So no single-resonance source or matching layer goes in a path that several tones must pass, and bolt-clamped Langevin horn transducers are parked.

**A printed surface against a driven one.** A printed surface delays the sound by a fixed amount at each point and shapes one chosen field ([Melde et al., 2016](https://doi.org/10.1038/nature19755), Documented). The wired sources can change at any moment, a print cannot. A printed phase lens on the chamber face is an [upgrade](upgrades.html) option (Open). Two rules for any printed or porous part:

- **Holes must be much wider than the sticky layer of air.** Friction slows the air next to a wall over a layer about 12 µm thick at 32 kHz and 5 µm at 160 kHz (Derived). Channels only a few times wider turn sound into heat.
- **A perfectly regular lattice is a filter.** Evenly repeated cells block whole bands of frequency (Documented for phononic crystals, source not yet registered).

## Known limits

None of these limits is resolved. An "earlier study" predates the rise in spacing from 120 to {{c:desktop_geometry.gap_mm}} mm and does not carry over. Solid-model results are at the present spacing.

### Control

**Control rank (Derived).** At one frequency the field is p = H·u, so N sources give at most N independent field patterns, whatever the plate does. The prototype has 12 sources and 5 tones: 60 complex amplitudes. That is the budget for every trap, every unwanted well and every correction. A target that is not a mix of the columns of H cannot be made, and the compiler reports that.

**Counting patterns across a band (Derived).** A swept drive makes one new pattern per slice of pitch the plate can tell apart (the tone divided by the plate's quality factor), up to the number of plate modes in the band: about 8 per kHz for the free glass, 1,300 below 160 kHz. Five fixed tones give 12 patterns each, 60 in all. The effective rank of H is how many of them stand clear of the noise.

**Echoes add control across a band, not for steady tones.** In a ringing space one source can focus by timing its echoes ([Draeger and Fink, 1997](https://doi.org/10.1103/PhysRevLett.79.407), Documented); see [time-reversal focusing](matter-loop.html#the-four-stage-sequence).

**Unwanted traps (Simulated).** With one tone, 10 to 17 % of the chamber is nearly as loud (above 70 %) as the target spot. The limit is 2 %. With four spots wanted at once, the weakest is usually 0.79 to 0.93 as strong as the strongest, and in the worst one case in ten only 0.53 to 0.71. The target is 0.8. This gate fails. The limit is stated on pressure; restating it on trap depth summed over tones is Open.

**Source size (Derived).** A bonded disc drives bending well only if it is smaller than half the bending wavelength: 3.9 mm at 160 kHz for the {{c:desktop_geometry.wafer_thickness_mm}} mm wafer. The Ø{{c:desktop_geometry.pzt_diameter_mm}} mm disc is several times larger. The solid model, which supersedes this rule, shows it gives more pressure per volt at every tone. Whether pattern control survives is Open.

### Drive strength and lift

**Drive strength is the limit, and the glass sets it (Simulated).** With all twelve sources phased onto one point, the Ø{{c:desktop_geometry.pzt_diameter_mm}} × {{c:desktop_geometry.pzt_thickness_mm}} mm discs give {{c:haptic_pzt.drive_authority_pa_per_volt|and}} Pa per volt at the five tones. A solid polystyrene bead needs about 0.9 to 2.0 kPa. Larger discs lower the voltage needed but not the limit: a bending wave stresses the glass by about 21 MPa for each metre per second of plate velocity (Derived). Holding solid polystyrene puts 15 to 21 MPa in the plates and 11 to 15 W of heat. The assumed design limit is {{c:desktop_geometry.plate_bending_stress_limit_mpa}} MPa, and the glass maker's characteristic strength is {{c:desktop_geometry.plate_characteristic_strength_mpa}} MPa. More sources, a stronger plate or lighter feedstock are the ways round it.

**A foam bead is the first test particle (Simulated).** A bead of 30 kg/m³ needs about one sixth of the pressure. Glass stress is then 3.7 to 5.0 MPa against the {{c:desktop_geometry.plate_bending_stress_limit_mpa}} MPa limit. The recipe is a single tone at 128 or 160 kHz on a {{c:haptic_pzt.bridge_rail_v}} V supply, which gives {{c:haptic_pzt.max_drive_v_peak_single_tone}} V at the disc. One 160 kHz tone on the full supply lifts about 1.2 times the bead's weight (1.22 in the force check) and holds 40 % of targets in three dimensions. The voltage margin is 1.19 at the median gap and 0.87 at the worst.

**One tone lifts; several tones clean (Simulated).** Driven together, the five tones share one supply. Each gets a fifth of the voltage, and the twelve sources lift only about 7 % of a foam bead's weight. The five-tone drive is still needed, at lower level, to remove unwanted traps and to listen, so a build alternates between the two. With 18 sources per plate the same model lifts about 11 times the bead's weight: a possible upgrade.

**Sound also makes wind (Documented effect, source not yet registered; Open here).** Air that absorbs sound is pushed into a slow steady flow, acoustic streaming. It drags on a held bead, and the force model leaves it out.

### The chamber as a resonator

**The gap must sit on a resonance.** The chamber is loudest when the gap is a whole number of half-wavelengths. At 160 kHz that repeats every 1.07 mm of gap (Derived). The lift changes 4.7 to 4.9 times between peak and trough (Simulated). Air carries sound about 0.17 % faster per kelvin, so the best gap moves 0.41 mm per kelvin (Derived). The gap must be held to ± 0.07 mm, which means knowing the air temperature to ± 0.15 K. The specified actuator has ± 1 mm of travel in 0.02 mm steps (Design decision). It is a requirement, not yet a part ([S05 Gap actuator and resonance lock](subsystems.html#s05-gap-actuator-and-resonance-lock)).

**The ends must reflect (Simulated).** The lift needs each end of the chamber to reflect at least 0.85 of the sound. Bare glass reflects almost everything. The flat ring round the lower wafer, 31 % of the end area, dominates the figure ([S03 Mid-plane interface](subsystems.html#s03-mid-plane-interface)).

**The glass cylinder helps modestly (Simulated).** Closing the chamber with the present cylinder ({{c:desktop_geometry.glass_cylinder_id_od_mm|x}} mm inside and outside diameter) raises the pressure by {{c:desktop_geometry.chamber_gain_closed_nominal|and}} times at the five tones for the nominal spacing, and by {{c:desktop_geometry.chamber_gain_closed_gap_median|range}} times as the median over a ±20 % range of spacing. Without it the figure is 1.01 to 1.08. The sound leaves at an angle and walks off the opposite plate.

**Air temperature (Derived).** Across the {{c:desktop_geometry.gap_mm}} mm spacing, one kelvin shifts the phase by roughly 70° at 160 kHz and 14° at 32 kHz. The warmest air inside the enclosure is estimated at 12.7 K above the room, against a 20 K limit, and the ceiling wafer runs 1.9 K warmer than the floor wafer ([Heat](desktop-replicator.html#heat)).

**Calibration goes stale quickly (Simulated).** The measured response stays valid (correlation 0.97, where 1 is a perfect match) after a {{c:desktop_geometry.air_temp_tolerance_k}} K change in air temperature or a 50 µm change in spacing. After 0.5 K it falls to 0.63, and after 200 µm to 0.65. It has to be re-measured or tracked after every head lift and every few tenths of a kelvin ([Metrology and calibration](subsystems.html#s10-metrology-and-calibration)).

**Ringing against drift (Design decision).** A part that rings long is efficient, but its sharp response moves far with a small temperature change. A machine calibrated once a session should be damped; one that tracks its own response can stay sharp.

### Timing

The ceramic disc answers in about 0.1 µs and limits nothing. The plate and its mounting take milliseconds (Open for this wafer) and set how fast one pattern can replace another (Derived).

A resonance with quality factor Q at frequency f needs about Q/f to build up, to die away, or to be told apart from its neighbour. So speed comes from using many frequencies at once.

**Ring-down bounds time-sharing (Simulated, earlier study).** Switching patterns faster than the source and plate ring down drops the held object. Sources with a quality factor near 500 dropped the bead at every switch. Sources near 50 worked, at ten times the power.

### The plate model

**The reduced plate model is contradicted by the solid model (Simulated).** Planning uses thin-plate theory with idealised sources and a rim that absorbs. A solid finite-element model of the wafer, discs and rim seal agrees on the bending wavelength to within 2.4 %. Its field does not agree with the planning file.

- **The plate rings.** The planning model lets a wave die out over about 45 mm. In the solid model the decay length is about 1.25 m.
- **The shipped plate-response file does not match.** The correlation of the two radiated fields is 0.06, chance level. Results planned from that file do not carry over.
- **The tiles are too coarse.** The file describes each plate as 96 tiles. Even the correct plate motion, cut into those tiles, matches the right sound field only to 0.21. A match of 0.95 needs tiles 6 mm apart at 32 kHz and 1.5 mm at 160 kHz.
- **The response cannot be predicted in advance.** A 0.5 % change in plate thickness drops the field correlation to 0.55. Each plate has to be measured in the chamber after assembly.
- **Control is not the limit.** All 60 drive settings remain independent on this plate.

## How a field is scored

The number of sources is not a score. These six are (Design decision; none measured yet).

| Score | Plain meaning | Aim |
|---|---|---|
| Effective rank | How many different fields the sources can really make, from the measured map H | The plate's sample budget is the ceiling |
| Spot size | Width of one commanded spot | Half a wavelength for pressure, a quarter for force |
| Fidelity | How closely a scan of the real field matches the plan | Correlation above 0.9 |
| Contrast | The wanted spot against the average clutter | Above 20 dB for one spot |
| Sites at once | How many spots hold at the stated contrast | The headline figure |
| Strength per watt | Pressure, or holding stiffness, per electrical watt | Limited by stress in the glass, not by watts |

<a id="ultimate-vs-prototype-acoustic-apertures"></a>

## Long-term direction

The long-term acoustic surface is not a plate with a few discs. [Architecture](architecture.html#long-term-architecture-and-the-desktop-replicator) compares the two, and [Ultimate Replicator](ultimate-replicator.html) gives the bounds. All of it is Open as an integrated design.

- **Light-switched surface.** A continuous piezo film carries four shared drive lines with the same tone at four timings a quarter-cycle apart. At each of about 100,000 small regions, a layer that conducts only when lit lets through as much of each line as the light there allows. Mixing the four gives any loudness and timing, so no region needs its own wire. This lifts the [control-rank limit](#known-limits). A light-addressed modulator for light is Documented ([Fan et al.](https://doi.org/10.1038/s41565-026-02128-x)). A first test would be 100 regions steering one focus.
- **Impedance matching.** A piezoceramic has an acoustic impedance near 30 MRayl and air about 415 Rayl, so only about 0.006 % of the power crosses a bare interface (Derived). This is the largest loss. Structures that taper the impedance gradually are the intended remedy.

### Handles not yet used

None of these is in the drive format or the models (Open). [Architecture](architecture.html#two-carriers-five-wavelength-decades-and-volume-crossings) lists those of both carriers.

- **Sound vortex.** A beam whose phase winds once round its axis spins a small object at its centre. Three or more sources driven in turn make one (Documented: [Marzo et al., 2015](https://doi.org/10.1038/ncomms9661)). Whether {{c:desktop_geometry.ports_per_plate}} sources behind a bending plate make a clean vortex is Open.
- **Difference tone (parametric array).** Two loud ultrasonic beams make a low tone only where they overlap (Documented textbook acoustics, source not yet registered).
- **Local spin.** Structured sound has a local turning direction that could be set point by point (Documented: [Shi et al., 2019](https://doi.org/10.1093/nsr/nwz059)).

## Open questions

- Which tones, source size, drive voltage and bead density reach a holding pressure on the Ø{{c:desktop_geometry.wafer_diameter_mm}} mm wafer, and what does the oversized disc cost at 128 and 160 kHz? (Simulation, then design)
- How is each plate's response measured in the chamber, and at what tile spacing? (Simulation and calibration design)
- At the {{c:desktop_geometry.gap_mm}} mm spacing, do 12 sources and 5 tones hold one object without unwanted wells nearby? (Simulation, then in-chamber calibration)
- How long do the wafer and the chamber ring, and how fast can patterns change? (Simulation, then in-chamber calibration)
- Which actuator holds the gap on resonance, and how wide is the empty chamber's resonance? (Design, then a one-source sweep)
- How is air temperature tracked during a job, and how often is recalibration needed? (Control design)
- What is the force on a sphere as large as the wavelength, and how much does acoustic streaming drag on it? (Simulation)
- At holding level, do the mixing products stay on the driven tones, with no cross force between tones? (Simulation, then in-chamber calibration)
- What are the plate's mode count and effective rank across 32 to 160 kHz? (Simulation)
- Does the 16-bit converter resolve the echo with five tones present? (Simulation)

Related: [Compute, sensing and control](compute-control.html), [Digital twin](digital-twin.html), [Glossary](glossary.html).
