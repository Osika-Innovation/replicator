---
# ignored: catalog owns metadata
---
<div class="eyebrow">EVIDENCE MAP / RESULTS FROM OUTSIDE LABORATORIES</div>

# Proven in the lab

<div class="callout">
The Replicator rests on eight physical tricks. Other laboratories have shown each one <strong>separately</strong>, in peer-reviewed papers. This project has not yet shown them working together, and nothing on this page is a measurement by this project.
</div>

Each row gives one outside result, its paper and what is still missing. Ids such as `R014` point into the [source catalogue](../sources.json). Every result is Documented ([evidence labels](glossary.html)). † means only the title and catalogue record were checked; the methods are still to be read.

## 1. Shaping sound in three dimensions and holding heavy things with it

Needed to hold, move and join material without touch.

| Shown | By | What they did | Meaning and limits |
|---|---|---|---|
| One flat array can now levitate much farther | **Koroyasu, Drinkwater, Fushimi et al., [*Phys. Rev. Lett.* 137, 094001 (2026)](https://doi.org/10.1103/pfkh-4x7j)** (`R110`) | Used the strong core of a Bessel beam (a narrow sound beam that does not spread) from one 16×16 array. Reach grew from 67 mm to 397 mm. It held several particles and odd shapes, past obstacles. | Newest single-sided levitation. Open beam, light foam beads at 40 kHz; not a closed chamber. |
| Charge can stop trapped particles clumping | **Shi et al., [*PNAS* 122 (2025)](https://doi.org/10.1073/pnas.2516865122)** (`R111`) | Controlled electric charge stopped "acoustic collapse", where many trapped particles pull into a clump. Spacing could be switched live. | Conflicts with the project's charge policy; see the note below the table. |
| Sound can take almost any 3D shape | **Melde et al., [*Nature* 537, 518–522 (2016)](https://doi.org/10.1038/nature19755)** (`R014`) | Printed plates bent sound into chosen 2D and 3D patterns, wavelength-sharp, and floated water droplets. | Their plates are fixed. The Desktop Replicator changes the pattern live, with several tones on [piezo discs](acoustics.html). |
| Small objects can float, move and turn in air | **Marzo et al., [*Nat. Commun.* 6, 8661 (2015)](https://doi.org/10.1038/ncomms9661)** (`R021`); **Foresti et al., [*PNAS* 110 (2013)](https://doi.org/10.1073/pnas.1301860110)** (`R107`); [*Sci. Adv.* (2023)](https://doi.org/10.1126/sciadv.adf6182) (`P007`) | Compact speaker arrays held, turned, carried and quickly assembled objects in air. | Contact-free building works. Live sensing and a machine-independent object description (a [holographic equation](compute-control.html)) are Open. |
| Many particles, each moved separately | **Marzo & Drinkwater, [*PNAS* (2019)](https://doi.org/10.1073/pnas.1813047115)** (`H003`) † | Timed speaker arrays held several particles and moved each on its own. | Precedent for several traps at once. Dense open arrays in free air, not this closed chamber with few sources. |
| Cheap low-voltage parts suffice; sound holds dense metal | **TinyLev (Marzo, Barnes & Drinkwater), [*Rev. Sci. Instrum.* 88, 085105 (2017)](https://doi.org/10.1063/1.4989995)** (`R022`); **Xie et al., [*Phys. Rev. Lett.* 89, 104304 (2002)](https://doi.org/10.1103/PhysRevLett.89.104304)** (`P025`) | TinyLev held objects above 2.2 g/cm³ with stock speakers at about 20 V and 10 W. Xie floated solid iridium (22.6 g/cm³) and liquid mercury. | Low-voltage piezo drive works. The Desktop Replicator stays with a foam bead (`{{c:haptic_pzt.first_particle}}`) to keep glass bending stress under {{c:desktop_geometry.plate_bending_stress_limit_mpa}} MPa. |
| Ultrasound can harden material deep inside, even in a living body | **Davoodi et al., [*Science* (2025)](https://doi.org/10.1126/science.adt0293)** (`R112`); **Kuang et al., [*Science* 382 (2023)](https://doi.org/10.1126/science.adi1563)** (`R090`), with a how-to protocol, [*Nat. Protoc.* (2025)](https://doi.org/10.1038/s41596-025-01258-1) (`R113`); **Habibi et al., [*Nat. Commun.* 13, 1800 (2022)](https://doi.org/10.1038/s41467-022-29395-1)** (`R091`) | Davoodi printed inside live tissue, guided by ultrasound images. Kuang and Habibi hardened inks and resins behind centimetre-thick barriers. The protocol is a recipe. | Joining needs no nozzle or line of sight. Special inks and megahertz ultrasound. Joining beads in air in this machine is Open. |
| Light can print a 3D object in under a second | **Wang, Dai et al., [*Nature* (2026)](https://doi.org/10.1038/s41586-026-10114-5)** (`R083`) | A rotating light pattern printed millimetre parts in 0.6 s, with 19 µm detail across 1 cm of depth, also inside a liquid channel. | Long-term route to fine detail. It hardens liquid resin; it does not assemble beads in air. |

**Charge tension (Open).** Shi et al. use controlled charge to keep many particles apart. The project's current policy (INS-31) drains charge to 0.2 pC or less, as a hazard. The two views conflict. This is flagged for the simulation team. It is not a decision.

## 2. Focusing sound with a few discs on a plain glass plate, and listening with the same discs

Needed so an undrilled glass plate with {{c:desktop_geometry.ports_per_plate}} piezo discs can replace a dense grid of speakers.

| Shown | By | What they did | Meaning and limits |
|---|---|---|---|
| Measured echoes can steer a moving object | **Orazbayev, Rotter et al., [*Nat. Phys.* (2024)](https://doi.org/10.1038/s41567-024-02538-5)** (`R118`); **Zhang, Delaporte & Ma, [*npj Acoust.* (2025)](https://doi.org/10.1038/s44384-025-00020-x)** (`R119`) | Orazbayev used a measured table of how every port hears every other to move and turn an object in a messy space (microwaves). Zhang measured such tables for sound in flat cavities. | Newest form of the Prada idea below. Airborne sound in this chamber is Open. |
| One disc can focus sound to a point | **Draeger & Fink, [*Phys. Rev. Lett.* 79, 407 (1997)](https://doi.org/10.1103/PhysRevLett.79.407)** (`R092`) | **One** disc on a silicon wafer's edge recorded a pulse's echoes and replayed them reversed. The vibration focused to the smallest spot the wavelength allows. | Echoes give few discs the reach of many. They used short pulses. Simulated: steady holding still needs several tones and discs to avoid unwanted traps. |
| A wave played backwards returns to its source | **Fink, [*IEEE Trans. Ultrason. Ferroelectr. Freq. Control* (1992)](https://doi.org/10.1109/58.156174)** (`H006`) † | Set out the principles of time-reversal focusing for ultrasound. | Theory for the row above. Assumes loss-free material and many-element arrays, not this chamber's losses and few discs. |
| Time reversal can focus far below the wavelength | **Lerosey, de Rosny, Tourin & Fink, [*Science* (2007)](https://doi.org/10.1126/science.1134824)** (`H008`) † | Did so with small scatterers beside the source. | Precedent only. Microwaves, with scatterers next to the antennas; not tested in this chamber. |
| Edge measurements can find and focus inside | **Williams & Maynard, [*Phys. Rev. Lett.* 45, 554 (1980)](https://doi.org/10.1103/PhysRevLett.45.554)** (`R108`); **Prada, Fink et al., [*J. Acoust. Soc. Am.* 99, 2067 (1996)](https://doi.org/10.1121/1.415393)** (`R104`) | Williams pictured a 3D sound source from a surrounding surface. Prada measured how every speaker hears every other, then focused on one object at a time. | Well-tested wave physics. The project's ideas beyond it are Open until bench-tested. |
| One sensor can take a 3D picture | **Kruizinga et al., [*Sci. Adv.* 3 (2017)](https://doi.org/10.1126/sciadv.1701423)** (`P026`) | An uneven plastic mask scrambles sound in a known way. A computer unscrambles one sensor's signal into a 3D picture. | The idea behind the lopsided rear baffle and few-disc imaging. That imaging is Open. |
| Separate small scatterers located far below the wavelength | **Errico, Tanter et al., [*Nature* (2015)](https://doi.org/10.1038/nature16066)** (`H009`) † | Located sparse microbubbles in ultrasound images to picture blood vessels. | Precedent for locating isolated objects. Says nothing about how finely a trap can place matter. |
| Calibration with no extra probe | **DiMattia & Wiener, [*J. Acoust. Soc. Am.* 18, 341 (1946)](https://doi.org/10.1121/1.1916371)** (`R105`) | Sound travels the same from A to B as B to A. Three reference laboratories calibrated devices this way. | The planned self-check: if the two stop matching, something such as moving warm air has changed the chamber. Open. |
| One disc can push and listen at once | **Dosch, Inman & Garcia, [*J. Intell. Mater. Syst. Struct.* 3, 166–185 (1992)](https://doi.org/10.1177/1045389X9200300109)** (`P024`) | Read speed and stretch from the piezo patch that drove the motion. A balancing circuit separated the signals. | Precedent for [self-sensing](glossary.html) discs, read through the {{c:haptic_pzt.adc_fallback_mpn}} converter. |
| Sound can steer light on a chip | **Liu et al., [*Optics Letters* 51(19), 5397–5400 (2026)](https://doi.org/10.1364/ol.608786)** (`R086`) | Sound-driven light switches on a thin film of lithium niobate, a crystal. Measured drive figure: 0.93 V·cm. | Long-term lead. Changes nothing in today's {{c:haptic_pzt.bridge_rail_v}} V piezo drive. |
| Gigahertz sound can be guided along a chip | **Jiang et al., [*Phys. Rev. Applied* (2026)](https://doi.org/10.1103/3gpm-mkyh)** (`R087`) *(journal landing summary)* | The journal summary reports a patterned chip carrying very high-pitched sound along a protected edge path. | Long-term lead. Only the summary was read; the methods are paywalled. Separate from the chamber's 32 to 160 kHz airborne sound. |

## 3. Seeing sound with laser light

Needed so a [laser ring](glossary.html) of {{c:mosquito_smi.total_ommatidia}} lasers can read the sound field and object outlines through the glass wall, with no microphone or camera in the work volume.

| Shown | By | What they did | Meaning and limits |
|---|---|---|---|
| Calibrated laser sound readings | **Chanu-Rigaldies et al., [*Sensors* 24, 1777 (2024)](https://doi.org/10.3390/s24061777)** (`R120`) | A self-mixing laser measured sound pressure in a tube, checked against a vibrometer. | Readings can be quantitative. A tube, not a 3D map. |
| A laser diode can picture sound in air | **Bertling et al., [*Optics Express* 22, 30346–30356 (2014)](https://doi.org/10.1364/OE.22.030346)** (`P030`) | Mapped ultrasonic standing waves with a laser diode that is its own detector ([self-mixing](glossary.html)). Nothing sat in the field. | The principle of [LightRead](optics.html). Equations: **Giuliani et al. ([`P031`](https://doi.org/10.1088/1464-4258/4/6/371))**. |
| Many laser lines give a 3D sound map | **Torras-Rosell, Barrera-Figueroa & Jacobsen, [*J. Acoust. Soc. Am.* 131, 3786 (2012)](https://doi.org/10.1121/1.3695394)** (`R093`) | Each beam measures total sound along its path. Swept beams gave the pressure at each point, as in a medical scanner. | They used many beam positions. Whether {{c:mosquito_smi.total_ommatidia}} fixed beams plus piezo echoes are enough is Open; tested only in simulation. |

## 4. Soaking up wave energy completely, to take things apart

Needed for [REMOVE](matter-loop.html): draining energy from one spot so joined material can be loosened and carried away. [Coherent perfect absorption](glossary.html) sends in waves shaped so that none bounce back.

| Shown | By | What they did | Meaning and limits |
|---|---|---|---|
| Sound can be fully absorbed at an exceptional point | **Xia et al., [*Phys. Rev. Lett.* (2025)](https://doi.org/10.1103/slhy-f76q)** (`R121`) | Absorbed airborne sound fully at an exceptional point, where two modes merge. | Newest sound result of this kind. Narrow band, in a duct. |
| Absorption works in a time-changing medium | **Galiffi et al., [*Nat. Photonics* (2026)](https://doi.org/10.1038/s41566-025-01833-8)** (`R122`) | Absorbed and amplified waves in a medium that changes in time. | Light, long-term. Links to time-switched boundaries (section 5). |
| In theory, a wave pattern can be wholly absorbed | **Chong, Ge, Cao & Stone, [*Phys. Rev. Lett.* 105, 053901 (2010)](https://doi.org/10.1103/PhysRevLett.105.053901)** (`H011`) † | Worked out the theory of the coherent perfect absorber, a laser run backwards. | Theory behind Wan's experiment below. Written for optical cavities; not tested with sound in this chamber. |
| Waves can vanish into an absorber | **Wan, Chong, Ge, Noh, Stone & Cao, [*Science* 331, 889–892 (2011)](https://doi.org/10.1126/science.1200735)** (`R069`); **Meng et al., [*Sci. Rep.* (2017)](https://doi.org/10.1038/srep43574)** (`R106`) | Wan timed two light beams so all the light was absorbed. Meng did the same with sound in an air duct, across many pitches. | The basic proof, in light and airborne sound, of the rule that sets the removal drive. |
| It also works in a messy, echoing chamber | **Pichler, Kühmayer, Rotter et al., [*Nature* 567, 351–355 (2019)](https://doi.org/10.1038/s41586-019-0971-3)** (`R094`) | Measured how a cluttered chamber scatters waves, then sent in the one pattern that does not come back. About 99.8 % was absorbed. | Works in strongly echoing spaces like this chamber. How fast airborne sound can heat or loosen a joint is Open. |
| It absorbs complicated, changing patterns | **Slobodkin, Katz et al., [*Science* 377, 995–998 (2022)](https://doi.org/10.1126/science.abq8103)** (`R095`) | An optical cavity absorbed thousands of light patterns at once, including changing ones. | Long-term precedent, in light, for a re-aimable energy sink. Not in the current hardware. |

## 5. Doughnut-shaped pulses, hidden resonances and surfaces that light can rewrite

Needed to tell materials apart without touching them and, long term, for boundary plates with about 10⁵ light-switched elements.

| Shown | By | What they did | Meaning and limits |
|---|---|---|---|
| One antenna can find position finer than the wavelength | **Wang, Shen et al., [*Commun. Phys.* (2024)](https://doi.org/10.1038/s42005-024-01850-z)** (`P016`; register `R047`) | Used [toroidal pulses](glossary.html) (doughnut-shaped) from one microwave antenna to locate a target more finely than the wavelength. | Newest use of doughnut pulses as a measuring tool; backs material identification. Microwaves, not this chamber. |
| Doughnut-shaped pulses can be made | **Zdagkas, Zheludev et al., [*Nat. Photonics* 16, 523–528 (2022)](https://doi.org/10.1038/s41566-022-01028-5)** (`P015`) | Made short toroidal pulses of light and terahertz waves. | Supports identifying materials with wide-band doughnut pulses, and an optional 12-arm spiral launcher. No strong launcher is fitted to the Desktop Replicator. |
| A doughnut pulse can carry a controllable twist | **Shi, Wang et al., [*Commun. Phys.* (2026)](https://doi.org/10.1038/s42005-026-02699-0)** (`H026`) † | Launched such single-cycle microwave pulses from one horn and a spiral grating. | Launcher precedent. Microwaves in free space; not tested in this chamber. |
| Particles can hold energy without radiating | **Miroshnichenko, Kuznetsov, Kivshar et al., [*Nat. Commun.* 6, 8069 (2015)](https://doi.org/10.1038/ncomms9069)** (`R071`) | In silicon nanoparticles two internal currents cancel when seen from afar, so one colour of light is barely scattered: an anapole. | Precedent for the material fingerprints in the [periodic table](periodic-table.html). Identifying a floating material with sound, light and radio together is Simulated and Open. |
| Surfaces can be light-switched and bulk-printed | **Kuznetsov et al., [*Nat. Nanotechnol.* (2026)](https://doi.org/10.1038/s41565-026-02128-x)** (`P017`); **Direct TiO₂ metasurface printing, [*Nat. Protoc.* (2026)](https://doi.org/10.1038/s41596-026-01407-0)** (`R013`) | Kuznetsov showed a [metasurface](glossary.html) whose pixels are set by light. The protocol stamps titanium dioxide metasurfaces across whole wafers. | Precedents for the planned titanium dioxide light-spreading strips on the laser ring, and for long-term boundaries of 10⁵ light-switched pixels. |
| A surface pattern can set an antenna's beam | **Xu, Alù et al., [*Nat. Commun.* (2023)](https://doi.org/10.1038/s41467-023-39818-2)** (`H033`) † | Built leaky-wave metasurface antennas that work this way. | Precedent for [printed radiating surfaces](optics.html). Microwave and millimetre-wave only; not tested in this chamber. |
| Light circuits erased and redrawn in about 100 ms | **Ropač (Humar Lab), [*Adv. Photonics* (2026)](https://doi.org/10.1117/1.AP.9.1.016006)** (`R084`) | An infrared laser draws light guides, lenses, splitters, gratings and logic gates in a liquid-crystal cell, with no cleanroom. | The closest published result to a rewritable optical boundary plate. Long-term design only. |
| Several holograms on one surface; plasma frequency shifting | **Wang, Huang et al., [*Adv. Photonics* (2026)](https://doi.org/10.1117/1.ap.8.5.056006)** (`R085`); **Huang, Asadchy et al., [*Sci. Adv.* (2026)](https://doi.org/10.1126/sciadv.aed2916)** (`R088`) | Wang's three-layer surface shows different holograms by the light's direction, twist and colour. Huang shifted terahertz frequency up or down by switching a plasma on suddenly. | Real in the laboratory. Neither is in the current hardware. |

## 6. Computing with waves instead of chips

Needed to work out which field to play. The plan today is a small network ([Cadence](glossary.html), under {{c:cadence_brain.cadence_sparse_max_kb}} kB) on a microcontroller. The long-term aim is optical hardware that uses almost no electricity.

| Shown | By | What they did | Meaning and limits |
|---|---|---|---|
| How to train a physical machine, in one review | **Momeni et al., [*Nature* (2025)](https://doi.org/10.1038/s41586-025-09384-2)** (`R128`) | Reviewed ways to train real hardware (light, vibrating parts, circuits) as a neural network. | The map for this whole section. A review, not an experiment. |
| A light chip can learn fully on its own | **Ashtiani et al., [*Nature* (2026)](https://doi.org/10.1038/s41586-026-10262-8)** (`R129`); **Bandyopadhyay et al., [*Nat. Photonics* (2024)](https://doi.org/10.1038/s41566-024-01567-z)** (`R130`) | Ashtiani trained a light network on one chip, learning step included. Bandyopadhyay trained with forward passes only. | Newest in-place light learning, building on Pai below. Chips, not sound. |
| Vibrating parts can be trained in place | **Li & Mao, [*Nat. Commun.* (2024)](https://doi.org/10.1038/s41467-024-54849-z)** (`R131`) | Trained all-mechanical networks by learning inside the hardware. | Newest vibrating-part result. Audio frequency, not an ultrasonic plate. |
| Phase-change layers can be tuned on a standard chip line | **Chen et al., [*npj Nanophotonics* (2024)](https://doi.org/10.1038/s44310-024-00009-6)** (`R134`) | Chen put Sb₂S₃ on a 300 mm chip line with multi-level tuning. | Makes the Delaney material (below) manufacturable. Long-term only. |
| Fixed hardware as a whole network (unreviewed) | **Wright et al., [arXiv:2604.27911](https://arxiv.org/abs/2604.27911) (2026)** (`R137`) | A preprint proposing very large neural networks built directly into physical hardware. | Horizon reading. Not peer-reviewed. |
| A plate or crystal can be trained like a neural network | **Wright, McMahon et al., [*Nature* 601, 549–555 (2022)](https://doi.org/10.1038/s41586-021-04223-6)** (`R096`) | Trained a shaking titanium plate, an optical crystal and analog circuits as neural-network layers. | Cadence's kind of calculation can run in vibrating metal, glass or light. Running Cadence itself that way is Open. |
| Light sent backwards can do the learning step | **Pai, Miller et al., [*Science* 380, 398–404 (2023)](https://doi.org/10.1126/science.ade8450)** (`R097`) | A silicon light chip sent the error signal backwards through the same paths, and so measured for itself how to improve. | Supports Cadence's design rule: waves travel the same both ways, so hardware can work out its own corrections. |
| A circuit can learn with no processor | **Dillavou, Stern, Liu & Durian, [*PNAS* 121, e2319718121 (2024)](https://doi.org/10.1073/pnas.2319718121)** (`R098`) | Two matched analog circuits learned a task by settling and comparing two states: [equilibrium propagation](glossary.html) (Scellier & Bengio [`P032`](https://doi.org/10.3389/fncom.2017.00024)). | Works in analog hardware. An optical version is not in the current hardware. |
| A material can hold an optical setting almost loss-free | **Delaney, Muskens et al., [*Adv. Funct. Mater.* 30, 2002447 (2020)](https://doi.org/10.1002/adfm.202002447)** (`R099`) | Sb₂S₃ and Sb₂Se₃ switch between two solid states and stay without power. Switching changes how strongly they bend light by 0.6 to 0.8. They absorb almost no near-infrared light. | Planned to hold network weights in the long-term optical compute card. Not in the current hardware. |

## 7. Storing data as holograms inside a crystal

Needed to keep object descriptions ([holographic equations](glossary.html)) in a crystal of about 1 cm³. A 250 g iron reference object needs about 6.35×10¹¹ bits (Derived). Storing every atom would need about 10²⁶ bits: not possible.

| Shown | By | What they did | Meaning and limits |
|---|---|---|---|
| Petabit-scale optical storage on a disc | **Zhao et al., [*Nature* 626, 772 (2024)](https://doi.org/10.1038/s41586-023-06980-y)** (`R138`) | Wrote 100 layers with 54 nm spots and 70 nm spacing on a DVD-sized disc. | Density record for volume storage. Layered disc, not a hologram crystal. |
| Lasers can write inside lithium niobate | **Zhang et al., [*Nat. Commun.* 16, 6086 (2025)](https://doi.org/10.1038/s41467-025-61317-9)** (`R139`) | Wrote 3D light-bending regions in lithium niobate. | Not hologram pages. |
| Data stored and read back inside a crystal | **Heanue, Bashaw & Hesselink, [*Science* 265, 749–752 (1994)](https://doi.org/10.1126/science.265.5173.749)** (`R100`) | Stored pages of data throughout an iron-doped lithium niobate crystal and read them back, each page at its own beam angle. | The basis for the crystal memory. Reaching the full 10¹² bits per cm³ is engineering still to do. |
| One page can carry data in several properties of light | **Chen, Tan et al., [*Optica* (2026)](https://doi.org/10.1364/OPTICA.586593)** (`H024`) † | Describes encoding and decoding data in one holographic page's brightness, phase and polarisation. | Long-term lead. Not confirmed as an experiment from the abstract. Not connected to this machine's memory. |
| Lithium niobate switches and makes terahertz waves | **Xu & Cong, [*Appl. Phys. Lett.* (2026)](https://doi.org/10.1063/5.0351575)** (`R001`); **Wagner et al., [*J. Infrared Milli. Terahz. Waves* (2026)](https://doi.org/10.1007/s00340-025-08616-7)** (`R008`) | Xu switched a terahertz resonance in a thin lithium niobate film with a light pulse. Wagner generated 488 GHz waves in a lithium niobate guide. | Supporting results for the same crystal family. Long-term design only. |

## 8. Holding thousands of single atoms with light, and joining metal without heat

The long-term design needs these to go from ready-made 10 µm bricks to a steady supply of single atoms and seams joined at room temperature. None of this is in the Desktop Replicator.

| Shown | By | What they did | Meaning and limits |
|---|---|---|---|
| One light beam can hold a particle | **Ashkin, Dziedzic, Bjorkholm & Chu, [*Optics Letters* 11, 288 (1986)](https://doi.org/10.1364/OL.11.000288)** (`H018`) † | First showed a single-beam trap holding small non-metal particles. | The start of optical tweezers. Micrometre particles in water under a microscope lens; not a force this machine relies on. |
| Light traps can hold many particles at once | **Grier, [*Nature* (2003)](https://doi.org/10.1038/nature01935)** (`H019`) † | A review of optical trapping, including holographic tweezers. | Background. Microscope-scale work; no result at this machine's scale. |
| 6,100 single atoms held in a grid of light | **Manetsch, Endres et al., [*Nature* (2025)](https://doi.org/10.1038/s41586-025-09641-4)** (`R101`) | Caesium atoms, each in its own laser spot, in an array of about 12,000 spots. They stayed for seconds. | Single-atom light traps scale to thousands. Needs ultra-high vacuum and atoms cooled to millionths of a degree above absolute zero. Does not work in room air. |
| A flat surface can make a huge atom-trap array | **Holman, Yu, Will et al., [*Nature* (2026)](https://doi.org/10.1038/s41586-025-09961-5)** (`H020`, register `R141`) † | Trapped single atoms in about 360,000 light spots made by a metasurface (count from the catalogue record). | Closest published result to the long-term optical-boundary and atom-array rungs. Vacuum only. Count not checked in the full article. |
| An atom array topped up without stopping | **Chiu, Lukin et al., [*Nature* (2025)](https://doi.org/10.1038/s41586-025-09596-6)** (`R102`) | An optical conveyor belt kept an array of over 3,000 atoms filled while running. | A steady single-atom feed is possible, under the same vacuum and cooling limits. Complements pulsed atom sources (`R082`). |
| Gold wires weld at room temperature | **Lu, Huang, Lou et al., [*Nat. Nanotechnol.* 5, 218–224 (2010)](https://doi.org/10.1038/nnano.2010.4)** (`R103`) | Gently touched single-crystal gold nanowires fused with no melting. The crystal pattern ran almost unbroken across the join. | Supports ready-made bricks joined by cold-welded seams. Shown for gold nanowires only. |
| Glass can cold-weld too | **Guo et al., *Matter* (2024)** (`R144`, [publisher page](https://www.cell.com/matter/fulltext/S2590-2385(24)00485-5), DOI not yet resolved); **Dong et al., *Mater. Today* (2024)** (`R143`, [publisher page](https://www.sciencedirect.com/science/article/pii/S1369702124002177), DOI not yet resolved) | Guo welded silica nanospheres at room temperature in seconds. Dong explains when such welds work. | Closer to the chamber glass than gold. Nanospheres only; seam strength is Open. |

## 9. Crystals that steer sound and light

Supporting results for the [crystals guide](crystals.html). These are not one of the eight tricks. They support the choice of which repeating patterns to try. † means only the title and catalogue record were checked.

| Shown | By | What they did | Meaning and limits |
|---|---|---|---|
| A repeating pattern can block sound | **Martínez-Sala et al., [*Nature* 378, 241 (1995)](https://doi.org/10.1038/378241a0)** (`R161`) †; **Kushwaha et al., [*Phys. Rev. Lett.* 71, 2022 (1993)](https://doi.org/10.1103/physrevlett.71.2022)** (`R160`) † | A sculpture of rods blocked a band of sound; the band structure of a periodic elastic composite was calculated. | Origin of the band gap for sound. Our tones need rows of 4.6 to 23 mm in water (Derived) |
| A repeating pattern can block light | **Yablonovitch, [*Phys. Rev. Lett.* 58, 2059 (1987)](https://doi.org/10.1103/physrevlett.58.2059)** (`R158`) †; **John, [*Phys. Rev. Lett.* 58, 2486 (1987)](https://doi.org/10.1103/physrevlett.58.2486)** (`R159`) † | Proposed forbidden bands for light in periodic dielectrics. | Theory. The same vocabulary of rows, contrast and gap is reused for sound |
| Tiny resonators block sound far below its wavelength | **Liu et al., [*Science* 289, 1734 (2000)](https://doi.org/10.1126/science.289.5485.1734)** (`R162`) | Built a sonic material with gaps at wavelengths much longer than its cells. | Each gap is narrow, so one such part does not serve five tones |
| Ribs on a panel let a slow bending wave radiate | **Maidanik, [*J. Acoust. Soc. Am.* (1962)](https://doi.org/10.1121/1.1918200)** (`R176`) | Showed how ribs raise the sound a panel radiates in a reverberant field. | The basis for RG-1. Our version, dots on a water-loaded glass wafer, is Derived and untested |
| Sound can order small particles into crystals | **Owens et al., [(2016)](https://doi.org/10.1039/c5sm02348c)** (`R179`); **He et al., [(2024)](https://doi.org/10.1063/5.0185692)** (`R180`) | Used sound to assemble microparticles into well-ordered layers. | Supports P-1. Sound anneals the layer; it does not place single sub-micrometre balls |
| A thick hologram is a crystal written by light | **Kogelnik, [*Bell Syst. Tech. J.* (1969)](https://doi.org/10.1002/j.1538-7305.1969.tb01198.x)** (`R197`) †; **Mok, [*Opt. Lett.* (1993)](https://doi.org/10.1364/OL.18.000915)** (`R195`) †; **Mok, Burr & Psaltis, [*Opt. Lett.* (1996)](https://doi.org/10.1364/OL.21.000896)** (`R196`) † | Gave the theory of thick gratings, stored 5,000 holograms in one lithium niobate crystal, and defined the memory metric. | Supports K-1. Drive-pattern storage as our store is Open |
| Doping lets a hologram be read without erasing it | **Buse, Adibi & Psaltis, [*Nature* (1998)](https://doi.org/10.1038/31429)** (`R198`) † | Reported non-volatile storage in doubly doped lithium niobate. | Fixes read-erasure for K-1 |
| Light and GHz sound in one chip pattern | **Eichenfield et al., [*Nature* (2009)](https://doi.org/10.1038/nature08524)** (`R188`) †; **Jiang et al., [*Optica* (2019)](https://doi.org/10.1364/optica.6.000845)** (`R192`) † | Silicon and lithium niobate optomechanical crystals. | Sound near 5 GHz with 1.5 µm light. Bought chips only; this is Rung 3 |

## Where to go next

- [Research library](research.html): every source by evidence strength. Patents and unverified leads (`P004`, `P020–P023`) are kept apart.
- [Current state](status.html): what is simulated, failing or open.
- [Crystals](crystals.html): which repeating patterns of sound and light the machine will try.
- [Desktop Replicator](desktop-replicator.html): the first machine.
