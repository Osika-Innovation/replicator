# Ideas from biology

Animals sense and act with few, cheap and noisy parts. A bat finds an insect with two ears and one voice. A fly steers with a few thousand simple eyes and a brain smaller than a grain of rice. The Desktop Replicator is in the same position: twelve piezo discs, {{c:mosquito_smi.total_ommatidia}} lasers and a small microcontroller. Several of its sensing and computing ideas are therefore borrowed from biology.

This page lists every such idea in the project, says plainly what it is, and records how far each one has got. Biology is used here as a source of engineering patterns. Nothing on this page claims that the machine works the way an animal does.

## How far this work has got

The results on this page are simulations and calculations.

- The ideas were first written for an earlier, smaller chamber that is now retired. On 18 November 2026 the sensing models and their checks were updated to the present machine: {{c:mosquito_smi.total_ommatidia}} lasers, undrilled plates {{c:desktop_geometry.gap_mm}} mm apart and a glass cylinder.
- Three acceptance checks cover this page: one for sensing with sound, one for the laser ring and the pattern network, and one for the whole loop from scan to quality check. They were reported as passing on that date. The project has no stored record of those runs, so the result is recorded here as reported, not as verified.
- The checks generate their test data with the same models that then interpret it. Passing shows the mathematics is self-consistent. It does not show that a real echo or a real laser signal will be interpreted correctly. A test on independently generated data, for example from the solid finite-element model, is the next step for all of them.

## Sensing with sound: bats, dolphins and moths

The twelve piezo discs drive the plates and listen on the same wires. These ideas concern what to send and how to read what comes back.

| Idea | Borrowed from | What it means for the machine | State |
|---|---|---|---|
| Steady tone with short chirps | Bats that hold a constant tone and add brief frequency sweeps (Documented: Schnitzler and Denzinger, 2011) | Hold the levitating tones about 95 % of the time and spend 5 % on sweeps. The steady tone reveals motion; the sweep gives distance | Model and check |
| Motion read from a steady tone | The bat's sharply tuned hearing around its own call frequency | A liquid surface that is still setting ripples, and the ripple adds faint side tones to the echo. When the side tones vanish the material has set. This is the proposed quality check after joining | Model and check; the loop check reports a 72 dB change |
| Thickness from echo gaps | The big brown bat, which hears two closely spaced reflections as notches in the spectrum (Documented: Saillant and Simmons, 1993) | Two surfaces of a small part return echoes that interfere. The spacing of the notches gives the thickness without imaging | Model and check |
| Direction from a shaped reflector | The folds of a bat's outer ear, which make an echo's spectrum depend on its direction (Documented: Zhuang and Müller, 2006) | A passive shaped surface in the chamber would let a few receivers locate an object in three dimensions | Model only, for the earlier chamber. Not in the present design |
| Sum and difference steering | Dolphin echolocation (Documented: Au and Pawloski, 1992) and radar practice | Send two overlapping beams. Their sum shows that an object is there; their difference shows which way it is off centre. That gives a fast correction signal without forming an image | Model and check |
| Graded coupling layer | The fatty tissue in a dolphin's forehead that passes sound smoothly into water | A layer whose stiffness changes gradually would pass more sound from the plate into air than an abrupt surface | Calculation only |
| Thin sound absorber | Moth wing scales, which absorb bat calls in a layer far thinner than a wavelength (Documented: Neil and others, 2020) | A thin resonant layer behind the sources would suppress stray echoes inside the machine | Calculation only |
| Tap and listen | Common to many animals and to workshop practice | Excite the finished part and measure how long it rings. A crack or a poor joint shortens the ring | Model and check |

## Sensing with light: the compound eye

An insect's eye is thousands of simple units, each looking in one direction with no focusing lens shared between them. The laser ring follows that pattern, which is why it is nicknamed the mosquito eye. Each of the {{c:mosquito_smi.total_ommatidia}} lasers looks along one line across the chamber and is its own detector. No unit forms an image; the set of line readings together constrains what is in the chamber. [Optics and metamaterials](optics.html) gives the physics and the limits.

The simulation check for the ring was updated to the present layout, in which the beams pass through the glass cylinder to reflector film on its outer face.

## Computing: the insect brain

| Idea | Borrowed from | What it means for the machine | State |
|---|---|---|---|
| Process at the sensor | The first layers of an insect's eye and antenna, which reduce raw signals before they reach the brain | Each head board turns its own raw samples into a few amplitudes and phases and sends only those on the bus | Firmware source exists and is tested on a workstation |
| Learning from local signals | Synapses, which change according to the activity at their two ends | The Cadence network learns with a rule that uses only the two units a connection joins. See [Cadence, memory and wave compute](cadence-memory.html) | Simulated |
| Sparse memory | The mushroom body, where only a few percent of cells respond to any one smell, which keeps memories from blurring together | A bank of units of which about 3 % are active at once stores known shapes and recalls the nearest | Code only; no check of its own |
| Looking where it is uncertain | The quick eye and head movements with which animals sample a scene | Choose the next drive pattern to illuminate the part of the chamber the estimate is least sure of | Code; partly covered by the laser-ring check |
| Subtracting your own signal | Animals cancel the sensation caused by their own movement | Subtract the echo the machine expects from its own drive, so that only the unexpected part is analysed | Code only |
| Tracking temperature drift | Named after the mosquito's hearing organ | Correct the sound readings as the air warms. The solid model shows this is essential: a calibration is stale after a few tenths of a kelvin | Code only |

## Ideas that exist only on paper

- **A plate graded like the inner ear.** The inner ear separates tones along its length because its stiffness changes gradually. A plate graded the same way would send each tone to a different place. This appears in one of the project's papers and nowhere in code.
- **Computing in a physical medium.** The long-term design replaces the digital controller with a medium whose own relaxation performs the network's settling. It is described in [Cadence, memory and wave compute](cadence-memory.html#long-term-direction-the-substrate-ladder) and has no model.

Two families of biologically inspired computing do not appear anywhere in the project: networks of spiking units, and reservoir computing, in which a fixed physical system is read out by a small trained layer. The reverberant glass plate is a natural candidate for the second, and nobody has examined it.

## What the solid plate model changed

The solid finite-element model of the plates ([Acoustic bodies](acoustics.html#known-limits)) altered the outlook for this work in three ways.

1. **Sensing is closer than levitation.** Holding a solid bead is out of reach on the present drive. Listening needs far less sound pressure than holding, so a machine that scans and calibrates itself is a nearer goal than one that assembles.
2. **Calibration is a learning problem.** A plate's response cannot be predicted and drifts with temperature. In simulation, a network trained on five plates fails on a sixth, but one sweep of a single sphere through 343 positions restores it. The in-chamber calibration sweep and the network's training data are therefore the same thing.
3. **The echo is harder to compress than expected.** On the solid model the echo pattern is close to random speckle. That is why the small form of the pattern network loses accuracy, as described in the [Cadence chapter](cadence-memory.html#in-the-desktop-replicator).

## Open questions

| Question | Who answers it |
|---|---|
| Do the sensing checks still pass on data from the solid finite-element model? | Sensing and simulation lanes |
| Can the pattern network learn one plate's response from a calibration sweep and then track temperature? | Simulation, then the assembled machine |
| Is a shaped reflector compatible with the glass cylinder? | Sensing lane and CAD |
| Does the reverberant plate work as a reservoir computer? | Not assigned |
