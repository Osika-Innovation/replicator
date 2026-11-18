# Architecture

The Replicator shapes sound, light and electric or magnetic fields inside one shared work volume so that material can be arranged, joined, inspected and taken apart without tools touching it. The design software, the field models and the machine use one coordinate frame and one set of file formats. This page shows how the parts fit together and sets the long-term architecture beside the [Desktop Replicator](desktop-replicator.html), the prototype being designed first. Nothing has been built or measured.

<div class="diagram">
<svg viewBox="0 0 880 550" role="group" aria-labelledby="architecture-title architecture-desc" xmlns="http://www.w3.org/2000/svg">
<title id="architecture-title">Coordinated fields in one Replicator work volume</title>
<desc id="architecture-desc">The twin and planner command coordinated control and power for acoustic, electric and magnetic, and optical modules. All three act in one shared work volume where material is arranged, joined and inspected. Feedstock enters that volume, measurements return to the twin, and frame, metrology and utilities support the process.</desc>
<defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8" fill="#186b60"/></marker></defs>
<rect x="205" y="300" width="650" height="125" rx="12" fill="#e2ede5" stroke="#186b60" stroke-width="1.5"/>
<g fill="#f2f5ef" stroke="#186b60" stroke-width="1.5">
<a href="digital-twin.html" aria-label="Digital twin and planner"><rect x="220" y="20" width="440" height="62" rx="9"/></a>
<a href="compute-control.html" aria-label="Coordinated control and power"><rect x="250" y="110" width="380" height="54" rx="9"/></a>
<a href="acoustics.html" aria-label="Acoustic fields"><rect x="145" y="205" width="190" height="58" rx="9"/></a>
<a href="electromagnetics.html" aria-label="Electric and magnetic fields"><rect x="355" y="205" width="190" height="58" rx="9"/></a>
<a href="optics.html" aria-label="Optical fields"><rect x="565" y="205" width="190" height="58" rx="9"/></a>
<a href="matter-loop.html" aria-label="Feedstock"><rect x="20" y="345" width="165" height="60" rx="9"/></a>
<a href="manufacturing.html" aria-label="Arrange and orient material"><rect x="220" y="345" width="190" height="60" rx="9"/></a>
<a href="manufacturing.html" aria-label="Join and transform material"><rect x="435" y="345" width="190" height="60" rx="9"/></a>
<a href="matter-loop.html" aria-label="Observe and recover material"><rect x="650" y="345" width="190" height="60" rx="9"/></a>
<a href="architecture.html#interfaces-that-survive-upgrades" aria-label="Frame, metrology and utilities"><rect x="220" y="475" width="635" height="58" rx="9"/></a>
</g>
<g pointer-events="none" fill="#173630" font-family="system-ui,sans-serif" text-anchor="middle" font-size="17">
<text x="440" y="47">Digital twin + planner</text><text x="440" y="69" font-size="13">CAD · field models · pattern network · upgrade graph</text>
<text x="440" y="143">Coordinated control, clock and power</text>
<text x="240" y="240">Acoustic fields</text><text x="450" y="240">Electric + magnetic</text><text x="660" y="240">Optical fields</text>
<text x="530" y="326" font-size="16" font-weight="600">ONE SHARED 3D WORK VOLUME</text>
<text x="102" y="370">Feedstock</text><text x="102" y="392" font-size="13">powder · liquid · seed</text>
<text x="315" y="370">Arrange + orient</text><text x="315" y="392" font-size="13">acoustic traps</text>
<text x="530" y="370">Join + transform</text><text x="530" y="392" font-size="13">consolidate · soften</text>
<text x="745" y="370">Observe + recover</text><text x="745" y="392" font-size="13">scan · sense · reclaim</text>
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

The four process stages share one volume. A recipe can overlap them or run them in sequence. The diagram does not imply separate stations, and it does not imply that every field is on all the time. The Desktop Replicator implements the acoustic column and optical sensing only.

## One work volume, coordinated fields

Each field is given the job its physics suits.

- **Sound** applies force. Acoustic radiation pressure holds and moves feedstock at millimetre scale. See [Acoustics](acoustics.html).
- **Light** measures, and in the long-term design addresses fine detail: wavefront readout, curing exposure and sub-micrometre trapping. See [Optics](optics.html).
- **Electric and magnetic fields** act selectively on conducting or magnetic material: force, torque or local heating. See [Electromagnetics](electromagnetics.html).

Optics is electromagnetic physics; the two modules are named separately because their frequency bands and hardware differ. The fields share a coordinate frame and a time base. Sound and light are not phase-locked to each other unless a measurement deliberately locks them.

## Two carriers, five wavelength decades and volume crossings

Sound is the better carrier of force and light is the better carrier of information. Both follow from their speeds: 3 × 10⁸ m/s for light, about 343 m/s for sound in air and about 5,000 m/s in solids.

**Force per watt (Derived).** A wave of power P that is fully absorbed pushes with a force P divided by its speed. One watt of light gives 3.3 nN. One watt of sound in air gives 2.9 mN, close to a million times more.

**Wavelength (Derived).** At the same frequency, sound has a wavelength about a million times shorter than light, so ordinary electronics at kilohertz to megahertz frequencies produce millimetre-scale acoustic features.

| Frequency | Light | Sound in air | Sound in a solid | What it means for the machine |
|---|---|---|---|---|
| 1 kHz | 300 km | 343 mm | 5 m | Room-scale acoustic modes |
| 100 kHz | 3 km | 3.4 mm | 50 mm | The prototype's band: millimetre features in air |
| 1 MHz | 300 m | 0.34 mm | 5 mm | Sub-millimetre features in gas or melt |
| 1 GHz | 300 mm | 0.34 µm | 5 µm | Sound in solids nears optical wavelengths; acousto-optic devices work here and above |

**Degrees of freedom (Derived).** Light has two polarisation states and can carry orbital angular momentum. Sound in a fluid has one wave type, longitudinal. In a solid it has three, plus surface and plate waves whose speed can be engineered. When sound and light interact, energy, momentum and angular momentum are each conserved.

### Cross-carrier verbs inside the work volume

Sound and light also act on each other inside the gas or melt. These interactions address, trim and cross-check. They never move bulk power from one carrier to the other.

| Interaction | Mechanism | Use in the machine | Evidence |
|---|---|---|---|
| Light reads sound | Pressure changes the refractive index of air, which shifts the phase of a beam passing through | Optical measurement of the real sound field, independent of the acoustic sensors | Documented effect; in-chamber performance Open |
| Sound trims light | A sound field acts as a weak, fast, graded-index lens | Fine steering in air; real beam shaping needs a liquid or melt at high pressure | Documented in acousto-optic modulators; melt shaping Open |
| Light writes sound | Patterned light absorbed on a surface heats it and launches sound | A reprogrammable sound source on any lit surface, with no moving parts | Documented effect; in-chamber use Open |
| Phonon to photon | Coherent coupling in optomechanical cavities | Signal hand-over inside solid interfaces | Documented components; integration Open |

**Worked number for "light reads sound" (Derived).** For the prototype's {{c:mosquito_smi.laser_wavelength_nm}} nm lasers the phase shift is {{c:mosquito_smi.lightread_coef_rad_per_pa_m}} radians per pascal per metre of path. A beam that crosses 100 mm of sound field at a pressure amplitude of 1 kPa, in phase along the whole path, shifts by 1.9 radians, or 0.3 of a wave, in a single pass. The return pass to the laser doubles it. This is an upper bound: the acoustic wavelength at the prototype's tones is 11 to 2 mm, so a real beam crosses many pressure maxima and minima that partly cancel. The figure of 1.38 waves at 155 dB quoted in earlier material assumed 500 nm light and a uniform 300 mm path, longer than any path in the Desktop Replicator.

For "sound trims light", water at equal pressure changes its refractive index less than air does (about 5 × 10⁻⁷ against 7 × 10⁻⁶ at 3.5 kPa), because it is far stiffer. Liquids help only because they tolerate much higher pressures.

## Long-term architecture and the Desktop Replicator

This is the handbook's single comparison of where the programme is going and what is being designed first. The prototype column is a design: nothing has been ordered, built or measured. The long-term column is a research direction; its integration is Open throughout.

| Subsystem | Long-term architecture | Desktop Replicator prototype | Chapter |
|---|---|---|---|
| Work volume | One tool-free volume with fields from all sides, plus a separate storage chamber for sorting and reclaim | One open chamber, {{c:desktop_geometry.gap_mm}} mm between two plates, crucibles inside | [Desktop Replicator](desktop-replicator.html) |
| Acoustic sources | Continuous piezo film with about 100,000 optically switched elements and no per-element wiring | Two undrilled Ø{{c:desktop_geometry.wafer_diameter_mm}} mm glass wafers, {{c:desktop_geometry.ports_per_plate}} bonded piezo discs each, five tones | [Acoustics](acoustics.html) |
| Acoustic sensing | The same surface read out optically | The same 12 discs sense on their drive wires through 1-bit converters | [Acoustics](acoustics.html) |
| Optics | Optically addressed surfaces, structured pulses, tomography and fine optical traps | {{c:mosquito_smi.total_ommatidia}} self-mixing laser diodes at {{c:mosquito_smi.laser_wavelength_nm}} nm, for sensing only | [Optics](optics.html) |
| Electric and magnetic fields | Compact pulsed coils and field shaping near the material (Open) | None by default; an optional conductor spiral on the glass and a candidate crucible coil | [Electromagnetics](electromagnetics.html) |
| Control electronics | Wave-based computing in optical or excitable soft-matter wave substrates, using little electrical power | Microcontrollers on {{c:clock_and_bus.pcb_count}} circuit boards plus a plug-in compute card, on one {{c:clock_and_bus.xin_hz|mhz}} MHz clock | [Compute, sensing and control](compute-control.html) |
| Pattern network | The network's settling carried out by a physical wave medium | Cadence network under {{c:cadence_brain.cadence_sparse_max_kb}} kB on the compute card, trained on a workstation | [Cadence, memory and wave compute](cadence-memory.html) |
| Feedstock and recovery | Storage chamber with acoustic sorting and closed reclaim of material | Open crucibles for powder, liquid and seed parts; removal of joined material Open | [Scan, recover and matter stores](matter-loop.html) |
| Calibration | Full-aperture acoustic and optical scattering measurement with reference objects | In the assembled chamber, with removable Ø1 to 2 mm spheres; no separate test rigs | [Desktop Replicator](desktop-replicator.html) |
| Digital twin | The same twin plans upgrades that the machine makes for itself | CAD, plate model and design checks; a solid finite-element check is in progress | [Digital twin](digital-twin.html) |
| First milestone | The machine makes precise parts of its successor | Repeatable hold, move and release of one bead, calibrated in the chamber | [Upgrade loop](upgrades.html) |

The prototype electronics are purchasable scaffolding, not a small version of the long-term design. Earlier baselines that this prototype replaced are tabulated once, in [Desktop Replicator](desktop-replicator.html#what-this-design-replaced).

## Interfaces that survive upgrades

A module can be replaced without redesigning the machine because what crosses each interface is fixed. Every module declares its identity and revision, its position in the shared coordinate frame, its signal, power and optical ports with their limits, and whether its response data is a made-up reference, simulated or measured. Three interfaces carry most of the weight.

**Acoustic body response.** A pair of plates and their sources is described by one file in the `body-response/0.1` format. It gives, for each frequency, how each drive input moves each small patch of the radiating faces, with stated uncertainty. The planner sees only this file. The two current presets are `desktop-200mm` (the Ø{{c:desktop_geometry.wafer_diameter_mm}} mm wafers) and `boro12` (Ø{{c:desktop_geometry.boro12_reducer_wafer_mm}} mm wafers). Swapping one for the other, or for a future optically addressed surface, changes the module and its file and nothing else.

**Compute card.** The pattern network runs on a plug-in card: first a microcontroller, optionally a field-programmable gate array, later an optical core. The socket stays the same.

**Machine commands.** The planner sends the same command stream (`.fcode`) and stores drive patterns in the same compact format (`.pattern`) whether the receiver is the simulated machine or hardware.

The frame supplies the shared reference surfaces, access, cooling and protection that these modules mount to.

[Manufacturing](manufacturing.html) covers the process and [Digital twin](digital-twin.html) the tooling. Terms are defined in the [Glossary](glossary.html).
