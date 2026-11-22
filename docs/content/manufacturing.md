# From fields to manufactured parts

<div class="lead">A part is made in five steps that share one work volume: feed, trap, move, consolidate and check. Trapping and moving a single small bead are supported by simulation on earlier apertures. Joining material, and placing one bead beside another, are not yet shown for the first machine.</div>

Nothing on this page has been built or measured. The first machine is described in [Desktop Replicator](desktop-replicator.html). Scanning, removal of material and the stores are in [Scan, recover and matter stores](matter-loop.html).

## The loop: feed, trap, move, consolidate, check

Before the loop starts, the planner turns the target shape into a timed schedule of drive signals. The schedule is not sliced into layers: material can arrive from any direction that the fields can reach.

| Step | What happens | In the Desktop Replicator |
|---|---|---|
| 1 · Feed | Material is made available to the fields | Three open crucibles at the back of the chamber: {{c:desktop_geometry.in_chamber_crucibles}} |
| 2 · Trap | Sound from the plates forms quiet pockets that hold a bead or droplet | Two plates {{c:desktop_geometry.gap_mm}} mm apart, twelve sources, tones of {{c:desktop_geometry.comb_tones_hz|khz}} kHz |
| 3 · Move | The drive signals change smoothly and the pockets travel | Same sources; no arm, nozzle or stage |
| 4 · Consolidate | Material that has arrived is joined to what is already there | By the fields themselves. No recipe simulated yet |
| 5 · Check | The machine senses the result and corrects before errors build up | Piezo discs that listen while driving, plus {{c:mosquito_smi.total_ommatidia}} lasers |

Different regions of the chamber can be at different steps at once. Each piece of material passes through them in order.

## The physics that matters

**Trapping.** A small sphere of radius a in a sound field feels the Gor'kov potential (Documented):

    U = (4/3) π a³ [ f₁ · ½ κ₀ ⟨p²⟩ − f₂ · ¾ ρ₀ ⟨v²⟩ ],     F = −∇U

Here ⟨p²⟩ and ⟨v²⟩ are the time-averaged squared pressure and air velocity, κ₀ and ρ₀ are the compressibility and density of air, and f₁ and f₂ are contrast factors close to 1 for any solid or liquid in air. Such material is pushed toward places where the pressure is quiet. The force depends on the squared field, which is why reversing a field does not reverse the force (see [removal](matter-loop.html#recover-dissolve-material-specific-separation-and-reuse)). The full treatment is in [Acoustics](acoustics.html).

**Why sound does the carrying.** A wave of power P that is absorbed pushes with force P/c, where c is the wave speed. One watt of sound in air (343 m/s) gives 2.9 mN. One watt of light gives 3.3 nN. Sound delivers about 900,000 times more force per watt (Derived), so sound moves material and light is kept for sensing and, in the long-term design, for fine alignment.

**Moving.** A pocket is carried by updating the steering of the sources toward the next waypoint first and optimising the depth of the pocket second, which keeps the pocket deep during travel. In an earlier simulation on a 2,560-element plate, a bead was carried 5 mm up and 5 mm across with a worst error of 0.04 mm (Simulated). That result is for a different aperture. It has not been repeated for twelve sources at the {{c:desktop_geometry.gap_mm}} mm spacing.

**Use the gentlest form of matter that works.** Feedstock can be handled in four forms of increasing energy cost. The rule is to use the lowest one that meets the tolerance.

| Form | Held by | Role |
|---|---|---|
| Powder or small beads | Sound | Default. Lowest energy per kilogram. Prototype starting point |
| Melt or droplets | Sound; induction for metals in the long-term design | Fast bulk build-up. Droplets join on contact |
| Vapour | Directed flux and masks | Thin surface coatings |
| Plasma | Electric and magnetic confinement | Long-term only: atomic finishing and separating elements |

<a id="consolidation-and-athermal-softening-r15"></a>

## Consolidation

**Sound alone does not melt a levitated grain.** A free grain smaller than a millimetre absorbs far too little ultrasound to sinter or melt. An earlier slogan to the contrary is retired. Sound can carry, press and rub material against a surface that is already fixed. Melting or sintering needs a separate, addressed source of heat.

**Joining without melting everything.** Heating a whole part past its melting point spends energy on material that does not need to flow. Between holding a solid and melting it lies field-assisted plastic flow, sometimes called athermal softening (R15 in the engineering record). Each effect below is Documented separately. Combining them in a chamber is Open.

- **Acoustoplasticity (Blaha effect).** Ultrasound superimposed on a load lowers the flow stress of a metal by tens of percent with little bulk heating.
- **Electroplasticity (Troitsky).** Pulsed current lowers yield stress by more than resistive heating explains. The programme's estimate is {{c:dissolve_and_toroidal.electroplastic_energy_reduction_vs_melt_x|range}} times less energy than bulk melting (Derived, Open).
- **Acoustic fluidisation (Melosh).** Vibration unjams friction between grains.
- **Hydrolytic weakening (Griggs).** Trace water and moderate temperature soften quartz.

None of this removes the thermodynamic floor. Latent heat and the entropy that must be exported still set a minimum energy for any joint.

### In the Desktop Replicator

An earlier plan joined beads with ultraviolet-curing adhesive applied by hand. That route is retired because it put a person inside the loop for every joint. The replacement is consolidation by the fields themselves: acoustic pressure, heat and phase change, for example a droplet that wets its neighbour and solidifies. Stated plainly:

- No end-to-end joining recipe has been simulated.
- The prototype's parts list contains no heat source for joining.
- A compact pulsed ring coil at a crucible is a candidate for softening conductive material. It is not in the CAD model. See [Electromagnetic control](electromagnetics.html).

## A candidate combined-field recipe

This section records Documented external precedent. It is not the prototype's joining route, because it depends on a light-cured resin.

In published work, sound arranges particles in a liquid resin, a magnetic field orients particles that respond to it, and patterned light cures the resin around them. Two pairings have been demonstrated. Greenhall and Raeymaekers combined ultrasound-directed particle assembly with stereolithography to build patterned composites ([Ultrasound and stereolithography](https://doi.org/10.1002/admt.201700122)). Nagarajan and colleagues combined magnetic particle alignment with jetting, published UV curing and a thermal post-cure ([Magnetic alignment and curing](https://pmc.ncbi.nlm.nih.gov/articles/PMC8433740/)).

Combining all three would require one resin and suspension that tolerates acoustic streaming, cure shrinkage and optical attenuation, and a measured improvement over the simpler pairings. The precedent shows that fields can arrange and orient material in one volume while it is being fixed in place.

## What is not yet shown

These limits come from the programme's own simulation record. They bound what the Desktop Replicator can be claimed to do.

| Limit | Evidence | Consequence |
|---|---|---|
| A second bead cannot be placed beside a first | Simulated, earlier 4 × 4 and 6 × 6 arrays at 40 kHz: the second bead lands 1 to 2 mm off | Building anything from more than one bead is Open. Four remedies are listed; none is chosen |
| Fields from few sources contain extra wells | Simulated, earlier six-source study: 8 to 26 unwanted wells in the working region | One bead can be handled. Powder would collect in the wrong places |
| No joining recipe | No simulation exists | A part cannot yet be completed in the model |
| No mass accounting | No simulation tracks mass through a build | Yield and loss are unknown |
| Closed chamber | Design decision: a glass cylinder that lifts with the head | Recalibration after each lift; clear glass does not enclose the lasers |
| New plate spacing | Spacing raised from 120 mm to {{c:desktop_geometry.gap_mm}} mm | Earlier acoustic results do not carry over |

The remedies under consideration for the second bead are more tones, a structured plate driven from a few inputs, a larger or differently shaped aperture, and a process in which the work moves to the bead.

## Long-term direction

The long-term design replaces twelve wired sources with a surface of roughly 100,000 optically switched elements, which gives many independent pockets and removes most unwanted wells. Three further capabilities belong to that design and not to the prototype:

- **Fine placement by light.** Sound brings a piece to within reach, then holographic optical tweezers (Documented: Ashkin; Grier) align it to nanometre tolerances. Below a few tens of nanometres thermal motion beats a plain optical trap, and near-field traps are needed. The hand-off from sound to light is Open.
- **Other ways to levitate.** Molten metals can be held and heated by induction, and charged droplets electrostatically under fast active control. Large coils acting across the whole chamber were studied and produce negligible force, so induction is a long-term, close-range option.
- **Automatic feed.** Feedstock would rise from a storage chamber below the build chamber, sorted and inspected on the way. See [the stores](matter-loop.html#the-stores-pattern-library-vs-matter-pantry).

## Open questions

| Question | Who answers it |
|---|---|
| What joins material without adhesive, and where does the heat come from? | Process simulation |
| Which remedy places a second bead beside a first? | Simulation |
| Can twelve sources and five tones hold and carry a bead at the {{c:desktop_geometry.gap_mm}} mm spacing? | Simulation |
| How are unwanted wells suppressed or tolerated when handling powder? | Simulation |
| Does mass in the part plus mass in the crucibles stay constant through a build? | Simulation |
| What is the first part the machine makes for itself? | [Upgrade loop](upgrades.html) |

Read next: [Scan, recover and matter stores](matter-loop.html), [Acoustics](acoustics.html), [Materials and modes](materials.html), [Upgrade loop](upgrades.html) and the earlier paper [Assemble](../papers/replicator_assemble.html).
