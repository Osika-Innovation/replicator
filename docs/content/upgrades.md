# The upgrade loop

The upgrade loop is the plan for how one machine improves itself. It is a list of steps, each naming the steps it depends on. It starts from bought parts and ends at modules the machine helps to make. No step yet names a self-made part.

The aim is to spend as little human time as possible. The plan is searched forward from what an affordable [Desktop Replicator](desktop-replicator.html) can do, and backward from the long-term design in [Architecture](architecture.html). Cheap models explore, an independent model checks, and a measurement settles what models cannot ([automated design search](digital-twin.html#automated-design-search)). Progress is scored as new abilities and settled questions per hour of human setup (Design decision).

## The swap rule

A part of the first machine is swapped for a better one only when a test passes. The test is a measurement on the real machine. A good result in a computer model is not enough.

Each part has its own test, written down first. If the test fails, the old part stays. Some swaps may never happen, because the old part is good enough.

All parts, replacements and tests are in one table: [Long-term architecture and the Desktop Replicator](architecture.html#long-term-architecture-and-the-desktop-replicator). Every test in it is Open, because each needs an assembled, calibrated machine.

## One enduring platform

There is one machine, upgraded in place. The mechanical reference surfaces, the optical sightlines, the coordinate convention, the job and [holographic-equation](compute-control.html#holographic-equations) file formats and the software interface stay fixed between generations. Only the module that limits performance is replaced.

There are no disposable test rigs. Calibration happens in the assembled chamber.

**Sensing first (Design decision).** Listening and looking need milliwatts. Holding and moving need far more. A new machine therefore [scans](matter-loop.html#scan-non-moving-3d-tomography-and-scattering) first: its own empty chamber, then an object. Lifting comes after, on the same hardware, once the measured response says the drive is safe and strong enough.

**Buying is allowed.** A bought wafer, microcontroller, laser diode or outside-made optical master is a valid starting part whenever buying costs less human time than building the tool that would make it.

## The rule that keeps the graph honest

Each record is one part, process, measurement or upgrade. A record that is made or measured must state:

1. the bottleneck it removes;
2. the fabrication tolerance it requires;
3. the measurement that checks that tolerance;
4. the bought or outsourced inputs it depends on (the "seeds");
5. the benefit, as the same task run before and after;
6. an estimate of the human minutes it costs.

Three more fields are proposed and not yet checked: where the prediction is trusted, machine cost (time, energy, yield, rework), and the smallest experiment that could still change the decision.

The plan must contain no loops. An upgrade may not depend on the precision it is supposed to create, unless a bought seed supplies that precision first.

The twin's command `fieldc upgrades` checks that no record depends on itself or on an unknown record, and that every made or measured record carries a tolerance and an inspection. The current plan passes. That shows it is well formed, not that any step will work.

## The current graph

Every record in the plan, in build order.

| Record | What it is | Status | Depends on |
|---|---|---|---|
| `S-SEEDS` | Bought parts: borosilicate wafers, piezo discs, microcontroller boards, drivers, receive converters, comparators, laser diodes, clock, calibration spheres | Listed in the bill of materials; no supplier contacted | Nothing |
| `S-WORKSHOP` | Workshop machining and 3-D printing, plus outsourced circuit boards and glass edge cutting | Specified in the manufacturing pack; nothing ordered | Nothing |
| `C-SIM-GATES` | Simulation checks to pass before any board is made: receive converter, pattern network size, laser readout, solid plate model | The 1-bit receive converter failed its check ({{c:haptic_pzt.sfdr_simulated_dbc}} dB against {{c:haptic_pzt.sfdr_gate_min_db}} dB) and is replaced by a 16-bit converter ({{c:haptic_pzt.adc_fallback_mpn}}). The current list of passing and failing checks is in [Current state](status.html) | Nothing |
| `S-META-MASTER` | Outside-made nanostructured optical master, for later imprint copies | Candidate; not ordered | Nothing |
| `C-FW-DESKTOP` | Controller firmware for the three boards: drive, receive, laser readout, shared clock and pattern network | Source written and tested on a workstation (Simulated); never run on a board | `C-SIM-GATES` |
| `X-EM` | Optional contactless exciter (magnet and flat coil) for testing metal plates outside the glass baseline | Drafted; off the critical path | `S-WORKSHOP` |
| `M-DESKTOP-REV-D` | The assembled Desktop Replicator | CAD model passes its geometry checks | `S-SEEDS`, `S-WORKSHOP`, `C-FW-DESKTOP` |
| `K-INCHAMBER-CAL` | Calibration inside the assembled chamber with removable spheres and crucibles: hold, move and transfer repeatability | Needs the assembled machine | `M-DESKTOP-REV-D` |
| `U1-PINNA-KINO` | First upgrade designed from the machine's own calibration data: a faceted rear reflector and an optional printed phase insert | Simulated; waits for calibration | `K-INCHAMBER-CAL` |
| `U2-TIO2-META` | Imprinted diffractive strips on the laser sightlines, to double the independent optical measurements | Simulated; waits for calibration and the master | `K-INCHAMBER-CAL`, `S-META-MASTER` |
| `U4-SPIRAL-TOROIDAL` | Optional thin-film spiral conductor on the wafers, for launching short toroidal pulses | Candidate; waits for a pulse simulation and calibration | `K-INCHAMBER-CAL`, `S-WORKSHOP` |
| `U5-TOROID-COLLAR` | Compact pulsed ring coil around a crucible throat | Candidate; waits for an electrodynamic model and calibration | `K-INCHAMBER-CAL`, `S-WORKSHOP` |
| `U3-WAVE-BRAIN` | Compute card progression: microcontroller, then a programmable-logic card, then an optical or wave-based core | First card simulated; later cards open | `K-INCHAMBER-CAL`, `U2-TIO2-META` |

Every upgrade waits for the in-chamber calibration, which produces the first measured data.

## What the graph does not yet contain

- **Measured costs.** The human-minute figures, 0 to 180 minutes per record, are estimates.
- **A part made by the platform.** The first self-made upgrade is not yet named. Every record is bought, made in a workshop, a measurement, or shaped by calibration data but printed elsewhere. The first self-made upgrade should remove the most human work per unit of benefit. Candidates are fixtures, feed guides, field-shaping inserts, scattering face plates and small optical structures (Open).
- **The current spacing.** The record for the assembled machine may still quote the earlier 120 mm plate spacing. The current value is {{c:desktop_geometry.gap_mm}} mm, and results simulated at the earlier spacing do not carry over.
- **Results.** Each upgrade's benefit is an acceptance target written before any measurement.

## Long-term direction

The long-term design replaces bought electronics with light-switched elements and wave-based computing, and closes the material cycle ([Architecture](architecture.html), [Scan, recover and matter stores](matter-loop.html)). A step enters the plan only when a record can state its tolerance, its measurement and its seeds.

| Stage | What happens |
|---|---|
| Seed | Buy or outsource what makes the first useful process possible |
| First upgrade | Make and check one part that improves the same machine |
| Precision ladder | Use that gain to make a harder part, and the tool that measures it |
| Reproduction | Make the next working machine, listing every outside step |

Weight is a poor score: a machine can make most of its own mass and still depend on one outside process. Every outside part and process stays on the list.

Copying needs a closed material loop and enough process range to make every module. Improving needs only one module the machine makes better than the one it replaces, and a measurement that proves it.

An optical computer is the computer this machine might make, because it works by shape and not by doping chemistry (Open; see [the substrate ladder](cadence-memory.html#long-term-direction-the-substrate-ladder)).

## Open questions

| Question | Who answers it |
|---|---|
| Which part is the first self-made upgrade? | Engineering management, after in-chamber calibration data exists |
| What do the steps cost in human minutes? | Measured during assembly and calibration |
| Do the upgrade targets survive the change to {{c:desktop_geometry.gap_mm}} mm spacing? | Simulation, by re-running the affected models |

Read next: [Desktop Replicator](desktop-replicator.html), [The engineering twin](digital-twin.html), [Manufacturing](manufacturing.html) and [From atoms to hardware](physics-to-hardware.html).
