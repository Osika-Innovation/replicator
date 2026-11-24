# P0 parts research — read 2026-11-12

Web research for the P0 order pack. Every figure was read on the page cited on
the date above, except those marked *snippet* (search-result text; DigiKey,
Mouser, Farnell UK, TME and Octopart refused automated access) or NOT VERIFIED.
Prices and stock move: re-check on the day of ordering. Nothing was bought.

## Transmitter and receiver: Murata MA40S4S / MA40S4R

Datasheet DM-U16-483 Rev.2 (https://www.farnell.com/datasheets/3747890.pdf):

| | |
|---|---|
| Sound level (MA40S4S) | 120 ± 3 dB re 20 µPa at 40 kHz, 10 V rms sine, 30 cm |
| Sensitivity (MA40S4R) | −63 ± 3 dB re 10 V/Pa at 40 kHz (3.9 kΩ load) |
| Capacitance | 2,550 pF ± 20 % |
| Largest input (transmitter) | 20 V p-p, 40 kHz square wave, continuous |
| Life test | 24 V p-p square continuous, 1000 h, level within ±3 dB |
| Frequency | 40.0 kHz "for reference": no tolerance, no bandwidth, no Q stated. Read off Fig. 1: about −10 dB at 37.5 and 43.5 kHz |
| Body, pins | Ø9.9 ± 0.3 × 7.1 ± 0.3 mm; two pins Ø0.64, pitch 5.0 ± 0.3, 10 mm long |
| Temperature | −40 to +85 °C, level within ±3 dB |

**Lifecycle: not recommended for new designs.** Murata's open-structure page asks
that the series not be used in new models; no successor is named
(https://www.murata.com/en-us/products/sensor/ultrasonic/overview/lineup/open).

| Seller | Part | Stock | Price (1 / 10 / 100) | Source |
|---|---|---|---|---|
| Newark | MA40S4S (52R3632) | 8 | $6.05 / 5.82 / 5.18 | https://www.newark.com/search?st=MA40S4 |
| Newark | MA40S4R (52R3631) | not stocked | $6.31 / 5.52 / 4.92 | same |
| LCSC | MA40S4S (C1519281) | 0 | $7.45 / 6.49 / 5.41 | https://www.lcsc.com/product-detail/Ultrasonic-Receivers-Transmitters_Murata-Electronics_C1519281.html |
| DigiKey | MA40S4S | *snippet*: 2,700–4,500, about $5.8–8.9 at 1, "not for new designs" | NOT VERIFIED | https://www.digikey.com/en/products/detail/murata-electronics/MA40S4S/4358147 |
| Mouser | MA40S4S | *snippet*: 224, €5.69 at 1, 26-week lead | NOT VERIFIED | https://www.mouser.com/ProductDetail/Murata-Electronics/MA40S4S |

## Alternates, 40 kHz

Levels at 10 V rms, 30 cm.

| Part | Size | Level | Limits | Price (1 / 10 / 100), stock | Source |
|---|---|---|---|---|---|
| Multicomp Pro MCUST10P40B07RO | Ø9.9 | 106 dB min | 40.1 ± 1 kHz; 2,500 pF ± 25 %; max volts not given | $3.12 / 2.71 / 2.24; 223 | https://www.newark.com/multicomp-pro/mcust10p40b07ro/transmitter-40khz-10mm-plastic/dp/17X2024 |
| Pro-Wave 400ST100 | Ø9.7 × 6.7 | 112 dB min | 40.0 ± 1.0 kHz; bandwidth 2.5 kHz; 10 V rms max | $7.30 / 6.63 / 6.09; 40 | https://www.newark.com/prowave/400st100/transmitter-ultrasonic-40khz/dp/98K9172 |
| Pro-Wave 400ST120 | Ø12.7 × 8.8 | 115 dB min | bandwidth 2.0 kHz; 20 V rms max | $7.22 / 6.56 / 6.02; 164 | https://www.newark.com/prowave/400st120/transducer-ultrasonic-tx-40khz/dp/98K9173 |
| Pro-Wave 400ST160 | Ø16.2 × 12 | 120 dB min | bandwidth 2.0 kHz; 20 V rms max | $7.05 / 6.41 / 5.19; 4,088 | https://www.newark.com/prowave/400st160/transmitter-ultrasonic-40khz-16mm/dp/98K9174 |
| Manorshi MSO-P1040H07T | Ø10 | ≥115 dB (*snippet*) | 40 V p-p max (*snippet*) | Alibaba only, about $1 at 100; NOT VERIFIED | used by SonicSurface, Ultraino, TinyLev |

The TinyLev paper found the Murata the best 10 mm part; the Manorshi cost about
3 % of trapping force and showed a 14° standard deviation of phase between units.

## Catalog transmitters at the RH-1's tones (53–97 kHz, ≤ Ø10 mm)

**None, with one exception.** The only part found between 50 and 120 kHz in a
body of 10 mm or less is STEMiNC SMATR10H60X80: 60 ± 4 kHz, Ø10 × 8 mm,
aluminium, level listed as "100" with no unit or condition, 140 V p-p max,
1,000 pF, $31.50 per pair, 2 pairs in stock (https://steminc.com/PZT/en/ultrasonic-air-transducer-60-khz).
Same Sky's catalogue runs 23–58 kHz then 200–400 kHz; Multicomp 38–48 then
200–400 kHz; Pro-Wave's open type stops at 50 kHz. Everything else found at
58–112 kHz is 14–40 mm across. Not checked to a readable page: TDK, Knowles,
SensComp; Murata MA58MF14-7N (14 mm by its name).

## Drivers

| | TC4427A | MIC4127 |
|---|---|---|
| Supply | 4.5–18 V (abs. max 22) | 4.5–20 V (abs. max 24) |
| Peak output, resistance | 1.5 A; 7 Ω typ, 9 Ω max | 1.5 A; 6 Ω typ, 10 Ω max |
| Logic high / low | ≥ 2.4 V / ≤ 0.8 V over the whole supply range: a 3.3 V pin drives it | same |
| Rise / fall, delay | 25 ns typ; 30 ns typ | 13 / 15 ns typ; 37 / 40 ns typ |
| Packages | PDIP-8, SOIC-8 | SOIC-8 ePad, MSOP, DFN: no DIP |

Sources: https://ww1.microchip.com/downloads/en/DeviceDoc/20001423J.pdf, Microchip DS20006084B.
Stocked at Newark (https://www.newark.com/search?st=TC4427A): **TC4427AEPA** (PDIP-8,
92C6108) 480 in stock, $1.51 / 1.43 / 1.35; TC4427ACOA (SOIC-8) 657, $1.38 / 1.22 / 1.05.
TC4427ACPA is non-stock (250 minimum).

## Controller

Raspberry Pi Pico 2 (RP2350A): 26 pins on the headers, 3 ADC inputs, 12-bit,
500 kS/s; $5.75 at SparkFun. **Too few pins for 32 drives.**

RP2350B boards (48 GPIO, 8 ADC inputs on the chip):

| Board | Pins reachable | Price | Stock | Source |
|---|---|---|---|---|
| Olimex RP2350-PICO2-XXL | all 48 per manual and schematic (LED on GPIO25, SD card on GPIO9/10/11/24) | €9.00 | in stock | https://www.olimex.com/Products/MicroPython/PICO/PICO2-XXL/open-source-hardware |
| Waveshare Core2350B | 48 on four 2×8 headers (LED GPIO39; GPIO47 is PSRAM select on PSRAM variants) | 129 SEK incl. VAT | 21 | https://www.electrokit.com/en/core2350b-core-board-8mb |
| Solder Party RP2350 Stamp XL | "all 48" (not checked pin by pin) | $11.68 | 176 | https://lectronz.com/products/rp2350-stamp-xl |
| Pimoroni Pico Plus 2, PGA2350 | not all / not read | £12.90, £9.00 | out of stock | shop.pimoroni.com |

## Air temperature

Adafruit 4821 (TI TMP117): ±0.1 °C max from −20 to +50 °C, 0.0078 °C per step,
I²C 0x48–0x4B, $11.50, in stock (https://www.adafruit.com/product/4821; https://www.ti.com/lit/ds/symlink/tmp117.pdf).
Second source SparkFun SEN-15805, $16.95.

## Microphones for 40–100 kHz

* MEMS breakouts (Knowles SPH0641LU4H-1 on Elecrow CCB50641P, $12.50; Infineon
  IM73A135 kit, about €65): typical curves only above 15–20 kHz, 40 kHz on the
  flank of the acoustic resonance. **Relative readings only** (phase, nulls,
  maps), no pascals, no individual curve.
* The MA40S4R itself (−63 ± 3 dB re 10 V/Pa at 40 kHz) is the cheapest receiver
  with a stated sensitivity; SonicSurface scanned its field with an MA40S4S.
* Calibrated: GRAS 46BE ¼" set (±2 dB to 80 kHz, to 160 dB) or 46DD ⅛"; B&K 4939
  (4 Hz–100 kHz ± 2 dB, individual chart supplied). Quote only.

## What the open designs use (DOCUMENTED, not ours)

| | SonicSurface | Ultraino | TinyLev |
|---|---|---|---|
| Transducers | 256 × Manorshi MSO-P1040H07T | 10 mm 40 kHz, Murata or Manorshi | 72 × Manorshi |
| Drivers, controller | 128 × MIC4127, 32 × 74HC595, Cyclone IV FPGA | 32 × TC4427A, Arduino Mega | L298N module, Arduino Nano |
| Drive | rail 6–16 V, tested at 9 V | square wave to 17 V p-p | 7–12 V supply, push-pull |
| Channels, phase steps | 256; 32 per period | 64; 10 per period | 2; 24 per period |
| Reported | two opposed boards give 3-D traps; no pascals | a 2 mm polystyrene particle, one-sided | solids to 3.9 g/cm³ at 10 W input |

Sources: github.com/upnalab/SonicSurface (BOM.txt), github.com/asiermarzo/Ultraino,
instructables.com/Acoustic-Levitator, Rev. Sci. Instrum. 88, 085105 (2017).
Both build guides say not to trust the polarity mark on a transducer: test each.

## Small items

| Item | Listing | Price, stock | Source |
|---|---|---|---|
| Solderable board | Adafruit Perma-Proto full size, 3-pack (590): 60 rows, 15 DIP-8 each | $19.95, in stock | https://www.adafruit.com/product/590 |
| DIP-8 sockets | Adafruit 2202, pack of 3 | $0.75 | https://www.adafruit.com/product/2202 |
| 100 nF ceramic | Adafruit 753, pack of 10 | $1.95 | https://www.adafruit.com/product/753 |
| 10 µF electrolytic 25 V | SparkFun COM-00523 | $0.55 | https://www.sparkfun.com/electrolytic-decoupling-capacitors-10uf-25v.html |
| M4 threaded rod 300 mm, stainless | McMaster 94185A581 | price NOT VERIFIED | https://www.mcmaster.com/product/94185A581/ |
| M4 nuts, 50 | ProtoSupplies | $2.65 | https://protosupplies.com/product/m4-hex-nut-ss-50-pack/ |
| Supply, 5–15 V selectable, 3 A | SparkFun TOL-19898 (polarity not stated) | $24.95 | https://www.sparkfun.com/products/19898 |
| Barrel jack to terminals | SparkFun PRT-10288 | $3.75 | https://www.sparkfun.com/dc-barrel-jack-adapter-female.html |
| Polystyrene beads Ø1.5–2 mm | Ecclestons micro-bead, 5 cu ft bag, UK delivery only | £27.77 | https://www.ecclestons.com/product/micro-bead-polystyrene-5-cu-ft-bag/ |

Not found: an M4 washer listing; a small quantity of Ø1–2 mm beads from a
catalogue seller; a fixed 15 V supply.
