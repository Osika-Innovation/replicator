// Spinal bus: the shared clock, the SYNC downbeat and the phasor packets
// that cross the three field PCBs (INS-03).
//
// XIN.  One 12.000 MHz oscillator on the base backplane fans out as a star
//       to the XIN pin of all six RP2350B. Each multiplies it to 150 MHz
//       (VCO 1500 MHz, /5 /2), so the six system clocks have the same
//       frequency exactly and a phase offset that is fixed after lock. The
//       offset is a multiple of the VCO period (0.667 ns), unknown per power-up.
// SYNC. One line, driven by the backplane MCU, on GPIO16 of every board.
//       Every PIO program waits for its rising edge. The star's trace
//       mismatch must stay under 2 ns (a layout rule: about 300 mm of trace);
//       what firmware sees is quantised to one 6.67 ns tick (0.38 degrees at
//       160 kHz), and that fixed residue is part of what calibration measures.
// Bus.  spinal_bus.pio: 75 Mbit/s, packets of 32-bit words:
//         [0] 0x5B | type << 8 | source << 16 | count << 24
//         [1] downbeat: frames since SYNC
//         [2 ... 2 + count)  phasors, int16 re | int16 im << 16
//         [2 + count]  CRC-32 of the words before it
#ifndef SPINAL_BUS_H
#define SPINAL_BUS_H
#include <stddef.h>
#include <stdint.h>

#define SB_MAGIC 0x5Bu
#define SB_MAX_PHASORS 255
#define SB_SYNC_GPIO 16
#define SB_BIT_PAIR_TICKS 4

typedef enum { SB_DRIVE = 1, SB_RECORD = 2, SB_SMI = 3, SB_STATUS = 4 } sb_type;
typedef struct { int16_t re, im; } sb_phasor;
typedef struct { uint8_t type, source, count; uint32_t downbeat; sb_phasor phasor[SB_MAX_PHASORS]; } sb_packet;
typedef enum { SB_OK = 0, SB_SHORT, SB_BAD_MAGIC, SB_BAD_CRC } sb_result;

uint32_t sb_crc32(const uint32_t *words, size_t n);
// Words for spinal_tx: out[0] is the length prefix (bit pairs - 1), then the
// packet. Returns the number of words written (count + 4).
size_t sb_encode(const sb_packet *p, uint32_t *out);
// `words`: a packet as spinal_rx pushed it (no length prefix).
sb_result sb_decode(const uint32_t *words, size_t n, sb_packet *p);
float sb_bit_rate(float sys_clk_hz);

// Point every `wait gpio` of a PIO program at SYNC for a PIO block whose GPIO
// base is `gpio_base` (0 or 16). Returns how many instructions were changed.
int sb_sync_patch(uint16_t *program, size_t n, unsigned gpio_base);

// On the board only (SB_ON_DEVICE, pico-sdk 2.x). Not compiled on the host.
void sb_clock_init_xin(void);          // XIN 12.000 MHz -> clk_sys 150 MHz
void sb_sync_init(int master);         // SYNC pin: output on the backplane MCU, input elsewhere
void sb_sync_downbeat(void);           // master: one rising edge; every waiting state machine starts
#endif
