# Glossary

Plain definitions of the terms used in this handbook. Where a term has a chapter, the definition links to it.

## The machine

| Term | Meaning |
|---|---|
| Replicator | The programme's machine concept: material is held, moved, joined and inspected by fields in one chamber, with no tools inside it. |
| Desktop Replicator | The first machine being designed, a benchtop chamber built from purchasable parts. See [Desktop Replicator](desktop-replicator.html). |
| Long-term architecture | The design the programme is working toward, with a light-switched surface of about 100,000 elements and wave-based computing. Also called the ultimate architecture. |
| Work volume | The space between the two plates where material is held and built. |
| Two-zone stack | The layout shared by every size of the machine: a build cylinder above, a plinth below, a mid-plane between. See [Architecture](architecture.html). |
| Build cylinder | The upper zone: the two plates, the glass wall, the optical ring and the work volume. |
| Mid-plane | The plane between the two zones. It reflects sound back into the build cylinder and lets material through from the plinth. |
| Plinth | The lower zone: material store, release and reclaim, power, clock and compute. |
| Interface control matrix | A table with every subsystem on both axes; each cell names the contract for what one sends the other. See [Subsystems and interfaces](subsystems.html#interface-control-matrix). |
| Wafer, plate | One of the two thin glass discs that radiate sound into the chamber. In the Desktop Replicator each is Ø{{c:desktop_geometry.wafer_diameter_mm}} mm and {{c:desktop_geometry.wafer_thickness_mm}} mm thick, with no holes. |
| Plate spacing, gap | The distance between the two plates: {{c:desktop_geometry.gap_mm}} mm. |
| Port, source | One piezo disc bonded to a plate. There are {{c:desktop_geometry.ports_per_plate}} per plate. |
| `boro12` | A small configuration with Ø{{c:desktop_geometry.boro12_reducer_wafer_mm}} mm wafers for early experiments. |
| Crucible | An open container inside the chamber that holds feedstock: one each for powder, liquid and seed parts. |
| Head board | The circuit board directly behind each plate. It drives and reads that plate's sources. |
| Backplane | The circuit board in the base that holds the clock, power conversion and the compute card socket. |
| Compute card | A plug-in card that runs the pattern network. It can be exchanged without changing the rest of the machine. |
| Prototype scaffolding | The microcontrollers, comparators and discrete lasers of the first machine. They are a means of getting started, not the long-term design. |

## Acoustics

| Term | Meaning |
|---|---|
| Piezo, PZT-8 | A ceramic that changes shape when a voltage is applied and produces a voltage when it is strained. PZT-8 is a hard, low-loss grade. |
| Bending wave, flexural wave | A wave in which a thin plate flexes. Its speed depends on frequency, which is why a few sources and a few tones can produce many different patterns. |
| Dispersion | The dependence of wave speed on frequency. |
| Tone comb | The set of drive frequencies used together: {{c:desktop_geometry.comb_tones_hz|khz}} kHz. All are multiples of the lowest. |
| Acoustic radiation force | The steady force a sound field exerts on a small object. It pushes most solids toward places where the pressure swing is smallest. |
| Gor'kov potential | The standard formula for the radiation force on a particle much smaller than the wavelength. |
| Trap, well | A pocket in the sound field where the radiation force holds an object. An unwanted well is one the field creates where none was intended. |
| Standing wave | The stationary pattern formed when sound travelling in opposite directions overlaps. |
| Chord | One complete set of drive amplitudes and phases, across all sources and tones, that produces a chosen field in one chamber. It is compiled from a holographic equation and is not the stored record. |
| Self-sensing | Reading the reaction of the plate on the same two wires that drive a source, so that each source is also a receiver. The project's name for this circuit is HAPTIC. |
| Ring-down | The time a plate or the chamber keeps sounding after the drive stops. |
| Q, quality factor | How long a resonance rings, counted in cycles. High Q means a narrow, slowly decaying resonance. |
| Plate response, body response | The file that states how each source's drive turns into motion of the plate surface, at each tone. Planning uses it to compute fields. |
| Solid finite-element model | A three-dimensional numerical model of the wafer, piezo discs and rim seal, used to check the simpler plate model. |

## Sensing and optics

| Term | Meaning |
|---|---|
| Sigma-delta converter, 1-bit converter | A converter that samples one bit very fast and averages. Here it samples at {{c:haptic_pzt.sigma_delta_fs_hz|mhz}} MHz. |
| Oversampling ratio | Sampling rate divided by twice the signal bandwidth. Higher ratios give finer resolution. |
| Spurious-free dynamic range | The gap, in decibels, between the wanted signal and the largest unwanted product. The acceptance gate is {{c:haptic_pzt.sfdr_gate_min_db}} dB. |
| Lock-in detection | Extracting the amplitude and phase of a signal at a known frequency by comparing it with a reference at that frequency. |
| Self-mixing interferometry (SMI) | Using a laser diode as its own detector: light returned from a target disturbs the laser, and the built-in photodiode reads the disturbance. |
| LightRead | Measuring sound with light: pressure changes the refractive index of air, which shifts the phase of a laser beam that crosses it. |
| Laser ring | The {{c:mosquito_smi.total_ommatidia}} self-mixing lasers that look across the chamber. Nicknamed the mosquito eye. |
| Occlusion | The drop in returned light when an object blocks a beam. It gives a shadow image. |
| Acousto-optic effect | Sound changes the density of air and so its refractive index. A beam crossing a sound field picks up a small phase ripple, which is how light can measure sound. |
| Retro-reflector | A surface that sends light back the way it came. |
| Toroidal pulse | A short doughnut-shaped electromagnetic pulse whose shape in space and in time cannot be separated. Sometimes called a flying doughnut. |
| Metasurface | A surface patterned at a scale below the wavelength so that it shapes a wave passing through or reflecting from it. |

## Control and computing

| Term | Meaning |
|---|---|
| Cadence | The project's pattern network. Given the sensed state and a target, it settles on a chord. See [Cadence, memory and wave compute](cadence-memory.html). |
| Prime | The project's model, built on the Cadence library: it reads the chamber's state from echoes and chooses the drive for a goal. See [Subsystems and interfaces](subsystems.html#s09-prime-world-model). |
| Equilibrium propagation | A way of training a network that settles to an equilibrium, using only quantities available locally at each connection. |
| Hermitian, reciprocal | A property of the network's weights that mirrors a physical fact: a wave path works the same in both directions. |
| Sparse network | A network in which most weights are removed. The target here keeps {{c:cadence_brain.target_block_sparsity_range|pct}} % so that it fits in {{c:cadence_brain.cadence_sparse_max_kb}} kB. |
| Settle time | The time the network takes to reach its answer. |
| Holographic equation | The stored description of an object, independent of any one machine. It holds the sound field the object needs around it and how the object scatters sound. Each machine compiles it through its own calibration. See [Compute, sensing and control](compute-control.html#holographic-equations). |
| HLEQ | The short goal packet sent to the on-board network for one object, about 1.5 kB for a six-stroke job. |
| LMQ8 | The chamber's calibration as the on-board network uses it, held in memory and replaced after every calibration. |
| `.holo` | The file that holds a holographic equation (format `holo-eq`). |
| Stroke | One step of a holographic equation: one field to apply for a stated time. |
| `.pattern` | An earlier file format that stored chords for one chamber. Superseded as the store by the holographic equation. |
| `.fcode` | The file format for a machine job: a sequence of operations for the machine to carry out. |
| Machine interface | The software boundary between the planner and the machine, the same for a simulated and a real machine. In code it is called `MachineBackend`. |
| Digital twin | The software model of the machine: geometry, field solvers and the machine interface. See [Digital twin](digital-twin.html). |
| Wave computing | Computing with the physical settling of waves in a medium in place of digital arithmetic. A long-term direction. |
| Holographic memory | Storing many patterns as overlapping interference patterns in one volume of material. A long-term direction. |

## Process

| Term | Meaning |
|---|---|
| Scan | Working out what is in the chamber from how it changes sound and light. |
| Assemble | Carrying material into place and joining it. |
| Consolidate, join | Turning placed material into one solid piece. |
| Recover, remove, dissolve | Taking joined material apart and returning it to storage. |
| Bond state | A record of whether material at a location is joined. Removal has to lower it before anything can move. |
| Coherent perfect absorption | Choosing a drive so that no energy is reflected and all of it is absorbed at a target. The time-reverse of a laser. |
| Stores | The stock of material the machine draws on, kept in chemically stable forms. |
| Upgrade graph | The plan that links purchased seed parts to machine-made upgrades, with no upgrade depending on itself. See [Upgrade loop](upgrades.html). |

## Evidence and project terms

| Term | Meaning |
|---|---|
| Evidence label | One of: design decision, documented, derived, simulated, measured, open, claim. Defined in [Current state](status.html#evidence-labels). |
| Gate | A check that must pass before the next step. A model gate is run in software. A release gate controls purchasing. |
| Receipt | A saved record of a check: what was run, on which revision, and the result. |
| Insight | A finding that changes a design number or rules out an approach. See [Insight register](insights.html). |
| Lane | An area of ownership among the people and agents working on the project. See [Agent entry point](agents.html). |
| Shared constants | The single file of design numbers read by firmware, simulation, CAD and this handbook. |
| Retired baseline | An earlier design that is no longer developed. The list is in [Desktop Replicator](desktop-replicator.html#what-this-design-replaced). |
