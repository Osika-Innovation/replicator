---
# ignored: catalog owns metadata
---
<div class="eyebrow">EVIDENCE MAP / THIRD-PARTY LABORATORY CORNERSTONES</div>

# Proven in the lab

<div class="callout">
What gives this programme its engineering foundation is that the core physical mechanisms — 3D acoustic holography, single-channel reverberant plate focusing, coherent wave-energy absorption, self-mixing optical sound imaging, non-radiating electromagnetic anapoles, rewriteable photonic boundaries, in-situ physical neural computation, photorefractive volume holographic memory, thousand-atom tweezer arrays, and room-temperature nanocrystalline cold welding — have <strong>all been demonstrated individually in peer-reviewed third-party laboratories</strong>.
</div>

The tables below organize our [public source catalog](../sources.json) into the **eight cornerstones of the Replicator architecture**. Every citation links directly to a DOI or institutional record reporting fabricated devices, experimental measurements, or published fabrication protocols. Where a mechanism belongs only to the long-term horizon rather than the [Desktop Replicator](desktop-replicator.html), that boundary is stated in the final column.

---

## 1. 3D Volumetric Acoustic Holography, Ultrasound Printing & Heavy-Matter Trapping

Replicator target: contactless 3D particle trapping, spatial field shaping, and subsurface field-addressed solidification inside one unified chamber.

| Cornerstone capability | Primary laboratory publication | What was achieved in the lab | Replicator scope & remaining gap |
|---|---|---|---|
| Arbitrary 3D mid-air / fluid acoustic field synthesis | **Melde et al., [*Nature* 537, 518–522 (2016)](https://doi.org/10.1038/nature19755)** (`R014`) | Fabricated transmission acoustic holograms reconstruct diffraction-limited complex 2D and 3D pressure fields and levitate water droplets in air. | Establishes arbitrary wavefield sculpting; Desktop Rev F swaps fixed lenses for dynamic multi-tone [`HAPTIC`](acoustics.html) arrays. |
| Single-sided / multi-channel mid-air levitation & rotation | **Marzo et al., [*Nat. Commun.* 6, 8661 (2015)](https://doi.org/10.1038/ncomms9661)** (`R021`); **Foresti et al., [*PNAS* 110 (2013)](https://doi.org/10.1073/pnas.1301860110)** (`R107`); [*Sci. Adv.* (2023)](https://doi.org/10.1126/sciadv.adf6182) (`P007`) | Demonstrated stable 3D mid-air trapping, rotation, planar contactless handling, and rapid hologram assembly using compact acoustic phased arrays. | Proves contactless airborne 3D assembly; Desktop adds closed-loop sensing and [`holo-eq/0.3-mm`](compute-control.html) portability. |
| Low-voltage COTS PZT levitation & dense-metal acoustic holding | **TinyLev (Marzo, Barnes & Drinkwater), [*Rev. Sci. Instrum.* 88, 085105 (2017)](https://doi.org/10.1063/1.4989995)** (`R022`); **Xie et al., [*Phys. Rev. Lett.* 89, 104304 (2002)](https://doi.org/10.1103/PhysRevLett.89.104304)** (`P025`) | Held `>2.2 g/cm³` objects at `~20 V` (`10 W`) using inexpensive COTS air transducers (`TinyLev`), and levitated solid iridium (`22.6 g/cm³`) and liquid mercury in air (`Xie`). | Proves low-voltage PZT actuation and heavy-matter radiation forces in air; Desktop Rev F stays capped on `{{c:haptic_pzt.first_particle}}` to respect `{{c:desktop_geometry.plate_bending_stress_limit_mpa}} MPa` glass bending stress. |
| Deep-penetrating volumetric ultrasound 3D printing | **Kuang et al., [*Science* 382 (2023)](https://doi.org/10.1126/science.adi1563)** (`R090`); **Habibi et al., [*Nat. Commun.* 13, 1800 (2022)](https://doi.org/10.1038/s41467-022-29395-1)** (`R091`) | Focused ultrasound selectively polymerizes formulated sono-inks and resins *inside* optically opaque volumes and behind centimeter-thick barriers. | Validates field-addressed volumetric joining without nozzles or optical line-of-sight; Desktop `M-A2` air-bead consolidation remains open for bench measurement. |
| Sub-second holographic volumetric light printing | **Wang, Dai et al., [*Nature* (2026)](https://doi.org/10.1038/s41586-026-10114-5)** (`R083`) | DISH rotating-periscope holographic synthesis achieved **`19 µm` resolution across `1 cm` depth** and printed millimetre-scale structures in **`0.6 s`**, including inside a fluid channel. | Documented volumetric holographic path for long-term mesoscale fabrication; uses resin photopolymer rather than airborne bead assembly. |

---

## 2. Sparse-Port Reverberant Wafer Focusing, Self-Sensing Piezos & Integrated Acoustic Actuation

Replicator target: replace dense, delicate transducer matrices with undrilled borosilicate plates (`{{c:desktop_geometry.ports_per_plate}}` edge-mounted discs per plate in Desktop Rev F) driven and sensed on the same electrical ports.

| Cornerstone capability | Primary laboratory publication | What was achieved in the lab | Replicator scope & remaining gap |
|---|---|---|---|
| Single-channel time-reversal focusing in a reverberant wafer | **Draeger & Fink, [*Phys. Rev. Lett.* 79, 407 (1997)](https://doi.org/10.1103/PhysRevLett.79.407)** (`R092`) | Experimentally focused pulsed elastic waves to diffraction limits inside a 2D monocrystalline silicon wafer using **one** edge transducer via cavity reverberation and reciprocity. | Foundational proof that plate reverberation multiplies channel degrees of freedom; Desktop Rev F simulations show CW trapping still needs multi-tone/multi-port control to curb parasitic wells. |
| Boundary holography & selective DORT focusing from measured `M` | **Williams & Maynard, [*Phys. Rev. Lett.* 45, 554 (1980)](https://doi.org/10.1103/PhysRevLett.45.554)** (`R108`); **Prada, Fink et al., [*J. Acoust. Soc. Am.* 99, 2067 (1996)](https://doi.org/10.1121/1.415393)** (`R104`) | Sub-wavelength 3D source imaging from boundary measurements (NAH), and selective focusing onto individual scatterers by diagonalizing a measured transfer matrix (`DORT`). | Establishes textbook boundary-to-interior focusing; **OPH extensions beyond linear wave physics remain `OPEN` / unverified until bench-tested.** |
| Single-sensor 3D ultrasound imaging via coded scatterer | **Kruizinga et al., [*Sci. Adv.* 3 (2017)](https://doi.org/10.1126/sciadv.1701423)** (`P026`) | Experimentally reconstructed 3D ultrasound scenes from one sensor behind a spatially coded asymmetric scatterer mask. | Inspires the Desktop's asymmetric rear Pinna baffle and sparse-port `HAPTIC` tomography. |
| Reciprocity transducer calibration (`S = Sᵀ`) | **DiMattia & Wiener, [*J. Acoust. Soc. Am.* 18, 341 (1946)](https://doi.org/10.1121/1.1916371)** (`R105`) | Demonstrated absolute acoustic transducer calibration via cross-port reciprocity across three reference laboratories without an external probe. | Physical basis for `INS-35` live `||S - Sᵀ||` chamber calibration and convection drift alarm. |
| Collocated self-sensing piezoelectric actuation | **Dosch, Inman & Garcia, [*J. Intell. Mater. Syst. Struct.* 3, 166–185 (1992)](https://doi.org/10.1177/1045389X9200300109)** (`P024`) | Experimentally extracted velocity and strain directly from the same piezoelectric wafer driving mechanical motion via bridge-balance separation. | Direct hardware precedent for `HAPTIC` drive/receive multiplexing on `{{c:haptic_pzt.adc_fallback_mpn}}`. |
| Thin-film lithium niobate (`TFLN`) acousto-optic modulation | **Liu et al., [*Optics Letters* 51(19), 5397–5400 (2026)](https://doi.org/10.1364/ol.608786)** (`R086`) | Demonstrated non-collinear integrated waveguide AOMs on chalcogenide-loaded TFLN with measured `VπL = 0.93 V·cm` across fundamental and higher-order modes (`TE₀₀`–`TE₂₀`). | Horizon integrated photonic/acoustic modulator precedent; does not change `{{c:haptic_pzt.bridge_rail_v}} V` PZT budgets today. |
| GHz NEMS topological phononic edge transport | **Jiang et al., [*Phys. Rev. Applied* (2026)](https://doi.org/10.1103/3gpm-mkyh)** (`R087`) *(journal landing summary)* | Journal summary reports experimental realization of a gigahertz quantum spin Hall topological waveguide in NEMS phononic crystals. | Long-term on-chip GHz phononic interconnect lead (full methods behind publisher gate; distinct from `32–160 kHz` chamber air drive). |

---

## 3. Contactless Optical Tomography of Sound Fields (`LightRead` / `SMI`)

Replicator target: read 3D chamber sound pressure and object silhouettes optically through the borosilicate wall using `{{c:mosquito_smi.total_ommatidia}}` self-mixing laser diodes (`SMI`), keeping microphones and cameras out of the work volume.

| Cornerstone capability | Primary laboratory publication | What was achieved in the lab | Replicator scope & remaining gap |
|---|---|---|---|
| Non-invasive imaging of airborne acoustic fields via optical self-mixing | **Bertling et al., [*Optics Express* 22, 30346–30356 (2014)](https://doi.org/10.1364/OE.22.030346)** (`P030`) | Experimentally imaged standing-wave airborne ultrasonic pressure fields directly through laser-diode self-mixing interferometry (`SMI`) without placing a probe in the field. | Exact measurement principle behind Desktop `LightRead`; quantitative review equations in **Giuliani et al. ([`P031`](https://doi.org/10.1088/1464-4258/4/6/371))**. |
| Tomographic 3D sound-field reconstruction from laser line integrals | **Torras-Rosell, Barrera-Figueroa & Jacobsen, [*J. Acoust. Soc. Am.* 131, 3786 (2012)](https://doi.org/10.1121/1.3695394)** (`R093`) | Experimentally reconstructed 3D airborne sound pressure via Radon inversion of acousto-optic phase integrals along traversing laser beams. | Validates line-integral inversion of chamber sound fields; Desktop tests sparse `24`-ray fusion with `HAPTIC` echoes in `LM-1`. |

---

## 4. Coherent Perfect Absorption (`CPA`): Time-Reversed Energy Extraction (`REMOVE`)

Replicator target: physically unbind and drain localized field energy (`REMOVE`) using time-reversed S-matrix absorption eigenmodes rather than unphysical field conjugation.

| Cornerstone capability | Primary laboratory publication | What was achieved in the lab | Replicator scope & remaining gap |
|---|---|---|---|
| Acoustic duct & experimental interferometric anti-lasing (`CPA`) | **Wan, Chong, Ge, Noh, Stone & Cao, [*Science* 331, 889–892 (2011)](https://doi.org/10.1126/science.1200735)** (`R069`); **Meng et al., [*Sci. Rep.* (2017)](https://doi.org/10.1038/srep43574)** (`R106`) | Demonstrated interferometric wave absorption ("anti-lasing") in optics (`R069`) and experimental broadband acoustic CPA inside an airborne duct (`R106`). | Foundational optical and airborne acoustic proof behind the [`REMOVE`](matter-loop.html) S-matrix minimum singular vector law (`INS-11`). |
| `CPA` inside a complex multi-scattering disordered cavity | **Pichler, Kühmayer, Rotter et al., [*Nature* 567, 351–355 (2019)](https://doi.org/10.1038/s41586-019-0971-3)** (`R094`) | Achieved **`~99.8%` coherent wave absorption** inside a disordered multi-scattering chamber by solving and injecting the measured scattering-matrix zero eigenmode. | Directly proves `CPA` works inside strongly reverberant cavities like the Replicator chamber; airborne acoustic thermal/debond rates stay `OPEN`. |
| Massively degenerate `CPA` for arbitrary dynamic wavefronts | **Slobodkin, Katz et al., [*Science* 377, 995–998 (2022)](https://doi.org/10.1126/science.abq8103)** (`R095`) | Extended `CPA` to thousands of spatial modes inside a degenerate cavity, absorbing arbitrary time-varying wavefronts interferometrically. | Long-term optical cavity precedent for programmable multi-mode energy sinks inside unified chambers. |

---

## 5. Space-Time Toroidal Pulses, Non-Radiating Anapoles & Programmable Optical Boundaries

Replicator target: non-contact broadband material identification (`INS-33`), non-radiating near-field modes, and high-pixel optically-addressed boundary plates (`~10⁵` elements in the long-term horizon).

| Cornerstone capability | Primary laboratory publication | What was achieved in the lab | Replicator scope & remaining gap |
|---|---|---|---|
| Experimental generation of space-time toroidal ("flying doughnut") pulses | **Zdagkas, Zheludev et al., [*Nat. Photonics* 16, 523–528 (2022)](https://doi.org/10.1038/s41566-022-01028-5)** (`P015`); **Wang, Zheludev et al., [*Commun. Phys.* (2024)](https://doi.org/10.1038/s42005-024-01850-z)** (`P016`) | Generated optical/THz space-time nonseparable toroidal pulses with skyrmionic topologies and demonstrated sub-wavelength super-resolution localization using a single detector. | Underpins broadband toroidal EM material spectroscopy and optional `12`-arm spiral launchers (`INS-12`, `INS-33`); high-power GHz/THz launchers are not yet fitted on Desktop. |
| Experimental non-radiating dielectric anapole modes | **Miroshnichenko, Kuznetsov, Kivshar et al., [*Nat. Commun.* 6, 8069 (2015)](https://doi.org/10.1038/ncomms9069)** (`R071`) | Observed radiationless anapole scattering dips in dielectric silicon nanoparticles where electric and toroidal dipoles cancel in the far field (`p = i k T`). | Physical precedent for sub-wavelength material anapole signatures modeled in [`periodic_table.py`](periodic-table.html); end-to-end tri-modal material classification in an airborne levitator remains **`SIMULATED` / `OPEN`** (`OPH-T3`). |
| Optically addressed metasurface spatial light modulator (`SLM`) | **Kuznetsov et al., [*Nat. Nanotechnol.* (2026)](https://doi.org/10.1038/s41565-026-02128-x)** (`P017`); **Direct TiO₂ metasurface printing, [*Nat. Protoc.* (2026)](https://doi.org/10.1038/s41596-026-01407-0)** (`R013`) | Demonstrated optically addressed pixelated metasurface wavefront modulation (`P017`) and wafer-scale UV nanoimprint replication of high-index TiO₂ metasurfaces (`R013`). | Direct manufacturing & device precedent for `U2` TiO₂ SMI diffuser strips and long-term `10⁵`-pixel optically switched boundaries. |
| All-optical rewriteable photonic circuits (~100 ms redraw) | **Ropač (Humar Lab), [*Adv. Photonics* (2026)](https://doi.org/10.1117/1.AP.9.1.016006)** (`R084`) | Focused IR laser writing in a liquid-crystal cell creates waveguides, lenses, splitters, gratings, and logic gates that can be erased and **redrawn in `~100 ms`** without cleanroom lithography. | Closest published laboratory precedent for a dynamically rewritable optical boundary plate on the long-term horizon. |
| Multi-channel Janus metasurface holography & THz plasma time boundaries | **Wang, Huang et al., [*Adv. Photonics* (2026)](https://doi.org/10.1117/1.ap.8.5.056006)** (`R085`); **Huang, Asadchy et al., [*Sci. Adv.* (2026)](https://doi.org/10.1126/sciadv.aed2916)** (`R088`) | Fabricated triple-layer Janus metasurfaces multiplexing direction/phase/polarization/wavelength (`R085`), and demonstrated bidirectional THz frequency conversion at a resonant plasma time boundary (`R088`). | Confirms dense multi-parameter boundary holograms (`R085`) and active time-boundary frequency conversion (`R088`) are experimentally real, though not part of Rev F hardware. |

---

## 6. Physical Wave Computing, In-Situ Photonic Backprop & `Sb₂S₃` Phase-Change Memory (`Cadence` -> `U3`)

Replicator target: move inverse field compilation from the `< {{c:cadence_brain.cadence_sparse_max_kb}} kB` `RP2350B` `Cadence` seed (`Card 1`) to near-zero-electricity physical wave/optical hardware (`Card 3`).

| Cornerstone capability | Primary laboratory publication | What was achieved in the lab | Replicator scope & remaining gap |
|---|---|---|---|
| Training mechanical plates & optical crystals as neural networks | **Wright, McMahon et al., [*Nature* 601, 549–555 (2022)](https://doi.org/10.1038/s41586-021-04223-6)** (`R096`) | Experimentally trained an oscillating titanium plate, an optical crystal waveguide, and analog circuits as deep neural layers using Physics-Aware Training. | Proves the same `Cadence` inverse map can execute physically in vibrating metal/glass plates as well as optics. |
| Experimental physical backpropagation via optical wave reciprocity | **Pai, Miller et al., [*Science* 380, 398–404 (2023)](https://doi.org/10.1126/science.ade8450)** (`R097`) | Experimentally computed backpropagation gradients in situ inside a silicon-photonic MZI mesh by injecting optical adjoint error fields backward through the same reciprocal hardware. | Direct experimental proof of `Cadence`'s reciprocal Helmholtz adjoint design rule (`H^T = H` wave physics computes gradients directly). |
| Processor-free analog Equilibrium Propagation hardware | **Dillavou, Stern, Liu & Durian, [*PNAS* 121, e2319718121 (2024)](https://doi.org/10.1073/pnas.2319718121)** (`R098`) | Built a twin nonlinear analog electrical network that learns supervised tasks autonomously using local contrastive steady-state physics (Scellier & Bengio [`P032`](https://doi.org/10.3389/fncom.2017.00024)) without any digital processor. | Laboratory validation of analog Equilibrium Propagation prior to photonic `Card 3` deployment. |
| Ultra-low-loss reversible `Sb₂S₃` / `Sb₂Se₃` phase-change photonics | **Delaney, Muskens et al., [*Adv. Funct. Mater.* 30, 2002447 (2020)](https://doi.org/10.1002/adfm.202002447)** (`R099`) | Demonstrated non-volatile, reversible optical refractive-index switching (`Delta n ~ 0.6–0.8`) with near-zero absorption loss across NIR/telecom bands in `Sb₂S₃` and `Sb₂Se₃`. | Non-volatile analog synaptic weight medium targeted for Replicator `U3` Compute `Card 3` optical cores. |

---

## 7. Volume Holographic Crystal Memory (`LiNbO₃` Keeper Storage)

Replicator target: store compressed `holo-eq/0.3-mm` mesoscale equations (`6.35×10¹¹` bits for a `250 g` iron reference object, `INS-36`) in a compact `~1 cm³` photorefractive keeper rather than attempting unphysical `10²⁶`-bit atom-by-atom storage.

| Cornerstone capability | Primary laboratory publication | What was achieved in the lab | Replicator scope & remaining gap |
|---|---|---|---|
| Digital holographic storage & fast retrieval in `Fe:LiNbO₃` | **Heanue, Bashaw & Hesselink, [*Science* 265, 749–752 (1994)](https://doi.org/10.1126/science.265.5173.749)** (`R100`) | Stored and retrieved digital binary pages volumetrically inside iron-doped lithium niobate (`Fe:LiNbO₃`) crystal via angle multiplexing. | Experimental crystal-memory foundation for `INS-36` keeper capacity scaling; full `10¹² bits/cm³` multiplexing density remains an engineering integration step. |
| Multi-resonant `TFLN` metasurface modulation | **Xu & Cong, [*Appl. Phys. Lett.* (2026)](https://doi.org/10.1063/5.0351575)** (`R001`); **Wagner et al., [*J. Infrared Milli. Terahz. Waves* (2026)](https://doi.org/10.1007/s00340-025-08616-7)** (`R008`) | Demonstrated optical-pump THz QBIC modulation in thin-film lithium niobate (`R001`) and 488 GHz waveguide generation in periodically poled LN (`R008`). | Supporting measured lithium-niobate THz conversion precedents on the horizon ladder. |

---

## 8. Thousand-Atom Optical Tweezer Arrays & Nanoscale Cold Welding (`Ultimate` Horizon)

Replicator target: bridge from mesoscale prefabricated micro-bricks (`~10 µm`) to continuous neutral-atom optical replenishment and room-temperature crystalline lattice seams (`U7`).

| Cornerstone capability | Primary laboratory publication | What was achieved in the lab | Replicator scope & remaining gap |
|---|---|---|---|
| `6,100`-site neutral-atom holographic optical tweezer array | **Manetsch, Endres et al., [*Nature* (2025)](https://doi.org/10.1038/s41586-025-09641-4)** (`R101`) | Trapped `6,100` individual neutral cesium atoms simultaneously in holographically shaped `~12,000`-trap optical arrays with multi-second lifetimes. | Demonstrates neutral-matter optical array scaling (`Rung R4` upper reference); requires ultrahigh vacuum and microkelvin cooling, not ambient Desktop operation. |
| Continuous conveyor-belt replenishment of `>3,000` optical tweezers | **Chiu, Lukin et al., [*Nature* (2025)](https://doi.org/10.1038/s41586-025-09596-6)** (`R102`) | Continuously replenished and maintained a `>3,000`-atom neutral optical array without pausing array operation using an optical conveyor belt. | Proves continuous neutral-feedstock stream replenishment in optical traps (`R4`); complements pulsed fractional Fermi gases (`R082`). |
| Room-temperature nanocrystalline cold welding (`0` thermal melt) | **Lu, Huang, Lou et al., [*Nat. Nanotechnol.* 5, 218–224 (2010)](https://doi.org/10.1038/nnano.2010.4)** (`R103`) | Cold-welded single-crystalline gold nanowires together at room temperature by gentle mechanical contact alone, producing near-perfect lattice continuity across the seam. | Experimental proof of room-temperature crystalline seam joining behind the two-scale prefabricated brick-plus-seam architecture (`R3`/`U7`). |

---

## Navigation & What Stays Strictly Separated

- **Audit the full source tiers:** See [Research library](research.html) — **Section 1** lists all published laboratory experiments and protocols (`R`/`P` DOIs), **Section 2** lists reference data and analytical models, and **Section 3** quarantines patents and unverified exploratory claims (`P004`, `P020–P023`) away from experimental evidence.
- **Check what is currently simulated vs. built:** See [Current state](status.html) for every failing simulation gate, hardware release blocker, and open engineering risk.
- **Explore the first buildable benchtop hardware:** See [Desktop Replicator](desktop-replicator.html) (`Rev F2`, stock DURAN cylinder, `{{c:desktop_geometry.ports_per_plate}}` ports per plate, `{{c:mosquito_smi.total_ommatidia}}` optical rays, zero hardware ordered yet).
