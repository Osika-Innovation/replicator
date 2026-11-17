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

## One work volume and material state

The target architecture coordinates acoustic, electric/magnetic and optical actions in the same three-dimensional region. Field maps, material geometry and sensors share a calibrated coordinate frame. A process program defines which actions overlap, which follow one another and which observations trigger the next step.

Couple the models through the material's evolving position, orientation, temperature and phase or cure state. For example, optical heating can change viscosity and acoustic response; curing can immobilize particles that an earlier field moved. Optimize the finished part and process against a simpler baseline. Separate field visualizations alone do not implement this coupled control loop.

This is an integration requirement for the twin. The published implementation and active studies retain the status described below.

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

The digital twin mirrors the machine's physical state variables directly: differential piezoelectric drive/sense state (`V(t)`, `I(t)`, `C_0(T) dV/dt`, `Θ ẋ(t)`), `τ_inertia = L / v_D` broadband crystal timing, passive cavity gain (`Q_cav`), sightline-true Beer-Lambert optical opacity plus `LightRead` acoustic phase over co-designed diffractive facets, and sparse harmonic `.pattern` chord lists rather than raw voxel-video sequences or synthetic X-ray pixel cameras. Keep raw two-terminal bridge and `SMI` captures available for calibration and fault diagnosis.

An optional neural warm-start or learner (`Cadence`, implemented as a `5%–10%` block-sparse, event-driven complex Hermitian Equilibrium Propagation graph `W_fb = W_fwdᴴ`, `||W||₂ ≤ 1`, fitting under `60 kB` `int8` SRAM for `~8–15 ms` `RP2350B` settles vs. `~220–300 ms` dense) is benchmarked against the existing `NOWS` physics optimizer across four hardware-realism tiers (`ideal_fp32`, `rp2350_ganglia_q8` simulating `75 MSa/s` `1-bit ΣΔ` + `C_0` drift + `SMI`, `fpga_int8_sparse`, and `optical_pcm_analog`) and validates bench coupons `K-HAPTIC-PZT` and `K-MOSQUITO-SMI` prior to hardware assembly ([Compute, sensing and control](compute-control.html)).

Pin library versions and benchmark the actual equations and workloads before replacing a solver or buying hardware for it. Representation, rendering speed and physical accuracy have separate checks.

## Show what is known

The viewer distinguishes design intent, simulated predictions, raw observations, reconstructed estimates and residuals. Sensor agreement can support an estimate; it does not make an unobserved interior directly measured.

An imported response or a simulation receipt never becomes hardware evidence merely because it is displayed beside CAD.
