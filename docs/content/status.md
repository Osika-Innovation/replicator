# Current state

The engineering record today is a parametric CAD model of the [Desktop Replicator](desktop-replicator.html), simulations of its acoustics, sensing and control, and this handbook. Every statement in this handbook about what the machine does is a design decision, a calculation or a simulation result, and is labelled as such. Third-party laboratory demonstrations of the underlying mechanisms are indexed separately in [Proven in the lab](evidence.html).

## State at a glance

| Area | What exists | Evidence | What blocks the next step |
|---|---|---|---|
| Machine design | Parametric CAD model, exact geometry export, drawings, parts list with candidate part numbers, power estimate | Derived | Simulation gates below; operator approval before anything is ordered |
| Plate acoustics | A reduced plate model used for planning, and a three-dimensional solid finite-element model that contradicts it | Simulated | The two models disagree; a measured plate response is required; all results repeated at the new {{c:desktop_geometry.gap_mm}} mm plate spacing |
| Drive and receive electronics | Circuit concept with a proposed front-end netlist. The 1-bit converter failed its test, so a conventional converter ({{c:haptic_pzt.adc_fallback_mpn}}) is fitted. A candidate drive part is named. There is no board layout | Simulated; Open | Datasheet values re-read; a check that the larger piezo discs keep pattern control |
| Optical ring | Geometry in the CAD model and a signal model in simulation | Simulated | A check on data that the same model did not generate; confirmation of the laser class |
| Pattern network (Cadence) | Trained in simulation at full size. A reduced form fits the controller's memory but, on the solid plate model, loses the accuracy needed | Simulated | A ruling: a smaller task, a larger memory budget, or the second compute card |
| Firmware | Source for the drive, receive, laser, bus and pattern-network modules, tested on a workstation (59 checks). Never built for or run on a board | Simulated | A main program, a build, and a board to run on |
| Assembly and joining | A transport model in simulation, and a modelled joining step that heats the joint with a laser pulse. Placing one bead beside another is unsolved | Simulated; Open | Enough drive for transport; the beside-bead problem; any evidence for the heating step |
| Removal and recovery | The correct physical sequence is implemented in simulation and conserves mass. On the solid plate model it delivers little energy to the part, so it is slow | Simulated | A measured scattering response; more energy on the part |
| Scanning | Acoustic and optical scan models updated to the present geometry; their checks are reported passing | Simulated | Stored results of those checks; tests on independently generated data |
| Electromagnetic control | Large coils across the chamber are ruled out by simulation. A small pulsed coil is a candidate | Simulated; Open | A model of the small coil that respects what it can and cannot reach |
| Long-term architecture | Design studies resting on published component physics, now with a computed bounds model (energy, information, force and time floors) and a parametric concept chamber with checked geometry | Documented; Open; Derived | Demonstrations of the components at useful scale; see [The long-term machine](ultimate-replicator.html) |

The detailed chapters are [Acoustic bodies](acoustics.html), [Compute, sensing and control](compute-control.html), [Optics and metamaterials](optics.html), [Manufacturing](manufacturing.html), [Scan, recover and matter stores](matter-loop.html) and [Electromagnetic control](electromagnetics.html).

## Known inconsistencies in the design

A review of the engineering record on 17 November 2026, and the simulations that followed it, found places where the design disagrees with itself or with its models. Each is registered and listed in the [insight register](insights.html). Several from the first review are now settled: the receive converter (a fallback part is fitted), the air temperature sensors (added) and the open chamber (closed with a glass cylinder). The ones that matter most now:

1. **Drive strength.** Sound pressure from a glass plate is limited by bending stress in the glass, not by voltage. Holding solid polystyrene would stress the plates past the assumed safe limit with any piezo. A foam bead of 30 kg/m³ can be held, in simulation, with larger and thinner piezo discs on an 18 V supply. One tone at full voltage lifts about 1.2 times the bead's weight; five tones sharing the supply lift about 7 % of it. Lifting and field clean-up therefore have to alternate.
2. **Plate response.** The solid model shows the plates ring, and the response shifts too much between nominally identical plates to be predicted. It has to be measured in the chamber for each plate, and again after every head lift and every few tenths of a kelvin of air temperature change.
3. **Unwanted traps.** One tone from twelve sources leaves 10 to 17 % of the work volume above 70 % of the target amplitude, against a limit of 2 %. Filling several sites evenly also falls short.
4. **Pattern network size.** The form of Cadence that fits in {{c:cadence_brain.cadence_sparse_max_kb}} kB keeps its speed but not its accuracy on the solid plate model. A second simulation, on a different task, reports the opposite. The two have not been reconciled.
5. **Laser class.** The glass cylinder is clear, so it does not enclose the laser beams. An interlock switches the lasers off when the head is raised. The laser class has been assessed from memory of the standard and needs confirming.
6. **Placing beads side by side.** A bead already in place disturbs the field that should hold its neighbour. This is unsolved. Two further limits are now known: touching beads scatter sound as a coupled group, which the simple model gets wrong above the lowest tone, and about 1 pC of static charge cancels the weak attraction between two beads.
7. **Static charge.** A foam bead sticks to bare glass at about 5 pC. The glass needs a charge-bleeding surface and the air a controlled humidity. Neither is specified as a part.

## What must exist before hardware is ordered

Hardware may be released for purchase only when all five of these exist:

1. A frozen revision of the design with file hashes.
2. A parts list with quantities, part numbers, live stock and prices.
3. Exact CAD geometry, drawings, tolerances, wiring and a thermal budget.
4. Passed simulation gates: the {{c:haptic_pzt.sfdr_gate_min_db}} dB converter test and agreement between the solid finite-element model and the plate model. Three gates currently fail: predicting the plate response offline, holding a solid bead, and keeping unwanted traps under the limit.
5. A fixed acceptance procedure to run in the chamber once the machine is built.

None of the five is complete. Ordering parts or contacting suppliers also requires explicit approval from the operator.

## Evidence labels

Every claim in this handbook carries one of these labels, stated or implied by its section.

| Label | Meaning |
|---|---|
| Design decision | A direction or requirement the programme has chosen |
| Documented | A result reported by an identified external source |
| Derived | A calculation with stated assumptions and units |
| Simulated | A result from a specified project model |
| Measured | A project bench result with apparatus, calibration and raw records. |
| Open | Not yet settled by calculation, simulation or measurement |
| Claim | Asserted by a source and not verified |

A result reported in the literature stays attributed to its authors. It is never presented as something this project has measured.

Scan data uses a separate pair of words. A value is *measured* when a sensor reported it and *inferred* when a model filled it in. That describes where a number in a data file came from. It is not an evidence label.

## How something moves up

A source enters the [research library](research.html) with its identity and how deeply it was read. A model earns use when an independent calculation agrees with it. A design earns hardware when it passes the five conditions above. Hardware earns a capability through repeatable measurement. An upgrade earns adoption through a measured before-and-after improvement on the same task, as described in the [upgrade loop](upgrades.html).

## Retired designs

Three earlier baselines are retired and appear in this handbook only as history: an array of sixteen 40 kHz transducers, a design with drilled wafers and single-purpose test rigs, and joining by hand-applied adhesive. The table of what was retired and why is in [Desktop Replicator](desktop-replicator.html#what-this-design-replaced). Parts and methods removed since, each with the finding that removed it, are logged in [Subsystems and interfaces](subsystems.html#deleted-parts-and-retired-baselines).

## Keeping this page true

The numbers on this page are quoted from the shared engineering constants, and the handbook build fails if they drift or if a retired design is described as current. Update this page whenever a row of the table changes.
