# Ideas from biology

Animals sense and act with few, cheap and noisy parts. A bat finds an insect with two ears and one voice. The [Desktop Replicator](desktop-replicator.html) is in the same position: twelve piezo discs, {{c:mosquito_smi.total_ommatidia}} lasers and a small microcontroller. This page lists each sensing and computing idea it borrows from biology and how far the idea has got. Biology is a source of engineering patterns here. The machine is not claimed to work as an animal does.

## How far this work has got

Every project result on this page is Simulated or Derived.

- The ideas were first written for an earlier, smaller chamber that is now retired. On 18 November 2026 the sensing models and checks were updated to the present machine: {{c:mosquito_smi.total_ommatidia}} lasers, undrilled plates {{c:desktop_geometry.gap_mm}} mm apart and a glass cylinder that closes the chamber.
- Three acceptance checks cover this page: sensing with sound, the laser ring with the pattern network, and the whole loop from scan to quality check. They were reported as passing on that date. No record of those runs is stored, so the result is a Claim.
- The checks make their test data with the same models that then read it. Passing shows the mathematics agrees with itself, not that a real echo or laser signal will be read correctly ([what each kind of check proves](digital-twin.html#what-each-kind-of-check-proves)). The next step is a test on data made another way, for example by the solid finite-element model.

## Sensing with sound: bats, dolphins and moths

The twelve piezo discs drive the plates and listen on the same wires ([self-sensing](acoustics.html#self-sensing-on-the-same-two-wires)). The animal studies are cited in words because they are not in the project's source catalogue. A specific figure taken from one is labelled Claim.

| Idea | Borrowed from | What it means for the machine | State |
|---|---|---|---|
| Steady tone with short chirps | Bats that hold a constant tone and add brief frequency sweeps (Schnitzler and Denzinger, 2011) | Hold the levitating tones about 95 % of the time and sweep for 5 %. The steady tone reveals motion. The sweep gives distance | Model and check |
| Motion read from a steady tone | The bat's sharply tuned hearing around its own call frequency | A liquid surface that is still setting ripples, which adds faint side tones to the echo. When they vanish, the material has set. This is the proposed quality check after joining | Model and check; the loop check reports a 72 dB change |
| Thickness from echo gaps | The big brown bat, which hears two closely spaced reflections as gaps in the spectrum (Saillant and Simmons, 1993) | Echoes from two surfaces of a small part interfere. The gap spacing gives the thickness without an image | Model and check |
| Direction from a shaped reflector | The folds of a bat's outer ear, which make an echo's spectrum depend on its direction (Zhuang and Müller, 2006) | A passive shaped surface would let a few receivers locate an object in three dimensions | Model only, for the earlier chamber. Not in the present design |
| Sum and difference steering | Dolphin echolocation (Au and Pawloski, 1992) and radar practice | Send two overlapping beams. Their sum shows an object is there. Their difference shows which way it is off centre: a fast correction signal without an image | Model and check |
| Graded coupling layer | The fatty tissue in a dolphin's forehead, which passes sound smoothly into water | A layer of gradually changing stiffness would pass more sound from plate to air than an abrupt surface | Calculation only |
| Thin sound absorber | Moth wing scales, which absorb bat calls in a layer far thinner than a wavelength (Claim: Neil and others, 2020) | A thin resonant layer behind the sources would suppress stray echoes | Calculation only |
| Tap and listen | Many animals; workshop practice | Excite the finished part and time its ring. A crack or poor joint shortens it | Model and check |

## Sensing with light: the compound eye

An insect's eye is thousands of simple units. Each looks in one direction and shares no lens. The laser ring follows that pattern and is nicknamed the mosquito eye. Each of the {{c:mosquito_smi.total_ommatidia}} lasers looks along one line across the chamber and is its own detector. No unit forms an image. Together the line readings narrow down what is in the chamber. The physics and limits are in [Optics and optical metamaterials](optics.html#coherent-self-mixing-optical-readout), and the electronics in [Compute, sensing and control](compute-control.html#laser-readout-electronics).

The beams pass through the glass cylinder to reflector film on its outer face.

## Computing: the insect brain

The network in these rows is Prime, the project's model built on the Cadence library.

| Idea | Borrowed from | What it means for the machine | State |
|---|---|---|---|
| Process at the sensor | The first layers of an insect's eye and antenna, which reduce raw signals before the brain | Each head board turns its own raw samples into a few amplitudes and phases and sends only those on [the bus](compute-control.html#the-bus) | Firmware source passes its tests on a workstation (Simulated) |
| Learning from local signals | Synapses, which change according to the activity at their two ends | The network learns with a rule that uses only the two units a connection joins ([the Cadence network](cadence-memory.html#the-cadence-network)) | Simulated |
| Sparse memory | The insect mushroom body, where only a few percent of cells respond to any one smell (Claim), which keeps memories from blurring together | A bank of units of which about 3 % are active at once stores known shapes and recalls the nearest ([chord memory](cadence-memory.html#chord-memory)) | Code only; no check of its own |
| Looking where it is uncertain | Animals' quick eye and head movements | Choose the next drive pattern to probe where the estimate is least sure | Code; partly covered by the laser-ring check |
| Subtracting your own signal | Animals cancel the sensation caused by their own movement | Subtract the echo expected from the machine's own drive, so only the unexpected part is analysed | Code only |
| Tracking temperature drift | Named after the mosquito's hearing organ | Correct the sound readings as the air warms. A stored calibration falls to a correlation of about 0.63 after 0.5 K (Simulated) | Code only |

## Ideas that exist only on paper

- **A plate graded like the inner ear.** The inner ear separates tones along its length because its stiffness changes gradually. A plate graded the same way would send each tone to a different place. It has no code.
- **Computing in a physical medium.** The long-term design replaces the digital controller with a medium whose own relaxation performs the network's settling. It is described in the [substrate ladder](cadence-memory.html#long-term-direction-the-substrate-ladder) and has no model.
- **The plate as a reservoir computer.** In reservoir computing a fixed physical system is read out by a small trained layer. The reverberant glass plate is a candidate. It has not been examined.

## What the solid plate model changed

The solid finite-element model of the plates ([Acoustics](acoustics.html#known-limits)) changed the outlook in three ways (Simulated).

1. **Sensing is closer than levitation.** Holding a solid bead is out of reach on the present drive. One tone on the full supply lifts only about 1.2 times the weight of a foam bead. Listening needs far less sound pressure than holding, so a machine that scans and calibrates itself is a nearer goal than one that assembles.
2. **Calibration is a learning problem.** A plate's response cannot be predicted and drifts with temperature. A network trained on five plates fails on a sixth, and one sweep of a single sphere through 343 positions restores it. The calibration sweep is therefore also the network's training data.
3. **The echo is hard to compress.** On the solid model the echo pattern is close to random speckle, so the small form of the pattern network loses accuracy ([Cadence guide](cadence-memory.html#in-the-desktop-replicator)).

## Open questions

| Question | Who answers it |
|---|---|
| Do the sensing checks still pass on data from the solid finite-element model? | Sensing and simulation lanes |
| Can the pattern network learn one plate's response from a calibration sweep and then track temperature? | Simulation, then the assembled machine |
| Is a shaped reflector compatible with the glass cylinder? | Sensing lane and CAD |
| Does the reverberant plate work as a reservoir computer? | Not assigned |
