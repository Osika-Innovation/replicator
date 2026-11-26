# Desktop Replicator

The Desktop Replicator is the machine we are designing to build first. It is a benchtop tower of two glass cylinders, one on top of the other. Sound shapes material inside them, and light locks the shape. Every figure carries an [evidence label](status.html#evidence-labels). The current default is called Rev S, the unified cylindrical two-zone stack. Everything here is drawn and calculated. Nothing on this page is a bench measurement.

<div class="callout note"><strong>See it in 3D.</strong> <a href="cad-3d.html">Open the model</a>, pull it apart and click its parts. Sizes and masses on this page are derived from that CAD model.</div>

## At a glance

| | Value | Evidence |
|---|---|---|
| Outside size | 379 × 294 × 644 mm closed, 909 mm with the head raised (the head rises 265 mm) | Derived from the CAD model |
| Mass | {{c:desktop_geometry.nominal_mass_kg}} kg. Of that, {{c:desktop_geometry.lift_moving_mass_kg}} kg rises with the head | Derived from model densities; the removed brake's 0.14 kg is assumed |
| Head lift | Motor-driven. A servo turns two belt-linked ball screws and lifts the head 265 mm in 2.5 s from the touchscreen. There is no brake. During a job the head rests on two hard stops with the servo off, so holding costs 0 W. If power fails with the head up, shorted motor windings let it sink at about 55 mm/s onto the stops | Design decision; motion times Derived, parts not chosen |
| Two zones | A build zone on top and a storage zone below, each {{c:desktop_geometry.gap_mm}} mm tall, with a mid-plane cassette between them | Design decision |
| Storage zone | A fixed, waterproof [DURAN](glossary.html) glass cylinder, Ø250 × 5 mm, about 10.0 L | Design decision; volume Derived from CAD |
| Build zone | A stock glass cylinder of the same size. It lifts with the head and closes the top | Design decision |
| Mid-plane | A drop-in cassette. Default M1: a sealed, undrilled Ø200 mm wafer inside a hard flat ring, with one 12 mm round transfer port (0.25 % of the end area). Test version M2: a mesh plate that does not levitate | Design decision |
| Acoustic plates | Three driven stacks. Each is an undrilled borosilicate [wafer](glossary.html) ({{c:desktop_geometry.wafer_material}}) with [piezo](glossary.html) discs (PZT-8, Ø{{c:desktop_geometry.pzt_diameter_mm}} × {{c:desktop_geometry.pzt_thickness_mm}} mm) bonded behind it | Design decision |
| Drive tones | {{c:desktop_geometry.comb_tones_hz|khz}} kHz. One tone lifts. The set of five senses and shapes | Design decision |
| Acoustic sensing | The piezo discs listen while they drive. A 16-bit converter ({{c:haptic_pzt.adc_fallback_mpn}}) reads them, because the 1-bit converter failed its simulated test | Simulated |
| Optical sensing | {{c:mosquito_smi.total_ommatidia}} laser diodes at {{c:mosquito_smi.laser_wavelength_nm}} nm that each double as their own detector. Their windows are in six flat panels inside the glass | Simulated |
| Screen | A 7-inch touchscreen on a 45° console wedge at the front of the base. The module is assumed, not chosen | Design decision; module Open |
| Electrical power | 23.8 W with the first compute card, 29.3 W with the second, every plate driven with its worst pattern | Derived from candidate-part datasheets |
| Controller memory | Under {{c:cadence_brain.cadence_sparse_max_kb}} kB for the on-board pattern network | Design target |
| Feedstock | Held in the storage zone, in a fluid that matches the material's density (see [Material in and out](#material-in-and-out)) | Design decision; fluid-loaded simulation Open |

A smaller configuration, called `boro12`, fits Ø{{c:desktop_geometry.boro12_reducer_wafer_mm}} mm wafers {{c:desktop_geometry.boro12_gap_mm}} mm apart. It uses tones of {{c:desktop_geometry.boro12_comb_tones_hz|khz}} kHz, so first experiments can run on a small, cheap pair of plates.

## How it works

**Sound shapes the whole volume at once.** The machine is not meant to pick up single dry foam beads one at a time. Sound makes a three-dimensional landscape of pressure. Material settles into its low points everywhere in the chamber together. Sound is a strong tool for this: per watt it carries about 2 × 10⁵ to 9 × 10⁵ times more force than light, 2.9 mN/W in air and 0.68 mN/W in water against 3.3 nN/W for light (Derived). The physics is in [Acoustics](acoustics.html).

**Light locks the shape.** Patterned light, sent through the six panels or the clear cylinder, can harden the held material in one shot. A published result did this in 0.6 s with 19 µm detail (Wang et al., Nature 2026; Documented outside result). This project has not run it. Joining by light in this chamber is Open ([Manufacturing](manufacturing.html#consolidation)).

**The plates make the field.** Each wafer is held only at its rim. Piezo discs on its back make the whole plate ring, and the plate sends ultrasound into the chamber. Facing plates make standing pressure patterns. Changing the strength and timing of the drive signals moves the pattern.

**The plates also listen.** The piezo disc that pushes on the glass is pushed back by it. The electronics measure that push-back on the same two wires while driving, so every source is also a microphone. Objects in the chamber change what comes back.

**Why the mid-plane is sealed.** The middle of the stack has to pass sound, not leak it. In simulation, a sealed cassette M1 lifts a foam bead with 2.37 times its weight at 12 ports and 1.93 times at 36 ports, with the bead at 0.90 of the radius. A retracted or mesh-only mid-plane reaches only 0.17 to 0.74 times (Simulated, dry-air bead, end models assumed). The 12 mm round port is small so that it disturbs the field little.

**Lasers watch.** {{c:mosquito_smi.total_ommatidia}} small laser diodes look across the build zone. Each beam crosses the work volume, hits a reflective strip at the far side and returns into its own laser, where a built-in photodiode picks up the disturbance. A bead that blocks the beam shows as a steady drop. Sound crossing the beam shows as a ripple. One cheap part gives a shadow image and a measurement of the sound field. This is [self-mixing interferometry](optics.html#coherent-self-mixing-optical-readout).

**One clock keeps everything in step.** A single {{c:clock_and_bus.xin_hz|mhz}} MHz oscillator feeds every controller through matched traces. Boards may differ by at most {{c:clock_and_bus.sync_skew_max_ns}} ns.

**A small network picks the drive pattern.** A plug-in card holds Prime, the project's model built on the Cadence library. Given the sensed state and a target, it settles on a set of drive strengths and timings. The settle target is {{c:cadence_brain.rp2350_settle_target_ms_range|range}} ms (Design target). Instruction counts give 4.4 to 6.1 ms (Derived). It is trained on a workstation and copied to the card ([Cadence, memory and wave compute](cadence-memory.html)).

**A gap check before anything else.** Bench Gate 0 is a one-port sweep from 156 to 164 kHz. It reports the echo ratio, the second echo over the first: 0.466 at radius 0.85 and 0.523 at 0.90 (Simulated). On a built machine this would show whether the real gap rings like the model. The same sweep is also a leak check on the cassette. If the reflection falls below 0.50, the firmware reports a flood, switches the drive off and refuses to start a matter drive or the pump until a later sweep passes (Simulated: workstation-tested, not on a board; the threshold rests on simulation, see [Crystals](crystals.html#bench-gate-0-can-tell-you-if-the-cassette-leaks)).

## The enclosure

The machine is one clear glass tube standing on another. A hollow rear tower, with its louvres at the back, carries the head and acts as a duct. The front of the body is a half cylinder of radius 147 mm, concentric with the glass.

- **Storage glass.** The bottom cylinder is fixed and waterproof. Stack 1 is a plug in its floor. Two radial O-rings seal the plug. It stands on three PEEK feet and puts no load on the glass ends (Design decision).
- **Build glass.** The top cylinder is a stock glass cylinder of the same size. It runs 25 mm into the head and lifts with it. It shields material from room draughts. In simulation it raises the sound pressure by {{c:desktop_geometry.chamber_gain_closed_gap_median|range}} times over an open chamber (Simulated, for the single-chamber layout). Stack 3 is the same plug as Stack 1, in the top of this glass. A drum and three arms hang it from the head, so the head sets the gap, not the glass.
- **Rim ring.** A ring on the storage glass holds three balls and 12 spring contacts. The cassette drops onto the balls and a person lifts it out by hand once the motor has raised the head.
- **Gap and temperature drift.** The gap is fixed. During a job the two nut arms rest on two hardened stops at {{c:desktop_geometry.gap_mm}} mm, held down by the head's own weight (about 62 N), with the servo off (Design decision; weight Derived). The earlier plan to trim the gap by ±1 mm with the servo is dropped. Temperature drift is followed by the drive instead. Sound travels about 0.17 % faster per kelvin, and the gap stays the same, so every tone's timing ring is shortened or lengthened together. The ring is 18,750 steps of a 150 MHz clock. Two steps shift all five tones by 107 parts per million, which is the effect of 0.063 K, and the ring can move ±136 steps, enough for ±3 K of air plus the seat error below (Derived; the simulation team's task #119). The head lands within about ±0.5 mm of 240.00 mm (proposed, to be measured). That is worth ±1.22 K of air, so ±3 K plus the seat needs 135 of the 136 steps, almost none spare. A wider seat would need a wider ring. The three stepper motors and three ball-in-vee seats of the earlier Rev S build are gone.
- **Six rear panels.** Flat aluminium panels, 57 × 2.5 mm, line the rear half of both cylinders on the inside, 108.5 mm from the axis. They carry the laser windows, two TMP117 temperature sensors, a humidity sensor and passive sound baffles. They are ready for active tiles later. In the build zone they hang from Stack 3 and rise with the head. In the storage zone they stand on Stack 1.
- **Static charge.** A foam bead that rubs glass picks up charge. At about {{c:electrostatics_and_matter_loop.eps_r0p5mm_image_clamp_1g_pc}} pC a 1 mm bead sticks to the glass with a force equal to its weight. Plates and cylinders need a slightly conductive, grounded surface. The chamber air needs a relative humidity of {{c:electrostatics_and_matter_loop.chamber_ambient_rh_pct_range|range}} %. That keeps the charge under {{c:electrostatics_and_matter_loop.max_bead_charge_pc}} pC (Derived). No surface treatment has been chosen.
- **One coating, three possible jobs (Open).** A clear, slightly conductive, grounded coating would bleed away static charge and keep radio-frequency fields inside. Cut into driven patches, it would later turn a passive wall into a controlled one ([what more wall buys](architecture.html#what-more-wall-buys)). The lasers must still see through it.
- **Lifting head.** The lift is electric. Two fixed corner pieces stand on the base. Each holds a 12 mm ball screw (10 mm lead), two guide carriages, and, in the left one, a brushless servo with no brake. Belts in the base turn the screws together. The centre spine rides with the head on a rail each side, and an arm at its foot carries the nut on each screw through a slot in the corner piece. Moving mass is {{c:desktop_geometry.lift_moving_mass_kg}} kg. The full 265 mm stroke takes 2.5 s at 132 mm/s peak, and the servo needs about 0.09 N·m against a 0.32 N·m class (Derived; parts assumed, none chosen). It draws about 25 W during a move. The head moves only from the touchscreen, with hold-to-run to close. Motor current is limited so the closing force stays under 75 N, and the last 20 mm is slow. Optical home and top-limit sensors, and a separate head-down switch, report the position. The tip angle is 17° head down and 13° raised (Derived from CAD). The upper plate moves with the head, so calibration is repeated after every opening. **Power loss.** The ball screws are not self-locking, so a raised head with no power would fall freely if the motor windings were open. The windings must be shorted when power is lost, either inside the servo or by a normally closed relay. Then the head sinks at about 55 mm/s, and a trapped hand feels about 62 N, under the 75 N pinch limit. This is required, and the part is not chosen (Derived; motor constants assumed). **Liquid seal.** The stops set the squeeze of the gasket, so it must be an extra-soft foam. About 41 N at 10 kPa is assumed, which leaves about 20 N on the stops, and at least 15 N is needed. The old firm sponge seal no longer fits (Derived; Open). Open: how to raise the head with no power, the brush seals on the screw slots, the cable grommets, the pinch-detection firmware, measured repeatability, and the choice of every part.
- **Interlock.** A hardware safety switch sits in series with the bridge-enable supply and the laser supply. Head up: drive outputs high impedance and lasers off, so the machine can listen but not transmit. The switch is independent of the lift controller: the spine's bottom plate presses it when the head is down. The firmware also refuses to drive. Clear glass does not block laser light, so it is not an enclosure around the laser beams. The laser class is Open ([S11](subsystems.html#s11-thermal-and-safety)).
- **Console.** The 7-inch touchscreen sits on a hollow aluminium wedge at 45°. It also carries USB-C and a status LED.
- **Cooling.** Air enters and leaves through louvres at the rear. None passes through the work chamber.

Removed from the default: the bottles, cradles, load cells, pump, liquid line, crucible tray, side vents, compute hatch and the 2.4-inch head display. The compute card is reached with the other service parts ([S01](subsystems.html#s01-chamber-and-stack-topology), [S03](subsystems.html#s03-mid-plane-interface), [S05](subsystems.html#s05-gap-actuator-and-resonance-lock)).

The model passes its checks: `fieldc desktop check` 11 of 11, 74 `fieldc` tests, and a match between the STEP export and the model. These show the model is self-consistent, not that the machine works (Simulated, Derived; [Digital twin](digital-twin.html)).

Two sizing limits are Open. The plug O-rings cannot take the whole catalogue spread of glass bore, about ±2.15 mm on the radius, so plugs must be made to fit the measured tube. A laser module behind a panel leaves −0.4 mm to a worst-case catalogue bore, so lasers fit only a tube picked for its size (Derived).

## Electronics

Each driven plate has its own stack of boards. A backplane in the plinth holds the clock, power conversion from USB-C, and the socket for the compute card. The numbers of boards in the Rev S layout are not yet re-counted.

| Board | What is on it |
|---|---|
| Plate board, one per driven plate | One RP2350B microcontroller, drive stages ({{c:haptic_pzt.hbridge_driver_mpn}}), receive protection (BAT54S), {{c:haptic_pzt.adc_fallback_mpn}} converters for the piezo discs, fast comparators (TLV3501) for the laser ring, and one spare piezo disc that touches nothing |
| Backplane | The 12 MHz clock and its distribution, power conversion from USB-C, and the socket for the compute card |
| Compute card (M.2 form factor) | Card 1: an RP2350B running Prime. Card 2: an optional FPGA module. Card 3 is reserved for an optical core |

**Why the electronics sit behind the wafer.** A piezo disc of this size has a capacitance of about {{c:haptic_pzt.c0_nominal_pf}} pF. A cable to a remote amplifier would add far more and swamp the small received signal. A controller millimetres away keeps the added capacitance under {{c:haptic_pzt.max_trace_cap_pf}} pF.

**Why not a 1-bit converter.** The first design read each disc with a comparator, which only answers "higher" or "lower", {{c:haptic_pzt.sigma_delta_fs_hz|mhz}} million times a second. That is {{c:haptic_pzt.osr}} times faster than signals below {{c:haptic_pzt.ultrasonic_bw_hz|khz}} kHz need, for an estimated {{c:haptic_pzt.enob_range|range}} bits. It had to keep {{c:haptic_pzt.sfdr_gate_min_db}} dB between the wanted tones and the largest false one. A bit-exact simulation reached {{c:haptic_pzt.sfdr_simulated_dbc}} dB, so it failed. A 16-bit converter takes its place on footprints already there ([details](compute-control.html#receive-reading-each-disc-while-it-drives)). The laser ring is still read through a fast comparator.

**Why a spare piezo disc.** The capacitance of the ceramic drifts by about {{c:haptic_pzt.c0_tempco_pct_per_c}} % per degree. A disc not attached to the plate drifts the same way but hears nothing, so subtracting its signal removes the drift.

All part numbers are candidates. Their electrical values are typical figures and must be re-read from current datasheets before the design is frozen. Stock and price have not been checked.

## Eight swappable modules

Rev S is built from eight modules that swap in place on the same frame: boundary stacks, interconnect, compute core, memory, six rear panels, lower bucket, chassis with lift, and metrology with interlocks. The head's brake-free lift (about 4.3 W of holding heat avoided) belongs to the chassis module. The [upgrade page](upgrades.html#the-rev-s-master-platform-pulled-apart) shows the machine pulled apart. It also gives each module's three upgrade steps, from today's design to a cable-free target. Each module can be isolated in the [3D model](cad-3d.html).

## Heat

With three driven plates the machine gives off an estimated 23.8 W with the first compute card and 29.3 W with the second, every plate driven with its worst pattern (Derived).

One rule shapes the layout: **the chamber floor must not be warmer than its ceiling.** Air heated from below turns over, and moving air drags on anything held in it. In a chamber {{c:desktop_geometry.gap_mm}} mm tall, a floor a few thousandths of a kelvin warmer than the ceiling is estimated to start that motion. The plinth holds the power supply and electronics, so without care the floors would be the warm side. The model gives a ceiling wafer 0.67 K warmer than the build-floor wafer, against a need of at least 0.15 K (Derived). That margin rests on an assumed 0.5 W/K heat path from the cassette to the tower, so it is Open until measured.

The goal was to keep plinth heat off both floors to within 50 mK. The model does not meet it: 0.61 K at the bottom wafer and 0.18 K at the build floor (Derived; Open). How fast the air would move, and whether that drag matters next to the holding force, is also Open.

## Material in and out

The old plan was open crucibles of dry powder and a store of bottles. That is retired. In Rev S the storage zone is a waterproof bucket, about 10.0 L, and the plan is to fill it with a fluid that matches the density of the material (Design decision). Matched density means the material hangs almost weightless, so sound has little to carry. The cassette passes material between the storage and build zones through the 12 mm round port.

The fluid-loaded simulation that would show whether the field still works in liquid has been queued and not run (Open). Dry foam beads of about 30 kg/m³ stay in the plan only as a diagnostic and calibration check. They are not the manufacturing route.

Three points about the cycle are open.

1. **Joining.** Material is to be joined by the fields themselves (sound pressure, patterned light, heat, a change of state). No joining recipe has been simulated end to end ([Manufacturing](manufacturing.html#consolidation)). See [S02](subsystems.html#s02-storage-and-release-plinth) for the storage side.
2. **Taking material away.** Removing joined material means breaking bonds, which replaying a reversed holding pattern does not do. That earlier shortcut was wrong and has been removed from the code. The simulation and the twin now model removal as absorption at a measured resonance, then transport to a crucible (Simulated; [why](matter-loop.html#why-reversing-a-holding-pattern-removes-nothing)). Where that happens inside the new bucket is not designed.
3. **Mass accounting.** The weigh cells that supported a mass balance are removed. How mass in the part and mass in the store is tracked is Open.

## What gets checked before anything is bought

The plan has no disposable test rigs. The front-end electronics, the plate response and the optical readout are checked in simulation against the full chamber. The assembled machine is then calibrated in place with removable Ø1 to 2 mm spheres.

Hardware may be released for purchase only when five things exist: a frozen design revision, a priced parts list, exact CAD with a thermal budget, passed simulation gates and a fixed acceptance procedure ([Current state](status.html)). Three release gates currently fail in simulation: the plate response cannot be predicted offline, the drive cannot hold a solid bead, and the field leaves too many unwanted traps ([Acoustic bodies](acoustics.html#known-limits)). The 1-bit converter test also failed and is answered by the 16-bit converter. No acoustic result yet covers the bucket, the annulus, the gate seam or the M2 plate.

Ordering parts or contacting suppliers also requires explicit approval from the operator.

## Optional and experimental features

**Spiral launcher.** The wafers have no holes, so the model can add a twelve-arm spiral of copper or indium tin oxide on the glass, about {{c:dissolve_and_toroidal.borofloat_chiral_spiral_trace_thickness_um}} µm thick and fed from the rim. It is meant to launch short doughnut-shaped electromagnetic pulses. It is off by default, and whether it makes a useful pulse in this chamber is Open ([Optics](optics.html#toroidal-optical-pulses)). The film is solid metal to microwaves and almost nothing to sound (Derived in principle; its effect on this plate is Open). It has no seat on the Rev S cassette yet.

**Small pulsed coil.** Large coils across the whole chamber give almost no force. A compact ring coil of {{c:dissolve_and_toroidal.compact_toroid_collar_id_mm_range|range}} mm is a candidate for softening or breaking down material during recovery. It is not in the CAD model ([Electromagnetics](electromagnetics.html)).

## What this design replaced

The machine before Rev S, called Rev F2, had a single {{c:desktop_geometry.gap_mm}} mm chamber, a rear store of three bottles on load cells with a pump and liquid line, and a tray of open crucibles in the chamber. All of these are removed from the default. Rev F2's outside size was {{c:desktop_geometry.envelope_mm|x}} mm. The shared engineering constants still hold that figure, and the handbook's revision S numbers are written out in the page above until the constants are updated. Rev F2 still builds with a `--no-bucket` option. The recorded reason for the change is a ruling to unify the stack as two zones. The reasons the individual parts went are not recorded, except where the table says so.

Other earlier whole-machine baselines are below. Parts and methods removed from the current design are logged in [Subsystems and interfaces](subsystems.html#deleted-parts-and-retired-baselines).

| Earlier baseline | Status | Why it was retired |
|---|---|---|
| Rev F2: one chamber, rear bottle store with load cells and pump, crucible tray | Retired from the default | Replaced by the two-zone stack. Part-by-part reasons not recorded |
| P0: a 4 × 4 array of 40 kHz ultrasonic transducers | Historic. Kept only as a software regression case | A separate rig that taught nothing about plate acoustics or self-sensing |
| HA-0 Rev C: Ø150 mm wafers drilled for a central pipe 12 mm wide, with single-purpose test coupons | Historic | The hole weakened the glass and removed the most useful part of the aperture. Coupons cost bench time and were then discarded |
| Hand-applied UV adhesive joining | Historic | Needed a person inside the loop for every joint |
| Bolt-clamped high-Q horn transducers and a fixed 20 ms frame clock | Parked | Narrow-band sources cannot play several tones at once or listen while driving |
| A floor-standing column with three plates sharing a two-faced middle plate | Earlier design study | The reason is not recorded. Storage below the build zone is kept in the [two-zone layout](architecture.html#three-zones) |
| Large wound coils behind each plate, meant to lift metal and carry feed up a central hole | Retired | In simulation, coils that far from the work give almost no force ([Electromagnetic control](electromagnetics.html#what-does-not-work-large-coils-across-the-chamber)) |
| Three piezo elements feeding a horn and a printed ceramic sponge behind a perforated metal plate | Retired | Above about 12 kHz a thin glass plate already radiates well, so discs are bonded straight onto bare glass (Derived) |

## Prototype, not destination

The microcontrollers, comparators and discrete lasers are scaffolding that can be bought now. The long-term design replaces the wired sources with a [surface switched by light](acoustics.html#long-term-direction) and the digital controller with wave-based computing. [Architecture](architecture.html#long-term-architecture-and-the-desktop-replicator) sets the two side by side, and the [interface control matrix](subsystems.html#interface-control-matrix) lists the interfaces that allow each swap.

## Open questions

| Question | Who answers it |
|---|---|
| Does the 16-bit converter resolve the echo to {{c:haptic_pzt.sfdr_gate_min_db}} dB with five tones present? | Electrical design and simulation |
| Does the field still hold material in a density-matched fluid? (The fluid-loaded simulation is queued.) | Simulation |
| Does a sealed M1 behave as simulated, with its annulus, seam and 12 mm round port in the field? | Simulation, then the assembled machine |
| Can plinth heat be kept off both floors to 50 mK? The model gives 0.61 K and 0.18 K | Thermal design, then the assembled machine |
| What drive voltage, tones and source size reach a holding pressure for a solid bead on the Ø{{c:desktop_geometry.wafer_diameter_mm}} mm wafer? | Simulation, then design |
| Does the head return to the same position after each motor-driven lift, closely enough to keep a calibration? The two hard stops set it, and the allowed error is ±0.5 mm (proposed). Repeatability is not measured | CAD tolerance study, then the assembled machine |
| How is the head raised with no power, and how do the screw slots stay sealed and pinch-safe? | Mechanical and firmware design |
| Which surface treatment bleeds static charge from the glass without disturbing the lasers or the sound? | Materials selection, then the assembled machine |
| How large is the buoyant air motion for a given floor-to-ceiling temperature difference? | Simulation |
| How are plugs sized to a measured tube, given the catalogue bore spread? | Mechanical design |
| Which mechanisms need design: the gate, the cassette grooves, the rim contacts, the screw-slot seals and the cable grommets? | Mechanical design |
| What joins material without adhesive, and what removes joined material on the real plates? | Process simulation |
| Which vendors can supply the custom piezo discs and at what tolerance? | Procurement, after approval |

## Where the design lives

The parametric model, parts list, drawings and exported geometry are generated by the [digital twin](digital-twin.html) (`fieldc desktop` commands). Numbers shared by firmware, simulation and CAD are held in one constants file. The [Insight register](insights.html) lists the findings that shaped this design.
