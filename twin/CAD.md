# RH-1 solid model — the CAD inside the twin

The free-standing RH-1 as a parametric solid model, built by FieldCore with no
dependencies, rendered by the twin's Metal pipeline, gated like the physics,
and exported to STL / OBJ / STEP. The engine's plates (`PlateArray.rh1`) and
the face plates drawn here are built from the same sites and sizes, and gate
G-CAD9 holds them equal, so the CAD and the simulation cannot drift apart.

Source files: `Sources/FieldCore/CAD/` (kernel, design, model, gates, exports),
`Sources/FieldGPU/SolidRenderer.swift` + `Shaders/solid.metal` (rendering),
`Tools/rh1_step.py` (B-rep STEP via CadQuery).

## Use it

```sh
swift build -c release
./.build/release/fieldc cad info --reconciliation   # stack, provenance of every number, conflicts
./.build/release/fieldc cad check --rules --receipt # CAD gates + 28 design rules
./.build/release/fieldc cad render --all --out renders/    # iso, front, section, section-iso, detail, plate, storage, top
./.build/release/fieldc cad render detail --light --door open detail.png
./.build/release/fieldc cad export --out cad-out    # STL per part, rh1.obj+mtl, params, BOM, drawing
./.build/release/fieldc cad step --out cad-out/rh1.step   # B-rep STEP assembly (needs CadQuery)
./.build/release/fieldc cad pack                    # the manufacturing pack: made parts, bought parts, drive electronics, assembly, what is missing
./.build/release/FieldCompilerApp                   # Machine tab: orbit, S = section, 1–5 views
```

Options: `--preview | --fine` (tessellation only — the design is identical at
every detail level), `--door open|closed|<deg>`.

## What is modelled — 104 parts

| assembly | parts | notes |
|---|---|---|
| body | bottom closure, lower body tube 0–1060, top band, crown, crown cap, LED ring | 4 mm anodized shells, Ø460 × 1650 |
| plate.top / mid-up / mid-down / deck | face plate, 1,536 transmitters and their carriers, wiring board, carrier ring, gyroid horn, copper inner cone, 3 throat piezos, rim electronics | four radiating faces; the middle assembly is two back-to-back stacks |
| torus.top / middle / deck | hollow former Ø290/Ø60, contrawound winding pair (CW feed A, CCW feed B) | 44 turns each, two independent feeds (R5) |
| bore | collars top / middle, deck feed tube | Ø12 clear, Ø14 collar |
| storage | chamber liner Ø400 | 420 → 936 |
| enclosure | rear glass Ø444 (fixed), front glass Ø464 (rotating), end-bands, 2 V-groove tracks, 6 V-rollers | door is a parameter |
| arcade | 7 slim columns + RX/status strips | rear 180°, 30° pitch |
| photonic | 6 optically-addressed bay tiles | between the columns |
| base / crown | intake filter, reservoir, graphite bay, PSU, compute, pump, cartridge circle, optical-stem head, touch UI | **envelopes only** — dimensioned nowhere |

The face plate is the part that carries the design. Since 2026-11-12 it is
drawn for **resonant elements** (proposal; the operator's ruling of
2026-11-11 was 192 elements, made when the engine drove ideal pistons — see
`ENGINE.md`, "The elements are hardware"):

* **1,536 open-type transmitters per face**, each tuned to one of nine tones
  (52.8–97.2 kHz) and driven by its own channel. A transmitter is the bought
  40 kHz Ø10 mm part scaled to its tone: Ø7.6 mm at the lowest, Ø4.1 mm at the
  highest, its can 0.7 diameters tall, flush with the radiating surface.
* They sit on the golden-angle spiral over r 13 → 195.2 mm. The spiral spaces
  centres evenly but the elements differ in size, so where two large ones
  fall side by side they are nudged apart until every pair of holes keeps a
  1 mm web (`PlateArray.spread`; rule DR11). 29 % of the face radiates.
* Inside the plate's 12 mm envelope: an 11 mm aluminium plate with one
  through-hole per element, a moulded carrier behind each transmitter, and a
  1 mm four-layer **wiring board** on the plate's back that takes every
  element's two pins to the rim electronics (one trace per element; 3.1 mm of
  rim per trace per layer, rule DR27).
* The **rim electronics** annulus holds the drivers: one two-channel gate
  driver per two elements and one shift register per eight, on three ring
  boards (rule DR28: 2.8× the board area they need).
* Up-facing faces carry the lower plate's layout, down-facing faces the upper
  plate's, exactly as `PlateArray.rh1` places the engine's two plates; gate
  G-CAD9 holds sites and sizes equal to 1e-6 mm.

`fieldc cad pack` lists the transmitters tone by tone with their drive
voltages, the driver counts, the assembly order and what cannot be built from
the model yet.

**What this face gives up.** The twelve light slots are gone: between 1,536
holes no stretch of a slot arm 8 mm long is left with 1 mm of metal to every
hole, so no dash is cut (G-CAD8: 0 dashes). With 192 elements the arms were
cut into ~150 dashes that kept three-quarters of their area. Whether the
slots or the powder mold has the face is the operator's call.

**Open on this face:** no transmitter of this kind has been measured at these
tones; what the horn, cone and three throat piezos behind the plate are for
now that the face carries its own elements; fasteners, gaskets and the board
connectors.

The face of 2026-11-10 — 192 Ø5 × 2 piezo discs flush with the surface,
radiating directly, a damping backing behind each — is still built when
`elementTones` is empty (`fieldc … --array disc`). It fails gate G-E1 by 310×.

The v0.4 face — a 380-site sunflower of biconical micro-horns (face radius
1.054 + 0.00981·r mm) behind one horn, crossed by twelve unbroken slots — is
kept as `RH1Design.microHornFace`; its claims (G-CAD5's 21 × 34
parastichies) are still gated there.

## Where every number comes from

`fieldc cad info` prints the full provenance list; each item carries a
register — **committed** (a paper commits to it), **site** (measured off an
etherworks.io to-scale figure), **derived**, **resolved** (a conflict settled in
code, below), or **assumed** (specified nowhere; a sized choice). Sources win
in this order when they disagree:

1. Mechanical Construction §3c (2026-08-03) — the plate stack, worked exactly.
2. etherworks.io "How it works" (2026-08-10) — FIG. 1 of *The machine* is drawn
   at exactly 0.48 px/mm (body 220.8 × 792 px = Ø460 × 1650), so its rectangles
   are dimensions; FIG. 2 of *The plate* is "drawn from the same math as the
   real one" — its 380 dots and 12 slot paths were fitted (golden angle
   137.508°, cot α 0.2483, hole radius law to 0.005 mm).
3. Hardware Specification RH-1 v0.4 (2026-07-30) — §3, §5, §8.
4. `lpoh/cad/rh1_freestanding_rev2.blend` — stale; used only where nothing
   newer exists (shell band heights).

## Reconciliation — conflicts resolved in code, not silently

| topic | papers | site | model | why |
|---|---|---|---|---|
| Middle plate | spec §8: one plate 1048–1060, torus + horn below | two plates flanking one torus | faces at 1060 (up) and 936 (down), mirrored about the 998 torus | a 12 mm plate cannot carry two back-to-back cap stacks |
| Storage deck & chamber | deck 655, chamber Ø400 × 385, base ~650 | deck 420, chamber 425–930, base 0–400 | deck face 420, chamber 420–936, deck torus 365 | the spec's numbers overlap its own middle stack (655 + 385 > 936) |
| Throat piezos vs bore | 3 × Ø25 (assumed) on r = 18 | — | 3 × Ø20 on r = 18; throat Ø36 and every horn number kept | Ø25 on r = 18 reaches r = 5.5 — inside the Ø12 bore |
| Bore collar | Ø12 bore + collar | Ø12 | Ø12 clear, Ø14 × 1 mm collar | a collar needs a wall |
| Face pattern | ~380 Vogel sites + 12 slots, "slots cut through" | dots drawn over slots | sites whose opening would cut a slot web are left to the slot void | the slot is already open there |
| Side panels | plan B (phononic); photonic note = DRAFT | six optically-addressed panels, baseline | six photonic tiles, EM only | site is newest; note is not yet a ruling |
| Arcade columns | desktop 40×20; free-standing "slim", no section | ~5 mm gaps | 18 × 10 at r 206–216 | 40×20 does not fit the 13 mm annulus |
| Canonical model | spec §8: rev2.blend | — | this model supersedes it | rev2 predates the Ø12 bore |
| Touch UI | 7″ "at standing eye height" | — | surface-mounted on band/crown | no flush shell surface there |

## What the CAD found — for the papers

These came out of building the geometry, not out of reading it:

1. **Only 128 of the 380 sunflower sites can be drilled.** 252 fall inside a
   slot or within its 0.8 mm web. The twelve arms are tightly wound (α = 76°,
   1.13 turns), so along any ray the arms repeat every 13.9 % of radius and
   their clearance bands cover roughly three-quarters of the face. Site FIG. 2
   draws the dots over the slots without resolving this.
2. **The slots are the acoustic aperture.** Per face: slots 34,600 mm² open,
   micro-horn faces ~2,700 mm² (throats ~680) — 12.8×. The papers call the
   slots voids in the conductor with porous gyroid behind; if so they radiate,
   and "too sparse to block the sound" undersells them — they are 93 % of the
   open area and a spiral line-source array, not a sunflower. (On the
   resonant face of 2026-11-12 the question is moot: no slot is left.)
3. **"21 × 34" is the mid-field reading.** Nearest-neighbour parastichies of the
   380-site field run 13 × 21 (inner third), 21 × 34 (middle), 34 × 55 (rim) —
   the paper's claim holds where it says, and the rim reads the next pair.
4. **The throat piezos do not fit around the bore** as specified (item 3 of the
   reconciliation). Design rule DR1 now pins ≥ 0.5 mm.
5. **Mass ≈ 69 kg, not ≈ 50.** Shells 28.9 kg (the 7 kg storage liner and the
   base closure are not in the spec's "~20"), plates + carriers 16.1 kg (four
   faces, the spec counted three), glass 6.4 kg (spec 6.5 ✓), hollow formers +
   windings ~9 kg. Placeholders excluded.
6. **Horn geometry checks out:** meridian arc 187.4 mm (mech §3c: ≈187),
   mouth:throat 11.2:1, fold 9.4:1.

## Validation

`fieldc cad check` (receipt in `Receipts/cad_*.json`):

| gate | measures | bar |
|---|---|---|
| G-CAD1 | every part a closed, outward-oriented solid (edge census on shared vertices) | 0 failures |
| G-CAD2 | mesh volume vs closed form, 77 parts | < 1 % |
| G-CAD3 | 28 design-rule clearances (piezo/bore, winding layers, horn, element holes and webs, wiring-board traces, driver board area, glass, rollers, columns, tiles, …) | all ≥ minimum |
| G-CAD3b | sampled interference between every pair of neighbouring parts | none |
| G-CAD4 | dimension audit vs spec/site (14 checks) | < 0.1 mm |
| G-CAD5 | 21 × 34 parastichies present | present |
| G-CAD6 | horn arc length vs mech §3c | < 1 mm |
| G-CAD7/8 | mass budget; open area slots vs micro-horns | informational |
| G-CAD9 | the engine's plate array (`PlateArray.rh1`) is the CAD's: same sites and element sizes on all four faces, no element rule broken | < 1e-6 mm |

`fieldc cad step` adds **G-STEP**: every B-rep part's exact OpenCascade volume
against the Swift mesh volume — two independent geometry kernels (1.5 % solids,
3 % swept windings; worst part at 0.43× its tolerance, re-run on the resonant
face 2026-11-12).

Unit tests (`fieldc test`) cover the triangulator (60-hole disc exact), revolve
/ sector / torus / extrusion / sweep closure and volumes, the interference test
itself (overlap caught, touching not), the stack, and a model-wide rule check.

## Kernel notes

- Zero dependencies. Every generator builds shared-index topology, so
  watertightness is a property of the construction, which the edge census
  then verifies (it does not weld floats to pass).
- Plate faces are one polygon with ~390 holes; triangulated by a flat-array
  port of Mapbox earcut, sharing vertices with the hole walls.
- The drilled-hole set is decided against a fixed fine slot centreline — it
  once depended on display tessellation, which a unit test caught.
- Wire polygons use an area-equivalent circumradius, so an 8-sided winding
  carries the copper cross-section of the round wire.
- OCCT will not sweep one closed 44-turn periodic spine into a valid solid;
  each STEP winding is eleven valid 4-turn bodies meeting end to end.
- Rendering: section cuts are fragment discards (a wedge, optionally a height
  band); back faces seen through a cut are painted as hatched section caps;
  glass never caps. 4× MSAA offscreen, same pipeline as the live Machine tab.

## Not modelled / open

The gyroid lattice itself (the horn is its envelope), the V-groove
construction of the micro-horn mesh (modelled as biconical holes), the EBG
terminal layer, the photonic tiles' write projector (OPEN in the photonic
note), gaskets, fasteners, interlock and detents, cabling beyond the wiring
boards, the controller, and everything in the base beyond envelopes.
