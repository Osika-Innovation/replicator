# P0 — calibration and operating margin (SIMULATED)

Record of the matrix runs of 2026-11-12/13 (`fieldc p0 matrix`, receipts
`Receipts/p0-*.json` with one CSV row per case in `Receipts/p0_*.csv`; the
table at the end is `Tools/p0_matrix_summary.py Receipts/p0_p2-*.csv`).
Everything here is the twin's emulated bench: no hardware exists.

## What a case is

One emulated bench session: a random build of P0 (element gain ±10 %, phase
±20°, position ±0.2 mm, resonance ±0.3 %) → calibration through
`MachineBackend` → a hold, 5 mm up, 5 mm across, hold, release job planned
and played → a Ø1.5 mm polystyrene bead integrated through the field the
build actually radiates (16-bit wire, pulse widths of 512 steps).

**Two metrics, kept apart.**
*Travel error*: the bead's displacement from where it was first held, against
the displacement asked. A manipulation observable; a camera can measure it.
The pass bar is 0.5 mm. *Absolute error*: where the bead ends against the
drawing's point. It includes where the calibration probe sat and is what a
fabricated part would inherit. It is reported and has no bar; passing on
travel does not establish fabrication accuracy.

**What the planner sees.** The drawing, the calibration record and its own
constants. The build's errors are used to radiate and to score, never to
plan. A *refusal* is the planner declining to play; *played and failed* is
the planner being wrong.

## The planner's policy, and how it got there

| Policy | Rule | Result at 46 mm |
|---|---|---|
| none (first runs) | drive level fixed by hand at 4× holding | passes and failures mixed; superseded |
| original, unfrozen | gentlest of 2×, 4×, 6×, 8× that carries on the calibrated model and on two copies moved by what calibration cannot see | **17 of 18** (six builds × plates reflecting 0, 0.5, 0.9). The failure: a 2× job that passed its models and lost the bead |
| floor raised to 4× | as above from 4× | the one failed case re-run alone: **pass**. The other 17 were not re-run |
| `P0-planner/1`, frozen | levels 4×, 6×, 8×; steps 40, 80 ms; ceiling 0.71 of full drive; model within 0.25 mm; copies (elements ±0.2 mm, plates ±15°, or ±5° after a reference pass) within 0.5 mm | two-pass 18 of 18; with reference 17 of 18 (one refused); **receiver tilted 3° on the reference pass: 0 of 3, played and lost** |
| `P0-planner/2`, frozen, current | as /1, but the plates' turn after a reference is twice the spread its pairs report (at least ±5°), and ±15° if that spread exceeds 7.5° | table below |

/1 failed because it trusted any reference pass to ±5°. A tilted receiver
corrupted the amplitude of the plates' ratio while its pairs disagreed by
13–16°, a number the planner had and ignored. /2 uses the spread, and the
calibration now takes only the phase of the ratio. The /1 receipts
(`p0-mx-*`) are kept.

## The phase between the plates

A receiver can hears the plate it faces, so two facing passes calibrate each
plate on its own and leave their relative phase unmeasured: 1.6–13.8° on the
builds tried (it is the difference of two means of sixteen ±20° errors).

**Minimum reference:** one lower element and the upper element facing it,
heard by the same receiver lying on its side in the mid-plane. They arrive at
mirror angles, so the receiver's directivity — unknown to the calibrator — is
the same for both and cancels in their ratio. One pair suffices in principle;
the pass plays all sixteen and reports how far they disagree.

| Disturbance during calibration (held-out truth in brackets) | Plates left apart | Jobs (policy /2) |
|---|---|---|
| none | 0.0–0.3° (from 1.6–13.8° without the pass) | 17 of 18; one played, travel 0.51 mm |
| receiver noise 30 dB below each record | 0.02–0.14° | 3 of 3 (policy /1) |
| air 0.5 K warmer by the last pass | 0.04–0.27° | 3 of 3 (policy /1) |
| receiver tilted 3° on the side pass | 1.9–2.2°; pairs disagree by 13–16° | 3 of 3 (0 of 3 under /1) |
| probe 0.05 mm above the mid-plane | 2.5–2.7° | 3 of 3 (policy /1) |
| probe 0.2 mm above the mid-plane | 9.9–10.1° | 3 of 3 (policy /1) |
| all four together (0.2 mm, 3°, 30 dB, 0.5 K) | 10.5–16.0° | 8 of 9, one refused; travel 0.08–0.40 mm |

The probe's height is not an error the reference can remove: about 50° per
millimetre, it is the definition of the origin. A probe 0.2 mm high gives a
machine whose traps all sit 0.2 mm high and whose travel is unaffected. A
point microphone needs no reference pass and leaves 0.0°; it is a different
sensor and input stage (11 of 12 here; one job played and lost at reflection 0.9).

## The neighbourhood of 46 mm

With the reference pass, three builds per cell:

| Gap mm | plates reflecting 0 | plates reflecting 0.9 |
|---:|---|---|
| 44 | 3 of 3 | 2 of 3 (one played, travel 0.73 mm) |
| 45 | 3 of 3 | 3 of 3 |
| 45.5 | 3 of 3 | 3 of 3 |
| 46 | 6 of 6 | 5 of 6 (one played, 0.51 mm) |
| 46.5 | 3 of 3 | 3 of 3 |
| 47 | 3 of 3 | 1 of 3 (two refused) |
| 48 | 3 of 3 | 0 of 3 (one refused, two played and failed) |

With non-reflecting plates the gap does not matter over 44–48 mm. With
strongly reflecting plates the window is about **45–46.5 mm**.

**Requirements this sets (DERIVED from the window; frequency and temperature
were not themselves varied in a run):**

| | Requirement | Basis |
|---|---|---|
| Gap | 45.75 ± 0.5 mm, by calipers on the nuts | leaves 0.25 mm of the window |
| Air temperature | no control; recalibrate, or retune, if it moves more than about 3 K from the calibration | the gap in wavelengths moves 0.17 % per kelvin: 0.08 mm of gap per kelvin |
| Drive frequency | can stand in for gap: 1 % (400 Hz) per 0.46 mm | the controller's divider steps about 5 Hz; the transmitter's own bandwidth (not in its datasheet) limits the range |
| Calibration | reference pairs' spread under 7.5°, else the planner falls back to ±15°; repeat calibration after any change of gap | policy /2 |
| Tracking during a job | none shown necessary at this scale | a job lasts 3 s |

## Does the reflection model change the conclusion?

At 46 mm, plates reflecting 0.9, with the reference pass: 3 of 3 with one
image, 3 of 3 with six (the engine's default is three); 3 of 3 at reflection
0.95. So neither the depth of the image series nor a higher coefficient
moves the 46 mm result, on three builds each. **Not tested, and able to move
it:** a reflecting plane that is not the cans' faces (a phase on reflection
acts like a change of gap, and the window is 1.5 mm wide), reflection that
varies across the face, and the probe's own echo. The bench's first
measurement is therefore the cavity itself: a frequency sweep with the probe
finds where the gap sits in the window before any job is played.

## What is not shown

* No case ran on hardware; the controller's board firmware has not been flashed.
* Six builds, one bead, one path. 105 cases under /2: 96 pass, 5 played and failed, 4 refused.
* Absolute error under /2 is 0.06–0.70 mm; the travel bar says nothing about it.

## All cases under `P0-planner/2`

| run | calibration | gap mm | reflection | images | pass | refused | played and failed | travel error mm | absolute mm | plates left apart ° |
|---|---|---:|---:|---:|---:|---:|---:|---|---|---|
| p2-can-46 (2) | receiver can, one pass per plate | 46 | 0 | 3 | 6 of 6 | 0 | 0 | 0.20–0.40 | 0.34–0.70 | 1.6–13.8 |
| p2-can-46 (2) | receiver can, one pass per plate | 46 | 0.5 | 3 | 6 of 6 | 0 | 0 | 0.13–0.28 | 0.11–0.51 | 1.6–13.5 |
| p2-can-46 (2) | receiver can, one pass per plate | 46 | 0.9 | 3 | 6 of 6 | 0 | 0 | 0.16–0.49 | 0.14–0.60 | 1.7–13.3 |
| p2-point-46 (2) | point microphone, one pass | 46 | 0 | 3 | 4 of 4 | 0 | 0 | 0.21–0.38 | 0.41–0.54 | 0.0–0.0 |
| p2-point-46 (2) | point microphone, one pass | 46 | 0.5 | 3 | 4 of 4 | 0 | 0 | 0.11–0.17 | 0.10–0.22 | 0.0–0.0 |
| p2-point-46 (2) | point microphone, one pass | 46 | 0.9 | 3 | 3 of 4 | 0 | 1 | 0.10–0.29 | 0.18–0.41 | 0.0–0.0 |
| p2-ref-46 (2) | receiver can, one pass per plate and a side reference pass | 46 | 0 | 3 | 6 of 6 | 0 | 0 | 0.21–0.39 | 0.33–0.60 | 0.0–0.3 |
| p2-ref-46 (2) | receiver can, one pass per plate and a side reference pass | 46 | 0.5 | 3 | 6 of 6 | 0 | 0 | 0.10–0.19 | 0.20–0.31 | 0.0–0.3 |
| p2-ref-46 (2) | receiver can, one pass per plate and a side reference pass | 46 | 0.9 | 3 | 5 of 6 | 0 | 1 | 0.10–0.51 | 0.19–0.48 | 0.0–0.3 |
| p2-ref-gaps (2) | receiver can, one pass per plate and a side reference pass | 44 | 0 | 3 | 3 of 3 | 0 | 0 | 0.21–0.30 | 0.41–0.43 | 0.0–0.3 |
| p2-ref-gaps (2) | receiver can, one pass per plate and a side reference pass | 44 | 0.9 | 3 | 2 of 3 | 0 | 1 | 0.35–0.73 | 0.25–0.47 | 0.0–0.3 |
| p2-ref-gaps (2) | receiver can, one pass per plate and a side reference pass | 45 | 0 | 3 | 3 of 3 | 0 | 0 | 0.28–0.33 | 0.41–0.54 | 0.0–0.3 |
| p2-ref-gaps (2) | receiver can, one pass per plate and a side reference pass | 45 | 0.9 | 3 | 3 of 3 | 0 | 0 | 0.23–0.43 | 0.19–0.49 | 0.0–0.3 |
| p2-ref-gaps (2) | receiver can, one pass per plate and a side reference pass | 45.5 | 0 | 3 | 3 of 3 | 0 | 0 | 0.28–0.39 | 0.48–0.54 | 0.0–0.3 |
| p2-ref-gaps (2) | receiver can, one pass per plate and a side reference pass | 45.5 | 0.9 | 3 | 3 of 3 | 0 | 0 | 0.18–0.38 | 0.28–0.41 | 0.0–0.3 |
| p2-ref-gaps (2) | receiver can, one pass per plate and a side reference pass | 46.5 | 0 | 3 | 3 of 3 | 0 | 0 | 0.23–0.31 | 0.39–0.45 | 0.0–0.3 |
| p2-ref-gaps (2) | receiver can, one pass per plate and a side reference pass | 46.5 | 0.9 | 3 | 3 of 3 | 0 | 0 | 0.22–0.46 | 0.38–0.47 | 0.0–0.3 |
| p2-ref-gaps (2) | receiver can, one pass per plate and a side reference pass | 47 | 0 | 3 | 3 of 3 | 0 | 0 | 0.27–0.40 | 0.38–0.55 | 0.0–0.3 |
| p2-ref-gaps (2) | receiver can, one pass per plate and a side reference pass | 47 | 0.9 | 3 | 1 of 3 | 2 | 0 | 0.23–0.23 | 0.53–0.53 | 0.0–0.3 |
| p2-ref-gaps (2) | receiver can, one pass per plate and a side reference pass | 48 | 0 | 3 | 3 of 3 | 0 | 0 | 0.26–0.31 | 0.41–0.47 | 0.0–0.3 |
| p2-ref-gaps (2) | receiver can, one pass per plate and a side reference pass | 48 | 0.9 | 3 | 0 of 3 | 1 | 2 | — | — | 0.0–0.2 |
| p2-ref-model (2) | receiver can, one pass per plate and a side reference pass | 46 | 0.9 | 1 | 3 of 3 | 0 | 0 | 0.13–0.35 | 0.34–0.45 | 0.0–0.3 |
| p2-ref-model (2) | receiver can, one pass per plate and a side reference pass | 46 | 0.9 | 6 | 3 of 3 | 0 | 0 | 0.27–0.38 | 0.34–0.53 | 0.0–0.3 |
| p2-ref-r95 (2) | receiver can, one pass per plate and a side reference pass | 46 | 0.95 | 3 | 3 of 3 | 0 | 0 | 0.22–0.28 | 0.31–0.39 | 0.0–0.3 |
| p2-ref-stress (2) | receiver can, one pass per plate and a side reference pass, noise 30 dB down, air 0.5 K warmer by the last pass, probe 0.20 mm high, tilted 3° | 46 | 0 | 3 | 3 of 3 | 0 | 0 | 0.24–0.40 | 0.14–0.29 | 15.9–16.0 |
| p2-ref-stress (2) | receiver can, one pass per plate and a side reference pass, noise 30 dB down, air 0.5 K warmer by the last pass, probe 0.20 mm high, tilted 3° | 46 | 0.5 | 3 | 3 of 3 | 0 | 0 | 0.08–0.18 | 0.06–0.10 | 11.8–11.9 |
| p2-ref-stress (2) | receiver can, one pass per plate and a side reference pass, noise 30 dB down, air 0.5 K warmer by the last pass, probe 0.20 mm high, tilted 3° | 46 | 0.9 | 3 | 2 of 3 | 1 | 0 | 0.20–0.26 | 0.09–0.15 | 10.5–10.7 |
| p2-ref-tilt3 (2) | receiver can, one pass per plate and a side reference pass, tilted 3° | 46 | 0.5 | 3 | 3 of 3 | 0 | 0 | 0.14–0.17 | 0.18–0.21 | 1.9–2.2 |
