# Desktop Replicator Rev F firmware (`twin/Firmware/desktop/`)

Firmware for the six `RP2350B` of the Desktop Replicator Rev F (240 mm chamber, lifting glass cylinder). Numbers come from [`coordination/system_constants.json`](../../../coordination/system_constants.json) through [`desktop_constants.h`](desktop_constants.h); `tests/check_constants.py` fails the test run if the header drifts.

**Status.** Everything that does not touch a pin is written and tested on the host (`./run_host_tests.sh`: 295 checks, and 42 constants against `coordination/system_constants.json` with 0 drifted). The `.pio` files assembled with `pioasm` from pico-sdk 2.x on 2026-11-22 and have not been re-assembled since: `#40` changed comments only, `#58` added comments and one `.define` to `haptic.pio`. The C modules compile for Cortex-M33 (`arm-none-eabi-gcc 15.2 -O2 -Wall -Wextra -Werror`, hard float, re-checked 2026-11-22 after the `#77` changes; against stub libc headers, so nothing is linked). **Nothing here has run on a board.** There is no `main`, no board file and no CMake build yet, the pin map below is a proposal. `P0` firmware (`../p0/`) is untouched.

## Files

| File | What it is | Insight |
|---|---|---|
| `haptic.pio` | `haptic_tx` (6 × INA+INB, one pin per bridge leg), `haptic_sd_feedback` + `haptic_sd_reader8` (75 MSa/s 1-bit sigma-delta, 8 channels), `ad7380_x4` / `ad7380_x4_fast` (ADC fallback) | `INS-01`, `INS-28` |
| `lockin_xor.c` | sinc3 (CIC) decimator + square lock-in + de-mix; XOR/popcount lock-in + de-mix; AD7380 sine lock-in; SMI DC occlusion; two-stage `OPA320` response | `INS-01`, `INS-26`, `INS-28` |
| `smi_strip.pio` | 24 sigma-delta loops in one instruction, banked reader (3 banks of 8), laser enable latch | `INS-02` |
| `spinal_bus.c`, `spinal_bus.pio` | `XIN` clock setup, `SYNC` downbeat, 75 Mbit/s phasor packets with CRC-32 | `INS-03` |
| `cadence_sparse_q8.c` | Block-sparse event-driven complex `int8` Hermitian Cadence with eqprop update; **`CSQ8 v1` image loader and settle** for the network SIM trains (`csq8_load`, `csq8_store`, `csq8_settle`, `csq8_settle_biased`); **`HLEQ v1` goal packet verifier** (`hleq_load`, `hleq_stroke_bias`); **`LMQ8 v1` live-M calibration image**, its RAM slot and the read through it (`lmq8_load`, `lmq8_slot_*`, `lmq8_listen`) | `INS-04`, `INS-26` |
| `tests/csq8_reference.py` | NumPy reference of SIM's `CSQ8` layout and settle, for the loader test | |
| `tests/lmq8_reference.py` | `LMQ8` images at +0 / +0.3 / +1 K, one goal packet and scenes, from SIM's operators and functions | `INS-38` |
| `frame_scheduler.c` | 95 % CF / 5 % FM frames, ternary comb and chirp patterns (zero = both legs low) on the 6.67 ns or the 100 ns grid, three comb pulse-length profiles, the three-level 120° single-tone pattern, receive windows on the shared enable, head-down interlock | `INS-07`, `INS-22` |
| `pulse_shocklet.c` | One-bit time reversal and ring (toroidal) shocklet bursts, duty-limited | `INS-12` |
| `tests/host_test.c` | Host tests of all of the above | |

## Timing

| Quantity | Value | Why |
|---|---|---|
| Transmit step | 1 system tick, 6.67 ns | 0.38° at 160 kHz |
| Transmit ring | 18 750 ticks = 125 µs, 9 375 words | 4 periods of 32 kHz, 5 of 40 kHz. The constants' 62.5 µs window is 2 periods of 32 kHz but 2.5 of 40 kHz, so the ring is two of them |
| Capture burst | 37 500 samples = 500 µs, 9 375 words (37.5 kB) | 16 periods of 32 kHz, 20 of 40 kHz, a whole number of 32-bit words. 125 µs is 2 343.75 words |
| Frame | 80 rings = 10 ms | 76 rings CF hold, 4 rings FM chirp (one burst) |

## Lock-in cycle budget and capture scheme (`INS-26`)

The scheme is **burst capture**, then processing at leisure. Continuous lock-in does not fit, as `INS-26` said; the numbers below say by how much.

`lockin_cycles` for the 1-bit path, from the Cortex-M33 object code of `lk_cic_burst()` (about 75 instructions per four input samples, taken as 90 cycles with loads and branches; `DERIVED` from an instruction count, not measured on the part):

| Step | Cost |
|---|---|
| Take one channel's 4 samples out of a capture word (shift, mask, multiply, shift) | ~5 cycles |
| sinc3 integrators for 4 samples (three table loads, shifts, adds: no multiplies) | ~30 cycles |
| Every 12 samples: three combs, then 5 tones × (I and Q add or subtract, phase step) | ~120 cycles, 40 per 4 samples |
| **Total per channel per 32-bit capture word (4 samples of that channel)** | **~90 cycles** |
| **cycles per word, all 7 channels (6 ports + reference)** | **~630** |

- Continuous: 18.75 M capture words/s × 630 = 11.8 G cycles/s against 150 M per core. It is short by a factor of about 80 per core.
- One burst (9 384 words with the filter warm-up): 0.84 M cycles = 5.6 ms **per channel** on one core.
- **capture_duty**: one 500 µs burst per 10 ms frame is 5 % of the time captured. One core dedicated to the lock-in finishes **one channel per frame** with margin, so the 7 channels of a lamina are refreshed every 70 ms on the 1-bit path (35 ms with both cores, leaving nothing for the bus).
- The XOR/popcount path costs about the same (the M33 has no popcount instruction) and gains nothing in the host test below, so the decimating path is the default.

For the AD7380 path the same 500 µs burst is 750 samples per channel. `lk_adc_burst()` is one multiply-accumulate pair and a rotor step per sample per tone on the FPU, taken as 20 cycles: 750 × 5 × 20 = 75 k cycles = 0.5 ms per channel, **4 ms for all 8 channels, inside every 10 ms frame**. Reading four dual ADCs at 1.5 MSa/s is 6 M words/s of DMA; whether the `RP2350B` sustains that beside the transmit ring (75 M words/s) is `OPEN` and is the first thing to measure on a board.

Conclusion for the front-end choice: on cycle budget alone the ADC path serves every channel every frame and the 1-bit path serves one. That agrees with the SFDR ruling.

## What the host test measured

`SIMULATED` on the host, with an ideal first-order modulator (no comparator hysteresis, clamp or reference mismatch: SIM's `holo/sigma_delta.py` has those, this test does not).

| Check | Result |
|---|---|
| sinc3 nibble update against bit-serial integrators; square reference words against bit-serial | exact |
| 5-tone comb through the 1-bit modulator, 500 µs burst, carrier-to-error | sinc3 + de-mix 45.8 dB (desktop-200mm), 41.1 dB (boro12); XOR + de-mix 43.3 dB, 40.0 dB |
| AD7380 lock-in, 750 samples, 16-bit quantisation only | 102.7 dB |
| `OPA320` ×200 at 200 kHz | one stage keeps 0.447 of its DC gain, two stages 0.980 |
| Sparse Cadence | 30 164 bytes, 173 stored blocks, 10.0 % of the block grid |
| eqprop recall of 3 patterns from half the units | overlap 0.01 before learning, 0.84 after 12 epochs |
| One recall | 6 sweeps, 605 block pushes (2 044 if every link fired every sweep) |
| Comb as ternary code, 107 ns pulses, one ring | worst tone error 3.0 % |
| Ring shocklet delays, off-axis target | arrivals within 2.0 ns |
| One-bit time reversal, 6 channels × 14 paths | peak where expected, 15.5 × the largest sidelobe |
| Bus | 75 Mbit/s, 30-phasor packet 14.1 µs, a flipped bit fails the CRC |
| `CSQ8` image `holo/runs/sparse_cadence_q8.bin` and `..._quick.bin` (35 707 bytes each, 390 → 384 ↔ 64, 235 + 38 blocks, 10.0 % of the grid) | loads; `store(load(image))` is the image byte for byte; 9 kinds of damage refused |
| `csq8_settle` against the NumPy reference, one seeded input per image | worst output difference 1.3e-7; same step count (16 and 13) and event fraction (0.139, 0.113) |
| The reference against SIM's own `SparseCadenceQ8.settle` (run with `PY=` an MLX Python) | agrees to 1.1e-7 |
| `CSQ8` settle cost | 61 120 and 50 752 complex MACs (66 % and 65 % of pushing every block every step): 6.1 ms and 5.0 ms at SIM's `ASSUMED` 8 cycles per MAC and 60 per soma |
| RAM of the Card 1 brain (`#77`) | settle state 15.4 kB + live-M calibration slot 43.3 kB = 58.7 kB of the 60 kB (58 748 B on Cortex-M33). The `CSQ8` image (35.7 or 39.1 kB) is flash and is not counted |
| One `HLEQ` packet read through a live `LMQ8` calibration at +0 / +0.3 / +1 K | 99.7 % / 100 % / 100 % exact occupancy on 320 scenes each (`SIMULATED` scenes); through the stale calibration 99.7 % / 20.9 % / 16.6 % |
| `HLEQ v1` packet from NumPy, 6 strokes × 64 outputs | 1 556 bytes; loads; all 12 448 one-bit errors refused, every one in the biases, CRC, echo norm or tolerance as `HLEQ_BAD_CRC`; NaN, infinity, tolerance 0 or NaN, reserved flag refused as `HLEQ_BAD_VALUE` with a correct CRC |
| `csq8_settle_biased` against NumPy, 6 strokes per image, event threshold off | worst difference 2.5e-7 and 3.3e-7. **The spec's `< 2e-7` is not met**; the test holds 1e-6 (see below) |
| The same with the event threshold on (0.010) | 8.3e-4 on one image, 1.8e-7 on the other; bounded by the threshold, not bit-true |
| `csq8_settle` against `csq8_settle_biased` with the image's own bias | identical bytes |
| Comb code at 18 % of full scale per tone, switching loss with zero = both legs low | 496 edges per 125 µs ring, no reversals: 2.86 W per port hard-switched into 4 450 pF at 18 V (`DERIVED`, C ΔV²/2 per edge, no inductor credit) |
| Pulse length against tone error and loss, that one phase set | 16 ticks: 3.0 %, 2.86 W. 32: 5.5 %, 1.38 W. 64: 9.8 %, 0.69 W. 128: 39.7 %, 0.36 W. Over 32 phase sets the errors are larger: see "Comb profiles" |
| Three-level 120° single tone, 160 kHz on the 100 ns grid | 19.79–19.94 V fundamental at 18 V, 80 edges per ring, 0.46 W per port; worst uncommanded line 2.1 % at 240 kHz (see "Three-level") |
| SIM's `hleq_v1_fixture.bin` through `hleq_load` and `csq8_settle_biased`, against NumPy | loads, CRC `42db485c` as the receipt; 3.1e-7 with the event threshold off on both images |

Three things these numbers do not say:

1. The 41–46 dB above is an ideal modulator with a 500 µs window. It is not the 80–87 dB of SIM's echo run and not comparable with it. The decimator's de-mix here is done on the raw estimates before the filter correction; `holo/sigma_delta.py: cic_square_lockin` corrects first and then subtracts, which leaves the difference between the filter's response at `f` and at `3f` in the result. Worth a look by SIM.
2. Settle time. 605 pushes × ~1 100 cycles (instruction count of the 8 × 8 complex block push) = **4.4 ms** at 150 MHz for this recall, below the 8–15 ms target. It is one toy task; the target range was derived from the dense network's 220–300 ms and is not confirmed or refuted by this.
3. Accuracy of a 5–10 % sparse Cadence on the real task is still not evidenced (`INS-26`). The recall test shows the arithmetic learns, nothing more.

## `CSQ8 v1` weight image (`#27`)

`cadence_sparse_q8.c` now reads the image SIM exports (`holo/cadence_drawer.py`, `SparseCadenceQ8.export_blob`). It is a different network from `csq_net` in the same file: `n_in → n_h ↔ n_o` with tied feedback, float state and `int8` weights, where `csq_net` is one square Hermitian matrix in fixed point. Both stay; `csq_net` is the on-device learning experiment, `CSQ8` is what SIM trains and scores.

| Field | Layout (little-endian, unaligned) |
|---|---|
| Header, 34 bytes | `"CSQ8"`, `u16` version 1, `u16` `n_in`, `n_h`, `n_o`, `u8` block 8, `u8` steps, `f32` alpha, drive scale, event threshold, `W_ih` scale, `W_ho` scale |
| `W_ih`, then `W_ho` | `u16` block count, `u16` row pointers × (`n_h`/8 + 1), `u8` column per block, `int8` tile `[block][8][8][re, im]` |
| Output bias | `f16` `[ceil8(n_o)][re, im]` |

- `csq8_load` copies nothing and checks every length and index first: magic, version, block size, shape limits (392 / 384 / 344), finite parameters, row pointers monotone and ending at the block count, columns inside the grid and increasing within a row, exact total length.
- `csq8_settle` pushes a unit's change through `W_ho` only when it moved by the image's threshold, so its counters give the event-driven cost directly.
- The settle uses the FPU (`float`, `tanhf`, `hypotf`). The cycle costs are SIM's `ASSUMED` ones; nothing was timed on the part.
- Limit: `u8` columns cap a matrix at 256 block columns (2 048 units), and the shape limits above are sized for the two images that exist.

## `HLEQ v1` goal packets and the biased settle (`#40`)

`coordination/HOLO_EQUATION_SPEC.md` §5: the network's weights are shared and stay in flash; an object is a set of output biases, one per stroke, streamed as an `HLEQ` packet.

- `csq8_settle_biased(img, x, bias_f16, w)` reads the bias where it lies in the packet. `csq8_work` did not grow for it. (`#77` then shrank it to 15.4 kB and changed what the compile-time check counts: see "Live-M calibration image".) `csq8_settle` is the same call with the image's bias.
- `hleq_load` checks in this order: header length, magic, version, shape (1–16 strokes; output width a multiple of 8, at most 344, equal to the image's), exact length, CRC, then values (reserved flags, tolerance in (0, 1], every `f16` finite). So damage in transit reports `HLEQ_BAD_CRC`, and `HLEQ_BAD_VALUE` means the sender built a bad packet.
- The CRC is byte-wise IEEE CRC-32 and equals `sb_crc32` over the same bytes (tested).

Three things to know:

1. **The spec's `< 2e-7` parity figure is not reachable.** It is under two `float32` rounding steps at unit magnitude. With the event threshold off, this code and NumPy differ by 2.5e-7 and 3.3e-7; NumPy and SIM's own class differ by 1.2e-7. The test holds 1e-6 and prints whether 2e-7 was met. The spec should say 1e-6.
2. **With the event threshold on, the settle is not bit-reproducible across implementations.** A unit that lands within rounding of the threshold announces in one and not the other, and the outputs then differ by up to about the threshold (8.3e-4 seen, threshold 0.010). The firmware's answer and SIM's score for the same packet can differ at that level.
3. **Two packets are tested.** One is written by `tests/csq8_reference.py` from the spec's table. The other is SIM's golden file `holo/runs/hleq_v1_fixture.bin` (`holo/holo_equation.py`, hub `#39`; 6 strokes × 64 outputs, flags 1, echo norm 12345, tolerance 0.125). `hleq_load` accepts it, its header and CRC `42db485c` equal the receipt's, and each stroke settles to within 3.1e-7 of NumPy with the event threshold off (bound 1e-6). The reference script also runs SIM's own `parse_hleq_blob` and `export_hleq_blob` on it: accepted, and reproduced byte for byte. Swift (`HoloEquation.swift`) parses the same file and writes it back byte for byte. Swift has no `CSQ8` settle, so the settle comparison is C against NumPy only.

## Live-M calibration image `LMQ8 v1` (`#77`, `INS-38`)

SIM's `#56`/`#69`/`#71` result: a read-out trained into the flash image stops working when the air warms by 0.3 K, and a linear inverse rebuilt from the transfer the machine has just measured does not. So the firmware now keeps the two apart.

| What | Depends on | Where it lives | Replaced |
|---|---|---|---|
| `CSQ8` weights | nothing at run time | flash | by reflashing |
| `HLEQ` goal packet | the object | wherever the bus left it | per object; same bytes in every chamber |
| `LMQ8` calibration | this chamber, now | RAM (`lmq8_slot`) | after every calibration, no reflash |

**The image.** `est_i = goal_scale × Re(goal_i) + scale_i × Σ_j q_ij v_j`, with `v` the real parts then the imaginary parts of the echo error `x`; site `i` is occupied when `est_i > threshold`. It is SIM's `ridge_inverse` + `quantize_inverse` (`holo/goal_cadence.py`) in a container:

```
"LMQ8" u16 version=1, u16 n_in, u16 n_out, u16 tone_mask,
f32 threshold, f32 goal_scale, u32 calibration_seq, f32 air_temp_offset_k,
f32 scale[n_out], int8 q[n_out][2 n_in], u32 CRC-32 (IEEE, as HLEQ)
```

64 sites × 336 inputs is 43 296 bytes. `tone_mask`, `calibration_seq` and `air_temp_offset_k` say which calibration it is and are not used in the arithmetic.

**The calls.** `lmq8_slot_begin` / `lmq8_slot_write` / `lmq8_slot_commit` stream a new calibration over the old one. `lmq8_listen(slot, packet, stroke, x, est, occupied, &mismatch)` reads one stroke of an object's packet through whatever calibration is held and counts the sites that differ from the goal.

**What the host test shows** (`tests/lmq8_reference.py` builds the images and scenes from SIM's operators in `holo/runs/goal_cadence_live_operators.npz`; `SIMULATED`, 30 dB noise, 320 scenes per temperature, goals on held-out sites):

| Air | Calibration held | Exact occupancy | Disturbed scenes flagged | False alarms on undisturbed scenes |
|---|---|---|---|---|
| +0 K | made at +0 K | 99.7 % | 188 of 189 | 0 of 131 |
| +0.3 K | made at +0.3 K | 100 % | 189 of 189 | 0 of 131 |
| +1 K | made at +1 K | 100 % | 189 of 189 | 0 of 131 |
| +0.3 K | stale (nominal) | 20.9 % | 181 of 189 | 100 of 131 |
| +1 K | stale (nominal) | 16.6 % | 177 of 189 | 111 of 131 |

- The goal packet is one file for all rows, and its CRC is the same after the six swaps. So is the flash image's.
- The C estimate is within 7e-7 of NumPy on the same `int8` matrix, and every occupancy bit agrees.
- One read is 43 008 real multiply-adds: 2.3 ms at 150 MHz at an `ASSUMED` 8 cycles each.
- Refused: a read before any calibration or during a download, half an image, 3 571 single-bit errors, a non-finite threshold or row scale, an image larger than the slot, a stroke the packet lacks, a packet narrower than the calibration.

**RAM.** The slot is 43.3 kB. To hold it beside the settle state under 60 kB, `csq8_work` is now one pool of 1 920 complex values (15.4 kB, was 20.5 kB) cut per image into four vectors of `n_h` and three of `n_o_p`. An image must satisfy `4 n_h + 3 n_o_p ≤ 1 920`: 384 hidden units go with up to 128 outputs, 344 outputs with up to 216 hidden. `csq8_load` refuses the rest. All three images that exist fit (384/64 and 192/64). The compile-time check is now `sizeof(csq8_work) + sizeof(lmq8_slot) < 60 000`; the flash image is no longer counted as RAM.

Four things to know:

1. **There is one slot, not two.** A second copy would be another 43 kB. A download that fails leaves the machine with no calibration, and `LISTEN` refused, until the next one arrives.
2. **The firmware does not form the echo error.** `x` is measured echo minus the echo the object's file predicts in this chamber, and the prediction needs the full sensing operator (336 × 64 complex, 172 kB as `float32`). Whoever builds the image must also supply `x`, or the prediction. A 64 × 64 matrix in the image (4.4 kB) would let the firmware take the raw echo instead; that does not fit under 60 kB beside the settle state as sized.
3. **The inverse is built off the MCU.** The firmware applies it. Solving the ridge system from a measured site dictionary on Card 1 is not written.
4. **`verify_tol` and `echo_norm_q15` of the packet are still unused.** The verdict here is the mismatch count; the spec does not say how the tolerance should be applied.

## Receive paths (`INS-28`)

SIM's cycle-accurate model gave 60.9 dBc SFDR for the 1-bit comparator front-end against the 72 dB gate, which triggers the `AD7380` fallback. Both paths are supported:

- **1-bit**: `haptic_sd_feedback` closes all eight loops with one instruction (`mov pins, !pins`); `haptic_sd_reader8` records the feedback pins, so the recorded bit is the bit that was fed back. `lk_cic_burst()` decimates by 12 with an adds-only sinc3 (75 → 6.25 MSa/s), locks in with square references, and de-mixes the 1/3 and 1/5 harmonics (the 96 and 160 kHz tones leak into the 32 kHz estimate through the square reference).
- **ADC**: `ad7380_x4_fast` reads four dual ADCs at 1.5 MSa/s; `lk_adc_burst()` uses sine references, so there is nothing to de-mix. The SPI timing in the `.pio` is from memory of the datasheet and marked `ASSUMED` there.

## Drive states (`CAD #35`, `IXDD604`)

One `IXDD604` per port, its two outputs as the two legs of a bridge. Two pins per port, INA and INB, and one shared enable per group of ports.

| Code | INA | INB | Across the port |
|---|---|---|---|
| +1 | 1 | 0 | +V |
| −1 | 0 | 1 | −V |
| 0 | 0 | 0 | 0 V, shorted through the two low sides |
| (never emitted) | 1 | 1 | 0 V through the high sides |

- **Zero is not high impedance.** Through the series inductor a Hi-Z zero free-wheels through the body diodes and the odd harmonics come back (CAD: 52 % against 31 %). Before `#40` the firmware's off state was the enable pin low; that is gone.
- **High impedance is the shared enable**, a plain GPIO outside the PIO programs: `fs_rx_window(open)` takes it low so the ports can be heard and high again after. A latched interlock fault takes it low and `fs_rx_window` cannot raise it.
- **Listening needs a receive window.** With zero = short, a port cannot be heard between pulses. Burst capture already runs after the comb stops, so the window is the 500 µs burst.
- **Listen level with the head up is now moot.** CAD powers the enable level shifters through the head-down switch, so with the head up every bridge is high impedance whatever `fs_gate` allows. The code still permits listen level; the hardware does not transmit it.
- **Loss changed with the zero state.** Every pulse now charges and discharges the port: 2.86 W per port hard-switched at the default 16-tick pulse, against the 0.55 W counted in `#27` for a zero that held its charge. Doubling the pulse halves the loss and more than doubles the tone error ("Comb profiles"). CAD's series inductor is what should recover this; nothing here models it.
- **Driver constants (`#58`).** `desktop_constants.h` and `system_constants.json` now name the `IXDD604SITR`: supply limit 35 V (the 18 V rail has 17 V of headroom; the `TC4427A` it replaces was at its limit), and an enable pin. The enable semantics above did not change.

## Drive grid (`#58`)

`fs_config.step_ticks` sets how long one pattern step lasts, and every pattern function builds for it:

| Grid | `step_ticks` | `haptic_tx` clock divider | Steps per 125 µs ring | Ring words | DMA rate |
|---|---|---|---|---|---|
| 6.67 ns | 1 | 1 | 18 750 | 9 375 | 75 M words/s |
| 100 ns | 15 | 15 (`TX_GRID_100NS_DIV`) | 1 250 | 625 | 5 M words/s |

The 100 ns grid is the one CAD's `HA0Drive` model uses. The PIO program is the same; only its clock divider differs. `fs_ring_steps()` gives the array length. The shocklet generators (`pulse_shocklet.c`) still build on the 6.67 ns grid only.

## Three-level 120° single tone (`#58`, `CAD #35`)

`fs_three_level_pattern(cfg, ch, hz, phase_turns, steps, n)`: +1 where cos(2π f t + phase) > 0.5, −1 where it is < −0.5, zero between, read at the middle of each step. Each polarity conducts for a third of the period. It is full drive: gate it with `fs_arm(s, 32767)`. Amplitude is not adjustable in this pattern; a tone the grid cannot hold (under 12 steps per period) is refused.

Measured on the host over one ring, worst over 48 phases. Voltages are the code's Fourier line times the 18 V rail, at the bridge output, before CAD's inductor and damper (`DERIVED`). Loss is C ΔV²/2 per edge into 4 450 pF, hard-switched.

| Tone | Steps per period (100 ns) | Fundamental, 6.67 ns grid | Fundamental, 100 ns grid | Phase error, 100 ns | 3rd harmonic, 100 ns | Worst other line, 100 ns | Edges per ring | W per port |
|---|---|---|---|---|---|---|---|---|
| 32 kHz | 312.5 | 19.85 V | 19.83–19.86 V | 0.10° | 0.19 % | 0.43 % at 816 kHz | 16 | 0.09 |
| 64 kHz | 156.25 | 19.85 V | 19.83–19.86 V | 0.10° | 0.19 % | 0.78 % at 848 kHz | 32 | 0.18 |
| 96 kHz | 104.17 | 19.85 V | 19.83–19.85 V | 0.10° | 0.19 % | 1.13 % at 880 kHz | 48 | 0.28 |
| 128 kHz | 78.125 | 19.85 V | 19.82–19.85 V | 0.10° | 0.19 % | 1.48 % at 912 kHz | 64 | 0.37 |
| 160 kHz | 62.5 | 19.85 V | 19.79–19.94 V | 0.47° | 0.96 % | 2.08 % at 240 kHz | 80 | 0.46 |

- **The ideal figure holds.** (4/π) cos 30° × 18 V = 19.85 V. On the 6.67 ns grid every tone is within 0.01 V of it, the third harmonic is under 0.05 % and no other line exceeds 0.12 %.
- **No comb tone has a whole number of 100 ns steps per period.** The edges then move by up to half a step from one period to the next, and the pattern repeats only every 2 periods (32, 96, 160 kHz), 4 (64 kHz) or 8 (128 kHz). That puts lines at multiples of f/2, f/4 or f/8. For 32–128 kHz they are small and far above the band (the worst sits at 816–912 kHz).
- **160 kHz is the worst case.** Its two alternating periods are 62 and 63 steps. The fundamental moves by ±0.4 % with phase, the third harmonic is no longer absent (up to 1.0 %), and the largest uncommanded line is 2.1 % of the fundamental at 240 kHz, which is 3 × f/2. CAD's network resonates at 294 kHz with `Ø16` discs, so that line is the one to put through `HA0Drive`; this test does not include the network.
- **The fifth harmonic is not removed** by this pattern: 20 % of the fundamental, as theory gives. Only multiples of three are absent.
- **Four edges per period, no reversals.** A single tone at 160 kHz costs 0.46 W per port hard-switched, against 2.86 W for the five-tone comb code.

## Comb profiles (`#58`)

`fs_profile_config(profile, step_ticks)` picks the comb's pulse length. A longer pulse makes fewer edges and so less switching loss, and a larger error on each tone. Measured over one ring for 32 random phase sets of the five tones at 18 % of full scale each. Loss is hard-switched into 4 450 pF at 18 V (`DERIVED`, no inductor credit) and is the mean over the sets.

| Profile | Pulse, 6.67 ns grid | Tone error median / worst | W per port | Pulse, 100 ns grid | Tone error median / worst | W per port |
|---|---|---|---|---|---|---|
| `FS_COMB_FINE` (default) | 16 ticks, 107 ns | 1.8 % / 5.1 % | 2.96 | 15 ticks, 100 ns | 1.8 % / 3.3 % | 3.16 |
| `FS_COMB_LOW_LOSS` | 32 ticks, 213 ns | 5.5 % / 11.9 % | 1.51 | 30 ticks, 200 ns | 5.1 % / 9.9 % | 1.58 |
| `FS_COMB_LOWEST_LOSS` | 64 ticks, 427 ns | 15.9 % / 27.2 % | 0.74 | 60 ticks, 400 ns | 13.9 % / 26.8 % | 0.81 |

- **The figures given in `#40` were one phase set.** 2.86 W / 3.0 %, 1.38 W / 5.5 % and 0.69 W / 9.8 % are reproduced for that set. Over 32 sets the loss is about the same (2.96, 1.51, 0.74 W) but the tone error is worse than that set suggested: the 64-tick profile has a median of 16 % and a worst case of 27 %, not 9.8 %.
- **Tone error is the distance between the phasor that comes out and the one commanded**, relative to the commanded amplitude, on the worst of the five tones. It is deterministic for a given chord, so a calibration that measures the played chord sees it; a planner that assumes the commanded phasors does not.
- **What to use.** `FS_COMB_FINE` when the chord must come out as commanded. `FS_COMB_LOW_LOSS` halves the heat for a typical 5 % error. `FS_COMB_LOWEST_LOSS` quarters it and is only usable if the planner reads back the played phasors.
- **The 100 ns grid costs nothing in accuracy** and 5–9 % more edges at the same profile.
- **Tried and dropped:** correcting the command by the measured tone error and re-quantising (up to 6 rounds). It did not converge; the quantiser's output jumps with small changes of its input.
- For 18 ports the per-lamina figures are 18 × the table: 53 W, 27 W, 13 W hard-switched.

## Interlock (`INS-22`)

`fs_gate()` refuses any drive above listen level (−60 dB, Q15 33) unless the head-down switch reads asserted; a missing reader counts as open. `fs_tick()` runs once per ring: if the head lifts under drive it takes the bridge enable low (every output high impedance), turns the lasers off and latches a fault that only `fs_clear_fault()` with the head down removes. Shocklet builders go through the same gate and write nothing when refused. This is the firmware half; the switch should also cut the driver enable in hardware.

## Proposed pin map, Rev F (one HAPTIC lamina MCU, 6 ports)

No schematic exists; this is what the PIO programs assume.

| GPIO | Use |
|---|---|
| 0–11 | TX: 6 × (INA, INB) |
| 12–15 | spinal bus: D0, D1, FRAME out; FRAME in |
| 16 | `SYNC` |
| 17 | head-down interlock |
| 18–25 | comparator outputs Q_A…Q_F, Q_ref; 25 = shared bridge enable (was spare) |
| 26–33 | sigma-delta feedback FB_A…FB_F, FB_ref, spare |
| 34, 35 | AD7380 SCLK, /CS |
| 36–43 | AD7380 SDOA/SDOB × 4 |
| 44, 45 | spinal bus D0, D1 in |
| 46, 47 | I²C: `TMP117` chamber air sensors |

## Rev G expansion: 18 ports per lamina (`INS-21` S-TR1, `#27`)

**Question.** With the 1-bit `TLV3501` path ruled out (60.9 dBc against the 72 dB gate, and one channel per frame on cycle budget), does freeing its 16 comparator and feedback GPIOs let one `RP2350B` drive 18 two-pin bridges and read 18 ports through `AD7380`s?

**Answer: no. One `RP2350B` runs out of pins, not DMA.** Two per lamina fit with room. A single-MCU variant exists only if the driver takes one pin per port.

### Pin count

Rev F without the 1-bit path uses 32 pins. Rev G adds 12 ports (24 drive pins) and 5 more dual ADCs.

| Function | Rev F, ADC only | Rev G, 2-wire ADC | Rev G, 1-wire ADC | Rev G, trimmed to the bone |
|---|---|---|---|---|
| Drive, (INA, INB) per port | 12 | 36 | 36 | 36 |
| `AD7380` SDO lines | 8 (4 parts) | 18 (9 parts) | 9 | 9 |
| `AD7380` SCLK, /CS, SDI | 2 (no SDI) | 3 | 3 | 3 |
| `SYNC`, head-down interlock | 2 | 2 | 2 | 2 |
| Spinal bus | 6 | 6 | 6 | 3 (half duplex) |
| I²C chamber air sensors | 2 | 2 | 2 | 0 (moved elsewhere) |
| **Total of 48** | **32** | **67** | **58** | **53** |

- The 16 freed pins take Rev F from 48 to 32. Twelve more ports need 24 drive pins alone, so the freed pins are spent before a single extra ADC line is added.
- 1-wire mode (both channels of a part on SDOA, 32 bits per conversion) halves the SDO lines and the sample rate. That the part does 750 kSa/s in this mode is `ASSUMED` from memory of the datasheet.
- SDI is new: 1-wire mode has to be written to the parts. Rev F relied on the power-up default (`ASSUMED` 2-wire).

### What fits

| Plan | Pins | Cost |
|---|---|---|
| **G-1, two MCUs per lamina (recommended)**: MCU-T drives, MCU-R reads | T: 36 drive + enable + `SYNC` + interlock + 6 bus + 2 I²C = **47**. R: 18 SDO + 3 SPI + `SYNC` + 6 bus = **28**, 20 spare | A second `RP2350B`, crystal fan-out and bus drop per lamina. No analog change |
| G-3, one MCU, one pin per port: 18 LEVEL + 1 shared Hi-Z enable, 9 parts in 1-wire mode | 19 + 9 + 3 + 2 + 6 + 2 = **41**, 7 spare | No per-port off state: a port's amplitude can only come from a two-level code, which reverses polarity far more often than the ternary code (see drive loss). 750 kSa/s receive |
| G-2, one MCU, two pins per port, 4 parts behind an 18-to-8 analog multiplexer | 36 + 4 + 2 + 2 + 3 = 47, and the multiplexer select lines, SDI and I²C have nowhere to go | Does not fit |

`clock_and_bus.mcu_count_full_machine` is 6 on 3 PCBs, so two per PCB may already be planned; this README has only ever assigned one per lamina, and nothing here says where the 24-ray SMI reader lives. If the lamina's second MCU was meant for SMI, G-1 needs a third or SMI moves to the base PCB. That allocation is `OPEN` for CAD and the CTO.

### Pin map, plan G-1

A PIO block on the `RP2350B` sees a 32-pin window based at GPIO 0 or 16, and one state machine writes at most 32 pins. So 36 drive pins take two state machines in two PIO blocks, and `SYNC` has to sit in GPIO 16–31 where both windows see it. Both wait on the same `SYNC` edge with the same system clock, so they start on the same tick.

| MCU-T GPIO | Use |
|---|---|
| 0–15 | Drive, ports 0–7: `out pins, 16`, PIO0 (base 0), two steps per 32-bit word |
| 16 | `SYNC` |
| 17–36 | Drive, ports 8–17: `out pins, 20`, PIO1 (base 16), one step per word |
| 37 | head-down interlock |
| 38–43 | spinal bus |
| 44, 45 | I²C: `TMP117` |
| 46 | shared bridge enable (one group; CAD's three groups need two more pins than there are) |
| 47 | spare |

| MCU-R GPIO | Use |
|---|---|
| 0–17 | `AD7380` SDOA/SDOB × 9: `in pins, 18` |
| 18, 19, 20 | SCLK, /CS, SDI (shared by all nine) |
| 21 | `SYNC` |
| 22–27 | spinal bus |
| 28–47 | spare |

### DMA and memory

The Rev F ring is written at one step per system tick: 75 M words/s for 12 pins, which was never credible for a DMA channel and is listed under Open. The comb code already holds every pulse for 16 ticks, so Rev G clocks the drive state machines at a divider of 15: 100 ns steps, 1 250 steps per 125 µs ring (18 750 = 15 × 1 250; 16 does not divide it).

| Stream | Rate | Buffer |
|---|---|---|
| Drive, ports 0–7 (two steps per word) | 5 M words/s, continuous | 625 words per ring |
| Drive, ports 8–17 (one step per word) | 10 M words/s, continuous | 1 250 words per ring |
| Receive, 18 lines × 16 bits at 1.5 MSa/s | 13.5 M words/s, during the 500 µs burst only (5 % duty) | 750 × 9 words = 27 kB per burst |
| **Peak, if it were one MCU** | **28.5 M words/s** | 7.5 kB per ring + 27 kB per burst |

- Against the DMA's ceiling of one transfer per system clock (150 M/s, `ASSUMED` from memory of the datasheet, shared with the CPU's bus use), the peak is 19 %. In plan G-1 MCU-T carries 15 M and MCU-R 13.5 M. The sustained rate is not the limit; it is still `OPEN` until measured on a board.
- A 100 ns drive step is 5.8° of 160 kHz per step. The error-feedback code recovers finer phase from pulse density; the host test's 3.0 % worst tone error was taken at 107 ns pulses on a 6.67 ns grid, and has **not** been re-run on a 100 ns grid.
- Lock-in: 18 channels × 0.5 ms = 9 ms of a 10 ms frame on one core at 1.5 MSa/s. MCU-R has both cores for it (4.5 ms each). On one MCU it would not leave room for the bus and the scheduler.

### Drive loss at `INS-30` values

With zero = both legs low (`CAD #35`), the comb code at 18 % of full scale per tone has 496 edges per ring and loses 2.86 W per port hard-switched into 4 450 pF at 18 V (`DERIVED`: C ΔV²/2 per edge, no inductor or zero-voltage-switching credit). That would be about 51 W per 18-port lamina, so the series inductor is not optional. The `#27` figure of 0.55 W assumed a zero that held its charge and no longer applies. See "Drive states" for the pulse-length trade.

## Open

- Board bring-up: `main`, DMA rings, CMake, flashing. Not started.
- `LMQ8`: the bus message that carries the 43 kB download in pieces, who computes the echo error, and a Swift writer for the image are not written. The network (`csq8_settle_biased`) and the linear read (`lmq8_listen`) are separate calls; nothing combines their answers.
- HSTX for the bus (150 Mbit/s). The PIO bus is 75 Mbit/s.
- `IXDD604` minimum pulse width and first pulse after a high-impedance window are `OPEN` in its datasheet (CAD acceptance 2.9). The shortest pulse asked for is 107 ns (`FS_COMB_FINE`, fine grid) or 100 ns (100 ns grid); the low-loss profiles ask for 200 ns and 400 ns. The three-level pattern's shortest state is the 1/6-period zero: 1.04 µs at 160 kHz.
- DMA throughput with transmit ring and capture running together. The patterns now build for the 100 ns grid (5 M words/s); the loader that sets the divider is not written.
- Three-level amplitude control (a conduction angle other than 120°) and several three-level tones at once are not written.
- The 160 kHz three-level line at 240 kHz has not been put through CAD's network model.
- Rev G: `haptic_tx` variants for 16 and 20 pins, a 9-part `AD7380` reader, and `FS_CHANNELS` 18 are not written. The plan above is arithmetic, not code.
- Where the SMI reader lives once a lamina has a drive MCU and a receive MCU.
- Shocklets and time reversal in the chamber: generators only.
