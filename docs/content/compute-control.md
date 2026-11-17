# Compute, sensing and control

<div class="lead">The Replicator's control architecture separates nanosecond boundary reflexes, millisecond equilibrium settling, and offline twin design under one deterministic wire contract (<code>.fcode</code> / <code>.pattern</code> / <code>MachineBackend</code>). Microcontroller ganglia and discrete op-amp bridges are strictly our <strong>Bootstrap Prototype (`P0` / `HA-0`)</strong> realization; the <strong>Ultimate Architecture</strong> executes the exact same wave contract continuously in optically addressed apertures, holographic cavities, and minimal-electricity physical substrates.</div>

<div class="diagram">
<svg viewBox="0 0 880 540" role="group" aria-labelledby="cc-title cc-desc" xmlns="http://www.w3.org/2000/svg">
<title id="cc-title">Invariant control contract across Prototype and Ultimate substrates</title>
<desc id="cc-desc">Shared timing and reference phase lock Boundary Acoustic Lamina (Prototype: collocated RP2350B 1-bit sigma-delta HAPTIC; Ultimate: optically-addressed piezo film on multimode fiber) and Boundary Optical Dendrites (Prototype: 3-pin SMI + SOT-23 1-bit sigma-delta; Ultimate: passive metasurfaces and fiber tomography). Both subtract local C0 and efference predictions before transmitting compact innovation phasors to the swappable Central Complex Brain Slot (RP2350B sparse SRAM now, optional SoC-FPGA, or Optical PCM / neural-gel wave substrates later), feeding ThoracicMotorCompiler and identical standalone or tethered .fcode execution.</desc>
<defs><marker id="cc-arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8" fill="#186b60"/></marker></defs>
<rect x="30" y="16" width="820" height="44" rx="8" fill="#e2ede5" stroke="#186b60" stroke-width="1.5"/>
<g fill="#f2f5ef" stroke="#186b60" stroke-width="1.5">
<a href="acoustics.html" aria-label="Boundary acoustic lamina"><rect x="30" y="82" width="400" height="112" rx="9"/></a>
<a href="optics.html" aria-label="Boundary optical dendrites"><rect x="450" y="82" width="400" height="112" rx="9"/></a>
<a href="#shared-xin-sync-clock-and-the-topographic-spinal-bus" aria-label="Topographic spinal phasor bus"><rect x="110" y="216" width="660" height="50" rx="8"/></a>
<rect x="30" y="288" width="820" height="148" rx="10" fill="#e2ede5"/>
<a href="#central-complex-sparse-complex-hermitian-cadence-and-the-swappable-brain-slot" aria-label="Card 1 Prototype RP2350B SRAM Cadence"><rect x="50" y="324" width="246" height="96" rx="8"/></a>
<a href="#central-complex-sparse-complex-hermitian-cadence-and-the-swappable-brain-slot" aria-label="Card 2 Prototype SoC-FPGA"><rect x="317" y="324" width="246" height="96" rx="8"/></a>
<a href="cadence-memory.html" aria-label="Card 3 Ultimate Optical PCM and Wave Compute"><rect x="584" y="324" width="246" height="96" rx="8"/></a>
<a href="#compiler-wire-contract-machinebackend-fcode-and-ring-0-parity" aria-label="Thoracic motor compiler and wire contract"><rect x="30" y="458" width="400" height="64" rx="9"/></a>
<a href="digital-twin.html" aria-label="Host digital twin and offline training"><rect x="450" y="458" width="400" height="64" rx="9"/></a>
</g>
<g pointer-events="none" fill="#173630" font-family="system-ui,sans-serif" text-anchor="middle">
<text x="440" y="36" font-size="14.5" font-weight="700">COHERENT PHASE REFERENCE (Prototype: XIN + SYNC · Ultimate: Master Optical / RF Carrier)</text>
<text x="440" y="52" font-size="12">6.67 ns cycle alignment · ~0.1° acoustic–optical phase lock across heads and sightlines</text>
<text x="230" y="105" font-size="15" font-weight="600">Boundary Acoustic Lamina</text>
<text x="230" y="126" font-size="12">Prototype: RP2350B 75 MSa/s 1-bit ΣΔ + C₀ ref</text>
<text x="230" y="145" font-size="12">Ultimate: Optically gated piezo film (10⁵ px)</text>
<text x="230" y="164" font-size="12">Subtracts C₀(T) drift &amp; efference ŷ(u, ρ̂)</text>
<text x="230" y="183" font-size="11.5" fill="#186b60">→ Innovation phasors (~30 acoustic / frame)</text>
<text x="650" y="105" font-size="15" font-weight="600">Boundary Optical Dendrites</text>
<text x="650" y="126" font-size="12">Prototype: Metasurface facets + 3-pin SMI + ΣΔ</text>
<text x="650" y="145" font-size="12">Ultimate: Fiber tomography &amp; stem RX</text>
<text x="650" y="164" font-size="12">Zero CMOS pixel bottleneck · zero splitters</text>
<text x="650" y="183" font-size="11.5" fill="#186b60">→ DC matter shadow + AC LightRead phase</text>
<text x="440" y="238" font-size="14.5" font-weight="600">Invariant Innovation Bus (Prototype: 50–150 Mbit/s PIO/HSTX · Ultimate: Fiber / Optical Mode)</text>
<text x="440" y="256" font-size="12">~128–343 complex innovation axons · &lt; 1 kB/stroke · tagged MEASURED</text>
<text x="440" y="311" font-size="14.5" font-weight="700">SWAPPABLE CENTRAL COMPLEX ("BRAIN SLOT") — Complex Hermitian Cadence (W_fb = Wᴴ, ||W||₂ ≤ 1)</text>
<text x="173" y="346" font-size="14" font-weight="600">Card 1 · Prototype MCU</text>
<text x="173" y="366" font-size="12">Bootstrap default (RP2350B)</text>
<text x="173" y="384" font-size="12">5–10% sparse int8 (&lt; 60 kB)</text>
<text x="173" y="402" font-size="12">~8–15 ms settle + local EqProp</text>
<text x="440" y="346" font-size="14" font-weight="600">Card 2 · Prototype FPGA</text>
<text x="440" y="366" font-size="12">Optional Rung 1.5 bootstrap</text>
<text x="440" y="384" font-size="12">Dual-port BRAM (&lt; 5 µs settle)</text>
<text x="440" y="402" font-size="12">Wide comb / SLM interface</text>
<text x="707" y="346" font-size="14" font-weight="600">Card 3 · Ultimate Wave Core</text>
<text x="707" y="366" font-size="12">Optical EML + Sb₂S₃ PCM</text>
<text x="707" y="384" font-size="12">Excitable neural-gel substrates</text>
<text x="707" y="402" font-size="12">Near-zero electricity (Open)</text>
<text x="230" y="484" font-size="14.5" font-weight="600">Thoracic Motor Compiler &amp; MachineBackend</text>
<text x="230" y="504" font-size="12">&lt; 10k LOC bare-metal Ring-0 · .fcode / .pattern / FCD1 wire</text>
<text x="650" y="484" font-size="14.5" font-weight="600">Host Twin &amp; Offline Trainer</text>
<text x="650" y="504" font-size="12">Standalone appliance OR tethered to Swift/Metal + MLX</text>
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

*Status:* **Design decision** and **Derived** analysis anchored on **Published experiments** ([Dosch et al., 1992](https://doi.org/10.1177/1045389X9200300109); [Giuliani et al., 2002](https://doi.org/10.1088/1464-4258/4/6/371); [Bertling et al., 2014](https://doi.org/10.1364/OE.22.030346); [Scellier &amp; Bengio, 2017](https://doi.org/10.3389/fncom.2017.00024)). Prototype electronics (`RP2350B` ganglia and `SMI` strips) are **workshop bootstrap hardware** pending bench coupon validation (`K-HAPTIC-PZT` and `K-MOSQUITO-SMI`).

---

## Three physical timescales, one control contract

No single processor should execute both nanosecond edge synthesis and hour-long finite-element optimization. Splitting control along physical timescales keeps critical actuator timing deterministic and keeps heavy design tools outside the real-time chamber loop:

| Layer | Timescale | Invariant function | Ultimate physical owner | Prototype bootstrap owner (`P0` / `HA-0`) |
|---|---|---|---|---|
| **Boundary lamina** | `6.7–13.3 ns` (`75–150 MHz`) | Synthesize waveforms, demodulate return echoes, subtract dielectric `C₀(T)` and local efference `ŷ(u, ρ̂)` | Continuous optically-addressed piezo films + passive metasurfaces over multimode fiber | Collocated `RP2350B` `PIO` ganglia (`75 MSa/s` `1-bit ΣΔ`) right beside each head and optic strip (`< 2 pF` trace) |
| **Central Complex &amp; motor compiler** | `ps–15 ms` | Settle sparse complex Hermitian `Cadence` (`EqProp`), query associative chords, project through `H(f)` to `.fcode` | Optical `EML`/`Sb₂S₃` cavities or excitable minimal-electricity wave/neural-gel substrates (`Open`) | Swappable Brain Slot: `RP2350B` `< 60 kB` `int8` SRAM (`~8–15 ms`) or optional `SoC-FPGA` BRAM (`< 5 µs`) |
| **Host twin &amp; planner** | `Seconds – Hours` | Co-design geometry (`CAD`, FEM), distill teachers, optimize `NOWS` trajectories, compile `.pattern`/`.fcode` | External workstation / cloud co-design tool for infrequent new part recipes | Workstation (`Swift/Metal` + `MLX/Cadence`), connected via `SerialBackend` / Ethernet—not required at runtime |

---

## Compiler wire contract: MachineBackend, .fcode and Ring-0 parity

A core architectural law from the [engineering twin](digital-twin.html) makes hardware and emulation swappable without rewriting callers: **everything above the boundary speaks the same narrow interface**:

```text
MachineBackend contract:
  describe()               -> MachinePreset / body-response/0.1 (geometry, H(f), limits, channels)
  calibrate()              -> empty-chamber H(f), C₀(T) baseline, sightline offsets
  play(frames: FCodeStream) -> timed complex port drives + live MEASURED boundary residuals
  listen(gates, steps)     -> multi-tone / FM S(f) port response
```

* **Binary `.fcode` / `FCD1` wire verbs:** Every frame carries compact quantized complex port phasors and one physical verb defined identically in Swift (`FCode.swift`), Python (`holo/pattern_codec.py`), and C firmware (`twin/Firmware/p0/`):
  * `ADD` (`code 1`): apply calibrated complex drive array `a`.
  * `REMOVE` (`code 2`): apply phase-conjugate time reversal `conj(a)` for wave-focusing / CPA energy extraction (does not automatically undo chemical bonds; see [Scan, recover and matter stores](matter-loop.html#recover-dissolve-material-specific-separation-and-reuse)).
  * `LISTEN` (`code 3`): execute `10⁻³ × a` (`−60 dB`) non-perturbative diagnostic probe.
* **Body-agnostic decoupling (`body-response/0.1`):** High-level policies and `Cadence` operate on normalized 3D force/wave descriptions; `ThoracicMotorCompiler` maps through the machine's measured `body-response/0.1` transfer operator, allowing the same Brain Slot to drive `borosilicate_12port`, `ha0_boro12`, or `vogel_plates` without retraining ([Cadence and memory](cadence-memory.html#the-cadence-wave-equilibrium-model-eqprop)).
* **Zero-OS Ring-0 parity:** Taking the disciplined simplicity principle from single-address-space operating systems (fixed line ceiling, direct hardware dispatch, no MMU or RTOS scheduler jitter), the embedded executive targets `< 10,000` lines of bare-metal C / open Hazard3 RISC-V and `.pio` assembly. Plugging in an external host computer over USB-C or Ethernet merely streams `.fcode` and `.pattern` packets over the identical local verb parser; unplugging it leaves the Replicator running standalone.

---

## Ultimate boundary control: continuous wave media and near-zero electricity

In the **Ultimate Architecture**, discrete copper bundles, multi-chip microcontroller trees, and static ADCs disappear from the chamber boundary (`Design decision` + `Research hypothesis`):

* **Continuous optically-addressed piezo apertures:** Rather than wiring `~10⁵` copper electrodes across a plate, a continuous thin piezoelectric layer carries four global quadrature electrical rails (`0° / 90° / 180° / 270°`) behind an amorphous-silicon photoconductive film. Projected light from a phase-conjugate multimode fiber gates complex phase and amplitude at every optical spot ([Acoustics](acoustics.html#ultimate-vs-prototype-acoustic-apertures); `Open` composed device).
* **Passive diffractive &amp; interferometric optical boundary:** Metasurface facets and fiber-coupled bidirectional stems perform spatial inner products at the speed of light (`0 W` digital pre-processing) ahead of coherence-locked optical tomography ([Optics](optics.html)).
* **Toward minimal-electricity equilibrium compute:** Replacing clocked transistor SRAM with reciprocal holographic elements (`ε = εᵀ` yielding physical `Wᴴ`), threshold laser-diode cavities (`eml(x, y) = exp(x) − ln(y)`), and longer-term **excitable soft-matter / neural-gel wave substrates (`Research hypothesis` / `Open`)** aims to collapse electronic control energy by allowing physics itself to settle EqProp fixed points directly ([Cadence and memory](cadence-memory.html#compute-substrate-ladder-from-prototype-sram-to-near-zero-electricity-wave-media)).

The sections below detail the **Prototype Electronic Bootstrap (`P0` / `HA-0`)** built today from off-the-shelf silicon to execute that exact contract on the bench with minimal build cost and setup time.

---

## Acoustic lamina: 75 MSa/s 1-bit sigma-delta piezo HAPTIC

*[Prototype electronic implementation — bench coupon `K-HAPTIC-PZT` pending]*

Under linear coupled Butterworth–Van Dyke piezo dynamics ([Acoustics](acoustics.html#simultaneous-two-terminal-haptic-self-sensing); [Dosch, Inman &amp; Garcia, 1992](https://doi.org/10.1177/1045389X9200300109)), terminal current splits cleanly into dielectric charging and crystal velocity:

    m ẍ + c ẋ + k x = Θ V(t) + F_echo(t)
    I(t) = C₀(T) · dV/dt + Θ · ẋ(t)

### Why bare zero-crossing timing fails on multi-tone combs (`Derived`)

An early prototype question asked whether two bare RP2350 pins in `Hi-Z` comparator mode could read echoes with zero external active components. A volts-and-decibels audit shows why multi-tone airborne operation defeats bare zero-crossing timing:

1. **Weak target echo vs. thermal `C₀` drift:** A `2 mm` airborne droplet returns a scattered motional echo `−60 to −80 dB` (`10⁻³–10⁻⁴`) below baseline drive current, whereas `PZT-8` clamped capacitance `C₀(T)` shifts by `~0.3% / °C` (`−50 dB` — `10–30×` larger than the object echo). A `−70 dB` echo perturbs a zero-crossing by less than `0.2 ns`, far below one `6.67 ns` (`150 MHz`) PIO clock tick.
2. **Underdetermined comb inversion:** Two zero-crossings per carrier period cannot separate `5` simultaneous harmonic tones (`10` unknown real I/Q components) because the highest-amplitude tone captures the edge timing.

### The 1-bit sigma-delta solution ("digital Johnston's organ") (`Derived`)

Adding **two resistors and one capacitor** around one fast comparator closes a **`75 MSa/s` `1-bit` continuous-time sigma-delta (`ΣΔ`) negative-feedback loop** across two `RP2350B` PIO pins (`1`-bit feedback out, `1`-bit quantized bit in) comparing the driven patch against the cartridge's uncoupled **`C₀` reference piezo**:

* **Linear dynamic range across all tones:** Over a `150 kHz` ultrasonic band, `75 MSa/s` gives an oversampling ratio `OSR = 75 MHz / (2 × 150 kHz) = 250`, yielding **`12–16` effective bits (`74–96 dB` linear dynamic range)** across all five comb harmonics simultaneously without external multi-MSa/s ADC silicon.
* **Multiplier-free lock-in demodulation:** Demodulating a `1`-bit pulse-density stream against digital cosine/sine reference tables requires zero hardware multiplications—only **bitwise `XOR` + `popcount`** inside the RP2350 cores.
* **PIO budget fits one prototype chip per head:** Each `RP2350B` exposes `48` GPIOs and `3` PIO blocks × `4` state machines (`12` SMs total). Driving all `6` H-bridges synchronously uses **`1` shared 12-pin PIO SM** and reading `6` banked `1-bit ΣΔ` channels uses **`1–2` PIO SMs**—leaving ample state machines for the spinal bus. Placing the `RP2350B` millimeters from the crystal keeps stray capacitance under `2 pF` (versus `C₀ ≈ 171 pF`).
* **Open gate (`K-HAPTIC-PZT`):** Bench verification of multi-tone motional velocity SNR and `C₀(T)` thermal tracking on `1 × RP2350B + tri-state H-bridge + comparator RC ΣΔ + PZT-8 patch + C₀ reference patch`.

---

## Optical mosquito eye: diffractive facets and self-mixing interferometry

*[Prototype &amp; Rung 1 optical readout — bench coupon `K-MOSQUITO-SMI` pending]*

Conventional `60–1,000 fps` CMOS cameras miss `24–200 kHz` ultrasonic oscillations without slow stroboscopic aliasing, and external Mach-Zehnder interferometers or `64–128` discrete photodiode-plus-TIA channels add fragile alignment paths.

Instead, the optical subsystem ([Optics](optics.html#coherent-self-mixing-optical-readout); [The Photons §3](../papers/replicator_photons.html#s3)) pairs passive replicated diffractive metasurface facets ([nanoimprint route](https://doi.org/10.1038/s41596-026-01407-0)) across real `HA-0` CAD sightlines (`270°` clear radial windows + coaxial `Ø12 mm` bore) with **Self-Mixing Interferometry (`SMI`)** inside commodity laser diodes:

* **Dual-band observable without beam splitters:** When laser light crosses the chamber, reflects from an opposing facet or retro-rim, and re-enters the diode cavity, optical feedback mixes inside the active junction (`Published experiment`: [Bertling et al., 2014](https://doi.org/10.1364/OE.22.030346)). Each single diode senses both **DC–kHz Beer–Lambert matter occlusion** and **`24–200 kHz` acousto-optic air-pressure phase** (`Δφ(t) = k_L ((n₀ − 1)/(γ P₀)) ∫ p dx`). Acoustic `HAPTIC` continues seeing inside optically opaque powders where light is blocked.
* **Why air-path SMI needs sub-dollar AC gain (`Derived`):** Unlike direct laser-to-laser optical toroid coupling where milliwatts enter the junction, weak `50 mm` air-path retro-reflection modulates laser terminal voltage by only **`ΔV ≈ 50 µV – 1 mV` per `2π` fringe** ([Giuliani et al., 2002](https://doi.org/10.1088/1464-4258/4/6/371))—roughly **`5–100 µV`** for a `0.1 rad` ultrasonic wave riding on `~2 V` DC. Directly timing that shift on a bare `200 mV`-hysteresis Schmitt GPIO pin moves RC slew by `~0.1 ps` (`67,000×` smaller than one `6.67 ns` PIO tick).
* **Prototype front-end fix:** Reading a commodity 3-pin TO-can laser diode's built-in **monitor photodiode** (or AC-coupling its anode) through **one tiny SOT-23 op-amp (`×200` AC gain) + `1-bit ΣΔ` comparator** into an `RP2350B` PIO preserves zero beam splitters, zero external interferometers, and zero multi-MSa/s ADCs while lifting `0.1 rad` phase signals cleanly into the linear `75 MSa/s` `ΣΔ` quantization range.
* **Open gate (`K-MOSQUITO-SMI`):** Bench measurement of simultaneous `Ø1 mm` bead occlusion (`DC`) and `40 kHz` ultrasonic `LightRead` phase SNR (`AC`) across air without external cameras or splitters.

---

## Shared XIN + SYNC clock and the topographic spinal bus

Independent `±30 ppm` crystal oscillators on separate prototype boards drift by `> 1,000°/s` at `100 kHz`, destroying standing-wave traps between opposed plates. The prototype ganglionic bus prevents clock skew structurally:

1. **One `XIN` oscillator + one `SYNC` downbeat wire:** Every acoustic head ganglion and optical `SMI` strip clocks directly off one fanned-out `12` or `24 MHz` CMOS master oscillator (`XIN`) and triggers on one global `SYNC` line (`wait 1 gpio SYNC`). All acoustic piezo combs and optical `LightRead` lock-in demodulators across the machine remain locked within **`6.67 ns` (`~0.1°` phase alignment)**.
2. **Local lamina efference-copy subtraction:** Each peripheral ganglion subtracts its calibrated `C₀(T)` drift and predicted empty-chamber/self-field response `ŷ(u, ρ̂)` (analogous to neural efference-copy subtraction), transmitting only compact innovation phasors `Δy = y − ŷ` up the spine (`~128–343` complex axons, `< 1 kB` per stroke) over a deterministic `50–150 Mbit/s` PIO/`HSTX` link.

---

## Central Complex: sparse complex Hermitian Cadence and the swappable Brain Slot

To keep software identical across prototype electronics and future optical/physical cores, the Central Complex models wavefields natively as **complex phasor wave-somas** (`z = a exp(iφ) ∈ ℂ`) inside a contractive (`||W||₂ ≤ 1`), tied Hermitian recurrent graph (`W_fb = W_fwdᴴ`) trained via **Equilibrium Propagation (`EqProp`)** ([Scellier &amp; Bengio, 2017](https://doi.org/10.3389/fncom.2017.00024); full theory in [Cadence, memory and wave compute](cadence-memory.html)).

### Why sparsity makes Prototype RP2350B real-time and maps directly to FPGA and optics (`Derived`)

| Brain Slot card | Role &amp; tier | Parameter budget (`192 → 512 → 180` graph) | Settle time / cadence | Local learning &amp; boundary role |
|---|---|---|---|---|
| **Card 1 · Prototype MCU (`RP2350B`)** | Bootstrap Rung 1 default (`520 kB` SRAM, dual `150 MHz` Cortex-M33 / Hazard3) | **`5%–10%` block-sparse, event-driven (`Δz`) `int8` → `&lt; 60 kB`** *(vs. `372 kB` / `~45M` MACs for `30` steps dense ≈ `220–300 ms`)* | **`~8–15 ms` per settle** (faster than chamber `T₆₀`) | Local outer-product `EqProp` thermal drift calibration; identical standalone or tethered `.fcode` stream |
| **Card 2 · Prototype FPGA (`SoC-FPGA`)** | Optional Rung 1.5 prototype upgrade (dual-port BRAM + DSP slices) | Identical `&lt; 60 kB` sparse complex graph | **`&lt; 5 µs` per settle** | Drop-in swap only if sub-50 µs wave-reflexes, `&gt; 80 dB` wide-comb ADCs, or `10⁵`-pixel SLM buses are needed |
| **Card 3 · Ultimate Wave Core (`Optical / PCM / Wave Media`)** | Long-term optical cavity &amp; minimal-electricity target (`Open`) | `4–6` bit analog weights in `Sb₂S₃`/`Sb₂Se₃` (`M#` limited) or continuous wave/neural-gel substrate | **Picosecond–nanosecond** optical propagation (or intrinsic medium settle) | Maxwell/Helmholtz reciprocity (`ε = εᵀ`) supplies `Wᴴ` physically; contrastive interference computes `ΔW` |

---

## Provenance boundary and pre-solder simulation gates

* **Provenance boundary (`MEASURED` vs. `INFERRED`):** Every boundary innovation emitted by the acoustic and `SMI` optical ganglia carries `MEASURED` provenance; every shape recall or interior completion proposed by `Cadence` or `AssociativeChordBank` carries `INFERRED` provenance until physical sensor feedback confirms ring-true alignment ([Matter loop](matter-loop.html#reconstruction-honesty-and-static-validation-g17-g18-g19)).
* **Four pre-solder simulation realism tiers (`holo/`):** Before soldering prototype PCBs or writing PCM transforms, the [digital twin](digital-twin.html#learning-and-control) benchmarks identical `Cadence` connectomes across `ideal_fp32`, `rp2350_ganglia_q8` (simulating `75 MSa/s` `1-bit ΣΔ`, `C₀(T)` thermal drift, and `SMI` shot/fringe noise), `fpga_int8_sparse`, and `optical_pcm_analog` (`4–6` bit precision, `(M#/M)²` crosstalk, finite `Q`), validating coupons `K-HAPTIC-PZT` and `K-MOSQUITO-SMI` prior to hardware release.

Read [Architecture](architecture.html), [Cadence, memory and wave compute](cadence-memory.html), [Acoustics](acoustics.html), [Optics and metamaterials](optics.html), and [Digital twin](digital-twin.html).
