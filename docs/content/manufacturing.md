# From fields to manufactured parts

<div class="lead">A part is made in five steps that share one work volume: feed, trap, move, consolidate and check. Trapping and moving a single small bead are supported by simulation. Joining material, and placing one bead beside another, are not yet shown for the first machine.</div>

The first machine is the [Desktop Replicator](desktop-replicator.html). Scanning, recovery and the stores are in [Scan, recover and matter stores](matter-loop.html).

## The loop: feed, trap, move, consolidate, check

The planner turns the target shape into a timed schedule of drive signals. There are no layers: material can arrive from any direction the fields can reach. Two rules order the steps (Design decision). Every piece has a clear path to its place. Each new piece is joined to material that is already fixed, never to something still floating.

| Step | What happens | In the Desktop Replicator |
|---|---|---|
| 1 · Feed | Material is made available to the fields | Three open crucibles at the back of the chamber: {{c:desktop_geometry.in_chamber_crucibles}} |
| 2 · Trap | Sound from the plates forms quiet pockets that hold a bead or droplet | Two plates {{c:desktop_geometry.gap_mm}} mm apart, twelve sources, tones of {{c:desktop_geometry.comb_tones_hz|khz}} kHz |
| 3 · Move | The drive signals change smoothly and the pockets travel | Same sources; no arm, nozzle or stage |
| 4 · Consolidate | Material that has arrived is joined to what is already there | An addressed heating step that exists only as a model. No recipe yet |
| 5 · Check | The machine senses the result and corrects before errors build up | Piezo discs that listen while driving, plus {{c:mosquito_smi.total_ommatidia}} lasers |

Different regions of the chamber can be at different steps at once. Each step is checked before the next starts, so small errors are fixed before they pile up ([what a scan may claim](matter-loop.html#what-a-scan-is-allowed-to-claim)). Fields can move many grains at once, but the slowest of the five steps sets the build speed (Derived).

## The physics that matters

**Trapping.** A small bead in a sound field is pushed toward the quiet spots (Documented; formula in [Acoustics](acoustics.html#the-radiation-force-and-where-traps-sit)). The force depends on the squared field, so reversing a field does not reverse the force ([why](matter-loop.html#why-reversing-a-holding-pattern-removes-nothing)). Sound does the carrying because it gives about 900,000 times more force per watt than light ([Acoustics](acoustics.html#why-sound-carries-the-force)).

**Moving.** A pocket is carried in two steps: steer the sources toward the next waypoint, then deepen the pocket. In an earlier simulation on a 2,560-element plate, a bead was carried 5 mm up and 5 mm across with a worst error of 0.04 mm (Simulated). It has not been repeated for twelve sources at the {{c:desktop_geometry.gap_mm}} mm spacing.

**Use the gentlest form of matter that works.** Use the lowest of four forms that meets the tolerance. The energy column is for iron (Derived from standard heats of melting, boiling and first ionisation).

| Form | Energy to reach it | Held by | Role |
|---|---|---|---|
| Powder or small beads | about 0 MJ/kg | Sound | Default. Prototype starting point |
| Melt or droplets | about 1 MJ/kg | Sound; induction for metals in the long-term design | Fast bulk build-up. Droplets join on contact |
| Vapour | about 8 MJ/kg | Directed flux and masks | Thin surface coatings |
| Plasma (gas with its electrons stripped) | about 22 MJ/kg | Electric and magnetic confinement | Long-term only: atomic finishing and separating elements |

**Rough in bulk, finish at the surface (Derived).** An iron droplet 0.1 mm across holds about 4 × 10¹⁶ atoms, so a 250 g part is only about 6 × 10⁷ droplets. Bulk can go in as droplets or beads, and only the surface needs the fine, costly forms. [The long-term machine](ultimate-replicator.html#why-the-write-must-be-parallel) gives the atom-by-atom arithmetic.

<a id="consolidation-and-athermal-softening-r15"></a>

## Consolidation

**Sound alone does not melt a levitated grain.** A free grain smaller than a millimetre absorbs far too little ultrasound to sinter or melt. Sound can carry, press and rub material against a fixed surface. Melting or sintering needs a separate, addressed source of heat.

**Heat is spent only at the join (Design decision).** Holding and moving do not warm the part. Heat is added at one spot, at the moment a piece is joined, so a build's heat is the sum of its joins. A droplet needs no joining step: it arrives molten, joins on contact, and the field only holds its shape while it cools (Open).

**The field moulds and the liquid polishes (Derived).** Below a few millimetres, surface tension is stronger than gravity and than any gentle field. Fields set the overall shape of a melt. The liquid sets the fine surface. Smaller features are made after the material is solid.

**Joining without melting everything.** Melting must first warm the whole piece. For iron that costs three to four times the heat of melting itself (Derived: about 0.9 MJ/kg to warm by 1,500 K against 0.25 MJ/kg to melt). The middle way is to make the solid flow like stiff clay. Each effect below is Documented alone, except where marked. Combining them in a chamber is Open.

| Effect | What it does | Source |
|---|---|---|
| Acoustoplasticity | Ultrasound added to a load lowers the stress at which a metal flows by tens of percent, with little bulk heating | [Blaha and Langenecker, 1955](https://doi.org/10.1007/BF00623773) |
| Electroplasticity | Pulsed current lowers the yield stress more than resistive heating explains. The programme's estimate is {{c:dissolve_and_toroidal.electroplastic_energy_reduction_vs_melt_x|range}} times less energy than bulk melting (Derived, Open) | Troitsky, 1969 (Claim) |
| Acoustic fluidisation | Vibration unjams friction between grains | [Melosh, 1979](https://doi.org/10.1029/JB084iB13p07513) |
| Hydrolytic weakening | Trace water and moderate temperature soften quartz | [Griggs, 1967](https://doi.org/10.1111/j.1365-246X.1967.tb06218.x) |
| Driving one crystal vibration | Very short far-infrared pulses flip a material into another state without heating it, for under a trillionth of a second | [Först et al., 2011](https://doi.org/10.1038/nphys2055) |

Latent heat and the entropy that must be exported still set a minimum energy for any joint.

**A proposed joining model (Open).** Each grain is one lump with one temperature. It warms by the heat put in and cools through its surface:

    m · c_p · dT/dt = Q_in − h · A · (T − T_air)

A piece is in the store, on its way, molten, touching a fixed neighbour, or fixed. A 200 µm bead of PLA plastic weighs about 5 µg and needs about 1 mJ to reach its melting range (Derived: 5 µg × about 1.5 J/g·K × 150 K), or about 10 mW for 100 ms. The model reports material fixed inside the target shape and material fixed outside it. The second score counts mistakes.

### In the Desktop Replicator

An earlier plan joined beads with ultraviolet-curing adhesive applied by hand. That route is retired because it put a person in the loop for every joint. The replacement is consolidation by the fields: acoustic pressure, heat and phase change.

- No end-to-end joining recipe has been simulated.
- The prototype's parts list contains no heat source for joining.
- A [pulsed ring coil at a crucible](electromagnetics.html#what-remains-open-a-small-pulsed-ring-coil-at-a-crucible) is a candidate for softening conductive material. It is not in the CAD model.
- The test that would add a joining part is fixed: a second bead placed within 0.25 mm of a held first bead, and a joint that holds ten times the trapping force in shear (Open; see [Architecture](architecture.html#long-term-architecture-and-the-desktop-replicator)).

## A candidate combined-field recipe

Documented outside precedent, not the prototype's route, because it depends on a light-cured resin. Sound arranges particles in a liquid resin and patterned light cures it ([Greenhall and Raeymaekers, 2017](https://doi.org/10.1002/admt.201700122)). A magnetic field orients particles before a UV and thermal cure ([Nagarajan and colleagues](https://pmc.ncbi.nlm.nih.gov/articles/PMC8433740/)). Combining all three is Open. It needs one resin that tolerates acoustic streaming, cure shrinkage and optical attenuation.

## What is not yet shown

These limits bound what the Desktop Replicator can be claimed to do.

| Limit | Evidence | Consequence |
|---|---|---|
| Lift is marginal | Simulated: one 160 kHz tone on the full supply lifts about 1.2 times a foam bead's weight. The voltage margin is 1.19 at the median gap and 0.87 at the worst. Five tones sharing the supply lift about 7 % | One tone holds a foam bead at the median gap but not at the worst gap. Holding a solid bead is a failing simulation check ([Current state](status.html)) |
| A second bead cannot be placed beside a first | Simulated, earlier 4 × 4 and 6 × 6 arrays at 40 kHz: the second bead lands 1 to 2 mm off | Building from more than one bead is Open. Candidate remedies, none chosen: more tones, a structured plate driven from a few inputs, a larger or reshaped set of sources, or moving the work to the bead |
| Fields from few sources contain extra wells | Simulated, earlier six-source study: 8 to 26 unwanted wells in the working region | One bead can be handled. Powder would collect in the wrong places |
| No joining recipe | No simulation exists | A part cannot yet be completed in the model |
| No mass accounting | No simulation tracks mass through a build | Yield and loss are unknown |
| Closed chamber | Design decision: a stock glass cylinder that lifts with the head | Recalibration after each lift. See [Desktop Replicator](desktop-replicator.html#the-enclosure) |
| New plate spacing | Spacing raised from 120 mm to {{c:desktop_geometry.gap_mm}} mm | Results simulated at the earlier spacing do not carry over |

## Long-term direction

A [light-switched surface](acoustics.html#long-term-direction) of roughly 100,000 elements gives many independent pockets and removes most unwanted wells. Three more capabilities belong to that design and not to the prototype.

- **Fine placement by light.** Sound brings a piece within reach and light does the last alignment ([Optics](optics.html#the-size-ladder-for-optical-traps)). The hand-off is Open.
- **Other holds.** A close-wound coil can hold and heat a molten metal drop. An electric field can hold a charged droplet, but only with a fast sensor and correction. Cold, uncharged insulators are the class those fields barely grip, which is why sound is in the machine ([Electromagnetic control](electromagnetics.html)).
- **Automatic feed.** Feedstock rises from a plinth below the build cylinder, sorted and inspected on the way ([the stores](matter-loop.html#the-stores-equation-library-vs-matter-pantry)).

## Open questions

| Question | Who answers it |
|---|---|
| What joins material without adhesive, and where does the heat come from? | Process simulation |
| Which remedy places a second bead beside a first? | Simulation |
| Can twelve sources hold a bead denser than foam, and carry it, at the {{c:desktop_geometry.gap_mm}} mm spacing? | Simulation |
| How are unwanted wells suppressed or tolerated when handling powder? | Simulation |
| Does mass in the part plus mass in the stores stay constant through a build? | Simulation |
| What is the first part the machine makes for itself? | [Upgrade loop](upgrades.html) |

Read next: [Scan, recover and matter stores](matter-loop.html), [Acoustics](acoustics.html), [Materials and modes](materials.html) and [Upgrade loop](upgrades.html).
