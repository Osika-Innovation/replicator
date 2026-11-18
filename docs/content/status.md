# Current state

**No hardware has been built, ordered or measured.** What exists today is a parametric CAD model of the [Desktop Replicator](desktop-replicator.html), simulations of its acoustics, sensing and control, and this handbook. Every statement about what the machine does is a design decision, a calculation or a simulation result, and is labelled as such.

## State at a glance

| Area | What exists | Evidence | What blocks the next step |
|---|---|---|---|
| Machine design | Parametric CAD model, exact geometry export, drawings, parts list with candidate part numbers, power estimate | Derived | Simulation gates below; operator approval before anything is ordered |
| Plate acoustics | A reduced plate model used for planning, and a three-dimensional solid finite-element model that contradicts it | Simulated | The two models disagree; a measured plate response is required; all results repeated at the new {{c:desktop_geometry.gap_mm}} mm plate spacing |
| Drive and receive electronics | Circuit concept with candidate parts. No circuit board layout | Derived | The {{c:haptic_pzt.sfdr_gate_min_db}} dB converter test in simulation; drive voltage and receive band reconciled with the plan |
| Optical ring | Geometry in the CAD model and a signal model in simulation | Simulated | Signal model checked against the present {{c:mosquito_smi.total_ommatidia}}-laser layout; amplifier design; laser safety for an open chamber |
| Pattern network (Cadence) | Trained and tested in simulation at full size | Simulated | The reduced form that fits the controller has not been shown at its target size |
| Firmware | None for the Desktop Replicator. Firmware for a retired earlier array still compiles as a regression case | — | Writing it, starting from a cycle budget |
| Assembly and joining | A transport model in simulation. No joining recipe without adhesive | Open | A joining step with its energy source; placing one bead beside another |
| Removal and recovery | The correct physical sequence is specified. The code still uses two shortcuts known to be wrong | Derived | Implementing the sequence and tracking mass |
| Scanning | Acoustic and optical scan models that pass their checks on simulated data | Simulated | Repeating them for the present geometry |
| Electromagnetic control | Large coils across the chamber are ruled out by simulation. A small pulsed coil is a candidate | Simulated; Open | A model of the small coil that respects what it can and cannot reach |
| Long-term architecture | Design studies resting on published component physics | Documented; Open | Demonstrations of the components at useful scale |
| Bench evidence | None | — | A built machine |

The detailed chapters are [Acoustic bodies](acoustics.html), [Compute, sensing and control](compute-control.html), [Optics and metamaterials](optics.html), [Manufacturing](manufacturing.html), [Scan, recover and matter stores](matter-loop.html) and [Electromagnetic control](electromagnetics.html).

## Known inconsistencies in the design

A review of the engineering record on 17 November 2026 found places where two parts of the design disagree. Each is registered, has an owner and is listed in the [insight register](insights.html). The ones that matter most:

1. **Drive voltage.** Planning assumes up to 40 V per source. The drive stage as specified supplies about 11 V. Force scales with the square of voltage, so planned forces are about ten times too high. A solid finite-element model has since put the voltage needed to hold a solid polystyrene bead at roughly 900 V per source at the best tone, far beyond either figure. Drive strength is the limiting factor for levitation.
2. **Receive band.** The converter figures are stated for a {{c:haptic_pzt.ultrasonic_bw_hz|khz}} kHz band, yet the highest drive tone is above that. A cycle-by-cycle simulation of the simple one-bit converter then reached about 61 dB on the six-tone test and cannot pass. The written fallback is a conventional converter chip.
3. **Plate model resolution.** The file that describes how the plates radiate samples them far more coarsely than half a wavelength of sound in air. The solid finite-element model confirms it: the plates ring instead of damping out, and the file does not match the solid model at all. The plate response has to be measured in the chamber for each plate.
4. **Air temperature.** The sound path between the plates changes by about 70° of phase per kelvin at the highest tone. The parts list has no air temperature sensor.
5. **Open chamber.** The glass wall was removed on 17 November 2026. The chamber now has no shield against draughts, no enclosure around the laser beams and no interlock.
6. **Joining.** Sound cannot supply the heat to join grains. With hand-applied adhesive retired, there is no joining recipe.

## What must exist before hardware is ordered

Hardware may be released for purchase only when all five of these exist:

1. A frozen revision of the design with file hashes.
2. A parts list with quantities, part numbers, live stock and prices.
3. Exact CAD geometry, drawings, tolerances, wiring and a thermal budget.
4. Passed simulation gates: the {{c:haptic_pzt.sfdr_gate_min_db}} dB converter test and agreement between the solid finite-element model and the plate model. Both currently fail.
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
| Measured | A project bench result with apparatus, calibration and raw records. None exist yet |
| Open | Not yet settled by calculation, simulation or measurement |
| Claim | Asserted by a source and not verified |

A result reported in the literature stays attributed to its authors. It is never presented as something this project has measured.

Scan data uses a separate pair of words. A value is *measured* when a sensor reported it and *inferred* when a model filled it in. That describes where a number in a data file came from. It is not an evidence label.

## How something moves up

A source enters the [research library](research.html) with its identity and how deeply it was read. A model earns use when an independent calculation agrees with it. A design earns hardware when it passes the five conditions above. Hardware earns a capability through repeatable measurement. An upgrade earns adoption through a measured before-and-after improvement on the same task, as described in the [upgrade loop](upgrades.html).

## Retired designs

Three earlier baselines are retired and appear in this handbook only as history: an array of sixteen 40 kHz transducers, a design with drilled wafers and single-purpose test rigs, and joining by hand-applied adhesive. The table of what was retired and why is in [Desktop Replicator](desktop-replicator.html#what-this-design-replaced).

## Keeping this page true

The numbers on this page are quoted from the shared engineering constants, and the handbook build fails if they drift or if a retired design is described as current. Update this page whenever a row of the table changes.
