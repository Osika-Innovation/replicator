# Electromagnetic control

This chapter covers electric and magnetic fields used to act on material: coils, induction and pulsed fields. Its message has two parts. Large coils acting across the chamber do not work, and the project's own models show why. A small pulsed ring coil at a crucible is a different case and remains open. The [Desktop Replicator](desktop-replicator.html) contains no electromagnetic process module.

Light is treated in [Optics](optics.html). The piezo discs that drive the plates are electrical parts, but they belong to [Acoustics](acoustics.html).

## The physics that matters

A coil can act on matter in three ways.

- **Force on a magnetic or magnetised body.** A body with magnetic moment m feels a force ∇(m·B) and a torque m × B. The force needs a field gradient, not just a field.
- **Force and heat in a conductor.** A changing field induces a current density J in a conductor. The current heats it and, with the field, produces the force density J × B. This is how induction heating and electromagnetic levitation of molten metal work.
- **Induced electric field.** A changing magnetic flux Φ produces an electric field around it (Faraday's law):

      ∮ E · dl = −dΦ/dt

Two geometric facts decide what is feasible.

**Reach.** Below about 100 kHz the wavelength is kilometres, so a coil's field is quasi-static. It cannot form detail finer than its distance from the work, however many circuits it has. A quasi-static coil acts usefully only on matter that fills or links its flux path within about one coil radius (Derived, with simulated examples below).

**Linking.** A toroidal winding keeps its magnetic field inside the ring. Outside the ring the magnetic field is zero and the induced electric field is curl-free. Such a field drives a sustained current only around a closed conducting path that passes through the hole of the ring. An isolated object only polarises: its charges shift until the field inside it is cancelled.

## What does not work: large coils across the chamber

An earlier design, now retired, carried pairs of large contrawound copper coils (about 290 mm across, 44 + 44 turns) roughly 300 mm from the work. Driven with equal currents a pair acts as a two-turn ring; driven with opposite currents it acts as an 88-turn toroid whose field stays inside the winding. Two project studies in November 2026 modelled what these coils, and frame coils around the chamber, could do to millimetre-scale payloads. All results below are Simulated or Derived, in reduced models, at frequencies from zero to 100 kHz.

| Task | Result |
|---|---|
| Hold a Ø1 mm steel ball with the large coil pairs | Force is 8.5 × 10⁻⁵ of the ball's weight |
| Levitate a stone-like, non-magnetic grain | Short by seven to nine orders of magnitude |
| Position a steel ball with frame coils of 2 to 8 circuits | Short by a factor of about 1,000 |
| Bring two steel balls into contact from outside | Not possible: they repel with 26 weights against 0.28 weights of command |
| Melt a Ø0.76 mm solder ball by induction at a distance | 0.6 to 5 % efficient, and the field lifts the ball as it melts |
| Weaken a chemical bond with a static field | Magnetic energy per spin is about 10⁻⁸ eV; a silicon–oxygen bond is 4.7 eV |

Three further results explain the table.

- **Coupling depends on distance.** A pin inside a solenoid absorbs 91 % of the power. A ball 1.3 mm from a flat coil absorbs 1 %. At 300 mm no change of winding helps.
- **The toroid mode reaches only matter that links the winding.** With opposite currents, leakage outside the winding is at most one part in a thousand. Material in the work volume does not link the winding and feels nothing.
- **The plate in front blocked most of the rest.** In the retired design an aluminium face plate passed only 12 to 18 % of the ring-mode field above 1 kHz.

**What this rules out.** Levitating, placing, heating or chemically altering millimetre-scale material with coils that sit outside the chamber. Non-conductive, non-magnetic feedstock such as polymer beads offers no handle in any case. The large coils are therefore omitted from the prototype.

**What it does not rule out.** A coil within about one radius of its target, or an induced electric field acting on matter that links a small ring. The studies above did not model either.

## What remains open: a small pulsed ring coil at a crucible

The candidate is a compact toroidal coil, with an inner diameter of {{c:dissolve_and_toroidal.compact_toroid_collar_id_mm_range|range}} mm, placed around the throat of a single crucible. It is Derived in principle and Open in the chamber. It is not in the CAD model and has not been simulated.

**Principle.** The winding keeps the magnetic field inside the ring, so nearby electronics and laser diodes see almost none of it. When the current changes, the flux in the ring changes and an electric field appears along the axis through the hole. In terms of the vector potential A this is E = −∂A/∂t. The coil is a transformer whose secondary is whatever closed conducting path threads the ring.

**Worked number.** By analogy with the magnetic field at the centre of a current loop, the electric field at the centre of a flux ring of mean radius R is

    E = (dΦ/dt) / (2R)

Take illustrative values, which are not design values: a core cross-section of 1 cm², a flux density swing of 0.3 T in 1 µs and R = 10 mm. Then dΦ/dt is 30 V, which is the voltage around any single loop through the ring, and the axial field at the centre is about 1.5 kV/m. Air at atmospheric pressure breaks down near 3 MV/m, some two thousand times higher (Derived).

**Candidate uses.** Both are for recovering material, as described in [Matter loop](matter-loop.html).

- *Electroplastic softening.* Passing a pulsed current through a metal can lower the stress at which it flows, with less heating than melting. The programme's working figure is {{c:dissolve_and_toroidal.electroplastic_energy_reduction_vs_melt_x|range}} times less energy than melting. No primary source for that figure is registered yet, and separating a true current effect from ordinary resistive heating requires a matched temperature control.
- *Plasma breakdown.* A closed loop of ionised gas through the ring can be driven like a transformer secondary and used to break residue down to elements. No primary source for inductively coupled plasma at this scale is registered yet. The worked number above shows that breakdown in open air is far from assured.

**The limit that must be respected.** The induced field does work only on matter that forms a closed conducting path through the ring. A metal ring, a wire loop or a closed plasma loop qualifies. A single joint, a grain or a droplet sitting in the throat does not: the field there is curl-free, so the object merely polarises. Softening an addressed joint with this coil is therefore not established. It would need the joint to be part of a conducting loop that links the ring, and the current would flow around the whole loop, not only through the joint.

**Anapole.** A related idea combines a toroidal current with an electric dipole of matched amplitude and phase (p = ikT, with k the wavenumber and T the toroidal dipole moment). Their radiated fields cancel far away, so energy stays stored near the source instead of radiating. The principle is established electrodynamics. Its use here is Open, it is not modelled, and no primary source is registered yet.

## Toroidal and pulsed fields

Four different things share the word "toroidal" or "vortex". They must not be mixed.

| Name | What it is | Status here |
|---|---|---|
| Large toroidal coil pair | Contrawound winding on a hollow former, far from the work | Ruled out as an actuator (Simulated) |
| Small pulsed ring coil | Compact toroid at a crucible throat, acting through the induced electric field | Derived in principle, Open in the chamber |
| Propagating toroidal pulse | A short free-space electromagnetic pulse with ring-shaped field lines | Documented in optics and microwaves; see [Optics](optics.html#toroidal-optical-pulses) |
| Rotating field pattern | Phased coils that stir or turn a conductive melt | Long-term only; no model yet |

## In the Desktop Replicator

The prototype has no coils, magnets or induction stage acting on the work. The piezo discs are driven directly by wire. Three electromagnetic items exist only as options:

- **Spiral conductor on the glass.** A CAD placeholder, off by default, described in [Optics](optics.html#toroidal-optical-pulses).
- **Small pulsed ring coil.** The candidate above. It is not in the CAD model.
- **Eddy-current plate exciter (X-EM).** A flat coil and a small magnet held 0.5 mm from a metal plate shake the plate and sense its motion without contact. It was proposed for the aluminium plates of the earlier design, where the model gives 0.13 to 0.21 N per ampere at under 1 W and detects 99.4 % of axisymmetric modes up to 45 kHz (Simulated). Borosilicate glass does not conduct, so it does not apply to the active wafers. It is an optional diagnostic for conductive plates only.

## Long-term direction

Electromagnetic fields earn a place once the feedstock gives them something to hold.

- **Conductive melts.** Induction can levitate, shape and heat a molten metal drop without a container, as the European Space Agency's [electromagnetic levitator](https://www.esa.int/Science_Exploration/Human_and_Robotic_Exploration/International_Space_Station/Material_Science_Laboratory_Electromagnetic_Levitator_MSL-EML) does in orbit (Documented). The coil surrounds the drop, consistent with the reach rule above.
- **Magnetic inclusions.** A uniform field can orient magnetic or anisotropic particles while sound positions them and light cures the matrix. See [Manufacturing](manufacturing.html).
- **Sound generation.** Launching sound in a plate directly by eddy currents is rejected as the main drive: it is tens of decibels less efficient than a piezo element, and the loss becomes heat next to the chamber.

## Unverified claims

Several patents and replication accounts assert lift, softening or other effects from vortex coils and high-voltage toroids. They are recorded in the [Research library](research.html) as Claims. They are not design inputs. Where a claimed geometry could be checked against standard electromagnetism, the model showed ordinary behaviour and no anomalous force.

## Open questions

| Question | Who answers it |
|---|---|
| What axial field, stray field and pulse energy does a ring coil of this size deliver? | Electrodynamic model, which does not exist yet |
| Is there a recoverable part or residue that forms a closed conducting path through the ring? | Matter-loop design |
| Does pulsed current soften a metal joint beyond what its heating explains? | Literature search, then a temperature-controlled bench test |
| Can a plasma loop be struck at the crucible, and at what pressure? | Literature search, then model |
| Do the levitation shortfalls of 10⁷ and 9 × 10⁸ quoted by the two studies refer to the same case? | Simulation |

Related reading: [Architecture](architecture.html), [Optics](optics.html), [Manufacturing](manufacturing.html) and [Research library](research.html).
