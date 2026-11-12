# P0 platform — order pack for review (revision P0-A, not released, not the selected architecture)

Prepared 2026-11-12 from the twin (`twin/`, configuration `p0x16g46`,
`fieldc p0 …`). **Nothing here has been ordered and no supplier has been
contacted.** The pack is not release-ready: the blockers are listed at the end.

**Standing (operator, 2026-11-12, later):** this dense-emitter configuration is
a reference and a calibration test bed, not the chosen prototype. The
preferred study is a few strong piezo inputs into printed acoustic bodies,
owned by another session; the frame, link, calibration and planner here are
what that study will be evaluated and operated with
(`twin/Design/BODY_INTERFACE.md`). Do not order from this pack on the
strength of the twin's results.

P0 is the first configuration of the platform: a frame whose datum is four
threaded rods, two replaceable aperture plates of bought 40 kHz
transmitters, a controller that plays the twin's frame log, and a probe that
calibrates every channel. It would be bought to learn four numbers the twin
assumes and to demonstrate hold, move and release. **It does not place a bead
beside a bead:** in the twin its aperture puts a second bead 1–2 mm off
(`fieldc build --array p0`, G-B1 and G-B2 fail). What it is for, in order:

1. **K-ELEM** — measure the transmitter: level against drive, resonance and Q, scatter between units, what a plate of cans reflects.
2. **K-HMR** — hold, move, release, repeated, against the twin's prediction.
3. The first self-made part (section 9), and the evidence to choose among the routes to multi-bead placement.

## 1. Configuration

| | |
|---|---|
| Apertures | 2 × aperture plate A1: 4 × 4 transmitters at 10.5 mm, facing, 32 drive channels |
| Gap | 46 mm face to face (plate tops 60.2 mm apart), set by nuts; adjustable 30–100 mm. The value follows the measured reflection (section 8) |
| Tone, drive | 40 kHz; 0–15 V square wave per channel, pulse width 0–50 % in 512 steps (0.7° of phase) |
| Bead | expanded polystyrene, Ø1.5 mm (density about 25 kg/m³) |
| Receive | one 40 kHz receiver on the probe bar, on the mid-plane, removed after calibration |
| Sensors | air temperature (TMP117, ±0.1 °C); camera: a phone on a stand (owned) |
| Software | `fieldc p0 job --port …`: calibrate → compile → play, through `MachineBackend`; the same call runs on the emulated machine |
| Source | twin commit recorded in the receipts (`fieldc p0 cad --receipt`); firmware `twin/Firmware/p0/`, compiled for the RP2350B (`FIRMWARE.md`: artifact, hash, timing), never flashed |

## 2. Bill of materials

Prices and stock as read on 2026-11-12 ([`PARTS_RESEARCH.md`](PARTS_RESEARCH.md)).
"NV" = not verified on a readable page. Re-check every line on the day.

| # | Item | Part number | Qty | Seller (read) | Unit price | Stock | Substitute |
|---:|---|---|---:|---|---:|---|---|
| 1 | Transmitter 40 kHz Ø9.9 | Murata **MA40S4S** | 36 (32 + 4) | Newark 52R3632 | $5.82 (10+) | **8** — short | DigiKey 490-7707-ND: NV, search text says thousands. Else Pro-Wave 400ST100 (Newark 98K9172, $6.63, 40 in stock, 112 dB min, 10 V rms max) |
| 2 | Receiver 40 kHz Ø9.9 | Murata **MA40S4R** | 2 (1 + 1) | Electrokit 41032755 | 58 SEK | 6 | Pro-Wave 400SR100 (Newark 13M3940, $7.30, 96) |
| 3 | Dual driver, DIP-8 | Microchip **TC4427AEPA** | 18 (16 + 2) | Newark 92C6108 | $1.43 (10+) | 480 | TC4427ACPA (non-stock) |
| 4 | Controller, RP2350B, 48 GPIO | Waveshare **Core2350B** | 1 | Electrokit | 129 SEK | 21 | Solder Party RP2350 Stamp XL ($11.68, lectronz). **Not** Olimex PICO2-XXL: its GPIO8 is the PSRAM select |
| 5 | Air temperature | Adafruit **4821** (TMP117) | 1 | Adafruit | $11.50 | in stock | SparkFun SEN-15805 |
| 6 | Qwiic cable to sockets | SparkFun **CAB-17261** | 1 | SparkFun | $1.95 | in stock | Adafruit 4397 (out) |
| 7 | Solderable board, full size | Adafruit **590** (3-pack) | 1 | Adafruit | $19.95 | in stock | — |
| 8 | DIP-8 socket | Adafruit **2202** (3-pack) | 6 | Adafruit | $0.75 | in stock | any |
| 9 | 100 nF ceramic | Adafruit **753** (10-pack) | 2 | Adafruit | $1.95 | 18 packs | any |
| 10 | 10 µF 25 V electrolytic | SparkFun **COM-00523** | 4 | SparkFun | $0.55 | in stock | any |
| 11 | Header strip, 40-pin | SparkFun **PRT-00116** | 6 | SparkFun | $1.95 | in stock | any |
| 12 | Jumper ribbon, socket–socket, 40 × 150 mm | Adafruit **266** | 3 | Adafruit | $3.95 | in stock | 4 × SparkFun PRT-09389 per 40 |
| 13 | Supply 15 V | SparkFun **TOL-19898** (5–15 V selectable, 3 A) | 1 | SparkFun | $24.95 | in stock | Mean Well GST25E15-P1J (NV); **not** the 18 V model |
| 14 | Barrel jack to terminals | SparkFun **PRT-10288** | 1 | SparkFun | $3.75 | in stock | any |
| 15 | M4 threaded rod, stainless, 1 m | Bauhaus 1067648 | 1 | Bauhaus SE | 64.95 kr | web stock | McMaster 94185A581 (300 mm, price NV) |
| 16 | M4 nuts, M4 washers | — | 24 + 24 | hardware shop | NV | NV | — |
| 17 | Polystyrene beads Ø1–2 mm | — | 1 L | relax-pillow.de (Germany only) | €1.50 | in stock | giraffenland.de 10 L €11.87 (EU delivery NV) |
| 18 | PETG filament | — | about 80 g | workshop | — | assumed owned | — |

Read total, excluding shipping, VAT differences and lines 16–18: about
**$330 + 250 SEK** (line 1 at $5.82 is $210 of it).

Owned or assumed owned: a printer, a soldering iron, a hacksaw or rod cutter,
calipers, a phone and stand, a computer running the twin, a USB-C cable.

## 3. Made parts

Generated by `fieldc p0 cad --out cad/p0-platform` (gates G-P0C1–3: closed
solids, volumes, ten fit checks).

| File | Qty | Process | Note |
|---|---:|---|---|
| `aperture-plate.stl` | 2 | FDM, PETG, 0.2 mm layers, 4 perimeters, 40 % infill, flat on the bed | 130 × 130 × 4; 32 pin holes Ø0.9, 4 rod holes Ø4.4. Drawing: `aperture_plate.svg`. ±0.2 mm; drill the pin holes through with a 0.9 mm bit if they close |
| `probe-bar.stl` | 1 | same | spans two diagonal rods; 2 pin holes at its centre |
| `flip-spacer.stl` | 2 | same | 18.2 mm tall |
| `side-cradle.stl` | 1 | same | sits over the turned bar; a groove holds the receiver on its side, axis on the mid-plane |
| rods | 4 | cut line 15 to 150 mm, deburr | — |

The plate is the interface: **mechanical** — four Ø4.4 holes on a 110 mm
square, the cans' faces 7.1 mm above the plate; **electrical** — two pins per
channel behind the plate (signal at −x), 0.1" sockets; **software** — channel
n is the can numbered n on the drawing; the upper plate is the same part turned over about x, its channel 16 + n the can facing n. A new aperture
(A2, another tone, another count) is a new plate file and a new `P0Design`;
the frame, controller, link and calibration are reused.

## 4. Electronics

No custom board. Two driver boards on solderable breadboards, eight
TC4427AEPA each, one per plate; every connection is a 0.1" jumper.

**Driver k (0–15), DIP-8 — check against the TC4427A datasheet before soldering:**

| Pin | Net |
|---:|---|
| 1, 8 | not connected |
| 2 (IN A) | controller GPIO 2k |
| 3 (GND) | ground |
| 4 (IN B) | controller GPIO 2k + 1 |
| 5 (OUT B) | header → transmitter 2k + 1, signal pin |
| 6 (VDD) | +15 V; 100 nF to ground at the chip |
| 7 (OUT A) | header → transmitter 2k, signal pin |

Each board: +15 V and ground rails, 2 × 10 µF across them at the entry, a
16-pin input header, a 16-pin output header and a 16-pin ground header (the
transmitters' second pins). Controller ground to both boards' ground.

**Controller (Core2350B):** GPIO0–15 → lower plate's drivers, GPIO16–31 →
upper; GPIO40 (ADC0) → probe receiver, its other pin to ground; GPIO32/33 →
TMP117 SDA/SCL, 3V3, ground; USB to the computer. The controller is powered
from USB; the 15 V supply feeds only the drivers.

**Budgets (DERIVED, not measured):**

| | |
|---|---|
| Drive | 15 V p-p square: fundamental 6.75 V rms, against the transmitter's 20 V p-p limit and the driver's 18 V |
| Reactive current | 2.55 nF × 15 V × 40 kHz = 1.5 mA per channel, 49 mA for 32 |
| Charging loss | C V² f = 23 mW per channel at 50 % duty, 0.73 W for 32, shared by driver and transmitter |
| Transmitter loss | not in the datasheet. TinyLev reports 10 W into 72 units at a higher voltage (0.14 W each): allow 0.15 W each, 5 W for 32, at full drive. The job uses under half the full amplitude: about a quarter of that |
| Supply | under 0.5 A at 15 V at full drive; the supply gives 3 A |
| Heat | under 6 W in two plates and two boards, free air; expect the cans a few kelvin above ambient at full drive — to be measured (K-ELEM step 4) |
| Air | the phase of a 22 mm path moves 1.6° per kelvin at 40 kHz: temperature is logged, not controlled |
| Sound | 40 kHz at up to about 150 dB at the centre, inaudible; keep ears and pets a metre away and do not run unattended |

## 5. Assembly — and the human time it takes (estimates)

| Step | What | Minutes |
|---:|---|---:|
| 1 | Print 2 plates, bar, spacers (unattended, about 5 h) | 15 |
| 2 | Cut four rods | 20 |
| 3 | Build two driver boards: 16 sockets, headers, capacitors, rails | 150 |
| 4 | Stand 32 transmitters on the plates, pins through (no polarity test: calibration reads a reversed unit as 180°) | 20 |
| 5 | Frame: nuts, lower plate, upper plate; set the gap to 46 mm with calipers | 20 |
| 6 | Jumpers: 64 from pins to driver headers, 34 from controller to boards, sensor, supply | 45 |
| 7 | Build and flash the firmware (`twin/Firmware/p0`, pico-sdk); first power-up with the supply at 5 V | 60 |
| 8 | Scope check of the five numbered assumptions in `pico_main.c` | 45 |
| | **Total to first calibration** | **about 6 h** |

Step 3 is the largest. A fabricated board would remove most of it and add a
design, a review and a lead time; not proposed for one prototype.

## 6. Calibration (scripted; two manual steps)

`fieldc p0 job --port /dev/cu.usbmodem… --out run1`

1. *Manual:* fit the probe bar on its two spacers, receiver facing down, face on the mid-plane (23 mm above the lower cans' faces). Return.
2. The twin plays `Calibration.program` for the lower plate: each of its 16 channels alone for 20 ms at a pulse 16 steps wide, the probe listening.
3. *Manual:* turn the bar over, without the spacers, receiver facing up. Return. The same for the upper plate.
4. *Manual:* pull the receiver from the bar, set the side cradle on the bar and lay the receiver in its groove (its axis is then on the mid-plane). Return. The reference pass: all 32 channels again.
5. The twin writes `calibration.json` (per channel gain and phase, the plates' ratio and how far the sixteen pairs disagree about it, air temperature, date, the controller's serial).
6. *Manual:* remove the bar. Return. The twin compiles the job on the plates as calibrated, checks it under the planner's policy, and plays it or declines.

Why three passes. A receiver hears the plate it faces, so passes 1–3
calibrate each plate on its own and leave the phase between the plates
unmeasured. On its side, the receiver hears a lower element and the upper
element facing it at mirror angles: whatever its directivity is, it is the
same for both, so each of the sixteen pairs gives the plates' ratio. One pair
would do; sixteen average the noise and report their spread. A point
microphone (a MEMS part) would need one pass and no reference, at the price
of a different sensor and input stage; the twin runs both (section 8).

Repeatability check, before anything else: calibrate, reseat the bar,
calibrate again. Pass: every channel's phase repeats within 5°, gain within 5 %.

## 7. Acceptance protocol (fixed before any hardware exists)

Bead Ø1.5 mm polystyrene, gap 46 mm, 15 V, room air, plates as calibrated.
Camera: two views (front, side), scale from the 10.5 mm can pitch; the bead's
centre is read to 0.1 mm. Positions are measured from where the bead is
first held: no bench knows the acoustic frame's origin better than the
probe was placed (±0.2 mm).

| # | Observable | Pass | Twin's prediction (SIMULATED) |
|---|---|---|---|
| A1 | Link: `describe`, calibration, repeat | phases repeat within 5°, gains within 5 % | electrical chain within 0.02 % and 0.01° (G-HW1–3, simulated controller) |
| A2 | Hold at the pick-up, 60 s | 10 of 10 | holds at 1× by construction; the job runs at its chosen level |
| A3 | Move 5 mm up then 5 mm across, 0.25 mm steps | the bead's travel within 0.5 mm of the travel asked, at the corner and the end, 9 of 10 runs | travel error 0.1–0.5 mm (section 8) |
| A4 | Release: drive off | bead falls within 0.1 s, 10 of 10; lands within 3 mm of the point below | not modelled (charge and sticking are not in the twin) |
| C1 | Control: the same job compiled on the drawing, uncalibrated | recorded, no bar | the bead leaves the trap on most emulated builds |
| C2 | Control: job at half the chosen level | recorded | the model predicts where it fails |

A failed A3 with a passed A1 means the twin's field or force model is wrong
for this machine: the calibration record, the camera track and the frame
log go back into the twin before anything is changed on the bench.

Log per session: human minutes at the bench, by step; reworks; air temperature.

## 8. What the twin says of this configuration (SIMULATED)

`fieldc p0 link`, `fieldc p0 job`, `fieldc carry | fly | build --array p0`. The
emulated machine is P0 as one random build — element gain ±10 %, phase ±20°,
position ±0.2 mm, resonance ±0.3 % — calibrated one plate at a time, driven
through the 16-bit wire and the controller's pulse widths.

| What | Result |
|---|---|
| Link (G-HW1–3) | the controller core, compiled for a computer, returns the emulated machine's records within 0.06 % and 0.04°; the frame log sent is byte for byte the emulator's |
| Holding a Ø1.5 mm polystyrene bead | 0.2–0.4 m/s on the hardest element, of 1.52 at 15 V |
| Job, gap 46 mm (G-P0a, G-P0b) | **passes on 18 of 18**: six builds × plates reflecting 0, 0.5 and 0.9. Travel error 0.10–0.49 mm (bar 0.5); hardest element 0.34–0.58 of full drive (bar 0.71, a −3 dB unit); level 4–8 × holding, chosen by the planner. 17 as run; the 18th after the planner's floor was raised from 2 × to 4 × |
| Job, gap 44 mm | plates reflecting 0: 6 of 6. Reflecting 0.5: 2 pass, 3 lose the bead, 1 refused by the planner. Reflecting 0.9: the planner refuses all 6 |
| Job, gaps 40, 42, 50, 62, 80 mm, plates reflecting 0.9 | 1 of 15 passes; the planner refuses 13 |
| Control: job compiled on the drawing, uncalibrated | the bead leaves the trap or travels 0.3–0.9 mm off on most builds |
| RH-1's stricter carry gate (G-P1: still the one deepest well) | fails on most gaps: one tone has equal wells every 4.3 mm, so "deepest" has no meaning here. Reported, not P0's bar |
| Placing beads touching (G-B1 row, G-B2 tetrahedron) | **fails**: the second bead lands 1–2 mm off, on A1 and on a 6 × 6 one-tone aperture |

**The gap is sharp when the plates reflect.** 46 mm works across the range;
2 mm either side does not if the reflection is high. The reflection is not
known (0.9 is a bare metal face's; cans on a printed plate are something
else) and is the first number K-ELEM measures; the nuts then set the gap the
twin picks for it. The planner refusing a job is the intended behaviour: it
plays nothing its own model, perturbed by what calibration cannot see, does
not carry.

## 9. The first self-made part, and what the later ones wait for

**Origin fiducial F1**: one Ø1.5 mm bead bonded on the tip of a printed post,
at the calibrated trap centre (record U1 in `twin/Design/upgrade_graph.json`).

| | |
|---|---|
| Why this part | it needs only what the hold / move / release milestone shows — one bead, held and lowered — and it gives the bench what it lacks: a mark of the acoustic origin a camera can see |
| Production | the platform holds the bead at the centre and lowers it onto the post's tip (hybrid: the bead is fed by hand) |
| Consolidation | a UV-curing adhesive put on the tip by hand, cured by a 405 nm lamp. Dose and bond strength are unmeasured: a material gate of its own |
| Externally made | the post (a workshop print: a seed part, not a self-made one), the adhesive, the lamp, the bead |
| Inspection | camera, two views at 20 µm per pixel: bead centre within 0.2 mm of the post's axis; survives a 10 mm drop |
| Benefit, measured | absolute placement becomes a measurement: bead positions are read against F1 instead of against where the probe sat (±0.2 mm). Before and after on the same job: the spread of the bead's end point in the frame |
| Enables next | any multi-bead part needs its sites measured in the frame |
| Evidence so far | SIMULATED only: in the twin a first bead is set on a support within a micrometre on A1 (`build` receipts, bead 0). The support's own echo is not modelled |

**Multi-bead parts are a separate, open question.** On aperture A1 and on a
6 × 6 one-tone aperture of the same part, the twin places a second bead
1–2 mm off. That establishes a limit of those two configurations, not what
the remedy is. Four routes are recorded and none is chosen: a few-input
structured body; an aperture of catalog parts at more than one tone; a
process change in which the trap stays put and a stage brings the work to
the bead; custom transmitters at higher tones. The adhesive and lamp are not
in the BOM: no listing with a stated cure wavelength and power was verified.

## 10. Blockers and unresolved risks

**To release this pack (each needs a person or a decision):**

1. **Transmitter supply.** Murata marks the MA40S4S "not for new designs"; the only readable seller has 8. DigiKey's stock could not be read by a program: check it by hand, or choose the Pro-Wave 400ST100 (lower guaranteed level: 112 dB min against 120 ± 3 dB).
2. **Controller's USB.** The Core2350B has no USB socket; it takes a separate adapter over a flat cable. Whether the Electrokit listing includes it was not verified.
3. **Jumper sockets on the pins.** The transmitter's pin is Ø0.64 mm round; that a 0.1" socket grips it was not verified. Fallback: solder the wires.
4. **Firmware on a board is untested.** It compiles for the RP2350B (`twin/Firmware/p0/FIRMWARE.md`); it has never been flashed. Five assumptions are numbered in `pico_main.c` for a scope.
5. **Nuts, washers, beads**: no verified EU listing; a hardware shop and any bean-bag filling.
6. **The operator's approval** of the configuration and of placing any order.

**Risks the bench run exists to retire:**

* The transmitter's level is ±3 dB; the job is held to what a −3 dB unit gives. A weaker alternate part may not hold the bead at 15 V.
* The plates' reflection is unknown. The twin's result changes with it and with the gap (section 8); 46 mm is the twin's choice before any measurement.
* The probe is a Ø10 mm can on a 12 mm bar in a 46 mm gap: it disturbs the field it measures. A MEMS microphone on a thin arm is the fallback; it gives relative numbers only.
* One probe point cannot see where an element is, only its phase there. Position errors of ±0.2 mm are the main residual in the twin.
* Absolute level (pascals) needs a calibrated measurement microphone: not owned, quote only. Without it K-ELEM stays relative, anchored on the datasheet.
