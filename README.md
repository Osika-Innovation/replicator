# The Replicator

**Holographic matter manipulation** — a machine that scans, assembles, and
dissolves objects with shaped acoustic and electromagnetic fields. No nozzle,
no moving parts: the walls of the build chamber command the field, the field
commands the matter.

This is the open engineering repository of
[Osika Innovation](https://osika-innovation.lovable.app). The guided story —
architecture, physics, roadmap — lives on the site; this repo is the working
material behind it: the digital twin, the CAD, and the research papers.

> Two chambers — one holds the object, one holds the matter it will become;
> between them, one plate.

## Layout

| Path | What it is |
|---|---|
| [`twin/`](twin/) | **RSW-1, the field compiler** — the machine's digital twin. Native Swift + Metal: RH-1 geometry, T0 Rayleigh–Sommerfeld propagator with exact adjoint, T1 acoustic FDTD, T2 Gor'kov radiation forces, inverse solvers (IBP / GS-PAT / Diff-PAT), physics acceptance gates that write receipts, and a headless render/screenshot harness. `swift build` and go — no Xcode required. |
| [`papers/`](papers/) | The research corpus: principles, architecture, the RH-1 hardware specification, the three modes (scan / assemble / dissolve), the two carriers (phonons / photons), stores, memory & compute, bounds analysis, and the field-compiler specification. |
| [`cad/`](cad/) | RH-1 free-standing machine model (Blender), plate and table-assembly sources (OpenSCAD / CadQuery), and the 12-port bench chamber. |
| [`sims/`](sims/) | Pre-registered simulation studies. Predictions are frozen before the run and results are published either way — including the negative ones (see the quasicrystal array study in `papers/`). |

## How we work

Every claim in the papers carries a register — **measured** (demonstrated in
published experiments), **derived** (follows from measured physics by
calculation), or **open** (not yet demonstrated, named as such, attached to a
concrete gate). Candidate designs are tested against pre-registered criteria,
and design decisions are recorded with their full history; nothing is
silently rewritten. The twin enforces the same discipline in code: physics
acceptance gates write timestamped receipts, and the emulator's API is the
hardware's API.

## Licensing

- Code (`twin/`, `sims/`) — [Apache License 2.0](LICENSE)
- Hardware design files (`cad/`) — [CERN-OHL-P v2](cad/LICENSE)
- Papers (`papers/`) — © Osika Innovation, all rights reserved for now;
  published openly on the [site](https://osika-innovation.lovable.app/research)

We publish our designs because we would rather live in a world where a
hundred groups extend this machine than one where one company owns it.
