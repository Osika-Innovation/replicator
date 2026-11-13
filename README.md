# Etherworks · Replicator

**One modular machine that gains the ability to manufacture its own upgrades.**

We develop field-controlled manufacturing through acoustic and electromagnetic research, twin-native CAD, simulation and reusable physical measurements. The long-term objective is a machine that can build increasing portions of its successors. The first milestone is an inspected, useful part that improves the same platform.

**[Read the Replicator Handbook →](https://osika-innovation.github.io/replicator/)**

| Start with | What it answers |
|---|---|
| [Architecture](docs/content/architecture.md) | Subsystems, interfaces and the preferred first acoustic candidate |
| [Manufacturing](docs/content/manufacturing.md) | Feed, arrange, join, inspect and upgrade |
| [Materials and modes](docs/content/materials.md) | Crystals, spectral response and fabrication requirements |
| [Digital twin](docs/content/digital-twin.md) | CAD, simulation, control and autonomous research |
| [Upgrade loop](docs/content/upgrades.md) | How the first platform leads toward self-replication |
| [Current state](docs/content/status.md) | Published code, active studies and evidence |
| [Agent entry point](docs/content/agents.md) | Ownership, reading order and contribution rules |

## Repository

- [twin/](twin/) — native Swift/Metal engineering software and numerical records.
- [cad/](cad/) — manufacturing geometry and exports.
- [papers/](papers/) — mechanism papers and dated architecture studies, indexed in the handbook.
- [sims/](sims/) — simulation studies.
- [docs/](docs/) — canonical handbook sources, catalog and public source selection.
- [tools/build_docs.py](tools/build_docs.py) — reproducible static documentation build.

Design decisions, calculations, simulations, published experiments and project bench measurements have distinct labels. A CAD export or simulation pass is not a hardware release.

## Contribute

Read [AGENTS.md](AGENTS.md) and the [agent guide](docs/content/agents.md). Make each change answer an engineering question, preserve reproducible evidence and update the relevant guide.

## Licensing

- Code: [Apache License 2.0](LICENSE).
- Hardware design files: [CERN-OHL-P v2](cad/LICENSE).
- Papers: © Osika Innovation; published for reading, all rights reserved unless stated otherwise.

[Etherworks](https://etherworks.io/) · [Handbook](https://osika-innovation.github.io/replicator/) · [Machine-readable catalog](https://osika-innovation.github.io/replicator/catalog.json)
