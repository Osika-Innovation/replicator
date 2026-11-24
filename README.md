# Etherworks · Replicator

**One modular machine that gains the ability to manufacture its own upgrades.**

We develop field-controlled manufacturing through acoustic, electromagnetic, and optical wave research, twin-native CAD, wave-equilibrium modeling, and reusable physical measurements. The **Engineering Handbook (`docs/`)** is the self-contained canonical technical reference tracking both the **Ultimate Architecture** and the **Bootstrap Prototype (`P0` / `HA-0`)**, superseding standalone legacy `papers/`.

**[Read the Replicator Handbook →](https://osika-innovation.github.io/replicator/)**

| Start with | What it answers |
|---|---|
| [Start here](docs/content/start.md) | Purpose, Ultimate Architecture vs. Bootstrap Prototype, and reading route |
| [Architecture](docs/content/architecture.md) | Subsystems, two-carrier physics, volume crossings, and Ultimate vs. Prototype map |
| [Compute, sensing and control](docs/content/compute-control.md) | Timescale split, `.fcode` wire contract, Ultimate wave boundary, and Prototype `RP2350B` `1-bit ΣΔ` / `SMI` electronics |
| [Cadence, memory and wave compute](docs/content/cadence-memory.md) | `8πV/3λ³` three-cavity theorem, `Sb₂S₃` chord stores, `Cadence` Hermitian `EqProp`, and substrate ladder |
| [Manufacturing](docs/content/manufacturing.md) | Six-step Assemble loop, hands-vs-fingertips ladder, consolidation, and first useful part |
| [Scan, recover and matter stores](docs/content/matter-loop.md) | Non-moving `S(f)` tomography, material recovery, and Salt/Ash/Noble-Gas stores |
| [Digital twin](docs/content/digital-twin.md) | Swift/Metal quadratic solver, CAD gates, `holo/` co-design, and hardware-realism tiers |
| [Upgrade loop](docs/content/upgrades.md) | How the purchased seed prototype bootstrap leads toward self-upgrading |
| [Current state](docs/content/status.md) | Published code, active prototype vs. long-term studies, and evidence gates |
| [Agent entry point](docs/content/agents.md) | Ownership, contracts, and contribution rules |

## Repository

- [twin/](twin/) — native Swift/Metal engineering software and numerical records.
- [cad/](cad/) — manufacturing geometry and exports.
- [docs/](docs/) — canonical handbook sources, catalog, and public source selection.
- [papers/](papers/) — archived mechanism studies and dated hardware specifications, indexed from the handbook.
- [sims/](sims/) — simulation studies.
- [tools/build_docs.py](tools/build_docs.py) — reproducible static documentation build.

Design decisions, calculations, simulations, published experiments, and project bench measurements have distinct labels. A CAD export or simulation pass is not a hardware release.

## Contribute

Read [AGENTS.md](AGENTS.md) and the [agent guide](docs/content/agents.md). Make each change answer an engineering question, preserve reproducible evidence, and update the relevant guide.

## Licensing

- Code: [Apache License 2.0](LICENSE).
- Hardware design files: [CERN-OHL-P v2](cad/LICENSE).
- Papers: © Osika Innovation; published for reading, all rights reserved unless stated otherwise.

[Etherworks](https://etherworks.io/) · [Handbook](https://osika-innovation.github.io/replicator/) · [Machine-readable catalog](https://osika-innovation.github.io/replicator/catalog.json)
