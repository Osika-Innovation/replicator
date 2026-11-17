# Start here

We are building a field-controlled manufacturing machine that manufactures increasingly demanding upgrades for itself. The **Engineering Handbook** is the canonical, self-contained technical specification for the entire programme, separating what defines the **Ultimate Architecture** from how we build the **Bootstrap Prototype (`P0` / `HA-0`)** today.

## What the Replicator does

Every build closes four physical steps inside one shared three-dimensional work volume: **supply feedstock, arrange and orient it by fields, consolidate/join it, and inspect/recover the output**. Optical, acoustic, and electric/magnetic fields act together on a shared material state—with **zero internal moving tools and zero object turntables (`Plan A`)**.

1. **Scan:** Probe an unknown or partially built object from the walls (`S(f)` + optical sightlines) into a provenance-tagged `.pattern` chord representation ([Scan, recover and matter stores](matter-loop.html)).
2. **Assemble:** Synthesize holographic traps (`sound as hands`, `light as fingertips`, induction where conductive), glide payloads into position, consolidate via ultrasonic clamping and addressed energy, and check continuously until the structure *rings true* ([Manufacturing](manufacturing.html)).
3. **Recover:** Disassemble or reprocess parts along least-costly physical/chemical routes back into safe, oxidized **Salt / Ash / Carbon / Water** stores ([Scan, recover and matter stores](matter-loop.html#recover-dissolve-material-specific-separation-and-reuse)).

## Three design commitments

**One enduring platform.** Stable mechanical datums, replaceable boundary cartridges, and shared `.fcode` / `.pattern` contracts preserve the machine frame as hardware modules upgrade.

**Minimum human engineering time.** Digital twins (`Swift/Metal` + `MLX/Cadence`) search geometry, tolerances, and drive chords ahead of hardware fabrication; reusable bench fixtures (`K-PORT+`, `K-HAPTIC-PZT`, `K-MOSQUITO-SMI`) become permanent service instrumentation.

**More function per part.** Dispersive plates, chaotic faceplates, diffractive facets, and two-terminal crystals execute multiplexing, beam shaping, and sensing natively in physics.

## Ultimate architecture and the bootstrap prototype

It is essential not to mistake temporary workshop electronics for the architecture of the machine itself. Every subsystem in this handbook separates these two horizons explicitly:

| Dimension | Ultimate architecture (physical limit) | Bootstrap prototype (`P0` / `HA-0` workshop seed) |
|---|---|---|
| **Boundaries & actuation** | Continuous optically-addressed photoconductive-piezo films (`~10⁵` pixels) over phase-conjugate multimode fibers, graded phononic tapers, and tonotopic dispersive plates ([Acoustics](acoustics.html)) | Opposed thin broadband `3 + 3` or `6 + 6` PZT elements on `1–1.5 mm` borosilicate/aluminum supersonic plates + SLA phase ring + `1.2 mm` PCB backing absorber |
| **Optical observation & fingertips** | Full bidirectional toroidal-pulse stem (`space ⊗ polarization ⊗ spectrum` density-matrix RX), `756 nm` optically-addressed metasurface SLMs, `OAM`/skyrmion registers, and optical gradient tweezers ([Optics](optics.html)) | Nanoimprinted `TiO₂` diffractive facets along `270°` clear radial windows + `Ø12 mm` bore feeding 3-pin TO-can laser diodes (`SMI` + `SOT-23 ×200` AC stage) |
| **Electromagnetic coupling** | Coordinated containerless `J × B` melt shaping, `m/q` sorting, and traveling-wave axial bore lift ([Electromagnetics](electromagnetics.html)) | Contactless modal exciter (`X-EM`) for bench blank characterization; process EM windings deferred past first acoustic build |
| **Compute, sensing & memory** | Minimal-electricity wave-equilibrium compute: threshold `EML` diode cavities, reciprocal `Sb₂S₃`/`Sb₂Se₃` holographic chord memory (`η = (M#/M)²`), and candidate passive optical or excitable neural-gel substrates (`Open`) ([Cadence and memory](cadence-memory.html)) | **Prototype scaffolding:** collocated `RP2350B` `75 MSa/s` `1-bit ΣΔ` ganglia on shared `XIN + SYNC`, `< 60 kB` `5–10%` sparse complex `int8` `Cadence` (`EqProp`) or optional `SoC-FPGA`, trained offline on workstation `MLX/Metal` GPU ([Compute, sensing and control](compute-control.html)) |
| **Matter & stores loop** | Mirrored three-plate active stack (`R9`): upper build chamber + lower acoustophoretic sorting and QC storage chamber fed from Salt/Ash/Carbon/Water/Air/Noble-Gas stores ([Matter loop](matter-loop.html)) | Indexed septum vials (`ha0_septum_cap`), calibrated dispenser feeds, single-material test payloads, and reusable bench phantoms |

## How to read the handbook

This handbook is self-contained and supersedes the older standalone HTML papers as the primary engineering authority. Use:

1. [Architecture](architecture.html) for coordinated fields, two-carrier physics (`λ`, momentum, crossings), and subsystem contracts.
2. [Compute, sensing and control](compute-control.html) for the timescale split, wire contracts (`.fcode`, `.pattern`, `MachineBackend`), and Prototype `RP2350B` / `SoC-FPGA` details.
3. [Cadence, memory and wave compute](cadence-memory.html) for the `8πV / 3λ³` mode theorem, `Sb₂S₃` chord memory, complex Hermitian `EqProp`, and the low-electricity compute ladder.
4. [Manufacturing](manufacturing.html) and [Scan, recover and matter stores](matter-loop.html) for the complete `Scan → Assemble → Recover → Store` loop.
5. [Upgrade loop](upgrades.html) and [Digital twin](digital-twin.html) for simulation gates, CAD contracts, and the path to self-upgrading.
6. [Physics overview](physics.html) for [OPH](oph.html), [Light, fields and matter](light-matter.html), [Periodic table and tones](periodic-table.html), and [From atoms to hardware](physics-to-hardware.html).

Legacy HTML papers remain accessible via the [research library](research.html) for historical traceability and long-form derivations.
