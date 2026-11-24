# The long-term machine: a materialisation chamber

<div class="lead">The long-term machine is a chamber that moves matter between forms without touching it. Old objects are released into stock, the stock is held sorted by kind, and new objects are written whole from a stored description. This chapter gives its physical floors and open questions. The machine being built first is the <a href="desktop-replicator.html">Desktop Replicator</a>. The steps between them are in <a href="upgrades.html">Upgrades</a>.</div>

Everything here is standard physics, arithmetic on published values (Derived), or an open question with a stated test. Nothing here is a demonstrated capability or a schedule. Each generation is tuned for a named task and then measured (Design decision).

## One loop: release, hold, write

1. **Release.** Old matter goes into a bin. Its bonds, order and shape are removed, and every atom is still counted. Release has three depths: grind to grains, dissolve into a carrier liquid, or ionise (strip electrons from the atoms). A household machine stays at the shallow depths and at chemical energies.
2. **Hold.** The stock waits, sorted by kind of atom, in [ordinary solid or liquid stores](matter-loop.html#the-stores-equation-library-vs-matter-pantry). More exotic stores are open questions below.
3. **Write.** A stored description, the object's [holographic equation](compute-control.html#holographic-equations), is projected from the chamber's boundary into the volume, and the object forms throughout the volume at once. The same ports read the result back against the description.

Only the description comes from outside. The matter goes round. The energy is borrowed and, at best, mostly given back (Open).

**Layout.** The chamber is the same [two-zone cylinder](architecture.html#long-term-architecture-and-the-desktop-replicator) as the prototype. That table compares two port layouts: a barrel head with 62 ports, and a twenty-faced shell with 12 ports that each carry three fields. A measured test of whether 12 ports are enough decides (Open).

## The floors (Derived, from the programme's bounds model)

A floor is the least that physics allows. The values are for a 250 g iron object.

| Floor | Value | Consequence |
|---|---|---|
| Making mass from energy | 2.25 × 10¹⁶ J (5.4 Mt of TNT) | Every design keeps a matter store. The machine supplies order, not mass |
| Chemical write (bonds, 4.3 eV per atom) | 1.9 MJ | The scale of the household loop |
| Deep release (bonds plus first ionisation, 7.9 eV per atom more) | 5.3 MJ | Lent, not spent. If 99 % is caught again, the outside supply is 53 kJ per object. At 99.99 % it is 530 J |
| Forgetting the old shape (Landauer's limit, the least energy to erase information) | about 7 µJ | Information costs almost nothing here |
| Unmixing the bin (the least energy to sort mixed atoms) | about 10 µJ | Sorting speed is an engineering problem, not a limit of physics |

Each floor answers one question under its stated assumptions. Two floors shape everything else.

- **The fault floor.** If the energy is not caught during a write, it turns to heat inside the chamber. 5.3 MJ is as much as 1.3 kg of TNT, so the chamber carries a heat dump sized for a full fault. The concept design uses a 39-litre ring of water that can take 8.2 MJ (Derived, see [Architecture](architecture.html#long-term-architecture-and-the-desktop-replicator)).
- **The information tier.** A description carries the least detail that still predicts what the part does: shape, material, fit, tolerances and tests, not the place of every atom (Design decision). An ordered object, such as a metal, ceramic or device, is kilobytes to megabytes. A disordered object in 10 µm cells, such as food, wood or tissue, is about 6 × 10¹¹ bits and fits one cubic centimetre of photorefractive crystal, which stores light patterns. An atom-exact description of 250 g is 2.7 × 10²⁶ bits, or 8,600 years at a petabit per second. Atom-exact objects must travel as matter. Everything else can travel as a description.

**How lent energy could come back (Open).** Each row is an ordinary catcher, not a source of energy. No return fraction is claimed.

| Energy left over as | Part that could catch it | Evidence |
|---|---|---|
| Microwaves of one steady frequency | An antenna with a built-in rectifier, a one-way valve for current | Above 80 % (Claim, no source registered) |
| Glow of a hot part as it cools | Solar-cell-like panels tuned to heat glow | About 40 %, with a 2,400 °C emitter (Documented: [LaPotin et al., 2022](https://doi.org/10.1038/s41586-022-04473-y)). Iron melts near 1,540 °C, where the efficiency is lower |
| Sound and vibration | The piezo sources, which work both ways | Open |
| A field still ringing in the chamber | Absorbing it back through the ports as work, not heat ([coherent perfect absorption](matter-loop.html#the-four-stage-sequence)) | Open |

## Why the write must be parallel

A cup holds about 3 × 10²⁴ atoms. Building it in five minutes means placing about 10²² atoms every second (Derived: 3 × 10²⁴ ÷ 300 s).

| How atoms are placed | Rate | Time for one cup |
|---|---|---|
| One nozzle or beam | 10⁹ atoms per second | about 95 million years |
| A million tips working together | 10¹⁵ per second | about 95 years |
| The whole boundary shaping the whole volume at once | 10²² per second (needed, not shown) | minutes |

Only a field that addresses the whole volume at once can do this. Bulk does not need atom-by-atom placing: a 0.1 mm droplet already carries about 10¹⁶ atoms ([Manufacturing](manufacturing.html#the-physics-that-matters)). The limit is how many independent controls the walls offer, not their power (Open).

## Appearance time

A write takes as long as the slowest of: setting the field across the volume (nanoseconds), streaming the description (under a millisecond for grain-scale detail), and delivering the energy (about 530 s for 250 g at 10 kW). Speed is therefore set by how much energy the loop can store and release, not by the field.

## Open questions, with the tests that close them

Each condition beyond present physics is a numbered door with a decisive, conventional measurement.

| Door | Condition | Decisive test |
|---|---|---|
| D2 · Coherent condensation | Binding energy leaves as an orderly wave back into the boundary, not as heat | Heat and light given off by a nanoparticle formed in a shaped field, against the same particle formed freely |
| D3 · Pattern-seeded bulk write | A field sets composition and outline throughout a volume. Chemistry sets the crystal lattice | Shaped-field growth of a nanocrystal of set outline, at many sites in parallel |
| D1 · Matter held without extent | Stock stored outside ordinary space, recovered by kind and number | Weigh the whole machine to 1 mg while a 1 kg parcel enters the store. Regenerate it through a sealed wall |
| D7 · Recall elsewhere | A held parcel returns at a different chamber | Two chambers on two balances. Arrival time over 300 m with nanosecond clocks |

The chamber works without D1 and D7, as a release and write machine fed from ordinary stock. It cannot work without D2 and D3, so the steps below test them at grain scale first.

## The bridge from the Desktop Replicator

Each step is a smaller case of the same write operation.

1. The Desktop Replicator writes millimetre grains in one shaped field (D3 at grain scale).
2. A liquid-filled cell adds material identity and micrometre particles.
3. A brick stage writes solid objects from grown crystal bricks.
4. An atom-array chamber tests D2 and D3 at atomic scale.
5. The materialisation chamber writes whole objects.

A step can be skipped once its test passes. A prototype part is replaced only when its measured test passes ([the swap rule](upgrades.html#the-swap-rule)).

## Safety by construction

The chamber writes only into a volume its own ports have measured as empty, and refuses a write that would overlap matter already present. It releases only what is in the bin, and the bin admits nothing alive. A transfer between two chambers releases the original last, after the receiver reports the object written and verified, so a failure at any step leaves it whole.

<div class="seealso">Related: <a href="architecture.html">Architecture</a> · <a href="matter-loop.html">Scan, recover and matter stores</a> · <a href="upgrades.html">Upgrades</a> · <a href="status.html">Current state</a></div>
