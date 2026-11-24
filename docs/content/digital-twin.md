# The engineering twin

The digital twin is the software model of the machine. It holds the parametric CAD, the field solvers and the same machine interface that real hardware will use, so a job that runs on the emulated machine is meant to run unchanged on a built one. Every result the twin produces is Derived or Simulated.

## Two code bases

**`twin/` is the machine in software.** It is a single Swift and Metal package with no third-party dependencies. It contains three things: the parametric solid model of the Desktop Replicator, the solvers that compute the sound field and the force on a particle, and the machine interface (`MachineBackend`) through which every program talks to either the emulator or a controller. Its command-line tool is `fieldc`.

**`holo/` is the simulation and training workbench.** It is Python on Apple's MLX array library. It trains the pattern network (Cadence), simulates the two sensing paths (the piezo receive path and the laser ring), runs automated design searches over plate layouts, and encodes the job files and holographic equations. Its checks run with `python3 -m holo.verify`.

The two share file formats: `.fcode` for a job, `.holo` for a holographic equation (the stored description of an object), and the plate-response file described below.

## The physics the solver rests on

The air between the plates behaves linearly at the sound levels used. Three consequences make the solver compact:

- The pressure at any point is a linear function of the complex drive amplitudes: p = H(f) u.
- The time-averaged force potential on a small particle (the Gor'kov potential) is a quadratic form in the drive: U(x) = Σ_f g_fᴴ K_f(x) g_f, summed over the tones.
- Powder in air is heavily damped, so it drifts downhill in that potential and collects in basins that can be mapped directly.

Finding a drive for a target therefore becomes an eigenvalue or quadratic optimization problem, not a blind search. The solvers run on the graphics processor, and each is compared against a double-precision reference on the main processor before its result is accepted. The force law itself is explained in [Acoustics](acoustics.html).

## Commands for the Desktop Replicator

The active command family is `fieldc desktop`:

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

The package also still contains two earlier configurations, a large two-plate column and the retired P0 transducer array. Their results do not describe the Desktop Replicator. Controller firmware source for the Desktop Replicator now exists in `twin/Firmware/desktop/` and passes its tests on a workstation; it has never been built for or run on a board (Simulated).

## What the CAD checks cover, and what they do not

The checks confirm that the solid model is geometrically self-consistent:

- every part is a closed solid with positive volume;
- mesh volumes agree with closed-form volumes;
- stated clearances are met and no two parts overlap;
- the outside envelope and the plate positions match the stated dimensions;
- the piezo positions in the CAD model are the same coordinates the field solver drives;
- the exact-geometry STEP export agrees in volume, part by part, with the mesh;
- the power budget keeps the estimated internal air temperature rise within its limit.

The current model passes these checks. The power and thermal figures are Derived from assumed datasheet values.

**The checks say nothing about whether the machine works.** They do not show that the plates produce a usable field, that a particle is held, that the sensing paths have enough signal, or that the parts can be bought and assembled. Those are questions for the bench.

## The plate-response file

The plate-response file is the hand-over between a model of the plates and everything that uses the plates. Its format name is `body-response/0.1`. One file describes both facing plates.

It contains:

- the plate spacing and the fraction of sound the faces reflect;
- a list of patches, small flat pistons that sample each radiating face, with position and radius;
- a list of inputs (the piezo drive ports), each with a maximum drive and an optional settling time;
- a list of frequencies;
- for each frequency, input and patch, the complex surface velocity of that patch per unit drive;
- a stated uncertainty in gain and phase;
- a provenance block saying whether the numbers are made up for testing, simulated or measured, and from what.

The field solver, the calibration routine, the job planner and the emulated machine all read the plates from this file. A bench measurement in the same format could replace a model without changing the software.

### Limits of version 0.1

The interface document lists what the format and its users cannot yet do:

- **No receive path.** The file describes how the plates radiate, not how they listen.
- **No electrical quantities.** The response is per unit drive, not per watt. Power, current and heat need the source impedance, which the file does not carry.
- **One frequency in practice.** The file and the field solver accept several frequencies, but calibration and jobs use only the first. Multi-tone operation, which the design depends on, cannot yet be evaluated end to end.
- **No coupling between inputs through the amplifier, and nothing nonlinear.**
- **Only two flat faces with equal patch counts.**

### Two known defects in the exported file

**The exported file is spatially undersampled (Derived).** The interface document requires patches no further apart than half a wavelength in air at the highest frequency, or the piston model aliases the face. The drive tones are {{c:desktop_geometry.comb_tones_hz|khz}} kHz, and at the highest of them half a wavelength in air is about 1 mm. The exported Desktop Replicator file samples each plate with 96 patches about 15 mm apart. Fields computed from it are therefore aliased, and remain so until a finer export or the solid model replaces it.

**Absolute force levels are not anchored (Open).** The exported response comes from a reduced closed-form plate model. The factor that converts drive voltage into patch velocity in that model is a constant with no reference behind it. Patterns and relative comparisons may still be informative; absolute pressure, force and required drive are not. A three-dimensional solid finite-element model of the wafer and its piezo discs (Gmsh for meshing, CalculiX for solving) was completed on 18 November 2026 and contradicts the exported file: the two radiated fields correlate at 0.06, which is chance level, and the solid model puts the voltage needed to hold a solid polystyrene bead at several hundred volts per source. The plate response also shifts too much with small changes in the plate to be predicted, so the file for a real machine has to be measured in its chamber. [Acoustic bodies](acoustics.html#known-limits) gives the figures.

The exported file also records the {{c:desktop_geometry.gap_mm}} mm spacing in its data but still describes the earlier 120 mm geometry in its provenance text. Acoustic results for the earlier spacing do not carry over.

## Automated design search

The design search in `holo/` scores candidate plate and chamber layouts on several tasks at once, such as carrying a particle through waypoints and the number of independent field patterns a layout can make, then exports the winners as plate-response files. Its rankings are Simulated on the reduced plate model and inherit both defects above; since the solid model does not match that file, the rankings should be treated as unverified. The project's own rule is to anchor a plate family in the solid model before trusting a large sweep.

## Learning and control

The twin models the quantities the real machine will be able to observe, and no others:

- the electrical state of each piezo disc while it drives, using the standard equivalent circuit of a piezo resonator (Butterworth–Van Dyke), including the drift of its capacitance with temperature;
- along each of the {{c:mosquito_smi.total_ommatidia}} laser sightlines, the shadow cast by an object and the ripple that sound imposes on the beam;
- holographic equations in the `.holo` format, and chords in the earlier `.pattern` format.

The pattern network is compared with the direct physics solver under four levels of hardware realism: ideal floating point; the prototype microcontroller with 8-bit weights, its 1-bit converter at {{c:haptic_pzt.sigma_delta_fs_hz|mhz}} million samples per second, capacitance drift and laser noise; a sparse 8-bit programmable-logic card; and an analogue optical phase-change medium. The network must fit in under {{c:cadence_brain.cadence_sparse_max_kb}} kB and settle in {{c:cadence_brain.rp2350_settle_target_ms_range|range}} ms on the microcontroller. These comparisons are Simulated, and the simulation checks that must pass before any board is made are still Open; the [insight register](insights.html) tracks them. Details are in [Cadence, memory and wave compute](cadence-memory.html) and [Compute, sensing and control](compute-control.html).

**Known error in the removal operation.** The code that removes material still uses two shortcuts that are physically wrong: replaying the phase-reversed holding pattern, and subtracting intensity. A reversed pattern rebuilds the same trap, because the force depends on the squared pressure magnitude. The correct method is described in [Scan, recover and matter stores](matter-loop.html) and has not yet been carried into the code.

## Show what is known

Every view and exported report keeps three layers apart:

1. **Design intent.** The target geometry and its tolerances.
2. **Simulated prediction.** Pressure, force, flow and temperature from a model, with the model's assumptions stated.
3. **Measured and inferred.** Raw observations at the boundary, kept distinct from any interior reconstruction computed from them.

A passing simulation check never stands in for a measurement.

## Rules for the twin's own size

The twin has a written charter: one interface to the machine, no third-party dependencies, and a cap on source size that is lowered when code is deleted and never raised. The proposed cap is 17,500 lines of Swift and Metal. It is not yet met: a count on 17 November 2026 found about 21,400 lines.

## Open questions

| Question | Who answers it |
|---|---|
| How is the plate-response file replaced by one measured in the chamber, at fine enough patch spacing? | Twin software and calibration design |
| What patch spacing can the field solver afford at the highest tone? | Simulation and twin software |
| When do calibration and jobs use every tone? | Twin software |
| How is the receive path represented in the plate-response format? | Twin software and simulation |
| When is the removal operation corrected in code? | Simulation |

Read next: [Desktop Replicator](desktop-replicator.html), [Acoustics](acoustics.html), [Compute, sensing and control](compute-control.html) and [Current state](status.html).
