# Electromagnetic and optical modules

Select fields by the interaction they provide with the chosen material. A coil shape, optical pattern or patent becomes useful when it solves a defined task with an acceptable power, thermal and manufacturing budget.

## Electromagnetic control

Evaluate the field where the material actually sits, then calculate force, heating and motion for that material. Coil topology, return paths, standoff, shielding, permeability and frequency determine the result.

A toroidal winding can concentrate flux within its own magnetic path. That is valuable for some functions; it does not establish useful control throughout a distant chamber. Optimize coil geometry against the payload and process, rather than preserving a shape for its name.

Candidate applications include contactless resonance measurement, transport of a suitable feedstock and localized heating. Each needs its own model and physical qualification.

## Current integration direction

The engineering EM study has evaluated the RH-1 windings and several closer-coupled alternatives. Its November 13 second pass recommends keeping an EM manufacturing module out of the initial acoustic build. It proposes contactless excitation/measurement of an acoustic disc as an instrument candidate.

These are branch-study recommendations, not a change already integrated into the published twin. The [current-state page](status.html) records that distinction. Future material and process choices can reopen the integration decision.

## Optical modules

Optics can support observation, phase measurement, patterned exposure and selected material processes. The useful route depends on wavelength, absorption, numerical aperture, power, thermal history and the required feature quality.

Passive optical structures and optical computation are longer-term upgrade candidates. Their fabrication requirements include material composition, index contrast, loss, surface quality, alignment and inspection. Shape alone is not the complete specification.

## A shared software boundary

Represent each module with typed ports, geometry, material laws, frequency response, operating limits and measurement records. Acoustic and optical solvers can share this infrastructure while retaining their distinct equations and validity ranges.

A forward-propagation optical model is appropriate for the structures it resolves. Extending it to a resonant cavity requires the relevant feedback, boundary and loss model.

Read [Materials and modes](materials.html), [Digital twin](digital-twin.html) and [Research library](research.html).
