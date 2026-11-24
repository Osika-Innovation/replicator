# Glossary

Plain definitions of the terms used in this handbook. A linked term opens the guide that explains it.

## The machine

| Term | Meaning |
|---|---|
| [Replicator](start.html) | The programme's machine concept: fields hold, move, join and inspect material in one chamber, with no tools inside it. |
| [Desktop Replicator](desktop-replicator.html) | The first machine being designed, a benchtop chamber built from purchasable parts. |
| [Long-term architecture](architecture.html#long-term-architecture-and-the-desktop-replicator) | The design the programme is working toward, with a light-switched surface of about 100,000 elements and wave-based computing. Also called the ultimate architecture. |
| [Prototype scaffolding](architecture.html#long-term-architecture-and-the-desktop-replicator) | The microcontrollers, comparators and discrete lasers of the first machine: a way to get started, not the long-term design. |
| [Two-zone stack](architecture.html) | The layout shared by every size of the machine: a build cylinder above, a plinth below, a mid-plane between. |
| Build cylinder | The upper zone: the two plates, the glass wall, the optical ring and the work volume. |
| Work volume | The space between the two plates where material is held and built. |
| [Mid-plane](subsystems.html#s03-mid-plane-interface) | The plane between the two zones. It reflects sound back into the build cylinder and lets material through from the plinth. |
| [Plinth](subsystems.html#s02-storage-and-release-plinth) | The lower zone: material store, release and reclaim, power, clock and compute. |
| [Glass cylinder](desktop-replicator.html) | The stock glass tube that closes the chamber and lifts with the head. |
| [Wafer, plate](acoustics.html#in-the-desktop-replicator) | One of the two thin glass discs that radiate sound into the chamber: Ø{{c:desktop_geometry.wafer_diameter_mm}} mm, {{c:desktop_geometry.wafer_thickness_mm}} mm thick, with no holes. |
| Plate spacing, gap | The distance between the two plates: {{c:desktop_geometry.gap_mm}} mm. |
| [Port, source](subsystems.html#s04-acoustic-array) | One piezo disc bonded to a plate. There are {{c:desktop_geometry.ports_per_plate}} per plate. |
| `boro12` | A small configuration with Ø{{c:desktop_geometry.boro12_reducer_wafer_mm}} mm wafers for early experiments. |
| [Crucible](matter-loop.html) | An open container inside the chamber that holds feedstock: one each for powder, liquid and seed parts. |
| [Head board](compute-control.html#in-the-desktop-replicator) | The circuit board directly behind each plate. It drives and reads that plate's sources. |
| Backplane | The circuit board in the base that holds the clock, power conversion and the compute card socket. |
| [Compute card](compute-control.html#central-complex-sparse-complex-hermitian-cadence-and-the-swappable-brain-slot) | A plug-in card that runs the pattern network and can be exchanged without changing the rest of the machine. |
| [Interlock](subsystems.html#s11-thermal-and-safety) | A hardware safety switch in series with the bridge-enable supply and the laser supply: with the head up, the bridges float and the lasers are off. Firmware also refuses to drive. |
| [Interface control matrix](subsystems.html#interface-control-matrix) | A table with every subsystem on both axes, where each cell names the contract for what one sends the other. |

## Sound

| Term | Meaning |
|---|---|
| Piezo, PZT-8 | A ceramic that changes shape under a voltage and makes a voltage when strained. PZT-8 is a hard, low-loss grade. |
| Phase | The timing of a wave within its cycle. |
| Decibel (dB) | A scale that counts in powers of ten: 3 dB is half the power, 10 dB a tenth, 20 dB a hundredth. |
| Acoustic impedance | How hard a material resists being moved by sound. Sound bounces off where it changes sharply, as between ceramic and air. |
| [Bending wave, flexural wave](acoustics.html#bending-waves-in-a-plate) | A wave in which a thin plate flexes. |
| Dispersion | Wave speed that depends on frequency, which is why a few sources and tones make many different plate patterns. |
| Coincidence frequency | The pitch above which a bending wave in a plate outruns sound in air, so the plate radiates well. |
| [Tone comb](acoustics.html#in-the-desktop-replicator) | The drive frequencies used together: {{c:desktop_geometry.comb_tones_hz|khz}} kHz, all whole multiples of the lowest. |
| [Standing wave](acoustics.html#why-two-plates) | The still pattern formed when sound travelling in opposite directions overlaps. |
| Node | A quiet spot in a standing wave, where the pressure hardly changes. |
| [Acoustic radiation force](acoustics.html#the-radiation-force-and-where-traps-sit) | The steady force a sound field exerts on a small object. It pushes solids and liquids in air toward the quiet spots. |
| Gor'kov potential | The standard formula for the radiation force on a particle much smaller than the wavelength. |
| Contrast factor | A number comparing a particle's squashiness or density with the air's. The two together decide whether it goes to quiet or loud spots. |
| Trap, well | A pocket in the sound field where the radiation force holds an object. An unwanted well is one nobody asked for. |
| [Hologram](acoustics.html#what-a-sound-hologram-is) | A record of a wave's loudness and timing on a surface, enough to rebuild the wave. |
| Sample budget | The most independent values a plate can hold at one tone: one per half-wavelength square. |
| [Control rank](acoustics.html#known-limits) | The number of independent field patterns the sources can make at one tone. It cannot exceed the number of sources. |
| [Effective rank](acoustics.html#how-a-field-is-scored) | The number of clearly different sound fields the sources can make above the noise. |
| [Fresnel number](acoustics.html#why-two-plates) | Plate radius squared, divided by wavelength times gap. Well above 1 a beam can be aimed across the gap; near 1 the wave fills the chamber. |
| [Gap resonance](acoustics.html#the-chamber-as-a-resonator) | The chamber is loudest when the gap is a whole number of half-wavelengths, so the gap has to follow the air temperature. |
| End reflection | The share of sound that an end of the chamber sends back. The lift needs at least 0.85. |
| [Chord](cadence-memory.html#holographic-memory-two-layers-and-chords-not-bits) | One complete set of drive amplitudes and phases, across all sources and tones, that makes a chosen field in one chamber. |
| [Self-sensing](acoustics.html#simultaneous-two-terminal-haptic-self-sensing) | Reading the plate's reaction on the same two wires that drive a source, so each source is also a receiver. The project calls the circuit HAPTIC. |
| Q, quality factor | How long a resonance rings, counted in cycles. High Q means a narrow, slowly fading resonance. |
| Ring-down | The time a plate or the chamber keeps sounding after the drive stops. |
| Bode–Fano limit | A resonant part can couple strongly or over a wide band, not both. |
| [Acoustic streaming](acoustics.html#drive-strength-and-lift) | A slow steady wind made by sound that the air absorbs. |
| [Parametric array](acoustics.html#handles-not-yet-used) | Two loud ultrasonic beams that make a lower tone only where they overlap. |
| Vortex beam | A beam of sound or light whose phase winds round its axis, so it carries twist and can spin an object. |
| Sticky layer (viscous boundary layer) | The thin layer of air slowed by friction next to a wall, 5 to 12 micrometres thick at the drive tones. |
| [Plate response, body response](digital-twin.html#the-plate-response-file) | The file that states how each source's drive turns into motion of the plate surface at each tone. The current version is `body-response/0.2`. |
| [Solid finite-element model](acoustics.html#the-plate-model) | A three-dimensional numerical model of the wafer, piezo discs and rim seal, used to check the simpler plate model. |

## Sensing and light

| Term | Meaning |
|---|---|
| [Sigma-delta converter, 1-bit converter](compute-control.html#acoustic-lamina-75-msas-1-bit-sigma-delta-piezo-haptic) | A converter that samples one bit very fast ({{c:haptic_pzt.sigma_delta_fs_hz|mhz}} MHz here) and averages. It failed its simulated {{c:haptic_pzt.sfdr_gate_min_db}} dB test and was replaced by a 16-bit converter ({{c:haptic_pzt.adc_fallback_mpn}}). |
| Oversampling ratio | Sampling rate divided by twice the signal bandwidth. Higher ratios give finer resolution. |
| [Lock-in detection](compute-control.html#in-the-desktop-replicator) | Finding the amplitude and phase of a signal at a known frequency by comparing it with a reference at that frequency. |
| [Self-mixing interferometry (SMI)](optics.html#coherent-self-mixing-optical-readout) | Using a laser diode as its own detector: light returned from a target disturbs the laser, and the built-in photodiode reads the disturbance. |
| [Laser ring](optics.html#in-the-desktop-replicator) | The {{c:mosquito_smi.total_ommatidia}} self-mixing lasers that look across the chamber. Nicknamed the mosquito eye. |
| Retro-reflector | A surface that sends light back the way it came. |
| [Acousto-optic effect](architecture.html#two-carriers-five-wavelength-decades-and-volume-crossings) | Sound changes the density of air and so how much the air bends light, which lets a light beam measure sound. |
| [LightRead](optics.html) | The project's name for measuring sound with the laser ring through the acousto-optic effect. |
| [Photoacoustic effect](architecture.html#two-carriers-five-wavelength-decades-and-volume-crossings) | Absorbed light heats a spot, the spot swells, and the swelling launches sound. |
| [Brillouin scattering](architecture.html#two-carriers-five-wavelength-decades-and-volume-crossings) | Light bouncing off a sound wave and shifting in frequency by the sound's frequency. |
| [Optical tweezer](optics.html#long-term-direction) | A tightly focused light beam that holds a tiny clear particle at its brightest point. |
| [Toroidal pulse](optics.html#toroidal-optical-pulses) | A short doughnut-shaped electromagnetic pulse whose shape in space and in time cannot be separated. |
| [Skyrmion number](optics.html#topological-labels) | A whole number that counts how many times a field pattern wraps around. Small disturbances cannot change it gradually. |
| [Metasurface](optics.html#long-term-direction) | A surface patterned more finely than the wavelength so that it shapes a wave passing through or reflecting from it. |

## Control and computing

| Term | Meaning |
|---|---|
| [Prime](subsystems.html#s09-prime-world-model) | The project's model, built on the Cadence library. It reads the chamber's state from echoes and chooses the drive for a goal. |
| [Cadence](cadence-memory.html#the-cadence-wave-equilibrium-model-eqprop) | The library that Prime is built on: a pattern network that settles on an answer. |
| Equilibrium propagation | A way of training a settling network using only quantities available locally at each connection. |
| Hermitian, reciprocal | A property of the network's weights that mirrors a physical fact: a wave path works the same in both directions. |
| Sparse network | A network with most weights removed. The target keeps {{c:cadence_brain.target_block_sparsity_range|pct}} % so that it fits in {{c:cadence_brain.cadence_sparse_max_kb}} kB. |
| Settle time | The time the network takes to reach its answer. The design target is {{c:cadence_brain.rp2350_settle_target_ms_range|range}} ms. |
| [Holographic equation](compute-control.html#holographic-equations) | The stored description of an object, independent of any one machine: the sound field it needs around it and how it scatters sound. Each machine compiles it through its own calibration. |
| `.holo` | The file that holds a holographic equation (format `holo-eq`). |
| Stroke | One step of a holographic equation: one field to apply for a stated time. |
| HLEQ | The short goal packet sent to the on-board network for one object, about 1.5 kB for a six-stroke job. |
| LMQ8 | The chamber's calibration as the on-board network uses it, replaced after every calibration. |
| `.pattern` | An earlier file format that stored chords for one chamber. The holographic equation replaced it. |
| [`.fcode`](compute-control.html#compiler-wire-contract-machinebackend-fcode-and-ring-0-parity) | The file format for a machine job: a list of operations for the machine to carry out. |
| [Machine interface](compute-control.html#compiler-wire-contract-machinebackend-fcode-and-ring-0-parity) | The software boundary between the planner and the machine, the same for a simulated and a real machine (`MachineBackend` in code). |
| [Digital twin](digital-twin.html) | The software model of the machine: geometry, field solvers and the machine interface. |
| [Wave computing](cadence-memory.html#compute-substrate-ladder-from-prototype-sram-to-near-zero-electricity-wave-media) | Computing with the physical settling of waves in a medium in place of digital arithmetic. A long-term direction. |
| [Holographic memory](cadence-memory.html#holographic-memory-two-layers-and-chords-not-bits) | Storing many patterns as overlapping interference patterns in one volume of material. A long-term direction. |

## Process

| Term | Meaning |
|---|---|
| [Scan](matter-loop.html#scan-non-moving-3d-tomography-and-scattering) | Working out what is in the chamber from how it changes sound and light. |
| [Assemble](manufacturing.html) | Carrying material into place and joining it. |
| [Consolidate, join](manufacturing.html#consolidation) | Turning placed material into one solid piece. |
| [Recover, remove, dissolve](matter-loop.html#recover-dissolve-material-specific-separation-and-reuse) | Taking joined material apart and returning it to storage: sound is absorbed at a measured resonance, then the loosened material is carried to a crucible. |
| [Coherent perfect absorption](ultimate-replicator.html) | Choosing a drive so that no energy is reflected and all of it is absorbed at a target. The time-reverse of a laser. |
| [Stores](matter-loop.html#the-stores-equation-library-vs-matter-pantry) | The stock of material the machine draws on, kept in chemically stable forms. |
| [Upgrade graph](upgrades.html) | The plan that links purchased seed parts to machine-made upgrades, with no upgrade depending on itself. |

## Evidence and project terms

| Term | Meaning |
|---|---|
| [Evidence label](status.html#evidence-labels) | One of: design decision, documented, derived, simulated, measured, open, claim. |
| [Gate](digital-twin.html#what-each-kind-of-check-proves) | A check that must pass before the next step. A model gate runs in software; a release gate controls purchasing. |
| Receipt | A saved record of a check: what was run, on which revision, and the result. |
| [Insight](insights.html) | A finding that changes a design number or rules out an approach. |
| [Lane](agents.html#lanes) | An area of ownership among the people and agents working on the project. |
| Shared constants | The single file of design numbers read by firmware, simulation, CAD and this handbook. |
| [Retired baseline](desktop-replicator.html#what-this-design-replaced) | An earlier design that is no longer developed. |
