# Cadence, memory and wave compute

<div class="lead">Cadence is the pattern network that chooses drive signals from what the sensors report. It uses complex numbers and reciprocal connections so that the same equations can run on a microcontroller now and in a physical wave medium later. This chapter covers the network, the chord memory beside it and the long-term route to computing with waves. All results are from simulation; none of the optical or wave hardware exists.</div>

<div class="diagram">
<svg viewBox="0 0 880 510" role="group" aria-labelledby="cm-title cm-desc" xmlns="http://www.w3.org/2000/svg">
<title id="cm-title">Cadence pattern network and chord memory</title>
<desc id="cm-desc">Measurements from the piezo discs and the laser ring enter the Cadence network, which settles to an equilibrium and exchanges stored chords with a chord memory. Recalled chords stay labelled as inferred until a sensor confirms them. The compiler maps the result through the machine's calibrated response into drive frames. Below, three substrates for the same equations: the prototype controller, an optical cavity with phase-change storage, and long-term wave media.</desc>
<defs><marker id="cm-arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8" fill="#186b60"/></marker></defs>
<g fill="#f2f5ef" stroke="#186b60" stroke-width="1.5">
<a href="compute-control.html" aria-label="Sensor measurements"><rect x="30" y="34" width="185" height="122" rx="9"/></a>
<a href="#the-cadence-network" aria-label="Cadence network"><rect x="255" y="24" width="370" height="142" rx="9"/></a>
<a href="compute-control.html#one-contract-files-verbs-and-the-machine-interface" aria-label="Compiler"><rect x="665" y="34" width="185" height="122" rx="9"/></a>
<a href="#chord-memory" aria-label="Chord memory"><rect x="255" y="198" width="370" height="92" rx="9" fill="#e2ede5"/></a>
</g>
<rect x="30" y="324" width="820" height="162" rx="10" fill="#e2ede5" stroke="#186b60" stroke-width="1.5"/>
<g fill="#f2f5ef" stroke="#186b60" stroke-width="1.5">
<a href="#in-the-desktop-replicator" aria-label="Prototype controller"><rect x="48" y="362" width="248" height="106" rx="8"/></a>
<a href="#long-term-direction-the-substrate-ladder" aria-label="Optical cavity and phase-change store"><rect x="316" y="362" width="248" height="106" rx="8"/></a>
<a href="#long-term-direction-the-substrate-ladder" aria-label="Long-term wave media"><rect x="584" y="362" width="248" height="106" rx="8"/></a>
</g>
<g pointer-events="none" fill="#173630" font-family="system-ui,sans-serif" text-anchor="middle">
<text x="122" y="64" font-size="14.5" font-weight="650">Sensor measurements</text>
<text x="122" y="86" font-size="12">Piezo discs and laser ring</text>
<text x="122" y="106" font-size="12">Drift and prediction removed</text>
<text x="122" y="128" font-size="11.5" fill="#186b60">Labelled measured</text>
<text x="440" y="54" font-size="15.5" font-weight="700">Cadence network</text>
<text x="440" y="76" font-size="12.5">Complex states z = a·exp(iφ)</text>
<text x="440" y="96" font-size="12.5">Feedback weights = conjugate transpose of forward weights</text>
<text x="440" y="116" font-size="12">Weight norm at most 1, so settling converges</text>
<text x="440" y="138" font-size="11.5" fill="#186b60">Trained by two nudged equilibria, local updates only</text>
<text x="757" y="64" font-size="14.5" font-weight="650">Compiler</text>
<text x="757" y="86" font-size="12">Calibrated machine response</text>
<text x="757" y="106" font-size="12">ADD · REMOVE · LISTEN</text>
<text x="757" y="128" font-size="11.5" fill="#186b60">Writes .fcode frames</text>
<text x="440" y="224" font-size="14.5" font-weight="650">Chord memory</text>
<text x="440" y="245" font-size="12">Stored .pattern chords · recall efficiency η = (M# / M)²</text>
<text x="440" y="264" font-size="12">Recall by correlation · labelled inferred until a sensor confirms</text>
<text x="440" y="346" font-size="14" font-weight="700">SAME EQUATIONS, THREE SUBSTRATES</text>
<text x="172" y="388" font-size="14" font-weight="650">1 · Prototype</text>
<text x="172" y="408" font-size="12">Trained on a workstation</text>
<text x="172" y="426" font-size="12">Sparse 8-bit copy on the compute card</text>
<text x="172" y="444" font-size="12">Under {{c:cadence_brain.cadence_sparse_max_kb}} kB (target)</text>
<text x="440" y="388" font-size="14" font-weight="650">2 · Optical cavity</text>
<text x="440" y="408" font-size="12">Laser cavities as the nonlinearity</text>
<text x="440" y="426" font-size="12">Phase-change hologram as the weights</text>
<text x="440" y="444" font-size="12">Composed loop: Open</text>
<text x="708" y="388" font-size="14" font-weight="650">3 · Wave media</text>
<text x="708" y="408" font-size="12">Passive wave networks</text>
<text x="708" y="426" font-size="12">Excitable soft-matter substrates</text>
<text x="708" y="444" font-size="12">Research hypothesis</text>
</g>
<g fill="none" stroke="#186b60" stroke-width="2" marker-end="url(#cm-arrow)">
<path d="M215 95 H255"/>
<path d="M625 95 H665"/>
<path d="M405 166 V198"/>
<path d="M475 198 V166"/>
</g>
</svg>
</div>

*Status:* design decisions, derived arithmetic and simulated models. The training method is documented ([Scellier &amp; Bengio, 2017](https://doi.org/10.3389/fncom.2017.00024)). The boards that run the network are in [Compute, sensing and control](compute-control.html); terms are in the [Glossary](glossary.html).

## What this subsystem does

Cadence takes the measurements from the piezo discs and the laser ring, together with a target, and settles on a chord: an amplitude and phase for each source at each tone. A chord memory beside it stores chords for known shapes, so a familiar shape is recalled instead of solved again. How a chord relates to the `.pattern` and `.fcode` files is defined once, in [Compute, sensing and control](compute-control.html#one-contract-files-verbs-and-the-machine-interface).

<a id="why-three-cavities-the-8v-33-mode-count-theorem"></a>

## Why sound holds and light computes

The chamber's sound field cannot double as the computer, because it has too few independent states. A cavity of volume V at wavelength λ supports roughly

    N ≈ 8π V / (3 λ³)

independent modes (Derived). The formula counts two polarisations, so a sound field has half as many; the comparison is unaffected.

The table uses an 18.5 L volume. That figure belongs to an earlier, larger chamber design, not to the Desktop Replicator; every row scales with volume in the same way.

| Carrier in 18.5 L | Wavelength | Modes N | Role |
|---|---:|---:|---|
| Sound, 100 kHz in air | 3.4 mm | 3.8 × 10⁶ | Holding and moving material |
| Sound, about 1 MHz in a melt | about 5 mm | 1.2 × 10⁶ | Working inside a liquid |
| Microwave, 10 GHz | 30 mm | 5.7 × 10³ | Heating and positioning aid; valued for speed, not mode count |
| Light, 500 nm | 0.5 µm | 1.2 × 10¹⁸ | Computing and storage |

For the Desktop Replicator, the space inside the glass cylinder is about 11 L, and the formula gives about 9 × 10⁶ at its top tone of 160 kHz (Derived). This counts resolvable field patterns, not sharp resonances.

Light offers twelve orders of magnitude more states than sound in the same volume. The architecture therefore uses sound for force and light for computing and memory.

<a id="the-cadence-wave-equilibrium-model-eqprop"></a>

## The Cadence network

Cadence is a recurrent network that settles to an equilibrium, not a deep feed-forward stack. Three properties define it.

**Complex states.** Each unit holds a complex number z = a·exp(iφ). Amplitude and phase are what the machine measures and drives at every tone.

**Reciprocal weights.** The feedback weights are the conjugate transpose of the forward weights, which makes the combined weight matrix Hermitian, and the matrix is kept contractive:

    W_fb = W_fwdᴴ        ‖W‖₂ ≤ {{c:cadence_brain.spectral_norm_max}}

The bound means each pass shrinks disturbances, so the network converges to a fixed point and noise decays. The simulated network is held at about 0.68.

**Local learning.** Training uses equilibrium propagation, abbreviated EqProp (Documented: Scellier &amp; Bengio). The network settles freely. The outputs are then nudged toward the target with strength +β and it settles again; the same is done with −β. The update uses only the states at the two ends of each connection, where the bar denotes the complex conjugate:

    ΔW_ij = η · ( z_i⁺ · z̄_j⁺ − z_i⁻ · z̄_j⁻ )

These choices anticipate physical hardware. In a lossless reciprocal optical medium, light travelling backward experiences the conjugate transpose of the forward transfer, which supplies the feedback weights. Two light fields interfering at a point give the product of one state with the conjugate of the other, which is the update rule (Derived). Whether a real medium does both with usable precision is Open.

**In simulation.** The project's models (in `holo/`) let units update asynchronously, with outer units relaxing faster than inner ones. The output units include a term for the acoustic loading of the ports. The outputs are also coupled to the chord memory, so a stored shape can be recalled within one settle (Simulated).

The network works in machine-independent terms, and the compiler maps its output through one machine's calibrated body-response file. In simulation a network trained on one plate geometry was carried to another with a new calibration and no retraining. Those runs used the simpler plate model. On the solid model the opposite holds: a network does not carry over from one plate to the next and must be retrained from a calibration sweep, as described [below](#in-the-desktop-replicator).

<a id="holographic-memory-two-layers-and-chords-not-bits"></a>

## Chord memory

Memory has two layers: a working state that lasts for one settle, and a non-volatile store of chords.

| Layer | Holds | In the prototype | Long-term |
|---|---|---|---|
| Working state | The network's state while it settles | Controller memory | The field in an optical or wave cavity |
| Store | Chords for known shapes, calibration data | `.pattern` files on storage | Low-loss phase-change or photorefractive media |

**Capacity is set by noise, not geometry** (Derived). One value per half-wavelength cube at 500 nm, four bits each, is about 32 terabytes per cubic centimetre. Real media do not approach that. Storing M pages in one volume divides a fixed refractive-index budget, written M#, among them, and the light returned per page falls as

    η = (M# / M)²

With M# = 20, 100 pages give η of 4 × 10⁻², 1,000 pages give 4 × 10⁻⁴ and 10,000 pages give 4 × 10⁻⁶. Detector noise and crosstalk end usable recall long before the geometric limit.

Three consequences follow.

- **Material.** The low-loss chalcogenides Sb₂S₃ and Sb₂Se₃ are preferred to the common alloy Ge₂Sb₂Te₅, which absorbs strongly when crystalline and wastes the index budget. Thick, low-loss multilayer stacks are Open.
- **Chords, not bits.** A `.pattern` file already holds complex drive values. Storing them directly allows recall by correlation: present a partial measurement and retrieve the stored chords that match best.
- **Recall is a hypothesis.** The memory returns a ranked guess. Every chord in a `.pattern` file must state whether it was measured or inferred, with no default, and an inferred chord must name the model and inputs it came from.

<a id="3d-form-drawing-curriculum-oph-quarantine-and-teacher-distillation"></a>

## Training and checks in simulation

All training happens on a workstation. Nothing here has touched hardware (Simulated).

- **Curriculum.** The network learns to form thirteen basic shapes (the five regular polyhedra and eight primitives such as sphere, ring, rod and helix) at arbitrary orientations. The set also holds part shapes from the earlier, retired HA-0 design, kept as test geometry only.
- **Boundary inputs only.** Three-dimensional ground truth is used for the training loss and for scoring held-out cases. In operation the network sees only port responses and laser beams. It is also tested with each sensor alone.
- **Teachers.** Large pretrained vision and shape models are distilled offline into compact descriptors. They never run on the machine.
- **Four deployment tiers.** Each network is re-scored under four hardware models: full-precision floating point; 8-bit weights on the microcontroller with converter noise and drift; pruned 8-bit weights on an FPGA; analogue weights in a phase-change medium with limited precision and crosstalk.

One caveat applies. The shape curriculum was run on the earlier small chamber and has not been repeated for the Desktop Replicator's {{c:mosquito_smi.total_ommatidia}} beams and {{c:desktop_geometry.gap_mm}} mm spacing. An earlier fault has been corrected: the REMOVE verb used to reverse the drive, which does not remove anything. The simulation now follows the physical sequence in [Scan, recover and matter stores](matter-loop.html) and conserves mass.

## In the Desktop Replicator

The first compute card is an RP2350B microcontroller with {{c:cadence_brain.rp2350_sram_total_kb}} kB of memory. The network is trained on the workstation and copied to the card as 8-bit weights. The card can then make small local corrections, for example for thermal drift, with the same update rule.

**Three networks share the name.** The project's code holds three networks called Cadence, built for different jobs. They should not be read as one result.

| Network | Job | Size | State |
|---|---|---|---|
| Shape drawer | Turns a target shape into a sequence of drive patterns | 192 inputs, 1,024 hidden units, 120 outputs; about 457,000 weights | Trained in simulation on the earlier small chamber. Far too large for the first compute card |
| Occupancy estimator | Turns sensor readings into a map of where material is, on a 7 × 7 × 7 grid | About 380 to 390 inputs, 256 hidden units, 343 outputs; 361 to 387 kB at 8 bits | Simulated. This is the job the first compute card is meant to do |
| Sparse occupancy estimator | The same job with most connections removed, in 8 × 8 blocks | 32 to 53 kB at 5 to 10 % of connections | Simulated; firmware source exists. Accuracy is disputed, below |

**Why it must be sparse** (Derived). At 361 to 387 kB the dense occupancy estimator fits in the controller's {{c:cadence_brain.rp2350_sram_total_kb}} kB only by leaving little for anything else, and it settles in an estimated 23 ms. The target is to keep {{c:cadence_brain.target_block_sparsity_range|pct}} % of the connections, which brings storage under {{c:cadence_brain.cadence_sparse_max_kb}} kB.

**What the evidence supports** (Simulated). Two simulations on 18 November 2026 reached opposite conclusions about the sparse network.

- *On the solid plate model it fits but does not work.* Trained on echoes computed from the solid finite-element model, locating one to four beads, the network at 5 to 10 % of connections takes 34 to 53 kB and settles in an estimated 4 to 5 ms. Its agreement with the true map is 0.24 to 0.39, against 0.92 for the dense network and a required 0.90. The first size that identifies the beads correctly keeps 40 % of connections and takes 164 kB. The stated reason is that the echo pattern from the reverberant plate is close to random speckle, with little structure for a sparse network to exploit.
- *On the sensing lane's own model it works.* A network at 5.9 % of connections, 44.9 kB, is reported to agree with the dense network at 0.96 and to settle in 15 ms. This run used the simpler plate model and compared the sparse network with the dense one, not with the true map. The project has no stored record of this run.

The first result is the more demanding test and should be taken as the current position: the memory and speed targets are met, the accuracy target is not. The settle times are estimates from instruction counts, not timings on a controller.

**Choices awaiting a ruling.** Give the first card a smaller job, such as locating a single bead. Raise its memory budget to between 165 and 390 kB. Or move the full map to the second compute card.

**The network must be trained per machine** (Simulated). A dense network trained on five simulated plates scores 0.28 on a sixth. After one sweep of a single sphere through the 343 grid positions on that plate, it scores 0.80 and names the correct set of beads 99 % of the time, and it then forgets the plates it knew before. The calibration sweep in the chamber is therefore also the network's training set. It has to be repeated when the air temperature drifts by more than about 0.1 K: a simple linear read-out falls from 0.91 to 0.62 between 0.1 and 0.3 K.

The card options are tabulated once, in [Compute, sensing and control](compute-control.html#compute-card).

<a id="compute-substrate-ladder-from-prototype-sram-to-near-zero-electricity-wave-media"></a>

## Long-term direction: the substrate ladder

The equations stay fixed while the hardware that evaluates them changes. Each rung is meant to use less electrical power than the one before.

| Rung | Mechanism | Evidence |
|---|---|---|
| 1 · Workstation trainer | Full-precision training with GPU kernels | Simulated; in use |
| 2 · Prototype compute card | Sparse 8-bit network on a microcontroller or optional FPGA | Design decision; sparse target not yet evidenced |
| 3 · Optical cavity with phase-change store | Laser cavities as the nonlinearity; a rewritable hologram as the weights | Component physics documented; composed loop Open |
| 4 · Wave media | Passive wave networks with excitable soft-matter wave substrates | Research hypothesis |

**Rung 3.** A laser diode near threshold has an exponential and logarithmic response, written exp(x) − ln(y), which the design proposes as the network's nonlinearity. This law describes laser cavities. It must not be applied to the piezo sources, which are modelled as linear circuits. A phase-change hologram would hold the weights and, by reciprocity, supply the feedback path. The known limits are severe: four to eight bits of analogue precision, 10⁶ to 10⁹ write cycles, the recall law above, and low cavity quality in the printable materials considered so far.

**Rung 4.** The aim is a medium whose own chemical, dielectric or mechanical relaxation settles to the network's fixed point, so that physics replaces clocked logic. Material, noise, drift and speed would all need to be established before any hardware decision.

Background is in the paper [Holographic Memory and Compute](../papers/holographic_memory_and_compute_plan.html).

## Open questions

| Question | Who answers it |
|---|---|
| Which of the two sparse-network results holds when both use the same data? | Simulation and sensing lanes together |
| Does the first card take a smaller job, more memory, or hand the map to the second card? | Ruling by the coordination lane |
| Does it settle in the estimated 4 to 5 ms on a real controller? | Firmware on a board |
| Do the training results hold for the Desktop Replicator's geometry and sensors? | Simulation on the `desktop-200mm` preset |
| Can a real reciprocal medium supply feedback and local updates at useful precision? | Optical experiment; not scheduled |
| Can thick, low-loss phase-change stacks be made? | Materials research |
