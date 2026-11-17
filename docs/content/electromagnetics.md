# Electromagnetic control

This subsystem owns electric, magnetic, induction, RF/microwave, and pulsed electromagnetic interactions in the shared three-dimensional work volume, coordinating with [acoustic bodies](acoustics.html) and [optics and optical metamaterials](optics.html) on one coordinate frame and material state.

## Ultimate vs. prototype electromagnetic role

| Aspect | Ultimate architecture (coordinated fields) | Prototype bootstrap plan (`P0` / `HA-0`, `2026-11-13` EM audit) |
|---|---|---|
| **Process manipulation &amp; heating** | Containerless `J × B` inductive levitation/melting of conductive drops (comparable to the [ESA MSL-EML facility](https://www.esa.int/Science_Exploration/Human_and_Robotic_Exploration/International_Space_Station/Material_Science_Laboratory_Electromagnetic_Levitator_MSL-EML)), magnetic torque orientation of anisotropic inclusions in combined cure recipes, `m/q` ion sorting, and traveling-wave axial bore lift (`R10`) | **Omitted as a `P0` process actuator:** the `2026-11-13` second-pass EM branch study (`em-integration`, `Simulated` + `Derived`) showed `0.3 m`-standoff RH-1 coil pairs deliver `~8.5 × 10⁻⁵` steel-bead weights (`9 × 10⁸×` short of levitating limestone), external planar coils cannot bring steel spheres into contact (`26` weights mutual dipole repulsion vs. `0.28` command authority), and induction efficiency on `Ø0.76 mm` solder is `0.6–5%` |
| **Instrumentation &amp; metrology** | Integrated non-contact modal sensing, dielectric spectroscopy across sweep bands, and active EM shielding | **Proposed `X-EM` calibration instrument:** a flat coil + `Ø20 mm` magnet `0.5 mm` behind the `Ø120` aluminum disc delivers `0.13–0.21 N/A` (`100–119 dB` at `1 A`, `< 1 W`), mapping `99.4%` of axisymmetric blank modes (`≤ 45 kHz`) for `K-PORT+` before mounting piezos |
| **Acoustic element coupling rule** | Baseline stays directly electromechanical (`k² ≈ 0.5–0.9` piezo); **Direct EMAT** (eddy-current Lorentz face launch) is **rejected** as primary muscle because tens-of-dB efficiency loss dumps heat inside a sealed chamber; cordless RF-rectenna power + local piezo stays a valid sealed-wall upgrade option | Direct wired H-bridge piezo drive on prototype heads |

Retaining EM geometry access and synchronized datums ensures future combined-field recipes—such as [magnetic inclusion alignment + acoustic shaping + optical curing](manufacturing.html#a-candidate-combined-field-recipe)—plug directly into the platform once their feed material requires magnetic torque or melt containment.

---

## Levitation, heating and softening experiments

In conductive fluids, Lorentz force `J × B` shapes and positions melts while resistive losses govern temperature; dielectric and magnetic powders obey dipolar force/torque laws (`−∇(m·B)` and `m × B`).

Treat any claimed **non-thermal "soft molding"** mechanism quantitatively (`Design discipline`): distinguish conventional inductive heating/melting, plastic yield change (`electroplasticity`, [Manufacturing](manufacturing.html#consolidation-and-athermal-softening-r15)), and any anomalous field hypothesis by measuring flow stress against matched temperature/thermal-history controls.

---

## Toroidal and pulsed fields

Preserving precise distinctions across identically named shapes prevents conceptual mixing across papers and twin models:

| Concept | Physical description | Engineering question &amp; status |
|---|---|---|
| **Toroidal coil / winding (`R5`)** | Contrawound copper pair on a hollow former (`44 + 44` turns); equal currents form a 2-turn ring dipole, opposite currents form an 88-turn confined toroid (`cad` verified; fixes earlier inverted text in `Architecture`) | What usable field reaches the work zone? At `0.3 m` standoff, passes `12–18%` ring mode above `1 kHz` through Al plates; unsuitable for small-payload levitation (`Simulated`) |
| **Vortex / rotating field pattern** | Azimuthal phased drive applying `J × B` stirring or torque inside conductive melt/particles | What eddy currents, stirring flow, and heating are measured vs. Biot–Savart + Navier–Stokes models? |
| **Propagating toroidal EM pulse** | Space–time nonseparable electromagnetic wave packet (`Optical/THz` [Zdagkas et al., 2022](https://doi.org/10.1038/s41566-022-01028-5); microwave cm-ranging [Wang et al., 2024](https://doi.org/10.1038/s42005-024-01850-z)) | What source bandwidth, launcher, and RX density-matrix tomography recover target structure? ([Optics](optics.html#toroidal-optical-pulses)) |
| **Exploratory propulsion / gravity claims** | Speculative couplings beyond Biot–Savart / Maxwell equations | What predicted force exceeds Lorentz, corona wind, thermal plume, and cable artifacts under closed controls? |

---

## Patent-led and exploratory mechanisms

Named patent disclosures are retained with explicit claim attribution and discriminating falsifiers rather than unverified adoption or blind dismissal:

| Primary source | Claimed connection to investigate | Evidence &amp; twin check status |
|---|---|---|
| [Magnetic vortex wormhole generator, US20030197093A1](https://patents.google.com/patent/US20030197093A1/en) | Proposed lift/mass effects and crystal joining via vortex coil coupling | Coil geometry checked against Biot–Savart (`windings`); no anomalous force in linear EM solver; sustained effect `Open` pending sealed weight/EMI test |
| [Water energy generator, US20060180473A1](https://patents.google.com/patent/US20060180473A1/en) | Proposed rotating magnetic vortex + constitutive softening | Claims only; no calibrated mechanical flow vs. matched thermal control published |
| [Full body teleportation system, US20060071122A1](https://patents.google.com/patent/US20060071122A1/en) | Related high-voltage/vortex waveguide claims (plus `1:3` ratio sweep `k = −8/9` tested monotonically through `1:3` in `S-SC3`—not a special resonance) | Monotonic dial confirmed in twin (`S-SC3`); `15 GHz` / kV spike claims outside quasi-static model (`Open`, unverified safety/EMC cost) |

An organizer-hosted summary of Jarod Yates's 2024 **Graviflyer replication experiments** ([Replication account](https://www.altsci.net/graviflyer-replication-experiments/)) documents horizontal deflection with sustained vertical lift unachieved; force claims require balanced, shielded, battery-only unpowered controls, and private laboratory reports remain outside public capability claims.

---

## Twin and integration contract

Every electromagnetic module exports coil geometry, winding sense, constitutive laws (`σ`, `μ`, `χ`), frequency/transient impedance, current/thermal limits, and cross-volume stray fields onto the shared acoustic/optical grid—benchmarking every combined process against its best simpler single-field baseline ([Manufacturing](manufacturing.html)).

Read [Architecture](architecture.html), [Optics and optical metamaterials](optics.html), [Manufacturing](manufacturing.html), and [Research library](research.html).
