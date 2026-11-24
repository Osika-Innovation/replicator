# RH-1 face transmitters — custom part specification (draft for review)

Status 2026-11-12: a specification, not an order. No supplier has been
contacted. It exists because the RH-1 face's elements cannot be bought: a
search of catalogues on 2026-11-12 found open-type air transmitters of
Ø10 mm or less only at 40 kHz, and one 60 kHz part with no stated level
([`../p0-platform/PARTS_RESEARCH.md`](../p0-platform/PARTS_RESEARCH.md)).
The twin's RH-1 results rest on the assumption written here as the
requirement; the numbers become a purchase specification only after the
40 kHz catalog part has been measured on the P0 platform (record K-ELEM in
`twin/Design/upgrade_graph.json`).

## What the twin assumes (and therefore what is asked)

The twin's element is the bought 40 kHz Ø10 mm open-type transmitter
(120 dB re 20 µPa at 30 cm at 10 V rms; at most 20 V p-p) with every length
scaled by 40 kHz ÷ f and the same face velocity, 2.03 m/s peak
(`ElementSpec.scaled`). DERIVED from that, per tone:

| tone kHz | face Ø mm | can Ø × h mm | level at 30 cm at full drive, dB | full drive V rms | per machine (4 faces × 2,560) |
|---:|---:|---|---:|---:|---:|
| 52.8 | 7.6 | 7.6 × 5.3 | 116.7 | 6.8 | 1,138 |
| 58.3 | 6.9 | 6.9 × 4.8 | 115.8 | 6.2 | 1,138 |
| 63.9 | 6.3 | 6.3 × 4.4 | 115.0 | 5.6 | 1,138 |
| 69.4 | 5.8 | 5.8 × 4.0 | 114.3 | 5.2 | 1,138 |
| 75.0 | 5.3 | 5.3 × 3.7 | 113.6 | 4.8 | 1,136 |
| 80.6 | 5.0 | 5.0 × 3.5 | 113.0 | 4.5 | 1,136 |
| 86.1 | 4.6 | 4.6 × 3.3 | 112.4 | 4.2 | 1,140 |
| 91.7 | 4.4 | 4.4 × 3.1 | 111.9 | 3.9 | 1,138 |
| 97.2 | 4.1 | 4.1 × 2.9 | 111.4 | 3.7 | 1,138 |

The level column is the 40 kHz part's level at its 9 V rms full drive
(119.1 dB) less 20 log₁₀(f ÷ 40 kHz): at equal face velocity the source
strength falls as 1/f² and the pressure it makes as 1/f. Air absorption over
30 cm (under 1 dB at 97 kHz) is not included.

## Requirements

| # | Requirement | Value | Where it comes from |
|---|---|---|---|
| 1 | Face velocity, continuous, at the part's own tone | ≥ 2.0 m/s peak (the level above); **the molds of 2026-11-12 use up to 57 % of it** | G-E1 on the 2,560 plate: ring 0.57, tetrahedron 0.54 (SIMULATED) |
| 2 | Resonance | the tone ± 0.3 % within a delivery; a lot may be binned | study S5: an uncalibrated plate fails at ±0.3 %; a calibrated one was tested with ±0.3 % and holds |
| 3 | Quality factor in air | 15–35 (the twin assumes 25) | sets how far the scan can sweep off the tones; ASSUMED, the 40 kHz datasheet states none |
| 4 | Phase between units at the tone | reported per unit, or ±20° | calibration measures it; ±20° was the build the calibrated study used |
| 5 | Outline | can no larger than the table's; two pins or pads at the back | the face plate's holes leave 1 mm of metal (DR11) |
| 6 | Drive | a unipolar square wave, 20 V p-p at most; state the capacitance | the driver is a gate driver per element |
| 7 | Heat | state efficiency or dissipation at full drive | the twin assumes 30 %: about 250 W into two plates at full drive of every element |
| 8 | Life | 1,000 h at full drive within ±3 dB, as the catalog part's life test | parity with the bought part |

## Acceptance test (on the P0 platform's calibration tool)

One unit of each tone on the P0 frame's aperture plate (a printed plate with
that part's pin pattern), a microphone on the probe bar at a known distance,
driven and recorded through `MachineBackend`:

1. Level against pulse width at the tone, 16 to 256 steps of 512: linearity and the level at full drive.
2. Frequency sweep ±10 % at one pulse width: resonance and Q.
3. Thirty units of one tone: scatter of level, resonance and phase.
4. Thirty minutes at full drive: the can's temperature and the level's drift.

Above 40 kHz the probe cannot be the 40 kHz receiver. A MEMS microphone gives
relative numbers (1–3 above, as ratios); requirement 1 in pascals needs a
calibrated ¼" or ⅛" measurement microphone, which is not owned (quote only).

## Open

* Whether such a part can be made at all at these sizes and levels is the
  supplier's answer; the scaling law is an assumption about material strain.
* Fewer tones would mean fewer part numbers. The twin has not been asked how
  few tones still mold evenly; nine sharing the face cost about √9 in drive.
* A band that includes 40 kHz would let one tone be the catalog part. The
  mold band is 50–100 kHz because sites 3.1 mm apart are not resolved at
  30–70 kHz (study of Round 12, on ideal pistons).
* Makers of the catalog parts list custom frequencies; none has been asked.
