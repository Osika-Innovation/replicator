# Research library

<div class="lead">The handbook is the one place where the programme is explained. The standalone papers that came before it are retired. This page shows where each paper's content went, and lists the outside publications the handbook rests on.</div>

## Where each paper went

The papers were written one mechanism at a time, over several machine designs. Their insights, derivations and sources have been moved into the guides below. The papers stay online as a record only. Several describe earlier machines, so where a paper and a guide disagree, the guide is right.

<!-- PAPER_TABLE -->

Three kinds of paper content were left behind on purpose: hardware that has been replaced, numbers with no traceable source, and claims that later work in the same papers withdrew. What was deleted from the design, and why, is logged in [Subsystems and interfaces](subsystems.html#deleted-parts-and-retired-baselines).

## Publications from outside the project

Outside work is sorted by how strong it is as evidence. Published laboratory experiments come first. Reference data and models come second. Patents and exploratory leads come last, so that they never read like a lab result. For the same sources arranged by subsystem, see [Proven in the lab](evidence.html). The full records are in the [source catalogue](../sources.json).

A catalogue entry says how deeply the source was read. "Bibliographic record only" means the record was checked and the paper itself has not yet been read by the project.

<!-- SOURCE_TABLE -->

## How a source becomes engineering

A report of an unusual result is a lead. It is not a specification. Before it can shape a part, five things are written down:

1. **Identity.** The DOI, patent number or versioned source.
2. **Depth.** Whether the project has seen only a mention, the abstract, or the full method.
3. **Mechanism.** What the source says happens, and which task in the machine it would serve.
4. **Cost.** The precision, materials and processes it depends on.
5. **Next check.** The calculation, simulation or measurement that would confirm it or rule it out.

Leads that fail are kept, with the reason. A source becomes part of a module only through a concrete design and an acceptance test, as described in [Current state](status.html#how-something-moves-up).

## The physics framework

The research framework pages connect the machine to deeper questions about waves and matter: [Physics overview](physics.html), [Observer Patch Holography](oph.html), [Light, fields and matter](light-matter.html), [Periodic table and tones](periodic-table.html), [Materials and modes](materials.html) and [From atoms to hardware](physics-to-hardware.html). They inform the programme. They are not required to follow the machine design.
