# Observer Patch Holography

Etherworks adopts Observer Patch Holography (OPH) as a research framework. It looks for simple shared structure beneath fields, matter, measurement and computation. Its value to the Replicator is one engineering question: how much behaviour can we get from shape, local interactions and feedback, with fewer independently controlled parts?

## The central idea

OPH starts with observers that each see only part of a world. They measure, keep records and compare what they observe across shared boundaries. A description becomes shared when those comparisons agree. The framework tries to recover familiar physics from that agreement.

The programme places this inside a closure hypothesis: observers recover an account of their world and build a realization that reproduces the same observable history. It is a direction for mathematical research. Still to be established: its fixed point at the level of a universe, and its identification with our Universe. The implementation uses interacting twelve-port carriers, local repair operations, kept records and feedback. [OPH basis](https://github.com/FloatingPragma/observer-patch-holography/blob/main/docs/BASIS.md)

The theorem library's main premises are:

- **A1:** an observer-screen architecture.
- **A2:** agreement between observers.
- **A3:** state selection by conditional maximum randomness.

These premises say what the mathematical statements assume. A carrier's twelve ports are part of that construction. They do not set the number of transducers our machine needs. [Premise reference](https://github.com/FloatingPragma/observer-patch-holography/blob/main/docs/AXIOM_REFERENCE.md)

## From carrier geometry to an interaction algebra

A1 supplies a twelve-dimensional response algebra that is complete, faithful, compact and closed under commutators. A2 requires the proper rotations of the icosahedron to act through inner transformations of that response. The algebra is then

    g ≅ u(1) ⊕ su(3) ⊕ su(2).

This is the Lie-algebra structure used by the gauge interactions of the Standard Model, the established theory of particles and forces. The result combines the geometry with the response assumptions. It establishes algebraic structure only. The physical currents, matter representation, global group and coupling strengths each need further constructions. [Proof and classifier](https://github.com/FloatingPragma/observer-patch-holography/blob/4483a9ca4b736fa2ea7160d2ba44c2604e5f05f3/code/a5_closure/a5_compact_lie_classifier.py), [formal finite classification steps](https://github.com/FloatingPragma/observer-patch-holography/blob/4483a9ca4b736fa2ea7160d2ba44c2604e5f05f3/Lean/Screen/A5OPH.lean).

<details><summary>The selection argument in five steps</summary>
<p>The twelve-port rotation representation decomposes as 1 ⊕ 3 ⊕ 3′ ⊕ 5, leaving one invariant direction. Inner transformations fix the centre, so its dimension is at most one. A zero-dimensional centre would force four su(2) factors under the stated compact-algebra classification. Their inner rotation action has an invariant-space dimension divisible by three, contradicting one. The centre therefore has dimension one; the remaining eleven dimensions split as eight plus three, giving su(3) ⊕ su(2).</p>
</details>

## From consistent probabilities to quantum dynamics

**Probabilities.** Take a finite complex matrix algebra. Its effects are the possible yes-or-no measurement outcomes. Give each effect a number that is normalized, never negative, and additive whenever E, F and E+F are all effects. The assignment then has the Born form `p(E) = Tr(ρE)` for a positive state ρ with unit trace, the standard quantum rule for probabilities. The library's theorem `isEffectValuation_iff_born` formalizes this. Its assumptions specify the measurement structure and are part of the result. [Finite Born representation](https://github.com/FloatingPragma/observer-patch-holography/blob/4483a9ca4b736fa2ea7160d2ba44c2604e5f05f3/Lean/EventAlgebra/FiniteBuschGleason.lean).

**Dynamics.** Take a continuous one-parameter group of star-automorphisms on a full finite complex matrix algebra: a smooth change in time that preserves the algebra's structure. For it, `finiteStoneConverse_of_continuous` supplies a self-adjoint Hamiltonian generator H, the energy operator. In physical units its unitary evolution is `U(t) = exp(−iHt/ℏ)`, with H defined up to a constant energy offset. This gives the form of the dynamics. Material-specific interactions set the actual H. [Hamiltonian generator theorem](https://github.com/FloatingPragma/observer-patch-holography/blob/4483a9ca4b736fa2ea7160d2ba44c2604e5f05f3/Lean/Dynamics/StoneConverse.lean).

## The field-to-atom connection

Upstream also develops a separate electrostatic model that makes the step from field to atom explicit. Connecting it to the physical currents selected by the gauge construction is a further task.

On a grid, let D map fields on the edges to charge at the vertices, and let `L = DDᵀ`. For a neutral charge distribution ρ, find the field of least quadratic energy that obeys Gauss's constraint `DE = ρ`. With the constant mode removed, `G = L⁺` is the Green operator and

    E* = DᵀGρ,
    Wmin = (g²/2) ρᵀGρ.

Every other allowed field adds a divergence-free part orthogonal to E*, which raises the energy. The interaction therefore comes from the inverse of the geometric operator. [Finite Gauss/Green derivation](https://github.com/FloatingPragma/observer-patch-holography/blob/4483a9ca4b736fa2ea7160d2ba44c2604e5f05f3/model/coherent_defect_wave/chiral_joint/interacting_charge_localization/COULOMB.md).

The atomic comparison uses a finite cubic box with zero boundary values, a central charge and nonrelativistic kinetic energy. In its unscaled-stencil convention,

    Hₐ = L₀/(2ma²) − (g²/a) G_D(·,0),
    m = 1,  g² = 4π.

Here a is the grid spacing, L₀ is the unscaled Dirichlet Laplacian and G_D is its inverse kernel. The attractive potential is computed from the field operator, not put in by hand as samples of −1/r. [Hamiltonian construction](https://github.com/FloatingPragma/observer-patch-holography/blob/4483a9ca4b736fa2ea7160d2ba44c2604e5f05f3/model/openwave_field_observables/PROOF.md).

At a box length of 24 model units, the published calculation gives:

| Grid spacing | Ground-to-lowest-odd energy gap |
|---|---:|
| 1/3 | 0.420953 |
| 1/4 | 0.399139 |
| 3/16 | 0.388152 |
| 0.15 | 0.383408 |
| Hydrogenic comparison in these units | 0.375000 |

The finest value is about 2.24% above the comparison. The refinement also reduces the second-shell cubic splitting from 0.00550045 to 0.00041065. These are upstream numerical results, reviewed at revision `4483a9c` and not rerun here. The differences between successive grids show the trend of convergence. They are not certified error bounds for the continuum limit. [Atomic result record](https://github.com/FloatingPragma/observer-patch-holography/blob/4483a9ca4b736fa2ea7160d2ba44c2604e5f05f3/model/openwave_atomic_refinement/results.json), [domain comparison and refinement proof](https://github.com/FloatingPragma/observer-patch-holography/blob/4483a9ca4b736fa2ea7160d2ba44c2604e5f05f3/model/openwave_atomic_refinement/PROOF.md).

This is a route from a field construction to atomic bound states. The model supplies its own charge, mass, coupling and kinetic law. Extending it to the periodic table adds many-electron antisymmetry, electron–electron interactions, exchange and correlation, and physical nuclei. The [periodic-table chapter](periodic-table.html#deriving-the-shell-structure) develops shell counting and screening. The [hardware chapter](physics-to-hardware.html) continues through bonding and material response to a driven machine.

## The scope of the chain

These constructions let OPH be inspected as operators and predictions. Their physical identification is tested link by link. Upstream does not yet establish agreement with every observed measurement statistic. The specific algebraic, field and atomic results above stand regardless. [Current programme](https://github.com/FloatingPragma/observer-patch-holography).

## How it informs the machine

The choices below are programme decisions inspired by OPH (Design decision). They are not theorems about the Replicator.

| Idea | Engineering use |
|---|---|
| Describe an object through its accessible interfaces | Give every [twin](digital-twin.html) module defined mechanical, electrical, acoustic and measurement ports. |
| Let geometry carry structure | Co-design source and elastic body so a few drives make the field patterns a task needs. |
| Resolve disagreement by local feedback | Compare predictions with calibrated measurements and update the response model. |
| Preserve records across changes | Bind every experiment to geometry, material, instrument, calibration and software revisions. |
| Use the simplest model that keeps the required observations | Search with reduced models, then test shortlisted designs against finer models and measurements. |

The loop: choose a manufacturing task, derive the required forces and material response, optimize a buildable module, measure it, and keep the improvement that passes. OPH can suggest a mechanism. Measured responses, energy balances and manufacturing tolerances decide whether it belongs in the machine. [The upgrade loop](upgrades.html) runs this cycle.

The next chapters keep atomic transitions, lattice vibrations and whole-component resonances distinct, so a musical analogy becomes a quantitative method.

Read [Physics overview](physics.html), [Light, fields and matter](light-matter.html) and [Periodic table and tones](periodic-table.html).
