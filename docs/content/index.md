---
# ignored: catalog owns metadata
---
<div class="eyebrow">ETHERWORKS / ENGINEERING HANDBOOK</div>

# Build the machine that builds the next.

<div class="lead">The Replicator holds, moves and joins material with sound, light and electromagnetic fields in one chamber with no tools inside it. This handbook is the working engineering reference for the programme.</div>

The first machine is the [Desktop Replicator](guides/desktop-replicator.html), a benchtop chamber designed from parts that can be bought today. It exists as a CAD model and a set of simulations. **No hardware has been built, ordered or measured yet.** The long-term aim is a machine that makes an increasing share of the parts of its own successor.

<div class="diagram">
<img src="assets/desktop/desktop_iso.jpg" alt="CAD render of the Desktop Replicator: a rounded-square base and head joined by a rear tower, with an open chamber between them and a round glass plate at the chamber floor." width="1200" height="900">
<p>The Desktop Replicator, {{c:desktop_geometry.envelope_mm|x}} mm. CAD render of the current design.</p>
</div>

<div class="cards">
<a class="card" href="guides/desktop-replicator.html"><span class="eyebrow">01 / THE MACHINE</span><h2>Desktop Replicator</h2><p>What is being designed first, how it works, and what is still open.</p></a>
<a class="card" href="guides/status.html"><span class="eyebrow">02 / TODAY</span><h2>Current state</h2><p>What exists, the evidence behind it, and what blocks each next step.</p></a>
<a class="card" href="guides/architecture.html"><span class="eyebrow">03 / THE SYSTEM</span><h2>Architecture</h2><p>How sound, light and electromagnetic fields share one work volume, now and in the long-term design.</p></a>
<a class="card" href="guides/insights.html"><span class="eyebrow">04 / WHAT WE LEARNED</span><h2>Insight register</h2><p>The findings that changed the design and how far each has been carried into code.</p></a>
</div>

## Choose a route

| You want to | Start with | Then read |
|---|---|---|
| Understand the project in ten minutes | [Start here](guides/start.html) | [Desktop Replicator](guides/desktop-replicator.html), [Current state](guides/status.html) |
| Design or review a subsystem | [Architecture](guides/architecture.html) | [Acoustic bodies](guides/acoustics.html), [Optics and metamaterials](guides/optics.html), [Electromagnetic control](guides/electromagnetics.html), [Compute, sensing and control](guides/compute-control.html) |
| Follow material through a build | [Manufacturing](guides/manufacturing.html) | [Scan, recover and matter stores](guides/matter-loop.html) |
| Understand the pattern network and wave computing | [Cadence, memory and wave compute](guides/cadence-memory.html) | [Digital twin](guides/digital-twin.html) |
| See how the machine improves itself | [Upgrade loop](guides/upgrades.html) | [Insight register](guides/insights.html) |
| Look up a term | [Glossary](guides/glossary.html) | |
| Work as an engineer or AI agent | [Agent entry point](guides/agents.html) | [Current state](guides/status.html) |
| Find a paper or patent | [Research library](guides/research.html) | |
| Read the theoretical framework | [Physics overview](guides/physics.html) | [From atoms to hardware](guides/physics-to-hardware.html) |

## How the programme works

Computation is spent to remove parts and human work. The digital twin searches geometry and tolerances before anything is made. Small, reusable measurements settle what computation cannot. The frame, the calibration tools and the file formats stay fixed while modules are replaced, increasingly by parts the machine makes.

Two things are kept strictly apart throughout: the first machine, built from purchasable electronics, and the long-term architecture it is a step towards.

## How to trust what you read

Every claim is labelled as a design decision, documented published work, a derivation, a simulation result, a project measurement, an open question or an unverified claim. The numbers that describe the Desktop Replicator are quoted from the shared engineering constants, and the build of this site fails if they drift. Known disagreements inside the design are listed openly in [Current state](guides/status.html#known-inconsistencies-in-the-design).
