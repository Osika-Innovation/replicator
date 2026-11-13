# From fields to manufactured parts

A manufacturing capability is a reproducible transformation from supplied material to an inspected part. The complete recipe includes feed, motion, capture, joining, finishing where required and verification.

## Select the first useful part

Choose the first upgrade and its material together. Candidate classes include a calibration feature, feed guide, fixture or field-shaping insert. Rank them by the bottleneck removed and the human effort needed to make and qualify them.

The part specification names its geometry, material state, required tolerance, function, manufacturing route and acceptance test. A simple part with a measured benefit is the first complete upgrade cycle.

## The process chain

| Stage | Required answer |
|---|---|
| Supply | What feedstock, quantity, size distribution and delivery method enter the work region? |
| Arrange | Which fields and surfaces move and capture it, with what position and force margin? |
| Join | What physical mechanism forms permanent bonds, with what dose, temperature or pressure? |
| Stabilize | What shrinkage, cooling, cure or finishing occurs before inspection? |
| Inspect | Which observations establish geometry, bond quality and useful function? |
| Upgrade | What improves when the part replaces or augments the previous module? |

A field pattern is one input to this process. The material's evolving position, contact, temperature and history determine the outcome.

## A candidate combined-field recipe

Evaluate a composite process in one shared work volume: acoustic forces arrange particles in a liquid feedstock, magnetic fields orient suitable anisotropic inclusions, and patterned light cures a compatible matrix while imaging tracks the arrangement. The intended output has both a designed outer shape and a designed internal orientation. Actions may overlap or be sequenced as the material requires.

Two parts of this route have experimental precedents. Greenhall and Raeymaekers combined ultrasound-directed particle assembly with stereolithography to make layered composites, including patterns of conductive fibers. Nagarajan and colleagues integrated magnetic particle alignment with material jetting, UV curing and thermal post-curing. [Ultrasound and stereolithography](https://doi.org/10.1002/admt.201700122), [magnetic alignment and curing](https://pmc.ncbi.nlm.nih.gov/articles/PMC8433740/).

The three-field recipe is a candidate to evaluate, not an already qualified combination. Select one feedstock that supports the required acoustic contrast, magnetic torque and cure depth. Model whether streaming, heating, optical attenuation and shrinkage preserve the arrangement. Inspect the final part's geometry, orientation and useful response, then compare the benefit with a simpler recipe.

## Generate programs with designs

The design system can search directly over actuator programs and process sequences. This constrains proposals to the machine's available actions and exposes their cost early.

Executable commands still need outcome checks. The forward model must include the relevant material transition; the planner includes sensing, correction and recovery. Learned proposals are compared with direct optimization on the same task and constraints.

## Fabrication precision ladder

Each new process records feature size, dimensional error, surface quality, alignment, material variation and metrology uncertainty separately. Identify external masters or seed processes explicitly.

Start with an achievable part. Use its improvement to qualify the next process. An upgrade must not require the precision it is supposed to introduce.

## Recover material

Recovery is a separate process design: identify the bonds or phases to separate, the energy source, collection, contamination and purity criteria. Wave focusing can deliver energy selectively. Reversing a drive phase does not itself reverse bonding or sort mixed materials.

Read [Upgrade loop](upgrades.html), [Materials](materials.html) and [Material recovery paper](../papers/replicator_dissolve.html).
