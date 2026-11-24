# Current state

The engineering record is a parametric CAD model of the [Desktop Replicator](desktop-replicator.html), simulations of its sound field, sensing and control, and this handbook. Every statement about what the machine does is a labelled design decision, calculation or simulation result. Other groups' laboratory demonstrations of the mechanisms are in [Proven in the lab](evidence.html).

## State at a glance

| Area | What exists | Evidence | What blocks the next step |
|---|---|---|---|
| Machine design | Parametric CAD model, exact geometry export, drawings, parts list with candidate part numbers, power estimate | Derived | Simulation gates below; operator approval before any order |
| [Plate acoustics](acoustics.html) | A reduced plate model for planning, and a three-dimensional solid model that contradicts it | Simulated | The two models disagree; a measured plate response is required; all results repeated at the {{c:desktop_geometry.gap_mm}} mm plate spacing |
| [Drive and receive electronics](compute-control.html) | Circuit concept with a proposed front-end netlist. The 1-bit converter failed its simulated test, so a 16-bit converter ({{c:haptic_pzt.adc_fallback_mpn}}) is fitted. A candidate drive part is named. No board layout | Simulated; Open | Datasheet values re-read; a check that the larger piezo discs keep pattern control |
| [Optical ring](optics.html) | Geometry in the CAD model and a signal model in simulation | Simulated | A check on data the same model did not generate; the laser class |
| [Pattern network](cadence-memory.html) (Prime, the project's model built on the Cadence library) | Trained in simulation at full size. A reduced form fits the controller's memory but loses the accuracy needed on the solid plate model | Simulated | A ruling: a smaller task, a larger memory budget, or the second compute card |
| Firmware | Source for the drive, receive, laser, bus and pattern-network modules, tested on a workstation (59 checks). Never run on a board | Simulated | A main program, a build, and a board to run on |
| [Assembly and joining](manufacturing.html) | A transport model, and a modelled joining step that heats the joint with a laser pulse. Placing one bead beside another is unsolved | Simulated; Open | Enough drive for transport; the beside-bead problem; any evidence for the heating step |
| [Removal and recovery](matter-loop.html) | The simulation and the twin model removal as absorption at a measured resonance, then transport to a crucible, and conserve mass. The earlier reversed-pattern shortcut was wrong and has been removed from the code. On the solid plate model little energy reaches the part, so removal is slow | Simulated | A measured scattering response; more energy on the part |
| [Scanning](matter-loop.html#scan-non-moving-3d-tomography-and-scattering) | Acoustic and optical scan models on the present geometry; their checks are reported passing | Simulated | Stored results of those checks; tests on independently generated data |
| [Electromagnetic control](electromagnetics.html) | Large coils across the chamber are ruled out by simulation. A small pulsed coil is a candidate | Simulated; Open | A model of what the small coil can and cannot reach |
| [Long-term architecture](ultimate-replicator.html) | Design studies on published component physics, a bounds model (energy, information, force and time floors) and a parametric concept chamber with checked geometry | Documented; Open; Derived | Demonstrations of the components at useful scale |

## Known inconsistencies in the design

Reviews and simulations found places where the design disagrees with itself or with its models. All are in the [insight register](insights.html). Three are settled: the receive converter (a 16-bit part is fitted), the air temperature sensors (added) and the chamber (closed by a glass cylinder). The ones that matter most now:

1. **Drive strength.** Sound pressure from a glass plate is limited by bending stress in the glass, not by voltage. Solid polystyrene would overstress the plates with any piezo. A foam bead of 30 kg/m³ can be held in simulation: one 160 kHz tone on the full {{c:haptic_pzt.bridge_rail_v}} V supply lifts about 1.2 times its weight, at a glass bending stress of 3.7 to 5.0 MPa against a {{c:desktop_geometry.plate_bending_stress_limit_mpa}} MPa limit. Five tones sharing the supply lift about 7 %. So lifting and field clean-up take turns ([why](acoustics.html#drive-strength-and-lift)).
2. **Plate response.** The solid model shows that the plates ring, and that the response shifts too much between nominally identical plates to be predicted. It must be measured in the chamber for each plate, and again after every head lift and every few tenths of a kelvin. A stored calibration matches the true response only about 0.63 after 0.5 K and 0.65 after 200 µm of gap change, where 1 is perfect (Simulated).
3. **Unwanted traps.** With one tone from twelve sources, 10 to 17 % of the work volume is above 70 % of the target spot's amplitude. The limit is 2 %. Filling several sites evenly also falls short.
4. **Pattern network size.** The form of the network that fits in {{c:cadence_brain.cadence_sparse_max_kb}} kB keeps its speed but not its accuracy on the solid plate model. A second simulation, on a different task, reports the opposite. They are not reconciled ([Cadence, memory and wave compute](cadence-memory.html#in-the-desktop-replicator)).
5. **Laser class.** The glass cylinder is clear, so it does not enclose the laser beams. A hardware switch cuts laser power when the head is raised. The laser class is Open.
6. **Placing beads side by side.** A bead already in place disturbs the field that should hold its neighbour. This is unsolved. Touching beads also scatter sound as a coupled group, which the simple model gets wrong above the lowest tone, and about 1 pC of static charge cancels the weak attraction between two beads.
7. **Static charge.** A foam bead sticks to bare glass at about 5 pC. The glass needs a charge-bleeding surface and the air a controlled humidity. Neither is a specified part.

## What must exist before hardware is ordered

Hardware may be released for purchase only when all five exist:

1. A frozen revision of the design with file hashes.
2. A parts list with quantities, part numbers, live stock and prices.
3. Exact CAD geometry, drawings, tolerances, wiring and a thermal budget.
4. Passed simulation gates: a receive path that meets {{c:haptic_pzt.sfdr_gate_min_db}} dB, and agreement between the solid model and the plate model. The 1-bit converter failed the first and is replaced. Three more gates fail now: predicting the plate response offline, holding a solid bead, and keeping unwanted traps under the limit.
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
