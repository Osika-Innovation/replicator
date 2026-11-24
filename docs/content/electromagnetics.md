# Electromagnetic control

This chapter covers coils, induction and pulsed fields used to act on material. Large coils acting across the chamber do not work, and the project's models show why. A small pulsed ring coil at a crucible remains open. The [Desktop Replicator](desktop-replicator.html) contains no electromagnetic process module.

Light is treated in [Optics](optics.html). The piezo discs that drive the plates belong to [Acoustics](acoustics.html).

## The physics that matters

A coil can act on matter in three ways.

- **Force on a magnet.** A magnetic or magnetised body with magnetic moment m feels a force ∇(m·B) and a torque m × B. The force needs a field that changes from place to place, not just a field.
- **Force and heat in a conductor.** A changing field makes a current of density J flow in a conductor. The current heats it and, with the field, pushes it with force density J × B. This is how induction heats and levitates molten metal.
- **Induced electric field.** A changing magnetic flux Φ makes an electric field that circles around it (Faraday's law):

      ∮ E · dl = −dΦ/dt

**Reach.** Below about 100 kHz the wavelength is kilometres. A coil's field then acts like a slowly changing magnet field, not a wave. It cannot form detail finer than its distance from the work, however many circuits it has. It acts usefully only on matter that fills or links its flux path within about one coil radius (Derived, with simulated examples below).

**Linking.** A toroidal winding, a coil wound around a ring, keeps its magnetic field inside the ring. The electric field outside has no swirl, so it drives a lasting current only around a closed conducting path that passes through the hole of the ring. An isolated object only polarises: its charges shift until the field inside it is cancelled.

## What does not work: large coils across the chamber

An earlier design, now retired, carried pairs of large copper coils wound in opposite senses (about 290 mm across, 44 + 44 turns), roughly 300 mm from the work. With equal currents a pair acts as a two-turn ring. With opposite currents it acts as an 88-turn toroid whose field stays inside the winding. Two project studies modelled what these coils, and frame coils around the chamber, could do to millimetre-scale payloads. All results are Simulated or Derived, in reduced models, from zero to 100 kHz.

| Task | Result |
|---|---|
| Hold a Ø1 mm steel ball with the large coil pairs | Force is 8.5 × 10⁻⁵ of the ball's weight |
| Levitate a stone-like, non-magnetic grain | Short by seven to nine orders of magnitude |
| Position a steel ball with frame coils of 2 to 8 circuits | Short by a factor of about 1,000 |
| Bring two steel balls into contact from outside | Not possible: they repel with 26 weights against 0.28 weights of command |
| Melt a Ø0.76 mm solder ball by induction at a distance | 0.6 to 5 % efficient, and the field lifts the ball as it melts |
| Weaken a chemical bond with a static field | Magnetic energy per spin is about 10⁻⁸ eV; a silicon–oxygen bond is 4.7 eV |

Why:

- **Coupling depends on distance.** A pin inside a solenoid absorbs 91 % of the power. A ball 1.3 mm from a flat coil absorbs 1 %. At 300 mm no change of winding helps.
- **The toroid mode reaches only matter that links the winding.** With opposite currents, leakage outside is at most one part in a thousand.
- **The plate in front blocked most of the rest.** In the retired design an aluminium face plate passed only 12 to 18 % of the ring-mode field above 1 kHz.

**Ruled out.** Levitating, placing, heating or chemically altering millimetre-scale material with coils outside the chamber. Feedstock that neither conducts nor is magnetic, such as polymer beads, offers no handle at all. The prototype therefore has no large coils.

**Not ruled out.** A coil within about one radius of its target, or an induced electric field acting on matter that links a small ring. The studies modelled neither.

## What remains open: a small pulsed ring coil at a crucible

The candidate is a compact toroidal coil with an inner diameter of {{c:dissolve_and_toroidal.compact_toroid_collar_id_mm_range|range}} mm, around the throat of one crucible. It is Derived in principle and Open in the chamber. It is not in the CAD model and not simulated.

**Principle.** The winding keeps the magnetic field inside the ring, so nearby electronics and laser diodes see almost none. When the current changes, the flux changes, and an electric field appears along the axis through the hole (E = −∂A/∂t, with A the vector potential). The coil is a transformer whose secondary winding is whatever closed conducting path threads the ring.

**Worked number.** By analogy with the magnetic field at the centre of a current loop, the electric field at the centre of a flux ring of mean radius R is

    E = (dΦ/dt) / (2R)

Take illustrative values: a core cross-section of 1 cm², a flux density swing of 0.3 T in 1 µs and R = 10 mm. Then dΦ/dt is 30 V, the voltage around any single loop through the ring. The field on the axis at the centre is about 1.5 kV/m. Air at atmospheric pressure breaks down near 3 MV/m, some two thousand times higher (Derived).

**Candidate uses.** Both are for [recovering material](matter-loop.html#recover-dissolve-material-specific-separation-and-reuse).

- *Electroplastic softening.* A pulsed current through a metal can lower the stress at which it flows. The working figure is {{c:dissolve_and_toroidal.electroplastic_energy_reduction_vs_melt_x|range}} times less energy than melting (Claim, no source registered). Telling a true current effect from plain resistive heating needs a control run at the same temperature.
- *Plasma breakdown.* A closed loop of ionised gas through the ring can be driven like a transformer secondary to break residue down to elements (Claim, no source registered). The worked number shows that breakdown in open air is far from assured.

**The limit that must be respected.** The induced field does work only on matter that forms a closed conducting path through the ring. A metal ring, a wire loop or a closed plasma loop qualifies. A single joint, grain or droplet in the throat does not: it merely polarises. Softening one chosen joint is therefore not established. The joint would have to be part of a conducting loop that links the ring, and the current would flow around the whole loop.

**Anapole.** Pair a ring-shaped (toroidal) current with a simple back-and-forth current. If their strengths and timing are matched, the waves they send out cancel far away, and energy stays stored near the source. The match is p = ikT, where p is the strength of the back-and-forth source, T that of the ring source and k = 2π/λ. The effect is Documented in light scattered by tiny particles ([Miroshnichenko et al., 2015](https://doi.org/10.1038/ncomms9069)). Its use here, for example sensing with a [toroidal pulse](optics.html#toroidal-optical-pulses), is Open and not modelled.

## Toroidal and pulsed fields

Four different things share the word "toroidal" or "vortex".

| Name | What it is | Status here |
|---|---|---|
| Large toroidal coil pair | A winding in two opposite senses on a hollow former, far from the work | Ruled out as an actuator (Simulated) |
| Small pulsed ring coil | Compact toroid at a crucible throat, acting through the induced electric field | Derived in principle, Open in the chamber |
| Propagating toroidal pulse | A short electromagnetic pulse in free space with ring-shaped field lines | Documented in optics and microwaves; see [Optics](optics.html#toroidal-optical-pulses) |
| Rotating field pattern | Coils driven one after another to stir or turn a conductive melt | Long-term only; no model yet |

## In the Desktop Replicator

The prototype has no coils, magnets or induction stage acting on the work. Three items exist only as options:

- **Spiral conductor on the glass.** A CAD placeholder, off by default. See [Optics](optics.html#toroidal-optical-pulses).
- **Small pulsed ring coil.** The candidate above, not in the CAD model.
- **Eddy-current plate exciter (X-EM).** A flat coil and a small magnet 0.5 mm from a metal plate shake the plate and sense its motion without contact. For the aluminium plates of the earlier design the model gives 0.13 to 0.21 N per ampere at under 1 W, and detects 99.4 % of the ring-symmetric vibration patterns up to 45 kHz (Simulated). Glass does not conduct, so this is an optional diagnostic for conductive plates only.

## Long-term direction

- **Conductive melts.** Induction can levitate, shape and heat a molten metal drop without a container. The European Space Agency's [electromagnetic levitator](https://www.esa.int/Science_Exploration/Human_and_Robotic_Exploration/International_Space_Station/Material_Science_Laboratory_Electromagnetic_Levitator_MSL-EML) does this in orbit (Documented). The coil surrounds the drop, as the reach rule requires. To press a detail into a melt, magnetic pressure B²/2μ₀ must beat the surface-tension pressure 2γ/r. With γ ≈ 1.8 N/m for liquid iron, that takes about 0.1 T of local field change for a feature of radius r = 1 mm and about 0.3 T for 0.1 mm (Derived). A thin stream of liquid breaks into beads by itself, so holding a stream needs active feedback.
- **Magnetic inclusions.** A uniform field can turn magnetic particles to face one way while sound positions them and light cures the material around them ([Manufacturing](manufacturing.html#a-candidate-combined-field-recipe)).
- **Heating by frequency.** Every material absorbs some frequencies more than others, so choosing the frequency chooses which material heats. A fixed printed antenna pattern also sends each frequency in a different direction, so changing the tone steers the beam with no moving parts (Claim; Open here). This needs a radiating source, such as a [printed radiating surface](optics.html#printed-radiating-surfaces). It is not the coil heating at a distance ruled out above.
- **Sound generation.** Launching sound in a plate by eddy currents is rejected as the main drive. It is tens of decibels less efficient than a piezo element, and the loss becomes heat next to the chamber. Light or radio pressure is no substitute: per watt it pushes about a million times more weakly than sound ([Acoustics](acoustics.html#why-sound-carries-the-force)).
- **Lifting stock.** Metal stock might ride a travelling magnetic wave from stacked coils, from the [store](matter-loop.html#the-stores-equation-library-vs-matter-pantry) up to the build zone (Open, not modelled).

## Unverified claims

Patents and replication accounts that assert lift or softening from vortex coils and high-voltage toroids are recorded in the [Research library](research.html) as Claims. They are not design inputs. Where a claimed geometry could be checked, the model showed ordinary electromagnetism and no anomalous force.

## Open questions

| Question | Who answers it |
|---|---|
| What axial field, stray field and pulse energy does a ring coil of this size deliver? | Electrodynamic model, which does not exist yet |
| Is there a recoverable part or residue that forms a closed conducting path through the ring? | Matter-loop design |
| Does pulsed current soften a metal joint beyond what its heating explains? | Literature search, then a temperature-controlled bench test |
| Can a plasma loop be struck at the crucible, and at what pressure? | Literature search, then model |
| Do the levitation shortfalls of 10⁷ and 9 × 10⁸ quoted by the two studies refer to the same case? | Simulation |

Related: [Architecture](architecture.html) and [Manufacturing](manufacturing.html).
