# Insight register

An insight, in this project, is a finding that changes a design number, rules out an approach or exposes a disagreement between two parts of the design. Each one is recorded once, given an evidence label and attached to checks that a program can run against the code and the documents. A finding is finished only when every place that should reflect it does.

The register exists because findings made in one corner of the project were being lost before they reached the others. A calculation in a design note is of no use if the firmware, the simulation and the handbook still assume the old number.

## How to read the table

- **Finding** says what was learned.
- **What it changes** says why it matters to the machine.
- **Evidence** uses the labels defined in [Current state](status.html#evidence-labels). Every finding in the register so far rests on published work, calculation or simulation.
- **Carried into code and documents** counts the places that already reflect the finding against the places that should. A low count is not a failure of the finding. It is the list of work still to do.

The checks look for specific text in specific files. They show that a finding has been written into a file, not that the resulting code is correct. Correctness is established by the model checks and, eventually, by measurement.

## The register

<!-- INSIGHT_TABLE -->

## What the register shows

Findings 1 to 15 define the [Desktop Replicator](desktop-replicator.html) and the corrections to removal, pulsed fields and thermal layout. Nearly all of their places are now filled.

Findings 16 to 27 come from a review of the whole engineering record on 17 November 2026. They are mostly disagreements and unstated limits, and they are the ones a reader should weigh before trusting any performance figure:

- The planned drive voltage is several times what the specified drive stage delivers (17).
- The receive converter's margin was computed for a narrower band than the tones need (18).
- The file describing how the plates radiate is too coarse to trust in detail (19).
- Air temperature has to be tracked far more closely than the design provides for (20).
- Twelve sources may leave unwanted traps and uneven filling, which is unchecked for this machine (21).
- The chamber, open at the time of the review, had no draught shield, no laser enclosure and no interlock (22). It has since been closed with a glass cylinder and given an interlock.
- There is no joining recipe without adhesive, and placing one bead beside another is unsolved (24).

Findings 28 to 30 are simulation results that followed on 18 November 2026 and settle several of the above: the simple one-bit receive converter fails its test (28), and a solid model of the plates shows that the shipped plate-response file is wrong and that drive strength, not pattern control, limits levitation (29). Finding 30 gives the reason, bending stress in the glass, and the way forward: a foam bead as the first test particle.

Findings 31 to 36 were added on 22 November 2026. They cover static charge on beads (31), a chamber-independent file format for shapes (32), the limits of sound for telling materials apart (33), lifting with one tone and cleaning the field with several (34), and how touching beads scatter sound together (35). Finding 36 sets bounds for the long-term machine and does not change the Desktop Replicator.

Each has an owner and a task. [Current state](status.html#known-inconsistencies-in-the-design) summarises them.

## Adding a finding

Record the finding, its evidence label and its sources in the register in the engineering working copy. Attach at least one check per affected lane: a file, text that must be present, and any text that must be gone. Then refresh this page's snapshot with `python3 tools/sync_canon.py` and add a plain-language note for it in `docs/canon.json`. The [agent entry point](agents.html) describes the full loop.
