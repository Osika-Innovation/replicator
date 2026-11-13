# Architecture

The Replicator coordinates acoustic, electric, magnetic and optical fields in one shared three-dimensional work volume. CAD, simulation, calibration and machine execution use the same coordinates, material state and revision records. The long-term capability comes from designing these interactions together around a complete manufacturing process.

<div class="diagram">
<svg viewBox="0 0 880 550" role="group" aria-labelledby="architecture-title architecture-desc" xmlns="http://www.w3.org/2000/svg">
<title id="architecture-title">Coordinated fields in one Replicator work volume</title>
<desc id="architecture-desc">The twin and planner command coordinated control and power for acoustic, electric and magnetic, and optical modules. All three act in one shared work volume where material is arranged, oriented, joined and inspected. Feedstock enters that volume, measurements return to the twin, and frame, metrology and utilities support the process.</desc>
<defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8" fill="#186b60"/></marker></defs>
<rect x="205" y="300" width="650" height="125" rx="12" fill="#e2ede5" stroke="#186b60" stroke-width="1.5"/>
<g fill="#f2f5ef" stroke="#186b60" stroke-width="1.5">
<a href="digital-twin.html" aria-label="Digital twin and planner"><rect x="220" y="20" width="440" height="62" rx="9"/></a>
<a href="digital-twin.html#one-work-volume-and-material-state" aria-label="Coordinated control and power"><rect x="250" y="110" width="380" height="54" rx="9"/></a>
<a href="acoustics.html" aria-label="Acoustic fields"><rect x="145" y="205" width="190" height="58" rx="9"/></a>
<a href="electromagnetics.html" aria-label="Electric and magnetic fields"><rect x="355" y="205" width="190" height="58" rx="9"/></a>
<a href="electromagnetics.html#optical-modules" aria-label="Optical fields"><rect x="565" y="205" width="190" height="58" rx="9"/></a>
<a href="manufacturing.html" aria-label="Feedstock"><rect x="20" y="345" width="165" height="60" rx="9"/></a>
<a href="manufacturing.html#a-candidate-combined-field-recipe" aria-label="Arrange and orient material"><rect x="220" y="345" width="190" height="60" rx="9"/></a>
<a href="manufacturing.html" aria-label="Join and transform material"><rect x="435" y="345" width="190" height="60" rx="9"/></a>
<a href="manufacturing.html" aria-label="Observe and inspect material"><rect x="650" y="345" width="190" height="60" rx="9"/></a>
<a href="architecture.html#interfaces-that-survive-upgrades" aria-label="Frame, metrology and utilities"><rect x="220" y="475" width="635" height="58" rx="9"/></a>
</g>
<g pointer-events="none" fill="#173630" font-family="system-ui,sans-serif" text-anchor="middle" font-size="17">
<text x="440" y="47">Digital twin + planner</text><text x="440" y="69" font-size="13">CAD · coupled models · recipes · upgrade graph</text>
<text x="440" y="143">Coordinated control + power</text>
<text x="240" y="240">Acoustic fields</text><text x="450" y="240">Electric + magnetic</text><text x="660" y="240">Optical fields</text>
<text x="530" y="326" font-size="16" font-weight="600">ONE SHARED 3D WORK VOLUME</text>
<text x="102" y="370">Feedstock</text><text x="102" y="392" font-size="13">supply + collection</text>
<text x="315" y="370">Arrange + orient</text><text x="315" y="392" font-size="13">position + microstructure</text>
<text x="530" y="370">Join + transform</text><text x="530" y="392" font-size="13">material-specific process</text>
<text x="745" y="370">Observe + inspect</text><text x="745" y="392" font-size="13">feedback + part acceptance</text>
<text x="537" y="500">Frame, metrology and utilities</text><text x="537" y="522" font-size="13">shared datums · access · sensors · cooling · protection</text>
</g>
<g fill="none" stroke="#186b60" stroke-width="2" marker-end="url(#arrow)">
<path d="M440 82 V110"/>
<path d="M440 164 V184 H240 V205"/><path d="M440 184 H450 V205"/><path d="M450 184 H660 V205"/>
<path d="M240 263 V300"/><path d="M450 263 V300"/><path d="M660 263 V300"/>
<path d="M185 375 H220"/><path d="M410 375 H435"/><path d="M625 375 H650"/>
<path d="M855 360 H868 V51 H660"/><path d="M537 475 V425"/>
</g>
<text x="780" y="105" fill="#186b60" font-family="system-ui,sans-serif" font-size="13" text-anchor="middle">measurements</text>
</svg>
</div>

The process stages share one work volume. A recipe can overlap or sequence them; the diagram does not require separate stations or every field to be active continuously.

## One work volume, coordinated fields

Design the fields around their combined action on the same material. Acoustic forces can arrange feedstock; electric or magnetic interactions can add material-selective forces, torques or heating; optical fields can provide observation, exposure and localized energy delivery. The selected material, medium and process determine which combinations work together. Optics is electromagnetic physics; the separate module names distinguish operating bands and hardware.

A candidate recipe combines particle arrangement, magnetic orientation and optical curing to make a composite with controlled shape and internal structure. Its [manufacturing study](manufacturing.html#a-candidate-combined-field-recipe) defines the physical couplings and acceptance checks. This is the intended path toward broader material control and greater autonomy: successive recipes turn coordinated fields into useful parts.

The twin shares coordinates, timing, sensor calibration and material state across the modules. It models cross-effects where they matter: heating changes viscosity and acoustic response, orientation changes material properties, and curing changes mobility. Optimize part quality, resolution, throughput, energy and human effort against the best simpler recipe. Common timing does not imply phase coherence between unrelated acoustic and optical carriers.

## Subsystems and ownership

| Subsystem | Responsibility | Interface delivered |
|---|---|---|
| Acoustic bodies | Convert a few electrical inputs into useful fields in the shared volume | Geometry, frequency response, drive limits, uncertainty and calibration points |
| Electric and magnetic fields | Apply material-dependent forces, torques, excitation or heating | Field maps, material coupling, access, limits and calibration |
| Optical fields | Supply observation, patterned exposure and selected material processing | Optical access, wavelength/dose, resolution, material coupling and calibration |
| Control and power | Coordinate waveforms, acquisition and process sequences | Channel map, timing, voltage/current limits and job records |
| Metrology | Observe fields, material and process quality | Raw measurements, shared coordinates, calibration, reconstruction and uncertainty |
| Feed and consolidation | Supply and permanently join the selected material | Process recipe, material/energy budget and inspection criteria |
| Frame and utilities | Preserve alignment and operating conditions | Datums, mounts, access, cooling and replaceable connections |
| Twin and planner | Co-design modules and their combined action; simulate, compile and compare jobs | Versioned module records, coupled material state, programs, receipts and upgrade dependencies |

## The acoustic candidate

Two opposed bodies provide a compact acoustic starting point within this architecture. Geometry is optimized with the source and its mounting: preload, contact, structural modes, radiation and temperature all affect the useful response. The current starting hypothesis is three inputs per body.

At one frequency in a linear model, six inputs span at most six independent complex field patterns. Geometry can make those patterns useful for the chosen task. Frequency and time provide additional choices within bandwidth, settling and motion constraints.

## Interfaces that survive upgrades

Every module carries its identity and revision, units, coordinate frame, mechanical mates, typed signal/power ports, limits, material description and response provenance. A job also records the calibration and module revisions it used. Preserve optical sightlines, field access and calibrated mounting references as the acoustic bodies and process cartridges evolve.

Keep desired object state, measured response and executable manufacturing program distinct. A shared representation links them through explicit transformations.

## First build and later modules

The first configuration needs an acoustic module, drive/acquisition, metrology, a frame and a selected feed/joining process. Its recipe selects which electric/magnetic and optical capabilities are installed initially. It does not inherit every subsystem in the large RH-1 concept.

The November 13 EM branch recommendation concerns that starting configuration. It does not remove electromagnetic processing from the ultimate architecture. Integration work should preserve the shared volume and define the next combined-field recipe that improves an inspected part.

Read [Acoustics](acoustics.html), [Electromagnetics](electromagnetics.html), [Manufacturing](manufacturing.html) and [Digital twin](digital-twin.html).
