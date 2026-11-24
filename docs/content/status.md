# Current state

The engineering record is a parametric CAD model of the [Desktop Replicator](desktop-replicator.html), simulations of its sound field, sensing and control, and this handbook. Every statement about what the machine does is a labelled design decision, calculation or simulation result. Other groups' laboratory demonstrations of the mechanisms are in [Proven in the lab](evidence.html).

## State at a glance

| Area | What exists | Evidence | What blocks the next step |
|---|---|---|---|
| Machine design | Parametric CAD of the Desktop Replicator, revision S: a storage bucket under a drop-in mid-plane cassette, a lifting build cylinder raised by a servo and two ball screws, which also trims the gap. Exact geometry export, drawings, parts list with candidate part numbers, power estimate. 11 of 11 design gates and 74 `fieldc` tests pass | Derived | Simulation gates below; operator approval before any order |
| [Plate acoustics](acoustics.html) | A reduced plate model for planning, and a three-dimensional solid model. The sealed mid-plane cassette reaches 1.9 to 2.4 times a foam bead's weight in simulation; without it only 0.17 to 0.74 times | Simulated | A measured plate response; the fluid-loaded simulation (S-VOL1); all results repeated at the {{c:desktop_geometry.gap_mm}} mm plate spacing |
| [Drive and receive electronics](compute-control.html) | Circuit concept with a proposed front-end netlist. The 1-bit converter failed its simulated test, so a 16-bit converter ({{c:haptic_pzt.adc_fallback_mpn}}) is fitted. A candidate drive part is named. No board layout | Simulated; Open | Datasheet values re-read; a check that the larger piezo discs keep pattern control |
| [Optical ring](optics.html) | Six flat panels inside the glass carry the laser windows. A signal model in simulation | Simulated | A check on data the same model did not generate; the laser class |
| [Pattern network](cadence-memory.html) (Prime, the project's model built on the Cadence library) | A reduced 8-bit form (LMQ8 v1) fits the controller: 58.7 kB working set, 59.4 kB static RAM on the host build, against the 60 kB limit | Simulated | Accuracy on a plate response that was not simulated by the same code |
| Firmware | Source for the drive, receive, laser, bus, gap-lock and sweep modules. 411 checks on a workstation, and the code compiles for the target chip. Never run on a board | Simulated | A main program, a build, and a board to run on |
| Thermal | The base's power supply and compute card warm the lower glass. A lumped model gives +0.61 K at the bottom wafer and +0.18 K at the build floor. The goal is under 0.05 K | Derived; Open | A heat break between the cartridge socket and the base. The CAD team has not found one that keeps the gap pads |
| [Assembly and joining](manufacturing.html) | The design target is volumetric single-shot assembly: sound shapes the whole 3D matter field at once, and patterned light locks it. Neither half has been simulated in the fluid-filled cylinder yet. The dry-air foam-bead lift is kept as a calibration check | Design decision; Open | S-VOL1 simulation; a locking recipe |
| [Removal and recovery](matter-loop.html) | The simulation and the twin model removal as absorption at a measured resonance, and conserve mass. The earlier reversed-pattern shortcut was wrong and has been removed from the code | Simulated | A measured scattering response; a recovery loop in the fluid-filled bucket |
| [Scanning](matter-loop.html#scan-non-moving-3d-tomography-and-scattering) | Acoustic and optical scan models on the present geometry; their checks are reported passing | Simulated | Stored results of those checks; tests on independently generated data |
| [Electromagnetic control](electromagnetics.html) | Large coils across the chamber are ruled out by simulation. A small pulsed coil is a candidate | Simulated; Open | A model of what the small coil can and cannot reach |
| [Long-term architecture](ultimate-replicator.html) | Design studies on published component physics, a bounds model (energy, information, force and time floors) and a parametric concept chamber with checked geometry | Documented; Open; Derived | Demonstrations of the components at useful scale |

## Active engineering gates

Four things stand between the design and a first test. Everything else that used to be listed here is either solved in simulation or is history.

1. **Bench Gate 0: does the empty cavity ring?** Before any matter goes in, a one-port sweep from 156 to 164 kHz in 10 Hz steps compares the closed cavity with an absorber in it. The ratio of the second echo to the first must show a reflection of at least 0.85 (ratio 0.466; 0.523 would mean 0.90). The firmware for the sweep is written and tested on a workstation. No board has run it (Open).
2. **S-VOL1: does volumetric assembly work in water-like fluid?** The new simulation must shape a whole 3D region at once, in a buoyancy-matched fluid, inside the glass cylinder. It replaces the old count of unwanted wells with a shape score: how much of the target volume is filled and how little is outside it. It must also show how fast matter settles against the stirring the sound itself causes, and that glass stress stays under the 10 MPa cap with real densities (Open; queued).
3. **Laser class and enclosure.** The glass cylinder is clear, so it does not enclose the laser beams. A hardware switch cuts laser power when the head is raised. The six flat panels sit inside the glass, but the laser modules sit outside, and a worst-case glass tube leaves them 0.4 mm short of the bore. The laser class is Open.
4. **One-shot locking and recovery.** Light must lock the shape in one exposure, and the machine must then take it apart again and account for every gram. A joining recipe has not been simulated, and nothing tracks mass through a build (Open).

### What was removed from the old list, and why

An earlier version of this page listed seven "known inconsistencies". Three are solved in simulation. Three were problems of one particular test, and the new plan avoids that test. They stay in the record as calibration history ([insight register](insights.html), INS-43).

| Old item | What happened |
|---|---|
| Plate response drifts | Solved in simulation. Laser readout of the plate, the small pattern network and the gap lock (0.41 mm per kelvin) track it. Still needs a measured plate response (Simulated) |
| Unwanted traps | Solved at 0.3 % median on 36 ports in simulation. The shape score in S-VOL1 replaces the trap count (Simulated) |
| Pattern network size | Reconciled: the reduced form fits in 58.7 of 60 kB (Simulated) |
| Drive strength | A 30 kg/m³ foam bead in air needs nearly the whole supply: one tone lifts about 1.2 times its weight at 3.7 to 5.0 MPa glass stress, and five tones lift about 7 %. That was a limit of lifting one dry bead against gravity in air. In a liquid with the same density as the matter, the weight that has to be carried is 10 to 100 times smaller. Kept as a dry check (Simulated) |
| Placing beads side by side | A placed bead disturbs the field that should hold its neighbour. Volumetric assembly never places one bead at a time (Simulated; retired) |
| Static charge | A foam bead sticks to dry glass at about 5 pC. In a liquid or slurry there is no dry clamping. A 2025 paper uses charge on purpose to keep many particles apart, so charge is now a possible control, not only a hazard ([Proven in the lab](evidence.html)) (Open) |
| Laser class | Still open. Now gate 3 above |

## What must exist before hardware is ordered

Hardware may be released for purchase only when all five exist:

1. A frozen revision of the design with file hashes.
2. A parts list with quantities, part numbers, live stock and prices.
3. Exact CAD geometry, drawings, tolerances, wiring and a thermal budget.
4. Passed simulation gates: a receive path that meets {{c:haptic_pzt.sfdr_gate_min_db}} dB, and the fluid-loaded volumetric simulation (S-VOL1). The 1-bit converter failed the first and is replaced. The second has not been run.
5. A fixed acceptance procedure to run in the built chamber.

None of the five is complete. Ordering parts or contacting suppliers also needs the operator's explicit approval.

## Evidence labels

Every claim in this handbook carries one of these labels.

| Label | Meaning |
|---|---|
| Design decision | A direction or requirement the programme has chosen |
| Documented | A result reported by an identified external source |
| Derived | A calculation with stated assumptions and units |
| Simulated | A result from a specified project model |
| Measured | A project bench result with apparatus, calibration and raw records. |
| Open | Not yet settled by calculation, simulation or measurement |
| Claim | Asserted by a source and not verified |

Four rules go with the table.

- **A published result stays with its authors.** It belongs to the apparatus and conditions it was made with, and is never presented as something this project measured. Textbook physics with no registered source is marked as textbook.
- **Choosing a design and proving it are separate.** A design can be pursued while its proof is open, as long as the label says so.
- **Firmware tested on a workstation is Simulated.** A passing model check is not a measurement.
- **A rebuilt image stays inferred.** In scan data a value is *measured* when a sensor reported it and *inferred* when a model filled it in, however sharp it looks. That describes where a number in a data file came from. It is not an evidence label.

## How something moves up

- A source enters the [research library](research.html) with its identity and how deeply it was read.
- A model earns use when an independent calculation agrees with it.
- A design earns hardware when it passes the five conditions above.
- Hardware earns a capability through repeatable measurement.
- An upgrade earns adoption through a measured before-and-after improvement on the same task ([upgrade loop](upgrades.html)).

## Retired designs

Whole-machine baselines are in [Desktop Replicator](desktop-replicator.html#what-this-design-replaced). Parts and methods removed since are in [Subsystems and interfaces](subsystems.html#deleted-parts-and-retired-baselines).

## Keeping this page true

Numbers here come from the shared engineering constants. The build fails if they drift or if a retired design is described as current.
