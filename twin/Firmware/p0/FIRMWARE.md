# P0 controller firmware

| File | What | Tested how |
|---|---|---|
| `fcore.c`, `fcore.h` | wire parser, pulse-width patterns, record encoder: everything that touches no pin | on a computer, against the emulated machine over a pipe (`fieldc p0 link`, G-HW1–3) |
| `sim_main.c` | pins, converter and microphone simulated | part of that test |
| `pico_main.c`, `p0.pio`, `boards/p0_rp2350b.h` | PIO drive, DMA ring, ADC lock-in, TMP117, USB serial | **compiled only** |

## Build (2026-11-12)

`PICO_SDK_PATH=… PICO_TOOLCHAIN_PATH=… ./build.sh` — compiling never touches a board.

| | |
|---|---|
| Target | RP2350B (QFN-80), `rp2350-arm-s`, board header `boards/p0_rp2350b.h` (generic: GPIO0–31, 32/33 and 40 free; 4 MB flash declared) |
| SDK | raspberrypi/pico-sdk tag 2.1.1, commit `bddd20f928ce76142793bef434d4f75f4af6e433`, with its `lib/tinyusb` submodule |
| Compiler | Arm GNU Toolchain 14.2.Rel1 `arm-none-eabi` for macOS arm64 (developer.arm.com; archive sha256 `c7c78ffa…0a3818`). Homebrew's `arm-none-eabi-gcc` formula has no C library and fails |
| Result | no warnings in `pico_main.c` or `fcore.c` at `-Wall -Wextra` |
| Artifact | `artifacts/p0-rp2350b.uf2`, 74,752 bytes, sha256 `802ff165d09037291e89199c06fcaf67a6f18771d9a971ba60cec7c2bf57d820` |
| Reproducibility | same inputs give the same code; the SDK embeds the build date, so the hash changes from day to day |

**Resources:** 37,156 bytes of flash (text + read-only data) of 4 MB; 59,364
bytes of zero-initialised RAM of 520 kB — the converter's sample buffer
32 kB, the reply buffer 20 kB, the pattern ring 2 kB. No heap use of its own.

## Timing the design rests on (DERIVED from the code, not measured)

| Quantity | Value | Constraint |
|---|---|---|
| Pattern step rate | 512 × tone = 20.48 MHz at 40 kHz | system clock 150 MHz ÷ 7.32: a fractional divider, so step edges jitter by one system cycle (6.7 ns, 0.1° at 40 kHz) |
| DMA | one 32-bit word per step, endless, ring of 2 kB | must sustain 20.48 M transfers/s into the PIO FIFO (8 deep) |
| Phase step | 0.70° | calibration asked for ±5° |
| Amplitude | sin(π w / 512), w whole steps | 1–3 % steps at the job's drive; driver edges (25 ns typ) against 49 ns steps |
| Pattern change | 2 kB copied into the live ring, about 10 µs | up to one period (25 µs) plays a mix of old and new |
| Frame time base | microseconds since the stream began, `sleep_until` | a 40 ms move step is 1,600 periods |
| Listening | 500 kS/s on one input, 16,384 samples at most | a gate listens for at most 32.8 ms per frame; a 20 ms calibration dwell is 10,000 samples |
| Link | USB CDC; the host sends a whole stream, the board consumes it as it plays | a stream of more than 512 frames is refused (reply buffer) |

## Assumptions only a board can settle (numbered in `pico_main.c`)

1. A pattern copied into the live ring does not disturb the trap for longer than one period.
2. The DMA read address, read when sampling starts, gives the pattern phase with a latency common to all channels.
3. The converter free-runs at exactly 500 kS/s from the 48 MHz clock, coherent with the system clock.
4. The DMA count's top bits select the endless mode on this chip revision.
5. The pad's pull-up and pull-down together bias the receiver input near mid-rail, and the converter tolerates it.

Also open: that DMA keeps up at 20.48 MHz; the tone's frequency resolution
(the PIO divider has 8 fractional bits: steps of about 5 Hz at 40 kHz); the
board's actual flash size and whether its USB needs the separate adapter.

## For a few high-power channels (provisional)

The core is not tied to pulse-width drive of small transmitters. What a body
with a few strong piezo inputs changes is listed in
`../../Design/BODY_INTERFACE.md`; the wire format and `MachineBackend` do not change.
