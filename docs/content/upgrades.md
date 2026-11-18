# The upgrade loop

The upgrade loop is the plan for how one machine improves itself. It is a dependency graph that starts from purchased parts and ends at modules the machine helps to make. The graph is planning data: **nothing in it has been ordered, built or measured**, and it does not yet name a part made by the platform itself.

The aim is to spend as little human engineering and experiment time as possible. Two searches meet in the graph: forward from what an affordable [Desktop Replicator](desktop-replicator.html) can do, and backward from the long-term design described in [Architecture](architecture.html).

## One enduring platform

There is one machine, and it is upgraded in place. The mechanical reference surfaces, the optical sightlines, the coordinate convention, the job and pattern file formats and the software interface to the machine stay fixed from one generation to the next. Only the module that limits performance is replaced.

There are no disposable test rigs. Calibration happens in the assembled chamber, using removable spheres and the crucibles, so the tool that calibrates the first machine is the machine.

Buying is allowed. A purchased wafer, microcontroller, laser diode or externally made optical master is a valid starting part whenever buying it costs less human time than building the tool that would make it.

## The rule that keeps the graph honest

Each record in the graph is one part, process, measurement or upgrade. A record that is made or measured must state:

1. the bottleneck it removes;
2. the fabrication tolerance it requires;
3. the measurement that checks that tolerance;
4. the purchased or outsourced inputs it depends on (the "seeds");
5. the benefit, as the same task run before and after;
6. an estimate of the human minutes it costs.

The graph must be acyclic. An upgrade may not depend on the precision it is supposed to create, unless a purchased or outsourced seed supplies that precision first. A machine cannot print a more accurate lens with optics that already need that lens; someone has to buy the first master.

The command `fieldc upgrades` checks two things: that no record depends on itself or on an unknown record, and that every made or measured record carries a tolerance and an inspection. The current graph passes both checks. That shows the plan is well formed. It says nothing about whether any step will work.

## The current graph

The table lists every record in `twin/Design/upgrade_graph.json`, in build order.

| Record | What it is | Status | Depends on |
|---|---|---|---|
| `S-SEEDS` | Purchased parts: borosilicate wafers, piezo discs, microcontroller boards, drivers, comparators, laser diodes, clock, calibration spheres | Listed in the bill of materials; stock not checked, no supplier contacted | Nothing |
| `S-WORKSHOP` | Workshop machining and 3-D printing, plus outsourced circuit boards and glass edge cutting | Specified in the manufacturing pack; nothing ordered | Nothing |
| `C-SIM-GATES` | Simulation checks to pass before any board is made: receive converter, pattern network size, laser readout, solid plate model | Open | Nothing |
| `S-META-MASTER` | Externally made nanostructured optical master, for later imprint copies | Candidate; not ordered | Nothing |
| `C-FW-DESKTOP` | Controller firmware for the three boards: drive, receive, laser readout, shared clock and pattern network | Open; not written | `C-SIM-GATES` |
| `X-EM` | Optional contactless exciter (magnet and flat coil) for testing metal plates outside the glass baseline | Drafted; off the critical path | `S-WORKSHOP` |
| `M-DESKTOP-REV-D` | The assembled Desktop Replicator | CAD model passes its geometry checks; no parts ordered | `S-SEEDS`, `S-WORKSHOP`, `C-FW-DESKTOP` |
| `K-INCHAMBER-CAL` | Calibration inside the assembled chamber with removable spheres and crucibles: hold, move and transfer repeatability | Blocked until the machine is built | `M-DESKTOP-REV-D` |
| `U1-PINNA-KINO` | First upgrade designed from the machine's own calibration data: a faceted rear reflector and an optional printed phase insert | Simulated; waits for calibration | `K-INCHAMBER-CAL` |
| `U2-TIO2-META` | Imprinted diffractive strips on the laser sightlines, to double the independent optical measurements | Simulated; waits for calibration and the master | `K-INCHAMBER-CAL`, `S-META-MASTER` |
| `U4-SPIRAL-TOROIDAL` | Optional thin-film spiral conductor on the wafers, for launching short toroidal pulses | Candidate; waits for a pulse simulation and calibration | `K-INCHAMBER-CAL`, `S-WORKSHOP` |
| `U5-TOROID-COLLAR` | Compact pulsed ring coil around a crucible throat | Candidate; waits for an electrodynamic model and calibration | `K-INCHAMBER-CAL`, `S-WORKSHOP` |
| `U3-WAVE-BRAIN` | Compute card progression: microcontroller, then a programmable-logic card, then an optical or wave-based core | First card simulated; later cards open | `K-INCHAMBER-CAL`, `U2-TIO2-META` |

Every upgrade waits for the in-chamber calibration, because that step produces the first measured data.

## What the graph does not yet contain

**All human-minute figures are estimates.** They range from 0 to 180 minutes per record. None has been measured, because no step has been carried out.

**No record is made by the platform.** Every record is purchased, made in a workshop, a measurement, or a hybrid in which the machine's calibration data shapes a part that is still printed or imprinted elsewhere. The "first self-made upgrade" is therefore not yet named. Choosing it is an open planning item: it should be the part whose fabrication and checking remove the most human work per unit of benefit.

**The prototype record may lag the design.** The record for the assembled machine may still quote the earlier 120 mm plate spacing. The current value is {{c:desktop_geometry.gap_mm}} mm, and acoustic results for the earlier spacing do not carry over.

**Benefits are targets.** Each upgrade states an acceptance target, such as a gain in reconstruction quality or a tolerance on a printed surface. These are targets written before any measurement, not results.

## Long-term direction

The long-term design replaces purchased electronics with optically addressed elements and wave-based computing, and closes the material cycle so that scanning, assembly and recovery run without manual handling. Those steps are described in [Architecture](architecture.html), [Cadence, memory and wave compute](cadence-memory.html) and [Scan, recover and matter stores](matter-loop.html). They enter the graph only when a record can state its tolerance, its measurement and its seeds.

Making a copy and making an improvement are different milestones. Copying needs a closed material loop and enough process range to make every module. Improving needs only one module that the machine can make better than the one it replaces, and a measurement that proves it.

## Open questions

| Question | Who answers it |
|---|---|
| Which part is the first self-made upgrade? | Engineering management, after in-chamber calibration data exists |
| What do the steps cost in human minutes? | Measured during assembly and calibration |
| Do the upgrade targets survive the change to {{c:desktop_geometry.gap_mm}} mm spacing? | Simulation, by re-running the affected models |

Read next: [Desktop Replicator](desktop-replicator.html), [Digital twin](digital-twin.html), [Manufacturing](manufacturing.html) and [From atoms to hardware](physics-to-hardware.html).
