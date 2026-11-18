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

For the Desktop Replicator, the space between the plates is about 4.6 L, and the formula gives about 4 × 10⁶ at its top tone of 160 kHz (Derived). The chamber is open, so this counts resolvable field patterns, not sharp resonances.

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

The network works in machine-independent terms, and the compiler maps its output through one machine's calibrated body-response file. In simulation a network trained on one plate geometry was carried to another with a new calibration and no retraining. Those runs used earlier presets and have not been repeated for `desktop-200mm`.

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

Two caveats apply. The sightlines and plate presets in these runs belong to earlier designs; the curriculum has not been re-run for the Desktop Replicator's {{c:mosquito_smi.total_ommatidia}} beams and {{c:desktop_geometry.gap_mm}} mm spacing. And the REMOVE verb in these simulations is not physically meaningful: the code conjugates the drive, and one path applies a negative acoustic intensity. Both are known to be wrong. The correct sequence is in [Scan, recover and matter stores](matter-loop.html).

## In the Desktop Replicator

The first compute card is an RP2350B microcontroller with {{c:cadence_brain.rp2350_sram_total_kb}} kB of memory. The network is trained on the workstation and copied to the card as 8-bit weights. The card can then make small local corrections, for example for thermal drift, with the same update rule.

**Why it must be sparse** (Derived). The reference network has 192 inputs, 512 hidden units and 180 outputs. Stored densely at one byte each for the real and imaginary parts, its weights take 372 kB, and a 30-step settle takes 220 to 300 ms on this controller. The target is to keep {{c:cadence_brain.target_block_sparsity_range|pct}} % of the weights, in blocks, and to skip units whose state has not changed. That would bring storage under {{c:cadence_brain.cadence_sparse_max_kb}} kB and settling to {{c:cadence_brain.rp2350_settle_target_ms_range|range}} ms.

**What the evidence supports** (Simulated and Open, as given by an audit of the engineering record):

- The only pruned network in the project's acceptance checks keeps 20 % of its weights, and its accuracy bar is lower than the dense network's: agreement with the full-precision reference of 0.90, against 0.98.
- A block-sparse variant near 9 % density exists in code, but no acceptance check covers it. The 5 to 10 % target that fits in {{c:cadence_brain.cadence_sparse_max_kb}} kB is not yet evidenced.
- Settle time scales with density. Linear scaling from the dense 220 to 300 ms gives 11 to 15 ms at 5 % but 22 to 30 ms at 10 %. The {{c:cadence_brain.rp2350_settle_target_ms_range|range}} ms target needs about 5 % density or real savings from skipping unchanged units.

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
| Does a network at 5 to 10 % density keep its accuracy? | Simulation, with an acceptance check at that density |
| Does it settle in {{c:cadence_brain.rp2350_settle_target_ms_range|range}} ms on the controller? | Firmware in emulation, then the assembled machine |
| Do the training results hold for the Desktop Replicator's geometry and sensors? | Simulation on the `desktop-200mm` preset |
| Can a real reciprocal medium supply feedback and local updates at useful precision? | Optical experiment; not scheduled |
| Can thick, low-loss phase-change stacks be made? | Materials research |
