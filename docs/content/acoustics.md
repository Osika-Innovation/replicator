# Acoustic bodies

Use geometry to obtain useful acoustic control with few electrical channels. The leading candidate is a coupled piezoelectric source and an optimized elastic body, with two bodies facing the work volume.

## Co-design the source and the body

The design variables include actuator location, front-body shape, supports, contact, radiating regions, gap, operating frequencies and drive sequence. Folded paths, ribs, local resonators and lattices are available tools. Compare them with simple solid bodies and separate horns.

A Langevin transducer's reaction mass and preload belong to its resonant structure. Start with intact preloaded cartridges and co-design their coupling to the custom body. An integrated replacement is a new transducer design with its own impedance, stress and thermal requirements.

## Optimize the manufacturing task

Score reachable positions, force and stiffness margin, unwanted traps, settling time, electrical power, temperature, fatigue and tolerance sensitivity. A high surface amplitude or a large mode count alone does not demonstrate control of the material.

Compare candidates on the same payload, work volume, trajectory, power limits and disturbance envelope. Retain failed cases: they identify the change that could remove the bottleneck.

## Response as the handover

For a linear operating regime, write the field as **p(f) = H(f)u(f)**. The response connects the input drives to the observable field or radiating surface. It belongs to a specific geometry, mounting, medium and operating state.

The engineering body-response contract separates physical input channels from sampled radiating patches. A thousand patches do not become a thousand independent controls. Multitone operation also needs loaded source response, amplifier limits and transients.

## Compute and measurement

Use reduced models for broad search and independent structural/acoustic models for finalists. When the models disagree about the best design, identify the missing coupling or measurement before expanding the same sweep.

The reusable calibration fixture should measure source impedance, resonance and damping, mounting repeatability and spatial response. Feed those observations back into the model with uncertainty.

## First useful output

The first manipulation gate is repeatable hold, move and release. The manufacturing gate additionally requires controlled feed, joining and inspection. A replaceable field-shaping insert, fixture or feed component becomes an upgrade only when its measured effect improves the machine.

See [Manufacturing](manufacturing.html), [Materials](materials.html) and the acoustic papers in the [library](research.html).
