# Compute, sensing and control

<div class="lead">This chapter covers the electronics and control loop of the Desktop Replicator: boards, clock, drive stage, 1-bit receive converters, laser readout, bus and compute card. It also defines the file formats and the software interface that every machine, real or emulated, must honour. Nothing described here has been built or measured.</div>

<div class="diagram">
<svg viewBox="0 0 880 540" role="group" aria-labelledby="cc-title cc-desc" xmlns="http://www.w3.org/2000/svg">
<title id="cc-title">Control electronics of the Desktop Replicator</title>
<desc id="cc-desc">One shared clock and frame-sync line feed two head boards, which drive and listen to the piezo discs, and two laser strip boards. Both send compact measurements over a bus to a plug-in compute card. Three card options exist: a microcontroller card, an optional FPGA card and a reserved slot for a future optical core. Firmware behind one machine interface plays the same drive files whether or not a workstation is attached.</desc>
<defs><marker id="cc-arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8" fill="#186b60"/></marker></defs>
<rect x="30" y="16" width="820" height="44" rx="8" fill="#e2ede5" stroke="#186b60" stroke-width="1.5"/>
<g fill="#f2f5ef" stroke="#186b60" stroke-width="1.5">
<a href="#receive-a-1-bit-converter-on-every-disc" aria-label="Head boards"><rect x="30" y="82" width="400" height="112" rx="9"/></a>
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
<text x="230" y="145" font-size="12">1-bit converter per disc, {{c:haptic_pzt.sigma_delta_fs_hz|mhz}} million samples/s</text>
<text x="230" y="164" font-size="12">Spare disc cancels capacitance drift</text>
<text x="230" y="183" font-size="11.5" fill="#186b60">→ amplitude and phase per tone, per disc</text>
<text x="650" y="105" font-size="15" font-weight="600">Laser strip boards (2)</text>
<text x="650" y="126" font-size="12">{{c:mosquito_smi.total_ommatidia}} self-mixing laser diodes in total</text>
<text x="650" y="145" font-size="12">Amplifier and 1-bit converter per laser</text>
<text x="650" y="164" font-size="12">No camera, no beam splitter</text>
<text x="650" y="183" font-size="11.5" fill="#186b60">→ shadow level and sound ripple per beam</text>
<text x="440" y="238" font-size="14.5" font-weight="600">Bus ({{c:clock_and_bus.spinal_bus_mbps_range|range}} Mbit/s design range)</text>
<text x="440" y="256" font-size="12">Carries differences from prediction, labelled as measurements</text>
<text x="440" y="311" font-size="14.5" font-weight="700">COMPUTE CARD SLOT — runs the Cadence pattern network</text>
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

*Status:* design decisions and derived estimates, built on documented methods for piezo self-sensing ([Dosch, Inman &amp; Garcia, 1992](https://doi.org/10.1177/1045389X9200300109)) and laser self-mixing ([Giuliani et al., 2002](https://doi.org/10.1088/1464-4258/4/6/371); [Bertling et al., 2014](https://doi.org/10.1364/OE.22.030346)). The machine is described in [Desktop Replicator](desktop-replicator.html); terms are in the [Glossary](glossary.html).

## What this subsystem does

The control system turns a target into twelve timed drive signals, and turns the returning echoes and laser signals into an estimate of what is in the chamber. It works on three timescales with separate owners, so that edge timing never waits for heavy computation.

| Layer | Timescale | Job | Runs on |
|---|---|---|---|
| Boards at the chamber | Nanoseconds | Generate drive edges, sample the returns, extract amplitude and phase per tone | Microcontrollers on the head and laser boards |
| Compute card | Milliseconds | Choose the next drive pattern from the sensed state | The Cadence network on the plug-in card |
| Workstation | Seconds to hours | Design geometry, train the network, compile patterns | The [digital twin](digital-twin.html); not needed at run time |

<a id="compiler-wire-contract-machinebackend-fcode-and-ring-0-parity"></a>

## One contract: files, verbs and the machine interface

Everything above the boards speaks one narrow interface, so real hardware and the emulator are interchangeable.

**Chord, `.pattern` and `.fcode`.** A chord is one set of complex drive values: an amplitude and a phase for each source at each tone. A `.pattern` file stores an object or field shape as one or more chords, each marked as measured or inferred; it says what to make, not when. A `.fcode` file is what a machine plays: a time-ordered list of frames, each with one chord, a duration, a verb and the channels to record. The compiler turns a `.pattern` into `.fcode` for a particular machine and refuses an inferred chord unless it has been explicitly promoted. On the wire, `.fcode` is a compact binary stream with 16-bit drive values (tagged `FCD1`).

**Verbs.** Each frame carries one of three verbs.

| Verb | Code | Meaning | State of the code |
|---|---|---|---|
| ADD | 1 | Apply the chord as written | Implemented |
| REMOVE | 2 | Release and remove material, as one step of the recovery sequence | Implemented incorrectly; see below |
| LISTEN | 3 | Play the chord at one thousandth of the amplitude (60 dB down) to probe without disturbing | Implemented |

REMOVE is not a reversed or mirrored ADD. The force on a small object depends on the squared magnitude of the pressure field. Flipping the sign of every phase leaves that magnitude unchanged, so a mirrored holding pattern rebuilds the same trap. The present code still implements REMOVE by taking the complex conjugate of the drive, and one simulation path fakes dispersal with a negative acoustic intensity. Both shortcuts are known to be physically wrong and have not yet been replaced. The correct sequence is in [Scan, recover and matter stores](matter-loop.html).

**The machine interface.** Hardware and emulator implement the same four calls, named `MachineBackend` in the twin:

```text
describe()             -> geometry, channels, limits and the body-response file
calibrate()            -> empty-chamber response and sensor baselines
play(frames)           -> plays .fcode frames, returns what the ports recorded
listen(gates, steps)   -> records the port response to a low-level probe
```

The body-response file (`body-response/0.1`) holds one machine's transfer from drive voltage to plate motion at each tone. Planning code states the field it wants, and the compiler maps that through the file for the machine in front of it. The current presets are `desktop-200mm` and the small `boro12`.

**Firmware.** The firmware target is `twin/Firmware/desktop/`. It does not exist yet; the only firmware in the repository belongs to the retired P0 array and is kept as a regression case. The intent is bare-metal code with no operating system, under about ten thousand lines, that parses the same frames whether they come from a workstation over USB-C or from the compute card. Unplugging the workstation should leave the machine running.

## In the Desktop Replicator

### Boards and controllers

The count of {{c:clock_and_bus.pcb_count}} boards refers to the three field boards: two identical head boards behind the wafers, and the backplane in the base with the clock, power conversion and compute-card socket. The bill of materials lists more: two laser strip boards in the tower, a display board in the head, and the compute card. With the first compute card fitted there are six microcontrollers: one per head board, one per laser strip, one on the compute card and one for the display. One controller per laser strip is an assumption.

Part numbers, power and heat are in [Desktop Replicator](desktop-replicator.html).

<a id="shared-xin-sync-clock-and-the-topographic-spinal-bus"></a>

### Clock and timing

Every controller runs from one {{c:clock_and_bus.xin_hz|mhz}} MHz oscillator on the backplane, distributed over matched traces, and every frame starts on one shared sync line. Each controller multiplies the reference to {{c:clock_and_bus.sys_clk_hz|mhz}} MHz.

The shared clock is necessary. Two free-running crystals rated at ±30 parts per million can differ by 60 parts per million, which at 160 kHz is a 9.6 Hz beat between the plates. The standing-wave pattern would cycle about ten times a second and no trap would stay still.

The timing figures, as given by an audit of the engineering record (Derived):

- One controller clock tick is {{c:clock_and_bus.pio_tick_ns}} ns, which is 0.38° of phase at 160 kHz.
- The board-to-board skew target is {{c:clock_and_bus.sync_skew_max_ns}} ns, which is 0.12° at 160 kHz. An older figure of 0.1° was computed at 40 kHz.
- No tone of the full-size machine has a whole number of clock ticks per period: {{c:clock_and_bus.sys_clk_hz|mhz}} MHz divided by 32 kHz is 4687.5. Firmware needs fractional timing or must accept one tick of jitter.

How the multiplied clocks on different boards are brought into a known phase relative to each other is Open.

### Drive stage

Each piezo disc is driven by a pair of gate-driver outputs ({{c:haptic_pzt.hbridge_driver_mpn}}) wired as a full bridge, with diodes ({{c:haptic_pzt.clamp_diode_mpn}}) protecting the receive path. The electrical estimate assumes a 12 V bridge rail. Two limits follow, as given by the audit (Derived).

**The voltage assumptions disagree.** The body-response file allows up to 40 V rms per source. A 12 V bridge gives about 11 V rms at a single tone, and less per tone when five tones share the swing. Force scales with voltage squared, so planning results that assume 40 V overstate force by roughly an order of magnitude until the two figures agree.

**Square-wave harmonics land on the comb.** A square wave at 32 kHz has its third and fifth harmonics at 96 and 160 kHz, exactly on two of the five tones.

The piezo port is modelled with a linear equivalent circuit: a capacitance in parallel with a series resonant branch for the mechanics. The exponential-and-logarithm threshold law in the long-term compute ladder describes laser cavities and does not apply to the piezo.

<a id="acoustic-lamina-75-msas-1-bit-sigma-delta-piezo-haptic"></a>

### Receive: a 1-bit converter on every disc

Each disc is read while it is driven. The physics of that self-sensing is in [Acoustics](acoustics.html); this section covers the converter.

The wanted signal is small. The echo from a 2 mm droplet is estimated at 60 to 80 dB below the drive current, while the ceramic's capacitance drifts by about {{c:haptic_pzt.c0_tempco_pct_per_c}} % per kelvin, a change about 50 dB below the drive (Derived). Timing the zero crossings of the current cannot recover it: an echo 70 dB down moves a crossing by less than 0.2 ns, and two crossings per period cannot separate five tones.

The design closes a sigma-delta loop around a fast comparator ({{c:haptic_pzt.comparator_mpn}}) with two resistors, one capacitor and two controller pins. The output is a stream of single bits at {{c:haptic_pzt.sigma_delta_fs_hz|mhz}} million samples per second whose density follows the input. A seventh comparator on each board reads a spare disc that is not bonded to the wafer. It drifts like the others but hears nothing, so subtracting it removes the drift. Keeping the controller within millimetres holds stray capacitance under {{c:haptic_pzt.max_trace_cap_pf}} pF, against about {{c:haptic_pzt.c0_nominal_pf}} pF for the disc.

For an ideal first-order 1-bit loop the signal-to-quantisation-noise ratio is

    SQNR ≈ 6.02 + 1.76 − 5.17 + 30·log₁₀(OSR)  dB,   OSR = f_s / (2·B)

With a band B of {{c:haptic_pzt.ultrasonic_bw_hz|khz}} kHz the oversampling ratio is {{c:haptic_pzt.osr}} and the result is about 74 dB, or 12 bits (Derived). The constants quote {{c:haptic_pzt.enob_range|range}} bits; the first-order formula supports only the lower end.

**The band definition is inconsistent** (Derived, as given by the audit). The stated band is {{c:haptic_pzt.ultrasonic_bw_hz|khz}} kHz, but the top tone is 160 kHz and the small preset reaches 200 kHz. At a 200 kHz band the ratio is about 188 and the ideal figure drops to about 71 dB, below the acceptance gate of {{c:haptic_pzt.sfdr_gate_min_db}} dB.

The gate is a bit-exact simulation with five tones present, which must show at least {{c:haptic_pzt.sfdr_gate_min_db}} dB between the wanted tones and the largest spurious product. If it fails, the boards take a conventional converter ({{c:haptic_pzt.adc_fallback_mpn}}) on footprints already provided. The simulation has not been run for the current geometry.

### Lock-in detection and its workload

Amplitude and phase at each tone are recovered by correlating the bit stream with a reference sine and cosine. Because the stream is one bit wide, multiplication reduces to an exclusive-or and a count of set bits.

Whether this fits in the controller is Open. Each channel produces {{c:haptic_pzt.sigma_delta_fs_hz|mhz}} million bits per second. Six channels, five tones and two references per tone come to the order of 10⁸ word operations per second, on a controller with 3 × 10⁸ clock cycles per second across two cores. Continuous software demodulation of every channel is unlikely to fit, so firmware will need burst capture or decimation. The {{c:mosquito_smi.total_ommatidia}} laser channels add more.

<a id="optical-mosquito-eye-diffractive-facets-and-self-mixing-interferometry"></a>

### Laser readout electronics

The optical sensor is a ring of {{c:mosquito_smi.total_ommatidia}} laser diodes at {{c:mosquito_smi.laser_wavelength_nm}} nm, nicknamed the mosquito eye. Each diode is its own detector: light returning from a reflector re-enters the laser and modulates it, and the photodiode in the same package reads the result. This is self-mixing interferometry (SMI); the optics are in [Optics and optical metamaterials](optics.html).

Each channel has one amplifier ({{c:mosquito_smi.tia_mpn}}) and one comparator ({{c:mosquito_smi.comparator_mpn}}) running the same 1-bit conversion as the acoustic channels, so both sensors share one clock and one demodulation method. Published self-mixing work reports changes of tens of microvolts to about a millivolt per optical fringe on a level of about 2 V (Documented: Giuliani et al.). The level expected over this machine's beam path has not been derived and is Open.

The amplifier topology is Open (Derived, as given by the audit). The constants specify a gain of {{c:mosquito_smi.tia_ac_gain}}. As voltage gain in a single stage, a part with about 20 MHz gain-bandwidth rolls off at about 100 kHz, below the top tone. Two stages or a transimpedance design are needed.

### The bus

The head and laser boards do not send raw samples. Each subtracts what it expects (the drift reference and the predicted empty-chamber response to its own drive) and sends the difference as complex numbers per tone, labelled as measurements. Anything the network later fills in is labelled as inferred until a sensor confirms it.

The link is a serial connection with a design range of {{c:clock_and_bus.spinal_bus_mbps_range|range}} Mbit/s. Its message layout is Open.

<a id="central-complex-sparse-complex-hermitian-cadence-and-the-swappable-brain-slot"></a>

### Compute card

The backplane has one socket in the M.2 form factor, reached through a side hatch. The card runs the Cadence pattern network, described in [Cadence, memory and wave compute](cadence-memory.html). The network has the same definition on every card, so a different card changes speed and power but not the software above it.

| Card | Status | Network storage | Settle time |
|---|---|---|---|
| 1 · RP2350B microcontroller | Default | Sparse 8-bit weights, under {{c:cadence_brain.cadence_sparse_max_kb}} kB of {{c:cadence_brain.rp2350_sram_total_kb}} kB memory | Target {{c:cadence_brain.rp2350_settle_target_ms_range|range}} ms; not yet evidenced |
| 2 · FPGA module | Optional | The same network in block memory | Microseconds as a design target; not modelled |
| 3 · Optical core | Reserved | Analogue weights in an optical medium | Set by light propagation; long-term research |

Card 2 is justified only by a need for faster reflexes, wider converters or a large modulator interface. How far the sparse network for Card 1 has been tested is in the [Cadence chapter](cadence-memory.html#in-the-desktop-replicator).

## Long-term direction

The prototype electronics are purchasable scaffolding. The long-term design keeps the contract above and replaces what implements it.

- **Sources.** The twelve wired discs give way to a continuous piezoelectric layer with about 10⁵ optically switched elements. See [Acoustics](acoustics.html).
- **Sensing.** Discrete laser channels give way to passive diffractive optics and fibre-coupled tomography. See [Optics and optical metamaterials](optics.html).
- **Computing.** The clocked controller gives way to wave-based computing in optical cavities and, later, excitable soft-matter wave substrates. See the [substrate ladder](cadence-memory.html#long-term-direction-the-substrate-ladder).

None of these has been simulated as a composed system. [Architecture](architecture.html) sets the two designs side by side.

## Open questions

| Question | Who answers it |
|---|---|
| Is the receive band {{c:haptic_pzt.ultrasonic_bw_hz|khz}} kHz, or wide enough for the 160 and 200 kHz tones? | Constants owner, then simulation |
| Does the 1-bit converter reach {{c:haptic_pzt.sfdr_gate_min_db}} dB with five tones present? | Bit-exact simulation |
| Is the drive level 40 V rms or what a 12 V bridge delivers? | Electrical design and plate model together |
| How are fractional tick periods and shared square-wave harmonics handled? | Firmware design |
| How are the multiplied clocks on different boards phase-aligned? | Circuit and firmware design |
| Can lock-in detection run continuously on all channels? | Firmware in emulation |
| Which laser amplifier topology, and what signal level reaches it? | Circuit design |
| What is the bus message layout? | Firmware design |
