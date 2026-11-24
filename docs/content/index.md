---
# ignored: catalog owns metadata
---
<div class="eyebrow">ETHERWORKS / ENGINEERING HANDBOOK</div>

# Build the machine that builds the next.

<div class="lead">The Replicator holds, moves and joins material with sound, light and electromagnetic fields in one chamber with no tools inside it. This handbook is the programme's engineering reference.</div>

The first machine is the [Desktop Replicator](guides/desktop-replicator.html), a benchtop chamber designed from parts that can be bought today. It exists as a CAD model and a set of simulations. The long-term aim is a machine that makes more and more of the parts of its own successor.

<div class="diagram">
<img src="assets/desktop/desktop_iso.jpg" alt="CAD render of the Desktop Replicator: a rounded-square base and head joined by a rear tower, with a glass cylinder enclosing the chamber between them and a round glass plate at the chamber floor." width="1600" height="1200">
<p>The Desktop Replicator, {{c:desktop_geometry.envelope_mm|x}} mm. CAD render of the current design.</p>
</div>

<div class="cards">
<a class="card" href="guides/evidence.html"><span class="eyebrow">00 / OUTSIDE PROOF</span><h2>Proven in the lab</h2><p>Peer-reviewed experiments by other groups behind each key mechanism.</p></a>
<a class="card" href="guides/desktop-replicator.html"><span class="eyebrow">01 / THE MACHINE</span><h2>Desktop Replicator</h2><p>What is being designed first, how it works, and what is still open.</p></a>
<a class="card" href="guides/status.html"><span class="eyebrow">02 / TODAY</span><h2>Current state</h2><p>What exists, the evidence behind it, and what blocks each next step.</p></a>
<a class="card" href="guides/architecture.html"><span class="eyebrow">03 / THE SYSTEM</span><h2>Architecture</h2><p>How sound, light and electromagnetic fields share one work volume, now and in the long-term design.</p></a>
<a class="card" href="guides/insights.html"><span class="eyebrow">04 / WHAT WE LEARNED</span><h2>Insight register</h2><p>The findings that changed the design and how far each has been carried into code.</p></a>
</div>

## Choose a route

| You want to | Start with | Then read |
|---|---|---|
| See the machine in 3D, pull it apart and click its parts | [The machine in 3D](guides/cad-3d.html) | [Subsystems and interfaces](guides/subsystems.html) |
| Understand the project in ten minutes | [Start here](guides/start.html) | [Desktop Replicator](guides/desktop-replicator.html), [Current state](guides/status.html) |
| Check the published science behind it | [Proven in the lab](guides/evidence.html) | [Research library](guides/research.html), [Current state](guides/status.html) |
| Design or review a subsystem | [Architecture](guides/architecture.html), then [Subsystems and interfaces](guides/subsystems.html) | [Acoustics](guides/acoustics.html), [Optics](guides/optics.html), [Electromagnetics](guides/electromagnetics.html), [Compute, sensing and control](guides/compute-control.html) |
| Follow material through a build | [Manufacturing](guides/manufacturing.html) | [Scan, recover and matter stores](guides/matter-loop.html) |
| Understand the pattern network and wave computing | [Cadence, memory and wave compute](guides/cadence-memory.html) | [Ideas from biology](guides/biology.html), [Digital twin](guides/digital-twin.html) |
| See how the machine improves itself | [Upgrade loop](guides/upgrades.html) | [Insight register](guides/insights.html) |
| Look up a word | [Glossary](guides/glossary.html) | |
| Work as an engineer or AI agent | [Agent entry point](guides/agents.html) | [Current state](guides/status.html) |
| Find a publication or an earlier paper's content | [Research library](guides/research.html) | |
| Read the theoretical framework | [Physics overview](guides/physics.html) | [From atoms to hardware](guides/physics-to-hardware.html) |

## How the programme works

Computing is spent to remove parts and human work. The [digital twin](guides/digital-twin.html) searches shapes and tolerances before anything is made. The frame, the calibration tools and the file formats stay fixed while modules are replaced, more and more by parts the machine makes ([Upgrade loop](guides/upgrades.html#one-enduring-platform)).

Two machines are kept apart throughout: the first, built from electronics that can be bought, and the long-term design it leads to. [Architecture](guides/architecture.html#long-term-architecture-and-the-desktop-replicator) compares them.

## How to trust what you read

Every claim carries an [evidence label](guides/status.html#evidence-labels). Desktop Replicator numbers come from the shared engineering constants, and the site build fails if they drift. Known disagreements inside the design are [listed openly](guides/status.html#active-engineering-gates).
