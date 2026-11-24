# Body-response interface — `body-response/0.1`

What the platform needs from a coupled body-and-source model (or a bench
measurement of one) to calibrate it and run a job on it. The acoustic-body
session owns the bodies; this file, `FieldCore/Machine/BodyResponse.swift`
and `PlateArray.inputs` own the hand-over. Written 2026-11-12; nothing here
selects an actuator, an amplifier or a geometry.

## The file

JSON, SI units. One file describes both facing bodies.

| Field | Meaning |
|---|---|
| `format` | `"body-response/0.1"`; anything else is refused |
| `name` | short identifier; becomes the machine tag `body-<name>` in receipts |
| `provenance` | `status`: `REFERENCE` (made up to test the interface), `SIMULATED` or `MEASURED`; `source` (session, solver and version, or bench); `date`; `geometry` (CAD file or hash); `note` |
| `driveUnit` | what one unit of an input's drive is: `"V rms"` at the amplifier output, or `"m/s"` for a reference set |
| `gap`, `reflection` | face to face (m); the fraction of sound the faces return (0–1) |
| `patches[]` | the radiating faces sampled as small flat pistons: `x`, `y` (m), `plate` (0 = lower face at z = 0 looking up, 1 = upper at z = gap looking down), `radius` (m). Lower body's first; the same number on each |
| `inputs[]` | `name`, `plate`, `maxDrive` (in `driveUnit`), optional `settling` (s to 1/e, about Q ÷ πf) |
| `frequencies[]` | Hz |
| `response[f][input][patch]` | `[re, im]`: the patch's normal velocity, m/s peak, per unit drive of that input, phase against the drive |
| `uncertainty` | `gain` (relative) and `phaseDegrees`: one standard deviation of every response entry |

Sampling: patches no further apart than half a wavelength in air at the
highest frequency used (4.3 mm at 40 kHz), or the engine's piston model
aliases the face.

## What the twin does with it

`BodyResponse.read` → `array()` gives a `PlateArray` whose elements are the
patches and whose drive channels are the inputs (`PlateArray.inputs`). From
there nothing is special: the same GPU field (`ArrayFieldGPU`, which maps a
drive through the response and its adjoint back), the same compilers, the
same `EmulatedBackend`, `Calibration`, `.fcode` stream and planner.

```sh
fieldc p0 body                                              # writes the two reference files to Design/bodies/
fieldc p0 job --body Design/bodies/p0-identity.json --probe point
fieldc p0 job --body Design/bodies/three-input-demo.json --probe point
```

* The emulated "real" body is one draw of the file's `uncertainty` on every entry.
* Calibration plays each input alone and fits one complex correction per
  input over the microphone points, then compiles on the corrected model.
* The planner (`P0-planner/1`) checks a job on the corrected model and on two
  further draws, each rescaled to what calibration measured: what it treats
  as unseen is the *shape* of an input's pattern, not its size.
* The job's drive is held to 0.71 of the smallest `maxDrive`; a body's
  `settling` slows every change of the field in the bead simulation.

## What the reference sets showed (SIMULATED on made-up data)

| Set | What it is | Result |
|---|---|---|
| `p0-identity` | P0's 32 transmitters written as 32 inputs of one patch each | calibrates and carries: travel error 0.14 mm, against 0.13 mm for the native plates under the same point-microphone calibration. The interface adds nothing and loses nothing |
| `three-input-demo` | three inputs per body — one uniform, two tilted — behind a fixed lens phase; synthetic | calibrates (plates within 0.2°); the planner refuses the 5 mm up + 5 mm across job: the bead leaves the trap on its own model at every level. Six inputs of this made-up kind do not carry. This says nothing about a designed body |

Two things the second set forced, which any few-input body will need:

1. **More than one microphone point.** An input whose field has a node at the
   probe (the tilted patterns, on the axis) cannot be calibrated there. The
   calibration now fits over several points (`Calibration.run(extra:)`); the
   body run uses two.
2. **A ceiling per input.** The compile's amplitude ceiling, written for
   resonant elements, now applies to inputs as well.

## Not in 0.1 — known gaps

* Faces that are not two flat planes; bodies with unequal patch counts.
* More than one frequency in calibration and in the job. The file and the
  field engine take several; `Calibration` and the P0 job use the first.
  Frequency and time multiplexing therefore cannot be evaluated yet.
* Coupling between inputs through the amplifier, and anything nonlinear.
* Electrical quantities: the response is per unit drive, not per watt. Power,
  current and heat need the source's impedance, which the file does not carry.
* Receiving through the body.

## What a few high-power piezo channels ask of the platform (provisional)

Nothing below is a hardware choice; the actuator is not selected.

| | P0 as drafted (32 small transmitters) | A few strong inputs |
|---|---|---|
| Waveform | 0–15 V square, pulse-width amplitude, one tone | sine per input with set amplitude and phase; sums of tones if the body multiplexes in frequency. A square wave into a tuned stack is not acceptable without a filter |
| Generation | 32 pins from one pattern ring | a converter or direct synthesis per input, 12 bits or more, phase steps under 1°, all inputs on one clock. Six channels at 1 MS/s are within the controller's reach; the output stage is not |
| Amplifier | none: a gate driver per element | per input: tens of watts into a load that is tens of ohms at resonance and a capacitor off it; hundreds of volts; matching network; enable and fault lines. Interface to the controller: an analog reference or a serial word, to be fixed with the actuator |
| Bandwidth | transmitter Q about 25 (assumed): settles in 0.2 ms | a preloaded stack with Q of several hundred settles in milliseconds and is tens of hertz wide. Its resonance moves with temperature by more than its width: the drive must track it (voltage–current phase), and `settling` belongs in every job |
| Sensing | one microphone, air temperature | per input: voltage and current as complex amplitudes (impedance, power, resonance tracking), stack temperature; face velocity by microphone points or a vibrometer; air temperature |
| Limits | 0.71 of the datasheet level | per input from the file: voltage, current, stack temperature, face stress. The planner needs them as numbers |
| Calibration | one gain and phase per element at one point | one complex correction per input per frequency over several points, repeated as the stacks warm |
| Safety | 40 kHz at 150 dB, low voltage | high voltage on the stacks; possibly audible sub-harmonics; interlock on the amplifier enable |

**What stays as it is:** `MachineBackend`, the `.fcode` stream and its frame
log (already several tones per frame, a full scale per tone), the record
format (listen gates beyond the drive channels can carry voltage and current
as well as microphones), `Calibration`, the planner, the job records.

**What must change in the controller core** (`Firmware/p0/fcore.c`): one tone
per frame today (`FC_MAX_TONES`); drive as pulse widths; one listen gate at a
time. The wire parser and the reply encoder do not change.
