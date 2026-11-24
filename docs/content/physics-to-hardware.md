# From atomic structure to a machine that shapes matter

The connection is a chain of physical models: **electronic structure → bonding → collective motion → material response → a driven component → a manufacturing process**. [OPH](oph.html) seeks a deeper account of the first links. The later links are usable engineering now. The Replicator swaps a better derivation in for an empirical link when it predicts the required response.

Earlier steps: [OPH’s field-to-atom construction](oph.html#the-field-to-atom-connection) and the [periodic-table derivation](periodic-table.html#deriving-the-shell-structure).

## 1. Bonds determine the modes

Choose the atoms and their arrangement. A model of the electrons then gives an energy landscape for the nuclei, U(R). Around a stable arrangement R₀, small displacements x give

    U(R₀+x) ≈ U(R₀) + ½ xᵀ Φ x,
    Φᵢⱼ = ∂²U/∂xᵢ∂xⱼ |R₀,
    D eₙ = ωₙ² eₙ,     D = Mₐ⁻¹ᐟ² Φ Mₐ⁻¹ᐟ².

Near its resting shape the solid acts like masses joined by springs. Φ is the table of spring stiffnesses (force constants). Mₐ holds the atomic masses. The last line gives the vibration patterns (modes) eₙ and their frequencies ωₙ. A periodic crystal adds a dependence on the vibration's direction and wavelength. Elastic response comes from how the energy changes with strain. Dielectric and piezoelectric couplings come from how the electrical polarization changes. This route replaces assigning one note to each element. [Quantum ESPRESSO's first-principles phonon workflow](https://www.quantum-espresso.org/Doc/ph_user_guide/node7.html), [force constants and modes](https://quantum-espresso.org/Doc/ph_user_guide/node9.html).

## 2. Geometry turns material response into an operator

For an elastic body with small motions, driven at one frequency ω (convention exp(iωt)):

    M q̈ + C q̇ + K q = B u,
    p = H(ω)u,
    H(ω) = R(ω)[K − ω²M + iωC]⁻¹B.

Here q is displacement and u is the list of drive amplitudes. B turns drives into forces. R turns surface motion into sound pressure p. K, M and C are stiffness, mass and damping, set by geometry, material, mounts and losses. H is the table from drives to pressure. A real piezo, body and fluid add the electrical load, the bond between source and body, and the load of the radiated sound. Eliminating those variables can make B and the effective stiffness depend on frequency.

**The body, its sources and the surrounding medium are H, in physical form.** Inverse design changes that table so that a few inputs efficiently produce the field patterns a task needs. The number of independent controls is set by the drives, not by a formal twelve-port carrier or thousands of surface features: with {{c:desktop_geometry.ports_per_plate}} drives on a plate, rank H(ω) ≤ {{c:desktop_geometry.ports_per_plate}}, so the plate makes at most that many independent patterns at one tone. The aim is to make that small set match the task. Other frequencies give other sets, within the sources' bandwidth and the settling time ([Acoustics](acoustics.html#why-a-few-sources-give-many-patterns)).

## 3. Optimize the action on matter

Acoustic, electromagnetic and optical modules act in [one work volume](architecture.html#one-work-volume-coordinated-fields), coupled through the changing state of the material. The target [twin](digital-twin.html) plans force, torque, energy delivery, joining and observation together, at once or in a deliberate order. The [combined-field example](manufacturing.html#a-candidate-combined-field-recipe) applies this to a candidate composite part.

For a small enough particle the acoustic radiation force is F = −∇U_G. U_G depends on the time-averaged squares of pressure and fluid velocity and on how the particle's density and compressibility differ from the fluid's, so a bright pressure spot is not always a trap ([Acoustics](acoustics.html#the-radiation-force-and-where-traps-sit)). Optimize force, stiffness, unwanted wells, heat and stress directly. Contributions at different frequencies need the right averaging or a transient model.

Precedent (Documented): Melde and colleagues combined passive holograms and ultrasound sources to assemble microparticles, hydrogel beads and cells into three-dimensional structures, and fixed some by gelation. Their calculation limits the finest detail by the wavelength and the source size. [Melde et al., 2023](https://pmc.ncbi.nlm.nih.gov/articles/PMC9908023/).

## 4. Build the upgrade chain

| Stage | Object or capability | Process |
|---|---|---|
| Seed platform | Calibrated acoustic module: stock borosilicate wafers, each driven by {{c:desktop_geometry.ports_per_plate}} bonded PZT-8 piezo discs | Bought wafers and discs, adhesive bonding, in-chamber calibration |
| First machine-made upgrade | A low-load insert, structured composite or calibration artifact | Feed, field-controlled arrangement, compatible curing or joining, inspection of size and function |
| Improved material module | A controlled orientation, porosity or composition that improves a named response | Qualified feedstock and consolidation; measured microstructure and response |
| Precision optical or crystal module | A part within limits on optical loss, orientation, defects and surface | A growth, deposition or finishing route, and matching measurements |

Documented precedent, not the current design: printed front masses with a triply periodic minimal surface (TPMS) lattice have been made for bolt-clamped Langevin transducers and characterized by impedance analysis and vibrometry. Geometry is thus a transducer design variable. The [Desktop Replicator](desktop-replicator.html) uses bonded discs on glass wafers with no bolt preload, and this reference does not qualify that design. [UFFC 2024 primary abstract](https://epapers2.org/uffc2024/ESR/paper_details.php?paper_id=7161).

Placement, permanent joining and atomic crystal growth are separate operations. The platform gains them as compatible modules. Its first self-made improvement should be the part whose making and checking remove the most human work per useful gain.

Read [Manufacturing](manufacturing.html) and [Upgrade loop](upgrades.html).
