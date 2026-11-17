# Compute, sensing and control

The Replicator separates fast boundary reflexes, medium-rate pattern relaxation, and slow twin training into three physical timescales connected by one deterministic contract. Collocated microcontrollers execute `75 MSa/s` `1-bit` sigma-delta (`ΣΔ`) acoustic and self-mixing optical sensing right at the chamber boundary, leaving heavy simulation, CAD, and training on an external workstation while allowing the machine to run either standalone or tethered over the identical wire protocol.

<div class="diagram">
<svg viewBox="0 0 880 540" role="group" aria-labelledby="cc-title cc-desc" xmlns="http://www.w3.org/2000/svg">
<title id="cc-title">Distributed ganglionic compute, sensing and control architecture</title>
<desc id="cc-desc">One shared CMOS master clock (XIN) and hardware SYNC downbeat wire lock collocated acoustic RP2350B ganglia and optical mosquito-eye SMI ganglia within 0.1 degrees. Each peripheral ganglion runs 75 MSa/s 1-bit sigma-delta feedback and subtracts local C0 drift and efference copies before sending compact complex innovation axons over a deterministic PIO/HSTX spinal bus to a swappable Central Complex Brain Slot (RP2350B sparse SRAM Cadence now, SoC-FPGA BRAM optional, reciprocal Sb2S3 PCM and threshold laser-diode optical core later). Below, the thoracic motor compiler outputs .fcode and .pattern programs identically in standalone Ring-0 mode or tethered to the digital twin.</desc>
<defs><marker id="cc-arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8" fill="#186b60"/></marker></defs>
<rect x="30" y="16" width="820" height="44" rx="8" fill="#e2ede5" stroke="#186b60" stroke-width="1.5"/>
<g fill="#f2f5ef" stroke="#186b60" stroke-width="1.5">
<a href="acoustics.html" aria-label="Acoustic lamina ganglia"><rect x="30" y="82" width="400" height="112" rx="9"/></a>
<a href="optics.html" aria-label="Optical mosquito-eye ganglia"><rect x="450" y="82" width="400" height="112" rx="9"/></a>
<a href="#shared-xin-sync-clock-and-the-topographic-spinal-bus" aria-label="Topographic spinal phasor bus"><rect x="110" y="216" width="660" height="50" rx="8"/></a>
<rect x="30" y="288" width="820" height="148" rx="10" fill="#e2ede5"/>
<a href="#central-complex-sparse-complex-hermitian-cadence-and-the-swappable-brain-slot" aria-label="Card 1 RP2350B SRAM Cadence"><rect x="50" y="324" width="246" height="96" rx="8"/></a>
<a href="#central-complex-sparse-complex-hermitian-cadence-and-the-swappable-brain-slot" aria-label="Card 2 Optional SoC-FPGA"><rect x="317" y="324" width="246" height="96" rx="8"/></a>
<a href="../papers/holographic_memory_and_compute_plan.html" aria-label="Card 3 Optical PCM core"><rect x="584" y="324" width="246" height="96" rx="8"/></a>
<a href="#sovereign-ring-0-appliance-provenance-and-simulation-gates" aria-label="Thoracic motor compiler and Ring-0 appliance"><rect x="30" y="458" width="400" height="64" rx="9"/></a>
<a href="digital-twin.html" aria-label="Digital twin and offline training"><rect x="450" y="458" width="400" height="64" rx="9"/></a>
</g>
<g pointer-events="none" fill="#173630" font-family="system-ui,sans-serif" text-anchor="middle">
<text x="440" y="36" font-size="15" font-weight="700">SHARED MASTER CLOCK (XIN) + HARDWARE SYNC DOWNBEAT</text>
<text x="440" y="52" font-size="12">6.67 ns cycle alignment · ~0.1° acoustic–optical phase lock across heads and sightlines</text>
<text x="230" y="106" font-size="16" font-weight="600">Acoustic Lamina Ganglia (RP2350B / head)</text>
<text x="230" y="128" font-size="12.5">Synchronous 12-pin H-bridge + C₀ ref piezo</text>
<text x="230" y="148" font-size="12.5">75 MSa/s 1-bit ΣΔ (OSR 250) + XOR lock-in</text>
<text x="230" y="168" font-size="12">Subtracts C₀(T) drift &amp; efference ŷ(u, ρ̂)</text>
<text x="230" y="185" font-size="11.5" fill="#186b60">→ 30 complex innovations (6 ports × 5 tones)</text>
<text x="650" y="106" font-size="16" font-weight="600">Optical Mosquito-Eye (RP2350B + SMI)</text>
<text x="650" y="128" font-size="12.5">Passive metasurface facets + 3-pin TO laser diodes</text>
<text x="650" y="148" font-size="12.5">Monitor PD / AC anode → SOT-23 ×200 → 1-bit ΣΔ</text>
<text x="650" y="168" font-size="12">Zero beam splitters · zero external interferometers</text>
<text x="650" y="185" font-size="11.5" fill="#186b60">→ DC matter shadow + AC LightRead wave phase</text>
<text x="440" y="238" font-size="15" font-weight="600">Topographic Spinal Phasor Bus (50–150 Mbit/s PIO / HSTX)</text>
<text x="440" y="256" font-size="12">~128–256 complex innovation axons · &lt; 1 kB/stroke · tagged MEASURED</text>
<text x="440" y="311" font-size="15" font-weight="700">SWAPPABLE CENTRAL COMPLEX ("BRAIN SLOT") — Sparse Complex Hermitian EqProp (W_fb = Wᴴ, ||W||₂ ≤ 1)</text>
<text x="173" y="346" font-size="14.5" font-weight="600">Card 1 · RP2350B SRAM</text>
<text x="173" y="366" font-size="12">Rung 1 default ($2 MCU)</text>
<text x="173" y="384" font-size="12">5–10% sparse int8 (&lt; 60 kB)</text>
<text x="173" y="402" font-size="12">~8–15 ms settle + local EqProp</text>
<text x="440" y="346" font-size="14.5" font-weight="600">Card 2 · SoC-FPGA BRAM</text>
<text x="440" y="366" font-size="12">Optional Rung 1.5 slot</text>
<text x="440" y="384" font-size="12">Dual-port BRAM (&lt; 5 µs settle)</text>
<text x="440" y="402" font-size="12">10⁵-pixel SLM / wide-comb DSP</text>
<text x="707" y="346" font-size="14.5" font-weight="600">Card 3 · Optical / PCM Core</text>
<text x="707" y="366" font-size="12">Rung 2–3 physical compute</text>
<text x="707" y="384" font-size="12">Sb₂S₃ hologram + threshold somas</text>
<text x="707" y="402" font-size="12">Helmholtz Wᴴ + interference ΔW</text>
<text x="230" y="484" font-size="15" font-weight="600">Thoracic Motor Compiler &amp; Ring-0 Port</text>
<text x="230" y="504" font-size="12">&lt; 10k LOC bare-metal C / Hazard3 RISC-V · .fcode / .pattern</text>
<text x="650" y="484" font-size="15" font-weight="600">Host Twin &amp; Curriculum Trainer</text>
<text x="650" y="504" font-size="12">Unplugged standalone OR USB-C / Ethernet tether to twin</text>
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

*Architecture status:* **Design decision** and **Derived** analysis anchored on **Published experiments** ([Dosch et al., 1992](https://doi.org/10.1177/1045389X9200300109); [Giuliani et al., 2002](https://doi.org/10.1088/1464-4258/4/6/371); [Bertling et al., 2014](https://doi.org/10.1364/OE.22.030346); [Scellier &amp; Bengio, 2017](https://doi.org/10.3389/fncom.2017.00024)). Front-end and brain tiers have not yet passed bench hardware acceptance (`K-HAPTIC-PZT` and `K-MOSQUITO-SMI` pending).

---

## Three physical timescales, one control contract

No single processor should run both nanosecond pin timing and hour-long finite-element co-design. Splitting control by physical timescale keeps real-time pins jitter-free and keeps heavy host compute off the critical loop:

| Layer | Timescale | Role in the Replicator | Hardware owner | Why alternatives fail here |
|---|---|---|---|---|
| **Boundary lamina** | `6.7–13.3 ns` (`75–150 MHz`) | Synthesize multi-tone H-bridge combs, run `75 MSa/s` `1-bit ΣΔ` modulation, subtract `C₀(T)` and local efference predictions | Collocated `RP2350B` PIO ganglia on each head and optical strip | Linux SBCs (`50 µs–1 ms` OS jitter) and USB links break cycle-accurate phase coherence; long analog piezo cables add `30–60 pF` stray capacitance |
| **Central Complex &amp; motor sequencer** | `5 µs – 15 ms` | Relax sparse complex Hermitian `Cadence` (`EqProp`), update associative chord memory, emit body-agnostic `.fcode` motor synergies | Swappable Brain Slot: `RP2350B` SRAM default (`~8–15 ms`), `SoC-FPGA` BRAM (`&lt; 5 µs`), or optical PCM core later | Uncompressed dense neural layers (`~220–300 ms` on MCU) lag chamber thermal drift; placing a GPU inside the appliance adds cost and heat |
| **Host twin &amp; curriculum trainer** | `Seconds – Hours` | Run Swift/Metal field solvers, solid-mechanics co-design, CAD exports, and 24/7 `Cadence` curriculum training | External workstation (e.g., Apple Silicon GPU / MLX) | Coupling training or FEM into the live control loop wastes energy and violates deterministic safety limits |

---

## Acoustic lamina: 75 MSa/s 1-bit sigma-delta piezo HAPTIC

Under linear coupled Butterworth–Van Dyke piezo dynamics ([acoustics](acoustics.html#simultaneous-two-terminal-haptic-self-sensing); [Dosch, Inman &amp; Garcia, 1992](https://doi.org/10.1177/1045389X9200300109)), terminal current splits cleanly into dielectric charging and crystal velocity:

    m ẍ + c ẋ + k x = Θ V(t) + F_echo(t)
    I(t) = C₀(T) · dV/dt + Θ · ẋ(t)

### Why bare zero-crossing timing fails on multi-tone combs (`Derived`)

Measuring across a real multi-tone harmonic comb (`24–200 kHz`) exposes two dynamic-range walls that defeat a naive zero-crossing comparator:

1. **Weak target echo vs. thermal `C₀` drift:** A `2 mm` airborne droplet returns a scattered motional echo `−60 to −80 dB` (`10⁻³–10⁻⁴`) below baseline drive current, whereas `PZT-8` clamped capacitance `C₀(T)` shifts by `~0.3% / °C` (`−50 dB` — `10–30×` larger than the object echo). A `-70 dB` echo perturbs a zero-crossing by less than `0.2 ns`, far below one `6.67 ns` (`150 MHz`) PIO clock tick.
2. **Underdetermined comb inversion:** Two zero-crossings per carrier period cannot separate `5` simultaneous harmonic tones (`10` unknown real I/Q components) because the highest-amplitude tone captures the edge timing.

### The 1-bit sigma-delta solution ("digital Johnston's organ") (`Derived`)

Adding **two resistors and one capacitor** around a fast comparator closes a **`75 MSa/s` `1-bit` continuous-time sigma-delta (`ΣΔ`) negative-feedback loop** across two RP2350 PIO pins (`1`-bit feedback out, `1`-bit quantized bit in) comparing the driven patch against the cartridge's uncoupled **`C₀` reference piezo**:

* **Linear dynamic range across all tones:** Over a `150 kHz` ultrasonic band, `75 MSa/s` gives an oversampling ratio `OSR = 75 MHz / (2 × 150 kHz) = 250`, yielding **`12–16` effective bits (`74–96 dB` SNR)** across all five comb harmonics simultaneously without external multi-MSa/s ADC silicon.
* **Multiplier-free lock-in demodulation:** Demodulating a `1`-bit pulse-density stream against digital cosine/sine reference tables requires zero hardware multiplications—only **bitwise `XOR` + `popcount`** inside the RP2350 cores.
* **PIO budget fits one chip per head:** Each `RP2350B` exposes `48` GPIOs and `3` PIO blocks × `4` state machines (`12` SMs total). Driving all `6` H-bridges synchronously uses **`1` shared 12-pin PIO SM** and reading `6` banked `1-bit ΣΔ` channels uses **`1–2` PIO SMs**—leaving ample state-machine headroom for the spinal bus without exhausting PIO blocks. Placing the `RP2350B` millimeters from the crystal keeps stray capacitance under `2 pF` (versus `C₀ ≈ 171 pF`).
* **Open gate (`K-HAPTIC-PZT`):** Bench verification of multi-tone motional velocity SNR and `C₀(T)` thermal tracking on `1 × RP2350B + tri-state H-bridge + comparator RC ΣΔ + PZT-8 patch + C₀ reference patch`.

---

## Optical mosquito eye: diffractive facets and self-mixing interferometry

Standard `60–1,000 fps` CMOS cameras cannot track `24–200 kHz` ultrasonic fields without slow stroboscopic aliasing, and external Mach-Zehnder interferometers or `64–128` discrete photodiode-plus-TIA channels add fragile alignment paths.

Instead, the optical subsystem ([optics](optics.html#coherent-self-mixing-optical-readout); [The Photons §3](../papers/replicator_photons.html#s3)) pairs passive replicated diffractive metasurface facets ([nanoimprint route](https://doi.org/10.1038/s41596-026-01407-0)) across the chamber's radial windows and coaxial `Ø12 mm` bore with **Self-Mixing Interferometry (`SMI`)** inside commodity laser diodes:

* **Dual-band observable without beam splitters:** When laser light crosses the chamber, reflects from an opposing facet or retro-rim, and re-enters the diode cavity, optical feedback mixes directly inside the active junction (`Published experiment`: [Bertling et al., 2014](https://doi.org/10.1364/OE.22.030346)). One diode senses both **DC–kHz Beer-Lambert matter occlusion** and **`24–200 kHz` acousto-optic air-pressure phase** (`Δφ(t) = k_L ((n₀ − 1)/(γ P₀)) ∫ p dx`). Acoustic `HAPTIC` continues seeing inside optically opaque powders where light is blocked.
* **Why air-path SMI needs `$0.20` of AC gain (`Derived`):** Unlike a direct laser-to-laser optical toroid where milliwatts couple between chips, weak/moderate `50 mm` air-path retro-reflection modulates laser terminal voltage by only **`ΔV ≈ 50 µV – 1 mV` per `2π` fringe** ([Giuliani et al., 2002](https://doi.org/10.1088/1464-4258/4/6/371))—roughly **`5–100 µV`** for a `0.1 rad` ultrasonic wave riding on `~2 V` DC. Directly timing that shift on a bare `200 mV`-hysteresis Schmitt GPIO pin moves RC slew by `~0.1 ps` (`67,000×` smaller than one `6.67 ns` PIO tick).
* **The practical front-end:** Reading the standard 3-pin `$0.50` TO-can laser diode's built-in **monitor photodiode** (or AC-coupling its anode) through **one SOT-23 op-amp (`×200` AC gain) + `1-bit ΣΔ` comparator** into an `RP2350B` PIO preserves zero splitters, zero external interferometers, and zero multi-MSa/s ADCs while lifting `0.1 rad` phase signals comfortably into the linear `75 MSa/s` `ΣΔ` quantization range.
* **Open gate (`K-MOSQUITO-SMI`):** Bench measurement of simultaneous `Ø1 mm` bead occlusion (`DC`) and `40 kHz` ultrasonic `LightRead` phase SNR (`AC`) across air without external photodiodes or cameras.

---

## Shared XIN + SYNC clock and the topographic spinal bus

Independent `±30 ppm` crystal oscillators on separate microcontrollers drift by `> 1,000°/s` at `100 kHz`, destroying standing-wave traps between opposed plates. The ganglionic bus prevents clock skew structurally:

1. **One `XIN` oscillator + one `SYNC` downbeat wire:** Every acoustic head ganglion and optical `SMI` strip clocks directly off one fanned-out `12` or `24 MHz` CMOS master oscillator (`XIN`) and triggers on one global `SYNC` line (`wait 1 gpio SYNC`). All acoustic piezo combs and optical `LightRead` lock-in demodulators across the machine remain locked within **`6.67 ns` (`~0.1°` phase alignment)**.
2. **Local lamina efference-copy subtraction:** Each peripheral ganglion subtracts its calibrated `C₀(T)` drift and predicted empty-chamber/self-field response `ŷ(u, ρ̂)`, transmitting only compact innovation phasors `Δy = y − ŷ` up the spine (`~128–256` complex axons, `< 1 kB` per stroke) over a deterministic `50–150 Mbit/s` PIO/`HSTX` link.

---

## Central Complex: sparse complex Hermitian Cadence and the swappable Brain Slot

To bridge smoothly from microcontroller hardware to future optical processors, the Central Complex models wavefields natively as **complex phasor wave-somas** (`z = a exp(iφ) ∈ ℂ`) inside a contractive (`||W||₂ ≤ 1`), tied Hermitian recurrent graph (`W_fb = W_fwdᴴ`) trained via **Equilibrium Propagation (`EqProp`)** ([Scellier &amp; Bengio, 2017](https://doi.org/10.3389/fncom.2017.00024)).

### Why sparsity makes RP2350B real-time and maps directly to FPGA and optics (`Derived`)

| Brain Slot card | Substrate | Parameter budget (`192 → 512 → 180` graph) | Settle time / cadence | Local learning &amp; role |
|---|---|---|---|---|
| **Card 1 (Rung 1 default)** | Coordinator `RP2350B` (`520 kB` SRAM, dual `150 MHz` Cortex-M33 / Hazard3) | **`5%–10%` block-sparse, event-driven (`Δz`) `int8` → `&lt; 60 kB`** *(vs. `372 kB` / `~45M` MACs for `30` steps dense ≈ `220–300 ms`)* | **`~8–15 ms` per settle** (faster than chamber `T₆₀`) | Local outer-product `EqProp` thermal drift calibration; standalone or USB-C tethered |
| **Card 2 (Optional Rung 1.5)** | `SoC-FPGA` dual-port BRAM + DSP slices | Identical `&lt; 60 kB` sparse complex graph | **`&lt; 5 µs` per settle** | Drop-in swap only if sub-50 µs wave-reflexes, `&gt; 80 dB` wide-comb ADCs, or `10⁵`-pixel Rung 2 SLM buses are needed |
| **Card 3 (Rung 2–3 optical core)** | Reciprocal `Sb₂S₃`/`Sb₂Se₃` phase-change holograms + threshold laser-diode `O-E-O`/`EML` somas | `4–6` bit analog weights stored in `~λ³` refractive modulation (`M#` limited) | **Picosecond–nanosecond** optical propagation; gain restored per layer at diode threshold | Maxwell/Helmholtz reciprocity (`ε = εᵀ`) executes `Wᴴ` physically; contrastive 2-beam interference computes `ΔW ∝ Re(E⁺ E⁺* − E⁻ E⁻*)` (`Open` PCM bench gates) |

---

## Sovereign Ring-0 appliance, provenance and simulation gates

* **Zero-OS standalone or tethered execution:** Inspired by single-address-space system design (minimal complexity cap, live function dispatch, unified documents; [memory and compute plan](../papers/holographic_memory_and_compute_plan.html#s4-2)), the entire embedded controller runtime targets `< 10,000` lines of bare-metal C / open Hazard3 RISC-V and `.pio` assembly with zero Linux scheduler or MMU jitter. Over USB-C or Ethernet, an external computer speaks the exact same `.fcode` / `.pattern` verb stream (`ADD`, `REMOVE`, `LISTEN`, `CALIBRATE`) that the coordinator runs locally when unplugged.
* **Provenance boundary (`MEASURED` vs. `INFERRED`):** Every boundary innovation emitted by the acoustic and `SMI` optical ganglia carries `MEASURED` provenance; every shape recall or completion proposed by `Cadence` or an associative optical store carries `INFERRED` provenance until physical sensor feedback confirms ring-true alignment.
* **Four pre-hardware simulation realism tiers:** Before soldering hardware or writing PCM transforms, the digital twin ([digital twin](digital-twin.html#learning-and-control)) benchmarks identical connectomes across `ideal_fp32`, `rp2350_ganglia_q8` (including `75 MSa/s` `1-bit ΣΔ`, `C₀(T)` drift, and `SMI` shot/fringe noise), `fpga_int8_sparse`, and `optical_pcm_analog` (`4–6` bit precision, `(M#/M)²` crosstalk, finite `Q`), alongside co-optimized diffractive phase masks `φ_opt(x, y)` over true Beer-Lambert CAD sightlines.

Read [Architecture](architecture.html), [Acoustics](acoustics.html), [Optics and metamaterials](optics.html), [Digital twin](digital-twin.html), and [Holographic Memory and Compute](../papers/holographic_memory_and_compute_plan.html).
