# From fields to manufactured parts

A manufacturing capability is a reproducible transformation from supplied material to an inspected part. Both the **Ultimate Architecture** and the **Bootstrap Prototype (`P0` / `HA-0`)** run the same closed process loop inside one shared work volume—varying in field aperture resolution, feed automation, and consolidation energy delivery rather than abandoning the loop itself.

---

## Six-step concurrent Assemble loop

In steady state, different regions of the chamber execute Steps 2–6 concurrently while every single grain walks through them causally:

1. **1 · Slice (field schedule, not Z-layers):** Convert target geometry (`.stl` or parametric twin shape) into timed multi-tone boundary drives (`.fcode`), free of mechanical Z-axis layering whenever trap paths remain clear.
2. **2 · Feed (`R10`):** Introduce powder, droplets, or wire/melt feedstock along the central `Ø12 mm` bore (`Ultimate`: traveling-wave axial induction / acoustic tube conveyor; `Prototype`: indexed septum vials `ha0_septum_cap` and calibrated injectors).
3. **3 · Trap (Gor'kov potential):** Superpose boundary waves into three-dimensional quiet pockets (`Derived` + `Published`):

       U_rad = (4/3) π a³ [ f₁ · (½) κ₀ ⟨p²⟩ − f₂ · (¾) ρ₀ ⟨v²⟩ ],    F_rad = −∇U_rad
       Φ = f₁ + (3/2) f₂   (Φ > 0 traps at pressure nodes for solids/liquids in air)

   Keep strict sign-and-normalization discipline: mixing Fourier conventions silently flips pressure nodes into unstable antinodes (`twin` tests `G7`, `G-B0`).
4. **4 · Move (parallel steer-first glide):** Ramp boundary phases continuously so hundreds of traps translate concurrently without toolarms. Each carry step updates array steering phases toward the target waypoint *before* optimizing contrast (`PlaceRig.steer`), keeping trap depth `≥ 99%` across `10 mm` spans (`G-P1` pass in twin) rather than decaying monotonically.
5. **5 · Consolidate / Weld:** Focus thermal, optical, or clamping energy exclusively onto grains that reach latched neighbors—keeping chamber heat confined to the bond zone (`FEEDSTOCK → IN_TRANSIT → MOLTEN → WETTED → LATCHED`).
6. **6 · Check (closed loop, never open-loop printing):** Run boundary tomography (`HAPTIC` + `SMI`) continuously underneath the build; compare live acoustic/optical chord response against target `.pattern` signatures and correct errors before compounding ([Scan, recover and matter stores](matter-loop.html)).

---

## Placement ladder ("sound is the hands, light is the fingertips") and levitation classes

No single carrier handles every length scale or material class efficiently (`R1` &amp; `R1-b`):

* **The hands (millimeter → micron):** Because phonons carry `~10⁵–10⁶×` more momentum per watt than photons (`E/v` vs. `E/c`), acoustic and inductive forces execute bulk transport and macro/mesoscale placement ([Acoustics](acoustics.html)).
* **The fingertips (micron → tens of nanometers, `Ultimate`):** Once sound brings a payload into the axial/radial optical working zone (`hand-off` verb `Open`), holographic optical gradient tweezers (`Published`: Ashkin, Grier) hold and align dielectric inclusions to nanometer tolerances. Below tens of nanometers, thermal agitation (`k_B T`) beats bare gradient stiffness (`polarizability ∝ a³`), requiring near-field / plasmonic traps (`Published` literature; `Open` in-machine).
* **Levitation by material class:**
  * **Conductive metals (including melts):** Induction (`J × B` levitation melting—handled inductively in the **Ultimate** stack; omitted from `P0` prototype process actuation per the `2026-11-13` EM audit).
  * **Charged droplets (any material):** Electrostatic levitation (`ESL` across plate electrodes with mandatory high-rate active servo per Earnshaw's theorem).
  * **Dielectric / neutral solids &amp; precision multi-trap placement:** Holographic acoustics (default across both Prototype and Ultimate).

---

## Transport-phase ladder (the lowest-rung rule)

Use the least-unbound matter phase that the active fields can grip cleanly—climb the energy ladder only when the surface or feature tolerance demands it:

| Rung | Feedstock form | Primary grip | Engineering role |
|---|---|---|---|
| **1 · Powder** | Micro-grains / polymer or composite spheres | Acoustic (+ magnetic orientation where doped) | Default lowest energy-per-kg path (`Prototype` starting rung) |
| **2 · Melt / droplets** | Mesoscale molten droplets (`~10¹⁶` atoms each) | Induction (`Ultimate` EM) or acoustic droplet hold | Fast roughing: droplets weld directly on contact |
| **3 · Vapor** | Directed vapor flux | Flux geometry &amp; masking | Surface thin-film coatings (PVD precedent) |
| **4 · Plasma** | Ionized atomic stream | Magnetic / electric `m/q` confinement | Reserved strictly for atomic finishing passes and elemental separation (`Ultimate` horizon) |

---

## Consolidation and athermal softening (R15)

**Permanent retirement notice — "The sound is the heat" is dead:** Ultrasonic absorption inside a free airborne sub-millimeter grain is far too small to sinter or melt it cleanly. Acoustics handles **transport, clamping, and ultrasonic friction joining** against an already-latched surface; thermal sintering or melting always requires a separate **addressed heat channel** (focused optical cure/sinter beam, spectral EM absorption, or radiant contact). On the molten-droplet rung, cooling glow offers optional **thermophotovoltaic (`TPV`) energy recovery** back onto the DC rail (`Published` component physics; `Open` in-chamber).

**Athermal softening rung (`R15` — "flow without melt"):** Conventional printing wastes `~3–4×` latent heat warming bulk parts past `T_m`. Between rigid holding and full melting lies field-assisted plastic flow—supported separately by multiple `Published experiments`, while composed in-chamber softening remains `Open`:

* **Acoustoplasticity (Blaha effect):** Superimposed ultrasound reduces metal flow stress tens of percent with minimal bulk heating.
* **Electroplasticity (Troitsky):** Pulsed electrical currents drop metal yield stress beyond pure resistive heating metrics.
* **Acoustic fluidization &amp; hydrolytic weakening:** Vibration unjams granular friction (Melosh), and trace water + moderate temperature softens crystalline quartz by dislocation creep (Griggs).
* **Ultrasonic machining &amp; nonlinear phononics:** Mode-selective transient deformation (`Open` for high-rate in-machine joining).

Latent heat and entropy export remain immutable thermodynamic bounds; avoiding an unnecessary bulk sensible-heat bath does not abolish joining energy budgets.

---

## A candidate combined-field recipe

Evaluate a composite process in one shared work volume: acoustic forces arrange particles in a liquid feedstock, magnetic fields orient suitable anisotropic inclusions, and patterned light cures a compatible matrix while `HAPTIC` / `SMI` readout tracks the arrangement ([Optics](optics.html), [Electromagnetics](electromagnetics.html)).

Two pairwise parts have direct experimental precedents: Greenhall and Raeymaekers combined ultrasound-directed particle assembly with stereolithography to build patterned composites ([Ultrasound and stereolithography](https://doi.org/10.1002/admt.201700122)), while Nagarajan and colleagues integrated magnetic particle alignment with jetting, UV curing, and thermal post-curing ([Magnetic alignment and curing](https://pmc.ncbi.nlm.nih.gov/articles/PMC8433740/)). Combining all three requires qualifying a single compatible resin/suspension against acoustic streaming, curing shrinkage, and optical attenuation, then proving a measurable improvement over simpler recipes.

---

## Prototype bootstrap vs. ultimate parallel fabrication

| Horizon | Feed, fixture &amp; inspection route | Target first-part &amp; production goal |
|---|---|---|
| **Prototype bootstrap (`P0` / `HA-0`, `FAB-01`)** | Calibrated `3 + 3` / `6 + 6` dispersive acoustic head, `ha0_septum_cap` vials, UV resin or fusible wax/solder beads, external caliper/optical microscope verification alongside inline `HAPTIC`/`SMI` checks | **First part (`FAB-01`):** repeatable hold/move/release, bonding a tracked origin fiducial / `ha0_sla_phase_ring` insert, demonstrating a measured machine improvement with explicit external finishing steps ([Upgrade loop](upgrades.html)) |
| **Ultimate architecture (`META-01`+)** | Continuous automated Salt/Ash/Carbon/Water feeds up the bore, optically-addressed `10⁵`-pixel acoustic/EM sculpting + optical tweezer registration, live non-moving `S(f)` verification, and closed [recovery loop](matter-loop.html) | Multi-material structural, electronic, acoustic, and replicated nanoimprint optical parts manufactured autonomously inside one sealed cycle |

Read [Upgrade loop](upgrades.html), [Scan, recover and matter stores](matter-loop.html), [Materials and modes](materials.html), and [Assemble](../papers/replicator_assemble.html).
