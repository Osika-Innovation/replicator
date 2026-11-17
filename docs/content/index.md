---
# ignored: catalog owns metadata
---
<div class="eyebrow">ETHERWORKS / ENGINEERING HANDBOOK</div>

# Build the machine that builds the next.

<div class="lead">One enduring modular platform. Geometry and wavefields that replace mechanical parts. A digital twin that turns each bench measurement into the next self-made upgrade.</div>

The Replicator programme develops field-controlled manufacturing: feed material, arrange it in mid-air or fluid, consolidate it cleanly, inspect the result, and recover reusable stock. Its long-term target is an **Ultimate Architecture** built around continuous wave-addressed boundaries, holographic chord memory, and minimal-electricity physical wave compute. Its immediate engineering path is an explicit **Bootstrap Prototype (`P0` / `HA-0`)** assembled from purchasable seed electronics and machined/printed bodies to manufacture its own upgrades with minimum human time.

**This handbook is the canonical, self-contained technical reference for the project.** Earlier standalone HTML essays in the [paper library](guides/research.html) remain preserved for mechanism lineage and historical specifications; current architectures, equations, and prototype-vs-ultimate boundaries live here.

<div class="cards">
<a class="card" href="guides/architecture.html"><span class="eyebrow">01 / SYSTEM</span><h2>Architecture: Ultimate vs. Prototype</h2><p>Coordinated acoustic, EM, and optical fields, two-carrier physics, and the side-by-side comparison table.</p></a>
<a class="card" href="guides/cadence-memory.html"><span class="eyebrow">02 / INTELLIGENCE</span><h2>Cadence, memory and wave compute</h2><p>Three-cavity theorem, holographic chord stores, complex Hermitian EqProp, and low-energy wave substrates.</p></a>
<a class="card" href="guides/compute-control.html"><span class="eyebrow">03 / CONTROL</span><h2>Compute, sensing and control</h2><p>Timescale split, .fcode contracts, Ultimate optical boundaries, and Prototype RP2350B 1-bit sigma-delta / SMI boards.</p></a>
<a class="card" href="guides/matter-loop.html"><span class="eyebrow">04 / MATTER LOOP</span><h2>Scan, recover and stores</h2><p>Zero-moving-part S(f) tomography, material recovery hierarchy, and Salt/Ash/Noble-Gas stores.</p></a>
</div>

## Choose a route

| You want to… | Start here | Then read |
|---|---|---|
| Understand the project and Ultimate vs. Prototype split | [Start here](guides/start.html) | [Architecture](guides/architecture.html) |
| Design a physical subsystem | [Architecture](guides/architecture.html) | [Acoustics](guides/acoustics.html), [Electromagnetics](guides/electromagnetics.html), [Optics and metamaterials](guides/optics.html) |
| Understand wave compute, electronics and `Cadence` | [Compute, sensing and control](guides/compute-control.html) | [Cadence, memory and wave compute](guides/cadence-memory.html), [Digital twin](guides/digital-twin.html) |
| Build, scan, recover or store feedstock | [Manufacturing](guides/manufacturing.html) | [Scan, recover and matter stores](guides/matter-loop.html), [Upgrade loop](guides/upgrades.html) |
| Explore OPH, light, spectra and crystal physics | [Physics overview](guides/physics.html) | [Observer Patch Holography](guides/oph.html), [Periodic table and tones](guides/periodic-table.html), [From atoms to hardware](guides/physics-to-hardware.html) |
| Work as an AI agent or verify evidence | [Agent entry point](guides/agents.html) | [Current state](guides/status.html), [Research library](guides/research.html) |

## The operating principle

Use computation and passive geometry to delete moving parts, calibration toil, and excess wiring. Keep the enduring platform's datums, coordinates, and `.fcode`/`.pattern` wire contracts fixed while advancing cleanly from purchasable prototype seed electronics (`RP2350B` ganglia, discrete `SMI` laser strips, workstation trainers) toward integrated optical cavities and minimal-electricity physical wave substrates.

## Where the work stands

The repository contains executable Swift/Metal twin geometry and field solvers (`twin/`), parametric CAD and benchtop upgrade exports, and MLX/Metal `Cadence` simulations (`holo/`). Immediate physical gates validate coupled dispersive piezo bodies (`K-PORT+`), `75 MSa/s` `1-bit ΣΔ` multi-tone piezo sensing (`K-HAPTIC-PZT`), and AC-coupled self-mixing optical readout (`K-MOSQUITO-SMI`).

The [current-state page](guides/status.html) distinguishes Ultimate targets, active prototype designs, and bench evidence. The [research library](guides/research.html) indexes primary sources and archived papers.
