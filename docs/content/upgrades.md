# The upgrade loop

<div class="lead">One machine, eight swappable modules. Each module gets better in three steps, and a step is only taken when a test passes. This page shows what swaps, what stays fixed, and how much of each step is real.</div>

The Desktop Replicator, revision S (Rev S), is the one master platform. Nothing is rebuilt from scratch. The frame, the seats and the file formats stay fixed, and the module that limits performance is swapped for a better one. The plan is searched forward from what an affordable [Desktop Replicator](desktop-replicator.html) can do, and backward from the long-term design in [Architecture](architecture.html). Cheap models explore, an independent model checks, and a measurement settles what models cannot ([automated design search](digital-twin.html#automated-design-search)). Progress is scored as new abilities and settled questions per hour of human setup (Design decision).

## How to read the upgrade map

Every module has three rungs.

- **Rung 1** is the design today.
- **Rung 2** is the next swap, with the same seat and the same size.
- **Rung 3** is the target if the physics allows it.

Each rung carries a badge, so what exists is never mixed up with what is hoped for.

| Badge | Meaning |
|---|---|
| <span class="bd bd-derived">Derived</span> | A calculation, or a CAD result, with stated assumptions |
| <span class="bd bd-sim">Simulated</span> | A result from a specified project model, including firmware tested on a workstation |
| <span class="bd bd-doc">Documented</span> | Reported by an identified outside source. The result belongs to its authors |
| <span class="bd bd-dec">Design decision</span> | A direction the programme has chosen. Not proved |
| <span class="bd bd-open">Open</span> | Not settled by calculation, simulation or measurement |
| <span class="bd bd-claim">Claim</span> | A target nobody has shown works here |

**No module has a Measured badge.** No part has been bought, built or weighed. Rung 1 means "designed, and checked in CAD or simulation", not "built".

## The Rev S master platform, pulled apart

<!-- generated:exploded:begin -->
<div class="diagram">
<svg viewBox="0 0 1010 740" role="img" aria-labelledby="ex-t ex-d" xmlns="http://www.w3.org/2000/svg" font-family="system-ui,sans-serif">
<title id="ex-t">Rev S pulled apart into the eight modules M01 to M08</title>
<desc id="ex-d">A side view of the Rev S machine pulled apart along its vertical axis. From top to bottom: the head shell (M07), the ceiling plate stack (M01), the glass build cylinder with six rear panels (M05), the mid-plane cassette (M01), the storage bucket (M06), the floor plate stack (M01) and the plinth with the compute bay (M03) and memory bay (M04). On the right a rear spine with the lift and two hard stops (M07), a service channel (M02) that runs up beside it, and sensor and safety points (M08).</desc>
<rect x="0" y="0" width="1010" height="740" fill="#fffefa"/>
<g transform="translate(70 0)">
<line x1="330" y1="22" x2="330" y2="722" stroke="#9fb3a8" stroke-width="1.2" stroke-dasharray="3 6"/>
<text x="330" y="16" text-anchor="middle" font-size="12" fill="#68736b">same axis and same seats: every module swaps in place</text>
<a href="#m07" aria-label="M07 Chassis, lift and spine"><rect x="215" y="34" width="230" height="46" rx="12" fill="#e8ebed" stroke="#55616b" stroke-width="1.6"/><text x="330" y="62" text-anchor="middle" font-size="14" fill="#2f3d46">Head shell and top cap</text></a>
<a href="#m01" aria-label="M01 Boundary stacks"><ellipse cx="330" cy="140" rx="112" ry="17" fill="#e3efe9" stroke="#186b60" stroke-width="1.8"/><ellipse cx="330" cy="135" rx="112" ry="17" fill="#fff" stroke="#186b60" stroke-width="1.8"/><text x="330" y="139" text-anchor="middle" font-size="13" fill="#173630">Stack 3 ceiling plate</text></a>
<rect x="225" y="190" width="210" height="150" rx="6" fill="#eaf3f6" fill-opacity=".75" stroke="#8aa9b5" stroke-width="1.5"/>
<text x="330" y="356" text-anchor="middle" font-size="12" fill="#68736b">glass build cylinder (M07) with the six rear panels (M05)</text><text x="330" y="369" text-anchor="middle" font-size="12" fill="#68736b">drawn as seen from the front</text>
<a href="#m05" aria-label="M05 Six rear active panels"><rect x="240" y="204" width="22" height="122" rx="3" fill="#f3ecd5" stroke="#8f6d10" stroke-width="1.4"/><rect x="271" y="204" width="22" height="122" rx="3" fill="#f3ecd5" stroke="#8f6d10" stroke-width="1.4"/><rect x="302" y="204" width="22" height="122" rx="3" fill="#f3ecd5" stroke="#8f6d10" stroke-width="1.4"/><rect x="333" y="204" width="22" height="122" rx="3" fill="#f3ecd5" stroke="#8f6d10" stroke-width="1.4"/><rect x="364" y="204" width="22" height="122" rx="3" fill="#f3ecd5" stroke="#8f6d10" stroke-width="1.4"/><rect x="395" y="204" width="22" height="122" rx="3" fill="#f3ecd5" stroke="#8f6d10" stroke-width="1.4"/></a>
<a href="#m01" aria-label="M01 Boundary stacks"><ellipse cx="330" cy="415" rx="112" ry="17" fill="#e3efe9" stroke="#186b60" stroke-width="1.8"/><ellipse cx="330" cy="410" rx="112" ry="17" fill="#fff" stroke="#186b60" stroke-width="1.8"/><text x="330" y="414" text-anchor="middle" font-size="13" fill="#173630">Stack 2 mid-plane cassette</text></a>
<text x="330" y="446" text-anchor="middle" font-size="12" fill="#186b60" font-weight="600">↑ lifts out by hand</text>
<a href="#m06" aria-label="M06 Lower bucket and feed"><rect x="228" y="462" width="204" height="86" rx="8" fill="#e4eedd" fill-opacity=".8" stroke="#3f7a28" stroke-width="1.8"/><text x="330" y="510" text-anchor="middle" font-size="14" fill="#26441a">Storage bucket (glass)</text></a>
<a href="#m01" aria-label="M01 Boundary stacks"><ellipse cx="330" cy="610" rx="112" ry="17" fill="#e3efe9" stroke="#186b60" stroke-width="1.8"/><ellipse cx="330" cy="605" rx="112" ry="17" fill="#fff" stroke="#186b60" stroke-width="1.8"/><text x="330" y="609" text-anchor="middle" font-size="13" fill="#173630">Stack 1 floor plate</text></a>
<rect x="190" y="645" width="280" height="76" rx="12" fill="#e8ebed" stroke="#55616b" stroke-width="1.6"/>
<a href="#m03" aria-label="M03 Compute core"><rect x="204" y="662" width="110" height="46" rx="6" fill="#e2e9f5" stroke="#2f5aa0" stroke-width="1.6"/><text x="259" y="689" text-anchor="middle" font-size="13" fill="#1d3a6b">compute bay</text></a>
<a href="#m04" aria-label="M04 Pattern and holographic memory"><rect x="326" y="662" width="130" height="46" rx="6" fill="#eee6f4" stroke="#7a4f9a" stroke-width="1.6" stroke-dasharray="5 3"/><text x="391" y="689" text-anchor="middle" font-size="13" fill="#4d2f66">memory bay</text></a>
<a href="#m07" aria-label="M07 Chassis, lift and spine"><rect x="504" y="70" width="24" height="650" rx="9" fill="#e8ebed" stroke="#55616b" stroke-width="1.6"/><rect x="498" y="592" width="36" height="9" rx="2" fill="#55616b"/><text x="516" y="586" text-anchor="middle" font-size="12" fill="#55616b">stops</text></a>
<a href="#m02" aria-label="M02 Interconnect and routing"><path d="M559 690 V76" stroke="#9a542e" stroke-width="3" stroke-dasharray="9 6" fill="none"/><path d="M559 610 H452" stroke="#9a542e" stroke-width="2" stroke-dasharray="4 4" fill="none"/><path d="M559 410 H452" stroke="#9a542e" stroke-width="2" stroke-dasharray="4 4" fill="none"/><path d="M559 245 H452" stroke="#9a542e" stroke-width="2" stroke-dasharray="4 4" fill="none"/><path d="M559 135 H452" stroke="#9a542e" stroke-width="2" stroke-dasharray="4 4" fill="none"/></a>
<a href="#m08" aria-label="M08 Metrology and interlocks"><circle cx="430" cy="262" r="6" fill="#a83f3f"/></a><a href="#m08" aria-label="M08 Metrology and interlocks"><circle cx="432" cy="540" r="6" fill="#a83f3f"/></a><a href="#m08" aria-label="M08 Metrology and interlocks"><circle cx="470" cy="654" r="6" fill="#a83f3f"/></a><a href="#m08" aria-label="M08 Metrology and interlocks"><circle cx="330" cy="626" r="6" fill="#a83f3f"/></a>
<defs><marker id="ar" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8 Z" fill="#186b60"/></marker></defs>
</g>
<g stroke="#b9c4bb" stroke-width="1" fill="none">
<path d="M262 53 H285"/>
<path d="M262 131 H292"/>
<path d="M262 251 H310"/>
<path d="M262 491 H298"/>
<path d="M262 661 H274"/>
<path d="M262 712 H461 V709"/>
</g>
<rect x="34" y="43" width="46" height="22" rx="11" fill="#55616b"/><text x="57.0" y="58.5" text-anchor="middle" font-size="13" font-weight="700" fill="#fff">M07</text><text x="88" y="59" text-anchor="start" font-size="15" font-weight="600" fill="#173630">Head shell</text><text x="88" y="78" text-anchor="start" font-size="13" fill="#4a5a54">moving head, 6.28 kg moves</text>
<rect x="34" y="121" width="46" height="22" rx="11" fill="#186b60"/><text x="57.0" y="136.5" text-anchor="middle" font-size="13" font-weight="700" fill="#fff">M01</text><text x="88" y="137" text-anchor="start" font-size="15" font-weight="600" fill="#173630">Boundary stacks</text><text x="88" y="156" text-anchor="start" font-size="13" fill="#4a5a54">three swappable cartridges</text>
<rect x="34" y="241" width="46" height="22" rx="11" fill="#8f6d10"/><text x="57.0" y="256.5" text-anchor="middle" font-size="13" font-weight="700" fill="#fff">M05</text><text x="88" y="257" text-anchor="start" font-size="15" font-weight="600" fill="#173630">Rear active panels</text><text x="88" y="276" text-anchor="start" font-size="13" fill="#4a5a54">six strips inside the glass</text>
<rect x="34" y="481" width="46" height="22" rx="11" fill="#3f7a28"/><text x="57.0" y="496.5" text-anchor="middle" font-size="13" font-weight="700" fill="#fff">M06</text><text x="88" y="497" text-anchor="start" font-size="15" font-weight="600" fill="#173630">Lower bucket and feed</text><text x="88" y="516" text-anchor="start" font-size="13" fill="#4a5a54">holds the matter to build from</text>
<rect x="34" y="651" width="46" height="22" rx="11" fill="#2f5aa0"/><text x="57.0" y="666.5" text-anchor="middle" font-size="13" font-weight="700" fill="#fff">M03</text><text x="88" y="667" text-anchor="start" font-size="15" font-weight="600" fill="#173630">Compute core</text><text x="88" y="686" text-anchor="start" font-size="13" fill="#4a5a54">plug-in card on the plinth</text>
<rect x="34" y="702" width="46" height="22" rx="11" fill="#7a4f9a"/><text x="57.0" y="717.5" text-anchor="middle" font-size="13" font-weight="700" fill="#fff">M04</text><text x="88" y="718" text-anchor="start" font-size="15" font-weight="600" fill="#173630">Pattern memory</text><text x="88" y="737" text-anchor="start" font-size="13" fill="#4a5a54">bay still being drawn (#132)</text>
<rect x="700" y="300" width="46" height="22" rx="11" fill="#55616b"/><text x="723.0" y="315.5" text-anchor="middle" font-size="13" font-weight="700" fill="#fff">M07</text><text x="754" y="316" text-anchor="start" font-size="15" font-weight="600" fill="#173630">Rear spine, lift and stops</text><text x="754" y="335" text-anchor="start" font-size="13" fill="#4a5a54">brake-free: rests on 240.00 mm stops</text>
<rect x="700" y="420" width="46" height="22" rx="11" fill="#9a542e"/><text x="723.0" y="435.5" text-anchor="middle" font-size="13" font-weight="700" fill="#fff">M02</text><text x="754" y="436" text-anchor="start" font-size="15" font-weight="600" fill="#173630">Service channel</text><text x="754" y="455" text-anchor="start" font-size="13" fill="#4a5a54">copper now, fibre next, none last</text>
<rect x="700" y="540" width="46" height="22" rx="11" fill="#a83f3f"/><text x="723.0" y="555.5" text-anchor="middle" font-size="13" font-weight="700" fill="#fff">M08</text><text x="754" y="556" text-anchor="start" font-size="15" font-weight="600" fill="#173630">Sensors and safety</text><text x="754" y="575" text-anchor="start" font-size="13" fill="#4a5a54">dots: air, camera, switch, echo test</text>
</svg>
<p>The Rev S machine pulled apart along its axis. Click a coloured label or shape to jump to that module's swap card. The picture is a schematic, not to scale. The 3D model on the <a href="cad-3d.html">CAD page</a> has the real geometry.</p>
</div>
<!-- generated:exploded:end -->

The eight modules are:

| Module | Plain name | What it does |
|---|---|---|
| M01 | Boundary stacks | The three sound plates: floor, mid-plane cassette and ceiling |
| M02 | Interconnect and routing | Carries power, timing and data up the machine |
| M03 | Compute core | The controller and the larger network card |
| M04 | Pattern and holographic memory | Stores the shapes the machine can make |
| M05 | Six rear active panels | Reflect sound now, project light later |
| M06 | Lower bucket and feed | Holds and returns the matter |
| M07 | Chassis, lift and spine | The frame, the lift and the stops |
| M08 | Metrology and interlocks | Listens, measures and keeps the machine safe |

You can pick any module in the [3D model](cad-3d.html) and see where it sits. The module map comes from the founder ruling INS-47. The tagged CAD export that assigns every part to a module is task #132. Until it lands, the 3D page groups parts with rules of its own, and M04 has no drawn part yet.

## The zero-cables ladder (M02)

The last machine has no electrical cable. It gets there in three steps, and each step keeps the same channel up the spine.

<!-- generated:ladder:begin -->
<div class="diagram">
<svg viewBox="0 0 900 400" role="img" aria-labelledby="lad-t lad-d" xmlns="http://www.w3.org/2000/svg" font-family="system-ui,sans-serif">
<title id="lad-t">The zero-cables ladder for module M02</title>
<desc id="lad-d">Three panels show the same machine skeleton, a plinth at the bottom, a spine and, at the top, the stacks and rear panels. In Rung 1 a copper loop and pogo pins link them. In Rung 2 a tube of optical fibres links them. In Rung 3 there is no cable: small optical waveguide chips pass light across gaps.</desc>
<rect width="900" height="400" fill="#fffefa"/>
<rect x="12" y="12" width="280" height="376" rx="10" fill="#f7f7f2" stroke="#dce1d7"/>
<text x="26" y="38" font-size="16" font-weight="700" fill="#9a542e">Rung 1 · copper</text>
<text x="26" y="56" font-size="13" fill="#68736b">Derived (CAD)</text>
<rect x="36" y="300" width="90" height="38" rx="6" fill="#e2e9f5" stroke="#2f5aa0" stroke-width="1.4"/><text x="81" y="323" text-anchor="middle" font-size="13" fill="#1d3a6b">plinth bays</text>
<rect x="162" y="84" width="104" height="34" rx="6" fill="#e3efe9" stroke="#186b60" stroke-width="1.4"/><text x="214" y="105" text-anchor="middle" font-size="13" fill="#173630">stacks M01</text>
<rect x="162" y="170" width="104" height="34" rx="6" fill="#f3ecd5" stroke="#8f6d10" stroke-width="1.4"/><text x="214" y="191" text-anchor="middle" font-size="13" fill="#5c4609">panels M05</text>
<rect x="162" y="250" width="104" height="34" rx="6" fill="#e3efe9" stroke="#186b60" stroke-width="1.4"/><text x="214" y="271" text-anchor="middle" font-size="13" fill="#173630">stacks M01</text>
<rect x="142" y="76" width="8" height="262" rx="3" fill="#dfe3e6" stroke="#9aa6ad"/>
<text x="138" y="214" text-anchor="end" font-size="12" fill="#68736b">spine</text>
<rect x="308" y="12" width="280" height="376" rx="10" fill="#f7f7f2" stroke="#dce1d7"/>
<text x="322" y="38" font-size="16" font-weight="700" fill="#2f7a72">Rung 2 · fibre bundles</text>
<text x="322" y="56" font-size="13" fill="#68736b">Design decision; link budget Open</text>
<rect x="332" y="300" width="90" height="38" rx="6" fill="#e2e9f5" stroke="#2f5aa0" stroke-width="1.4"/><text x="377" y="323" text-anchor="middle" font-size="13" fill="#1d3a6b">plinth bays</text>
<rect x="458" y="84" width="104" height="34" rx="6" fill="#e3efe9" stroke="#186b60" stroke-width="1.4"/><text x="510" y="105" text-anchor="middle" font-size="13" fill="#173630">stacks M01</text>
<rect x="458" y="170" width="104" height="34" rx="6" fill="#f3ecd5" stroke="#8f6d10" stroke-width="1.4"/><text x="510" y="191" text-anchor="middle" font-size="13" fill="#5c4609">panels M05</text>
<rect x="458" y="250" width="104" height="34" rx="6" fill="#e3efe9" stroke="#186b60" stroke-width="1.4"/><text x="510" y="271" text-anchor="middle" font-size="13" fill="#173630">stacks M01</text>
<rect x="438" y="76" width="8" height="262" rx="3" fill="#dfe3e6" stroke="#9aa6ad"/>
<text x="434" y="214" text-anchor="end" font-size="12" fill="#68736b">spine</text>
<rect x="604" y="12" width="280" height="376" rx="10" fill="#f7f7f2" stroke="#dce1d7"/>
<text x="618" y="38" font-size="16" font-weight="700" fill="#55616b">Rung 3 · no cables</text>
<text x="618" y="56" font-size="13" fill="#68736b">Claim</text>
<rect x="628" y="300" width="90" height="38" rx="6" fill="#e2e9f5" stroke="#2f5aa0" stroke-width="1.4"/><text x="673" y="323" text-anchor="middle" font-size="13" fill="#1d3a6b">plinth bays</text>
<rect x="754" y="84" width="104" height="34" rx="6" fill="#e3efe9" stroke="#186b60" stroke-width="1.4"/><text x="806" y="105" text-anchor="middle" font-size="13" fill="#173630">stacks M01</text>
<rect x="754" y="170" width="104" height="34" rx="6" fill="#f3ecd5" stroke="#8f6d10" stroke-width="1.4"/><text x="806" y="191" text-anchor="middle" font-size="13" fill="#5c4609">panels M05</text>
<rect x="754" y="250" width="104" height="34" rx="6" fill="#e3efe9" stroke="#186b60" stroke-width="1.4"/><text x="806" y="271" text-anchor="middle" font-size="13" fill="#173630">stacks M01</text>
<rect x="734" y="76" width="8" height="262" rx="3" fill="#dfe3e6" stroke="#9aa6ad"/>
<text x="730" y="214" text-anchor="end" font-size="12" fill="#68736b">spine</text>
<path d="M126 319 H146 V101 H162 M146 187 H162 M146 267 H162" stroke="#b9602f" stroke-width="4.5" fill="none" stroke-linejoin="round"/>
<circle cx="162" cy="101" r="4.5" fill="#fff" stroke="#9a542e" stroke-width="2"/>
<circle cx="162" cy="187" r="4.5" fill="#fff" stroke="#9a542e" stroke-width="2"/>
<circle cx="162" cy="267" r="4.5" fill="#fff" stroke="#9a542e" stroke-width="2"/>
<text x="26" y="362" font-size="13" fill="#33443f">Flexible copper loop and spring</text><text x="26" y="377" font-size="13" fill="#33443f">pogo pins at every cartridge rim.</text>
<path d="M422 319 H442 V101 H458 M442 187 H458 M442 267 H458" stroke="#bfe0da" stroke-width="12" fill="none" stroke-linejoin="round" stroke-linecap="round"/>
<path d="M422 316 H439 V101 H458 M439 187 H458 M439 267 H458" stroke="#1f7a6f" stroke-width="1.3" fill="none"/>
<path d="M422 318 H441 V101 H458 M441 187 H458 M441 267 H458" stroke="#1f7a6f" stroke-width="1.3" fill="none"/>
<path d="M422 320 H443 V101 H458 M443 187 H458 M443 267 H458" stroke="#1f7a6f" stroke-width="1.3" fill="none"/>
<path d="M422 322 H445 V101 H458 M445 187 H458 M445 267 H458" stroke="#1f7a6f" stroke-width="1.3" fill="none"/>
<text x="322" y="362" font-size="13" fill="#33443f">One fibre bundle in the same channel.</text><text x="322" y="377" font-size="13" fill="#33443f">Light carries clock, pages and sensing.</text>
<rect x="750" y="95" width="8" height="12" rx="2" fill="#55616b"/>
<rect x="750" y="181" width="8" height="12" rx="2" fill="#55616b"/>
<rect x="750" y="261" width="8" height="12" rx="2" fill="#55616b"/>
<rect x="718" y="313" width="8" height="12" rx="2" fill="#55616b"/>
<path d="M726 319 C744 300 748 120 750 104" stroke="#2f7a72" stroke-width="2" stroke-dasharray="3 5" fill="none"/>
<path d="M726 319 C742 290 746 210 750 190" stroke="#2f7a72" stroke-width="2" stroke-dasharray="3 5" fill="none"/>
<path d="M726 319 C738 300 744 280 750 270" stroke="#2f7a72" stroke-width="2" stroke-dasharray="3 5" fill="none"/>
<text x="618" y="362" font-size="13" fill="#33443f">Waveguide chips and small mirrors pass</text><text x="618" y="377" font-size="13" fill="#33443f">light across gaps. No cable at all.</text>
</svg>
<p>The same machine skeleton three times. Rung 1 is the CAD design. Rung 2 is a design decision whose link budget is not yet calculated. Rung 3 is a claim.</p>
</div>
<!-- generated:ladder:end -->

- **Rung 1, copper (Derived, CAD).** A flexible copper loop and spring pins carry power and data. It is simple and it can be built today.
- **Rung 2, fibre bundles (Design decision; Open).** A bundle of optical fibres, or a photonic-crystal fibre, carries the clock, hologram pages and sensing from the plinth up the spine to the rear panels and the stacks. Nobody has yet worked out how much light survives the bends and joints. That link budget is task #133. Until it exists, this rung is a plan.
- **Rung 3, no cables (Claim).** Small waveguide chips and mirrors pass light across the gaps. This is the target. It is not simulated.

## Swap cards, M01 to M08

Each card shows the three rungs side by side, with the seat that stays fixed. The same text appears next to the 3D model.

<!-- generated:cards:begin -->
<div class="mod-grid">
<section class="mod-card" id="m01" style="--mc:#186b60">
<header><span class="mod-chip">M01</span><h3>Boundary stacks</h3></header>
<p class="mod-kid">The flat glass plates that make the sound. There are three: floor, middle and ceiling. Each is a cartridge you can lift out and swap.</p>
<div class="mod-rungs">
<div class="mod-rung r1"><span class="mod-rn">Rung 1 · Today</span><span class="bd bd-derived">Derived</span><span class="bd bd-sim">Simulated</span><p>An undrilled Ø200 mm Borofloat wafer (1 mm thick, with 2 mm as the water option), six Ø16 mm PZT-8 discs and a haptic board, in a Ø238 mm cartridge with rim pogo pins. The sealed mid-plane cassette reaches 1.9 to 2.4 times a foam bead&#x27;s weight in simulation. The steel-dot grating RG-1 was killed (1.08 times against 1.3 needed). A 2 mm wafer gives 3.6 to 3.8 times the pressure per volt in water at 32 and 64 kHz.</p></div>
<div class="mod-rung r2"><span class="mod-rn">Rung 2 · Next</span><span class="bd bd-dec">Design decision</span><p>An 18-port lamina, or an optically addressed transducer tile, in the same cartridge and the same seat.</p></div>
<div class="mod-rung r3"><span class="mod-rn">Rung 3 · Target</span><span class="bd bd-claim">Claim</span><p>An aperture plate of about 10⁵ optically gated pixels, or a phoxonic plate that steers sound and light together. Only factory-made chips at gigahertz do both today (X-1 in the crystals guide).</p></div>
</div>
<p class="mod-fixed"><strong>Stays fixed:</strong> The Ø238 mm bore-plug cartridge with its rim pogo pins (Stack 1 floor, Stack 2 mid-plane cassette, Stack 3 ceiling). <strong>Read more:</strong> <a href="subsystems.html#s04-acoustic-array">S04 Acoustic array</a> · <a href="crystals.html">Crystals</a></p>
</section>
<section class="mod-card" id="m02" style="--mc:#9a542e">
<header><span class="mod-chip">M02</span><h3>Interconnect and routing</h3></header>
<p class="mod-kid">How power, timing and messages travel up the machine. Today it is wires. Next it is light inside glass threads. At the end there are no wires at all.</p>
<div class="mod-rungs">
<div class="mod-rung r1"><span class="mod-rn">Rung 1 · Today (copper)</span><span class="bd bd-derived">Derived</span><p>A rolling flexible copper loop in the right corner piece carries power and signals to the moving head. Spring pogo pins on each cartridge rim carry the 18 V supply and the data bus, so no cable is plugged in when a cartridge is swapped (CAD; electrical figures are design values).</p></div>
<div class="mod-rung r2"><span class="mod-rn">Rung 2 · Next (fibre bundles)</span><span class="bd bd-dec">Design decision</span><span class="bd bd-open">Open</span><p>Photonic-crystal or multi-core fibre bundles carry the optical clock, hologram pages and optical sensing from the plinth up the spine into the rear panels and the stacks. The link budget, the bend limits and the bundle keep-outs are being worked out in tasks #132 and #133. Nothing here is simulated yet.</p></div>
<div class="mod-rung r3"><span class="mod-rn">Rung 3 · Target (no cables)</span><span class="bd bd-claim">Claim</span><p>Cable-free routing: integrated optical waveguides and free-space micro-optical relays between modules. No electrical cable in the final machine.</p></div>
</div>
<p class="mod-fixed"><strong>Stays fixed:</strong> The service channel in the right corner piece and up the spine, and the rim contact positions on every cartridge. <strong>Read more:</strong> <a href="upgrades.html#the-zero-cables-ladder-m02">Interconnect ladder</a> · <a href="compute-control.html">Compute, sensing and control</a></p>
</section>
<section class="mod-card" id="m03" style="--mc:#2f5aa0">
<header><span class="mod-chip">M03</span><h3>Compute core</h3></header>
<p class="mod-kid">The small computer that works out what every sound plate should do.</p>
<div class="mod-rungs">
<div class="mod-rung r1"><span class="mod-rn">Rung 1 · Today</span><span class="bd bd-sim">Simulated</span><p>An RP2350B controller running the small pattern network: 59,548 bytes of the 60,000-byte static memory on the Cortex-M33 build, with 452 workstation checks passing (#129). The larger Prime-Core network on a plug-in M.2 card scores J = 0.36318 on validation in simulation (#123). Nothing has run on a board.</p></div>
<div class="mod-rung r2"><span class="mod-rn">Rung 2 · Next</span><span class="bd bd-dec">Design decision</span><span class="bd bd-doc">Documented</span><p>A hybrid photonic tensor co-processor built on antimony-sulphide phase-change material feeds the fibre bundles. The parts are reported by others (R129†, R134†). The way they connect to this machine is a design decision.</p></div>
<div class="mod-rung r3"><span class="mod-rn">Rung 3 · Target</span><span class="bd bd-claim">Claim</span><p>An all-optical, toroidal wave-compute core, checked against the digital twin.</p></div>
</div>
<p class="mod-fixed"><strong>Stays fixed:</strong> The plinth compute slot and the backplane connector. <strong>Read more:</strong> <a href="compute-control.html">Compute, sensing and control</a> · <a href="cadence-memory.html">Cadence, memory and wave compute</a></p>
</section>
<section class="mod-card" id="m04" style="--mc:#7a4f9a">
<header><span class="mod-chip">M04</span><h3>Pattern and holographic memory</h3></header>
<p class="mod-kid">Where the shapes the machine knows how to make are kept.</p>
<div class="mod-rungs">
<div class="mod-rung r1"><span class="mod-rn">Rung 1 · Today</span><span class="bd bd-dec">Design decision</span><span class="bd bd-sim">Simulated</span><p>Digital flash on the controller, and holographic-equation files (.holo, HLEQ v1) kept on the host.</p></div>
<div class="mod-rung r2"><span class="mod-rn">Rung 2 · Next</span><span class="bd bd-doc">Documented</span><span class="bd bd-open">Open</span><p>K-1, an angle-multiplexed Fe:LiNbO₃ volume-grating crystal, about 100 kbit a page and 500 to 1,600 pages per cm³ (R100†, R195–R198†). Other groups have done the pieces. Putting them in this machine is open.</p></div>
<div class="mod-rung r3"><span class="mod-rn">Rung 3 · Target</span><span class="bd bd-claim">Claim</span><p>Petabit-class 3D optical memory. R138† reports a nanoscale optical disk with that capacity. Our version is a claim.</p></div>
</div>
<p class="mod-fixed"><strong>Stays fixed:</strong> The plinth memory bay (its keep-out is being drawn in task #132). <strong>Read more:</strong> <a href="cadence-memory.html">Cadence, memory and wave compute</a> · <a href="crystals.html#rung-2-crystals-of-light">Crystals (K-1)</a></p>
</section>
<section class="mod-card" id="m05" style="--mc:#8f6d10">
<header><span class="mod-chip">M05</span><h3>Six rear active panels</h3></header>
<p class="mod-kid">Six flat strips on the back wall inside the glass. Now they only reflect sound and read the temperature. Later they shine patterned light.</p>
<div class="mod-rungs">
<div class="mod-rung r1"><span class="mod-rn">Rung 1 · Today</span><span class="bd bd-derived">Derived</span><p>Passive flat aluminium baffles (the &quot;pinna&quot;), temperature and humidity sensors and clear windows. They sit inside the glass, so the curved wall never bends the light (CAD; light transmission figure from the S-VOL1 study).</p></div>
<div class="mod-rung r2"><span class="mod-rn">Rung 2 · Next</span><span class="bd bd-dec">Design decision</span><span class="bd bd-doc">Documented</span><p>Fibre-fed volumetric optical hologram projectors that lock a whole 3D shape in one exposure. Others have shown the effect in the lab (R083, R151). Our version is a design decision.</p></div>
<div class="mod-rung r3"><span class="mod-rn">Rung 3 · Target</span><span class="bd bd-claim">Claim</span><p>Active, programmable metasurface panels (R141 and R084 show the building blocks).</p></div>
</div>
<p class="mod-fixed"><strong>Stays fixed:</strong> Six 30° panel slots on the rear half-circle inside the glass, about 108.5 mm from the axis. <strong>Read more:</strong> <a href="subsystems.html#s06-optical-tomography">S06 Optical tomography</a> · <a href="optics.html">Optics</a></p>
</section>
<section class="mod-card" id="m06" style="--mc:#3f7a28">
<header><span class="mod-chip">M06</span><h3>Lower bucket and feed</h3></header>
<p class="mod-kid">The glass tube below the build chamber. It holds the stuff the machine builds from, and takes leftovers back.</p>
<div class="mod-rungs">
<div class="mod-rung r1"><span class="mod-rn">Rung 1 · Today</span><span class="bd bd-derived">Derived</span><p>A waterproof Stack 1 bore plug seals the glass tube. It has a Ø6 mm fill-and-drain tube. Matter goes up through the 12 mm rim port of the cassette (CAD).</p></div>
<div class="mod-rung r2"><span class="mod-rn">Rung 2 · Next</span><span class="bd bd-dec">Design decision</span><p>A six-sector feedstock carousel, a louver ring at the rim and acoustic guidance of matter along curved paths with no walls (R156).</p></div>
<div class="mod-rung r3"><span class="mod-rn">Rung 3 · Target</span><span class="bd bd-claim">Claim</span><p>Closed-loop release and a reclaim bin that takes back every gram.</p></div>
</div>
<p class="mod-fixed"><strong>Stays fixed:</strong> The Ø250 × 5 mm DURAN glass tube and the Stack 1 bore. <strong>Read more:</strong> <a href="subsystems.html#s02-storage-and-release-plinth">S02 Storage and release</a> · <a href="matter-loop.html">Scan, recover and matter stores</a></p>
</section>
<section class="mod-card" id="m07" style="--mc:#55616b">
<header><span class="mod-chip">M07</span><h3>Chassis, lift and spine</h3></header>
<p class="mod-kid">The body, the motor that lifts the top, and two stops it rests on. It holds still without using power.</p>
<div class="mod-rungs">
<div class="mod-rung r1"><span class="mod-rn">Rung 1 · Today</span><span class="bd bd-derived">Derived</span><p>17.08 kg, no brake. During a job the head rests on two hard stops at 240.00 mm with the servo off, so holding costs 0 W (about 4.3 W saved against holding on current). The motor windings are shorted on power loss, so a raised head sinks at about 55 mm/s. 6.28 kg moves. CAD-derived; motor constants are assumed; nothing weighed.</p></div>
<div class="mod-rung r2"><span class="mod-rn">Rung 2 · Next</span><span class="bd bd-dec">Design decision</span><p>A freestanding machine with the same eight bays, scaled by diameter and height.</p></div>
<div class="mod-rung r3"><span class="mod-rn">Rung 3 · Target</span><span class="bd bd-derived">Derived</span><span class="bd bd-open">Open</span><p>The Ultimate barrel on the same bay layout. The scaling rule is derived. The machine is open.</p></div>
</div>
<p class="mod-fixed"><strong>Stays fixed:</strong> The Rev S frame: two corner pieces, the centre spine and the two 240.00 mm hard stops. <strong>Read more:</strong> <a href="desktop-replicator.html#the-enclosure">Desktop Replicator</a> · <a href="subsystems.html#s01-chamber-and-stack-topology">Subsystems S01</a></p>
</section>
<section class="mod-card" id="m08" style="--mc:#a83f3f">
<header><span class="mod-chip">M08</span><h3>Metrology and interlocks</h3></header>
<p class="mod-kid">The listening, the temperature checks and the safety switches that tell the machine when something is wrong.</p>
<div class="mod-rungs">
<div class="mod-rung r1"><span class="mod-rn">Rung 1 · Today</span><span class="bd bd-sim">Simulated</span><p>A 16-bit AD7380 receive path on the piezo discs. A 150 MHz ring-length lock that follows temperature (±136 steps, 0.063 K per two steps). Bench Gate 0, whose echo test doubles as a cassette-flood interlock. An optional Class 1 laser reading. Host-tested only; the laser class is open.</p></div>
<div class="mod-rung r2"><span class="mod-rn">Rung 2 · Next</span><span class="bd bd-dec">Design decision</span><p>Fibre-coupled interferometry, and material identification that uses sound and several colours of light together (INS-33).</p></div>
<div class="mod-rung r3"><span class="mod-rn">Rung 3 · Target</span><span class="bd bd-open">Open</span><p>Optical metrology over the cable-free link. Not yet worked out.</p></div>
</div>
<p class="mod-fixed"><strong>Stays fixed:</strong> The sensor ports, the head-down switch and the interlock chain. <strong>Read more:</strong> <a href="subsystems.html#s05-gap-actuator-and-resonance-lock">S05 Resonance lock</a> · <a href="subsystems.html#s11-thermal-and-safety">S11 Thermal and safety</a></p>
</section>
</div>
<!-- generated:cards:end -->

## The swap rule

A part of the first machine is swapped for a better one only when a test passes. The test is a measurement on the real machine. A good result in a computer model is not enough.

Each part has its own test, written down first. If the test fails, the old part stays. Some swaps may never happen, because the old part is good enough.

All parts, replacements and tests are in one table: [Long-term architecture and the Desktop Replicator](architecture.html#long-term-architecture-and-the-desktop-replicator). Every test in it is Open, because each needs an assembled, calibrated machine.

## One enduring platform

There is one machine, upgraded in place. The mechanical reference surfaces, the optical sightlines, the coordinate convention, the job and [holographic-equation](compute-control.html#holographic-equations) file formats and the software interface stay fixed between generations. Only the module that limits performance is replaced.

There are no disposable test rigs. Calibration happens in the assembled chamber.

**Sensing first (Design decision).** Listening and looking need milliwatts. Holding and moving need far more. A new machine therefore [scans](matter-loop.html#scan-non-moving-3d-tomography-and-scattering) first: its own empty chamber, then an object. Lifting comes after, on the same hardware, once the measured response says the drive is safe and strong enough.

**Buying is allowed.** A bought wafer, microcontroller, laser diode or outside-made optical master is a valid starting part whenever buying costs less human time than building the tool that would make it.

## The rule that keeps the graph honest

Each record is one part, process, measurement or upgrade. A record that is made or measured must state:

1. the bottleneck it removes;
2. the fabrication tolerance it requires;
3. the measurement that checks that tolerance;
4. the bought or outsourced inputs it depends on (the "seeds");
5. the benefit, as the same task run before and after;
6. an estimate of the human minutes it costs.

Three more fields are proposed and not yet checked: where the prediction is trusted, machine cost (time, energy, yield, rework), and the smallest experiment that could still change the decision.

The plan must contain no loops. An upgrade may not depend on the precision it is supposed to create, unless a bought seed supplies that precision first.

The twin's command `fieldc upgrades` checks that no record depends on itself or on an unknown record, and that every made or measured record carries a tolerance and an inspection. The current plan passes. That shows it is well formed, not that any step will work.

## The current graph

Every record in the plan, in build order. The right-hand column says which module each upgrade belongs to.

| Record | What it is | Status | Depends on | Module |
|---|---|---|---|---|
| `S-SEEDS` | Bought parts: borosilicate wafers, piezo discs, microcontroller boards, drivers, receive converters, comparators, laser diodes, clock, calibration spheres | Listed in the bill of materials; no supplier contacted | Nothing | All |
| `S-WORKSHOP` | Workshop machining and 3-D printing, plus outsourced circuit boards and glass edge cutting. Nothing is moulded, cast or stamped | Specified in the manufacturing pack; nothing ordered | Nothing | M07 |
| `C-SIM-GATES` | Simulation checks to pass before any board is made: receive converter, pattern network size, laser readout, solid plate model | The 1-bit receive converter failed its check ({{c:haptic_pzt.sfdr_simulated_dbc}} dB against {{c:haptic_pzt.sfdr_gate_min_db}} dB) and is replaced by a 16-bit converter ({{c:haptic_pzt.adc_fallback_mpn}}). The crystal screen for the steel-dot grating RG-1 also failed (1.08 times against 1.3 needed). The current list is in [Current state](status.html) | Nothing | M01, M08 |
| `S-META-MASTER` | Outside-made nanostructured optical master, for later imprint copies | Candidate; not ordered | Nothing | M05 |
| `C-FW-DESKTOP` | Controller firmware: drive, receive, laser readout, shared clock, the ring-length lock and the flood interlock, and the pattern network | Source written and tested on a workstation, 452 checks (Simulated); never run on a board | `C-SIM-GATES` | M03, M08 |
| `X-EM` | Optional contactless exciter (magnet and flat coil) for testing metal plates outside the glass baseline | Drafted; off the critical path | `S-WORKSHOP` | M01 |
| `M-DESKTOP-REV-S` | The assembled Desktop Replicator, Rev S: brake-free, {{c:desktop_geometry.nominal_mass_kg}} kg. The engineering graph file still lists it under its old id `M-DESKTOP-REV-D` | CAD model passes its geometry checks (11 of 11 gates) | `S-SEEDS`, `S-WORKSHOP`, `C-FW-DESKTOP` | M07 |
| `K-INCHAMBER-CAL` | Calibration inside the assembled chamber with removable spheres and crucibles: hold, move and transfer repeatability | Needs the assembled machine | `M-DESKTOP-REV-S` | All |
| `U1-PINNA-KINO` | First upgrade designed from the machine's own calibration data: a faceted rear reflector and an optional printed phase insert | Simulated; waits for calibration | `K-INCHAMBER-CAL` | M05 |
| `U2-TIO2-META` | Imprinted diffractive strips on the laser sightlines, to double the independent optical measurements | Simulated; waits for calibration and the master | `K-INCHAMBER-CAL`, `S-META-MASTER` | M08, M05 |
| `U4-SPIRAL-TOROIDAL` | Optional thin-film spiral conductor on the wafers, for launching short toroidal pulses | Candidate; waits for a pulse simulation and calibration | `K-INCHAMBER-CAL`, `S-WORKSHOP` | M01 |
| `U5-TOROID-COLLAR` | Compact pulsed ring coil around a crucible throat | Candidate; waits for an electrodynamic model and calibration | `K-INCHAMBER-CAL`, `S-WORKSHOP` | M06 |
| `U3-WAVE-BRAIN` | Compute card progression: microcontroller, then a programmable-logic card, then an optical or wave-based core | First card simulated; later cards open | `K-INCHAMBER-CAL`, `U2-TIO2-META` | M03 |

Every upgrade waits for the in-chamber calibration, which produces the first measured data.

## What the graph does not yet contain

- **Measured costs.** The human-minute figures, 0 to 180 minutes per record, are estimates.
- **A part made by the platform.** There is no record made by the platform yet, and no module is made by the machine. Every record is bought, made in a workshop, a measurement, or shaped by calibration data but printed elsewhere. The first self-made upgrade should remove the most human work per unit of benefit. Candidates are fixtures, feed guides, field-shaping inserts and small optical structures, most likely in M05 or M06 (Open).
- **A fibre-bundle link budget.** M02 Rung 2 has no light budget yet (task #133).
- **The tagged module export.** The CAD files do not yet say which part belongs to which module (task #132).
- **Results.** Each upgrade's benefit is an acceptance target written before any measurement.

## Long-term direction

The long-term design replaces bought electronics with light-switched elements and wave-based computing, and closes the material cycle ([Architecture](architecture.html), [Scan, recover and matter stores](matter-loop.html)). A step enters the plan only when a record can state its tolerance, its measurement and its seeds.

| Stage | What happens |
|---|---|
| Seed | Buy or outsource what makes the first useful process possible |
| First upgrade | Make and check one part that improves the same machine |
| Precision ladder | Use that gain to make a harder part, and the tool that measures it |
| Reproduction | Make the next working machine, listing every outside step |

Weight is a poor score: a machine can make most of its own mass and still depend on one outside process. Every outside part and process stays on the list.

Copying needs a closed material loop and enough process range to make every module. Improving needs only one module the machine makes better than the one it replaces, and a measurement that proves it.

An optical computer is the computer this machine might make, because it works by shape and not by doping chemistry (Open; see [the substrate ladder](cadence-memory.html#long-term-direction-the-substrate-ladder)).

## Open questions

| Question | Who answers it |
|---|---|
| Which part is the first self-made upgrade? | Engineering management, after in-chamber calibration data exists |
| What do the steps cost in human minutes? | Measured during assembly and calibration |
| Do the upgrade targets survive the change to {{c:desktop_geometry.gap_mm}} mm spacing? | Simulation, by re-running the affected models |

Read next: [Desktop Replicator](desktop-replicator.html), [The engineering twin](digital-twin.html), [Manufacturing](manufacturing.html) and [From atoms to hardware](physics-to-hardware.html).
