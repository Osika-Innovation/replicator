# Agent entry point

Work toward one enduring modular machine that increasingly manufactures its own upgrades with minimum human engineering time. Keep two horizons clear in every document, simulation, and design: the **Ultimate Architecture** (tool-free coordinated wavefields, continuous optical/wave apertures, and minimal-electricity physical equilibrium compute) and the **Bootstrap Prototype (`P0` / `HA-0`)** (purchasable `RP2350B`, `SMI`, and `PZT`/SLA seed modules). **Never conflate temporary prototype scaffolding silicon with the final architecture of the Replicator.**

This **Engineering Handbook (`docs/content/*.md`) is the canonical, self-contained technical specification**, superseding older standalone HTML essays in `papers/`.

## Read in this order

1. [Current state](status.html): Ultimate vs. Prototype tracks, published code, and open bench gates.
2. [Architecture](architecture.html): Two-carrier physics (`λ`, momentum, crossings) and Ultimate vs. Prototype system boundaries.
3. [Compute, sensing and control](compute-control.html): Invariant `.fcode` / `MachineBackend` contract, Ultimate continuous wave boundaries, and Prototype `RP2350B` `1-bit ΣΔ` / `SMI` hardware.
4. [Cadence, memory and wave compute](cadence-memory.html): `8πV / 3λ³` three-cavity theorem, `Sb₂S₃` chord memory, complex Hermitian `EqProp`, and the compute substrate ladder.
5. [Manufacturing](manufacturing.html) and [Scan, recover and matter stores](matter-loop.html): `Slice → Feed → Trap → Move → Weld → Check`, non-moving `S(f)` tomography (`G17–G19`), material recovery, and Salt/Ash/Noble-Gas stores.
6. [Upgrade loop](upgrades.html) and [Digital twin](digital-twin.html): `upgrade_graph.json`, Charter/solver gates, and pre-solder simulation realism tiers.
7. The specific physics/subsystem guide ([Acoustics](acoustics.html), [Optics](optics.html), [Electromagnetics](electromagnetics.html), [Physics overview](physics.html), [Research library](research.html)).

For foundational physics and atomic-to-hardware work, read [Observer Patch Holography](oph.html), [Light, fields and matter](light-matter.html), [Periodic table and tones](periodic-table.html), and [From atoms to hardware](physics-to-hardware.html). Verify the small shell/geometry suite with `python3 tools/check_physics_derivations.py`.

Use [catalog.json](../catalog.json) for stable document IDs, [llms.txt](../llms.txt) as the compact agent map, and [llms-full.txt](../llms-full.txt) for complete plaintext ingestion.

## Ownership

| Lane | Owns | Delivers |
|---|---|---|
| **System integration** | Architecture, Ultimate vs. Prototype framing, cross-field contracts | Compatible modules, invariant `.fcode`/`.pattern` schemas, complete manufacturing loop |
| **Acoustics** | Coupled piezo/plate/scatterer/radiation co-design, harmonic comb closure | `body-response/0.1` `H(f)`, `K-PORT+` solid FEM agreement, thermal/force limits |
| **Platform / control** | Timescale split, `MachineBackend`, Ring-0 firmware, prototype `RP2350B` `1-bit ΣΔ` &amp; `XIN`/`SYNC` bus, Brain Slot | Bounded executable jobs, standalone/tethered parity, `K-HAPTIC-PZT` bench receipts |
| **Intelligence / Cadence** | Sparse complex Hermitian `EqProp`, `AssociativeChordBank`, `ThoracicMotorCompiler`, multi-teacher distillation | Validated `holo/` benchmarks across `ideal_fp32`, `rp2350_ganglia_q8`, `fpga_int8_sparse`, `optical_pcm_analog` |
| **Optics / metamaterials** | Metasurface facets, toroidal stem, `SMI` mosquito-eye readout, nanoimprint replication, optical tweezers | Sightline-true `K-MOSQUITO-SMI` receipts, phase tolerances (`δh`), PCM `M#` &amp; endurance specs |
| **Electromagnetic control** | Coils, transient/RF fields, `J × B` melt shaping, `m/q` sort, contactless `X-EM` exciter | Calibrated field/force maps, current/thermal limits, `X-EM` disc modal response |
| **Feed, join &amp; stores** | `Assemble`, `Recover`, consolidation state machine (`R15`), Salt/Ash/Noble-Gas stores, active `R9` chamber | Qualified process recipes, mass/energy balance ledger, `FAB-01` first upgrade part |
| **Metrology &amp; Scan** | Non-moving `S(f)` (`G17`–`G19`), `measured` vs. `inferred` tagging, calibration phantoms | Reproducible raw sensor captures, uncertainty bounds, phantom ground-truth checks |
| **Physics / documentation** | OPH &amp; material-tone links, canonical Markdown handbook maintenance | Clear current explanations preserving epistemic status and public-scope firewall |

## Working rules

Inspect git status and active branches before editing. Use isolated branches for concurrent work. Never touch running experiment logs or overwrite uncommitted local hardware edits without explicit check.

Every engineering change declares its input revision, target observable, baseline comparison, and discriminating gate. Keep simulation predictions (`SIMULATED`), analytical calculations (`DERIVED`), external literature (`Published`), and project hardware receipts (`Bench measured`) strictly separate. Do not approve parts ordering or push public deployments without operator authorization.

## Documentation changes

Lead cleanly with both **Ultimate Architecture** and **Prototype Bootstrap** context whenever describing hardware or compute. Update the owning guide, [Status](status.html), [catalog.json](../catalog.json), and cross-links together so the handbook remains self-contained without relying on legacy HTML papers. Never introduce private intake attachments, local filesystem paths, sibling private studies, or unverified internal codenames into public builds. Always run `python3 tools/build_docs.py` and `python3 tools/check_docs.py` before committing.
