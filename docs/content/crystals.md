# Crystals: patterns that steer sound and light

<div class="lead">A crystal, in this handbook, is any pattern that repeats. A repeating pattern can block a wave, trap it or push it out. This page says which patterns the Replicator will try first, which it will not, and what has to be true before it tries the rest.</div>

<div class="callout note"><strong>Status.</strong> Every number here comes from a calculation or from other groups' papers. Nothing on this page has been measured by this project, and no part has been bought. The first crystal to try (RG-1, below) still has to pass a simulation before anyone builds it (Open).</div>

## What a crystal does to a wave

Waves bounce off every row of a pattern. If the rows sit about half a wavelength apart, the bounces from all the rows line up and add together. That tone cannot get through. The blocked band of tones is called a band gap ([Martínez-Sala et al., *Nature* 1995](https://doi.org/10.1038/378241a0), `R161`; [Kushwaha et al., *Phys. Rev. Lett.* 1993](https://doi.org/10.1103/physrevlett.71.2022), `R160`, for sound; [Yablonovitch, *Phys. Rev. Lett.* 1987](https://doi.org/10.1103/physrevlett.58.2059), `R158`, and [John, 1987](https://doi.org/10.1103/physrevlett.58.2486), `R159`, for light) (Documented).

Smaller rows than that do something else. The wave no longer sees single rows, only an average, like a smooth lens. A third trick uses tiny resonators that are much smaller than the wave. Each one blocks one narrow band ([Liu et al., *Science* 2000](https://doi.org/10.1126/science.289.5485.1734), `R162`) (Documented).

## Sound, light or both

| Name | What the pattern steers | Size of one row | Where the Replicator could use it |
|---|---|---|---|
| **Phononic** crystal | Sound, or vibration in a solid | Millimetres for our tones (32 to 160 kHz) | The glass plates, the cassette seat, the chamber |
| **Photonic** crystal | Light | Fractions of a micrometre for red light | An optical filter, a light-written store, a colour sensor |
| **Phoxonic** crystal | Both at once | A few tenths of a micrometre | Only a chip made in a factory. Its sound is at gigahertz, millions of times higher than ours |

Why can one pattern not steer our sound and our light together? Because the row size follows the wavelength. Red light has a wavelength of about 0.65 µm. Sound in water at 160 kHz has one of 9.3 mm. A pattern that fits one is far too small or far too big for the other. A pattern that steers both has to sit near 0.2 to 0.35 µm, and sound with such a short wavelength vibrates at about 5 to 19 GHz (Derived). Silicon chips with light and sound in the same tiny pattern exist, working near 5 GHz with 1.5 µm light ([Eichenfield et al., *Nature* 2009](https://doi.org/10.1038/nature08524), `R188`) (Documented).

### How big the pattern must be for our sound

A half-wavelength row in water, for the five tones the machine uses (Derived):

| Tone | Sound wavelength in water | Row size that blocks it |
|---|---|---|
| 32 kHz | 46.3 mm | 23.2 mm |
| 64 kHz | 23.2 mm | 11.6 mm |
| 96 kHz | 15.4 mm | 7.7 mm |
| 128 kHz | 11.6 mm | 5.8 mm |
| 160 kHz | 9.3 mm | 4.6 mm |

One pattern cannot block all five tones: the tones span a factor of five, and one gap covers only a small part of that. The five tones are also exact multiples of one another. A plain hard wall keeps all five in step. A crystal wall whose echo timing changes unevenly with tone would put them out of step.

## One fact that shapes everything: the glass plate is too slow

The glass plate (a 1 mm wafer) sends sound into the water by bending. A bending wave in this plate travels slower than sound in water at all five tones. A wave that slow cannot send a sound wave straight into the water. Most of its energy stays in the plate. This is why driving the plate in water takes much more voltage than in air: unmatched water needs 49 to 61 V rms to hold a heavy particle, against an 18 V supply (Derived, from the S-VOL1 study).

A crystal can help here, but only one kind: a pattern that scatters the slow bending waves into directions where they do radiate.

## What we do not need a crystal for

Three ideas were checked against the numbers and dropped (all Derived):

| Idea | Result |
|---|---|
| **A crystal rim reflector** around the plate edge | Not needed. A hard aluminium ring with air behind it already bounces back at least 99.7 % of the sound for the typical chamber mode. What limits the echo is the leaks and gaps (the 12 mm transfer port, slots, a soft bond), not the ring |
| **A permeable crystal floor** that lets matter flow through the whole mid-plane | Fails. With water behind it, the echo drops badly for the sideways chamber modes (the weakest 5 % fall to 0.05 to 0.47). The sealed, air-backed cassette M1 stays |
| **Safety opals** for laser filtering | Not safe by design. A grown opal has no rated blocking strength. Laser filters are bought as rated parts |

Two more are parked, not killed. A graded-index plate that bends sound like a lens is too weak at 32 kHz (1.4 rad of phase). Soft-clamping the plate edge buys nothing, because the silicone ring already acts like a free edge in simulation (field correlation 0.9998, Simulated).

## Bench Gate 0 can tell you if the cassette leaks

The sealed cassette has air behind the plate. The first test of the empty chamber ([Bench Gate 0](status.html)) compares the second echo to the first and needs a ratio showing a reflection of at least 0.85.

The crystal study found a useful side effect. If water gets behind the plate, the reflection falls from about 0.9996 to between 0.11 and 0.43 (Derived). That is a huge change. So the same echo test is also a leak detector for the cassette, with no extra sensor. It should become a software interlock and a seal requirement in the CAD (Design decision; not yet built).

## Rung 1: the first crystal to try

The plan climbs three rungs. Rung 1 uses what the machine already is.

### RG-1: little steel dots on the back of the glass

**What.** A triangular pattern of small steel discs glued to the dry back face of each acoustic wafer, 37.4 mm apart (Derived).
- About 18 dots, each 3 mm wide and 1 mm thick, 56 mg each. Together about 1 g, 1.4 % of the wafer's mass.
- Only on the dry air side, at least 10 mm from every piezo disc, and inside the O-ring line.
- Held by removable wax, so the test can be undone. The wet face stays flat, bare glass.

**Why.** At this spacing the pattern turns the slow bending waves into waves that radiate into the water, for all five tones and from every direction. The idea is an old one from ribbed panels ([Maidanik, *J. Acoust. Soc. Am.* 1962](https://doi.org/10.1121/1.1918200), `R176`) (Documented). The dots must be light, or they would open a gap of their own and block a tone.

**Temperature.** The best pitch moves very little when the water warms. The calculated safety margin shifts by at most 0.0014 per kelvin, so it stays positive over a 10 K swing and RG-1 needs no speed-of-sound lock (Derived).

**Status: Derived pattern, gain Open.** A simulation screen comes first (task #124). It compares four plates on the same drive: bare, with RG-1, the same weight at random places (to test whether the pattern matters), and a 2 mm plate (the simple alternative).
- **Pass:** at least 1.3 times the sound pressure per volt at 32 to 96 kHz, no tone below 0.9 times, and glass stress still under 10 MPa.
- **Kill:** it fails that, or the random dots do as well. Then the repeat does not matter and the idea goes.

### PX-1: a quiet seat

**What.** Under each ball that locates a cassette, a short chain of four steel discs joined by thin necks, turned from one piece of stainless steel. Discs 16 mm wide and 6 mm tall, necks 1 mm wide.

**Why.** It holds the cassette still (about 1 µm of squash under 20 N) but blocks vibration above 16.4 kHz. Each link removes about 22 to 52 dB at the five tones (Derived). That stops a plate's hum from running through the frame into the other plate.

**Status: Derived, built only if needed.** Bench Gate 0 will measure whether sound really crosses through the structure. If the early arrival through glass (about 43 µs, against about 700 µs through air) is louder than a limit the software team sets (a suggested −40 dB against the first echo, Open), PX-1 gets built. If not, it never is.

## Rung 2: crystals of light

### K-1: a light-written crystal that stores drive patterns

A thick hologram is a stack of thin mirrors written into a crystal by two crossing laser beams. That stack is a one-dimensional photonic crystal that the machine writes itself ([Kogelnik, *Bell Syst. Tech. J.* 1969](https://doi.org/10.1002/j.1538-7305.1969.tb01198.x), `R197`). Each hologram is selected by the angle of one reference beam. Experiments have stored thousands of pages in one lithium niobate crystal ([Mok, *Opt. Lett.* 1993](https://doi.org/10.1364/OL.18.000915), `R195`; [Heanue et al., *Science* 1994](https://doi.org/10.1126/science.265.5173.749), `R100`) (Documented).

What it would store for the machine:
- One page holds one drive pattern: about 100 kbit (Derived).
- A cubic centimetre holds 500 to 1,600 usable pages (Derived, using the standard memory metric of [Mok, Burr and Psaltis, *Opt. Lett.* 1996](https://doi.org/10.1364/OL.21.000896), `R196`).
- In plain iron-doped crystal, every read partly erases the page. Heating to fix it, or two kinds of dopant, gives readout that does not erase ([Buse, Adibi and Psaltis, *Nature* 1998](https://doi.org/10.1038/31429), `R198`) (Documented).

**Status: physics Documented, as our store Open.** It does not need the liquid chamber or Bench Gate 0, so it can run alongside Rung 1. The test is a round trip: write one page, then ten, recall a real compiled drive pattern and play it in the twin. It passes if the recalled pattern holds the same trap and the measured memory metric, erase rate and retention are reported. It fails if not, and then K-1 leaves the plan. The costed build plan is a separate private document. Nothing is bought, and any purchase needs the operator's approval.

### P-1: an opal made with sound

A stack of tiny, equal balls packed in a regular lattice reflects one colour, like a natural opal. For a red stop band at 650 nm, the balls need to be about 260 to 295 nm wide (Derived). Using glass balls in a resin of similar index would hide the effect entirely, so the plan uses polystyrene balls locked in a low-index jelly.

The experiment uses sound to shake the balls into order. Others have done this with sound waves before ([Owens et al., 2016](https://doi.org/10.1039/c5sm02348c), `R179`; [He et al., 2024](https://doi.org/10.1063/5.0185692), `R180`) (Documented). Our version is a side sample on a 50.8 mm wafer, compared with a no-sound control. The honest limit: at our tones the sound force on a 260 nm ball is about as small as heat jiggle, so sound here anneals the layer. It does not place single balls (Derived).

Related routes are shear ordering ([Zhao et al., *Nat. Commun.* 2016](https://doi.org/10.1038/ncomms11661), `R181`), spinning ([Liu et al., *Nat. Commun.* 2023](https://doi.org/10.1038/s41467-023-38819-5), `R182`) and copying a bought master pattern ([Chou et al., *Science* 1996](https://doi.org/10.1126/science.272.5258.85), `R186`; [Zhao et al., 2023](https://doi.org/10.1039/d3na00001j), `R187`). A complete gap for light needs silicon ([Blanco et al., *Nature* 2000](https://doi.org/10.1038/35013024), `R183`), so that is a lab benchmark, not a plan.

**To start P-1** all four must hold: the liquid-cure path is cleared as laser Class 1, liquid-mode sound focusing is measured at the bench, a supplier gives balls of tight enough size, and a colour reader (photodiode and light source) exists.

## Rung 3: both at once, from a factory

### X-1: bought chips for the long-term machine

A chip with light and GHz sound in one pattern can be bought, not made here. Silicon and lithium niobate versions exist ([Safavi-Naeini et al., 2014](https://doi.org/10.1103/physrevlett.112.153603), `R190`; [Ren et al., *Nat. Commun.* 2020](https://doi.org/10.1038/s41467-020-17182-9), `R191`; [Jiang et al., *Optica* 2019](https://doi.org/10.1364/optica.6.000845), `R192`; [Burger et al., 2025](https://doi.org/10.1063/5.0246075), `R193`) (Documented). The idea is a boundary tile of the long-term machine that reads elastic motion at gigahertz or converts microwave to light.

All three must be true first:
- A long-term chamber design needs sensing above about 10 MHz per tile (or light read-out of elastic motion).
- Fibre-coupled optics and radio testing exist in-house.
- Rung 2 light measurement works.

Until then, no phoxonic work touches the Desktop Replicator.

## Parked, with reasons

| Idea | Why it waits |
|---|---|
| Graded-index sound lens ([Lin et al., 2009](https://doi.org/10.1103/physrevb.79.094302), `R165`; printed lens, [Tong and Ren, 2023](https://doi.org/10.1063/5.0145179), `R166`) | Too weak at 32 kHz; shown only in open water |
| Topological sound guides ([He et al.](https://doi.org/10.1038/nphys3867), `R171`; [Lu et al.](https://doi.org/10.1038/nphys3999), `R172`) | No routing need until the long-term apertures |
| Printed sound holograms and brick plates ([Brown et al.](https://doi.org/10.1063/1.5004040), `R168`; [Memoli et al.](https://doi.org/10.1038/ncomms14608), `R169`) | The simulated search for fixed ring-shaped relief plates found none that beat the bare wafer (task #100). Needs a non-round plate and a chamber-aware design |
| A solid block that rings like a drum, with time-reversed drive | Replaces the canon plate. Revisit if the number of drive channels becomes the blocker |
| Laser-written 3D crystals (holographic lithography) | Needs a high-power open laser, which breaks the Class 1 rule |

## Open questions

| Question | How it will be answered |
|---|---|
| Does RG-1 raise the sound pressure per volt, and does the repeat beat random dots? | Simulation screen (#124), then the bench |
| Does structure-borne crosstalk exceed the PX-1 trigger? | Bench Gate 0 |
| Is a flooded cassette really visible in the echo ratio? | Bench Gate 0, with a deliberate flood test on a spare cassette |
| Can a recalled hologram page hold the same trap as the stored pattern? | K-1 round-trip test |
| Does sound improve opal order against a no-sound control? | P-1 coupon |

## Where to go next

- [Acoustics](acoustics.html#bending-waves-in-a-plate): why plates, and what sound can and cannot do in the chamber.
- [Optics](optics.html): the laser ring, light locking and the size ladder for optical traps.
- [Materials and modes](materials.html): quartz, periodic tables and the fabrication route.
- [Proven in the lab](evidence.html): the outside papers for the pieces above.
- [Subsystems and interfaces](subsystems.html#s03-mid-plane-interface): the sealed cassette whose seal the echo test checks.
