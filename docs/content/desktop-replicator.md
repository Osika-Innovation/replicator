# Desktop Replicator

The Desktop Replicator is the machine we are designing to build first. It is a benchtop chamber, about the size of an espresso machine, in which two vibrating glass plates hold and move small amounts of material in mid-air while a ring of low-power lasers watches. Everything on this page is a design: **no parts have been ordered, nothing has been built and nothing has been measured.**

<div class="diagram">
<img src="../assets/desktop/desktop_iso.jpg" alt="CAD render of the Desktop Replicator. A rounded-square base and head are joined by a rear tower; between them is an open chamber with a round glass plate at the floor, a dark rear baffle and small crucibles at the back." width="1200" height="900">
<p>CAD render. The round plate on the chamber floor is the lower acoustic wafer; an identical one faces it from the head. The crucibles at the rear hold feedstock. This is a model, not a photograph.</p>
</div>

## At a glance

| | Value | Evidence |
|---|---|---|
| Outside size | {{c:desktop_geometry.envelope_mm|x}} mm | Derived from the CAD model |
| Mass | {{c:desktop_geometry.nominal_mass_kg}} kg nominal | Derived from model densities |
| Work chamber | One chamber, {{c:desktop_geometry.gap_mm}} mm between the plates, no holes in floor or ceiling, open at the front and sides | Design decision |
| Acoustic plates | Two undrilled Ø{{c:desktop_geometry.wafer_diameter_mm}} × {{c:desktop_geometry.wafer_thickness_mm}} mm borosilicate wafers ({{c:desktop_geometry.wafer_material}}), Ø{{c:desktop_geometry.clear_glass_diameter_mm}} mm free to vibrate | Design decision |
| Sound sources | {{c:desktop_geometry.ports_per_plate}} small piezo discs (PZT-8, Ø{{c:desktop_geometry.pzt_diameter_mm}} × {{c:desktop_geometry.pzt_thickness_mm}} mm) bonded behind each wafer, 12 in total | Design decision |
| Drive tones | {{c:desktop_geometry.comb_tones_hz|khz}} kHz, used together | Design decision |
| Acoustic sensing | The same 12 piezo discs listen while they drive; each is read by a 1-bit converter at {{c:haptic_pzt.sigma_delta_fs_hz|mhz}} million samples per second | Derived; simulation gate open |
| Optical sensing | {{c:mosquito_smi.total_ommatidia}} laser diodes at {{c:mosquito_smi.laser_wavelength_nm}} nm that each double as their own detector | Derived; simulation gate open |
| Electronics | {{c:clock_and_bus.pcb_count}} circuit boards and one plug-in compute card | Design decision |
| Controller memory | Under {{c:cadence_brain.cadence_sparse_max_kb}} kB for the on-board pattern network | Design target |
| Electrical power | 4.7 W with the first compute card, 10.2 W design ceiling | Derived from assumed datasheet values |
| Feedstock | Open crucibles for powder, liquid and seed parts, inside the chamber | Design decision |
| Hardware built | None | — |

A smaller configuration, called `boro12`, fits Ø{{c:desktop_geometry.boro12_reducer_wafer_mm}} mm wafers {{c:desktop_geometry.boro12_gap_mm}} mm apart into the same frame. It uses tones of {{c:desktop_geometry.boro12_comb_tones_hz|khz}} kHz and exists so that the first experiments can run on a small, cheap pair of plates.

## How it works

**Two plates make the field.** Each wafer is clamped only at its rim in a soft silicone ring. Six piezo discs glued to its back face set the whole plate ringing. Because bending waves travel through glass at a speed that depends on frequency, a handful of drive points and five tones produce a rich pattern of motion across the plate, and that pattern radiates ultrasound into the chamber. Two such plates facing each other create standing pressure patterns with quiet pockets where a small bead or droplet is held. Changing the amplitude and timing of the twelve drive signals moves the pockets. The physics of that force is in [Acoustics](acoustics.html).

**The plates also listen.** The piezo disc that pushes on the glass is pushed back by it. The electronics measure that reaction on the same two wires while driving, so every source is also a microphone and no separate listening interval is needed. Objects in the chamber change what comes back, which is how the machine senses what it is holding.

**A ring of lasers watches.** The {{c:mosquito_smi.total_ommatidia}} small laser diodes look across the chamber from two strips beside the rear tower. Each beam crosses the work volume, hits a reflective strip on a post at the far side and returns into the laser it came from. Returned light disturbs the laser slightly, and a photodiode built into the laser package picks that up. A bead that blocks the beam shows up as a steady drop in signal. Sound passing through the beam shows up as a ripple, because pressure changes the refractive index of air. One cheap part therefore gives both a shadow image of the object and an independent optical measurement of the sound field. This is called self-mixing interferometry (SMI).

**One clock keeps everything in step.** A single {{c:clock_and_bus.xin_hz|mhz}} MHz oscillator feeds every controller through matched traces, and one shared signal marks the start of each frame. The design allows at most {{c:clock_and_bus.sync_skew_max_ns}} ns of timing difference between boards, so the twelve drive signals and all the sensor readings share a time base.

**A small network picks the drive pattern.** A plug-in card holds a compact pattern-completion network called Cadence. Given the sensed state and a target, it settles on a set of drive amplitudes and phases in {{c:cadence_brain.rp2350_settle_target_ms_range|range}} ms. It is trained on a workstation and copied to the card. See [Cadence, memory and wave compute](cadence-memory.html).

<div class="diagram">
<img src="../assets/desktop/desktop_section.jpg" alt="Vertical section through the Desktop Replicator. A wafer and circuit board sit in the head, a matching wafer and board sit above the base electronics, and the open chamber lies between them with the rear tower on the left." width="1200" height="900">
<p>Section through the centre. Top and bottom: wafer, piezo discs and the board that drives them. Bottom: backplane, power and compute card. Left: the hollow tower that carries the head, the laser strips, the cabling and the cooling air.</p>
</div>

## The enclosure

The body is a rounded-square base and head joined by a hollow rear tower. The tower is one structural part that carries the head, covers the laser strips and acts as a duct.

- **Open chamber.** The current default has no glass wall. A matte black baffle closes the rear third of the chamber and carries the crucible tray; two slim posts at the front carry the laser reflector strips and leave a {{c:desktop_geometry.retro_post_opening_chord_mm}} mm opening between them. An open chamber is easy to load and to watch, but it has no shield against room draughts and no enclosure around the laser beams. Both need an answer before the machine runs outside a controlled bench.
- **Optional glass.** The model keeps a glass option: a curved door that rotates {{c:desktop_geometry.door_half_sweep_deg}}° to either side behind a fixed glass arc. With glass fitted the reflector strips sit on the door, so optical scanning requires the door closed.
- **Cooling.** Air enters through louvres beside the power supply, rises through the tower and leaves through louvres in the head. No cooling air passes through the work chamber, where it would disturb levitated material.
- **Service.** A side hatch reaches the compute card. Power and USB-C are on the rear panel. A small display and a rotary knob are on the head.

The model passes its geometric checks (closed solids, clearances, no interference between parts, agreement between the mesh and the exact CAD geometry). Those checks establish that the model is self-consistent. They do not establish that the machine works.

## Electronics

There are three field circuit boards. Two are identical and sit directly behind the wafers. The third is the backplane in the base.

| Board | What is on it |
|---|---|
| Head board, two identical (Ø172 mm) | One RP2350B microcontroller, six drive stages (TC4427A), receive protection (BAT54S), seven fast comparators (TLV3501) and one spare piezo disc that touches nothing |
| Backplane (Ø188 mm) | The 12 MHz clock and its distribution, power conversion from USB-C, rear connectors and the socket for the compute card |
| Compute card (M.2 form factor) | Card 1: an RP2350B running Cadence. Card 2: an optional FPGA module. Card 3 is reserved for an optical core |

**Why the electronics sit behind the wafer.** A piezo disc of this size has a capacitance of about {{c:haptic_pzt.c0_nominal_pf}} pF. A cable to a remote amplifier would add far more capacitance than that and swamp the small received signal. Placing the controller within millimetres keeps the added capacitance under {{c:haptic_pzt.max_trace_cap_pf}} pF.

**Why a 1-bit converter.** The signals of interest lie below {{c:haptic_pzt.ultrasonic_bw_hz|khz}} kHz. Sampling one bit at {{c:haptic_pzt.sigma_delta_fs_hz|mhz}} MHz is {{c:haptic_pzt.osr}} times faster than the minimum rate, and averaging that fast stream recovers a precise value. A comparator and a microcontroller pin then replace a multi-channel precision converter. The estimated resolution is {{c:haptic_pzt.enob_range|range}} bits. The 1-bit path is accepted only if a bit-exact simulation with several tones present shows at least {{c:haptic_pzt.sfdr_gate_min_db}} dB between the wanted signals and the largest spurious product. If it does not, the board is populated with a conventional converter ({{c:haptic_pzt.adc_fallback_mpn}}) on footprints that are already there. A simulation on 18 November 2026 reached about 61 dB, so the test fails and the fallback applies ([Compute, sensing and control](compute-control.html)).

**Why a spare piezo disc.** The capacitance of the ceramic drifts by about {{c:haptic_pzt.c0_tempco_pct_per_c}} % per degree. A disc that is not attached to the plate drifts the same way but hears nothing, so subtracting its signal removes the drift.

All part numbers are candidates. Their electrical values were entered from memory of typical datasheet figures and must be re-read from current datasheets before the design is frozen. Stock and price have not been checked with any supplier.

## Heat

With the first compute card the whole machine dissipates an estimated 4.7 W, of which the {{c:mosquito_smi.total_ommatidia}} lasers account for 2.0 W. The estimated rise of the internal air is 5 K. This is a single-node estimate from assumed values, not a flow simulation.

One thermal rule follows from the physics of the chamber and constrains the layout: **the chamber floor must not be warmer than its ceiling.** Air heated from below overturns. For a chamber {{c:desktop_geometry.gap_mm}} mm tall the estimate is that a floor warmer than the ceiling by a few thousandths of a kelvin is enough to start that motion, and moving air drags on anything levitated in it. The base holds most of the electronics, so the default arrangement is the unstable one. The stable arrangement is a ceiling slightly warmer than the floor. How fast the air would move, and whether that drag matters next to the acoustic holding force, has not yet been calculated.

## Material in and out

Feedstock sits in three open crucibles on a tray at the back of the chamber, held just clear of the lower wafer by an arm from the rear baffle: one for powder, one for liquid and one for seed parts. The intended cycle is that the machine locates material in a crucible, lifts it acoustically, carries it to the build position and joins it there, and that unwanted material is carried back to a crucible. Nothing leaves the chamber through pipes or vials.

Three points about this cycle are open and should be read as such:

1. **Joining.** An earlier plan bonded beads with ultraviolet-curing adhesive applied by hand. That plan is retired. The replacement is to consolidate material with the fields themselves (acoustic pressure, heat, phase change). No specific joining recipe has been simulated end to end.
2. **Taking material away.** Releasing loose material is straightforward. Removing material that has already been joined requires breaking bonds, which reversing a holding pattern does not do. The planned approach and the errors it corrects are described in [Scan, recover and matter stores](matter-loop.html).
3. **Mass accounting.** The design goal is that the mass in the part plus the mass in the crucibles stays constant through a build. No simulation yet tracks that.

## What gets checked before anything is bought

There are no disposable test rigs in this plan. The front-end electronics, the plate response and the optical readout are checked in simulation against the full chamber. The assembled machine is then calibrated in place with removable Ø1 to 2 mm spheres and the crucibles themselves.

Hardware may be released for purchase only when all five of these exist:

1. A frozen revision of the design with file hashes.
2. A bill of materials with quantities, part numbers, live stock and prices.
3. Exact CAD geometry, drawings, tolerances, wiring and a thermal budget.
4. Passed simulation gates: the {{c:haptic_pzt.sfdr_gate_min_db}} dB converter test above, and a three-dimensional solid finite-element model of the wafer, piezo discs and rim seal that agrees with the plate model used for planning. Both currently fail: the converter test above, and the model comparison, which also shows that the drive is far too weak to hold a solid bead ([Acoustic bodies](acoustics.html#known-limits)).
5. A fixed acceptance procedure to run in the chamber once built.

Ordering parts or contacting suppliers also requires explicit approval from the operator.

## Optional and experimental features

**Spiral launcher.** Because the wafers have no holes, a thin conductor pattern can sit directly on the glass. The model can add a twelve-arm spiral of copper or indium tin oxide, about {{c:dissolve_and_toroidal.borofloat_chiral_spiral_trace_thickness_um}} µm thick and fed from the rim, intended to launch short doughnut-shaped electromagnetic pulses. It is off by default. Whether it produces a useful pulse in this chamber is an open question for simulation.

**Small pulsed coil at a crucible.** Earlier studies showed that large coils acting across the whole chamber produce negligible force. A compact ring coil of {{c:dissolve_and_toroidal.compact_toroid_collar_id_mm_range|range}} mm around a single crucible is a different case, because a rapidly changing current induces an electric field along its axis while the magnetic field stays inside the ring. It is a candidate for softening or breaking down material during recovery. It is not in the CAD model. See [Electromagnetic control](electromagnetics.html).

## What this design replaced

| Earlier baseline | Status | Why it was retired |
|---|---|---|
| P0: a 4 × 4 array of 40 kHz ultrasonic transducers | Historic. Kept only as a software regression case | A separate rig that taught nothing about plate acoustics or self-sensing |
| HA-0 Rev C: Ø150 mm wafers drilled for a Ø12 mm central pipe, with single-purpose test coupons | Historic | The hole weakened the glass and removed the most useful part of the aperture. Coupons cost bench time and were then discarded |
| Hand-applied UV adhesive joining | Historic | Needed a person inside the loop for every joint |
| Bolt-clamped high-Q horn transducers and a fixed 20 ms frame clock | Parked | Narrow-band sources cannot play several tones at once or listen while driving |

## Prototype, not destination

The microcontrollers, comparators and discrete lasers above are purchasable scaffolding for a first machine. They are not the architecture the programme is aiming at. The long-term design replaces the twelve wired sources with a continuously addressable surface of roughly 100,000 optically switched elements and replaces the digital controller with wave-based computing that needs little electrical power. [Architecture](architecture.html) sets the two side by side.

## Open questions

| Question | Who answers it |
|---|---|
| Does the receive path meet {{c:haptic_pzt.sfdr_gate_min_db}} dB with the fallback converter? | Electrical design and simulation |
| What drive voltage, tones, source size and bead density reach a holding pressure on the Ø{{c:desktop_geometry.wafer_diameter_mm}} mm wafer? | Simulation, then design |
| How does the field change at the new {{c:desktop_geometry.gap_mm}} mm plate spacing? Results for the earlier 120 mm spacing do not carry over | Simulation |
| What protects an open chamber from draughts, and what encloses the laser beams? | Enclosure design |
| How large is the buoyant air motion for a given floor-to-ceiling temperature difference? | Simulation |
| Does the laser amplifier pass the highest drive tone? A single stage with a gain of 200 would roll off at about 100 kHz | Circuit design |
| What joins material without adhesive, and what removes joined material? | Process simulation |
| Which vendors can supply the custom piezo discs and at what tolerance? | Procurement, after approval |

## Where the design lives

The parametric model, bill of materials, drawings and exported geometry are generated by the digital twin (`fieldc desktop` commands) and stored under `cad/desktop-replicator/` in the working repository. Numbers shared between firmware, simulation and CAD are held in one constants file so that they cannot drift apart. [Digital twin](digital-twin.html) describes the tooling and [Insight register](insights.html) lists the findings that shaped this design and how far each has been carried into code.
