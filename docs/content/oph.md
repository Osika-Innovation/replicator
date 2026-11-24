# Observer Patch Holography

Etherworks adopts Observer Patch Holography (OPH) as a research framework for finding simple, shared structure beneath fields, matter, measurement and computation. Its value to the Replicator programme is an engineering question: how much behaviour can we obtain from geometry, local interactions and feedback, with fewer independently controlled parts?

## The central idea

OPH starts with observers that have limited access to a world. They make measurements, retain records and compare what they can observe across shared boundaries. A description becomes shared when those comparisons agree. The framework seeks to recover familiar physics from the structure and dynamics of that agreement.

The current programme places this inside a closure hypothesis: observers recover an account of their world and construct a realization that reproduces the same observable history. The hypothesis is a mathematical research direction. Its universe-level fixed point and identification with our Universe remain questions to establish. The concrete implementation uses interacting twelve-port carriers, local repair operations, retained records and feedback. [OPH basis](https://github.com/FloatingPragma/observer-patch-holography/blob/main/docs/BASIS.md)

The theorem library calls its main premises A1, A2 and A3: an observer-screen architecture, agreement between observers, and state selection by conditional maximum randomness. These premises specify what the mathematical statements assume. A carrier's twelve ports are part of that formal construction; they do not prescribe the number of transducers required by our acoustic machine. [Premise reference](https://github.com/FloatingPragma/observer-patch-holography/blob/main/docs/AXIOM_REFERENCE.md)

## From carrier geometry to an interaction algebra

The formal programme contains a specific selection argument. A1 supplies a complete, faithful, compact, commutator-closed, twelve-dimensional response algebra. A2 requires the icosahedron's proper rotations to act through inner transformations of that response. Under these premises, the algebra is

    g ≅ u(1) ⊕ su(3) ⊕ su(2).

This is the Lie-algebra structure used by the Standard Model's gauge interactions. The result comes from the combination of geometry and response assumptions. It establishes algebraic structure; the physical currents, matter representation, global group and coupling strengths have further constructions. [Proof and classifier](https://github.com/FloatingPragma/observer-patch-holography/blob/4483a9ca4b736fa2ea7160d2ba44c2604e5f05f3/code/a5_closure/a5_compact_lie_classifier.py), [formal finite classification steps](https://github.com/FloatingPragma/observer-patch-holography/blob/4483a9ca4b736fa2ea7160d2ba44c2604e5f05f3/Lean/Screen/A5OPH.lean).

<details><summary>The selection argument in five steps</summary>
<p>The twelve-port rotation representation decomposes as 1 ⊕ 3 ⊕ 3′ ⊕ 5, leaving one invariant direction. Inner transformations fix the centre, so its dimension is at most one. A zero-dimensional centre would force four su(2) factors under the stated compact-algebra classification. Their inner rotation action has an invariant-space dimension divisible by three, contradicting one. The centre therefore has dimension one; the remaining eleven dimensions split as eight plus three, giving su(3) ⊕ su(2).</p>
</details>

## From consistent probabilities to quantum dynamics

Two further results make the language operational. A normalized, nonnegative assignment defined on all effects of a finite complex matrix algebra, additive whenever E, F and E+F are effects, has the Born form `p(E) = Tr(ρE)` for a positive unit-trace state ρ. The library's theorem `isEffectValuation_iff_born` formalizes this representation. Its assumptions specify the measurement structure; they are part of the result. [Finite Born representation](https://github.com/FloatingPragma/observer-patch-holography/blob/4483a9ca4b736fa2ea7160d2ba44c2604e5f05f3/Lean/EventAlgebra/FiniteBuschGleason.lean).

For a continuous one-parameter group of star-automorphisms on a full finite complex matrix algebra, `finiteStoneConverse_of_continuous` supplies a self-adjoint Hamiltonian generator. In physical units its unitary evolution is `U(t) = exp(−iHt/ℏ)`, with H defined up to a scalar energy offset. This gives the form of dynamics. Material-specific interactions determine the actual H. [Hamiltonian generator theorem](https://github.com/FloatingPragma/observer-patch-holography/blob/4483a9ca4b736fa2ea7160d2ba44c2604e5f05f3/Lean/Dynamics/StoneConverse.lean).

## The field-to-atom connection

The upstream repository also develops a separate electrostatic model that makes the field-to-atom step explicit. Connecting it to the physical currents selected by the gauge construction is a further task. Let D map edge fields to vertex charge and let `L = DDᵀ`. For neutral charge ρ, minimize quadratic field energy subject to Gauss's constraint `DE = ρ`. With the constant mode removed, `G = L⁺` is the Green operator and

    E* = DᵀGρ,
    Wmin = (g²/2) ρᵀGρ.

Every other allowed field adds a divergence-free component orthogonal to E*, increasing the quadratic energy. The interaction therefore comes from the inverse geometric operator. [Finite Gauss/Green derivation](https://github.com/FloatingPragma/observer-patch-holography/blob/4483a9ca4b736fa2ea7160d2ba44c2604e5f05f3/model/coherent_defect_wave/chiral_joint/interacting_charge_localization/COULOMB.md).

For the atomic comparison, the construction uses a finite cubic box with zero boundary values, a central charge and nonrelativistic kinetic energy. In its unscaled-stencil convention,

    Hₐ = L₀/(2ma²) − (g²/a) G_D(·,0),
    m = 1,  g² = 4π.

Here a is grid spacing, L₀ is the unscaled Dirichlet Laplacian and G_D its inverse kernel. The attractive potential is computed from the field operator rather than supplied as samples of −1/r. [Hamiltonian construction](https://github.com/FloatingPragma/observer-patch-holography/blob/4483a9ca4b736fa2ea7160d2ba44c2604e5f05f3/model/openwave_field_observables/PROOF.md).

At fixed box length 24 in model units, the published calculation gives:

| Grid spacing | Ground-to-lowest-odd energy gap |
|---|---:|
| 1/3 | 0.420953 |
| 1/4 | 0.399139 |
| 3/16 | 0.388152 |
| 0.15 | 0.383408 |
| Hydrogenic comparison in these units | 0.375000 |

The finest value is about 2.24% above the comparison. The same refinement reduces the second-shell cubic splitting from 0.00550045 to 0.00041065. These are upstream numerical results, reviewed here at revision `4483a9c`; this handbook update did not rerun the large calculation. Successive-grid differences are convergence diagnostics, not certified continuum error bounds. [Atomic result record](https://github.com/FloatingPragma/observer-patch-holography/blob/4483a9ca4b736fa2ea7160d2ba44c2604e5f05f3/model/openwave_atomic_refinement/results.json), [domain comparison and refinement proof](https://github.com/FloatingPragma/observer-patch-holography/blob/4483a9ca4b736fa2ea7160d2ba44c2604e5f05f3/model/openwave_atomic_refinement/PROOF.md).

This is a concrete route from a field construction to atomic bound states. The model supplies its charge, mass, coupling and kinetic law. Extending the route to the periodic table adds many-electron antisymmetry, electron–electron interactions, exchange/correlation and physical nuclei. The [periodic-table chapter](periodic-table.html#deriving-the-shell-structure) develops the shell-counting and screening calculations. The [hardware chapter](physics-to-hardware.html) takes electronic structure through bonding and material response to a driven machine.

## The scope of the chain

These constructions make OPH useful to inspect at the level of operators and predictions. Their physical identification is tested link by link. Upstream does not yet establish agreement with every observed measurement statistic; that statement leaves the specific algebraic, field and atomic results above intact. [Current programme](https://github.com/FloatingPragma/observer-patch-holography).

## How it informs the machine

Our engineering interpretation is to put interactions and observable behaviour at the centre of the design. The following choices are programme decisions inspired by that perspective, not theorems about the Replicator.

| Idea | Engineering use |
|---|---|
| Describe an object through its accessible interfaces | Give every twin module defined mechanical, electrical, acoustic and measurement ports. |
| Let geometry carry useful structure | Co-design the source and elastic body so a few drives generate the field patterns a task needs. |
| Resolve disagreement through local feedback | Compare predictions with calibrated measurements and update the response model. |
| Preserve records across changes | Bind every experiment to geometry, material, instrument, calibration and software revisions. |
| Use the simplest model that retains the required observations | Search with reduced models, then test shortlisted designs against higher-resolution models and physical measurements. |

This produces a concrete loop: choose a manufacturing task, derive the required forces and material response, optimize a realizable module, measure it, and keep the improvement that passes. OPH can suggest a better representation or mechanism. Measured response functions, energy balances and manufacturing tolerances determine whether that suggestion belongs in the machine.

The next chapters connect this perspective to periodic structure, material spectra and resonant control. They keep atomic transitions, lattice vibrations and whole-component resonances distinct, so that a useful musical analogy becomes a quantitative design method.

Read [Physics overview](physics.html), [Light, fields and matter](light-matter.html), [Periodic table and tones](periodic-table.html) and [Digital twin](digital-twin.html).
