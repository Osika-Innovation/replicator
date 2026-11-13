# Agent entry point

Work toward one enduring modular machine that increasingly manufactures its own upgrades. Minimize human engineering and experiment time. Keep the ultimate architecture and a concrete first configuration moving together.

## Read in this order

1. [Current state](status.html): published code, active work and evidence.
2. [Architecture](architecture.html): subsystem boundaries and interfaces.
3. [Upgrade loop](upgrades.html): objectives and acceptance.
4. The relevant subsystem guide, interface and implementation.
5. Its owning paper and source records.

Use [catalog.json](../catalog.json) for stable document IDs, source paths, roles, owners, related documents and review dates. [llms.txt](../llms.txt) is the compact map; [llms-full.txt](../llms-full.txt) contains the handbook text. These are navigation aids, not substitutes for code and measurements.

## Ownership

| Lane | Owns | Delivers |
|---|---|---|
| System integration | Architecture, interfaces and decisions | Compatible modules and a complete manufacturing route |
| Acoustics | Source/body/radiation co-design | Geometry, response, limits and calibration task |
| Platform/control | Timing, drive, acquisition and backend | Bounded executable jobs and reproducible records |
| Feed/joining | First material and permanent part formation | Recipe, energy/material budget and inspection |
| Metrology | Calibration and observation | Raw records, uncertainty and qualification |
| Materials/optics/EM | Candidate processes and components | A named bottleneck removed with a feasible fabrication route |
| Representation/learning | Module data and optional learned proposals | A validated interface and improvement over a baseline |
| Documentation | Handbook, catalog and source connections | Clear current explanation with evidence and ownership |

## Working rules

Inspect repository status and active branches before editing. Use an isolated branch for concurrent work. Preserve other sessions' changes and keep research proposals distinct from integrated configurations.

For each task, state the input revision, target observable, constraints, baseline and completion test. Keep acceptance criteria fixed during the comparison; record a changed criterion as a new decision.

Use independent checks and held-out cases where they can reveal a model error. A model must not certify its own invented observations as physical evidence.

Do not turn every question into a new rig. Reuse mounts, sensors and calibration software. Prepare concrete designs and order packs before requesting an operator decision. Purchases and hardware operation require their applicable authorization.

## Documentation changes

Lead with what the system does or what we are building. Replace repeated hedging with a precise evidence label and a named next step. Preserve source-specific uncertainty.

Each guide has one canonical topic. Papers explain mechanisms or retain historical arguments; they must link back to the current guide. Do not copy private notes, intake attachments, local paths or credentials into a public build.

When a change affects a design, update its guide, catalog relations and status in the same change. Run the documentation build and link check before publication.
