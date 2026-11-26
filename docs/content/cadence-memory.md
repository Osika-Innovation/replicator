# Cadence, memory and wave compute

<div class="lead">The pattern network chooses drive signals from what the sensors report. Its numbers carry a size and a timing, as waves do, and every link works in both directions. The same equations can therefore run on a microcontroller now and in a physical wave medium later. This guide covers the network, its chord memory and the long-term route to computing with waves. Every result here is Simulated or Derived.</div>

<div class="diagram">
<svg viewBox="0 0 880 510" role="group" aria-labelledby="cm-title cm-desc" xmlns="http://www.w3.org/2000/svg">
<title id="cm-title">Prime pattern network and chord memory</title>
<desc id="cm-desc">Measurements from the piezo discs and the laser ring enter the Prime network, built on the Cadence library, which settles to an equilibrium and exchanges stored chords with a chord memory. Recalled chords stay labelled as inferred until a sensor confirms them. The compiler maps the result through the machine's calibrated response into drive frames. Below, three substrates for the same equations: the prototype controller, an optical cavity with phase-change storage, and long-term wave media.</desc>
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
<text x="440" y="54" font-size="15.5" font-weight="700">Prime network (Cadence library)</text>
<text x="440" y="76" font-size="12.5">Complex states z = a·exp(iφ)</text>
<text x="440" y="96" font-size="12.5">Feedback weights = conjugate transpose of forward weights</text>
<text x="440" y="116" font-size="12">Weight norm at most 1, so settling converges</text>
<text x="440" y="138" font-size="11.5" fill="#186b60">Trained by two nudged equilibria, local updates only</text>
<text x="757" y="64" font-size="14.5" font-weight="650">Compiler</text>
<text x="757" y="86" font-size="12">Calibrated machine response</text>
<text x="757" y="106" font-size="12">ADD · REMOVE · LISTEN</text>
<text x="757" y="128" font-size="11.5" fill="#186b60">Writes .fcode frames</text>
<text x="440" y="224" font-size="14.5" font-weight="650">Chord memory</text>
<text x="440" y="245" font-size="12">Stored chords · recall efficiency η = (M# / M)²</text>
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

*Status:* the training method is Documented ([Scellier &amp; Bengio, 2017](https://doi.org/10.3389/fncom.2017.00024)). The boards that run the network are in [Compute, sensing and control](compute-control.html). Terms are in the [Glossary](glossary.html).

**Two names.** Prime is the project's model, built on the Cadence library. Prime is the network that reads the chamber and chooses the drive. Cadence is the library of equations and training code. This guide keeps the library's name in its title.

## What this subsystem does

Prime takes the measurements from the piezo discs and the laser ring, and a target. It settles on a chord: an amplitude and a phase for each source at each tone. A chord memory stores chords for known shapes, so a familiar shape is recalled instead of solved again.

Objects are stored as holographic equations (`.holo` files), which do not depend on the chamber. A chord is what one chamber computes from an equation. Both are defined in [Compute, sensing and control](compute-control.html#one-contract-files-verbs-and-the-machine-interface).

<a id="why-three-cavities-the-8v-33-mode-count-theorem"></a>

**Why the sound field is not the computer (Derived).** Sound carries force and light carries information ([Architecture](architecture.html#two-carriers-five-wavelength-decades-and-volume-crossings)). A closed volume V holds about 8πV ÷ 3λ³ distinguishable wave patterns at wavelength λ, and half that for sound, which has one polarisation. The 10.9 L chamber gives about 9 × 10⁶ for 160 kHz sound and 7 × 10¹⁷ for 500 nm light, about 80 billion times more.

<a id="the-cadence-wave-equilibrium-model-eqprop"></a>

## The Cadence network

Prime is recurrent: its units feed each other until the whole network comes to rest. Three properties define it.

**Wave-like states.** Each unit holds a complex number z = a·exp(iφ): a size a and a timing φ. Amplitude and phase are what the machine measures and drives at every tone.

**Links that work both ways.** The link from unit B back to unit A is the mirror of the link from A to B, with its phase reversed. The links are also kept weak enough that each pass makes a disturbance smaller:

    W_fb = W_fwdᴴ        ‖W‖₂ ≤ {{c:cadence_brain.spectral_norm_max}}

The feedback weights are the conjugate transpose of the forward weights, and the largest gain of the weight matrix stays at or below the bound. The network therefore comes to rest at one answer and noise dies away. The simulated network is held at about 0.68.

**Local learning.** Training uses equilibrium propagation (Documented: Scellier &amp; Bengio). The network settles freely. Its outputs are nudged toward the target with strength +β and it settles again, then the same with −β. Each link is updated from the states at its own two ends only, where the bar means the complex conjugate:

    ΔW_ij = η · ( z_i⁺ · z̄_j⁺ − z_i⁻ · z̄_j⁻ )

These choices suit physical hardware (Derived). In a clear material, light going backward meets the same connections as light going forward, mirrored. That is the feedback, with no extra wiring. Two light fields meeting at a point give the product of one state with the conjugate of the other, which is the update rule. Whether a real medium does both with usable precision is Open.

**In simulation.** The outputs account for how the air pushes back on each source. They are also coupled to the chord memory, so a stored shape can be recalled within one settle (Simulated).

The network's output does not depend on the machine. The compiler maps it through one machine's calibrated [plate-response file](digital-twin.html#the-plate-response-file). On the solid plate model a trained network does not carry over from one plate to the next and must be retrained from a calibration sweep ([below](#in-the-desktop-replicator)).

<a id="holographic-memory-two-layers-and-chords-not-bits"></a>

## Chord memory

A hologram keeps the pattern two waves make where they meet, and gives one wave back when lit with the other ([what a sound hologram is](acoustics.html#what-a-sound-hologram-is)). The project uses that step to shape the chamber field, to store patterns, and to compute with light.

Memory has two layers (Design decision).

| Layer | Holds | In the prototype | Long-term |
|---|---|---|---|
| Working state | The network's state while it settles | Controller memory | The field in an optical or wave cavity |
| Store | Holographic equations for known objects, calibration data, and chords compiled for this chamber | `.holo` files on storage; compiled chords as a cache | Low-loss phase-change or photorefractive media |

The store is rewritten rarely on purpose: phase-change material is expected to wear out after 10⁶ to 10⁹ rewrites (Claim, no source registered).

**Capacity is set by noise, not geometry (Derived).** A hologram spreads each pattern through the whole thickness, and many patterns share the same volume. The ceiling is the number of modes that fit. For 500 nm light, one mode per wavelength cube at 1 bit each is 8 × 10¹² modes per cubic centimetre, about 1 TB. One per half-wavelength cube is about 8 TB, and 8 bits per mode would be about 64 TB at very low noise.

More than one bit per mode means coding in strength, timing and polarisation together, which one experiment reports (Documented: [Chen et al., Optica 13, 591, 2026](https://doi.org/10.1364/OPTICA.586593)).

Real media do not approach the ceiling. A material can only be changed so much: call that budget M#. With M pages stored, each page sends back this fraction of the light:

    η = (M# / M)²

With M# = 20, 1,000 pages give η of 4 × 10⁻⁴ and 10,000 give 4 × 10⁻⁶. Detector noise and crosstalk end usable recall long before the geometric limit. Volume holographic storage of digital pages is Documented ([Heanue, Bashaw &amp; Hesselink, 1994](https://doi.org/10.1126/science.265.5173.749)).

A holographic memory is judged by five measured things: light returned, errors, speed, retention and rewrites survived (Design decision). Four consequences follow.

- **Material.** Sb₂S₃ and Sb₂Se₃ stay clear in both of their states, where the common Ge₂Sb₂Te₅ turns dark in one. M# grows with how much a material can change its refractive index, and these two change it by about 0.6 to 0.8 (Documented: [Delaney et al., 2020](https://doi.org/10.1002/adfm.202002447)). Films today are tens of nanometres thick. Thick, low-loss stacks are Open.
- **Wave amplitudes, not bits.** Equations and chords hold complex wave amplitudes, which allows recall by likeness: one flash of light, and every stored pattern answers at once, each as strongly as it matches (textbook principle; not built here). Today's recall code works on chords compiled for one chamber, in the earlier `.pattern` format. Recall over the equations has not been written.
- **Recall and capacity share one limit (Derived).** The more patterns are stored, the more alike the weak answers look, on the same η curve. The honest score is patterns that can still be told apart per cubic centimetre, not bytes.
- **Recall is a hypothesis (Design decision).** The memory returns a ranked guess. Only a sensor can confirm it. Every stored entry states whether it was measured or inferred, and an inferred one names its model and inputs. Writing weights into a material makes them fast, not more true. The same rule governs scans ([what a scan may claim](matter-loop.html#what-a-scan-is-allowed-to-claim)).

## How Prime borrows from the human brain: silent imagination first, words second

Research task BRAIN-BIO-1 (#126) asked which ideas from the human brain are worth copying into Prime, and which are not. It added no hardware and ran no simulation. It is a reading of 32 sources (`R199`–`R230`) and a plan for the next experiments (Design decision; Open). The network it concerns is the research version of Prime, not the small controller card.

The human brain does not think in English sentences. Brain scans and patient studies show that silent thinking happens in quiet spatial and problem-solving networks: picturing a shape, judging whether a glass plate will crack, or asking "what if I push here instead?". The language circuits act mostly as a translator that packs a finished thought into words ([Fedorenko et al., *Nature* 2024](https://doi.org/10.1038/s41586-024-07522-w), `R216`) † (Documented).

The plan copies that split on purpose. The wave network settles the sound, light and shape fields silently, and only afterwards a small frozen language model turns its settled state into words.

| Brain idea | What the lab work shows (Documented) | What the plan does with it (Derived or Open) |
|---|---|---|
| **Thinking in shape-waves** | Activity in the cortex follows the natural standing waves set by the folded shape of the cortex ([Pang et al., *Nature* 2023](https://doi.org/10.1038/s41586-023-06098-1), `R209`) †. Travelling waves sweep one way while a memory is stored and the other way while it is recalled ([Mohan et al., *Nat. Hum. Behav.* 2024](https://doi.org/10.1038/s41562-024-01838-3), `R214`) † | Prime already settles to rest on a symmetric wave grid (Derived). Sensor drive and goal drive are applied at the boundary, so the two directions are two kinds of input and the symmetric network, which keeps settling guaranteed, is not touched (Design decision; Open) |
| **Maps shaped like a doughnut** | Navigation cells in the entorhinal cortex trace out a doughnut-shaped surface (a torus), also during sleep ([Gardner et al., *Nature* 2022](https://doi.org/10.1038/s41586-021-04268-7), `R210`) † | Prime's phases already wrap onto a bounded torus, so values cannot blow up in long runs (Derived). The fast and slow bands of the state may be split to match several map scales (Open) |
| **Trying futures before acting** | Before a path is chosen, the hippocampus flicks about eight times a second between candidate futures ([Kay et al., *Cell* 2020](https://doi.org/10.1016/j.cell.2020.01.014), `R218`) † | Prime checks several "what if" drives against the exact wave physics before it commits, and keeps the existing rule that it learns only from real errors (Open) |
| **Silent thought, then words** | Non-verbal thought reaches the language network only at the end, to be spoken or to be understood (`R216`) † | Prime thinks silently, then a frozen local language model reads its settled state through a simple geometric map, so its words stay tied to the physics (Open; task #127 is building the first test) |

**What a first test would be.** The bridge is judged against three controls on the same questions: the language model alone, the language model with only the geometric map, and a random map. The map is adopted only if it beats all three (Open; not run). The ideas on the machine-learning side come from 2024–2026 preprints: models that learn in an internal space and are translated outward ([LLM-JEPA](https://arxiv.org/abs/2509.14252), `R223`; [LeJEPA](https://arxiv.org/abs/2511.08544), `R224`; [H-JEPA](https://arxiv.org/abs/2610.06805), `R227`; [Counterfactual world models](https://arxiv.org/abs/2611.24778), `R228`). Plato's Key (`R222`) is a lab blog post, not a peer-reviewed paper. All of these are Documented as reports and none has been reproduced here.

**What is left out.** The plan assumes no quantum effects in the brain. A calculation of how fast delicate quantum states scramble in warm, wet tissue gives between 10⁻¹³ and 10⁻²⁰ seconds, far too short to drive thought ([Tegmark, *Phys. Rev. E* 2000](https://doi.org/10.1103/PhysRevE.61.4194), `R202`) † (Documented). The older "holonomic" brain idea, that memory is spread like a hologram, is kept only as a mathematical picture of overlapping phase patterns ([Plate, 1995](https://doi.org/10.1109/72.377968), `R203`; [Pribram and Carlton, 1986](https://doi.org/10.1016/0001-6918(86)90062-4), `R199`) †. Laser reference beams in the cortex and quantum claims about microtubules are not used.

<a id="3d-form-drawing-curriculum-oph-quarantine-and-teacher-distillation"></a>

## Training and checks in simulation

All training happens on a workstation (Simulated).

- **Curriculum.** The network learns to form thirteen basic shapes at any orientation: the five regular polyhedra and eight primitives such as sphere, ring, rod and helix.
- **Boundary inputs only.** The true three-dimensional field is used only for training and scoring. In operation the network sees port responses and laser beams. It is also tested with each sensor alone.
- **Teachers.** Large pretrained vision and shape models are distilled offline. They never run on the machine.
- **Larger research network, Prime-Core (#123, Simulated).** Prime-Core runs on the workstation's graphics chip, not on the controller. Its best validation score is J = 0.36318, reached at step 4,843. A further 330 cycles (9,894 steps) ran with no numerical failure and no gain, because every cycle used its limit of four new connection groups. The next lever is a higher limit or a wider layer, not more steps. The same checkpoint scores 0.334 on the test set.
- **Optical-hardware twin (#123, Simulated).** A model of the phase-change optical card (5-bit weights, 0.05 rad of phase jitter, 10,000 photons per reading, 68 to 70 % of weights zero) scores 0.226 on validation and 0.237 on test with no retraining, against 0.363 and 0.334 for the ideal network. The overlap between a text request and the 3D shape falls from 0.35 to 0.07. That drop is the cost of the hardware conversion. Fine-tuning the twin first failed on a noise term, which is fixed. One cycle then needs 8.66 GB at batch size 8, so it has to run at batch size 4 (Open).
- **Four deployment tiers.** Each network is re-scored as: full-precision floating point; 8-bit weights on the microcontroller with converter noise and drift; pruned 8-bit weights on an FPGA; analogue weights in a phase-change medium with limited precision and crosstalk.

The curriculum was run on the earlier small chamber. It has not been repeated for the Desktop Replicator's {{c:mosquito_smi.total_ommatidia}} beams and {{c:desktop_geometry.gap_mm}} mm spacing. Removal is modelled as absorption at a measured resonance, then transport to a crucible; an earlier shortcut that replayed a reversed holding pattern was wrong and has been taken out of the code (Simulated; [why](matter-loop.html#why-reversing-a-holding-pattern-removes-nothing)).

**A learned part may speed up a solver. It may not replace one (Design decision).** The project has the exact equations for sound in air, so a network that guesses the whole field can only be less accurate. It is also slower: touching whole 192³ fields costs about 63 ms of memory traffic on the workstation (Derived), while the fast [field solver](digital-twin.html#solver-tiers) answers in milliseconds. Published comparisons flatter such networks: of 76 papers claiming a learned method beat a standard solver for fluid equations, 79 % had used a weak baseline (Documented: [McGreivy &amp; Hakim, 2024](https://doi.org/10.1038/s42256-024-00897-5)). Prime sits beside the solver, chooses drives, and is always scored against the direct physics solve.

## In the Desktop Replicator

The first [compute card](compute-control.html#compute-card) is an RP2350B microcontroller with {{c:cadence_brain.rp2350_sram_total_kb}} kB of memory. It receives the trained network as 8-bit weights and can then make small corrections, such as for thermal drift, with the same update rule.

**Three networks share the Cadence name** and are not one result.

| Network | Job | Size | State |
|---|---|---|---|
| Shape drawer | Turns a target shape into a sequence of drive patterns | 1,024 hidden units; about 457,000 weights | Simulated on the earlier small chamber. Far too large for the first card |
| Occupancy estimator | Turns sensor readings into a 7 × 7 × 7 map of where material is | 256 hidden units, 343 outputs; 361 to 387 kB at 8 bits | Simulated. The job meant for the first card |
| Sparse occupancy estimator | The same job with most connections removed, in 8 × 8 blocks | 32 to 53 kB at 5 to 10 % of connections | Simulated; firmware source exists. Accuracy disputed, below |

**Why it must be sparse (Derived).** The dense estimator nearly fills the controller's {{c:cadence_brain.rp2350_sram_total_kb}} kB and settles in an estimated 23 ms. The target is to keep {{c:cadence_brain.target_block_sparsity_range|pct}} % of the connections, which brings storage under {{c:cadence_brain.cadence_sparse_max_kb}} kB. The settle target is {{c:cadence_brain.rp2350_settle_target_ms_range|range}} ms (Design target). Instruction counts put the sparse network at 4.4 to 6.1 ms (Derived). No time has been taken on a controller.

**What the sparse network can and cannot do (Simulated).** Two simulations on 18 November 2026 reached opposite conclusions.

- *On the solid plate model it fits but does not work.* Trained on echoes from the solid finite-element model to locate one to four beads, it takes 34 to 53 kB at 5 to 10 % of connections. Its agreement with the true map is 0.24 to 0.39, against 0.92 for the dense network and a required 0.90. The first size that identifies the beads keeps 40 % of connections and takes 164 kB. The stated reason is that the echo from the reverberant plate is close to random speckle, with little structure for a sparse network to use.
- *On the simpler plate model it works.* A network at 5.9 % of connections, 44.9 kB, is reported to agree with the dense network at 0.96 and to settle in 15 ms. It was compared with the dense network, not the true map, and no record of the run is stored (Claim).

The first is the harder test and is the current position: the memory and speed targets are met, the accuracy target is not. A later sizing is in the [subsystem datasheet](subsystems.html#s09-prime-world-model): 15.4 kB of working memory plus a 43.3 kB calibration slot, 58.7 kB of the {{c:cadence_brain.cadence_sparse_max_kb}} kB allowed (Simulated).

**Choices awaiting a ruling.** Give the first card a smaller job, such as locating one bead; raise its memory budget to between 165 and 390 kB; or move the full map to the second card.

**The network must be trained per machine (Simulated).** A dense network trained on five simulated plates scores 0.28 on a sixth. After one sweep of a single sphere through the 343 grid positions on that plate, it scores 0.80 and names the correct beads 99 % of the time. It then forgets the earlier plates. The calibration sweep is therefore also the network's training set. It has to be repeated when the air temperature drifts by more than about {{c:desktop_geometry.air_temp_tolerance_k}} K: a simple linear read-out falls from 0.91 to 0.62 between 0.1 and 0.3 K. Stored calibration goes stale in the same way: its correlation falls to about 0.63 after 0.5 K of air temperature change and 0.65 after 200 µm of gap change ([Acoustics](acoustics.html#known-limits)).

<a id="compute-substrate-ladder-from-prototype-sram-to-near-zero-electricity-wave-media"></a>

## Long-term direction: the substrate ladder

The equations stay fixed while the hardware changes. Each rung is meant to use less electrical power than the one before.

| Rung | Mechanism | Evidence |
|---|---|---|
| 1 · Workstation trainer | Full-precision training with GPU kernels | Simulated; in use |
| 2 · Prototype compute card | Sparse 8-bit network on a microcontroller or optional FPGA | Design decision; sparse target not yet evidenced |
| 3 · Optical cavity with phase-change store | Laser cavities as the nonlinearity; a rewritable hologram as the weights | Component physics documented; composed loop Open |
| 4 · Wave media | Passive wave networks with excitable soft-matter wave substrates | Research hypothesis |

### Rung 3: light does the sum

A network needs a linear step and a bend. Without the bend, many layers act like one.

**The hologram does the linear step.** Light crossing a hologram is multiplied by a fixed table of weights, which is the sum a network layer does (Documented for photonic chips: [Pai et al., 2023](https://doi.org/10.1126/science.ade8450)). At one mode per wavelength cube of 500 nm light, a table of 1,024 × 1,024 weights needs a block about 51 µm on a side (Derived). Learning would mean rewriting spots with small light or heat pulses. This buys speed, not exact arithmetic.

**A laser near switch-on supplies the bend.** A laser diode near threshold responds as exp(x) − ln(y). On paper, that one operation repeated can build every ordinary calculator function (Claim: [Odrzywołek, preprint](https://arxiv.org/abs/2603.21852)). That a real diode follows the law well enough to compute with is also a Claim. The law does not apply to the piezo sources, which are modelled as linear circuits.

**Known limits.**

- *Precision and wear.* Four to eight bits of analogue precision, the rewrite limit and the recall law above.
- *Depth, not width.* Each pass through the cavity loses light. The steps that finish before the signal sinks into noise are set by the cavity's quality factor Q, how long it rings. An earlier project note reports Q of 10 to 100 for a printed resin cavity and a usable depth near ten steps (Claim; no record stored). The number of programs a cavity could be set to is far larger and must not be quoted as depth.
- *Settling fights sensitivity.* The network must shrink disturbances on every pass. The laser is run at switch-on because it is most sensitive there, and a very sensitive system shrinks disturbances least. Whether one operating point does both is Open.

Until rewritable phase-change stores pass an endurance test, all training stays on a workstation and every result is checked outside the optical loop (Design decision).

**The link between plate and store (Open).** One multimode fibre with a 1 mm core could carry about 480,000 spots of 500 nm light, enough for a whole plate pattern (Derived: (π × core width × numerical aperture of 0.22 ÷ wavelength)² ÷ 4). A hologram recorded through the fibre undoes its fixed scramble. The weak point is drift when the fibre bends or warms.

### Rung 4: the medium settles itself

The aim is a medium whose own chemical, dielectric or mechanical relaxation settles to the network's fixed point, so that physics replaces clocked logic. Material, noise, drift and speed are all Open.

## Order of tests for the optical store

None has been run (Open). Each step gives one number, and nothing after step 3 should be argued for until step 3 has its number. The upgrade is tracked in [Upgrades](upgrades.html).

| Step | Test | Number it gives |
|---|---|---|
| 1 | Write one hologram in a phase-change film and read back a known pattern | Bit errors on one page |
| 2 | Store N pages and plot light returned per page against N | The material's M#, and capacity as a share of the ceiling |
| 3 | Send light through one stored weight table | Error against the same sum done digitally |
| 4 | Write, use, rewrite, use again | Contrast kept after N rewrites |
| 5 | Give the store a real echo and ask which stored chord matches | Match rate against the software matcher |
| 6 | Score speed, energy and accuracy against a digital baseline | A filled comparison table |

## Open questions

| Question | Who answers it |
|---|---|
| Which of the two sparse-network results holds when both use the same data? | Simulation and sensing lanes together |
| Does the first card take a smaller job, more memory, or hand the map to the second card? | Ruling by the coordination lane |
| Does it settle in the estimated 4.4 to 6.1 ms on a real controller? | Firmware on a board |
| Do the training results hold for the Desktop Replicator's geometry and sensors? | Simulation on the `desktop-200mm` preset |
| Can a real reciprocal medium supply feedback and local updates at useful precision, at an operating point that is sensitive and still shrinks noise? | Optical experiment; not scheduled |
| Can thick, low-loss phase-change stacks be made? | Materials research |
| Can the machine make its own memory material? Plastics and doped glass look possible; phase-change films of exact composition look hard | Materials research |
| Does a frozen language model, reading Prime's settled state through a simple geometric map, beat the three controls above? | Task #127; not run |
| Does the sound field in the chamber do any useful computing for free while it shapes material? | Not assigned. It must not be counted on in any budget ([reservoir question](biology.html#ideas-that-exist-only-on-paper)) |
