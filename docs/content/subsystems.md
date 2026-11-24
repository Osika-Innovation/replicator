# Subsystems and interfaces

<div class="lead">This is the engineering layer under <a href="architecture.html">Architecture</a>. It holds one datasheet for each of the eleven subsystems, the interface control matrix that says exactly what crosses between them, and the log of parts that have been deleted. The figures are those of the <a href="desktop-replicator.html">Desktop Replicator</a>.</div>

Each line carries an evidence label: *Design decision*, *Documented*, *Derived*, *Simulated*, *Measured*, *Open* or *Claim*, as defined in [Current state](status.html#evidence-labels). No figure on this page carries the Measured label. Firmware results come from tests run on a workstation and are labelled Simulated.

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

Every datasheet has the same seven lines: what the subsystem is for, what the prototype fits, what enters, what leaves, its budgets, what is still open, and the guide that owns the detail.

### S01 Chamber and stack topology

| | |
|---|---|
| Function | Enclose one work volume between two facing plates, keep room air out, and place storage, power and compute directly beneath it on one axis |
| Prototype fits | Stock borosilicate glass tube, {{c:desktop_geometry.glass_cylinder_id_od_mm|x}} mm inside and outside diameter; {{c:desktop_geometry.gap_mm}} mm between the plates; head and tube lift {{c:desktop_geometry.lift_stroke_mm}} mm on rails; envelope {{c:desktop_geometry.envelope_mm|x}} mm; {{c:desktop_geometry.nominal_mass_kg}} kg. *Derived from CAD* |
| In | Material through the mid-plane; twelve drive signals; laser light |
| Out | Echoes, optical readings, a finished or released part |
| Budgets | Sound pressure raised {{c:desktop_geometry.chamber_gain_closed_gap_median|range}} times over an open chamber at the median gap (*Simulated*). Tube tolerance: outside diameter ± 2.9 mm, wall ± 0.7 mm (*Documented*, catalogue) |
| Open | CAD of the coaxial plinth. Whether the head returns to the same position after each lift. Stiffness of the lift posts |
| Owner | [Desktop Replicator](desktop-replicator.html) |

### S02 Storage and release plinth

| | |
|---|---|
| Function | Hold feedstock, meter it into the chamber, take unwanted material back, and account for mass |
| Prototype fits | Three 500 mL laboratory bottles on three bar load cells; one reversible metering pump; Ø1.6 mm fluoropolymer line; desiccant and a humidity sensor; three open crucibles in the chamber for powder, liquid and seed parts. *Derived CAD; bottles Documented; pump, cells and sensor not selected* |
| In | Hand-loaded stock; returned material |
| Out | Liquid to the chamber floor; weight readings |
| Budgets | Material moves only as neutral grains or droplets, never as a stream of charged particles (*Derived*). The liquid riser has 6.8 mm of floor between the wafer socket and the smallest glass bore the catalogue tolerance allows (*Derived*) |
| Open | Any automated path for powder and seed stock. Removing material that has already been joined. A mass balance in simulation |
| Owner | [Scan, recover and matter stores](matter-loop.html) |

### S03 Mid-plane interface

| | |
|---|---|
| Function | Reflect sound back into the build cylinder and let material through from below, on one plane |
| Prototype fits | The undrilled lower wafer, the flat annulus round it, the liquid riser at the rim. *Design decision* |
| In | Sound from above; liquid from below |
| Out | Reflected sound; material onto the chamber floor |
| Budgets | The lift needs an end reflection of at least 0.85. The annulus covers 31 % of the end area and dominates that figure; the bare glass reflects almost everything (*Simulated*) |
| Open | The choice between a sealed wafer with feed ports in the annulus and a continuous tall cylinder with a separator. The effect of the liquid riser on the sound field |
| Owner | [Acoustic bodies](acoustics.html), [Scan, recover and matter stores](matter-loop.html) |

### S04 Acoustic array

| | |
|---|---|
| Function | Create the pressure field that holds and moves material, and hear what is in it |
| Prototype fits | Two undrilled Ø{{c:desktop_geometry.wafer_diameter_mm}} × {{c:desktop_geometry.wafer_thickness_mm}} mm wafers ({{c:desktop_geometry.wafer_material}}), {{c:desktop_geometry.ports_per_plate}} PZT-8 discs of Ø{{c:desktop_geometry.pzt_diameter_mm}} × {{c:desktop_geometry.pzt_thickness_mm}} mm behind each; tones at {{c:desktop_geometry.comb_tones_hz|khz}} kHz. *Design decision* |
| In | Twelve bridge-driven signals on an {{c:haptic_pzt.bridge_rail_v}} V supply |
| Out | Sound into the chamber; the echo on the same two wires |
| Budgets | Each disc is a {{c:haptic_pzt.c0_nominal_pf}} pF load, with at most {{c:haptic_pzt.max_trace_cap_pf}} pF of added wiring (*Derived*). One 160 kHz tone lifts 1.22 times a foam bead's weight and holds 40 % of targets in three dimensions; the five-tone comb lifts 0.07 times (*Simulated*). Glass stress 3.7 to 5.0 MPa for the foam bead against a {{c:desktop_geometry.plate_bending_stress_limit_mpa}} MPa limit (*Simulated*) |
| Open | Solid beads: the glass would exceed its stress limit with any drive. Unwanted traps above the 2 % limit. The response of each real plate, which has to be measured |
| Owner | [Acoustic bodies](acoustics.html) |

### S05 Gap actuator and resonance lock

| | |
|---|---|
| Function | Keep the chamber on the axial resonance that the lift depends on |
| Finding | At 160 kHz the lift changes 4.7 to 4.9 times between the peak and the trough of a resonance that repeats every 1.07 mm of gap (*Simulated*) |
| Prototype fits | A requirement, not yet a part: move the gap 0.41 mm for each kelvin of mean air temperature, to ± 0.07 mm, which is ± 0.15 K of temperature knowledge. Specified actuator: ± 1 mm travel, 0.02 mm resolution. *Simulated need; Design decision of 24 November 2026* |
| In | Air temperature; an optical reading or a one-source sweep of the resonance |
| Out | Gap set point |
| Budgets | After 0.5 K of air temperature change or 200 µm of gap change the stored calibration is only about 0.64 correlated with the true response (*Simulated*) |
| Open | The actuator, its place in the lift mechanism, and the control loop in firmware. The first measurement: resonance width in an empty chamber from one source |
| Owner | [Acoustic bodies](acoustics.html) |

### S06 Optical tomography

| | |
|---|---|
| Function | See the object and measure the sound field without touching either |
| Prototype fits | {{c:mosquito_smi.total_ommatidia}} laser diodes at {{c:mosquito_smi.laser_wavelength_nm}} nm with built-in photodiodes, on two strips; each beam returns from a reflective film into its own laser. *Design decision* |
| In | 3.3 V through the head-down switch |
| Out | Per beam: a steady level (shadow) and a ripple (sound along the beam) |
| Budgets | {{c:mosquito_smi.lightread_coef_rad_per_pa_m}} radians of optical phase per pascal per metre of path (*Derived*). 2.0 W for the ring (*Derived*). In simulation the ring tracks air temperature to 0.0005 K and gap to 0.28 µm (*Simulated*) |
| Open | The amplifier's bandwidth at the top tone. The laser class of the assembled machine. Tolerance of the lasers to the returned light level |
| Owner | [Optics and metamaterials](optics.html) |

### S07 Electromagnetics and consolidation

| | |
|---|---|
| Function | Act selectively on conducting or magnetic material, and supply the energy that joins material |
| Prototype fits | Nothing by default. Joining is a modelled heating step addressed to one joint. *Simulated; recipe Open* |
| In | Not applicable |
| Out | Not applicable |
| Budgets | A pulsed ring coil acts only on material that forms a closed conducting loop through it; induction lifts millimetre shot, not powder (*Derived*). |
| Open | Every joining recipe. Whether the optional wafer spiral produces a useful pulse. Placing one bead beside another |
| Owner | [Electromagnetic control](electromagnetics.html), [Manufacturing](manufacturing.html) |

### S08 Control and firmware

| | |
|---|---|
| Function | Turn frames into twelve timed drive signals, capture what comes back, and keep every board on one time base |
| Prototype fits | {{c:clock_and_bus.pcb_count}} field boards and {{c:clock_and_bus.mcu_count_full_machine}} microcontrollers; {{c:haptic_pzt.hbridge_driver_mpn}} bridge drivers; {{c:haptic_pzt.adc_fallback_mpn}} converters; one {{c:clock_and_bus.xin_hz|mhz}} MHz clock. *Design decision; part numbers are candidates* |
| In | Frames from the workstation or the compute card; clock |
| Out | Drive signals; recorded echoes and optical readings |
| Budgets | Timing step {{c:clock_and_bus.pio_tick_ns}} ns, which is {{c:clock_and_bus.pio_tick_phase_deg_at_160khz}}° of phase at the top tone. Board-to-board skew at most {{c:clock_and_bus.sync_skew_max_ns}} ns. Demodulating 8 channels takes 4 ms of each 10 ms frame (*Derived* from instruction counts) |
| Open | No main program, build or board. Whether one controller sustains the converter data beside the drive output. The firmware pin map has one shared enable where the boards draw three groups |
| Owner | [Compute, sensing and control](compute-control.html) |

### S09 Prime world model

| | |
|---|---|
| Function | Read the chamber's state from echoes and choose the drive that reaches a stated goal |
| Naming | Prime is the project's model. Cadence is the library it is built on, held at its 0.11.0 release |
| Prototype fits | A sparse 8-bit network on the compute card. Working memory 15.4 kB plus a 43.3 kB calibration slot: 58.7 kB of the {{c:cadence_brain.cadence_sparse_max_kb}} kB allowed. The network image (35.7 or 39.1 kB) is in flash. *Simulated* |
| In | Echo vector; a goal packet; a calibration image |
| Out | Occupancy estimate and mismatch count; drive amplitudes and phases |
| Budgets | Settle 5.0 to 6.1 ms and a calibrated read 2.3 ms, at an assumed cycle count per operation (*Derived*). Read through a live calibration: 99.7 to 100 % of scenes exact at 0, 0.3 and 1 K of drift; through a stale one: 99.7, 20.9 and 16.6 % (*Simulated*, 320 scenes each) |
| Open | The bus message that carries the calibration image. Combining the network's answer with the calibrated read. Any result on a board |
| Owner | [Cadence, memory and wave compute](cadence-memory.html) |

### S10 Metrology and calibration

| | |
|---|---|
| Function | Measure this chamber's real response, so that stored objects compile onto it |
| Prototype fits | In the assembled chamber with removable Ø1 to 2 mm spheres and the crucibles; two air-temperature sensors; no separate test rigs. *Design decision* |
| In | Low-level probe signals; optical readings; air temperature |
| Out | A plate-response file for the planner; a calibration image for the compute card |
| Budgets | Air temperature to {{c:desktop_geometry.air_temp_tolerance_k}} K; phase to {{c:desktop_geometry.calibration_phase_tol_deg}}°; gain to {{c:desktop_geometry.calibration_gain_tol_pct}} % (*Design decision*). Still air makes the source-to-source response symmetric, so 78 pairs are measured in place of 144 (*Derived*) |
| Open | The acceptance run on a built machine. The planning plate model disagrees with the solid finite-element model |
| Owner | [Digital twin](digital-twin.html), [Desktop Replicator](desktop-replicator.html#what-gets-checked-before-anything-is-bought) |

### S11 Thermal and safety

| | |
|---|---|
| Function | Remove heat without disturbing the chamber air, and make the unsafe states unreachable |
| Prototype fits | Cooling air through the rear tower only. A direct-opening switch in series with the bridge-enable supply and the laser supply: with the head up the machine can listen but cannot transmit. *Design decision; actuator geometry Open* |
| In | 17.0 W of dissipation with the first compute card, 22.5 W with the second |
| Out | Warm air at the head louvres |
| Budgets | Warmest internal air 12.7 K above ambient against a 20 K limit; ceiling wafer 1.9 K warmer than the floor wafer (*Derived*, eleven-node model). Bead charge at most {{c:electrostatics_and_matter_loop.max_bead_charge_pc}} pC, which needs a surface of at most 10⁹ ohms per square and air at {{c:electrostatics_and_matter_loop.chamber_ambient_rh_pct_range|range}} % humidity (*Derived*) |
| Open | Laser class against the standard. The static-bleed coating. A second independent interlock contact. The humidity gate in firmware |
| Owner | [Desktop Replicator](desktop-replicator.html#heat) |

## Interface control matrix

The matrix reads from row to column: the cell in row A, column B names what A sends to B. An empty cell means the two have no direct interface, and anything that needs one must be added here first. The contract numbers are defined in the table that follows. C1, the stored description of an object, stays inside the workstation column: it is compiled there into C2 and C3 and never crosses to the machine as a file.

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

| No. | Contract | Kind | Exact definition | Survives | Evidence and open points |
|---|---|---|---|---|---|
| C1 | `holo-eq/0.2` and `holo-eq/0.3-mm` (`.holo`) | File | An object about its own centre. Write form: spherical waves per tone, 49 complex terms per tone at the default order, stored sparsely, under 3 kB. Read form: a scattering table of rank at most 8 per tone. Version 0.3-mm stores a list of materials and their positions; 1,721 bytes for an eleven-material test object | Any chamber, source count, tube size or air temperature | *Simulated.* A goal compiled per chamber matches a direct solve within 1 % on 12 and on 36 sources |
| C2 | `.fcode` (tag `FCD1`) | File and wire | Time-ordered frames, each one chord of 16-bit drive values, a duration, a verb (ADD 1, REMOVE 2, LISTEN 3) and the channels to record | Emulator or hardware; any compute card | *Simulated* |
| C3 | `HLEQ v1` | Wire | Little-endian. 16-byte header: tag `HLEQ`, version 1, stroke count 1 to 16, output width in multiples of 8 up to 344, echo scale, verify tolerance. Then half-precision stroke biases and a CRC-32. 1,556 bytes for 6 strokes of 64 outputs | A new object, with no change to the stored network and no extra memory | *Simulated.* On a workstation the packet loads and settles to within 3.3 × 10⁻⁷ of the reference, and every single-bit error is rejected |
| C4 | `LMQ8 v1` | Wire, then memory | Tag `LMQ8`, version 1, input and output counts, tone mask; 28-byte header; at most 43,296 bytes; checksum. Streamed in pieces by begin, write and commit. One slot: a failed download leaves no calibration and reading is refused until the next | Temperature and gap drift, a head lift, a change of plates: only the image changes | *Simulated.* The bus message that carries it is not written |
| C5 | `CSQ8 v1` | Flash image | The shared sparse network: 35.7 or 39.1 kB. Hidden and output sizes must satisfy 4 × hidden + 3 × outputs ≤ 1,920 | A change of object or calibration | *Simulated.* Its use as a fixed chamber read is deleted (below) |
| C6 | `body-response/0.1` and `/0.2` | File | For each tone, how each drive input moves each patch of the radiating faces, with uncertainty and a maximum drive of {{c:haptic_pzt.max_drive_vrms}} V rms. Version 0.2 adds the receive path. An export whose patches are wider than half a wavelength at the top tone is refused. Presets `desktop-200mm` and `boro12` | The present wafers, 36 sources, a future optically addressed surface | *Simulated.* The shipped file does not match the solid model; each plate must be measured |
| C7 | Machine interface | Calls | `describe`, `calibrate`, `play(frames)`, `listen(gates, steps)`, identical for emulator and hardware | Any hardware revision | *Simulated* |
| C8 | Clock and frame start | Electrical | One {{c:clock_and_bus.xin_hz|mhz}} MHz clock on matched traces and one frame-start signal; skew at most {{c:clock_and_bus.sync_skew_max_ns}} ns | Any number of boards | *Derived* |
| C9 | Board bus | Electrical | Two data lines and a frame line, 75 Mbit/s, packets of drive and echo values with CRC-32; design range {{c:clock_and_bus.spinal_bus_mbps_range|range}} Mbit/s | Board and controller changes | *Simulated* on a workstation |
| C10 | Drive port | Electrical | Two bridge outputs per disc through 2 × 33 µH with a 180 Ω and 15 nF damper; {{c:haptic_pzt.bridge_rail_v}} V supply, driver limit {{c:haptic_pzt.hbridge_driver_v_max}} V; three enable groups per board so that one group listens while two drive; enable low is high impedance; zero state is both outputs low | The driver part; a 24 V supply; 18 discs per plate | *Derived.* Worst unwanted harmonic 31 % against a 35 % limit. Firmware has one enable pin where three are drawn |
| C11 | Receive tap | Electrical | Difference stage of gain one-twentieth on matched resistor networks into a 16-bit converter; one {{c:clock_and_bus.capture_burst_us}} µs capture per frame | The converter part | *Derived.* Feedthrough 2.7 mV against a 6.3 mV echo floor |
| C12 | `LightRead` | Optical | {{c:mosquito_smi.total_ommatidia}} beams at {{c:mosquito_smi.laser_wavelength_nm}} nm at four heights (± 8 and ± 24 mm), returned by a reflective film at {{c:desktop_geometry.retro_film_radius_mm}} mm radius. Per beam: a level and a ripple of {{c:mosquito_smi.lightread_coef_rad_per_pa_m}} rad per Pa per m | The laser part; diffractive strips on the windows | *Simulated* |
| C13 | Environment bus | Electrical | I²C: two air-temperature sensors read to {{c:desktop_geometry.air_temp_tolerance_k}} K, one humidity sensor. Load-cell readings join this bus or a separate one (not selected) | Sensor parts | *Design decision.* Humidity sensor and load cells not selected |
| C14 | Interlock chain | Electrical | A normally closed safety switch in series with the supply of the bridge-enable level shifters and with the 3.3 V laser supply. Open switch: every bridge output high impedance, lasers off | Anything downstream | *Design decision.* Second contact and actuator Open |
| C15 | Compute socket | Mechanical and electrical | One plug-in card slot (M.2 form factor) on the backplane. Card 1 microcontroller, card 2 gate array, card 3 reserved for an optical core | The compute substrate | *Design decision.* Cards 2 and 3 Open |
| C16 | Mechanical datums | Mechanical | Wafer seat for Ø{{c:desktop_geometry.wafer_diameter_mm}} × {{c:desktop_geometry.wafer_thickness_mm}} mm in a soft ring, Ø{{c:desktop_geometry.clear_glass_diameter_mm}} mm free; tube seat for the stock tube; three ball-in-vee seats that locate the head when it comes down; head-down switch | Any plate pair that fits the seat | *Derived from CAD.* Return repeatability Open |
| C17 | Material port | Mechanical | Laboratory bottles with GL 45 thread, tubing caps, Ø1.6 mm line; crucible tray clear of the lower wafer; neutral material only | The store behind the tower or under the chamber | *Derived; bottles Documented* |
| C18 | Power | Electrical | USB-C inlet; {{c:haptic_pzt.bridge_rail_v}} V for the bridges, 5 V for driver logic, 3.3 V for logic and lasers | The supply and converters | *Derived.* Converter parts are candidates |

Three rules keep the matrix honest. A contract names its version, and a reader refuses a version it does not know. Every file states whether its contents are measured or inferred. And an interface that exists in one lane's drawing but not in another's code is listed as an open point, as in C4 and C10.

## Deleted parts and retired baselines

Each row is something that was in the design, or assumed by it, and has been removed. The right-hand column is the finding that removed it.

| Deleted | Status | Replaced by | Why | Evidence |
|---|---|---|---|---|
| P0, the 4 × 4 array of 40 kHz transducers | Retired; kept as a software regression case | The two-plate Desktop Replicator | A separate rig that taught nothing about plate acoustics or self-sensing | Design decision |
| P-JOIN, joining beads with hand-applied UV adhesive | Retired | Joining by the fields themselves; no recipe yet | Needed a person in the loop for every joint | Design decision; replacement Open |
| Drilled glass wafers with a central pipe | Retired | Undrilled wafers; material enters at the rim | The hole weakened the glass and removed the most useful part of the aperture | Design decision |
| Single-purpose test rigs for the electronics and optics | Retired; no disposable rigs remain | Simulation first, then calibration in the assembled chamber | Cost bench time and were then discarded | Design decision |
| The 1-bit receive converter (a TLV3501 comparator on each disc) | Retired as the acoustic receive path | A 16-bit converter ({{c:haptic_pzt.adc_fallback_mpn}}) on footprints already present | Reached {{c:haptic_pzt.sfdr_simulated_dbc}} dB in a bit-exact simulation against a {{c:haptic_pzt.sfdr_gate_min_db}} dB requirement | Simulated |
| Small thick piezo discs (Ø4.6 × 0.8 mm) on a 12 V supply | Replaced | Ø{{c:desktop_geometry.pzt_diameter_mm}} × {{c:desktop_geometry.pzt_thickness_mm}} mm discs on {{c:haptic_pzt.bridge_rail_v}} V | About ten times short of the voltage needed for the first test bead | Simulated |
| The first bridge driver (a motor-driver part) | Withdrawn | {{c:haptic_pzt.hbridge_driver_mpn}} | Slow edges and an automatic sleep mode | Documented (datasheets) |
| A custom Ø224 × 3 mm glass tube | Replaced | The stock tube, {{c:desktop_geometry.glass_cylinder_id_od_mm|x}} mm | Not a catalogue size; would have rubbed at catalogue tolerance | Derived |
| Lifting with all five tones at once | Replaced | One tone lifts; the comb senses and shapes | Five tones sharing the supply lift 7 % of a foam bead's weight | Simulated |
| The chamber's response fixed in flash with the network (`CSQ8` used as a static inverse) | Deleted | A calibration image in memory (`LMQ8`), replaced after every calibration | Correct on 42 to 50 % of sites after a 0.3 K change in air temperature | Simulated |
| Stored drive values as the record of an object (`.pattern`, `holo-field/0.1`) | Superseded as the store | The holographic equation (`holo-eq`) | Drives tuned on one plate fall to chance on a plate half a percent different | Simulated |
| Rule-only self-edits of the model's weights | Deleted | Gradient updates that a verifier must accept | 0 of 42 rule-only edits were accepted; the verifier stopped every corrupting edit | Simulated |
| Moving material as an unneutralised stream of ions | Forbidden | Neutral grains and droplets | A charged stream repels itself and screens the fields that should steer it | Derived |
| Large coils acting across the whole chamber | Ruled out | At most a small pulsed ring coil at one crucible | Negligible force at chamber scale | Simulated |
| Removing material by reversing a holding pattern | Deleted as a method | Absorption at the joint, then transport to a crucible | A reversed pattern has the same pressure magnitude and rebuilds the same trap | Derived |
| Bolt-clamped horn transducers on a fixed frame clock | Parked | Broadband discs on glass that drive and listen at once | Narrow-band sources cannot play several tones or listen while driving | Design decision |

The same history from the point of view of the machine as a whole is in [Desktop Replicator](desktop-replicator.html#what-this-design-replaced), and the findings behind each row are in the [Insight register](insights.html).

<div class="seealso">Related: <a href="architecture.html">Architecture</a> · <a href="desktop-replicator.html">Desktop Replicator</a> · <a href="ultimate-replicator.html">The long-term machine</a> · <a href="compute-control.html">Compute, sensing and control</a> · <a href="upgrades.html">Upgrade loop</a></div>
