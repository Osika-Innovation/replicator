# Periodic table and tones

The Replicator treats a material as a structured system with a response we can measure. Composition supplies the ingredients. Bonding and arrangement decide which motions are available. Shape and boundaries decide how those motions couple to an outside field. That links the periodic table to machine design.

## Why the table repeats

An element's atomic number is the charge of its nucleus. Electrons occupy quantum states around that nucleus. The pattern of the outermost electrons recurs, giving families of elements with related chemistry. The wave description enters through these states and their interactions.

Our standing-wave research asks whether a simpler geometry can recover those patterns and their measured spectra (Open). For engineering, the reference stays the specified atom, ion or material phase and its measured properties.

## What a material's “tones” mean

An atom has a set of energy levels. A particle of light, a photon, can exchange the energy difference of an allowed transition between two levels, **ΔE = hf**. Coupling depends on the transition's strength and on selection rules, which say which jumps are allowed. An element has a spectrum, not one note. NIST records energy levels, wavelengths and transition probabilities for specified atoms and ions. [NIST Atomic Spectra Database](https://www.nist.gov/pml/atomic-spectra-database), [NIST spectral-line physics](https://www.nist.gov/pml/atomic-spectroscopy-compendium-basic-ideas-notation-data-and-formulas/atomic-spectroscopy)

Bonding creates collective behaviour. Molecules rotate and vibrate. Crystals carry vibrations of their whole lattice. A finished resonator has modes shaped by its size, cut and mounting. One composition can give different structures and responses. We therefore map **material + structure + environment → response**, then choose a drive for the desired action.

| Physical level | What is being described | Useful machine decision |
|---|---|---|
| Atom or ion | Electronic transitions and their coupling strengths | Choose spectral lines for identification or a specified optical interaction |
| Molecule | Rotational and vibrational transitions | Identify bonds and process changes through spectroscopy |
| Crystal | Collective lattice motion, symmetry and direction-dependence | Choose crystal orientation and electromechanical or optical coupling |
| Fabricated component | Elastic modes, losses, supports and surface motion | Design the [acoustic body](acoustics.html#bending-waves-in-a-plate), its input points and usable operating bands |
| Work volume | Travelling fields, interference and material forces | Transport, trap and arrange feedstock into a target form |

These levels share the language of modes but use different models of motion. Shifting an optical frequency down by octaves until it is audible is only a picture. It does not preserve an interaction with matter or specify an acoustic drive.

## Deriving the shell structure

Four separate calculations build the table. Geometry sets which modes are possible. An operator sets their energies. Spin and exclusion set how many electrons each holds. Interactions set the order in which they fill.

**Angular structure supplies the subshell alphabet.** For one electron with the same physics in every direction, the angular patterns are the spherical harmonics, the standing waves on a sphere. They satisfy

`−∇²(S²) Yℓm = ℓ(ℓ+1) Yℓm`, with `m = −ℓ,…,+ℓ`.

There are therefore `2ℓ+1` angular states: 1, 3, 5 and 7 for s, p, d and f. Spin gives two states per spatial orbital, and exclusion means no two electrons share a state. A subshell therefore holds `2(2ℓ+1)` electrons: **2, 6, 10, 14**. The count is exact under those assumptions.

**Hydrogen supplies the principal shells.** Summing over `ℓ=0,…,n−1` gives `2Σ(2ℓ+1)=2n²`: **2, 8, 18, 32**. The nonrelativistic Coulomb problem has an extra symmetry, called SO(4). Fock's construction relates the count of its bound states at each energy to harmonics on S³, the three-dimensional sphere. This n² count is what the geometric programme aims to recover. [Fock (1935)](https://doi.org/10.1007/BF01336904), [fish-eye and Coulomb symmetry](https://www.jetp.ras.ru/cgi-bin/dn/e_033_06_1083.pdf).

The 600-cell is a regular grid of points on S³. Its 120 vertices correspond to the binary icosahedral group. A fresh calculation of its nearest-neighbour graph Laplacian gives the first six multiplicities **1, 4, 9, 16, 25, 36**. The remaining bands are 9, 16 and 4: the finite lattice has a real cutoff. Relating OPH's observer screen and phase transport to the relevant nontrivial Hopf bundle is a further identification, physical and in the model. A sphere plus arbitrary circles does not automatically select that bundle.

**Screening supplies an ordering mechanism.** Inner electrons screen the nucleus, which changes the pull that outer electrons feel. The Demkov–Ostrovsky focusing family models this and can be solved on paper. It shows how the radial shape of the potential changes where each shell begins. In our normalization, its zero-energy coupling thresholds are ordered by

`λ = nᵣ + (2ℓ+1)/μ`, with `nᵣ = n−ℓ−1`.

For a fixed μ, a larger λ needs a stronger well. Here μ is twice the 1972 paper's parameter. The dimensionless radial shape is `r²|V| ∝ x^μ/(1+x^μ)²`, with `x=r/R`.

At μ=1, `λ=n+ℓ`: subshells with equal n+ℓ share a threshold. Just above 1, larger ℓ lowers λ more, so within a tied group the smaller n goes first. An exact comparison in fractions gives **1<μ<6/5** for the familiar first 19 subshells through 7p. At μ=6/5, 6s crosses 4f and 7s crosses 5f. This explains the nominal filling sequence through a radial mechanism. These are thresholds of the specified potential. The configurations of real neutral atoms, and their exceptions, also depend on many-electron interactions. [Demkov and Ostrovskii (1972)](https://jetp.ras.ru/cgi-bin/dn/e_035_01_0066.pdf).

**The doubled rows follow by counting.** For a diagonal `N=n+ℓ`, the allowed angular values are `ℓ=0,…,floor((N−1)/2)`. Its capacity is `2 ceil(N/2)²`, giving **2, 2, 8, 8, 18, 18, 32, 32**. These are diagonal (left-step) capacities. Conventional periods are **2, 8, 8, 18, 18, 32, 32**, with a different row boundary. Principal-shell capacities, diagonal capacities and period lengths are three different things.

**Reproducible calculation.** The [check script](https://github.com/Osika-Innovation/replicator/blob/main/tools/check_physics_derivations.py) builds the 600-cell graph, counts the shells and uses exact rational inequalities to find the strict ordering interval. Its [result record](../assets/physics/atomic-structure-check.json) contains the counts and a failing comparison just beyond μ=6/5. These checks establish the stated mathematics (Derived). Atomic spectra and material response remain separate comparison targets.

## Quartz and the cymatics question

Quartz's atomic structure, its lattice vibrations and the resonances of a cut component are three different levels of description. The [materials chapter](materials.html#quartz-and-the-cymatics-question) connects them to crystal growth and field-guided assembly.

## From atomic structure to the twin

A model of the electrons' energy gives the bonding forces. Derivatives of that energy give the crystal's force constants and elastic properties, which enter the model of the acoustic body. The [atoms-to-hardware derivation](physics-to-hardware.html) follows this chain to a manufacturing task.

### Put the spectrum into the twin

Each material record carries composition, phase, microstructure, temperature, density and the response that matters for the task, with uncertainty and source. The module adds geometry, supports and measured transfer response. Optimization chooses frequency, amplitude, phase and timing against a useful outcome: force, position, heating, joining quality or a measured optical change.

For the first acoustic module, two things decide the outcome: the coupled piezo, body and medium, and how the feedstock interacts mechanically with the field. Published holographic ultrasound experiments have assembled particles, cells and hydrogel beads into three-dimensional forms (Documented). They are a precedent for shaping and fixing material with wave fields, not for atomic rearrangement or element conversion. [Melde et al., 2023](https://pmc.ncbi.nlm.nih.gov/articles/PMC9908023/)

Read [Light, fields and matter](light-matter.html) and [Digital twin](digital-twin.html).
