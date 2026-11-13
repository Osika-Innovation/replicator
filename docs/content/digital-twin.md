# The engineering twin

The twin connects CAD, physical models, control programs and evidence. It is the place where candidate machines are compared, jobs are prepared and measurements improve the next design.

## Four linked descriptions

| Description | Contents |
|---|---|
| Module | Geometry, constitutive properties, datums, ports and revision |
| Response | Model or measurement, frequency band, loading, uncertainty and validity |
| Process | Feedstock, actions, joining, state transitions and acceptance |
| Evidence | Source, code revision, calibration, inputs, outputs and decision |

Exact CAD and spatial material fields are complementary. Preserve STEP and other manufacturing exports where they carry useful geometry and tolerances. A module package links representations rather than claiming they are interchangeable.

## Existing software

The published repository contains a native Swift/Metal implementation with field calculation, optimization, particle models, scanning studies, parametric CAD and recorded numerical checks. Start from the [twin README](https://github.com/Osika-Innovation/replicator/blob/main/twin/README.md) for the commands supported by the checked-out revision.

Build from the repository's twin directory:

```sh
swift build -c release
./.build/release/fieldc test
./.build/release/fieldc cad check --rules
```

Additional platform/backend and body-response work exists in active engineering branches. The [current-state page](status.html) distinguishes it from the published code; this handbook does not merge those branches implicitly.

## Around-the-clock research

Maintain a durable queue of questions, designs, runs and decisions. Cache unchanged responses, checkpoint long work, avoid duplicate jobs and bound compute resources.

For every question choose among a cheap search, a higher-fidelity calculation and a reusable measurement. Evaluate expected decision value per human setup hour, along with elapsed time and cost. More samples of an incomplete model do not supply a missing material law.

## Learning and control

Use compact observations when they preserve information needed for the task. Keep raw records available for diagnosis. An optional learner can propose actions or initialize optimization; compare it with the existing planner on held-out targets and disturbances.

Pin library versions and benchmark the actual equations and workloads before replacing a solver or buying hardware for it. Representation, rendering speed and physical accuracy have separate checks.

## Show what is known

The viewer distinguishes design intent, simulated predictions, raw observations, reconstructed estimates and residuals. Sensor agreement can support an estimate; it does not make an unobserved interior directly measured.

An imported response or a simulation receipt never becomes hardware evidence merely because it is displayed beside CAD.
