# Agent entry point

This page is for engineers and AI agents who change the design, the code or this handbook. Several agents work at once in one shared working copy. These rules stop collisions and lost findings.

## The goal you are working toward

One modular machine that lasts and makes more and more of its own upgrades, reached with the least human hands-on time. Never mix up the [Desktop Replicator](desktop-replicator.html), the first machine built from parts that can be bought, and the [long-term machine](ultimate-replicator.html) it leads to.

## Read in this order

1. [Current state](status.html): what exists, its evidence, the known inconsistencies.
2. [Desktop Replicator](desktop-replicator.html): the machine all near-term work targets.
3. [Insight register](insights.html): the findings that changed the design, and which are not yet in code.
4. [Architecture](architecture.html) and [Subsystems and interfaces](subsystems.html), then the chapter for your subsystem.
5. [Glossary](glossary.html) for any unknown term.

Plain-text copies: [llms-full.txt](../llms-full.txt) (complete) and [llms.txt](../llms.txt) (map). Document identifiers are in [catalog.json](../catalog.json).

## Lanes

Each of six lanes owns a set of files and stays out of the others.

| Lane | Owns | Delivers |
|---|---|---|
| Firmware and machine interface (`os`) | Controller firmware, the machine interface and calibration code in the twin | Firmware that compiles, a calibration procedure, the same job running tethered and standalone |
| Simulation (`sim`) | The acoustic and electrical models, pattern network training, the solid finite-element bridge | Model results with receipts, including the gates before hardware |
| Sensing (`biomimicry`) | The acoustic and laser-ring scan models and their acceptance checks | Scan and inspection checks on the current geometry |
| CAD (`cad`) | The parametric model, exported geometry, drawings, parts list, power and thermal estimates | A self-consistent model and a priceable parts list |
| Handbook (`handbook`) | This handbook and the [research library](research.html) | An accurate explanation that passes its checks |
| Coordination (`cto`) | Shared constants, insight register, task board, upgrade graph, version control | Consistent numbers across lanes and clean checkpoints |

## The working loop

The engineering working copy carries a coordination tool, `tools/hub.py`, with the shared constants and the [insight register](insights.html). They are not yet in the public repository.

1. **Brief.** `python3 tools/hub.py brief --lane <lane>` lists reserved files, open findings for your lane and open tasks.
2. **Claim.** Before editing, claim a task and reserve your files: `python3 tools/hub.py claim <task> --agent <name> --files "<paths>"`. Respect other agents' reservations.
3. **Work.** Stay inside your lane's files. On a long run, send a heartbeat every 20 to 30 minutes so the reservation does not lapse.
4. **Report.** Post numbers, blockers and anything another lane needs: `python3 tools/hub.py post --channel <lane> --agent <name> --message "..."`.
5. **Register findings.** Anything that changes a design number or rules out an approach goes in the insight register, with a check a program can run and an evidence label. A finding only in prose is treated as lost. A deleted part or method gets a row in the [deleted-parts log](subsystems.html#deleted-parts-and-retired-baselines).
6. **Close.** When a task passes its check, close it with its receipt: `python3 tools/hub.py done <task> --receipt "<path>"`.

## Rules

- **One source for numbers.** Geometry, tones, part numbers and budgets come from the shared constants file. Never type a design number where a constant exists.
- **Evidence labels.** Use the labels in [Current state](status.html#evidence-labels). A passing model check is not a measurement. A published result is Documented, never Measured. Firmware tested on a workstation is Simulated.
- **Retired designs stay retired.** Do not extend the sixteen-transducer array, the drilled-wafer design, single-purpose test rigs or hand-applied adhesive joining. See [Desktop Replicator](desktop-replicator.html#what-this-design-replaced) and [Subsystems and interfaces](subsystems.html#deleted-parts-and-retired-baselines).
- **Version control.** Do not create working trees or run commands that discard work (reset, checkout of files, rebase, clean). The coordination lane makes the checkpoints.
- **Outside world.** Do not order parts, contact suppliers, push or publish without the operator's explicit approval.
- **Private material.** Research intake, private studies, internal codenames, personal names and task numbers never enter any public text.
- **State your scope.** Every change names its starting revision, the quantity it targets, the baseline and the check that decides it.
- **Check the model before reporting a miss.** Make sure the model contains the thing being tested, including its losses.

## Changing the handbook

Chapters are Markdown files in `docs/content/`. Navigation is in `docs/catalog.json`.

- Quote design numbers with a token, for example <code>&#123;&#123;c:desktop_geometry.gap_mm&#125;&#125;</code>. Tokens are filled from `docs/canon.json`, a snapshot of the shared constants and the insight register, refreshed by `python3 tools/sync_canon.py`.
- Write plainly: short sentences, everyday words, one idea per sentence. Explain a term at first use or link the [glossary](glossary.html).
- The earlier papers are retired. Do not link to them. The [research library](research.html#where-each-paper-went) maps where their content went.
- Link a publication only if it is in the source catalogue (`docs/sources.json`). Otherwise name it in words and label it a Claim.
- When a decision changes, update the owning chapter and [Current state](status.html) together. Each idea has one home; other chapters link to it.
- Before proposing a change, run:

```
python3 tools/build_docs.py
python3 tools/check_docs.py
python3 tools/check_canon.py
```

The first builds the site. The second checks links, anchors and public scope. The third fails if a number has drifted, a retired design is described as current, or a private name appears.
