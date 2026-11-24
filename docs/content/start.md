# Start here

The Replicator is a machine that builds objects by holding and moving material with fields, not tools. Sound carries material and puts it in place. Light looks at it and handles fine detail. Electric and magnetic fields act on materials that respond to them. All of this happens in one chamber with no nozzle, no robot arm and no moving stage.

The long-term aim is a machine that makes more and more of the parts of its own successor.

## What exists today

- A CAD model of the first machine, the [Desktop Replicator](desktop-replicator.html).
- Simulations of its sound field, its sensors and its controller.
- A [research library](research.html) of the published work the design relies on.
- This handbook.

[Current state](status.html) lists each area with its evidence and what blocks the next step.

## What the machine does

A build repeats four steps inside the chamber.

1. **Scan.** Find out what is in the chamber. Any object changes the sound and the laser beams that cross it, and the changes are turned into a description of the object.
2. **Assemble.** Shape the sound field into small pockets that hold material. Move the pockets to carry material into place, and join it there.
3. **Check.** Compare what is there with what was wanted, all the time, with the same sensors.
4. **Recover.** Take apart what is wrong or no longer needed, and return the material to storage.

Scanning and checking are the best understood. Joining and recovery have no complete recipe yet ([Manufacturing](manufacturing.html), [Scan, recover and matter stores](matter-loop.html)).

The machine keeps three records apart (Design decision).

| Record | What it says | What proves it |
|---|---|---|
| The wanted part | Shape, material, fit, tolerances, tests | Nothing yet. It is the goal |
| What was observed | Sensor readings of the real workpiece | Predicting readings that were held back from the model |
| The build program | Feed, move, join, check and recover steps | A finished part that passes its test |

A program can run perfectly and still make a bad part. Playing a recorded field back does not re-create matter.

## Three commitments

- **One platform that lasts.** The frame, the coordinate system, the calibration tools and the file formats stay fixed. Modules are replaced as better ones arrive, and some are made by the machine ([Upgrade loop](upgrades.html#one-enduring-platform)).
- **Least human time.** Simulation and the [digital twin](digital-twin.html) do the searching and checking. People do the building, the alignment and the buying decisions.
- **More function from each part.** One glass plate that carries many wave shapes replaces hundreds of separate sources. A laser that is its own detector replaces a camera.

## Two machines

**The Desktop Replicator** is the first machine: a benchtop chamber with two glass plates, {{c:desktop_geometry.ports_per_plate}} piezo sound sources on each, a ring of {{c:mosquito_smi.total_ommatidia}} small lasers and ordinary microcontrollers. Everything in it can be bought or made in a workshop.

**[The long-term machine](ultimate-replicator.html)** replaces the wired sources with a [surface switched by light](acoustics.html#long-term-direction), and the digital controller with computing done by waves. Its components are Documented in published work. Putting them together is Open.

The first machine's electronics are scaffolding, not the architecture. [Architecture](architecture.html#long-term-architecture-and-the-desktop-replicator) sets the two side by side, one row per subsystem.

## How to read this handbook

| If you want to | Read |
|---|---|
| See the machine being designed | [Desktop Replicator](desktop-replicator.html) |
| Know what is real today | [Current state](status.html) |
| Look up a word | [Glossary](glossary.html) |
| Understand the whole system | [Architecture](architecture.html), then [Subsystems and interfaces](subsystems.html) |
| Trace a mechanism to published experiments | [Proven in the lab](evidence.html) |
| Go deep on one subsystem | [Acoustics](acoustics.html), [Optics](optics.html), [Electromagnetics](electromagnetics.html), [Compute, sensing and control](compute-control.html), [Cadence, memory and wave compute](cadence-memory.html), [Ideas from biology](biology.html) |
| Follow material through a build | [Manufacturing](manufacturing.html), then [Scan, recover and matter stores](matter-loop.html) |
| See the tooling | [Digital twin](digital-twin.html) and [Upgrade loop](upgrades.html) |
| See what changed the design | [Insight register](insights.html) |
| Work on the project | [Agent entry point](agents.html) |
| Read the theoretical framework | [Physics overview](physics.html) |
| Find where an earlier paper's content went | [Research library](research.html#where-each-paper-went) |

Every claim carries an evidence label, such as Design decision, Derived, Simulated or Open. The definitions are in [Current state](status.html#evidence-labels).
