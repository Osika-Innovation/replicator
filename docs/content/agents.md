# Agent entry point

This page is for engineers and AI agents who will change the design, the code or this handbook. Several agents work on the project at the same time in one shared working copy, so the rules below exist to keep their work from colliding and to keep findings from being lost.

## The goal you are working toward

One modular machine that lasts and that increasingly makes its own upgrades, reached with the least human hands-on time. Two things must never be confused in anything you write: the [Desktop Replicator](desktop-replicator.html), which is the first machine and is built from purchasable parts, and the long-term architecture it leads to. **No hardware has been built, ordered or measured.**

## Read in this order

1. [Current state](status.html): what exists, its evidence, and the known inconsistencies.
2. [Desktop Replicator](desktop-replicator.html): the machine all near-term work targets.
3. [Insight register](insights.html): the findings that changed the design and where each still has to be carried into code.
4. [Architecture](architecture.html), then the chapter for your subsystem.
5. [Glossary](glossary.html) for any term you do not know.

For a complete plain-text copy of the handbook use [llms-full.txt](../llms-full.txt). For the compact map use [llms.txt](../llms.txt). Stable document identifiers are in [catalog.json](../catalog.json).

## Lanes

Work is divided into six lanes. Each lane owns a set of files and stays out of the others.

| Lane | Owns | Delivers |
|---|---|---|
| Firmware and machine interface (`os`) | Controller firmware for the Desktop Replicator, the machine interface and calibration code in the twin | Firmware that compiles, a calibration procedure, the same job running tethered and standalone |
| Simulation (`sim`) | The acoustic and electrical physics models, the pattern network training code, the solid finite-element bridge | Model results with receipts, including the gates that must pass before hardware |
| Sensing (`biomimicry`) | The scan models for sound and for the laser ring, and their acceptance checks | Scan and inspection checks on the current geometry |
| CAD (`cad`) | The parametric model, exported geometry, drawings, parts list, power and thermal estimates | A self-consistent model and a parts list that can be priced |
| Handbook (`handbook`) | This handbook and the paper library | An accurate public explanation that passes its checks |
| Coordination (`cto`) | The shared constants, the insight register, the task board, the upgrade graph and version control | Consistent numbers across lanes and clean checkpoints |

## The working loop

The engineering working copy carries a small coordination tool, `tools/hub.py`, together with the shared constants and the insight register. They are not yet part of the public repository.

1. **Brief.** Run `python3 tools/hub.py brief --lane <lane>`. It lists the files other agents have reserved, the open findings for your lane and the open tasks.
2. **Claim.** Before editing, claim a task and reserve the files you will touch: `python3 tools/hub.py claim <task> --agent <name> --files "<paths>"`. Respect other agents' reservations.
3. **Work.** Stay inside your lane's files. During a long run, send a heartbeat every 20 to 30 minutes so the reservation does not lapse.
4. **Report.** Post concrete numbers, blockers and anything another lane needs to know: `python3 tools/hub.py post --channel <lane> --agent <name> --message "..."`.
5. **Register findings.** If you learn something that changes a design number or rules out an approach, add it to the insight register with a check that a program can run, and state its evidence label. A finding that lives only in prose is treated as lost.
6. **Close.** When a task passes its check, close it with a pointer to the receipt: `python3 tools/hub.py done <task> --receipt "<path>"`.

## Rules

- **One source for numbers.** Geometry, tones, part numbers and budgets are read from the shared constants file. Do not type a design number into code or prose when a constant exists.
- **Evidence labels.** Keep documented, derived, simulated, measured, open and claim separate, as defined in [Current state](status.html#evidence-labels). A model check that passes is not a measurement.
- **Retired designs stay retired.** Do not extend the sixteen-transducer array, the drilled-wafer design, single-purpose test rigs or hand-applied adhesive joining. The table is in [Desktop Replicator](desktop-replicator.html#what-this-design-replaced).
- **Version control.** Do not create working trees and do not run commands that discard work (reset, checkout of files, rebase, clean). The coordination lane makes the checkpoints.
- **Outside world.** Do not order parts, contact suppliers, push or publish without explicit approval from the operator.
- **Private material.** Research intake, private studies and internal codenames never enter the handbook, the public repository or any public text.
- **State your scope.** Every engineering change names the revision it started from, the quantity it targets, the baseline it compares against and the check that decides it.

## Changing the handbook

Chapters are Markdown files in `docs/content/`. Navigation and metadata are in `docs/catalog.json`.

- Quote design numbers with a token, for example <code>&#123;&#123;c:desktop_geometry.gap_mm&#125;&#125;</code>. The tokens are filled from `docs/canon.json`, a snapshot of the shared constants and of the insight register. Refresh it with `python3 tools/sync_canon.py`.
- Write plainly. Define a term at first use or link the [glossary](glossary.html). Use code formatting only for file names, commands and identifiers.
- When a decision changes, update the owning chapter, [Current state](status.html) and the catalog together.
- Before proposing a change, run all three:

```
python3 tools/build_docs.py
python3 tools/check_docs.py
python3 tools/check_canon.py
```

The first builds the site. The second checks links, anchors and public scope. The third fails if a number has drifted from the constants, if a retired design is described as current, or if a private name appears.
