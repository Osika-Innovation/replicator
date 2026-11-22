// Frame scheduler and drive interlock for a HAPTIC lamina (INS-07, INS-22).
//
// Time is counted in transmit rings (DR_TX_RING_TICKS = 125 us). A frame is
// 80 rings = 10 ms: 76 rings of constant-frequency comb hold (cf_duty 95 %)
// and 4 rings (500 us, one capture burst) of a hyperbolic FM micro-chirp for
// the broadband scan (fm_chirp, 5 %). The plate rings for about 1 ms after
// the comb stops, so the hold field has not gone when it returns.
//
// Drive is a ternary code per channel per step: +1, -1 or 0. On the pins
// that is (INA, INB) = (1,0), (0,1), (0,0): see FS_STEP_INA below. The
// driver is CAD's IXDD604 (cad/desktop-replicator/HAPTIC_FRONT_END.md).
//
// A step is cfg.step_ticks system ticks: 1 (6.67 ns, haptic_tx at clock
// divider 1) or 15 (100 ns, divider 15, the grid of CAD's HA0Drive model).
// Every pattern array below holds one entry per step, so a ring is 18750
// entries on the fine grid and 1250 on the 100 ns grid.
//
// The interlock: the Rev F head-down switch. Nothing above listen level is
// built, armed or left running unless the line reads asserted. Refusal is a
// result code, not a silent clamp.
#ifndef FRAME_SCHEDULER_H
#define FRAME_SCHEDULER_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "desktop_constants.h"

#define FS_CHANNELS 6
// Two pins per port, one per bridge leg of its IXDD604 (CAD #35):
//   +1 = INA high, INB low     -1 = INA low, INB high     0 = BOTH LOW
// Zero shorts the load through the two low sides. It is NOT high impedance:
// through the series inductor a Hi-Z zero free-wheels through the body
// diodes and brings the odd harmonics back. Both high is never emitted.
// High impedance is the shared group enable, a separate pin (fs_hal
// tx_enable): low only for receive windows, and on an interlock fault.
#define FS_STEP_INA(ch) (1u << (2 * (ch)))
#define FS_STEP_INB(ch) (1u << (2 * (ch) + 1))
#define FS_STEP_MASK(ch) (3u << (2 * (ch)))
// The code a step holds for a port: +1, -1 or 0.
static inline int fs_step_value(uint16_t step, int ch) {
    unsigned b = (step >> (2 * ch)) & 3u;
    return b == 1u ? 1 : (b == 2u ? -1 : 0);
}
// Listen level: -60 dB of full drive (ChordDrive.Verb.listen is 1e-3), Q15.
#define FS_LISTEN_LEVEL_Q15 33

typedef enum { FS_OK = 0, FS_REFUSED_INTERLOCK, FS_REFUSED_LEVEL, FS_REFUSED_DUTY, FS_FAULT_LATCHED } fs_result;
typedef enum { FS_SLOT_CF = 0, FS_SLOT_FM = 1 } fs_slot;

#define FS_GRID_FINE_TICKS 1u
#define FS_GRID_100NS_TICKS 15u

typedef struct {
    uint16_t rings_per_frame;       // 80
    uint16_t fm_rings;              // 4
    float fm_lo_hz, fm_hi_hz;       // the Golomb band
    uint16_t hold_ticks;            // shortest comb pulse, system ticks (16 = 107 ns); a multiple of step_ticks
    uint16_t step_ticks;            // system ticks per emitted step: 1 or 15
} fs_config;

// Comb pulse length. A longer pulse makes fewer edges, so less switching
// loss, and a larger tone error. Per port at 18 V into 4450 pF, hard-switched
// (README "Comb profiles"): 2.86 W, 1.38 W, 0.69 W.
typedef enum { FS_COMB_FINE = 0, FS_COMB_LOW_LOSS = 1, FS_COMB_LOWEST_LOSS = 2 } fs_comb_profile;

typedef struct {
    bool (*interlock_asserted)(void);       // head-down switch: true = chamber closed
    void (*tx_enable)(bool on);             // the shared bridge enable: false = every output high impedance, now
    void (*lasers_off)(void);
} fs_hal;

typedef struct {
    fs_config cfg;
    const fs_hal *hal;
    uint32_t ring;                  // rings since the SYNC downbeat
    uint16_t armed_level_q15;       // what is playing
    bool fault;                     // interlock opened while driving above listen level
} fs_state;

fs_config fs_default_config(void);
// The default with another pulse length and grid. On the fine grid the
// pulses are 16, 32, 64 ticks; on the 100 ns grid 15, 30, 60 (1, 2, 4 steps).
// step_ticks other than 1 or 15 gives the fine grid.
fs_config fs_profile_config(fs_comb_profile p, uint16_t step_ticks);
// Steps in one transmit ring on this grid.
size_t fs_ring_steps(const fs_config *c);
float fs_cf_duty(const fs_config *c);
void fs_init(fs_state *s, const fs_config *c, const fs_hal *hal);
fs_slot fs_slot_at(const fs_config *c, uint32_t ring);

// May a drive of this peak level (Q15 of full scale) play now?
fs_result fs_gate(const fs_state *s, uint16_t level_q15);
// Arm a drive: gate it, and remember its level for fs_tick().
fs_result fs_arm(fs_state *s, uint16_t level_q15);
// Once per ring. If the interlock has opened under a drive above listen
// level: enable low (Hi-Z), lasers off, fault latched. Returns the slot of
// the next ring.
fs_slot fs_tick(fs_state *s);
// A receive window: open = bridge enable low (every port high impedance, so
// the ports can be heard), close = enable high again. A code of 0 does not
// do this: it shorts the port. Closing is refused while a fault is latched.
fs_result fs_rx_window(fs_state *s, bool open);
// Only with the interlock asserted again.
fs_result fs_clear_fault(fs_state *s);

// A comb on one channel: v(t) = sum a_k cos(2 pi f_k t + phi_k), a in Q15 of
// full scale, quantised to the ternary code by first-order error feedback
// every hold_ticks. ORs the channel's bits into steps[0...n_steps).
// Returns the peak level (sum of a_k, Q15), or 0 if refused for level > 1.
uint16_t fs_comb_pattern(const fs_config *c, int ch, int n_tones, const float *hz, const int16_t *re_q15, const int16_t *im_q15,
                         uint16_t *steps, size_t n_steps);
// One tone at full drive as the three-level, 120 degree pattern (CAD #35):
// +1 where cos(2 pi f t + phase) > 0.5, -1 where it is < -0.5, else 0, read
// at the middle of each step. Each polarity conducts for a third of the
// period, so the third harmonic and its multiples are absent and the
// fundamental is (4/pi) cos 30 = 1.103 of the rail: 19.8 V at 18 V. Four
// edges per period and no reversals. This is full drive: gate it with
// fs_arm(s, 32767) first. Returns 32767, or 0 for a tone the grid cannot
// hold (fewer than 12 steps per period).
// A period that is not a whole number of steps (160 kHz is 62.5 steps of
// 100 ns) is not repeated exactly: the edges move by up to half a step from
// period to period and lines appear below the tone (README "Three-level").
uint16_t fs_three_level_pattern(const fs_config *c, int ch, float hz, float phase_turns, uint16_t *steps, size_t n_steps);
// Phase (turns) of the hyperbolic FM chirp at time t of a sweep lasting T.
double fs_fm_chirp_phase(const fs_config *c, double t, double T);
// The chirp on one channel at `level_q15`, same code and quantiser.
void fs_fm_chirp_pattern(const fs_config *c, int ch, uint16_t level_q15, uint16_t *steps, size_t n_steps);
// Two steps per ring word, first step in the low 12 bits (haptic_tx).
void fs_pack_ring(const uint16_t *steps, size_t n_steps, uint32_t *words);
#endif
