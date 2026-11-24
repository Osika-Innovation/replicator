# The long-term machine: a materialisation chamber

<div class="lead">The long-term architecture is a chamber that moves matter between forms without touching it: old objects are released into pattern-free stock, the stock is held by species, and new objects are written whole from a stored description. This chapter sets out that machine, the physical floors it cannot go below, and the open questions that decide it. The machine being built first is the <a href="desktop-replicator.html">Desktop Replicator</a>; how the two connect rung by rung is in <a href="upgrades.html">Upgrades</a>.</div>

Everything on this page is either standard physics, arithmetic on published values (Derived), or an explicitly open question with a stated test. Nothing here is a demonstrated capability, a product plan, or a schedule.

## One loop: release, hold, write

The chamber performs three operations on a loop, and the loop is the machine:

1. **Release.** Old matter enters a bin and its pattern is erased — bonds, order and shape removed, while the number of each kind of atom is accounted for. Release has depth tiers: granulate, dissolve into a carrier, or ionise. A household machine works at the shallow tiers and stays at chemical energies.
2. **Hold.** The pattern-free stock waits, kept by species. An ordinary condensed store needs no new physics; more exotic stores are open questions (below).
3. **Write.** A stored description — the object's equation — is projected from the chamber's boundary into the volume, and the object condenses into it throughout the volume at once. The same boundary ports that write also read the result back against the equation.

Only the pattern enters from outside. Matter circulates; energy is lent around the loop and mostly returned.

## The floors (Derived, from the programme's bounds model)

The bounds model (`cad/ultimate-replicator/` in the engineering repository) computes each floor from published constants. For a 250 g iron object:

| Floor | Value | Consequence |
|---|---|---|
| Making mass from energy | 2.25 × 10¹⁶ J (5.4 Mt TNT) | Every design keeps a matter store. What the machine supplies is order, not mass. |
| Chemical write (bonds, 4.3 eV/atom) | 1.9 MJ | The household loop's scale. |
| Deep release (+ first ionisation, 7.9 eV/atom) | 5.3 MJ | Lent, not spent: at 99 % recapture the outside supply is 53 kJ per object; at 99.99 %, 530 J. |
| Pattern erasure (Landauer) | ~7 µJ | Information is thermodynamically free at this scale. |
| Unmixing the bin (separation entropy) | ~10 µJ | The bin's true floor; separation throughput is an engineering problem, not a thermodynamic one. |

Two floors deserve emphasis because they shape everything else:

- **The fault floor.** If energy recapture fails mid-write, the loop energy thermalises in the work volume — 5.3 MJ is a 1.3 kg TNT equivalent. Any materialisation-class chamber therefore carries a thermal dump sized for a full-loop fault. This is a chamber part, not a footnote.
- **The information tier.** An ordered object (metals, ceramics, devices) is kilobytes to megabytes. A disordered object at 10 µm voxels (food, wood, tissue) is about 6 × 10¹¹ bits and fits one cubic centimetre of photorefractive crystal. An atom-exact description of 250 g is 2.7 × 10²⁶ bits — it fits nothing and, on any link that can be built, moves slower than matter: 8,600 years at a petabit per second. Atom-exact objects must travel as matter; everything else can travel as a description.

The boundary itself is never the limit: the holographic capacity of a one-metre spherical screen is ~4 × 10⁶⁹ bits, 43 orders above the largest equation.

## Appearance time

A write takes as long as its slowest of three terms: setting the field across the volume (nanoseconds), streaming the equation (sub-millisecond at mesoscale), and delivering the energy (about 530 s for 250 g at 10 kW). An "instant" write is therefore an energy-storage property of the loop bus, not a field property.

## Open questions, with the tests that close them

Each condition beyond present physics is kept as a door with a decisive, conventional measurement. A door is closed by a measurement, not by an argument.

| Door | Condition | Decisive test |
|---|---|---|
| Coherent condensation (D2) | Binding energy leaves as a coherent wave back into the boundary, not as heat | Calorimetry and emission spectra of a nanoparticle condensed in a shaped field, against the same particle condensed freely |
| Pattern-seeded bulk write (D3) | A field sets composition and outline throughout a volume; chemistry sets the lattice | Shaped-field growth of a nanocrystal of set outline, in parallel at many sites |
| Matter held without extent (D1) | Stock stored outside ordinary space, recovered by species and number | Weigh the whole machine to 1 mg while a 1 kg parcel enters the store (the chamber sits on its balance); regeneration through a sealed wall |
| Recall elsewhere (D7) | A held parcel returns at a different chamber | Two portals on two balances; arrival-time measurement over 300 m with nanosecond clocks |

The chamber works with D1 and D7 closed, as a release–write machine fed from ordinary stock. It cannot work without D2 and D3, which is why the rung ladder tests them at grain scale first.

## The bridge from the Desktop Replicator

Each rung is a smaller instance of the same write operation, and each tests a door at a scale that can be built now: the Desktop Replicator writes millimetre grains in one shaped field (D3 at grain scale); a liquid-host cell adds material identity and micrometre particles; a brick-slab stage writes solid objects from grown crystal bricks; an atom-array chamber tests D2 and D3 at atomic scale; the materialisation chamber writes whole objects. The rung-deletion table in the bounds model records which rungs can be skipped as each test lands.

## Safety by construction

The chamber writes only into a volume its own ports have measured as empty; it releases only what is in the bin; and the bin admits nothing alive. A write that would intersect matter already present is refused, because the boundary sees that matter before it writes. A two-chamber transfer completes only after the receiver reports the object written and verified — the original is released last, and a failure at any step leaves it whole.

<div class="seealso">Related: <a href="architecture.html">Architecture</a> · <a href="matter-loop.html">Scan, recover and matter stores</a> · <a href="upgrades.html">Upgrades</a> · <a href="status.html">Current state</a></div>
