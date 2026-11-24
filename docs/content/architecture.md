# Architecture

The Replicator shapes sound, light and electric or magnetic fields inside one shared work volume so that material can be arranged, joined, inspected and taken apart without tools touching it. Every size of the machine, from the [Desktop Replicator](desktop-replicator.html) to the [long-term machine](ultimate-replicator.html), is the same two-zone cylinder: a build chamber above, a plinth for storage, release, power and compute below, and one mid-plane between them. Growing the machine changes diameters and swaps modules across fixed interfaces. It does not change the layout.

This page is the top of the architecture layer. It gives the whole machine in one diagram, the four flows that cross it with their budgets, and one table that sets the prototype, the alternatives still being traded and the final machine side by side. The per-subsystem datasheets, the interface control matrix and the log of deleted parts are in [Subsystems and interfaces](subsystems.html).

**Reading the labels.** Each figure carries one evidence label: *Design decision* (chosen), *Documented* (an identified external source), *Derived* (a calculation), *Simulated* (a project model), *Measured* (a project bench result), *Open* (not settled) or *Claim* (asserted by a source, unverified). No row on this page carries the Measured label. The definitions are in [Current state](status.html#evidence-labels).

## The machine in one picture

<div class="diagram master">
<input class="flowradio" type="radio" name="msflow" id="fl-all" checked><label for="fl-all">All flows</label>
<input class="flowradio" type="radio" name="msflow" id="fl-matter"><label for="fl-matter">Matter</label>
<input class="flowradio" type="radio" name="msflow" id="fl-act"><label for="fl-act">Actuation</label>
<input class="flowradio" type="radio" name="msflow" id="fl-sense"><label for="fl-sense">Sensing</label>
<input class="flowradio" type="radio" name="msflow" id="fl-power"><label for="fl-power">Power and heat</label>
<!-- MASTER_STACK:BEGIN -->
<svg viewBox="0 0 912 1140" role="group" aria-labelledby="ms-title ms-desc" xmlns="http://www.w3.org/2000/svg" font-family="system-ui,-apple-system,Segoe UI,sans-serif">
<title id="ms-title">Master subsystem block diagram of the unified cylindrical two-zone stack</title>
<desc id="ms-desc">An upper build cylinder sits on a mid-plane reflector and transfer gate, which sits on a lower plinth holding storage, release, power and compute. A workstation is tethered below. Four colour-coded buses run alongside: matter and return, actuation, sensing and telemetry, and power and heat. Every block links to its subsystem guide.</desc>
<defs>
<marker id="ms-matter" markerWidth="8" markerHeight="8" refX="6.5" refY="4" orient="auto" markerUnits="userSpaceOnUse"><path d="M0 .8 L7 4 L0 7.2z" fill="#9a542e"/></marker>
<marker id="ms-act" markerWidth="8" markerHeight="8" refX="6.5" refY="4" orient="auto" markerUnits="userSpaceOnUse"><path d="M0 .8 L7 4 L0 7.2z" fill="#166b60"/></marker>
<marker id="ms-sense" markerWidth="8" markerHeight="8" refX="6.5" refY="4" orient="auto" markerUnits="userSpaceOnUse"><path d="M0 .8 L7 4 L0 7.2z" fill="#2b5fa8"/></marker>
<marker id="ms-power" markerWidth="8" markerHeight="8" refX="6.5" refY="4" orient="auto" markerUnits="userSpaceOnUse"><path d="M0 .8 L7 4 L0 7.2z" fill="#a8323a"/></marker>
</defs>
<text x="120" y="30" font-size="14" font-weight="700" fill="#173630">Unified cylindrical two-zone stack</text>
<text x="800" y="30" font-size="10.5" text-anchor="end" fill="#3d4d47">Desktop Replicator · every block is a link · dots mark its flows</text>
<g class="fl fl-matter" stroke="#9a542e" fill="none" stroke-width="2.6">
<path d="M40 300 V866"/>
<path d="M120 866 H40"/><circle cx="120" cy="866" r="4" fill="#9a542e" stroke="none"/>
<path d="M40 545 H113" marker-end="url(#ms-matter)"/><path d="M120 557 H47" stroke-dasharray="5 3" marker-end="url(#ms-matter)"/>
<path d="M40 300 H113" marker-end="url(#ms-matter)"/><path d="M120 312 H47" stroke-dasharray="5 3" marker-end="url(#ms-matter)"/>
</g>
<g class="fl fl-power" stroke="#a8323a" fill="none" stroke-width="2.6">
<path d="M100 125 V884"/>
<path d="M120 884 H100"/><circle cx="120" cy="884" r="4" fill="#a8323a" stroke="none"/>
<path d="M100 690 H113" marker-end="url(#ms-power)"/>
<path d="M100 125 H113" marker-end="url(#ms-power)"/>
</g>
<g class="fl fl-act" stroke="#166b60" fill="none" stroke-width="2.6">
<path d="M820 112 V778"/>
<path d="M800 778 H820"/><circle cx="800" cy="778" r="4" fill="#166b60" stroke="none"/>
<path d="M800 676 H820"/><circle cx="800" cy="676" r="4" fill="#166b60" stroke="none"/>
<path d="M820 536 H807" marker-end="url(#ms-act)"/>
<path d="M820 250 H807" marker-end="url(#ms-act)"/>
<path d="M820 112 H807" marker-end="url(#ms-act)"/>
</g>
<g class="fl fl-sense" stroke="#2b5fa8" fill="none" stroke-width="2.6">
<path d="M866 138 V705"/>
<path d="M800 138 H866"/><circle cx="800" cy="138" r="4" fill="#2b5fa8" stroke="none"/>
<path d="M800 360 H866"/><circle cx="800" cy="360" r="4" fill="#2b5fa8" stroke="none"/>
<path d="M800 568 H866"/><circle cx="800" cy="568" r="4" fill="#2b5fa8" stroke="none"/>
<path d="M866 705 H807" marker-end="url(#ms-sense)"/>
</g>
<text class="fl fl-matter" transform="rotate(-90 16 480)" x="16" y="480" text-anchor="middle" font-size="10" font-weight="600" fill="#9a542e" stroke="#fffefa" stroke-width="3.5" paint-order="stroke">MATTER AND RETURN · neutral grains and droplets only · charge ≤ {{c:electrostatics_and_matter_loop.max_bead_charge_pc}} pC per bead</text>
<text class="fl fl-matter" transform="rotate(-90 29 480)" x="29" y="480" text-anchor="middle" font-size="10" font-weight="600" fill="#9a542e" stroke="#fffefa" stroke-width="3.5" paint-order="stroke">air at {{c:electrostatics_and_matter_loop.chamber_ambient_rh_pct_range|range}} % RH · one Ø1.6 mm liquid line · solids feed OPEN · return to crucibles (dashed)</text>
<text class="fl fl-power" transform="rotate(-90 76 480)" x="76" y="480" text-anchor="middle" font-size="10" font-weight="600" fill="#a8323a" stroke="#fffefa" stroke-width="3.5" paint-order="stroke">POWER AND HEAT · USB-C in · {{c:haptic_pzt.bridge_rail_v}} V bridge rail · 5 V driver logic · 3.3 V logic and lasers</text>
<text class="fl fl-power" transform="rotate(-90 89 480)" x="89" y="480" text-anchor="middle" font-size="10" font-weight="600" fill="#a8323a" stroke="#fffefa" stroke-width="3.5" paint-order="stroke">17.0 W in total (22.5 W with the gate-array card) · ceiling kept 1.9 K warmer than floor</text>
<text class="fl fl-act" transform="rotate(-90 838 480)" x="838" y="480" text-anchor="middle" font-size="10" font-weight="600" fill="#166b60" stroke="#fffefa" stroke-width="3.5" paint-order="stroke">ACTUATION · 12 channels ≤ {{c:haptic_pzt.max_drive_v_peak_single_tone}} V peak · tones {{c:desktop_geometry.comb_tones_hz|khz}} kHz · timing step {{c:clock_and_bus.pio_tick_ns}} ns</text>
<text class="fl fl-act" transform="rotate(-90 851 480)" x="851" y="480" text-anchor="middle" font-size="10" font-weight="600" fill="#166b60" stroke="#fffefa" stroke-width="3.5" paint-order="stroke">pattern ring {{c:clock_and_bus.transmit_ring_us}} µs · frame 10 ms · {{c:mosquito_smi.total_ommatidia}} lasers ≤ 5 mW each · no EM drive fitted</text>
<text class="fl fl-sense" transform="rotate(-90 884 480)" x="884" y="480" text-anchor="middle" font-size="10" font-weight="600" fill="#2b5fa8" stroke="#fffefa" stroke-width="3.5" paint-order="stroke">SENSING AND TELEMETRY · 16-bit echo read · one {{c:clock_and_bus.capture_burst_us}} µs capture per 10 ms frame</text>
<text class="fl fl-sense" transform="rotate(-90 897 480)" x="897" y="480" text-anchor="middle" font-size="10" font-weight="600" fill="#2b5fa8" stroke="#fffefa" stroke-width="3.5" paint-order="stroke">lock-in 4 ms for 8 channels · {{c:mosquito_smi.total_ommatidia}} optical rays · board bus 75 Mbit/s · calibrated read 2.3 ms</text>
<rect x="120" y="44" width="680" height="414" rx="12" fill="#e9f1e9" stroke="#173630" stroke-width="1.5"/>
<text x="135" y="65" font-size="12.5" font-weight="700" letter-spacing=".6" fill="#173630">UPPER BUILD CYLINDER</text>
<text x="135" y="80" font-size="10" fill="#3d4d47">stock glass tube {{c:desktop_geometry.glass_cylinder_id_od_mm|x}} mm · {{c:desktop_geometry.gap_mm}} mm between the plates · lifts {{c:desktop_geometry.lift_stroke_mm}} mm with the head</text>
<a href="acoustics.html" class="bk on-act on-sense on-power" aria-label="Upper acoustic lamina (in the head)">
<rect x="135" y="92" width="318" height="66" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="145" y="110" font-size="12.5" font-weight="600" fill="#173630">Upper acoustic lamina (in the head)</text>
<text x="145" y="125" font-size="10" fill="#3d4d47">{{c:desktop_geometry.ports_per_plate}} × PZT-8 Ø{{c:desktop_geometry.pzt_diameter_mm}} × {{c:desktop_geometry.pzt_thickness_mm}} mm · {{c:haptic_pzt.hbridge_driver_mpn}} full bridges</text>
<text x="145" y="138" font-size="10" fill="#3d4d47">echo read on the drive wires by {{c:haptic_pzt.adc_fallback_mpn}}, 16 bit</text>
<text x="444" y="152" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#166b60">DESIGN · SIMULATED</text>
<circle class="fl fl-act" cx="148" cy="149" r="3.6" fill="#166b60"/>
<circle class="fl fl-sense" cx="158" cy="149" r="3.6" fill="#2b5fa8"/>
<circle class="fl fl-power" cx="168" cy="149" r="3.6" fill="#a8323a"/>
</a>
<a href="acoustics.html#known-limits" class="bk on-act on-sense" aria-label="Gap actuator and resonance lock">
<rect x="467" y="92" width="318" height="66" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="477" y="110" font-size="12.5" font-weight="600" fill="#173630">Gap actuator and resonance lock</text>
<text x="477" y="125" font-size="10" fill="#3d4d47">holds gap ÷ sound speed: 0.41 mm per kelvin, ± 0.07 mm</text>
<text x="477" y="138" font-size="10" fill="#3d4d47">± 1 mm travel in 0.02 mm steps · not yet in CAD or firmware</text>
<text x="776" y="152" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#9a542e">SIMULATED NEED · OPEN PART</text>
<circle class="fl fl-act" cx="480" cy="149" r="3.6" fill="#166b60"/>
<circle class="fl fl-sense" cx="490" cy="149" r="3.6" fill="#2b5fa8"/>
</a>
<a href="acoustics.html" class="bk on-act on-sense" aria-label="Upper wafer">
<rect x="135" y="168" width="650" height="30" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="145" y="187" font-size="11.5" fill="#173630"><tspan font-weight="600">Upper wafer</tspan> · undrilled Ø{{c:desktop_geometry.wafer_diameter_mm}} × {{c:desktop_geometry.wafer_thickness_mm}} mm borosilicate: source, reflector and microphone in one part</text>
<text x="752" y="186.5" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#166b60">DESIGN</text>
<circle class="fl fl-act" cx="774" cy="183" r="3.6" fill="#166b60"/>
<circle class="fl fl-sense" cx="764" cy="183" r="3.6" fill="#2b5fa8"/>
</a>
<a href="optics.html" class="bk on-sense on-power" aria-label="Optical ring (LightRead)">
<rect x="135" y="208" width="190" height="198" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="145" y="226" font-size="12.5" font-weight="600" fill="#173630">Optical ring (LightRead)</text>
<text x="145" y="241" font-size="10" fill="#3d4d47">{{c:mosquito_smi.total_ommatidia}} self-mixing lasers, {{c:mosquito_smi.laser_wavelength_nm}} nm</text>
<text x="145" y="254" font-size="10" fill="#3d4d47">each laser is its own detector</text>
<text x="145" y="267" font-size="10" fill="#3d4d47">shadow image of the object</text>
<text x="145" y="280" font-size="10" fill="#3d4d47">optical phase of the sound field</text>
<text x="145" y="293" font-size="10" fill="#3d4d47">tracks air temperature and gap</text>
<text x="145" y="306" font-size="10" fill="#3d4d47">no cameras, no beam splitters</text>
<text x="145" y="319" font-size="10" fill="#3d4d47"></text>
<text x="145" y="332" font-size="10" fill="#3d4d47">amplifier bandwidth at the</text>
<text x="145" y="345" font-size="10" fill="#3d4d47">top tone: OPEN</text>
<text x="316" y="400" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#9a542e">SIMULATED · OPEN</text>
<circle class="fl fl-sense" cx="148" cy="397" r="3.6" fill="#2b5fa8"/>
<circle class="fl fl-power" cx="158" cy="397" r="3.6" fill="#a8323a"/>
</a>
<rect x="337" y="208" width="246" height="198" rx="9" fill="#d6e6da" stroke="#173630" stroke-width="1" stroke-dasharray="3 3"/>
<text x="460" y="226" font-size="11" font-weight="700" letter-spacing=".5" text-anchor="middle" fill="#173630">ONE SHARED WORK VOLUME</text>
<a href="manufacturing.html" class="bk on-act on-matter" aria-label="Arrange and hold">
<rect x="349" y="234" width="222" height="50" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="359" y="252" font-size="12.5" font-weight="600" fill="#173630">Arrange and hold</text>
<text x="359" y="267" font-size="10" fill="#3d4d47">one 160 kHz tone lifts; the comb shapes</text>
<text x="562" y="278" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#166b60">SIMULATED</text>
<circle class="fl fl-act" cx="362" cy="275" r="3.6" fill="#166b60"/>
<circle class="fl fl-matter" cx="372" cy="275" r="3.6" fill="#9a542e"/>
</a>
<a href="manufacturing.html#consolidation" class="bk on-act on-matter" aria-label="Join and consolidate">
<rect x="349" y="290" width="222" height="50" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="359" y="308" font-size="12.5" font-weight="600" fill="#173630">Join and consolidate</text>
<text x="359" y="323" font-size="10" fill="#3d4d47">addressed heat step; no recipe yet</text>
<text x="562" y="334" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#9a542e">OPEN</text>
<circle class="fl fl-act" cx="362" cy="331" r="3.6" fill="#166b60"/>
<circle class="fl fl-matter" cx="372" cy="331" r="3.6" fill="#9a542e"/>
</a>
<a href="matter-loop.html" class="bk on-sense on-matter" aria-label="Scan, verify and remove">
<rect x="349" y="346" width="222" height="50" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="359" y="364" font-size="12.5" font-weight="600" fill="#173630">Scan, verify and remove</text>
<text x="359" y="379" font-size="10" fill="#3d4d47">echo check (LISTEN), absorb (REMOVE)</text>
<text x="562" y="390" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#166b60">SIMULATED</text>
<circle class="fl fl-sense" cx="362" cy="387" r="3.6" fill="#2b5fa8"/>
<circle class="fl fl-matter" cx="372" cy="387" r="3.6" fill="#9a542e"/>
</a>
<a href="electromagnetics.html" class="bk on-act on-power" aria-label="Electric and magnetic">
<rect x="595" y="208" width="190" height="198" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="605" y="226" font-size="12.5" font-weight="600" fill="#173630">Electric and magnetic</text>
<text x="605" y="241" font-size="10" fill="#3d4d47">none fitted by default</text>
<text x="605" y="254" font-size="10" fill="#3d4d47"></text>
<text x="605" y="267" font-size="10" fill="#3d4d47">option: 12-arm spiral on wafer</text>
<text x="605" y="280" font-size="10" fill="#3d4d47">option: Ø{{c:dissolve_and_toroidal.compact_toroid_collar_id_mm_range|range}} mm pulsed</text>
<text x="605" y="293" font-size="10" fill="#3d4d47">ring coil at one crucible</text>
<text x="605" y="306" font-size="10" fill="#3d4d47"></text>
<text x="605" y="319" font-size="10" fill="#3d4d47">large coils across the</text>
<text x="605" y="332" font-size="10" fill="#3d4d47">chamber: ruled out</text>
<text x="605" y="345" font-size="10" fill="#3d4d47">static bleed coating: OPEN</text>
<text x="776" y="400" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#9a542e">SIMULATED · OPEN</text>
<circle class="fl fl-act" cx="608" cy="397" r="3.6" fill="#166b60"/>
<circle class="fl fl-power" cx="618" cy="397" r="3.6" fill="#a8323a"/>
</a>
<a href="desktop-replicator.html#the-enclosure" class="bk on-act" aria-label="Glass wall">
<rect x="135" y="416" width="650" height="30" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="145" y="435" font-size="11.5" fill="#173630"><tspan font-weight="600">Glass wall</tspan> · draught shield · raises sound pressure {{c:desktop_geometry.chamber_gain_closed_gap_median|range}} × (gap median) · not a laser enclosure</text>
<text x="762" y="434.5" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#166b60">SIMULATED</text>
<circle class="fl fl-act" cx="774" cy="431" r="3.6" fill="#166b60"/>
</a>
<rect x="120" y="470" width="680" height="122" rx="12" fill="#f5eade" stroke="#173630" stroke-width="1.5"/>
<text x="135" y="491" font-size="12.5" font-weight="700" letter-spacing=".6" fill="#173630">MID-PLANE REFLECTOR AND TRANSFER GATE</text>
<text x="135" y="506" font-size="10" fill="#3d4d47">one plane, two duties: reflect sound up, pass material up · layout trade in simulation</text>
<a href="acoustics.html" class="bk on-act on-sense" aria-label="Lower wafer">
<rect x="135" y="518" width="155" height="64" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="145" y="536" font-size="12.5" font-weight="600" fill="#173630">Lower wafer</text>
<text x="145" y="551" font-size="10" fill="#3d4d47">same part as the upper</text>
<text x="145" y="564" font-size="10" fill="#3d4d47">source and reflector</text>
<text x="281" y="576" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#166b60">DESIGN</text>
<circle class="fl fl-act" cx="148" cy="573" r="3.6" fill="#166b60"/>
<circle class="fl fl-sense" cx="158" cy="573" r="3.6" fill="#2b5fa8"/>
</a>
<a href="acoustics.html#known-limits" class="bk on-act" aria-label="Hard end annulus">
<rect x="300" y="518" width="155" height="64" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="310" y="536" font-size="12.5" font-weight="600" fill="#173630">Hard end annulus</text>
<text x="310" y="551" font-size="10" fill="#3d4d47">end reflection ≥ 0.85</text>
<text x="310" y="564" font-size="10" fill="#3d4d47">measured first, no bead</text>
<text x="446" y="576" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#166b60">SIMULATED</text>
<circle class="fl fl-act" cx="313" cy="573" r="3.6" fill="#166b60"/>
</a>
<a href="matter-loop.html" class="bk on-matter" aria-label="Transfer gate">
<rect x="465" y="518" width="155" height="64" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="475" y="536" font-size="12.5" font-weight="600" fill="#173630">Transfer gate</text>
<text x="475" y="551" font-size="10" fill="#3d4d47">Ø1.6 mm liquid riser</text>
<text x="475" y="564" font-size="10" fill="#3d4d47">solids ports: OPEN</text>
<text x="611" y="576" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#9a542e">DERIVED · OPEN</text>
<circle class="fl fl-matter" cx="478" cy="573" r="3.6" fill="#9a542e"/>
</a>
<a href="desktop-replicator.html#heat" class="bk on-power" aria-label="Thermal barrier">
<rect x="630" y="518" width="155" height="64" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="640" y="536" font-size="12.5" font-weight="600" fill="#173630">Thermal barrier</text>
<text x="640" y="551" font-size="10" fill="#3d4d47">floor never warmer</text>
<text x="640" y="564" font-size="10" fill="#3d4d47">than the ceiling</text>
<text x="776" y="576" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#166b60">DERIVED</text>
<circle class="fl fl-power" cx="643" cy="573" r="3.6" fill="#a8323a"/>
</a>
<rect x="120" y="604" width="680" height="312" rx="12" fill="#e8ecf3" stroke="#173630" stroke-width="1.5"/>
<text x="135" y="625" font-size="12.5" font-weight="700" letter-spacing=".6" fill="#173630">LOWER PLINTH: STORAGE, RELEASE, POWER, COMPUTE</text>
<text x="135" y="640" font-size="10" fill="#3d4d47">coaxial under the build cylinder (ruled 24 Nov 2026) · CAD pivot pending; the current model has the store behind the tower</text>
<a href="compute-control.html#drive-stage" class="bk on-act on-sense on-power" aria-label="Lower acoustic lamina">
<rect x="135" y="652" width="208" height="76" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="145" y="670" font-size="12.5" font-weight="600" fill="#173630">Lower acoustic lamina</text>
<text x="145" y="685" font-size="10" fill="#3d4d47">6 drive channels + 1 reference</text>
<text x="145" y="698" font-size="10" fill="#3d4d47">3 enable groups: 1 listens, 2 drive</text>
<text x="334" y="722" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#166b60">DESIGN</text>
<circle class="fl fl-act" cx="148" cy="719" r="3.6" fill="#166b60"/>
<circle class="fl fl-sense" cx="158" cy="719" r="3.6" fill="#2b5fa8"/>
<circle class="fl fl-power" cx="168" cy="719" r="3.6" fill="#a8323a"/>
</a>
<a href="compute-control.html#clock-and-timing" class="bk on-act on-sense on-power" aria-label="Clock and bus backplane">
<rect x="356" y="652" width="208" height="76" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="366" y="670" font-size="12.5" font-weight="600" fill="#173630">Clock and bus backplane</text>
<text x="366" y="685" font-size="10" fill="#3d4d47">{{c:clock_and_bus.xin_hz|mhz}} MHz + frame sync, skew ≤ {{c:clock_and_bus.sync_skew_max_ns}} ns</text>
<text x="366" y="698" font-size="10" fill="#3d4d47">board bus 75 Mbit/s with CRC-32</text>
<text x="555" y="722" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#166b60">DERIVED</text>
<circle class="fl fl-act" cx="369" cy="719" r="3.6" fill="#166b60"/>
<circle class="fl fl-sense" cx="379" cy="719" r="3.6" fill="#2b5fa8"/>
<circle class="fl fl-power" cx="389" cy="719" r="3.6" fill="#a8323a"/>
</a>
<a href="compute-control.html#in-the-desktop-replicator" class="bk on-sense" aria-label="Chamber and plinth sensors">
<rect x="577" y="652" width="208" height="76" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="587" y="670" font-size="12.5" font-weight="600" fill="#173630">Chamber and plinth sensors</text>
<text x="587" y="685" font-size="10" fill="#3d4d47">I²C: 2 air thermometers, humidity</text>
<text x="587" y="698" font-size="10" fill="#3d4d47">3 load cells · head-down switch</text>
<text x="776" y="722" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#9a542e">DESIGN · PARTS OPEN</text>
<circle class="fl fl-sense" cx="590" cy="719" r="3.6" fill="#2b5fa8"/>
</a>
<a href="cadence-memory.html" class="bk on-act on-sense on-power" aria-label="Compute card: Prime network">
<rect x="135" y="740" width="208" height="76" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="145" y="758" font-size="12.5" font-weight="600" fill="#173630">Compute card: Prime network</text>
<text x="145" y="773" font-size="10" fill="#3d4d47">sparse, under {{c:cadence_brain.cadence_sparse_max_kb}} kB of memory</text>
<text x="145" y="786" font-size="10" fill="#3d4d47">settle 15.4 kB + calibration 43.3 kB</text>
<text x="334" y="810" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#166b60">SIMULATED</text>
<circle class="fl fl-act" cx="148" cy="807" r="3.6" fill="#166b60"/>
<circle class="fl fl-sense" cx="158" cy="807" r="3.6" fill="#2b5fa8"/>
<circle class="fl fl-power" cx="168" cy="807" r="3.6" fill="#a8323a"/>
</a>
<a href="digital-twin.html" class="bk on-sense" aria-label="Calibration and metrology">
<rect x="356" y="740" width="208" height="76" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="366" y="758" font-size="12.5" font-weight="600" fill="#173630">Calibration and metrology</text>
<text x="366" y="773" font-size="10" fill="#3d4d47">in-chamber spheres, reciprocity</text>
<text x="366" y="786" font-size="10" fill="#3d4d47">new LMQ8 image per calibration</text>
<text x="555" y="810" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#166b60">SIMULATED</text>
<circle class="fl fl-sense" cx="369" cy="807" r="3.6" fill="#2b5fa8"/>
</a>
<a href="compute-control.html#drive-stage" class="bk on-act on-power" aria-label="Safety interlocks">
<rect x="577" y="740" width="208" height="76" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="587" y="758" font-size="12.5" font-weight="600" fill="#173630">Safety interlocks</text>
<text x="587" y="773" font-size="10" fill="#3d4d47">head up: bridges off, lasers off</text>
<text x="587" y="786" font-size="10" fill="#3d4d47">humidity gate in firmware: OPEN</text>
<text x="776" y="810" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#9a542e">DESIGN · OPEN</text>
<circle class="fl fl-act" cx="590" cy="807" r="3.6" fill="#166b60"/>
<circle class="fl fl-power" cx="600" cy="807" r="3.6" fill="#a8323a"/>
</a>
<a href="matter-loop.html" class="bk on-matter on-sense" aria-label="Material store">
<rect x="135" y="828" width="208" height="76" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="145" y="846" font-size="12.5" font-weight="600" fill="#173630">Material store</text>
<text x="145" y="861" font-size="10" fill="#3d4d47">3 × 500 mL stock bottles, weighed</text>
<text x="145" y="874" font-size="10" fill="#3d4d47">reversible metering pump</text>
<text x="334" y="898" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#9a542e">DERIVED · PARTS OPEN</text>
<circle class="fl fl-matter" cx="148" cy="895" r="3.6" fill="#9a542e"/>
<circle class="fl fl-sense" cx="158" cy="895" r="3.6" fill="#2b5fa8"/>
</a>
<a href="matter-loop.html" class="bk on-matter on-act" aria-label="Release and reclaim">
<rect x="356" y="828" width="208" height="76" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="366" y="846" font-size="12.5" font-weight="600" fill="#173630">Release and reclaim</text>
<text x="366" y="861" font-size="10" fill="#3d4d47">crucibles: powder, liquid, seed</text>
<text x="366" y="874" font-size="10" fill="#3d4d47">removing joined material: OPEN</text>
<text x="555" y="898" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#9a542e">OPEN</text>
<circle class="fl fl-matter" cx="369" cy="895" r="3.6" fill="#9a542e"/>
<circle class="fl fl-act" cx="379" cy="895" r="3.6" fill="#166b60"/>
</a>
<a href="desktop-replicator.html#heat" class="bk on-power" aria-label="Power and heat reject">
<rect x="577" y="828" width="208" height="76" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="587" y="846" font-size="12.5" font-weight="600" fill="#173630">Power and heat reject</text>
<text x="587" y="861" font-size="10" fill="#3d4d47">USB-C in → {{c:haptic_pzt.bridge_rail_v}} V, 5 V, 3.3 V</text>
<text x="587" y="874" font-size="10" fill="#3d4d47">17.0 W · air path outside chamber</text>
<text x="776" y="898" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#166b60">DERIVED</text>
<circle class="fl fl-power" cx="590" cy="895" r="3.6" fill="#a8323a"/>
</a>
<g class="fl fl-sense fl-act" stroke="#2b5fa8" stroke-width="2.6" fill="none"><path d="M452 920 V943" marker-end="url(#ms-sense)"/><path d="M468 946 V923" marker-end="url(#ms-sense)"/></g>
<text class="fl fl-sense fl-act" x="442" y="937" font-size="10" text-anchor="end" fill="#2b5fa8" font-weight="600">USB-C tether · down: frames, goal packet (1,556 B), calibration (≤ 43.3 kB)</text>
<text class="fl fl-sense fl-act" x="478" y="937" font-size="10" fill="#2b5fa8" font-weight="600">up: recorded echoes and optical readings</text>
<rect x="120" y="950" width="680" height="112" rx="12" fill="#fffefa" stroke="#173630" stroke-width="1.5" stroke-dasharray="6 4"/>
<text x="135" y="971" font-size="12.5" font-weight="700" letter-spacing=".6" fill="#173630">WORKSTATION (OFF THE MACHINE)</text>
<text x="135" y="986" font-size="10" fill="#3d4d47">plans, trains and keeps the record · the machine is meant to keep running when unplugged</text>
<a href="digital-twin.html" class="bk on-act on-sense" aria-label="Digital twin and planner">
<rect x="135" y="996" width="208" height="56" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="145" y="1014" font-size="12.5" font-weight="600" fill="#173630">Digital twin and planner</text>
<text x="145" y="1029" font-size="10" fill="#3d4d47">CAD · field models · equation → frames</text>
<text x="334" y="1046" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#166b60">SIMULATED</text>
<circle class="fl fl-act" cx="148" cy="1043" r="3.6" fill="#166b60"/>
<circle class="fl fl-sense" cx="158" cy="1043" r="3.6" fill="#2b5fa8"/>
</a>
<a href="cadence-memory.html" class="bk on-sense" aria-label="Prime training">
<rect x="356" y="996" width="208" height="56" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="366" y="1014" font-size="12.5" font-weight="600" fill="#173630">Prime training</text>
<text x="366" y="1029" font-size="10" fill="#3d4d47">world model · verifier-gated updates</text>
<text x="555" y="1046" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#166b60">SIMULATED</text>
<circle class="fl fl-sense" cx="369" cy="1043" r="3.6" fill="#2b5fa8"/>
</a>
<a href="evidence.html" class="bk " aria-label="Evidence ledger">
<rect x="577" y="996" width="208" height="56" rx="7" fill="#fffefa" stroke="#173630" stroke-width="1.2"/>
<text x="587" y="1014" font-size="12.5" font-weight="600" fill="#173630">Evidence ledger</text>
<text x="587" y="1029" font-size="10" fill="#3d4d47">labels, gates and published basis</text>
<text x="776" y="1046" font-size="8.3" letter-spacing=".4" text-anchor="end" fill="#166b60">DOCUMENTED</text>
</a>
<text x="120" y="1088" font-size="10.5" font-weight="700" fill="#173630">FLOWS</text>
<g class="fl fl-matter"><path d="M176 1084 H200" stroke="#9a542e" stroke-width="3"/><text x="206" y="1088" font-size="10.5" fill="#9a542e" font-weight="600">Matter and return</text></g>
<g class="fl fl-act"><path d="M334 1084 H358" stroke="#166b60" stroke-width="3"/><text x="364" y="1088" font-size="10.5" fill="#166b60" font-weight="600">Actuation</text></g>
<g class="fl fl-sense"><path d="M492 1084 H516" stroke="#2b5fa8" stroke-width="3"/><text x="522" y="1088" font-size="10.5" fill="#2b5fa8" font-weight="600">Sensing and telemetry</text></g>
<g class="fl fl-power"><path d="M650 1084 H674" stroke="#a8323a" stroke-width="3"/><text x="680" y="1088" font-size="10.5" fill="#a8323a" font-weight="600">Power and heat</text></g>
<text x="120" y="1108" font-size="10.5" font-weight="700" fill="#173630">LABELS</text>
<text x="176" y="1108" font-size="10.5" fill="#3d4d47">DESIGN decision · DOCUMENTED external source · DERIVED calculation · SIMULATED project model</text>
<text x="176" y="1124" font-size="10.5" fill="#3d4d47"><tspan fill="#9a542e" font-weight="600">OPEN</tspan> not settled · no block in this diagram is MEASURED</text>
</svg>
<!-- MASTER_STACK:END -->
<p>Master subsystem block diagram. Choose a flow to isolate it. Every block opens its subsystem guide. The stack is drawn as ruled on 24 November 2026; the parts named are those of the current Desktop Replicator model, whose CAD still carries the material store behind the tower rather than under the chamber.</p>
</div>

The diagram shows where things are, and what crosses between them. It does not show a sequence: the three operations in the work volume share one space and a recipe can overlap them. The prototype fits the acoustic column and optical sensing only; the electric and magnetic block is empty by default.

## Three zones

| Zone | What it holds | What fixes its size | Evidence |
|---|---|---|---|
| Upper build cylinder | Two facing acoustic wafers {{c:desktop_geometry.gap_mm}} mm apart, the optical ring, the glass wall, the work volume | The stock glass tube ({{c:desktop_geometry.glass_cylinder_id_od_mm|x}} mm inside and outside diameter) and the plate spacing | Design decision; acoustics Simulated |
| Mid-plane | The lower wafer and the flat annulus round it, which reflect sound back up; the gate that lets material up from the plinth; the thermal barrier under the chamber floor | The end reflection the lift needs, and the route material can take without cutting the wafer or the glass | Simulated requirement; layout Open |
| Lower plinth | Material store on weigh cells, release and reclaim, the lower drive board, clock and bus, the compute card, power conversion, the cooling air path | The store volume and the electronics, not the acoustics | Design decision of 24 November 2026; CAD pending |

The mid-plane is the one place where two requirements meet on a single part. Sound wants an uninterrupted, hard, flat end. Material wants a way through it. Two layouts are being compared in simulation before any hardware is cut: a sealed undrilled wafer inside a hard annulus with retractable feed ports round its edge, and one continuous tall cylinder of about 440 to 480 mm with a perforated or retractable separator at mid-height.

## Four flows and their budgets

The four colours in the diagram are the four things that cross subsystem boundaries. The figures are those of the Desktop Replicator.

| Flow | What it carries | Voltage or level | Bandwidth | Power | Latency | Evidence |
|---|---|---|---|---|---|---|
| Matter and return | Feedstock from the store to the work volume and unwanted material back | Neutral grains and droplets only; at most {{c:electrostatics_and_matter_loop.max_bead_charge_pc}} pC per bead; air at {{c:electrostatics_and_matter_loop.chamber_ambient_rh_pct_range|range}} % relative humidity | One Ø1.6 mm liquid line; solids have no automated path | Not applicable | Not yet budgeted | Derived; solids path Open |
| Actuation (sound) | Twelve drive signals from the two boards to the piezo discs | {{c:haptic_pzt.bridge_rail_v}} V bridge supply; up to {{c:haptic_pzt.max_drive_v_peak_single_tone}} V peak on one tone, {{c:haptic_pzt.max_drive_vrms_5tone_per_tone}} V rms per tone when five share the supply | Tones at {{c:desktop_geometry.comb_tones_hz|khz}} kHz; timing step {{c:clock_and_bus.pio_tick_ns}} ns | 0.78 W per channel at the worst pattern, 10.9 W for 14 channels | Pattern repeats every {{c:clock_and_bus.transmit_ring_us}} µs; one frame is 10 ms; the network settles in {{c:cadence_brain.rp2350_settle_target_ms_range|range}} ms (target) | Derived; lift Simulated |
| Actuation (light, EM) | Laser illumination for sensing; no electric or magnetic drive is fitted | {{c:mosquito_smi.total_ommatidia}} lasers at {{c:mosquito_smi.laser_wavelength_nm}} nm, at most 5 mW each, on the 3.3 V supply | Not applicable | 2.0 W for the lasers | Not applicable | Derived; laser class Open |
| Sensing and telemetry | Echo on the drive wires, optical readings, air temperature, humidity, store weight | 16-bit converter ({{c:haptic_pzt.adc_fallback_mpn}}) behind a one-twentieth tap; echo floor 6.3 mV at the disc | Receive band {{c:haptic_pzt.ultrasonic_bw_hz|khz}} kHz; board bus 75 Mbit/s inside a design range of {{c:clock_and_bus.spinal_bus_mbps_range|range}} Mbit/s | 0.33 W per board for the converters | One {{c:clock_and_bus.capture_burst_us}} µs capture per 10 ms frame; demodulating 8 channels takes 4 ms; a calibrated read takes 2.3 ms | Derived from instruction counts; converter choice Simulated |
| Power and heat | Supply in, heat out | USB-C inlet converted to {{c:haptic_pzt.bridge_rail_v}} V, 5 V and 3.3 V | Not applicable | 17.0 W with the first compute card, 22.5 W with the second | Not applicable | Derived from candidate-part datasheets |
| Timing (shared) | One clock and one frame-start signal to every board | {{c:clock_and_bus.xin_hz|mhz}} MHz | Not applicable | Not applicable | At most {{c:clock_and_bus.sync_skew_max_ns}} ns difference between boards | Derived |

Two budgets constrain the layout more than the rest.

- **Heat.** The chamber floor must not be warmer than its ceiling, or the air overturns and drags on levitated material. The thermal model predicts a ceiling 1.9 K warmer than the floor with thermal pads on the lower board only (Derived, eleven-node model). No cooling air passes through the work volume.
- **Lift.** One 160 kHz tone on the full supply lifts about 1.2 times the weight of a foam bead; five tones sharing the supply lift about 7 % of it (Simulated). Lifting and field shaping therefore alternate, and the lift depends on an axial resonance of the gap that the machine has to hold ([Subsystems](subsystems.html#s05-gap-actuator-and-resonance-lock)).

## Long-term architecture and the Desktop Replicator

This is the handbook's single comparison of what is being designed first, what is still being traded, and where the programme is going. The first column is the current prototype design. The second lists the alternatives that have been modelled or ruled on. The third is the final machine, a research direction whose integration is Open throughout; it is set out in [The long-term machine](ultimate-replicator.html). The last column is the test that has to pass before the prototype part is replaced. Where no test has been fixed, the cell says so.

| Subsystem | Prototype 1 (Desktop, coaxial) | Engineering options and trade space | Final machine | Gate that triggers the swap |
|---|---|---|---|---|
| [Chamber and stack topology](subsystems.html#s01-chamber-and-stack-topology) | Build cylinder closed by a stock glass tube, {{c:desktop_geometry.gap_mm}} mm between two plates, lifting {{c:desktop_geometry.lift_stroke_mm}} mm with the head, over a coaxial plinth. *Design decision; plinth CAD pending* | Open-fronted chamber with no lift; rotating glass door; the small `boro12` plate pair ({{c:desktop_geometry.boro12_reducer_wafer_mm}} mm wafers, {{c:desktop_geometry.boro12_gap_mm}} mm gap) in the same frame | Same two zones at Ø0.9 m: a barrel head with 62 ports on a Ø1.24 × 0.55 m plinth. An icosahedral shell with 12 three-field ports is the isotropic limit. *Derived concept geometry* | A measured test of whether 12 ports are sufficient. If it fails, the barrel is the reference geometry. *Open* |
| [Storage and release plinth](subsystems.html#s02-storage-and-release-plinth) | Three 500 mL stock bottles on three load cells, a reversible metering pump, one Ø1.6 mm liquid line; three open crucibles in the chamber; solids dosed by hand with the head raised. *Derived CAD; pump and cells Open* | Store docked behind the tower (modelled 23 November) against a plinth under the build chamber (ruled 24 November). For solids: a raised glass seat with screw feeders, or powder carried as a suspension in the liquid line | Release bin, a store that keeps stock by species, and a loop bus that carries binding energy from release to write. *Derived; the store beyond ordinary condensed stock is Open* | Mass in the part plus mass in the store constant through a build, on the weigh cells. *No threshold fixed* |
| [Mid-plane interface](subsystems.html#s03-mid-plane-interface) | The undrilled lower wafer and a flat annulus round it reflect sound; liquid rises through the deck between the wafer socket and the glass bore. *Design decision* | Sealed wafer inside a hard annulus with retractable annular feed ports, against one continuous tall cylinder (about 440 to 480 mm) with a perforated or retractable separator. *Simulation in progress* | No plate in the way: the object is written in free levitation from ports on the boundary. *Derived concept* | End reflection of at least 0.85, measured with an empty chamber by sweeping one source across the gap resonance. *Simulated requirement; measurement Open* |
| [Acoustic array](subsystems.html#s04-acoustic-array) | {{c:desktop_geometry.ports_per_plate}} piezo discs (PZT-8, Ø{{c:desktop_geometry.pzt_diameter_mm}} × {{c:desktop_geometry.pzt_thickness_mm}} mm) behind each of two undrilled Ø{{c:desktop_geometry.wafer_diameter_mm}} mm wafers, 12 in all, on an {{c:haptic_pzt.bridge_rail_v}} V supply. Foam-bead margin 1.19 at the median gap, 0.87 at the worst. *Simulated* | 12 against 36 sources: 18 smaller discs per plate on a 24 V supply raise the margin to 1.60 and hold it at the worst gap (1.27). A field free of unwanted traps needs 113 V with 12 sources and 30.5 V with 36, against 22.9 V available: neither reaches it | Continuous piezo film with about 100,000 optically switched elements and no per-element wiring. *Documented components; integration Open* | Unwanted-trap volume under 2.0 % at twice the 12-source focal pressure, with under 3.0 W of bridge loss at 160 kHz. Skipped if 12 sources pass the lift and clean-trap test on the bench. *Open* |
| [Gap actuator and resonance lock](subsystems.html#s05-gap-actuator-and-resonance-lock) | Hold the ratio of gap to sound speed constant: 0.41 mm per kelvin, to ± 0.07 mm. An actuator with ± 1 mm travel in 0.02 mm steps is specified. *Simulated need; not yet in CAD or firmware* | Find the set point from an optical reading or from a one-source sweep of the resonance; without an actuator, recalibrate after every head lift and every few tenths of a kelvin | One clock phase-locks every port and the boundary reads the field back. *Derived concept* | The measured resonance width and lift in an empty chamber agree with the simulated law. *Open* |
| [Optical tomography](subsystems.html#s06-optical-tomography) | {{c:mosquito_smi.total_ommatidia}} self-mixing laser diodes at {{c:mosquito_smi.laser_wavelength_nm}} nm give a shadow image and an optical reading of the sound field; in simulation they track air temperature to 0.0005 K and gap to 0.28 µm. *Simulated* | A one-stage or two-stage amplifier (one stage rolls off at about 100 kHz, below the top tone); replicated diffractive strips on the windows | Optically addressed surfaces, structured pulses, tomography, fine optical traps; X-ray absorption edges for shielded parts. *Documented components; integration Open* | Diffractive strips at least double the effective rank of the optical reading in the calibrated chamber. *Open* |
| [Electromagnetics and consolidation](subsystems.html#s07-electromagnetics-and-consolidation) | No electric or magnetic drive. Joining is an addressed heating step that exists only as a model. *Simulated; recipe Open* | A twelve-arm conductor spiral on the wafer; a pulsed ring coil of {{c:dissolve_and_toroidal.compact_toroid_collar_id_mm_range|range}} mm at one crucible. Large coils across the chamber are ruled out. *Simulated* | Ports that combine sound, light and electromagnetic fields; binding energy returned to the loop as a coherent wave. *Open: this needs physics not yet demonstrated* | A second bead placed within 0.25 mm of a held first bead, and a joint that holds ten times the trapping force in shear. *Open* |
| [Control and firmware](subsystems.html#s08-control-and-firmware) | Six microcontrollers on {{c:clock_and_bus.pcb_count}} field boards and a plug-in compute card, one {{c:clock_and_bus.xin_hz|mhz}} MHz clock, {{c:haptic_pzt.adc_fallback_mpn}} receive converters. Firmware source passes its tests on a workstation and has never run on a board. *Simulated* | The 1-bit receive converter reached {{c:haptic_pzt.sfdr_simulated_dbc}} dB against a {{c:haptic_pzt.sfdr_gate_min_db}} dB requirement and is replaced. Compute card 1 (microcontroller) against card 2 (gate array, 5 W ceiling) | Wave-based computing in optical or excitable soft-matter wave substrates, using little electrical power. *Documented components; integration Open* | A swapped card reproduces the reference network's output with cosine similarity of at least 0.90 on the same job suite, and settles within 5 µs. *Open* |
| [Prime world model](subsystems.html#s09-prime-world-model) | Prime, the project's model built on the Cadence library: a sparse network in under {{c:cadence_brain.cadence_sparse_max_kb}} kB on the card, reading the chamber through a calibration image that is replaced after every calibration. *Simulated* | Chamber response fixed in flash against a live calibration image (42 to 50 % against 99.9 to 100 % of sites read correctly after a 0.3 K change). Drawing by retrieve-then-refine against multi-task fine-tuning. Rule-only self-edits against verifier-gated gradient updates | The network's settling carried out by a physical wave medium; object descriptions held in a photorefractive crystal. *Documented components; integration Open* | Same test as the compute card swap. *Open* |
| [Metrology and calibration](subsystems.html#s10-metrology-and-calibration) | In the assembled chamber, with removable Ø1 to 2 mm spheres: a frequency sweep, a phase reference between the plates, air temperature to {{c:desktop_geometry.air_temp_tolerance_k}} K. Repeated after every head lift. *Simulated procedure* | Calibrate with a bead echo, or with no bead from the optical ring and the symmetry of the source-to-source response (78 pairs in place of 144) | Full-aperture acoustic and optical scattering measurement with reference objects; the whole machine stands on a balance. *Derived concept* | Phase within {{c:desktop_geometry.calibration_phase_tol_deg}}° and gain within {{c:desktop_geometry.calibration_gain_tol_pct}} %; sphere placement repeatable to 0.3 mm over ten runs. *Open* |
| [Thermal and quench safety](subsystems.html#s11-thermal-and-safety) | 17.0 W in total; cooling air rises through the tower, outside the chamber; ceiling held warmer than floor; a switch removes bridge and laser power when the head is up; glass bending stress limited to {{c:desktop_geometry.plate_bending_stress_limit_mpa}} MPa. *Derived; laser class Open* | Thermal pads on the lower board only, an insulated baffle, an optional guard heater at about 0.8 K per watt | A 39-litre water annulus holding 8.2 MJ, sized above the 5.3 MJ released if energy recapture fails during a write. *Derived* | A dump at least as large as the stored loop energy exists before any experiment stores that energy. *Derived rule* |

Three things in this table are easy to misread.

1. **The prototype electronics are scaffolding.** Microcontrollers, converters and discrete lasers are what can be bought now. They are not a small version of the final design, and each sits behind an interface so that it can be replaced without redesigning the machine.
2. **A gate is a measurement.** A prototype part is replaced when the test in the last column passes on the machine, not when a simulation says it should. Every gate is Open, because each needs an assembled, calibrated chamber.
3. **Some swaps may never happen.** The 36-source plates are skipped if 12 sources pass on the bench. The list of prototype steps that can be deleted, and the test that deletes each, is kept with the long-term bounds model.

## Interfaces that survive upgrades

A module can be replaced without redesigning the machine because what crosses each interface is fixed. Every module declares its identity and revision, its position in the shared coordinate frame, its signal, power and optical ports with their limits, and whether its response data is a made-up reference, simulated or measured. Seven contracts carry most of the weight.

| Contract | Kind | What it fixes | What can change behind it |
|---|---|---|---|
| `holo-eq/0.2`, `holo-eq/0.3-mm` | File | An object described about its own centre: the field it needs and how it scatters; in the later version, its materials | The chamber, the number of sources, the air temperature |
| `.fcode` | File and wire | Time-ordered frames: one set of drive values, a duration, a verb and the channels to record | Emulator or hardware; the compute card |
| `HLEQ v1` | Wire | The goal packet to the on-board network: 1,556 bytes for six strokes, with a checksum | The object, without rewriting the network |
| `LMQ8 v1` | Wire, held in memory | The chamber's calibration as the network sees it: up to 43,296 bytes, replaced after every calibration | Temperature, gap, the plates themselves |
| `body-response/0.2` | File | How each drive input moves each patch of the radiating faces at each tone, and how the face is heard back | The plates and sources: the present wafers, 36 sources, a future optically addressed surface |
| Drive port and enable groups | Electrical | Two bridge outputs per disc, three enable groups per board, enable low is high impedance | The driver part, the supply voltage up to the driver's limit |
| Clock, bus and environment | Electrical | One {{c:clock_and_bus.xin_hz|mhz}} MHz clock with a frame-start signal; the board bus; I²C for air temperature and humidity | Boards, controllers, sensors |

The full interface control matrix, with every contract's exact fields, limits and open points, is in [Subsystems and interfaces](subsystems.html#interface-control-matrix). The compute card socket and the mechanical datums for the wafers, the glass tube and the head are listed there too.

## What has been deleted

A design improves as much by what is removed as by what is added. Parts and baselines that were tried in design or simulation and then removed are logged, with the finding that removed each, in [Subsystems and interfaces](subsystems.html#deleted-parts-and-retired-baselines). The earlier machine baselines that the Desktop Replicator replaced are in [Desktop Replicator](desktop-replicator.html#what-this-design-replaced).

## One work volume, coordinated fields

Each field is given the job its physics suits.

- **Sound** applies force. Acoustic radiation pressure holds and moves feedstock at millimetre scale. See [Acoustics](acoustics.html).
- **Light** measures, and in the long-term design addresses fine detail: wavefront readout, curing exposure and sub-micrometre trapping. See [Optics](optics.html).
- **Electric and magnetic fields** act selectively on conducting or magnetic material: force, torque or local heating. See [Electromagnetics](electromagnetics.html).

Optics is electromagnetic physics; the two modules are named separately because their frequency bands and hardware differ. The fields share a coordinate frame and a time base. Sound and light are not phase-locked to each other unless a measurement deliberately locks them.

## Two carriers, five wavelength decades and volume crossings

Sound is the better carrier of force and light is the better carrier of information. Both follow from their speeds: 3 × 10⁸ m/s for light, about 343 m/s for sound in air and about 5,000 m/s in solids.

**Force per watt (Derived).** A wave of power P that is fully absorbed pushes with a force P divided by its speed. One watt of light gives 3.3 nN. One watt of sound in air gives 2.9 mN, close to a million times more.

**Wavelength (Derived).** At the same frequency, sound has a wavelength about a million times shorter than light, so ordinary electronics at kilohertz to megahertz frequencies produce millimetre-scale acoustic features.

| Frequency | Light | Sound in air | Sound in a solid | What it means for the machine |
|---|---|---|---|---|
| 1 kHz | 300 km | 343 mm | 5 m | Room-scale acoustic modes |
| 100 kHz | 3 km | 3.4 mm | 50 mm | The prototype's band: millimetre features in air |
| 1 MHz | 300 m | 0.34 mm | 5 mm | Sub-millimetre features in gas or melt |
| 1 GHz | 300 mm | 0.34 µm | 5 µm | Sound in solids nears optical wavelengths; acousto-optic devices work here and above |

**Degrees of freedom (Derived).** Light has two polarisation states and can carry orbital angular momentum. Sound in a fluid has one wave type, longitudinal. In a solid it has three, plus surface and plate waves whose speed can be engineered. When sound and light interact, energy, momentum and angular momentum are each conserved.

### Cross-carrier verbs inside the work volume

Sound and light also act on each other inside the gas or melt. These interactions address, trim and cross-check. They never move bulk power from one carrier to the other.

| Interaction | Mechanism | Use in the machine | Evidence |
|---|---|---|---|
| Light reads sound | Pressure changes the refractive index of air, which shifts the phase of a beam passing through | Optical measurement of the real sound field, independent of the acoustic sensors | Documented effect; in-chamber performance Open |
| Sound trims light | A sound field acts as a weak, fast, graded-index lens | Fine steering in air; real beam shaping needs a liquid or melt at high pressure | Documented in acousto-optic modulators; melt shaping Open |
| Light writes sound | Patterned light absorbed on a surface heats it and launches sound | A reprogrammable sound source on any lit surface, with no moving parts | Documented effect; in-chamber use Open |
| Phonon to photon | Coherent coupling in optomechanical cavities | Signal hand-over inside solid interfaces | Documented components; integration Open |

**Worked number for "light reads sound" (Derived).** For the prototype's {{c:mosquito_smi.laser_wavelength_nm}} nm lasers the phase shift is {{c:mosquito_smi.lightread_coef_rad_per_pa_m}} radians per pascal per metre of path. A beam that crosses 100 mm of sound field at a pressure amplitude of 1 kPa, in phase along the whole path, shifts by 1.9 radians, or 0.3 of a wave, in a single pass. The return pass to the laser doubles it. This is an upper bound: the acoustic wavelength at the prototype's tones is 11 to 2 mm, so a real beam crosses many pressure maxima and minima that partly cancel. The figure of 1.38 waves at 155 dB quoted in earlier material assumed 500 nm light and a uniform 300 mm path, longer than any path in the Desktop Replicator.

For "sound trims light", water at equal pressure changes its refractive index less than air does (about 5 × 10⁻⁷ against 7 × 10⁻⁶ at 3.5 kPa), because it is far stiffer. Liquids help only because they tolerate much higher pressures.

[Manufacturing](manufacturing.html) covers the process and [Digital twin](digital-twin.html) the tooling. Terms are defined in the [Glossary](glossary.html).
