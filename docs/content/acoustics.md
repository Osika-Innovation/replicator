# Acoustic bodies

Use dispersive geometry plus electrical timing headroom to obtain full 3D acoustic control with few electrical channels. The leading candidate is two opposed thin broadband piezoelectric plates (`3 + 3` asymmetric inputs, `≤ 5 mm` patches or annuli bonded to a `1–1.5 mm` low-loss supersonic glass or aluminum plate and/or a replaceable thin-walled SLA chaotic "pinecone" scatterer around a coaxial `Ø12 mm` optical/material bore) governed by continuous two-terminal self-sensing.

## First-principles crystal inertia vs. cavity Q

Physical piezoelectric switching is bounded by longitudinal acoustic transit across the crystal thickness (`τ_inertia = L / v_D`), not by room-air cavity decay (`T_60 ≈ 20–50 ms`). For a `1 mm` thin plate, `τ_inertia` spans `~91 ns` (`AlN/ScAlN`), `~136–174 ns` (`LiNbO3` / quartz), `~217–245 ns` (`PMN-PT` / `PZT`), and `~255–285 ns` (`1–3` piezocomposite). Air `T_60` sets passive chamber energy storage (`Q_cav`) rather than an actuator frame clock.

Avoid bolt-clamped `Q ≈ 500` steel Langevin dumbbells as the multi-tone holographic default (`~4.5 ms` narrowband ring-down); retain preloaded Langevin stacks only as historical or single-tone CW power comparison hardware.

## Simultaneous two-terminal HAPTIC self-sensing

Drive and sense continuously across both terminals of every piezoelectric element through a differential H-bridge (`+V_bus` expand, `-V_bus` contract, `0 V` brake, `Hi-Z` float) with `10–50×` electrical timing and sample-rate headroom. From coupled Butterworth–Van Dyke dynamics:

- `m ẍ + c ẋ + k x = Θ V(t) + F_echo(t)`
- `I(t) = C_0 dV/dt + Θ ẋ(t)`

Subtracting the dielectric slewing current `C_0 dV/dt` against a matched `C_ref` capacitor (such as the cartridge's uncoupled `C_0` reference piezo) recovers strain `x(t)`, crystal velocity `ẋ(t)`, and returning chamber echo loading `F_echo(t)` simultaneously during drive with zero blind TX/RX switching gap.

On a multi-tone harmonic comb (`24–200 kHz`), a `2 mm` airborne droplet echo lies `−60 to −80 dB` below baseline drive while `PZT-8` `C_0(T)` drifts `~0.3% / °C` (`−50 dB`), which captures a bare zero-crossing comparator (`< 0.2 ns` crossing shift; two crossings per period cannot invert ten I/Q comb unknowns). Closing a **`75 MSa/s` `1-bit` sigma-delta (`ΣΔ`) feedback loop** (`1` comparator + `2` resistors + `1` capacitor across two `RP2350B` PIO pins, `OSR = 250` over `150 kHz` → `12–16` ENOB / `74–96 dB` dynamic range) with multiplier-free bitwise `XOR` + `popcount` lock-in demodulates all comb lines simultaneously; collocating one `RP2350B` ganglion per 6-port head keeps trace capacitance below `2 pF` (`1` synchronous 12-pin drive SM + `1–2` banked `ΣΔ` SMs out of `12`, clock-locked via shared `XIN`/`SYNC`; [Compute, sensing and control](compute-control.html#acoustic-lamina-75-msas-1-bit-sigma-delta-piezo-haptic)). Bench coupon `K-HAPTIC-PZT` remains open.

## Coupled-cavity equilibrium and sparse chords

Design variables include actuator layout, supersonic plate dispersion, replaceable SLA chaotic scatterers, gap, harmonic comb spacing (`f_0 ≈ 25 kHz`), and closed-loop gain. Folded paths, asymmetric patches, and perforated thin shells trade electrical bandwidth headroom for thousands of spatial degrees of freedom in one SIMO body.

Stationary holding does zero mechanical work (`F · ż = 0`). High air–solid impedance mismatch (`415 Rayl` vs. `46 MRayl`, `99.996%` reflection) means dense inclusions (such as steel at `7.85 g/cm³`) resonate in coupled chamber-plus-object air modes rather than internal solid modes. Once `ẋ(t)` locks onto the target harmonic chord, continuous feedback settles near passive chamber loss (`P_hold = ω E_stored / Q_cav`). Objects are therefore represented as compact sparse `.pattern` chord lists (kilobytes to sub-megabyte in Rung 1) rather than raw voxel-video frames; extending single-axis standing-wave dense-metal levitation to closed-loop 3D dispersive holding remains open.

## Response as the handover

For a linear operating regime, write the field as **p(f) = H(f)u(f)**. The response connects the input drives to the observable field or radiating surface. It belongs to a specific geometry, mounting, medium and operating state.

The engineering body-response contract separates physical input channels from sampled radiating patches. A thousand patches do not become a thousand independent controls without multi-tone dispersion across the calibrated `H(f)` response and amplifier headroom.

## Compute and measurement

Use reduced models (and optional physics-constrained neural warm-starts evaluated against `NOWS`) for broad search and independent structural/acoustic models for finalists. When models disagree, identify the missing coupling or measurement before expanding the sweep.

The reusable calibration fixture measures electrical impedance, adaptive `C_0` bridge balance, mounting repeatability, and spatial pressure response. Feed those observations back into the digital twin with uncertainty.

## First useful output

The first manipulation gate is repeatable hold, move and release under simultaneous two-terminal `HAPTIC` closed-loop regulation. The manufacturing gate additionally requires controlled feed, joining and inspection. A replaceable field-shaping faceplate, fixture or feed component becomes an upgrade only when its measured effect improves the machine.

See [Compute, sensing and control](compute-control.html), [The Acoustic Hologram](../papers/replicator_acoustic_hologram.html), [The Phonons](../papers/replicator_phonons.html), [Manufacturing](manufacturing.html), [Materials](materials.html) and the full acoustic library in [research](research.html).
