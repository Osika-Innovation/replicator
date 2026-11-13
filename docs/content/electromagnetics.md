# Electromagnetic control

This subsystem owns electric and magnetic forces, torques, induction, pulsed-field interactions and RF/microwave launch and sensing. It coordinates with [acoustic bodies](acoustics.html) and the separately owned [optics and metamaterials subsystem](optics.html) in one shared three-dimensional work volume.

Design the field at the material and the material's response together. The required outputs are a useful force, orientation, flow, temperature or observation, together with the power and timing needed to produce it.

## Levitation, heating and material shaping

Electromagnetic fields already provide a practical route to containerless processing of conductive material. The ESA/DLR electromagnetic levitator uses coil-generated fields to position and heat samples, including melting and solidification. This gives the programme a concrete starting point for investigating controlled melt processing. [ESA facility](https://www.esa.int/Science_Exploration/Human_and_Robotic_Exploration/International_Space_Station/Material_Science_Laboratory_Electromagnetic_Levitator_MSL-EML).

For a conducting fluid, the Lorentz-force density includes `J × B`; the current distribution also determines resistive heating. The coupled model needs conductivity, induced currents, field gradients, flow, surface tension and thermal history. Magnetic or dielectric particles have their own force and torque laws. Coil topology, return paths, standoff and frequency determine how effectively the source reaches the work volume.

Treat “soft molding” as a process question: what changes the material's flow or yield behavior, what stress shapes it, and what fixes the final shape? Distinguish heating/melting, mechanical deformation and any proposed change in constitutive behavior. Record temperature, strain and the final part's properties so the mechanism can be identified.

## Toroidal and pulsed fields

The existing [photon mechanism paper](../papers/replicator_photons.html#s2) includes spiral launchers, structured pulses, spectral addressing and position sensing. Preserve that design work while selecting the mechanism for a particular task.

| Concept | What is specified | Engineering question |
|---|---|---|
| Toroidal coil or magnetic circuit | Source geometry, winding and return path | What external field, gradient and force reach the material? |
| Rotating or vortex-like field pattern | Vector field in space and time | What currents, torques, flow and heating does it produce in the selected material? |
| Toroidal electromagnetic pulse | A space–time structured propagating field | What source, bandwidth and detector generate and resolve the required waveform? |
| Proposed gravito-magnetic effect | An additional claimed force or coupling | What quantitative prediction distinguishes it from electromagnetic and mechanical forces? |

A toroidal winding can concentrate flux inside its magnetic path. A propagating toroidal pulse is a different field solution. Wang and colleagues demonstrated toroidal-pulse-based positioning at microwave frequencies; Zdagkas and colleagues demonstrated optical/THz pulse generation. These establish specific launch and sensing results, with their own apparatus and bands. [Microwave positioning](https://doi.org/10.1038/s42005-024-01850-z), [optical/THz pulses](https://doi.org/10.1038/s41566-022-01028-5).

For a pulsed-field candidate, record the measured current waveform, spatial field map, induced-current distribution, force/torque, thermal response and energy per operation. Compare the useful response with a simpler drive and geometry. Pulse rise time or a vortex-shaped field alone does not specify its material effect.

## Patent-led and exploratory mechanisms

Retain named patent mechanisms as research leads with their exact publication number, claimed effect and next discriminating observation. A patent's description supplies a proposed apparatus; its performance requires experimental evidence. Keep documented electromagnetic levitation and processing, structured-wave demonstrations and proposed gravity-related effects as separately testable mechanisms.

John St. Clair's applications are retained as specific research leads:

| Primary source | Claimed connection to investigate |
|---|---|
| [Magnetic vortex wormhole generator, US20030197093A1](https://patents.google.com/patent/US20030197093A1/en) | Proposed lift/mass effects; claim 6 also describes crystal joining through its proposed mechanism |
| [Water energy generator, US20060180473A1](https://patents.google.com/patent/US20060180473A1/en) | Its description connects a rotating magnetic vortex to proposed material softening; the identity of that separately named device remains to resolve |
| [Full body teleportation system, US20060071122A1](https://patents.google.com/patent/US20060071122A1/en) | A related proposed vortex/waveguide mechanism; retained for source traceability |

The reviewed texts establish what the inventor proposed, without calibrated measurements establishing those effects. For material-softening research, measure stress–strain or flow behavior at matched temperature and thermal history. For a proposed additional force, specify its predicted magnitude and scaling and separate it from ordinary electromagnetic forces, airflow, vibration, cable forces and measurement interference.

Graviflyer replication reports are another retained lead. An organizer-hosted account of Jarod Yates's 2024 experiments reports horizontal deflection while sustained vertical lift remained unachieved. It documents that particular attempt, not the outcome of every reported replication. A successful gravitational interpretation requires the corresponding force record and controls; this account alone does not establish it. [Replication account](https://www.altsci.net/graviflyer-replication-experiments/).

The research register preserves source identities and review status. Private laboratory reports stay outside public capability claims. An exploratory result becomes part of a process model when its observable, controls and uncertainty support that use.

## Current integration direction

The engineering EM study evaluated the RH-1 windings and closer-coupled alternatives. Its November 13 second pass recommends keeping an EM manufacturing module out of the initial acoustic build and proposes contactless excitation/measurement of an acoustic disc as an instrument candidate.

That recommendation concerns the initial hardware configuration. The ultimate architecture includes coordinated electromagnetic processing and optical metamaterials. The first material recipe selects the starting combination; later modules expand it. These branch-study recommendations retain their [current-state status](status.html).

## Twin and integration contract

Deliver typed ports, geometry, constitutive laws, field maps, frequency/transient response, current and voltage limits, thermal limits and calibration records. Register actuators and sensors to the same work-volume coordinates as acoustics and optics. Couple the solvers through material position, orientation, temperature, flow and process state where those affect the job.

Common process timing permits simultaneous or deliberately sequenced actions. Phase coherence is included where the actual interaction needs it. Compare a combined recipe with its best simpler baseline on the finished part, power, throughput and human effort.

## Optical modules

The optical-wavelength programme now has its own [Optics and optical metamaterials](optics.html) chapter, covering holographic ports, metasurfaces, optical toroidal pulses, fabrication and readout. This link preserves the former combined chapter's entry point.

Read [Architecture](architecture.html), [Manufacturing](manufacturing.html), [Optics](optics.html) and [Research library](research.html).
