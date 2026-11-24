// Bench Gate 0: the first measurement on the empty closed chamber (INS-40).
//
// SIM #82: every 160 kHz lift figure rests on an ASSUMED end reflection of
// 0.88, and the lift at the peak of the gap resonance scales with it (0.65x
// bead weight at 0.70, 1.1-1.4x at 0.88, 2.2x for bare glass). The width of
// the axial resonance gives that number with one PZT, one receiver channel
// and no bead.
//
// The sweep: one port plays a single full-rail tone (the three-level
// pattern), stepped from 158 to 162 kHz; a port of ANOTHER enable group is
// held high impedance and read through its AD7380 channel. 201 points of
// 20 Hz, two frames each (the cavity rings up in about 3 ms): 4 s.
// The band holds five or six axial resonances, c / (2 gap) = 715 Hz apart.
//
// The estimate: the power response of a cavity with round-trip amplitude
// factor rho is the Airy comb, whose Fourier series over one resonance
// spacing is 1 + 2 sum rho^n cos(n x). So with C_n the n-th Fourier
// coefficient of the measured power over a whole number of spacings,
//     rho = |C1| / C0   and also   rho = |C2| / |C1|,
// the phase of C1 is where the resonance sits against the tone (what the
// resonance lock wants), and the full width at half maximum is
//     fwhm = fsr (2 / pi) asin((1 - rho) / (2 sqrt(rho))).
// A constant noise floor lowers the first figure and not the second; a
// response that is not one Airy comb (many duct modes, a slope from the
// transducer) separates them. The smaller is used, both are reported.
//
// From rho to an end reflection, two readings that do not agree exactly:
//   plane wave   rho = r^2 exp(-2 alpha gap), alpha = 0.69 Np/m at 160 kHz
//                (ISO 9613-1 form, 20 C, 50 % RH; DERIVED from memory of the
//                standard, to be checked);
//   SIM anchors  #82's widths in gap: 0.15 mm near-rigid, 0.25 mm = 0.88,
//                0.35 mm = 0.70, read on a 0.05 mm grid (SIMULATED).
// The gate (r_eff >= 0.85) passes when both say so, fails when neither does,
// and is MARGINAL between.
//
// Limits: magnitude only, so a coherent structural path from the driving
// port through the wafer bends the line shape (the points sent to the host
// carry re and im so a baseline can be removed there); one Airy comb for a
// chamber with 25 000 duct modes at 160 kHz; nothing has run on a board.
#ifndef BENCH_GATE0_H
#define BENCH_GATE0_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "frame_scheduler.h"

#define BG0_F_LO_HZ 158000.0f
#define BG0_F_HI_HZ 162000.0f
#define BG0_F_STEP_HZ 20.0f
#define BG0_POINTS 201
#define BG0_SETTLE_FRAMES 2
#define BG0_R_GATE 0.85f
#define BG0_ALPHA_NP_PER_M 0.69f

typedef enum {
    BG0_OK = 0, BG0_REFUSED_INTERLOCK, BG0_REFUSED_FAULT, BG0_REFUSED_PORTS, BG0_REFUSED_PLAN, BG0_NOT_RUNNING,
    BG0_SHORT, BG0_BAD_MAGIC, BG0_BAD_CRC, BG0_NO_RESONANCE
} bg0_result;
typedef enum { BG0_PASS = 0, BG0_MARGINAL = 1, BG0_FAIL = 2 } bg0_verdict;

typedef struct {
    float f_lo_hz, f_step_hz;
    uint16_t n;                  // points, at most BG0_POINTS
    uint8_t tx_port, rx_port;    // of FS_CHANNELS, in different enable groups
    uint8_t settle_frames;       // frames a tone plays before its point is read
} bg0_plan;

typedef struct {
    bg0_plan plan;
    uint16_t at;                 // the point being played
    uint8_t wait;                // frames left before it is read
    bool running, done;
    uint16_t rms_q1[BG0_POINTS]; // magnitude in half ADC counts, saturating (402 B)
} bg0_sweep;

typedef struct {
    float fsr_hz;                // resonance spacing found, c / (2 gap)
    float detune_hz;             // nearest resonance minus the tone, +-fsr/2
    float rho1, rho2, rho;       // |C1|/C0, |C2|/|C1|, the smaller
    float fwhm_hz, width_mm;     // of the power response; the same as gap at the tone
    float r_plane_wave, r_sim_anchor;
    uint16_t points_used;        // a whole number of spacings
    uint8_t periods;
    uint8_t verdict;             // bg0_verdict
} bg0_fit;

bg0_plan bg0_default_plan(void);
// Start: arms full drive through the scheduler's gate (head down, no fault)
// and opens the receive window of rx_port's enable group only.
bg0_result bg0_begin(bg0_sweep *w, const bg0_plan *p, fs_state *fs);
// The tone to play now on plan.tx_port (fs_three_level_pattern), Hz.
float bg0_frequency(const bg0_sweep *w);
// Once per frame while running. Returns true when the point is to be read
// this frame: capture the burst, lock in at bg0_frequency(), call bg0_record.
bool bg0_frame(bg0_sweep *w, const fs_state *fs);
// One point, the lock-in phasor in ADC counts (lk_adc_burst gives fractions
// of full scale: multiply by 32768). Moves to the next tone.
bg0_result bg0_record(bg0_sweep *w, float re, float im);
// End or abort: window closed, drive disarmed.
void bg0_end(bg0_sweep *w, fs_state *fs);

// The estimate from n magnitudes at f_lo + i f_step. gap_mm and c_ms are
// the nominal chamber: they place the search for the spacing (+-3 %) and
// convert widths. tone_hz is what detune is measured against.
bg0_result bg0_estimate(const uint16_t *rms_q1, size_t n, float f_lo_hz, float f_step_hz, float tone_hz,
                        float gap_mm, float c_ms, float alpha_np_per_m, bg0_fit *fit);
// The pieces, for tests and for the host.
float bg0_airy_fwhm_hz(float rho, float fsr_hz);
float bg0_r_plane_wave(float rho, float gap_mm, float alpha_np_per_m);
float bg0_r_sim_anchor(float width_mm);

// Over USB-C, little-endian, CRC-32 (IEEE, as HLEQ) closing each message:
//   start   "BG0S" u8 tx_port, u8 rx_port, u8 settle_frames, u8 0, f32 f_lo, f32 f_step, u16 n, u16 0, u32 crc   24 B
//   point   "BG0P" u16 index, u16 0, f32 hz, f32 re, f32 im, u32 crc                                              24 B
//   result  "BG0R" u16 points_used, u8 periods, u8 verdict, f32 fsr, detune, rho1, rho2, fwhm_hz, width_mm,
//           r_plane_wave, r_sim_anchor, u32 crc                                                                   44 B
#define BG0_START_BYTES 24
#define BG0_POINT_BYTES 24
#define BG0_RESULT_BYTES 44
bg0_result bg0_parse_start(const uint8_t *b, size_t n, bg0_plan *p);
size_t bg0_encode_start(const bg0_plan *p, uint8_t out[BG0_START_BYTES]);
size_t bg0_encode_point(uint16_t index, float hz, float re, float im, uint8_t out[BG0_POINT_BYTES]);
size_t bg0_encode_result(const bg0_fit *f, uint8_t out[BG0_RESULT_BYTES]);
#endif
