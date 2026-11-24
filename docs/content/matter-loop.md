# Scan, recover and matter stores

<div class="lead">A machine that improves itself has to do three things with matter: see what is in the chamber, take material away as well as add it, and keep its feedstock in a safe form. This chapter covers scanning, removal and the stores. Adding material is covered in <a href="manufacturing.html">Manufacturing</a>.</div>

Scanning rests on standard scattering physics and simulation. Removal is a derived plan that the code does not yet implement. The first machine is the [Desktop Replicator](desktop-replicator.html).

## Scan: non-moving 3D tomography and scattering

A scan measures how the chamber and its contents answer every drive the machine can apply. That answer is the scattering matrix S(f): if the boundary is driven with the vector a at frequency f, the boundary receives b = S(f) a. Three features of S carry different information.

| Feature of S(f) | Physical meaning | Used for |
|---|---|---|
| Poles | Natural resonances of the object. Their frequencies and decay rates depend on shape and stiffness | Identifying materials and joints by ring-down |
| Eigenvectors | Drive patterns that scatter back into themselves with only a phase shift | Characteristic views of the object |
| Zeros | Drive patterns that are completely absorbed | Depositing energy at a chosen place (see removal below) |

**Nothing moves (Design decision).** There is no turntable and no moving scanner. A flat facet is seen only if some source, receiver and frequency catch its mirror reflection, so fixed sources leave facets unseen. Three static remedies close the gap, in order of preference:

1. **Wall reflections.** A known reflecting wall acts as a mirror image of the array (Documented: Zhang, Wilcox and Drinkwater, 2010). This needs a measured empty-chamber response, never an assumed one.
2. **Several frequencies.** Each tone diffracts differently and gives a partly independent view.
3. **Side sightlines.** Two facing plates resolve the plane midway between them poorly. A sensor looking across the chamber fills that band.

**Two contrasts from two directions (Derived).** For a weak scatterer the amplitude scattered through an angle θ from the incident direction follows

    f(θ) ∝ k² [ γ_κ + γ_ρ cos θ ]

where γ_κ is the contrast in compressibility and γ_ρ the contrast in density. Forward scatter (θ = 0) reads γ_κ + γ_ρ and backscatter (θ = π) reads γ_κ − γ_ρ, so two facing plates separate the two contrasts at a single frequency.

The relation has a hard limit in air. A solid has an acoustic impedance of 10 to 46 MRayl against 415 Rayl for air, so its surface reflects more than 99.98 % of the incident energy. A rigid solid gives a sharp silhouette, but the contrast saturates and says little about the material. Foams, droplets and gels separate directly. Rigid solids must be told apart by ring-down, whose frequencies scale as √(E/ρ)/L for stiffness E, density ρ and size L. Whether ring-down is readable in this chamber is Open.

### In the Desktop Replicator

**Acoustic scan.** The twelve piezo discs that drive the plates also listen on the same wires. The plan holds constant tones about 95 % of the time and spends 5 % on frequency-modulated chirps of about 200 microseconds. That is some fifty times shorter than the roughly 10 ms a levitated particle takes to respond, so scanning does not disturb what is held (Derived; the pattern follows bat echolocation, Schnitzler and Denzinger, 2011). The scan band is {{c:desktop_geometry.golomb_band_khz|range}} kHz.

**Laser ring.** {{c:mosquito_smi.total_ommatidia}} self-mixing laser diodes, nicknamed the mosquito eye, look across the chamber from beside the rear tower. Each gives two readings: a steady drop when an object blocks the beam, which builds a shadow image, and a ripple when sound crosses the beam, which measures the sound field independently of the piezo discs. This is the side sightline of remedy 3. Details are in [Desktop Replicator](desktop-replicator.html) and [Optics](optics.html).

**Glass wall.** The chamber is closed by a glass cylinder. The lasers look through it and their reflector film is on its outer face, so every beam crosses the curved glass twice each way. The cylinder shields the scan from draughts. It lifts with the head for loading, and the scan must be recalibrated after each lift.

**Sound alone cannot tell dense solids apart (Simulated).** Almost all the sound in air reflects from any dense solid, whatever it is made of, so echoes carry little about the material. In simulation, classifying solids from echoes at a realistic noise level is right 9 % of the time, which is near chance. Identifying a material needs the other channels as well: its response to a pulsed electromagnetic field, its optical reflectance in two bands, and its density from how it moves in the sound field. Combined, these separate eleven test materials completely in the model. The electromagnetic part of this is a long-term capability; the Desktop Replicator has no such coil.

**Touching beads scatter together (Derived).** Two to four beads in contact do not scatter sound as the sum of separate beads. The difference is 2 to 6 % at 32 kHz, 11 to 51 % at 64 kHz and complete at 96 kHz and above. A scan of an assembled cluster has to use a model in which each bead re-scatters the sound from its neighbours. The simple sum is acceptable only at the lowest tone.

**Material moves as neutral grains (Design decision).** Feedstock is carried as electrically neutral grains or droplets. A stream of charged particles would repel itself and screen the fields that are meant to steer it. Stray static charge on a bead is a separate problem, limited to {{c:electrostatics_and_matter_loop.max_bead_charge_pc}} pC by grounded, slightly conductive glass and controlled humidity, as described in [Desktop Replicator](desktop-replicator.html#the-enclosure).

<a id="reconstruction-honesty-and-static-validation-g17-g18-g19"></a>

### What a scan is allowed to claim

Three rules keep reconstruction honest. The first two are software checks run on simulated data. They are model checks, not bench results.

- **Measured or inferred, always stated.** Every stored pattern must say whether it was measured or inferred, with no default, and an inferred pattern must name the model that produced it. The file reader rejects a pattern that omits this (the provenance check, G17).
- **Held-out prediction.** The chamber model must predict a quarter of the source and receiver pairs that were withheld from it (the held-out check, G18). A wrong model cannot predict data it never saw. The check passes on simulated data.
- **A known reference object.** Absolute dimensional error is to be checked against a precisely made reference object in the chamber (G19). This needs hardware and has not been run.

Display filters that sharpen an image for a person are never fed back into reconstruction as if they were data.

### Long-term direction

The long-term design replaces twelve wired sources with roughly 100,000 optically addressed elements, which removes unseen facets by coverage. The optical aim is tomography that resolves position, polarisation and spectrum together and reads roughness from depolarisation. The component techniques are Documented. A real-time loop in a chamber is Open.

## Recover (Dissolve): material-specific separation and reuse

Removing joined material is harder than adding it, and the obvious shortcut is wrong. The current plan is Derived, with published precedent for one step, and Open in the chamber.

### Why reversing a holding pattern removes nothing

The pressure field is p = H·u, where u is the vector of drive signals and H is the complex response of the chamber. Two facts follow.

    H·conj(u) ≠ conj(H·u)            reversing the drive does not reverse the field
    |conj(p)|² = |p|²,  |∇conj(p)|² = |∇p|²     so the force is unchanged: the same trap

H is complex because sound takes time to travel, so conjugating the drive does not conjugate the field. Even if it did, the radiation force depends only on |p|² and |∇p|², which conjugation leaves unchanged, and the same trap is rebuilt. Negative acoustic intensity, which would push material out of a well, does not exist.

The simulation and twin code still contain both shortcuts: a removal command that conjugates the drive, and a simulation step that feeds a negative intensity into the material model. One simulation self-test asserts that a removal pass erases a shape built by an add pass. It passes only because of the negative-intensity term and will have to be rewritten when the shortcut is removed.

### Two state fields

The model needs two fields: density ρ(x), which says where material is, and bond strength b(x), which says whether it is joined. Assembly moves ρ into place and then raises b. Removal must lower b first, because bonds are far stronger than any acoustic force.

### The four-stage sequence

<div class="diagram">
<svg viewBox="0 0 880 200" role="group" aria-labelledby="remove-title remove-desc" xmlns="http://www.w3.org/2000/svg">
<title id="remove-title">Four stages of removing joined material</title>
<desc id="remove-desc">Four boxes in a row joined by arrows: ring-down scan, coherent perfect absorption, cold unbinding, and transport back to a crucible. Bond strength falls in stage three and density moves in stage four.</desc>
<defs><marker id="arrow-remove" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8" fill="#186b60"/></marker></defs>
<g fill="#f2f5ef" stroke="#186b60" stroke-width="1.5">
<rect x="10" y="20" width="190" height="96" rx="9"/><rect x="233" y="20" width="190" height="96" rx="9"/><rect x="456" y="20" width="190" height="96" rx="9"/><rect x="679" y="20" width="190" height="96" rx="9"/>
</g>
<g stroke="#186b60" stroke-width="1.5" marker-end="url(#arrow-remove)"><path d="M200 68 H231"/><path d="M423 68 H454"/><path d="M646 68 H677"/></g>
<g fill="#173630" font-family="system-ui,sans-serif" text-anchor="middle" font-size="16">
<text x="105" y="50" font-weight="600">1 · Ring-down scan</text><text x="105" y="74" font-size="13">find the resonances</text><text x="105" y="94" font-size="13">of the joint</text>
<text x="328" y="50" font-weight="600">2 · Perfect absorption</text><text x="328" y="74" font-size="13">drive that reflects least</text><text x="328" y="94" font-size="13">puts energy in the joint</text>
<text x="551" y="50" font-weight="600">3 · Cold unbinding</text><text x="551" y="74" font-size="13">short high-peak pulses</text><text x="551" y="94" font-size="13">break the bond</text>
<text x="774" y="50" font-weight="600">4 · Return</text><text x="774" y="74" font-size="13">carry freed material</text><text x="774" y="94" font-size="13">to a crucible</text>
<text x="105" y="150" font-size="13">b high · ρ in part</text><text x="328" y="150" font-size="13">b high · ρ in part</text><text x="551" y="150" font-size="13">b falls to zero</text><text x="774" y="150" font-size="13">ρ moves to crucible</text>
<text x="440" y="186" font-size="13">Throughout: mass in the part + mass in the crucibles = constant</text>
</g>
</svg>
</div>

1. **Ring-down scan.** Excite the chamber briefly at low power and listen. The poles of S(f) that belong to the joint give its resonance frequencies.
2. **Coherent perfect absorption.** At one of those resonances, choose the drive that minimises reflected energy. Mathematically this is the smallest singular vector of the scattering matrix at that frequency. With nothing coming back, the energy sent in ends up in the joint. Coherent perfect absorption is Documented in optics ([Chong et al., 2010](https://doi.org/10.1103/PhysRevLett.105.053901); [Wan et al., 2011](https://doi.org/10.1126/science.1200735)) and related to acoustic time reversal ([Fink](https://pubmed.ncbi.nlm.nih.gov/18267667/)). It controls where wave energy goes. It does not by itself undo chemistry.
3. **Cold unbinding.** Break the bond without heating the bulk, using short, high-peak pulses at a very low duty cycle, or a pulsed induced electric field from a small ring coil at a crucible (see [Electromagnetic control](electromagnetics.html)). Which materials and joints this can release is Open.
4. **Return to a crucible.** Reshape the field so the freed fragment sits on a slope instead of in a well, and carry it back to a crucible. The mass in the part plus the mass in the crucibles stays constant.

### Material-specific routes

Wave energy cannot un-react a cured polymer, reverse metal diffusion or sort a mixed alloy. Recovery is therefore planned when a part is designed, and uses the least disruptive route that works.

| Priority | Route | What must be qualified |
|---:|---|---|
| 1 | Release a reversible joint (wax, solder, soluble binder) and recover the module whole | Release threshold; damage and contamination afterwards |
| 2 | Soften or remelt compatible thermoplastics or low-melting metals into droplets or powder | Thermal history, oxidation, viscosity, solidification |
| 3 | Break up loosely bound composites or powders acoustically or mechanically | Particle size, wear contamination, yield |
| 4 | Separate chemically into pure, oxidised stock | Selectivity, side products, energy, purity of each lot |

Every recovery run is meant to update a ledger of mass in, stock recovered, losses and energy spent. The loop counts as closed when a second inspected part has been built from recovered material.

## The Stores: equation library vs. matter pantry

The equation store holds information. The matter stores hold atoms. Keeping them separate avoids design errors.

| Store | Holds | Constraint | In the Desktop Replicator |
|---|---|---|---|
| Equation store | Holographic equations of objects, the calibrated chamber response, the trained pattern network, build recipes | Storage capacity; every item tagged measured or inferred | Workstation disk, plus under {{c:cadence_brain.cadence_sparse_max_kb}} kB on the compute card |
| Matter stores | Feed materials | Conservation of mass, chemical stability, safety | Three open crucibles in the chamber: {{c:desktop_geometry.in_chamber_crucibles}} |

The prototype's crucibles are loaded by hand with material whose origin is recorded. Nothing enters or leaves through pipes. The holographic equation is described in [Compute, sensing and control](compute-control.html#holographic-equations), and the memory that recalls stored entries in [Cadence, memory and wave compute](cadence-memory.html).

### Store oxidised, never as reactive powder (Derived)

Bulk stock is kept in its most stable chemical form, and reduced to a reactive form only at build time. An oxidised metal is at its thermodynamic ground state. A fine pure metal powder is a fire hazard with a shelf life.

- **Reactive metals cannot sit near water as powder.** Per kilogram in contact with water, finely divided lithium releases 1,762 L of hydrogen, aluminium 1,359 L, magnesium 1,006 L, iron 657 L, calcium 610 L and sodium 532 L.
- **Salt and ash.** The same alkali and alkaline-earth metals form very soluble chlorides (LiCl about 830 g/L, CaCl₂ 745, MgCl₂ 540, NaCl 360) and can be stored as a pumpable brine. Insoluble oxides (SiO₂, Al₂O₃, Fe₂O₃, CaO) form an inert solid ash. Water supplies hydrogen and oxygen, graphite supplies carbon, and filtered air supplies nitrogen, oxygen and 0.93 % argon.
- **Noble gases in a pressure cartridge.** Water dissolves only 1.5 to 578 mg/L of the gases from helium to xenon, and extracting a gram of xenon from air means processing about 2,140 m³ of air at about 714 kWh. A steel cartridge at 200 bar holds 3,900 to 21,000 times more per litre than water does, with no cryogenics: at 20 °C xenon is supercritical at 2,281 g/L and krypton reaches 978 g/L (Peng–Robinson equation of state).

Two limits apply. Arranging trace-element containers by position in the periodic table is a filing system with no physical function. Speculative states of matter, such as claimed ultradense hydrogen, are kept out of feedstock storage.

### Long-term direction

The long-term design stacks three plates. The middle plate carries sources on both faces, one set facing up into the build chamber and one facing down into a mirrored storage chamber. In that lower chamber, incoming or recovered material would be sorted acoustically by its compressibility and density contrast, scanned for quality, and lifted to the build chamber by the fields. The long-term pattern store is a volume hologram in a low-loss phase-change material. All of this is a design direction with no model result yet.

## What is not yet shown

The loop presumes capabilities that the simulation record does not yet support. Placing a second bead beside a first failed in earlier array studies (1 to 2 mm off) and is Open for the Desktop Replicator. Fields from few sources leave unwanted wells, so powder handling is not shown. No simulation tracks mass through a build. Physical removal is not implemented. [Manufacturing](manufacturing.html#what-is-not-yet-shown) gives the evidence for each.

## Open questions

| Question | Who answers it |
|---|---|
| Can ring-down distinguish a joint from the part around it in this chamber? | Simulation, then in-chamber calibration |
| Does a minimum-reflection drive exist for twelve sources and five tones, and how much energy reaches the joint? | Simulation |
| Which joints can be broken cold, and with what pulse? | Process simulation |
| Does the two-field model conserve mass through add and remove? | Simulation |
| How accurate is a scan against a known reference object? | In-chamber calibration |

Read next: [Manufacturing](manufacturing.html), [Desktop Replicator](desktop-replicator.html), [Architecture](architecture.html) and the earlier paper [Material recovery](../papers/replicator_dissolve.html).
