# Architecture

The machine is a set of cooperating functions built around one modular work volume. CAD, simulation, calibration and machine execution share identifiers, coordinates and revision records.

<div class="diagram">
<svg viewBox="0 0 880 440" role="group" aria-labelledby="architecture-title architecture-desc" xmlns="http://www.w3.org/2000/svg">
<title id="architecture-title">Replicator subsystem block diagram</title>
<desc id="architecture-desc">The twin and planner command control and power. Feed passes through field manipulation, joining and inspection to a useful upgrade. Sensors return measurements to the twin. The frame and utilities support every process.</desc>
<defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8" fill="#186b60"/></marker></defs>
<g fill="#f2f5ef" stroke="#186b60" stroke-width="1.5">
<a href="digital-twin.html" aria-label="Digital twin and planner"><rect x="230" y="20" width="420" height="62" rx="9"/></a><a href="digital-twin.html" aria-label="Control and power"><rect x="310" y="115" width="260" height="58" rx="9"/></a>
<a href="manufacturing.html" aria-label="Feedstock"><rect x="20" y="230" width="170" height="66" rx="9"/></a><a href="acoustics.html" aria-label="Acoustic manipulation"><rect x="230" y="230" width="195" height="66" rx="9"/></a><a href="manufacturing.html" aria-label="Consolidation"><rect x="465" y="230" width="170" height="66" rx="9"/></a><a href="manufacturing.html" aria-label="Inspection"><rect x="675" y="230" width="180" height="66" rx="9"/></a>
<a href="architecture.html#interfaces-that-survive-upgrades" aria-label="Frame and utilities"><rect x="230" y="355" width="625" height="58" rx="9"/></a>
</g>
<g pointer-events="none" fill="#173630" font-family="system-ui,sans-serif" text-anchor="middle" font-size="17">
<text x="440" y="47">Digital twin + planner</text><text x="440" y="69" font-size="13">CAD · models · recipes · upgrade graph</text>
<text x="440" y="150">Control + power</text>
<text x="105" y="259">Feedstock</text><text x="105" y="281" font-size="13">supply + collection</text>
<text x="327" y="259">Field manipulation</text><text x="327" y="281" font-size="13">acoustic bodies</text>
<text x="550" y="259">Consolidation</text><text x="550" y="281" font-size="13">material-specific joining</text>
<text x="765" y="259">Inspection</text><text x="765" y="281" font-size="13">qualified upgrade part</text>
<text x="542" y="380">Frame, metrology and utilities</text><text x="542" y="401" font-size="13">datums · sensors · temperature · cooling · protection</text>
</g>
<g fill="none" stroke="#186b60" stroke-width="2" marker-end="url(#arrow)">
<path d="M440 82 V115"/><path d="M440 173 V200 H327 V230"/><path d="M440 200 H550 V230"/>
<path d="M190 263 H230"/><path d="M425 263 H465"/><path d="M635 263 H675"/>
<path d="M765 230 V51 H650"/><path d="M542 355 V321 H327 V296"/>
</g>
<text x="770" y="107" fill="#186b60" font-family="system-ui,sans-serif" font-size="13" text-anchor="middle">measurements</text>
</svg>
</div>

## Subsystems and ownership

| Subsystem | Responsibility | Interface delivered |
|---|---|---|
| Acoustic bodies | Convert a few electrical inputs into useful fields | Geometry, frequency response, drive limits, uncertainty and calibration points |
| Control and power | Coherent waveforms, acquisition and bounded execution | Channel map, timing, voltage/current limits and job records |
| Metrology | Observe fields, material and process quality | Raw measurements, calibration, reconstruction and uncertainty |
| Feed and consolidation | Supply and permanently join the selected material | Process recipe, material/energy budget and inspection criteria |
| Frame and utilities | Preserve alignment and operating conditions | Datums, mounts, access, cooling and replaceable connections |
| Twin and planner | Design, simulate, compile and compare jobs | Versioned module records, programs, receipts and upgrade dependencies |
| Optional EM/optics | Add a specific material interaction or sensing capability | Qualified process or instrument module with a measured benefit |

## The acoustic candidate

Two opposed bodies provide a compact starting architecture. Geometry is optimized with the source and its mounting: preload, contact, structural modes, radiation and temperature all affect the useful response. The current starting hypothesis is three inputs per body.

At one frequency in a linear model, six inputs span at most six independent complex field patterns. Geometry can make those patterns useful for the chosen task. Frequency and time provide additional choices within bandwidth, settling and motion constraints.

## Interfaces that survive upgrades

Every module carries its identity and revision, units, coordinate frame, mechanical mates, typed signal/power ports, limits, material description and response provenance. A job also records the calibration and module revisions it used.

Keep desired object state, measured response and executable manufacturing program distinct. A shared representation links them through explicit transformations.

## First build and later modules

The first configuration needs an acoustic module, drive/acquisition, metrology, a frame and a selected feed/joining process. It does not inherit every subsystem in the large RH-1 concept.

EM and optical research continues alongside this build. Integration follows a task: a better measurement, a joining operation, a finer feature or a material the platform cannot yet process.

Read [Acoustics](acoustics.html), [Electromagnetics](electromagnetics.html), [Manufacturing](manufacturing.html) and [Digital twin](digital-twin.html).
