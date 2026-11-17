# The upgrade loop

Design the seed machine and the path to its own successors together. The objective is to minimize total human engineering and experiment minutes by uniting two searches: working **forward** from what an affordable **Bootstrap Prototype (`P0` / `HA-0`)** can assemble today, and working **backward** from the **Ultimate Architecture**'s tool-free physical limits.

## One enduring platform

Keep mechanical datums, optical sightlines, coordinate conventions, `.fcode`/`.pattern` wire contracts, and `MachineBackend` stable across hardware generations. Replace or upgrade only the bottleneck module—turning disposable test jigs (`K-PORT+`, `K-HAPTIC-PZT`, `K-MOSQUITO-SMI`, `X-EM`) into reusable platform service tools.

Purchased transducers, prototype microcontrollers (`RP2350B`), `3`-pin laser diodes, outsourced optics masters, and machined blanks are valid seed inputs whenever buying or outsourcing saves more human time than building an intermediate machine tool in-house.

---

## Two-ended dependency graph (`upgrade_graph.json`)

Checked in code via `fieldc upgrades` (strictly acyclic—no upgrade may depend on the very precision it claims to create unless an explicit external seed step bridges the gap):

| Edge / Generation | Bottleneck removed | Bootstrap / process route &amp; metrology | Next unlocked capability |
|---|---|---|---|
| **Seed (`P0` / `HA-0` coupons)** | Unmeasured piezo coupling, thermal drift, and air-path `SMI` SNR | Bought `PZT` / `RP2350B` `1-bit ΣΔ` bridge (`K-HAPTIC-PZT`), `3`-pin `SMI` strip (`K-MOSQUITO-SMI`), `X-EM` + `Ø120` Al blank (`K-PORT+`) | Closed-loop hold/move/release and verified `body-response/0.1` model |
| **`FAB-01` (First self-made part)** | Open-loop calibration drift / manual alignment | Fix and inspect an origin fiducial, SLA modulo-`2π` phase ring (`ha0_sla_phase_ring`), or bayonet insert (`ha0_bayonet_ring`); external UV/cure finish recorded explicitly | Measurable trap contrast / alignment gain verified before/after on identical task (`G-M1` / `K-HMR`) |
| **`META-01` (Optical &amp; acoustic ladder)** | Limited spatial rank, manual optical fixturing, discrete electrical wiring | Externally lithographed master → soft-mold nanoimprinted `TiO₂` diffractive facets (`R013`) paired with `δh = λ δφ / (2π |n − 1|)` interferometry | Higher-rank `SMI` vision, shaped acoustic-optical apertures |
| **Ultimate physical convergence** | Electronic clock power, manual feed, open reclaim loop | Continuous optically-addressed `PMN-PT`/photoconductor plates over multimode fiber (`Rung 2`), mirrored `R9` sort/reclaim chamber, `EML`/`Sb₂S₃` or `Open` minimal-electricity wave/neural-gel compute | Autonomous Scan → Assemble → Recover self-upgrading manufacturing loop ([Matter loop](matter-loop.html); [Cadence and memory](cadence-memory.html)) |

---

## A complete upgrade record

Every candidate upgrade passes review only when it specifies:

1. **The limiting capability** and quantified task bottleneck removed.
2. **Exact geometry, materials, and compatibility interfaces** on the enduring platform.
3. **Required fabrication tolerances and independent metrology** (converting functional budgets like `~17 nm` optical phase height error at `532 nm` cleanly rather than trusting printer nominal voxel specs).
4. **All external seed parts and finishing steps** (tracked separately from self-made mass fraction so a single purchased laser or driver stays visible as an external dependency).
5. **Estimated human setup hours, machine time, yield risk, and rollback handle.**
6. **Before/after measured acceptance test** proving net improvement on the same task before retiring the previous module.

Self-copying and self-improvement are distinct milestones: autonomous design search ([Digital twin](digital-twin.html)), multi-carrier manufacturing ([Manufacturing](manufacturing.html)), and closed recovery ([Scan, recover and matter stores](matter-loop.html)) close the loop together.

Read [Start here](start.html), [Manufacturing](manufacturing.html), [Scan, recover and matter stores](matter-loop.html), and [From atoms to hardware](physics-to-hardware.html).
