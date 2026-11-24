# Scan, recover and matter stores

<div class="lead">A machine that improves itself must see what is in the chamber, take material away as well as add it, and keep its feedstock in a safe form. This chapter covers scanning, recovery and the stores. Adding material is in <a href="manufacturing.html">Manufacturing</a>.</div>

Scanning rests on standard scattering physics and simulation. Recovery is a Derived plan whose removal step runs only in simulation. The first machine is the [Desktop Replicator](desktop-replicator.html).

## Scan: non-moving 3D tomography and scattering

A scan records how the chamber answers every drive the machine can apply, first empty and then with the object inside. The difference belongs to the object (Open in the chamber).

### The physics that matters

**The scattering matrix.** Drive the boundary with a list of signals a at frequency f, and it receives b = S(f) a. S(f) is a table of how every source is heard by every receiver.

| Feature of S(f) | Physical meaning | Used for |
|---|---|---|
| Poles (resonances) | Notes at which the object rings. Pitch and fading rate depend on shape and stiffness | Identifying materials and joints by ring-down |
| Self-returning patterns (eigenvectors) | Drive patterns that come back with the same shape, shifted in time | The object's own typical views |
| Zeros | Drive patterns that are completely absorbed | Putting energy in a chosen place ([recovery](#the-four-stage-sequence)) |

**Every scan is a comparison (Design decision).** Dividing the recording with the object by the empty recording removes what the walls, echoes and sources add. The empty recording is repeated whenever the chamber changes, including after each lift of the [glass cylinder](desktop-replicator.html#the-enclosure), which also shields the scan from draughts.

**Nothing moves (Design decision).** A flat face is seen only if some source, receiver and frequency catch its mirror reflection, so fixed sources leave some faces unseen. Three fixed remedies, in order of preference:

1. **Wall reflections.** A known reflecting wall acts as a mirror image of the array (Documented in ultrasonic testing: [Zhang et al., 2010](https://doi.org/10.1016/j.ndteint.2009.10.001)). This needs a measured empty-chamber response.
2. **Several frequencies.** Each tone bends round the object differently.
3. **Side sightlines.** Two facing plates resolve the plane midway between them poorly. A sensor looking across the chamber fills that band.

**What adds information (Derived).** With N sources, every drive pattern is a mix of the N single-source responses. A cleverer pattern, or a wiser choice of the next measurement, gives a cleaner signal and shows nothing new. New information comes from different frequencies, from different positions (real or mirrored in a known wall), and from sound launched by a spot of light where no disc sits (long-term, see [Optics](optics.html#long-term-direction)).

**Few sensors far apart see ghosts (Documented, source not yet registered).** Sensors spaced much more than half a wavelength apart cannot tell a true echo direction from several false ones. A scan from a sparse ring must name its cure: close spacing along one line, many frequencies at once, or reconstruction built for sparse data.

**Two contrasts from two directions (Derived).** For a weak scatterer, the amplitude scattered through an angle θ follows

    f(θ) ∝ k² [ γ_κ + γ_ρ cos θ ]

Here γ_κ is the contrast in compressibility (squashiness) and γ_ρ the contrast in density. Squashiness scatters equally in all directions. Density scatters forward and backward with opposite signs. Forward scatter reads γ_κ + γ_ρ and backscatter reads γ_κ − γ_ρ, so two facing plates separate the two contrasts at one frequency. The same two contrasts set the [holding force](acoustics.html#the-radiation-force-and-where-traps-sit), so what the machine can grip well it can also see well.

**In air, sound sees surfaces only (Derived).** A solid has an acoustic impedance of 10 to 46 MRayl against 415 Rayl for air, so its surface reflects more than 99.98 % of the energy. A rigid solid gives a sharp outline and little else. Foams, droplets and gels can be told apart directly. Rigid solids are told apart by ring-down, whose notes scale as √(E/ρ)/L for stiffness E, density ρ and size L. Seeing inside a solid needs a liquid around it, which is long-term.

**Reading resonances from ring-down (Documented method: [Hua and Sarkar, 1990](https://doi.org/10.1109/29.56027); Simulated in the twin).** The decay at each sensor is a sum of fading tones. The matrix pencil method fits all the records together and returns each tone's pitch, fading rate and strength at each sensor.

- The record must be a real decay in time, from a chamber with loss. A steady-tone solver cannot supply it.
- Read early. In an earlier simulation on a spherical model, the echoes of two different objects were 0.76 alike just after the pulse and 0.92 alike four times later (Simulated).
- Two shapes can share the same pitches. The strength of each resonance at each sensor breaks the tie.

**A resonance takes time to answer (Derived).** A resonance of sharpness Q at frequency f needs about Q/f seconds to ring up. Q = 100 at 32 kHz takes about 3 ms, and higher tones answer sooner.

**How sharp a scan can be.**

| Method | Smallest detail | Evidence |
|---|---|---|
| Many tones, full wave fit, in air | Half the shortest wavelength, on surfaces only. At the top of the {{c:desktop_geometry.golomb_band_khz|range}} kHz scan band that is about 0.9 mm (343 m/s ÷ 198 kHz ÷ 2) | Derived |
| Guessing a little beyond the measured band | About 2 times finer, limited by noise | Derived |
| Listening at overtones of the drive | A few times finer | Documented in medical ultrasound, source not yet registered |
| Small resonators placed next to the object | About 1/30 of a wavelength, with microwaves ([Lerosey et al., 2007](https://doi.org/10.1126/science.1134824)) | Documented; Open here |
| Finding the centre of a separate small object | About 1/100 of a wavelength, in medical ultrasound ([Errico et al., 2015](https://doi.org/10.1038/nature16066)) | Documented; Open here |

The last row matters most, because the feedstock is separate beads of known size.

### In the Desktop Replicator

**Acoustic scan.** The twelve piezo discs that drive the plates also listen on the same wires ([Acoustics](acoustics.html#self-sensing-on-the-same-two-wires)). The plan holds steady tones about 95 % of the time and spends 5 % on chirps, sweeps in pitch of about 200 microseconds. A levitated particle takes roughly 10 ms to respond, so scanning does not disturb what is held (Derived). The scan band is {{c:desktop_geometry.golomb_band_khz|range}} kHz.

**A speaking order for twelve sources (Derived; Open in the chamber).** The simplest scan lets one source speak while all listen. A faster one changes source and frequency together, in an order that makes echoes least likely to be confused: in slot k, source 2ᵏ mod 13 speaks (a Welch–Costas sequence, which exists because 13 is prime).

**Side sightline.** The ring of {{c:mosquito_smi.total_ommatidia}} laser diodes gives a shadow image and an independent reading of the sound field ([Optics](optics.html#in-the-desktop-replicator)).

**Sound alone cannot tell dense solids apart (Simulated).** Sorting solids by their echoes at a realistic noise level is right 9 % of the time, near chance. Adding the response to a pulsed electromagnetic field, optical reflectance in two bands, and density from motion in the sound field separates eleven test materials completely in the model. The electromagnetic channel is long-term: the Desktop Replicator has no such coil.

**Touching beads scatter together (Derived).** Two to four beads in contact do not scatter as the sum of separate beads. The difference is 2 to 6 % at 32 kHz, 11 to 51 % at 64 kHz and complete at 96 kHz and above. A scan of a cluster must model each bead re-scattering sound from its neighbours.

### From echoes to a picture

The same recordings become a picture in four ways, run cheapest first and compared (Design decision; none has run on chamber data). If two levels disagree, at least one is wrong.

| Level | Method | What it gives | Caution |
|---|---|---|---|
| 1 | Add up echoes by travel time | A map of where sound bounced, in milliseconds | It shows brightness, not shape. It must not be turned into a solid by picking a brightness level |
| 2 | Split the response table into its strongest parts (Documented: [Prada et al., 1996](https://doi.org/10.1121/1.415393)) | The separate scatterers, in milliseconds | See the three facts below |
| 3 | Fit a simple model with a smoothness penalty | A first estimate of the object, in seconds | Needs the measured chamber response |
| 4 | Fit the full wave model | The object itself, in minutes | Slow, and the fit has many false answers |

**The wrong-empty-chamber trap (Derived).** Levels 3 and 4 need to know how sound travels from every point inside to every sensor. In a closed, ringing chamber that map changes with tiny changes in shape, so it must be recorded, never assumed. The open-air formula gives a sharp, confident and meaningless picture.

**Three facts about the response table (Derived).**

- One small sphere can show up as up to four strong parts: one for its swelling and three for its sloshing. The number of strong parts is not the number of objects.
- Each chamber wall gives its own strong, steady part. Comparing with the empty chamber removes these.
- In still air, source A heard at B matches B heard at A. If the mismatch exceeds 10 % of the table's size, suspect the calibration and not the object.

To count strong parts in unknown noise, a published rule keeps those above 2.858 times the median (Documented: [Gavish and Donoho, 2014](https://doi.org/10.1109/TIT.2014.2323359)).

<a id="reconstruction-honesty-and-static-validation-g17-g18-g19"></a>

### What a scan is allowed to claim

The software checks among these rules run on simulated data (Simulated).

- **Measured or inferred, always stated.** Every stored pattern says which it is, with no default, and an inferred one names its model. The file reader rejects a pattern without this. A stored description is also the build target, so a guessed interior would be built and then seem to confirm the guess (Derived). See [chord memory](cadence-memory.html#chord-memory).
- **Seen full, seen empty, or not seen.** Every point of a scan carries one of three marks, never blended or smoothed. Anything filled in by a model is drawn differently and left out when a build is checked, unless a person promotes it on the record (Design decision).
- **Two scores.** Accuracy is quoted over the whole object and over the seen part only. The whole-object score has no pass mark, because one would reward filling gaps with guesses.
- **Held-out prediction.** The chamber model must predict a quarter of the source and receiver pairs that were withheld from it. It passes on simulated data. Whether it keeps an earlier bar (under 15 % error on withheld pairs, at most 1.5 times the error on used pairs) is Open.
- **A known reference object.** Absolute size error is checked against a precisely made reference object in the chamber. Not yet run.
- **A matching echo is not a passed part.** A part is accepted on its measured size, its material and a test of what it must do, together (Design decision).
- **Display filters stay out.** Sharpening an image for a person is never fed back into reconstruction as data.

**Long-term.** A [light-switched surface](acoustics.html#long-term-direction) of roughly 100,000 elements removes unseen faces by coverage (Open).

## Recover (Dissolve): material-specific separation and reuse

Recovery succeeds when the material that comes out has a known make-up and can be used again. The plan is Derived, with published precedent for one step, and Open in the chamber.

Building and recovering share the chamber, the models and the sensors (Design decision). Their recipes differ, and a recovery route may need its own module or an outside finishing step. Parts are designed for recovery: reachable joints, materials that can be told apart, modules that come apart, and a record of how each part was made.

### Why reversing a holding pattern removes nothing

The pressure field is p = H·u. Here u is the drive signals and H the chamber's response. A star means mirrored in time.

    H·u* ≠ (H·u)*           mirroring the drive does not mirror the field
    |p*|² = |p|²            the force is unchanged: the same trap

Sound takes time to cross the chamber, so a mirrored drive does not mirror the field. Even if it did, the [radiation force](acoustics.html#the-radiation-force-and-where-traps-sit) depends only on the squared size of the pressure and of its slope. The same trap is rebuilt. Negative sound intensity, which would push material out of a well, does not exist.

The simulation and the twin now implement removal as absorption at a measured resonance followed by transport to a store (Simulated; in revision S the store is the bucket under the mid-plane, route Open). The earlier shortcut, replaying a mirrored holding pattern, was wrong and has been removed from the code.

### The four-stage sequence

The model keeps two fields: density ρ(x), which says where material is, and bond strength b(x), which says whether it is joined. Assembly moves ρ into place and then raises b. Removal must lower b first, because bonds are far stronger than acoustic forces.

<div class="diagram">
<svg viewBox="0 0 880 200" role="group" aria-labelledby="remove-title remove-desc" xmlns="http://www.w3.org/2000/svg">
<title id="remove-title">Four stages of removing joined material</title>
<desc id="remove-desc">Four boxes in a row joined by arrows: ring-down scan, absorption at a measured resonance, cold unbinding, and transport back to a crucible. In stage two the energy goes to whatever is lossy at that resonance, which is the joint only if the joint is the lossy part. Bond strength falls in stage three and density moves in stage four.</desc>
<defs><marker id="arrow-remove" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8" fill="#186b60"/></marker></defs>
<g fill="#f2f5ef" stroke="#186b60" stroke-width="1.5">
<rect x="10" y="20" width="190" height="96" rx="9"/><rect x="233" y="20" width="190" height="96" rx="9"/><rect x="456" y="20" width="190" height="96" rx="9"/><rect x="679" y="20" width="190" height="96" rx="9"/>
</g>
<g stroke="#186b60" stroke-width="1.5" marker-end="url(#arrow-remove)"><path d="M200 68 H231"/><path d="M423 68 H454"/><path d="M646 68 H677"/></g>
<g fill="#173630" font-family="system-ui,sans-serif" text-anchor="middle" font-size="16">
<text x="105" y="50" font-weight="600">1 · Ring-down scan</text><text x="105" y="74" font-size="13">find the resonances</text><text x="105" y="94" font-size="13">of the joint</text>
<text x="328" y="50" font-weight="600">2 · Absorption</text><text x="328" y="74" font-size="13">drive that reflects least</text><text x="328" y="94" font-size="13">energy goes to what is lossy</text>
<text x="551" y="50" font-weight="600">3 · Cold unbinding</text><text x="551" y="74" font-size="13">short high-peak pulses</text><text x="551" y="94" font-size="13">break the bond</text>
<text x="774" y="50" font-weight="600">4 · Return</text><text x="774" y="74" font-size="13">carry freed material</text><text x="774" y="94" font-size="13">to a crucible</text>
<text x="105" y="150" font-size="13">b high · ρ in part</text><text x="328" y="150" font-size="13">b high · ρ in part</text><text x="551" y="150" font-size="13">b falls to zero</text><text x="774" y="150" font-size="13">ρ moves to crucible</text>
<text x="440" y="186" font-size="13">Throughout: mass in the part + mass in the crucibles = constant</text>
</g>
</svg>
</div>

1. **Ring-down scan.** Excite the chamber briefly at low power and read the joint's resonances ([scanning](#scan-non-moving-3d-tomography-and-scattering)).
2. **Absorption at a measured resonance.** The machine searches for the mix of drive signals that sends the least sound back (the smallest singular vector of S at that frequency). The energy goes into whatever is lossy at that resonance. That is the joint only if the joint is the lossy part (Derived). It may be the air, glass or mounts. Perfect absorption is Documented in optics ([Chong et al., 2010](https://doi.org/10.1103/PhysRevLett.105.053901); [Wan et al., 2011](https://doi.org/10.1126/science.1200735)). Energy in a joint may only warm, bend or damage it. It does not undo chemistry.
3. **Cold unbinding.** Break the bond without heating the bulk, with short, high-peak pulses at a very low duty cycle, or a pulsed electric field from a [small ring coil at a crucible](electromagnetics.html#what-remains-open-a-small-pulsed-ring-coil-at-a-crucible). Which joints this releases is Open.
4. **Return to a store.** Reshape the field so the freed fragment sits on a slope instead of in a well, and carry it back. Mass in the part plus mass in the stores stays constant.

**Time reversal is a way to aim (Documented: [Fink, 1992](https://doi.org/10.1109/58.156174); [Wu et al., 1992](https://doi.org/10.1109/58.156175); [Draeger and Fink, 1997](https://doi.org/10.1103/PhysRevLett.79.407)).** Record how a sound arrives, play the recording backwards, and the sound returns to where it came from. This works while the chamber stays the same between recording and playback. More sources and more tones sharpen the focus. It puts energy in a known place. It does not choose which bond breaks and does not remove material. A joint changes as it is worked, so the recording is renewed.

### Material-specific routes

Wave energy cannot un-react a cured polymer, reverse metal diffusion or sort a mixed alloy. Recovery uses the least disruptive route that works.

| Priority | Route | What must be qualified |
|---:|---|---|
| 1 | Release a reversible joint (wax, solder, soluble binder) and recover the module whole | Release threshold; damage and contamination afterwards |
| 2 | Soften or remelt compatible thermoplastics or low-melting metals into droplets or powder | Thermal history, oxidation, viscosity, solidification |
| 3 | Break up loosely bound composites or powders acoustically or mechanically | Particle size, wear contamination, yield |
| 4 | Separate chemically into pure, oxidised stock | Selectivity, side products, energy, purity of each lot |

**Sort with the cheapest tool that works (Derived).** Chemistry sorts bulk material for about a megajoule per kilogram. Sorting atoms one by one with fields costs about 1 keV per atom, which for iron is about 480 kWh per kilogram (1 keV × 1.08 × 10²⁵ atoms). Chemistry sorts the bulk and the atom sorter the last traces.

**Count all the energy (Design decision).** A recovery run books the energy for driving, heating, melting, chemistry, sorting, pumping and cooling. Energy won back is listed separately. A recovery module earns its place only if the measured total cost goes down. The floors are in [The long-term machine](ultimate-replicator.html).

**The ledger (Design decision).** Every recovery run lists what went in, what was added, the stock that came out, leftovers, captured fumes and what stays inside the machine, with losses and the uncertainty of each number. A melted part is not pure stock by default. Each returning batch carries a number, its history and a pass or fail result. Different materials are kept apart.

### The first recovery test

A first test closes the loop once, on one known joint, part or single-material scrap (Design decision; not yet run). The wanted output, the reuse test and the pass numbers are written down first. Everything that goes in and comes out is weighed, and the energy is booked. The loop is closed when a second accepted part is built from the recovered material. Materials are then added one at a time, and the result is compared with an outside recycler.

### Recovery in the Desktop Replicator

The prototype can listen for ring-down and search for a least-reflection drive with its twelve sources. It has no heat source and no pulsed coil for stage 3 ([Manufacturing](manufacturing.html#consolidation)). Removal runs in the twin only (Simulated). Loose material is returned to an open crucible.

## The Stores: equation library vs. matter pantry

The equation store holds information. The matter stores hold atoms.

| Store | Holds | Constraint | In the Desktop Replicator |
|---|---|---|---|
| Equation store | [Holographic equations](compute-control.html#holographic-equations) of objects, the calibrated chamber response, the trained [pattern network](cadence-memory.html), build recipes | Storage capacity; every item tagged measured or inferred | Workstation disk, plus under {{c:cadence_brain.cadence_sparse_max_kb}} kB on the compute card |
| Matter stores | Feed materials | Conservation of mass, chemical stability, safety | Revision S: one storage bucket under the mid-plane cassette. The earlier three open crucibles are retired |

### Stores in the Desktop Replicator

The store holds material of recorded origin. In revision S it is a fixed 10-litre glass bucket under the chamber, with a waterproof plug as its floor. The earlier bottles, pump, liquid line and weigh cells are not in the default CAD, so how feed is dosed and weighed is Open ([Storage and release plinth](subsystems.html#s02-storage-and-release-plinth)).

**Material moves as neutral grains (Design decision).** A stream of charged particles would repel itself and screen the fields meant to steer it. Stray static charge on a bead is limited to {{c:electrostatics_and_matter_loop.max_bead_charge_pc}} pC by grounded, slightly conductive glass and controlled humidity ([Desktop Replicator](desktop-replicator.html#the-enclosure)).

**Mass accounting.** The goal is that mass in the part plus mass in the stores stays constant through a build, read on the weigh cells. No threshold is fixed, and no simulation yet tracks mass through a build.

### Staples, not parts

The long-term store keeps elements in bulk, not small copies of objects (Derived; long-term design).

| Store | Gives | Kept as |
|---|---|---|
| Water | Hydrogen, oxygen | Tank |
| Carbon | Carbon | Solid graphite block |
| Air | Nitrogen, oxygen, 0.93 % argon | Not stored. Filtered from the room |
| Salt | Metals whose salts dissolve (sodium, calcium, magnesium, lithium) | Brine that can be pumped |
| Ash | Silicon, aluminium, iron, calcium as oxides | Dry inert solid |
| Noble gases | Helium, neon, krypton, xenon | One small pressure bottle |
| Trace rack | Rare elements for the last few recipes | Small sealed cartridges, each in its most stable form |

### Store oxidised, never as reactive powder (Derived)

Bulk stock is kept in its most stable chemical form and made reactive only at build time. A fine pure metal powder is a fire hazard with a shelf life. The stored form must still suit the material and the next process, and each batch is checked (Design decision). Hot, molten or charged material is a form for moving, never for storing.

- **Reactive metals cannot sit near water as powder.** Per kilogram in contact with water, finely divided lithium releases 1,762 L of hydrogen, aluminium 1,359 L, magnesium 1,006 L, iron 657 L, calcium 610 L and sodium 532 L.
- **Salt and ash.** The same light metals form very soluble chlorides (LiCl about 830 g/L, CaCl₂ 745, MgCl₂ 540, NaCl 360) and store as brine. Insoluble oxides (SiO₂, Al₂O₃, Fe₂O₃, CaO) form an inert ash.
- **Noble gases in a pressure bottle.** Water dissolves too little of them. A steel bottle at 200 bar holds 3,900 to 21,000 times more per litre.

| Gas | Dissolves in water (mg/L, 25 °C) | In a 200 bar bottle (g/L, 20 °C) | Air needed for 1 g (m³) |
|---|---:|---:|---:|
| Helium | 1.5 | 31 | 1,166 |
| Neon | 9.1 | 154 | 67 |
| Argon | 56 | 355 | taken from air as needed |
| Krypton | 210 | 978 | 256 |
| Xenon | 578 | 2,281 | 2,140 |

The bottle values use the Peng–Robinson gas equation. The school gas law gets xenon wrong by 2.1 times. Extracting a gram of xenon from air costs about 714 kWh.

**The number of containers is a sorting choice (Derived).** Separate containers mean the sorting was paid for when the stock was bought. One mixed heap means paying at build time. The plan starts with about four stores and one cartridge and merges them as sorting gets cheaper. Brine and ash merge last, because separating them means boiling off the water.

**How big the store must be (Derived; no volumes are fixed).** A machine that recovers what it made stores only what is kept or used up. Recovery does not return the mix that building uses: making food and recovering plates leaves too much carbon and too little iron. The trace rack and fresh supply cover the difference.

**Long-term layout.** The stores sit in the plinth of the [two-zone cylinder](architecture.html#long-term-architecture-and-the-desktop-replicator), which sorts, inspects and prepares stock. Recovered stock gets the same check as bought stock (design direction; no model result yet).

## Open questions

Physical removal has not been shown and runs only in simulation. The build-side limits are in [Manufacturing](manufacturing.html#what-is-not-yet-shown).

| Question | Who answers it |
|---|---|
| Is ring-down readable in this chamber, and can it tell a joint from the part around it? | Simulation, then in-chamber calibration |
| Is the Welch–Costas speaking order better than one source at a time? | Simulation |
| Can both contrast maps be recovered for a foam or gel sample at one tone? | In-chamber calibration |
| How accurate is a scan against a known reference object? | In-chamber calibration |
| Does a least-reflection drive exist for twelve sources and five tones, and how much energy reaches the joint? | Simulation |
| Which joints can be broken cold, and with what pulse? | Process simulation |
| Which known part and material make the first recovery test? | Engineering management |
| Does mass in the part plus mass in the stores stay constant through add and remove? | Simulation, then the weigh cells |
| How does stock cross the mid-plane without spoiling the sound reflection? | Simulation |
| How many separate stores does the first closed loop need? | Process simulation |

Read next: [Manufacturing](manufacturing.html), [Desktop Replicator](desktop-replicator.html), [Architecture](architecture.html) and [The long-term machine](ultimate-replicator.html).
