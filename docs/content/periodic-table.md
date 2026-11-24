# Periodic table and tones

The Replicator treats a material as a structured physical system with a measurable response. Composition supplies the ingredients; bonding and arrangement determine the available motions; geometry and boundaries select how those motions couple to an external field. This connects the periodic table to machine design through spectra, constitutive properties and manufacturing processes.

## Why the table repeats

An element's atomic number specifies its nuclear charge. Electrons occupy quantum states around that nucleus, and recurring patterns in the outer electronic structure produce families of related chemical behavior. The wave description enters through these quantum states and their interactions. Bonding then creates molecules and solids with additional collective behavior.

Our standing-wave research asks whether a more economical underlying geometry can recover those patterns and their quantitative spectra. For engineering, the reference remains the specified atom, ion or material phase and its measured properties.

## What a material's “tones” mean

An atom has a set of energy levels. A photon can exchange an energy difference with an allowed transition, with **ΔE = hf**. The transition's strength and selection rules determine how effectively it couples. Consequently, an element has a spectrum rather than a single universal note. The NIST Atomic Spectra Database records energy levels, wavelengths and transition probabilities for specified atoms and ions. [NIST Atomic Spectra Database](https://www.nist.gov/pml/atomic-spectra-database), [NIST spectral-line physics](https://www.nist.gov/pml/atomic-spectroscopy-compendium-basic-ideas-notation-data-and-formulas/atomic-spectroscopy)

Bonding creates new collective behavior. Molecules rotate and vibrate; crystals carry lattice vibrations; a finished resonator has modes shaped by its size, cut and mounting. The same chemical composition can produce different structures and useful responses. We therefore map **material + structure + environment → response**, then choose a drive for the desired action.

| Physical level | What is being described | Useful machine decision |
|---|---|---|
| Atom or ion | Electronic transitions and their coupling strengths | Choose spectral lines for identification or a specified optical interaction |
| Molecule | Rotational and vibrational transitions | Identify bonds and process changes through spectroscopy |
| Crystal | Collective lattice motion, symmetry and anisotropy | Choose crystal orientation and electromechanical or optical coupling |
| Fabricated component | Elastic modes, losses, supports and surface motion | Design the acoustic body, its input points and usable operating bands |
| Work volume | Propagating fields, interference and material forces | Transport, trap and arrange feedstock into a target form |

These descriptions share the language of modes but use different dynamical models. Converting an optical frequency into an audible octave is a visualization convention. It does not preserve an interaction with matter or specify an acoustic drive.

## Deriving the shell structure

The strongest connection is a chain of spectral calculations. Geometry determines the space of possible modes; an operator determines their energies; spin and exclusion determine their capacities; interactions determine their filling order. These are distinct calculations, and we can show where each enters.

**Angular structure supplies the subshell alphabet.** In a rotationally symmetric one-electron model, the angular eigenfunctions are the spherical harmonics. They satisfy

`−∇²(S²) Yℓm = ℓ(ℓ+1) Yℓm`, with `m = −ℓ,…,+ℓ`.

There are therefore `2ℓ+1` angular states: 1, 3, 5 and 7 for s, p, d and f. Electron spin adds two states per spatial orbital. With fermionic exclusion, a subshell holds `2(2ℓ+1)` electrons: **2, 6, 10, 14**. This is an exact counting argument under those physical assumptions.

**Hydrogen supplies the principal shells.** Summing over `ℓ=0,…,n−1` gives `2Σ(2ℓ+1)=2n²`: **2, 8, 18, 32**. The nonrelativistic Coulomb problem has an additional symmetry, conventionally described by SO(4); Fock's construction relates its bound-state degeneracy to harmonics on S³. This n² count is the atomic mathematics that the geometric programme aims to recover. [Fock (1935)](https://doi.org/10.1007/BF01336904), [fish-eye and Coulomb symmetry](https://www.jetp.ras.ru/cgi-bin/dn/e_033_06_1083.pdf).

The geometric programme makes a concrete connection here. The 600-cell is a regular discretization on S³, with 120 vertices corresponding to the binary icosahedral group. A fresh calculation of its nearest-neighbor graph Laplacian gives the first six multiplicities **1, 4, 9, 16, 25, 36**. The remaining bands are 9, 16 and 4: the finite lattice has a real cutoff. Relating OPH's observer screen and phase transport to the relevant nontrivial Hopf bundle is an additional physical/model identification. A sphere plus arbitrary circles does not automatically select that bundle.

**Screening supplies an ordering mechanism.** The Demkov–Ostrovsky focusing family is an analytically tractable model of how radial structure changes shell onset. In our normalization, its zero-energy coupling thresholds are ordered by

`λ = nᵣ + (2ℓ+1)/μ`, with `nᵣ = n−ℓ−1`.

For a fixed μ, increasing λ increases the required well strength. Here μ is twice the parameter used in the original 1972 paper. The dimensionless radial shape is `r²|V| ∝ x^μ/(1+x^μ)²`, with `x=r/R`.

At μ=1, `λ=n+ℓ`: subshells with equal n+ℓ share a threshold. Just above 1, larger ℓ lowers λ more strongly; within a tied group that means smaller n goes first. An exact rational comparison gives **1<μ<6/5** for the familiar first 19 subshells through 7p. At μ=6/5, 6s crosses 4f and 7s crosses 5f. The result explains the nominal filling sequence through a radial mechanism. These are thresholds of the specified potential; neutral-atom configurations and their exceptions also depend on many-electron interactions. [Demkov and Ostrovskii (1972)](https://jetp.ras.ru/cgi-bin/dn/e_035_01_0066.pdf).

**The doubled rows then follow by counting.** For a diagonal `N=n+ℓ`, the allowed angular values are `ℓ=0,…,floor((N−1)/2)`. Its capacity is therefore `2 ceil(N/2)²`, giving **2, 2, 8, 8, 18, 18, 32, 32**. These are diagonal/left-step capacities. Conventional table periods are **2, 8, 8, 18, 18, 32, 32**, grouped with a different row boundary. Principal-shell capacities, diagonal capacities and conventional period lengths should not share a label.

**Reproducible calculation.** The [check script](https://github.com/Osika-Innovation/replicator/blob/main/tools/check_physics_derivations.py) independently constructs the 600-cell graph, counts the shells and uses exact rational inequalities to find the strict ordering interval. Its [result record](../assets/physics/atomic-structure-check.json) contains the counts and a failing comparison just beyond μ=6/5. These checks establish the stated mathematics; atomic spectra and material response remain separate comparison targets.

## Quartz and the cymatics question

Quartz connects composition, crystal symmetry and a useful electrical–mechanical response. Its atomic structure, lattice vibrations and the resonances of a cut component are three different levels of description. The [materials chapter](materials.html#quartz-and-the-cymatics-question) explains how these connect to crystal growth and the idea of field-guided assembly.

## From atomic structure to the twin

The next connection is quantitative: an electronic energy model gives bonding forces; derivatives of that energy give crystal force constants and elastic properties. Those properties enter the acoustic body model. The [atoms-to-hardware derivation](physics-to-hardware.html) follows this chain through to a manufacturing task.

### Put the spectrum into the twin

Each material record should carry composition, phase, microstructure, temperature, density and the response relevant to the task, together with uncertainty and source. The module adds its geometry, supports and measured transfer response. Optimization then chooses operating frequency, amplitude, phase and timing against a useful outcome: force, position, heating, joining quality or a measured optical change.

For our first acoustic module, the decisive response is the coupled piezo–body–medium system and the feedstock's mechanical interaction with its field. Published holographic ultrasound experiments have assembled particles, cells and hydrogel beads into three-dimensional forms. They give us a concrete precedent for shaping and fixing material using wave fields; they do not establish atomic rearrangement or element conversion. [Melde et al., 2023](https://pmc.ncbi.nlm.nih.gov/articles/PMC9908023/)


Read [Light, fields and matter](light-matter.html), [Materials and modes](materials.html), [Acoustics](acoustics.html) and [Digital twin](digital-twin.html).
