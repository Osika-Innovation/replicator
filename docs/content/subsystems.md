# Subsystems and interfaces

<div class="lead">The engineering layer under <a href="architecture.html">Architecture</a>: one datasheet for each of the eleven subsystems, the matrix of what crosses between them, and the log of deleted parts. Figures are for the <a href="desktop-replicator.html">Desktop Replicator</a>.</div>

Evidence labels are defined in [Current state](status.html#evidence-labels). No figure on this page is Measured. Firmware results come from workstation tests and are Simulated.

<div class="diagram master">
<!-- ZONE_MAP:BEGIN -->
<svg viewBox="0 0 860 236" role="group" aria-labelledby="zm-title zm-desc" xmlns="http://www.w3.org/2000/svg" font-family="system-ui,-apple-system,Segoe UI,sans-serif">
<title id="zm-title">Subsystem index by zone</title>
<desc id="zm-desc">The three zones of the stack with the eleven subsystem datasheets on this page. Each chip jumps to its datasheet.</desc>
<rect x="8" y="8" width="844" height="66" rx="10" fill="#e9f1e9" stroke="#173630" stroke-width="1.3"/>
<text x="22" y="28" font-size="11.5" font-weight="700" letter-spacing=".6" fill="#173630">UPPER BUILD CYLINDER</text>
<a href="#s01-chamber-and-stack-topology" class="bk" aria-label="S01 Chamber and stack"><rect x="22" y="36" width="156" height="28" rx="6" fill="#fffefa" stroke="#173630" stroke-width="1.1"/><text x="100" y="54" font-size="11.5" text-anchor="middle" fill="#173630">S01 Chamber and stack</text></a>
<a href="#s04-acoustic-array" class="bk" aria-label="S04 Acoustic array"><rect x="186" y="36" width="156" height="28" rx="6" fill="#fffefa" stroke="#173630" stroke-width="1.1"/><text x="264" y="54" font-size="11.5" text-anchor="middle" fill="#173630">S04 Acoustic array</text></a>
<a href="#s05-gap-actuator-and-resonance-lock" class="bk" aria-label="S05 Gap lock"><rect x="350" y="36" width="156" height="28" rx="6" fill="#fffefa" stroke="#173630" stroke-width="1.1"/><text x="428" y="54" font-size="11.5" text-anchor="middle" fill="#173630">S05 Gap lock</text></a>
<a href="#s06-optical-tomography" class="bk" aria-label="S06 Optical ring"><rect x="514" y="36" width="156" height="28" rx="6" fill="#fffefa" stroke="#173630" stroke-width="1.1"/><text x="592" y="54" font-size="11.5" text-anchor="middle" fill="#173630">S06 Optical ring</text></a>
<a href="#s07-electromagnetics-and-consolidation" class="bk" aria-label="S07 EM and joining"><rect x="678" y="36" width="156" height="28" rx="6" fill="#fffefa" stroke="#173630" stroke-width="1.1"/><text x="756" y="54" font-size="11.5" text-anchor="middle" fill="#173630">S07 EM and joining</text></a>
<rect x="8" y="84" width="844" height="66" rx="10" fill="#f5eade" stroke="#173630" stroke-width="1.3"/>
<text x="22" y="104" font-size="11.5" font-weight="700" letter-spacing=".6" fill="#173630">MID-PLANE</text>
<a href="#s03-mid-plane-interface" class="bk" aria-label="S03 Mid-plane interface"><rect x="22" y="112" width="156" height="28" rx="6" fill="#fffefa" stroke="#173630" stroke-width="1.1"/><text x="100" y="130" font-size="11.5" text-anchor="middle" fill="#173630">S03 Mid-plane interface</text></a>
<rect x="8" y="160" width="844" height="66" rx="10" fill="#e8ecf3" stroke="#173630" stroke-width="1.3"/>
<text x="22" y="180" font-size="11.5" font-weight="700" letter-spacing=".6" fill="#173630">LOWER PLINTH</text>
<a href="#s02-storage-and-release-plinth" class="bk" aria-label="S02 Storage and release"><rect x="22" y="188" width="156" height="28" rx="6" fill="#fffefa" stroke="#173630" stroke-width="1.1"/><text x="100" y="206" font-size="11.5" text-anchor="middle" fill="#173630">S02 Storage and release</text></a>
<a href="#s08-control-and-firmware" class="bk" aria-label="S08 Control and firmware"><rect x="186" y="188" width="156" height="28" rx="6" fill="#fffefa" stroke="#173630" stroke-width="1.1"/><text x="264" y="206" font-size="11.5" text-anchor="middle" fill="#173630">S08 Control and firmware</text></a>
<a href="#s09-prime-world-model" class="bk" aria-label="S09 Prime model"><rect x="350" y="188" width="156" height="28" rx="6" fill="#fffefa" stroke="#173630" stroke-width="1.1"/><text x="428" y="206" font-size="11.5" text-anchor="middle" fill="#173630">S09 Prime model</text></a>
<a href="#s10-metrology-and-calibration" class="bk" aria-label="S10 Metrology"><rect x="514" y="188" width="156" height="28" rx="6" fill="#fffefa" stroke="#173630" stroke-width="1.1"/><text x="592" y="206" font-size="11.5" text-anchor="middle" fill="#173630">S10 Metrology</text></a>
<a href="#s11-thermal-and-safety" class="bk" aria-label="S11 Thermal and safety"><rect x="678" y="188" width="156" height="28" rx="6" fill="#fffefa" stroke="#173630" stroke-width="1.1"/><text x="756" y="206" font-size="11.5" text-anchor="middle" fill="#173630">S11 Thermal and safety</text></a>
</svg>
<!-- ZONE_MAP:END -->
<p>The eleven subsystems by zone. Each chip jumps to its datasheet. The full block diagram with the four flows is in <a href="architecture.html#the-machine-in-one-picture">Architecture</a>.</p>
</div>

## Subsystem datasheets

Every datasheet has the same lines. Owner is the guide that holds the detail.

### S01 Chamber and stack topology

| | |
|---|---|
| Function | Enclose one work volume between two facing plates, keep room air out, and put storage, power and compute beneath it on one axis |
| Prototype fits | Stock borosilicate glass tube, {{c:desktop_geometry.glass_cylinder_id_od_mm|x}} mm inside and outside diameter, which closes the chamber and lifts with the head. {{c:desktop_geometry.gap_mm}} mm between the plates; head and tube lift {{c:desktop_geometry.lift_stroke_mm}} mm on rails, driven by a servo and two ball screws (about 2.5 s, 7.2 kg moving; no part chosen); envelope {{c:desktop_geometry.envelope_mm|x}} mm; {{c:desktop_geometry.nominal_mass_kg}} kg. *Derived from CAD* |
| In | Material through the mid-plane; twelve drive signals; laser light |
| Out | Echoes, optical readings, a finished or released part |
| Budgets | Sound pressure raised {{c:desktop_geometry.chamber_gain_closed_gap_median|range}} times over an open chamber at the median gap (*Simulated*). Tube tolerance: outside diameter ± 2.9 mm, wall ± 0.7 mm (*Documented*, catalogue) |
| Open | Head return repeatability after a lift. Raising the head with no power. Screw-slot seals and pinch detection. The Rev S model (storage bucket and cassette under the chamber) has no acoustic study yet |
| Owner | [Desktop Replicator](desktop-replicator.html#the-enclosure) |

### S02 Storage and release plinth

| | |
|---|---|
| Function | Hold feedstock, meter it in, take unwanted material back, and account for mass |
| Prototype fits | In the Rev S CAD (the default build): a fixed glass storage tube, the same stock as the build tube, directly under the mid-plane, with an LED ring and a camera under its rim. *Design decision; no acoustic study yet*. Rev F2 option (not in the default build): three 500 mL laboratory bottles on three bar load cells; one reversible metering pump; Ø1.6 mm fluoropolymer line; desiccant and a humidity sensor; three open crucibles in the chamber for powder, liquid and seed parts. *Derived CAD; bottles Documented; pump, cells and sensor not selected* |
| In | Hand-loaded stock; returned material |
| Out | Liquid to the chamber floor; weight readings |
| Budgets | Material moves only as neutral grains or droplets, never as a charged stream. The liquid riser has 6.8 mm of floor between the wafer socket and the smallest glass bore the catalogue tolerance allows (*Derived*) |
| Open | An automated path for powder and seed stock. Removing joined material. A mass balance in simulation |
| Owner | [Scan, recover and matter stores](matter-loop.html#the-stores-equation-library-vs-matter-pantry) |

### S03 Mid-plane interface

| | |
|---|---|
| Function | Reflect sound back up and let material through from below, on one plane |
| Prototype fits | The undrilled lower wafer, the flat ring round it, the liquid riser at the rim. *Design decision* |
| In | Sound from above; liquid from below |
| Out | Reflected sound; material onto the chamber floor |
| Budgets | The lift needs an end reflection of at least 0.85. The ring covers 31 % of the end area and dominates it; bare glass reflects almost everything (*Simulated*) |
| Open | Sealed wafer with feed ports in the ring, or a continuous tall cylinder with a separator. The liquid riser's effect on the sound field |
| Owner | [Acoustic bodies](acoustics.html), [Scan, recover and matter stores](matter-loop.html) |

### S04 Acoustic array

| | |
|---|---|
| Function | Make the pressure field that holds and moves material, and hear what is in it |
| Prototype fits | Two undrilled Ø{{c:desktop_geometry.wafer_diameter_mm}} × {{c:desktop_geometry.wafer_thickness_mm}} mm wafers ({{c:desktop_geometry.wafer_material}}), {{c:desktop_geometry.ports_per_plate}} PZT-8 discs of Ø{{c:desktop_geometry.pzt_diameter_mm}} × {{c:desktop_geometry.pzt_thickness_mm}} mm behind each; tones at {{c:desktop_geometry.comb_tones_hz|khz}} kHz. *Design decision* |
| In | Twelve bridge-driven signals on an {{c:haptic_pzt.bridge_rail_v}} V supply |
| Out | Sound into the chamber; the echo on the same two wires |
| Budgets | Each disc is a {{c:haptic_pzt.c0_nominal_pf}} pF load, with at most {{c:haptic_pzt.max_trace_cap_pf}} pF of added wiring (*Derived*). One 160 kHz tone on the full supply lifts about 1.2 times a foam bead's weight (1.22 in the force check) and holds 40 % of targets in three dimensions. Voltage margin 1.19 at the median gap, 0.87 at the worst. Five tones sharing the supply lift about 7 %. Glass bending stress 3.7 to 5.0 MPa for the foam bead against a {{c:desktop_geometry.plate_bending_stress_limit_mpa}} MPa limit (*Simulated*; [why](acoustics.html#drive-strength-and-lift)) |
| Open | Solid beads: the glass would exceed its stress limit with any drive. Unwanted traps above the 2 % limit ([scores](acoustics.html#how-a-field-is-scored)). Each real plate's response, which must be measured. Whether mixing products stay on the five tones at holding level |
| Owner | [Acoustic bodies](acoustics.html) |

### S05 Gap actuator and resonance lock

| | |
|---|---|
| Function | Keep the chamber on the gap resonance the lift depends on |
| Finding | At 160 kHz the lift changes 4.7 to 4.9 times between peak and trough of a resonance that repeats every 1.07 mm of gap (*Simulated*) |
| Prototype fits | Move the gap 0.41 mm per kelvin of mean air temperature, to ± 0.07 mm (± 0.15 K of temperature knowledge). The actuator is the head's lift servo: ± 1 mm trim either side of two hard stops, 0.0016 mm per encoder count. *Simulated need; Design decision (the three-stepper version was replaced on 24 November 2026)* |
| In | Air temperature; an optical reading or a one-source sweep of the resonance |
| Out | Gap set point |
| Budgets | A stored calibration goes stale: its match with the true response falls to about 0.63 after 0.5 K of air temperature change and 0.65 after 200 µm of gap change, where 1 is perfect (*Simulated*; [why](acoustics.html#the-chamber-as-a-resonator)) |
| Open | The firmware control loop and measured servo repeatability. First measurement: resonance width in an empty chamber from one source |
| Owner | [Acoustic bodies](acoustics.html) |

### S06 Optical tomography

| | |
|---|---|
| Function | See the object and measure the sound field without touching either |
| Prototype fits | {{c:mosquito_smi.total_ommatidia}} laser diodes at {{c:mosquito_smi.laser_wavelength_nm}} nm with built-in photodiodes, on two strips; each beam returns from a reflective film into its own laser, read through fast comparators. *Design decision* |
| In | 3.3 V through the head-down switch |
| Out | Per beam: a steady level (shadow) and a ripple (sound along the beam) |
| Budgets | {{c:mosquito_smi.lightread_coef_rad_per_pa_m}} radians of optical phase per pascal per metre of path; 2.0 W for the ring (*Derived*). The ring tracks air temperature to 0.0005 K and gap to 0.28 µm (*Simulated*) |
| Open | Amplifier bandwidth at the top tone. Laser class of the assembled machine. Laser tolerance to the returned light level |
| Owner | [Optics and metamaterials](optics.html#in-the-desktop-replicator) |

### S07 Electromagnetics and consolidation

| | |
|---|---|
| Function | Act on conducting or magnetic material only, and supply the energy that joins material |
| Prototype fits | Nothing by default. Joining is a modelled heating step addressed to one joint. *Simulated; recipe Open* |
| In, Out | None |
| Budgets | A pulsed ring coil acts only on material forming a closed conducting loop through it; induction lifts millimetre shot, not powder (*Derived*) |
| Open | Every joining recipe. Whether the optional wafer spiral gives a useful pulse. Placing one bead beside another |
| Owner | [Electromagnetic control](electromagnetics.html), [Manufacturing](manufacturing.html#consolidation) |

### S08 Control and firmware

| | |
|---|---|
| Function | Turn frames into twelve timed drive signals, capture the returns, and keep every board on one time base |
| Prototype fits | {{c:clock_and_bus.pcb_count}} field boards and {{c:clock_and_bus.mcu_count_full_machine}} microcontrollers; {{c:haptic_pzt.hbridge_driver_mpn}} bridge drivers; {{c:haptic_pzt.adc_fallback_mpn}} 16-bit converters on the piezo receive path; one {{c:clock_and_bus.xin_hz|mhz}} MHz clock. *Design decision; part numbers are candidates* |
| In | Frames from the workstation or the compute card; clock |
| Out | Drive signals; recorded echoes and optical readings |
| Budgets | Timing step {{c:clock_and_bus.pio_tick_ns}} ns, which is {{c:clock_and_bus.pio_tick_phase_deg_at_160khz}}° of phase at the top tone. Board-to-board skew at most {{c:clock_and_bus.sync_skew_max_ns}} ns. Picking the tones out of 8 channels takes 4 ms of each 10 ms frame (*Derived*, instruction counts) |
| Open | No main program, build or board. Whether one controller sustains converter data beside the drive output. The firmware pin map has one shared enable where the boards draw three groups |
| Owner | [Compute, sensing and control](compute-control.html#in-the-desktop-replicator) |

### S09 Prime world model

| | |
|---|---|
| Function | Read the chamber's state from echoes and choose the drive that reaches a goal |
| Prototype fits | Prime, the project's model built on the Cadence library (release 0.11.0): a sparse 8-bit network on the compute card. Working memory 15.4 kB plus a 43.3 kB calibration slot, 58.7 kB of the {{c:cadence_brain.cadence_sparse_max_kb}} kB allowed. Network image (35.7 or 39.1 kB) in flash. *Simulated* |
| In | Echo vector; a goal packet; a calibration image |
| Out | Occupancy estimate and mismatch count; drive amplitudes and phases |
| Budgets | Settle target {{c:cadence_brain.rp2350_settle_target_ms_range|range}} ms (*Design target*); instruction counts give 4.4 to 6.1 ms, and a calibrated read 2.3 ms, at an assumed cycle count per operation (*Derived*). Test scenes exactly right: 99.7 to 100 % with a fresh calibration, even after 1 K of warming; with an old calibration 99.7 % at no drift, 20.9 % at 0.3 K and 16.6 % at 1 K (*Simulated*, 320 scenes each) |
| Open | The bus message that carries the calibration image. Combining the network's answer with the calibrated read. Any result on a board |
| Owner | [Cadence, memory and wave compute](cadence-memory.html#in-the-desktop-replicator) |

### S10 Metrology and calibration

| | |
|---|---|
| Function | Measure this chamber's real response, so stored objects compile onto it |
| Prototype fits | In the assembled chamber, with removable Ø1 to 2 mm spheres and the crucibles; two air-temperature sensors; no separate test rigs. *Design decision* |
| In | Low-level probe signals; optical readings; air temperature |
| Out | A plate-response file for the planner; a calibration image for the compute card |
| Budgets | Air temperature to {{c:desktop_geometry.air_temp_tolerance_k}} K; phase to {{c:desktop_geometry.calibration_phase_tol_deg}}°; gain to {{c:desktop_geometry.calibration_gain_tol_pct}} % (*Design decision*). In still air the response from source A to B equals B to A, so 78 pairs are measured in place of 144 (*Derived*; [Compute, sensing and control](compute-control.html)) |
| Start-up order | (1) Measure: with the chamber empty, every source is pinged and every source listens. (2) Lock: the gap is tuned onto its resonance ([S05](#s05-gap-actuator-and-resonance-lock)). (3) Fill: the resonance is pumped up to working level over many cycles. No job starts before step 3 ends. *Design decision; not yet in firmware* |
| Open | The acceptance run on a built machine. The planning plate model disagrees with the solid model |
| Owner | [Digital twin](digital-twin.html), [Desktop Replicator](desktop-replicator.html#what-gets-checked-before-anything-is-bought) |

### S11 Thermal and safety

| | |
|---|---|
| Function | Remove heat without disturbing the chamber air, and make unsafe states unreachable |
| Prototype fits | Cooling air through the rear tower only. A hardware safety switch (direct-opening) in series with the bridge-enable supply and the laser supply. Head up: bridges high impedance and lasers off, so the machine can listen but not transmit. Firmware also refuses to drive. The switch is pressed by the spine's bottom plate when the head is down. *Design decision; actuator geometry Open* |
| In | 17.0 W of dissipation with the first compute card, 22.5 W with the second |
| Out | Warm air at the head louvres |
| Budgets | Warmest internal air 12.7 K above ambient against a 20 K limit; ceiling wafer 1.9 K warmer than the floor wafer. Bead charge at most {{c:electrostatics_and_matter_loop.max_bead_charge_pc}} pC, which needs a surface of at most 10⁹ ohms per square and air at {{c:electrostatics_and_matter_loop.chamber_ambient_rh_pct_range|range}} % humidity (*Derived*) |
| Open | Laser class. The static-bleed coating. A second independent interlock contact. The humidity gate in firmware |
| Owner | [Desktop Replicator](desktop-replicator.html#heat) |

## Interface control matrix

Row A, column B names what A sends to B, by contract number. An empty cell means no direct interface; add one here before using it. C1, the stored description of an object, stays in the workstation. It is compiled there into C2 and C3 and never crosses to the machine as a file.

| From ↓ to → | Workstation | Compute card | Backplane | Drive boards | Plates and chamber | Optical ring | Sensors and interlock | Store and plinth |
|---|---|---|---|---|---|---|---|---|
| **Workstation** | — | C3, C4, C5 | C2 | | | | | |
| **Compute card** | C7 | — | C9, C15 | | | | | |
| **Backplane** | C7 | C8 | — | C8, C9, C18 | | C8, C18 | C18 | C18 |
| **Drive boards** | | | C9 | — | C10 | | | |
| **Plates and chamber** | C6 | | | C11 | — | C12 | C16 | C17 |
| **Optical ring** | | | C9 | | C12 | — | | |
| **Sensors and interlock** | | | C13 | C14 | | C14 | — | |
| **Store and plinth** | | | | | C17 | | C13 | — |

### Contracts

This table fixes the exact fields. The file formats are explained in [Compute, sensing and control](compute-control.html#one-contract-files-verbs-and-the-machine-interface).

| No. | Contract | Kind | Exact definition | Survives | Evidence and open points |
|---|---|---|---|---|---|
| C1 | `holo-eq/0.2` and `holo-eq/0.3-mm` (`.holo`) | File | An object about its own centre. Write form: spherical waves per tone, 49 complex numbers per tone at the default setting, with only the non-zero ones stored, under 3 kB. Read form: a scattering table of at most 8 independent patterns per tone. Version 0.3-mm stores a list of materials and their positions; 1,721 bytes for an eleven-material test object | Any chamber, source count, tube size or air temperature | *Simulated.* A goal compiled per chamber matches a direct solve within 1 % on 12 and on 36 sources |
| C2 | `.fcode` (tag `FCD1`) | File and wire | Time-ordered frames, each one chord of 16-bit drive values, a duration, a verb (ADD 1, REMOVE 2, LISTEN 3) and the channels to record | Emulator or hardware; any compute card | *Simulated* |
| C3 | `HLEQ v1` | Wire | Little-endian. 16-byte header: tag `HLEQ`, version 1, stroke count 1 to 16, output width in multiples of 8 up to 344, echo scale, verify tolerance. Then half-precision stroke biases and a CRC-32. 1,556 bytes for 6 strokes of 64 outputs | A new object, with no change to the stored network and no extra memory | *Simulated.* The packet loads and settles to within 3.3 × 10⁻⁷ of the reference; every single-bit error is rejected |
| C4 | `LMQ8 v1` | Wire, then memory | Tag `LMQ8`, version 1, input and output counts, tone mask; 28-byte header; at most 43,296 bytes; checksum. Streamed in pieces by begin, write and commit. One slot: a failed download leaves no calibration, and reading is refused until the next | Temperature and gap drift, a head lift, a change of plates: only the image changes | *Simulated.* The bus message that carries it is not written |
| C5 | `CSQ8 v1` | Flash image | The shared sparse network: 35.7 or 39.1 kB. Hidden and output sizes must satisfy 4 × hidden + 3 × outputs ≤ 1,920 | A change of object or calibration | *Simulated.* Its use as a fixed chamber read is deleted (below) |
| C6 | `body-response/0.1` and `/0.2` | File | For each tone, how each drive input moves each patch of the radiating faces, with uncertainty and a maximum drive of {{c:haptic_pzt.max_drive_vrms}} V rms. Version 0.2 adds the receive path and refuses an export with patches wider than half a wavelength at the top tone; 0.1 had neither. Presets `desktop-200mm` and `boro12` | The present wafers, 36 sources, a future surface addressed by light | *Simulated.* The shipped file disagrees with the solid model; each plate must be measured |
| C7 | Machine interface | Calls | `describe`, `calibrate`, `play(frames)`, `listen(gates, steps)`, identical for emulator and hardware | Any hardware revision | *Simulated* |
| C8 | Clock and frame start | Electrical | One {{c:clock_and_bus.xin_hz|mhz}} MHz clock on matched traces and one frame-start signal; skew at most {{c:clock_and_bus.sync_skew_max_ns}} ns | Any number of boards | *Derived* |
| C9 | Board bus | Electrical | Two data lines and a frame line, 75 Mbit/s, packets of drive and echo values with CRC-32; design range {{c:clock_and_bus.spinal_bus_mbps_range|range}} Mbit/s | Board and controller changes | *Simulated* on a workstation |
| C10 | Drive port | Electrical | Two bridge outputs per disc through 2 × 33 µH with a 180 Ω and 15 nF damper; {{c:haptic_pzt.bridge_rail_v}} V supply, driver limit {{c:haptic_pzt.hbridge_driver_v_max}} V; three enable groups per board so that one group listens while two drive; enable low is high impedance; zero state is both outputs low | The driver part; a 24 V supply; 18 discs per plate | *Derived.* Worst unwanted harmonic 31 % against a 35 % limit. Firmware has one enable pin; three are drawn |
| C11 | Receive tap | Electrical | Difference stage of gain one-twentieth on matched resistor networks into a 16-bit converter; one {{c:clock_and_bus.capture_burst_us}} µs capture per frame | The converter part | *Derived.* Feedthrough 2.7 mV against a 6.3 mV echo floor |
| C12 | `LightRead` | Optical | {{c:mosquito_smi.total_ommatidia}} beams at {{c:mosquito_smi.laser_wavelength_nm}} nm at four heights (± 8 and ± 24 mm), returned by a reflective film at {{c:desktop_geometry.retro_film_radius_mm}} mm radius. Per beam: a level and a ripple of {{c:mosquito_smi.lightread_coef_rad_per_pa_m}} rad per Pa per m | The laser part; diffractive strips on the windows | *Simulated* |
| C13 | Environment bus | Electrical | I²C: two air-temperature sensors read to {{c:desktop_geometry.air_temp_tolerance_k}} K, one humidity sensor. Load-cell readings join this bus or a separate one | Sensor parts | *Design decision.* Humidity sensor and load cells not selected |
| C14 | Interlock chain | Electrical | A normally closed safety switch in series with the bridge-enable level-shifter supply and the 3.3 V laser supply. Open switch: every bridge output high impedance, lasers off | Anything downstream | *Design decision.* Second contact and actuator Open |
| C15 | Compute socket | Mechanical and electrical | One plug-in card slot (M.2 form factor) on the backplane. Card 1 microcontroller, card 2 gate array, card 3 reserved for an optical core | The compute substrate | *Design decision.* Cards 2 and 3 Open |
| C16 | Mechanical datums | Mechanical | Wafer seat for Ø{{c:desktop_geometry.wafer_diameter_mm}} × {{c:desktop_geometry.wafer_thickness_mm}} mm in a soft ring, Ø{{c:desktop_geometry.clear_glass_diameter_mm}} mm free; tube seat for the stock tube; two hard stops under the head and the servo encoder, which locate the head when it comes down; optical home and top-limit sensors; head-down switch | Any plate pair that fits the seat | *Derived from CAD.* Return repeatability Open |
| C17 | Material port | Mechanical | Laboratory bottles with GL 45 thread, tubing caps, Ø1.6 mm line; crucible tray clear of the lower wafer; neutral material only | The store behind the tower or under the chamber | *Derived; bottles Documented* |
| C18 | Power | Electrical | USB-C inlet; {{c:haptic_pzt.bridge_rail_v}} V for the bridges, 5 V for driver logic, 3.3 V for logic and lasers | The supply and converters | *Derived.* Converter parts are candidates |

Three rules keep the matrix honest:

1. A contract names its version, and a reader refuses a version it does not know.
2. Every file states whether its contents are measured or inferred.
3. An interface that is drawn but not coded is listed as an open point, as in C4 and C10.

## Deleted parts and retired baselines

Each row was in the design, or assumed by it, and was removed for the finding under Why. Earlier whole-machine baselines are in [Desktop Replicator](desktop-replicator.html#what-this-design-replaced), and the findings in the [Insight register](insights.html).

| Deleted | Status | Replaced by | Why | Evidence |
|---|---|---|---|---|
| The 1-bit receive converter (a TLV3501 comparator on each disc) | Retired for acoustic receive; the laser ring still uses a fast comparator | A 16-bit converter ({{c:haptic_pzt.adc_fallback_mpn}}) on footprints already present | Reached {{c:haptic_pzt.sfdr_simulated_dbc}} dB in a bit-exact simulation against a {{c:haptic_pzt.sfdr_gate_min_db}} dB requirement | Simulated |
| Small thick piezo discs (Ø4.6 × 0.8 mm) on a 12 V supply | Replaced | Ø{{c:desktop_geometry.pzt_diameter_mm}} × {{c:desktop_geometry.pzt_thickness_mm}} mm discs on {{c:haptic_pzt.bridge_rail_v}} V | About ten times short of the voltage needed for the first test bead | Simulated |
| The first bridge driver (a motor-driver part) | Withdrawn | {{c:haptic_pzt.hbridge_driver_mpn}} | Slow edges and an automatic sleep mode | Documented (datasheets) |
| A custom Ø224 × 3 mm glass tube | Replaced | The stock tube, {{c:desktop_geometry.glass_cylinder_id_od_mm|x}} mm | Not a catalogue size; would rub at catalogue tolerance | Derived |
| Lifting with all five tones at once | Replaced | One tone lifts; the five sense and shape | Five tones sharing the supply lift 7 % of a foam bead's weight | Simulated |
| Large coils acting across the whole chamber | Ruled out | At most a small pulsed ring coil at one crucible | Negligible force at chamber scale ([Electromagnetic control](electromagnetics.html#what-does-not-work-large-coils-across-the-chamber)) | Simulated |
| Moving material as an unneutralised stream of ions | Forbidden | Neutral grains and droplets | A charged stream repels itself and screens the steering fields | Derived |
| Removing material by replaying a reversed holding pattern | Deleted from design and code | Absorption at a measured resonance, then transport to a crucible, in simulation and twin | A reversed pattern rebuilds the same trap ([why](matter-loop.html#why-reversing-a-holding-pattern-removes-nothing)) | Derived; replacement Simulated |
| The chamber's response fixed in flash (`CSQ8` as a fixed chamber read) | Deleted | A calibration image in memory (`LMQ8`), replaced after every calibration | Correct on 42 to 50 % of sites after a 0.3 K air temperature change | Simulated |
| Stored drive values as an object's record (`.pattern`, `holo-field/0.1`) | Superseded as the store | The holographic equation (`holo-eq`) | Drives tuned on one plate fall to chance on a plate 0.5 % different | Simulated |
| Rule-only self-edits of the model's weights | Deleted | Gradient updates that a verifier must accept | 0 of 42 rule-only edits accepted; the verifier stopped every corrupting edit | Simulated |
| A network that replaces the field solver | Rejected | The exact solver, with learning only beside it | Slower than the solver: moving the memory for one answer takes 64 ms on a workstation, and the solver answers in under a millisecond | Derived |
| A turntable for scanning | Removed from the plan | Wall reflections, several frequencies and side sightlines, checked against held-back readings and a known reference object | A second view only shows that two guesses agree; a reference object gives the true answer with no moving part | Design decision |
| A web-browser version of the twin | Replaced | One native program with a command-line tool | Field, particles and picture must share graphics memory, and tests must render without a window | Design decision |
| Sintering a levitated grain with sound alone | Retired | A separate, addressed heat source ([Manufacturing](manufacturing.html#consolidation)) | A grain under a millimetre absorbs far too little ultrasound | Derived |
| A horn and a graded ceramic lattice behind each plate | Retired as a requirement | The bare thin plate | Above about 12 kHz a 1 mm glass plate already radiates well ([bending waves](acoustics.html#bending-waves-in-a-plate)) | Derived |
| A three-dimensional source array on a quasicrystal layout (ordered but never repeating) | Deleted | Random layouts; one with a minimum spacing is untested | Side beams 12 to 16 dB worse than random, in a test with predictions fixed in advance | Simulated (array model) |
| Driving the sound sources by coil and magnet or by radio, without wires | Rejected as the main drive; kept as a sealing option | Wired piezo discs | Radio turned straight into sound in a metal face is tens of decibels weaker than a piezo, and the loss heats a closed chamber. Radio power with local drive needs a receiver and amplifier per panel | Derived |
| A filter part at every source to put sound and radio on one wire | Retired in the earlier design | One part, one band, one wire; physics keeps the bands apart ([Architecture](architecture.html#one-work-volume-coordinated-fields)) | Each carrier lost its best shape, and every site gained a failure point | Design decision |
| One central hole shared by light, feed and a melting coil | Retired with the earlier design | Undrilled wafers; material enters at the rim | The hole was sized by the one unchecked job, melting whole ingots. Light and feed each needed a few millimetres | Design decision (review of 3 August 2026) |

**Lesson: name the job that sets each size.** Sized job by job, the shared hole shrank roughly tenfold. Every dimension should name the one requirement that fixes it, so a review can ask whether it is still wanted ([upgrades](upgrades.html)).

<div class="seealso">Related: <a href="architecture.html">Architecture</a> · <a href="desktop-replicator.html">Desktop Replicator</a> · <a href="ultimate-replicator.html">The long-term machine</a> · <a href="compute-control.html">Compute, sensing and control</a> · <a href="upgrades.html">Upgrade loop</a></div>
