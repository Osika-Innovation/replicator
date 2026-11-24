# Start here

The Replicator is a machine that builds objects by holding and moving material with fields instead of tools. Sound waves carry and position material, light inspects it and addresses fine detail, and electric and magnetic fields act on materials that respond to them. The work happens in one chamber with no nozzle, no robot arm and no moving stage.

The programme has one long-term aim: a machine that makes an increasing share of the parts of its own successor.

## What exists today

The current work is:

- a parametric CAD model of the first machine, the [Desktop Replicator](desktop-replicator.html);
- simulations of its acoustic field, its sensors and its controller;
- a research library of the published work the design relies on;
- this handbook, which is the current explanation of all of it.

[Current state](status.html) lists each area with its evidence and what blocks the next step.

## What the machine does

A build repeats four steps inside the chamber.

1. **Scan.** Find out what is in the chamber. Sound sent from the plates and laser beams crossing the chamber are both changed by any object in their path, and the changes are turned into a description of the object.
2. **Assemble.** Shape the sound field into small pockets that hold material, move the pockets to carry material into place, and join it there.
3. **Check.** Compare what is there with what was intended, continuously, with the same sensors.
4. **Recover.** Take apart what is wrong or no longer needed and return the material to storage.

Steps 1 and 3 are the best understood. Joining and recovery are the least: neither has a complete recipe yet. [Manufacturing](manufacturing.html) and [Scan, recover and matter stores](matter-loop.html) say exactly what is and is not shown.

## Three commitments

**One platform that lasts.** The frame, coordinate system, calibration tools and file formats stay fixed. Modules are replaced as better ones become available, some of them made by the machine. Nothing is built as a throwaway rig.

**Least human time.** Simulation and the digital twin do the searching, the tolerance analysis and the checking. People do the physical building, the alignment and the purchasing decisions. Every choice is judged by how many hands-on minutes it costs to reach the next measured capability.

**More function from each part.** A glass plate that carries waves of many shapes replaces an array of hundreds of separate sources. A laser that is its own detector replaces a camera. Geometry and wave physics are used in place of parts wherever they can be.

## Two horizons

The handbook describes two machines and keeps them apart.

**The Desktop Replicator** is the first machine: a benchtop chamber with two glass plates, {{c:desktop_geometry.ports_per_plate}} piezo sources on each, a ring of {{c:mosquito_smi.total_ommatidia}} small lasers and ordinary microcontrollers. Everything in it can be bought or made in a workshop. [Desktop Replicator](desktop-replicator.html) describes it in full.

**The long-term architecture** replaces the wired sources with a surface of roughly 100,000 elements switched by light, and the digital controller with computing done by waves themselves. Its components exist in the published literature; the machine does not.

The microcontrollers and discrete lasers of the first machine are scaffolding. They are not the architecture. [Architecture](architecture.html) sets the two side by side, one row per subsystem.

## How to read this handbook

| If you want to | Read |
|---|---|
| Trace every cornerstone mechanism to peer-reviewed lab experiments | [Proven in the lab](evidence.html) |
| See the machine being designed | [Desktop Replicator](desktop-replicator.html) |
| Know what is real today | [Current state](status.html) |
| Look up a term | [Glossary](glossary.html) |
| Understand the whole system | [Architecture](architecture.html) |
| Go deep on one subsystem | [Acoustic bodies](acoustics.html), [Optics and metamaterials](optics.html), [Electromagnetic control](electromagnetics.html), [Compute, sensing and control](compute-control.html), [Cadence, memory and wave compute](cadence-memory.html), [Ideas from biology](biology.html) |
| Follow material through a build | [Manufacturing](manufacturing.html), then [Scan, recover and matter stores](matter-loop.html) |
| See the tooling | [Digital twin](digital-twin.html) and [Upgrade loop](upgrades.html) |
| See what changed the design, and what is unresolved | [Insight register](insights.html) |
| Work on the project as an engineer or an AI agent | [Agent entry point](agents.html) |
| Read the theoretical framework | [Physics overview](physics.html) |

The handbook is the current explanation. The papers in the [research library](research.html) are kept as the record of how each mechanism was worked out; several of them describe earlier designs and say so.

## How claims are labelled

Each claim is a design decision, documented in published work, derived, simulated, measured, open or an unverified claim. The definitions are in [Current state](status.html#evidence-labels).
