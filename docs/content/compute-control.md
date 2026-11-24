# Compute, sensing and control

<div class="lead">This guide covers the electronics that drive and listen to the chamber of the Desktop Replicator: boards, clock, drive stage, 16-bit receive converters, laser readout, bus and compute card. It also explains the files and the software interface that every machine, real or emulated, must follow.</div>

<div class="diagram">
<svg viewBox="0 0 880 540" role="group" aria-labelledby="cc-title cc-desc" xmlns="http://www.w3.org/2000/svg">
<title id="cc-title">Control electronics of the Desktop Replicator</title>
<desc id="cc-desc">One shared clock and frame-sync line feed two head boards, which drive and listen to the piezo discs, and two laser strip boards. Both send compact measurements over a bus to a plug-in compute card. Three card options exist: a microcontroller card, an optional FPGA card and a reserved slot for a future optical core. Firmware behind one machine interface plays the same drive files whether or not a workstation is attached.</desc>
<defs><marker id="cc-arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8" fill="#186b60"/></marker></defs>
<rect x="30" y="16" width="820" height="44" rx="8" fill="#e2ede5" stroke="#186b60" stroke-width="1.5"/>
<g fill="#f2f5ef" stroke="#186b60" stroke-width="1.5">
<a href="#receive-reading-each-disc-while-it-drives" aria-label="Head boards"><rect x="30" y="82" width="400" height="112" rx="9"/></a>
<a href="#laser-readout-electronics" aria-label="Laser strip boards"><rect x="450" y="82" width="400" height="112" rx="9"/></a>
<a href="#the-bus" aria-label="Bus between boards"><rect x="110" y="216" width="660" height="50" rx="8"/></a>
<rect x="30" y="288" width="820" height="148" rx="10" fill="#e2ede5"/>
<a href="#compute-card" aria-label="Card 1, microcontroller"><rect x="50" y="324" width="246" height="96" rx="8"/></a>
<a href="#compute-card" aria-label="Card 2, optional FPGA"><rect x="317" y="324" width="246" height="96" rx="8"/></a>
<a href="cadence-memory.html" aria-label="Card 3, reserved for a future optical core"><rect x="584" y="324" width="246" height="96" rx="8"/></a>
<a href="#one-contract-files-verbs-and-the-machine-interface" aria-label="Firmware and machine interface"><rect x="30" y="458" width="400" height="64" rx="9"/></a>
<a href="digital-twin.html" aria-label="Workstation twin and trainer"><rect x="450" y="458" width="400" height="64" rx="9"/></a>
</g>
<g pointer-events="none" fill="#173630" font-family="system-ui,sans-serif" text-anchor="middle">
<text x="440" y="36" font-size="14.5" font-weight="700">ONE CLOCK AND ONE FRAME-SYNC LINE FOR EVERY BOARD</text>
<text x="440" y="52" font-size="12">{{c:clock_and_bus.xin_hz|mhz}} MHz oscillator · {{c:clock_and_bus.sys_clk_hz|mhz}} MHz controller clock · skew target {{c:clock_and_bus.sync_skew_max_ns}} ns</text>
<text x="230" y="105" font-size="15" font-weight="600">Head boards (2)</text>
<text x="230" y="126" font-size="12">Six bridge drivers, six piezo discs each</text>
<text x="230" y="145" font-size="12">16-bit converter ({{c:haptic_pzt.adc_fallback_mpn}}) reads each disc while it drives</text>
<text x="230" y="164" font-size="12">Spare disc cancels capacitance drift</text>
<text x="230" y="183" font-size="11.5" fill="#186b60">→ amplitude and phase per tone, per disc</text>
<text x="650" y="105" font-size="15" font-weight="600">Laser strip boards (2)</text>
<text x="650" y="126" font-size="12">{{c:mosquito_smi.total_ommatidia}} self-mixing laser diodes in total</text>
<text x="650" y="145" font-size="12">Amplifier and fast comparator per laser</text>
<text x="650" y="164" font-size="12">No camera, no beam splitter</text>
<text x="650" y="183" font-size="11.5" fill="#186b60">→ shadow level and sound ripple per beam</text>
<text x="440" y="238" font-size="14.5" font-weight="600">Bus ({{c:clock_and_bus.spinal_bus_mbps_range|range}} Mbit/s design range)</text>
<text x="440" y="256" font-size="12">Carries differences from prediction, labelled as measurements</text>
<text x="440" y="311" font-size="14.5" font-weight="700">COMPUTE CARD SLOT: runs Prime, the project's pattern network</text>
<text x="173" y="346" font-size="14" font-weight="600">Card 1 · Microcontroller</text>
<text x="173" y="366" font-size="12">Default (RP2350B)</text>
<text x="173" y="384" font-size="12">Sparse 8-bit network, under {{c:cadence_brain.cadence_sparse_max_kb}} kB</text>
<text x="173" y="402" font-size="12">Settle target {{c:cadence_brain.rp2350_settle_target_ms_range|range}} ms</text>
<text x="440" y="346" font-size="14" font-weight="600">Card 2 · FPGA</text>
<text x="440" y="366" font-size="12">Optional</text>
<text x="440" y="384" font-size="12">Same network in block memory</text>
<text x="440" y="402" font-size="12">Only if speed demands it</text>
<text x="707" y="346" font-size="14" font-weight="600">Card 3 · Optical core</text>
<text x="707" y="366" font-size="12">Reserved, long-term</text>
<text x="707" y="384" font-size="12">Laser cavities, phase-change store</text>
<text x="707" y="402" font-size="12">Open research</text>
<text x="230" y="484" font-size="14.5" font-weight="600">Firmware and machine interface</text>
<text x="230" y="504" font-size="12">Plays .fcode frames · same parser tethered or standalone</text>
<text x="650" y="484" font-size="14.5" font-weight="600">Workstation twin and trainer</text>
<text x="650" y="504" font-size="12">Designs, trains and compiles; not needed at run time</text>
</g>
<g fill="none" stroke="#186b60" stroke-width="2" marker-end="url(#cc-arrow)">
<path d="M230 60 V82"/>
<path d="M650 60 V82"/>
<path d="M230 194 V216"/>
<path d="M650 194 V216"/>
<path d="M440 266 V288"/>
<path d="M230 436 V458"/>
</g>
<path d="M430 490 H450" fill="none" stroke="#186b60" stroke-width="2"/>
</svg>
</div>

*Status:* design decisions and derived estimates, built on Documented methods for piezo self-sensing ([Dosch, Inman &amp; Garcia, 1992](https://doi.org/10.1177/1045389X9200300109)) and laser self-mixing ([Giuliani et al., 2002](https://doi.org/10.1088/1464-4258/4/6/371); [Bertling et al., 2014](https://doi.org/10.1364/OE.22.030346)). Firmware results come from tests on a workstation and are Simulated. The machine is in [Desktop Replicator](desktop-replicator.html) and terms in the [Glossary](glossary.html).

## What this subsystem does

The control system turns a target into twelve timed drive signals, and the returning echoes and laser signals into an estimate of what is in the chamber. Three layers share the work, so edge timing never waits for heavy computing.

| Layer | Timescale | Job | Runs on |
|---|---|---|---|
| Boards at the chamber | Nanoseconds | Make drive edges, sample the returns, find amplitude and phase per tone | Microcontrollers on the head and laser boards |
| Compute card | Milliseconds | Choose the next drive pattern from the sensed state | Prime, the project's model built on the Cadence library, on the plug-in card |
| Workstation | Seconds to hours | Design geometry, train the network, compile patterns | The [digital twin](digital-twin.html); not needed at run time |

<a id="compiler-wire-contract-machinebackend-fcode-and-ring-0-parity"></a>

## One contract: files, verbs and the machine interface

Everything above the boards speaks one narrow interface, so hardware and emulator can be swapped. The exact fields of every file and packet are in [Subsystems and interfaces](subsystems.html#contracts).

**Three records are kept apart.**

| Record | What it is for |
|---|---|
| Holographic equation (`.holo`, format `holo-eq/0.2`) | The stored description of an object. It does not depend on any one machine. It says what to make |
| Chord | One set of drive values: an amplitude and a phase for each source at each tone. It belongs to one chamber in one state and is computed when needed |
| `.fcode` | What a machine plays: frames in time order, each with one chord, a duration, a verb and the channels to record |

The compiler turns a holographic equation into `.fcode` for one machine, using that machine's calibration. Every stored item states whether it was measured or inferred, and the compiler refuses an inferred item unless it has been explicitly promoted.

An earlier format, `.pattern`, stored chords. It is superseded as the store, because chords do not survive a change of chamber ([below](#holographic-equations)). The workbench and the [chord memory](cadence-memory.html#chord-memory) still use it.

**Verbs.** One per frame.

| Verb | Code | Meaning | State of the code |
|---|---|---|---|
| ADD | 1 | Apply the chord as written | Implemented |
| REMOVE | 2 | Release and remove material: the object absorbs sound at a resonance measured from its echo, then the freed material is carried to a crucible | Implemented in the simulation and the twin (Simulated) |
| LISTEN | 3 | Play the chord at one thousandth of the amplitude (60 dB down) to probe without disturbing | Implemented |

REMOVE is not ADD played backward. An earlier shortcut replayed a reversed holding pattern. That was wrong, because a reversed pattern rebuilds the same trap. It has been removed from the code ([why](matter-loop.html#why-reversing-a-holding-pattern-removes-nothing)).

**The machine interface.** Hardware and emulator implement the same four calls, named `MachineBackend` in the twin:

```text
describe()             -> geometry, channels, limits and the plate-response file
calibrate()            -> empty-chamber response and sensor baselines
play(frames)           -> plays .fcode frames, returns what the ports recorded
listen(gates, steps)   -> records the port response to a low-level probe
```

A feature that cannot be written as calibrate, play or listen belongs to the simulator (Design decision). A recorded job must replay through the emulator and give, byte for byte, the frame log the hardware link would receive.

The [plate-response file](digital-twin.html#the-plate-response-file) holds one machine's transfer from drive voltage to plate motion at each tone. Its current version, `body-response/0.2`, also holds the receive path, and it refuses an export sampled more coarsely than half a wavelength at the top tone. Version 0.1 had neither. The compiler maps the wanted field through this file. The presets are `desktop-200mm` and the small `boro12`.

### Holographic equations

**Why chords cannot be the record (Simulated).** In a pre-registered simulation, drives optimised per shape on the nominal plate scored 0.60 to 1.00 overlap with their targets. Replayed on plates half a percent different in thickness, they fell to chance. The same happens when the cylinder changes size, sources are added, or the air warms by a couple of kelvin. A stored chord describes a chamber, not an object.

**What the file holds.** It describes the object about its own centre, in two parts written as spherical waves.

- *The write form* is the sound field the object needs around it, in one or more steps called strokes.
- *The read form* is how the object scatters sound: a table that turns any incoming wave into the outgoing one.

Turning or moving the object is therefore an exact calculation and needs no new optimisation (Derived).

**How a machine uses it.** Each chamber measures, during calibration, what one volt on each source produces at the object's position. ADD compiles the goal through that measurement into drive values, within the voltage it has. LISTEN predicts the echo the object should return and compares it with the measured one. REMOVE uses the measured echo to compute the drive the object absorbs best.

**A build is finished when the echo matches (Design decision).** The machine drives, listens, and compares the echo with the one the finished object should give. The build is done when the two match, not when the frame list runs out. Listening uses little power, so it runs all through the build. One number, the echo mismatch, is the stop rule and is what the operator sees. A matching echo is still not a passed part ([what a scan may claim](matter-loop.html#what-a-scan-is-allowed-to-claim)).

**Carry the goal, not the field (Simulated).** Reproducing the stored field on each chamber wastes the supply: it lifts 50 to 1,000 times less than the chamber's own best. Carrying the goal (the sites to hold and the clearance around them) lets each chamber choose its own field. That matches a direct solve within 1 % on chambers with 12 and with 36 sources. The format therefore stores the goal.

**What the experiments support so far (Simulated, pre-registered, 22 November 2026).**

- A rule re-derived from each chamber's calibration beats a stored chord on plates it was not tuned for: mean overlap 0.32 against 0.04.
- Thirty further iterations on the chamber's own calibration bring that to 86 % of a full per-chamber optimisation, above chance on all 65 plate and shape pairs tested.
- The equation is not yet short: no compact list of modes reached 95 % of the fully optimised result. Deriving the drive from listening alone failed.
- Thin objects cost lift. Written one site at a time with neighbouring traps suppressed, three of six test objects fell below their own weight on twelve sources.

These scores measure where the pressure nodes fall on a 7 × 7 × 7 grid. They do not simulate material being held.

**Limits that are physics (Derived).** At the default detail the write form describes the field only within about 2 mm of the object's centre at the top tone, so larger objects need more terms or several centres. Twelve sources make only twelve independent fields per tone, so compilation reports how much of the equation it could not meet. A scan can recover only the part of the read form that the sources can see.

**Several materials.** A follow-on version, `holo-eq/0.3-mm`, stores a list of materials and where each sits, and rebuilds the scattering table from a material model.

**To the controller.** The controller receives not the file but a short packet (`HLEQ`) that sets the goal for the on-board pattern network without using extra memory.

**Calibration uses a symmetry of still air (Derived).** In still air the response from source A to source B equals the response from B to A. Calibration therefore measures 78 pairs of the twelve sources instead of 144, and recovers each channel's send and receive gains. A departure from the symmetry during a build means the air is moving or the machine has drifted, and serves as an alarm.

**Firmware.** The firmware source holds the drive and receive programs, the laser-strip readout, the bus, lock-in detection, the frame scheduler and the sparse pattern network. Its 59 tests pass on a workstation and its constants match the shared file (Simulated). There is no main program and no build for a board. It parses the same frames from a workstation over USB-C or from the compute card, so unplugging the workstation should leave the machine running.

## In the Desktop Replicator

### Boards and controllers

The count of {{c:clock_and_bus.pcb_count}} boards means the field boards: two identical head boards behind the wafers, and the backplane in the base with the clock, power conversion and compute-card socket. The bill of materials adds two laser strip boards, a display board and the compute card. With the first compute card there are six microcontrollers: one per head board, one per laser strip (an assumption), one on the compute card and one for the display.

Part numbers are in [Desktop Replicator](desktop-replicator.html#electronics). The power estimate is 17.0 W with the first compute card and 22.5 W with the second. The warmest internal air is 12.7 K above ambient against a 20 K limit (Derived; [Heat](desktop-replicator.html#heat)).

<a id="shared-xin-sync-clock-and-the-topographic-spinal-bus"></a>

### Clock and timing

Every controller runs from one {{c:clock_and_bus.xin_hz|mhz}} MHz oscillator on the backplane, sent over matched traces, and multiplies it to {{c:clock_and_bus.sys_clk_hz|mhz}} MHz. Every frame starts on one shared sync line.

The shared clock is necessary. Two free-running crystals rated at ±30 parts per million can differ by 60. At 160 kHz that is a 9.6 Hz beat between the plates, so no trap would stay still.

The timing figures (Derived):

- One controller clock tick is {{c:clock_and_bus.pio_tick_ns}} ns, which is {{c:clock_and_bus.pio_tick_phase_deg_at_160khz}}° (about 0.38°) of phase at 160 kHz.
- The board-to-board skew target is {{c:clock_and_bus.sync_skew_max_ns}} ns, which is 0.12° at 160 kHz.
- No tone has a whole number of clock ticks per period: {{c:clock_and_bus.sys_clk_hz|mhz}} MHz divided by 32 kHz is 4687.5. Firmware needs fractional timing or must accept one tick of jitter.

How the multiplied clocks on different boards are brought into a known phase is Open.

### Drive stage

Each piezo disc ([piezo physics](acoustics.html#in-the-desktop-replicator)) is driven by a pair of gate-driver outputs wired as a full bridge. Diodes ({{c:haptic_pzt.clamp_diode_mpn}}) protect the receive path. The candidate driver is {{c:haptic_pzt.hbridge_driver_mpn}}, rated to {{c:haptic_pzt.hbridge_driver_v_max}} V. It can switch its outputs off so the disc can listen. Its values have not been re-read from a current datasheet. The bridge supply is {{c:haptic_pzt.bridge_rail_v}} V.

Each bridge has four states (Design decision): push (plus the supply across the disc), pull (minus the supply), brake (both sides at zero volts, which damps the disc) and float (disconnected, so the disc only listens). The electrical contract is in [Subsystems and interfaces](subsystems.html#contracts).

**Safety switch (Design decision).** A hardware switch sits in series with the supply that enables the bridges and with the laser supply. With the head up, the bridges are disconnected (high impedance) and the lasers are off. Firmware also refuses to drive. The laser class is Open ([Thermal and safety](subsystems.html#s11-thermal-and-safety)).

**Drive voltage is scarce (Derived).** A {{c:haptic_pzt.bridge_rail_v}} V bridge gives {{c:haptic_pzt.max_drive_vrms}} V rms at a single tone, and {{c:haptic_pzt.max_drive_vrms_5tone_per_tone}} V rms per tone when five tones share the swing. Force grows with voltage squared, and the planner refuses any plan above what the supply delivers. On 18 November 2026 the supply was raised from 12 V to {{c:haptic_pzt.bridge_rail_v}} V and the discs were enlarged, because the solid finite-element model shows that a first levitation needs both, with one tone and a foam bead. One 160 kHz tone on the full supply lifts about 1.2 times a foam bead's weight. Five tones sharing the supply lift about 7 % (Simulated; [Acoustics](acoustics.html#known-limits)). A front-end circuit with a grounded sensing node would need single-ended drive, which halves the voltage.

**Square-wave harmonics land on the tones (Derived).** A square wave at 32 kHz also contains weaker waves at three and five times its frequency: 96 and 160 kHz, exactly on two of the five tones.

The piezo port is modelled as a linear circuit: a capacitance in parallel with a series resonant branch for the mechanics.

<a id="acoustic-lamina-75-msas-1-bit-sigma-delta-piezo-haptic"></a>

### Receive: reading each disc while it drives

Each disc is read while it is driven. The echo is 1,000 to 10,000 times smaller than the drive current (60 to 80 dB down), and the disc's own capacitance drifts by about {{c:haptic_pzt.c0_tempco_pct_per_c}} % per kelvin, a larger change than the echo ([why](acoustics.html#self-sensing-on-the-same-two-wires)).

**What is fitted (Design decision; converter choice Simulated).** A 16-bit converter ({{c:haptic_pzt.adc_fallback_mpn}}) reads each disc through a tap that divides the signal by twenty. Each head board carries four of them, giving eight channels for six discs and one spare disc. The spare is bonded to nothing: it drifts like the others but hears nothing, so subtracting it removes the drift. The controller sits within millimetres of the discs, which holds stray capacitance under {{c:haptic_pzt.max_trace_cap_pf}} pF against about {{c:haptic_pzt.c0_nominal_pf}} pF for the disc. Each 10 ms frame holds one {{c:clock_and_bus.capture_burst_us}} µs capture. The receive band is {{c:haptic_pzt.ultrasonic_bw_hz|khz}} kHz. Whether this path resolves the echo with five tones present is Open.

**What it replaced: a 1-bit converter that failed (Simulated, 18 November 2026).** The first design used a comparator ({{c:haptic_pzt.comparator_mpn}}), a part that only answers "higher" or "lower", {{c:haptic_pzt.sigma_delta_fs_hz|mhz}} million times a second. It had to show at least {{c:haptic_pzt.sfdr_gate_min_db}} dB between the wanted tones and the largest false tone. A cycle-by-cycle simulation over 144 sets of part values reached {{c:haptic_pzt.sfdr_simulated_dbc}} dB at best. No part values could have passed: an ideal converter of this kind reaches only {{c:haptic_pzt.ideal_1bit_sqnr_200khz_db}} dB over the {{c:haptic_pzt.ultrasonic_bw_hz|khz}} kHz band at an oversampling ratio of {{c:haptic_pzt.osr}}, about 188 (Derived). The earlier estimate of {{c:haptic_pzt.enob_range|range}} bits was not supported. The 16-bit converter was then fitted on footprints already on the board. Two lessons carry over:

- An echo 70 dB below the drive was still recovered in one 14 ms frame at 80 to 87 dB, and at 75 to 78 dB under board-level stress, after filtering and a lower sample rate.
- Timing the zero crossings of the current cannot work: such an echo moves a crossing by less than 0.2 ns, and five tones mean ten unknowns where one crossing gives one number.

### Lock-in detection and its workload

Lock-in detection finds amplitude and phase at each tone: multiply the samples by a reference sine and cosine at that tone, and add up.

- **Piezo channels.** Demodulating the 8 converter channels of a head board takes an estimated 4 ms of each 10 ms frame (Derived from instruction counts). Whether one controller can take in the converter data while it also makes the drive edges is Open.
- **Square-wave references leak.** With a square-wave reference, the reading for 32 kHz picks up one third of the 96 kHz signal and one fifth of the 160 kHz signal. Firmware must subtract them in a fixed order (Simulated).
- **Laser channels.** A comparator gives single bits, so multiplying shrinks to an exclusive-or and a count of set bits. The twelve channels of one strip board, at {{c:haptic_pzt.sigma_delta_fs_hz|mhz}} million bits per second each, with five tones and two references per tone, still come to about 3 × 10⁸ word operations per second (Derived). The controller has 3 × 10⁸ clock cycles per second on each of two cores, so continuous demodulation does not fit. Firmware needs burst capture or a reduced sample rate. The scheme is Open.

<a id="optical-mosquito-eye-diffractive-facets-and-self-mixing-interferometry"></a>

### Laser readout electronics

The optical sensor is a ring of {{c:mosquito_smi.total_ommatidia}} laser diodes at {{c:mosquito_smi.laser_wavelength_nm}} nm. Each diode is its own detector, a method called self-mixing ([optics](optics.html#coherent-self-mixing-optical-readout)).

Each channel has one amplifier ({{c:mosquito_smi.tia_mpn}}) and one fast comparator ({{c:mosquito_smi.comparator_mpn}}), which turns the signal into single bits on the same clock as the piezo channels. Whether a comparator gives the laser signal enough range is Open.

Published work reports tens of microvolts to about a millivolt per optical fringe, on a level of about 2 V (Documented: Giuliani et al.). The level expected on this machine's beam path is Open.

The amplifier circuit is Open. The constants give a gain of {{c:mosquito_smi.tia_ac_gain}}. As voltage gain in a single stage, a part with about 20 MHz gain-bandwidth rolls off at about 100 kHz, below the top tone (Derived). Two stages or a current-input (transimpedance) design are needed.

### The bus

The head and laser boards do not send raw samples. Each subtracts what it expects: the drift reference and the predicted empty-chamber response to its own drive. It sends the difference as one complex number per tone, labelled as a measurement. Anything the network fills in is labelled inferred until a sensor confirms it.

The link is serial, with a design range of {{c:clock_and_bus.spinal_bus_mbps_range|range}} Mbit/s. Its message layout is Open.

<a id="central-complex-sparse-complex-hermitian-cadence-and-the-swappable-brain-slot"></a>

### Compute card

The backplane has one M.2 socket behind a side hatch. The card runs Prime, the pattern network in [Cadence, memory and wave compute](cadence-memory.html). A different card changes speed and power but not the software above it.

| Card | Status | Network storage | Settle time |
|---|---|---|---|
| 1 · RP2350B microcontroller | Default | Sparse 8-bit weights, under {{c:cadence_brain.cadence_sparse_max_kb}} kB of {{c:cadence_brain.rp2350_sram_total_kb}} kB memory. It fits, but accuracy at that size is disputed | Target {{c:cadence_brain.rp2350_settle_target_ms_range|range}} ms (Design target). Instruction counts give 4.4 to 6.1 ms (Derived) |
| 2 · FPGA module | Optional | The same network in block memory | Microseconds as a design target; not modelled |
| 3 · Optical core | Reserved | Analogue weights in an optical medium | Set by light travel time; long-term research |

Card 2 is justified only by a need for faster reflexes, wider converters or a large modulator interface. Tests of the sparse network for Card 1 are in the [Cadence guide](cadence-memory.html#in-the-desktop-replicator).

## Long-term direction

The long-term design keeps the contract above and replaces what implements it. None of this has been simulated as a composed system ([Architecture](architecture.html#long-term-architecture-and-the-desktop-replicator)).

- **Sources.** A continuous piezoelectric layer with about 10⁵ optically switched elements replaces the twelve wired discs ([Acoustics](acoustics.html#long-term-direction)).
- **Sensing.** Passive diffractive optics and fibre-coupled tomography replace discrete laser channels ([Optics](optics.html#long-term-direction)).
- **Computing.** Waves in optical cavities and, later, excitable soft-matter wave substrates replace the clocked controller ([substrate ladder](cadence-memory.html#long-term-direction-the-substrate-ladder)).

## Open questions

| Question | Who answers it |
|---|---|
| Does the 16-bit receive path resolve the echo with five tones present, and what is the front-end circuit? | Electrical design and simulation |
| What drive stage and voltage does a holding pressure require, given the solid plate model? | Electrical design and plate model together |
| How are fractional tick periods and shared square-wave harmonics handled? | Firmware design |
| How are the multiplied clocks on different boards phase-aligned? | Circuit and firmware design |
| Can one controller take in the converter data beside the drive output, and how are the laser channels demodulated? | Firmware in emulation |
| Is a comparator good enough for the laser signal? Which amplifier circuit, and what signal level reaches it? | Circuit design and simulation |
| What is the bus message layout? | Firmware design |
| What is the laser class? | Safety review |
