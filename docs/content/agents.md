# Agent entry point

Work toward one enduring modular machine that increasingly manufactures its own upgrades. Minimize human engineering and experiment time. Keep the ultimate architecture and a concrete first configuration moving together.

The ultimate architecture coordinates acoustic, electric/magnetic and optical fields in one shared 3D work volume. Design subsystem contributions against a common material state, coordinate frame and process recipe. An acoustic-first hardware configuration establishes a starting subset; preserve the interfaces and access for the combined-field machine. Each proposed combination names its material couplings and improvement over a simpler baseline.

## Read in this order

1. [Current state](status.html): published code, active work and evidence.
2. [Architecture](architecture.html): subsystem boundaries and interfaces.
3. [Upgrade loop](upgrades.html): objectives and acceptance.
4. The relevant subsystem guide, interface and implementation.
5. Its owning paper and source records.

For physics or material-model work, also read the [Physics overview](physics.html), [OPH framework](oph.html) and [Periodic table and tones](periodic-table.html). Preserve the distinction between a mathematical result, a physical interpretation and a measured material response. Translate a proposed connection into an observable, a coupling mechanism and a comparison the twin can perform.

The [atoms-to-hardware derivation](physics-to-hardware.html) identifies the operators passed between these scales. Reproduce the small shell/geometry check with `python3 tools/check_physics_derivations.py`; upstream atomic refinements and Lean results retain their separate source and execution status.

Use [catalog.json](../catalog.json) for stable document IDs, source paths, roles, owners, related documents and review dates. [llms.txt](../llms.txt) is the compact map; [llms-full.txt](../llms-full.txt) contains the handbook text. These are navigation aids, not substitutes for code and measurements.

## Ownership

| Lane | Owns | Delivers |
|---|---|---|
| System integration | Architecture, interfaces and decisions | Compatible modules and a complete manufacturing route |
| Acoustics | Source/body/radiation co-design | Geometry, response, limits and calibration task |
| Platform/control | Timing, drive, acquisition and backend | Bounded executable jobs and reproducible records |
| Feed/joining | First material and permanent part formation | Recipe, energy/material budget and inspection |
| Metrology | Calibration and observation | Raw records, uncertainty and qualification |
| Electromagnetic control | Coils, transient/RF fields and material coupling | Field/force response, current and thermal limits, calibration and process benefit |
| Optics / metamaterials | Holographic TX/RX, optical surfaces, structured pulses and optical fabrication | Optical response, fabrication tolerances, power limits and task-qualified readout |
| Materials/processes | Material formulations and manufacturing routes | A named bottleneck removed with a feasible fabrication and inspection route |
| Physics/model validation | Framework interpretation, response laws and their validity | A sourced prediction, defined observable and comparison against measurement |
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
