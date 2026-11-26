# The engineering twin

The digital twin is the machine in software: the solid model, the field solvers and the same machine interface that real hardware uses. A job that runs on the emulated machine is meant to run unchanged on a built one. Every result the twin produces is Derived or Simulated.

## Two code bases

| | The twin (the machine in software) | The workbench (simulation and training) |
|---|---|---|
| Built with | One Swift and Metal package, no third-party dependencies | Python on Apple's MLX array library |
| Holds | The parametric solid model of the [Desktop Replicator](desktop-replicator.html), the sound-field and force solvers, and the [machine interface](compute-control.html#one-contract-files-verbs-and-the-machine-interface) (`MachineBackend`) | Training of Prime, the project's model built on the Cadence library; models of the two sensing paths; design searches; file encoders |
| Run with | `fieldc`; tests with `fieldc test` | `python3 -m holo.verify` |

They share three file formats: `.fcode` for a job, `.holo` for a [holographic equation](compute-control.html#holographic-equations), and the [plate-response file](#the-plate-response-file). In the twin, the field, the particles and the picture share graphics memory, so nothing is copied to be shown (Design decision).

## The physics the solver rests on

Nobody can look at twelve drive values and see what shape they hold. The compiler therefore computes and scores the field its own output would make (Design decision).

Air behaves linearly at the sound levels used: doubling the drive doubles the pressure. So the best drive can be found with standard matrix methods, not by trial.

- The pressure at any point is a fixed table times the drive values: p = H(f) u.
- The steady push on a small particle comes from a hill-and-valley map, the Gor'kov potential ([Acoustics](acoustics.html#the-radiation-force-and-where-traps-sit)). Doubling every drive gives four times the force.
- Powder in air is heavily damped. Each grain feels the sound force, its weight, air drag and its neighbours. It drifts downhill in that map and collects in the valleys.

**The patch sum (the textbook baffled-piston sum).** Each radiating face is cut into flat patches no wider than half a wavelength in air. Each patch adds a pressure that falls off as one over distance, turns in phase once per wavelength, and is weaker off to the side. Four rules come with it (Derived).

- **The table is reusable.** Summed over all points and sources this is H, computed once per geometry and tone.
- **The backward map is free.** Going from field error back to drive change is the conjugate transpose of H, exactly.
- **Take slopes from the formula, not the grid.** Numerical slopes taken twice make the trap jitter.
- **It is an open-air model.** It does not know about the held object or any other scatterer.

**Left out on purpose (Open).** Shocks, and steady air currents driven by the sound ([acoustic streaming](acoustics.html#known-limits)). At the pressures a solid bead needs, both may matter.

## Solver tiers

No one solver is both exact and quick, so the twin keeps several and ties them together with checks (Design decision). Times are from a workstation, for an earlier, larger chamber (Simulated).

| Tier | What it computes | Typical time | Used for | What it leaves out |
|---|---|---|---|---|
| Patch sum | Sound from every plate patch, through the table H | Milliseconds | Live views; inside the search for a drive | Sound bouncing off the workpiece |
| Boundary elements | Sound on the surface of a rigid object | 0.1 to 2 s | Compiling around an object | Sound inside the object |
| Time-stepping grid | Pressure and air velocity stepped forward on a grid of cells | 10 to 60 s | Echoes, ring-down; the reference for the faster tiers | Nothing in linear sound, but it is slow |
| Steady-tone series | One steady tone, by repeated fast Fourier transforms | 1 to 4 s | A steady field at one tone | Ring-down; slow to converge for a hard object in air |

A fast tier is trusted only while it matches the slow tier ([checks](#what-each-kind-of-check-proves)). Ring-down needs the time-stepping tier: a steady-state solver cannot produce a decay. The Desktop Replicator results in this handbook come from steady single-tone solvers.

**Sizing a time-stepping run (Derived).** Cells are one fifth of the shortest wavelength. The time step shrinks with the fastest sound speed in the grid, so steel cuts it 17 times against air alone. Walls need a damping layer about 16 cells thick, or the box never stops ringing. Cost grows with the fourth power of frequency. For a box of air {{c:desktop_geometry.gap_mm}} mm tall and 250 mm square and 35 ms of sound, at the workstation's 10¹⁰ cell updates per second:

| Tone | Cell size | Cells | Run time | Memory |
|---|---|---|---|---|
| 32 kHz | 2.1 mm | 1.5 million | About 3 s | 0.02 GB |
| 160 kHz | 0.43 mm | 190 million | About 30 min | 3 GB |

The top tone is a batch job, so a run-time estimate should be shown before a run starts.

## Finding a drive

Three standard methods turn a wanted field into drive values, all through the table H (Design decision). Back-propagation sends the wanted phases backward through H and repeats; it is the fast baseline the others must beat. Gerchberg–Saxton works only on the few control points that matter and takes milliseconds; it is the usual choice for several traps. Gradient descent is slowest and most faithful, and can obey power and voltage limits.

**Limits go inside the search (Design decision).** Each channel's voltage ceiling and the clock's smallest phase step are applied on every pass ([drive stage](compute-control.html#drive-stage), [clock and timing](compute-control.html#clock-and-timing)). A drive that works only with unlimited precision is a fault that will come back on the machine.

**The emulator is imperfect on purpose.** It has adjustable gain and phase errors on each source, so the compiler runs the same calibration code it will use on a real chamber.

## Commands for the Desktop Replicator

| Command | What it does |
|---|---|
| `fieldc desktop check` | Runs the geometry checks on the solid model |
| `fieldc desktop export` | Writes the part meshes and drawings |
| `fieldc desktop step` | Writes an exact-geometry STEP file and compares it with the mesh |
| `fieldc desktop body` | Writes the plate-response file |
| `fieldc desktop electrical` | Writes the power budget and thermal estimate |
| `fieldc desktop render` | Renders views of the model |

```sh
swift build -c release
./.build/release/fieldc test
./.build/release/fieldc desktop check --rules
```

The package still holds two earlier configurations, a large two-plate column and the retired P0 transducer array. Their results do not describe the Desktop Replicator. Controller [firmware source](compute-control.html#one-contract-files-verbs-and-the-machine-interface) passes its tests on a workstation and has not run on a board (Simulated).

## What each kind of check proves

A model that agrees with itself has proved nothing. Every check compares the twin with something outside it (Design decision). The pass bars are those of the earlier software specification.

| Check | Compared with, and pass bar | Shows | Does not show |
|---|---|---|---|
| Shape to cells | Sphere volume formula, within 2 % | Geometry is read correctly | Anything about sound |
| Energy | Conservation in a loss-free box: drift under 1 % over 10,000 steps | The time-stepper is stable and not leaking | That loss is modelled correctly |
| Travel time | 2 × plate spacing ÷ sound speed, within 2 % | Speed and grid size are right | Amplitude |
| Standing wave | Node spacing of half a wavelength, within 1 % | Reflections and phase are right | Force |
| Sphere echo | Exact textbook solution for a rigid sphere: five lowest resonances within 3 % | Scattering is right for one simple shape | Other shapes; real materials |
| Fast tier against slow tier | The time-stepper's steady field, under 5 % difference | The quick solver can be trusted in an empty chamber | That either matches a real chamber |
| Force | The closed-form standing-wave force ([Acoustics](acoustics.html#the-radiation-force-and-where-traps-sit)), within 2 % | Sign and size of the force law | Large particles; moving air |
| Held bead | Node position from the formula, within one twentieth of a wavelength; stiffness within 5 % | The particle model settles where it should | Powder; several beads |
| File round trip | The same file, bit-exact | Nothing is lost on save and load | That the content is true |
| Second program | A separately written double-precision solver, difference under 10⁻³ | No coding slip in the fast routine | Shared wrong assumptions |

The order is a ladder: the fast routine matches a second program, then the emulator matches closed-form physics, and only then is it a design tool. No rung is a measurement on a machine ([evidence labels](status.html#evidence-labels)).

**Use someone else's solver as the second opinion.** A checker by the same author repeats the same mistake. The earlier specification named two: AcousTools (Documented: [Mukherjee et al.](https://doi.org/10.1109/tuson.2026.3659798)) and k-Wave (no catalogue entry). Whether the present twin is checked against either is Open.

**A miss on the wrong model blames the model (Simulated, earlier design).** An early run was nearly reported as "24 channels cannot focus". It had left out wall reflections, several tones, and scoring by force instead of pressure. Before reporting that something cannot work, check that the model contains the thing tested. A pass on a model that leaves out a loss proves as little.

### What the CAD checks cover, and what they do not

The checks confirm that the solid model agrees with itself: every part is a closed solid whose mesh volume matches its closed-form volume; clearances are met and no parts overlap; the envelope and plate positions match the stated dimensions; the piezo positions are the coordinates the field solver drives; the exact-geometry STEP export matches the mesh in volume, part by part; and the power budget keeps the internal air temperature rise within its limit.

The current model passes. The power and thermal figures (Derived from assumed datasheet values): 17.0 W with the first compute card, 22.5 W with the second, and the warmest internal air 12.7 K above ambient against a 20 K limit ([Heat](desktop-replicator.html#heat)).

**The checks do not show that the machine works:** that the plates make a usable field, that a particle is held, that the sensing paths have enough signal, or that the parts can be bought and assembled. Those need a measurement on a machine.

## The plate-response file

The plate-response file is the hand-over between a model of the plates and everything that uses them. One file describes both plates. Its format is `body-response/0.2`; the exact fields are in [Subsystems and interfaces](subsystems.html#contracts). It contains:

- the plate spacing and the fraction of sound the faces reflect;
- patches (small flat pistons that sample each radiating face), inputs (the piezo drive ports, each with a maximum drive) and frequencies;
- for each frequency, input and patch, the complex surface velocity of that patch per unit drive;
- the receive path: how each input responds when the plates listen;
- an uncertainty in gain and phase, and provenance: whether the numbers are made up for testing, simulated or measured.

The solver, the calibration routine, the job planner and the emulator all read the plates from this file, so a measurement in the same format can replace a model without changing the software.

**What version 0.2 changed.** Version 0.1 had no receive path and accepted any patch spacing. Version 0.2 adds the receive path. It refuses an export whose patches are further apart than half a wavelength in air at the top tone, because the piston model then gives false patterns (aliasing). The drive tones are {{c:desktop_geometry.comb_tones_hz|khz}} kHz, and at the highest, half a wavelength is about 1 mm (Derived). The version 0.1 export had 96 patches per plate about 15 mm apart, so fields computed from it were aliased.

**Limits that remain.**

- *No electrical quantities.* The response is per unit drive. Power, current and heat need the source impedance, which the file does not carry.
- *One frequency in practice.* The file and solver accept several, but calibration and jobs use only the first. Multi-tone operation cannot yet be evaluated end to end.
- *No coupling between inputs through the amplifier, nothing nonlinear, and only two flat faces with equal patch counts.*

**The shipped file does not match the solid model (Simulated).** It comes from a reduced closed-form plate model whose factor from drive voltage to patch velocity has no reference behind it. Absolute pressure, force and required drive from it are therefore not anchored (Open). A solid finite-element model of the wafer and its piezo discs, completed on 18 November 2026, contradicts it and puts the voltage needed to hold a solid polystyrene bead at several hundred volts per source. The response also shifts too much with small plate changes to be predicted, so the file for a real machine has to be measured in its chamber ([Acoustics](acoustics.html#known-limits)).

The shipped file records the {{c:desktop_geometry.gap_mm}} mm spacing in its data, but its provenance text still describes the earlier 120 mm geometry.

## Automated design search

The workbench scores candidate plate and chamber layouts on several tasks at once, such as carrying a particle through waypoints, and exports the winners as plate-response files. Its rankings are Simulated on the reduced plate model, which the solid model contradicts, so they are unverified. The rule is to anchor a plate family in the solid model before trusting a large sweep.

## Learning and control

The twin models only what the real machine can observe:

- the electrical state of each piezo disc while it drives, from the standard circuit model of a piezo resonator, with its capacitance drifting with temperature;
- along each of the {{c:mosquito_smi.total_ommatidia}} laser sightlines, the shadow of an object and the ripple that sound puts on the beam;
- holographic equations in the `.holo` format, and chords in the earlier `.pattern` format.

The optical-hardware twin (5-bit weights, phase jitter and photon noise) belongs to the same family of checks. Its zero-shot score on Prime-Core is 0.226 against 0.363 ideal ([Cadence guide](cadence-memory.html#training-and-checks-in-simulation), Simulated). The pattern network is scored against the direct physics solver under four levels of hardware realism ([Cadence, memory and wave compute](cadence-memory.html#training-and-checks-in-simulation)). On the microcontroller it must fit in under {{c:cadence_brain.cadence_sparse_max_kb}} kB. Its settle target is {{c:cadence_brain.rp2350_settle_target_ms_range|range}} ms (Design target); instruction counts give 4.4 to 6.1 ms (Derived). The simulation checks that must pass before any board is made are Open ([insight register](insights.html)).

**Removal.** REMOVE is modelled as absorption at a measured resonance, then transport to a crucible (Simulated). An earlier shortcut replayed a reversed holding pattern. It was wrong and has been taken out of the code ([why](matter-loop.html#why-reversing-a-holding-pattern-removes-nothing)).

## Show what is known

Every view and report keeps three layers apart: design intent, simulated prediction with its assumptions, and measurement. Raw observations stay distinct from anything reconstructed from them.

- **Three states, never two (Design decision).** A reconstructed point is seen and solid, seen and empty, or never seen. Averaging the last two draws a surface out of ignorance ([what a scan may claim](matter-loop.html#what-a-scan-is-allowed-to-claim)).
- **Draw doubt as doubt.** Show the chance that the surface passes through each point, in place of one hard surface (Documented: [Pöthkow &amp; Hege, 2011](https://doi.org/10.1109/TVCG.2010.247)). An exported surface carries the threshold used and how much of it was seen.
- **Show phase as motion.** Phase drawn as colour blends to grey when seen through a volume.

## Rules for the twin's own size

The twin's charter: one interface to the machine, no third-party dependencies, and a cap on source size that is lowered when code is deleted and never raised. The proposed cap is 17,500 lines of Swift and Metal. A count on 17 November 2026 found about 21,400, so it is not yet met.

Rules that keep it testable (Design decision):

1. **No logic in the screen code.** Every view is drawn from plain data, so any screen renders without a window.
2. **One core, two front ends.** Anything the app can do, a `fieldc` script can do.
3. **Repeatable on request.** One switch fixes the random seed, clock and window size.
4. **Every run leaves a record** of settings, code version, timings and each check's limit and verdict. A claim quotes a record.
5. **No check is loosened to pass.** A limit changes only in a change that alters nothing else and says why.
6. **A slow, plain copy of every fast routine,** compared on a tiny case. A run more than 20 % slower than its stored baseline fails.
7. **Source count is data,** read from the machine description, never a constant in code.

## Open questions

| Question | Who answers it |
|---|---|
| How is the shipped plate-response file replaced by one measured in the chamber, at fine enough patch spacing? | Twin software and calibration design |
| What patch spacing can the field solver afford at the highest tone? | Simulation and twin software |
| When do calibration and jobs use every tone? | Twin software |
| Is the twin checked against an independent published solver? | Twin software |
| Do shocks and acoustic streaming matter at the pressures a solid bead needs? | Simulation |
