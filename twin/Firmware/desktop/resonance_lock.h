// Axial resonance lock: hold gap / c constant (INS-40, SIM #79 and #82).
//
// The 160 kHz lift at r = 120 mm is a resonance of the 240 mm gap: peak over
// trough 4.7-4.9x across half a wavelength (1.07 mm), and 80 % of the lift
// needs the gap within +-0.07 mm or the mean air within +-0.15 K. Holding
// gap / c at the value the drive was calibrated at restores full lift and
// keeps that drive valid. c grows as sqrt(T), so the gap must follow the air
// by gap / (2 T) = 0.41 mm per K at 240 mm and 20 C.
//
// The controller takes one of two observations and gives one bounded gap
// step per frame:
//   - LightRead (LM-1): the ray fit's (c_air, gap). Error = gap_ref c / c_ref - gap.
//   - a 1-port sweep (bench_gate0): where the resonance nearest the tone sits.
//     Error = gap (f_peak - tone) / tone. It sees gap / c only, which is
//     all the lock needs.
// It does not move anything: the caller passes the step to the gap actuator.
// That actuator is not designed (OPEN for CAD): travel, resolution and
// backlash below are ASSUMED and are configuration.
//
// Nothing here has run on a board.
#ifndef RESONANCE_LOCK_H
#define RESONANCE_LOCK_H
#include <stdbool.h>
#include <stdint.h>

typedef struct {
    float gap_ref_mm;        // the gap the drive was calibrated at (on the resonance)
    float c_ref_ms;          // the sound speed at that calibration
    float tone_hz;           // the lifting tone, 160 kHz
    float step_max_mm;       // largest move per frame: 0.02 mm
    float deadband_mm;       // no move for a smaller error (actuator resolution, ASSUMED 0.002 mm)
    float lock_tol_mm;       // in lock within this: 0.06 mm
    float lock_tol_k;        // and within this much air temperature: 0.15 K (0.0614 mm at 240 mm)
    float travel_mm;         // actuator travel each side of gap_ref (ASSUMED 0.6 mm: one resonance period)
    uint16_t stale_frames;   // an observation older than this is not acted on (100 frames = 1 s)
} rl_config;

typedef enum { RL_SRC_NONE = 0, RL_SRC_LIGHTREAD, RL_SRC_SWEEP } rl_source;
typedef enum {
    RL_LOCKED = 0,           // inside both tolerances; the step may still be a small correction
    RL_SLEWING,              // outside a tolerance and moving toward it
    RL_NO_OBSERVATION,       // nothing measured since init or since the head was last up
    RL_STALE,                // the last observation is too old
    RL_REFUSED_INTERLOCK,    // head up: there is no cavity, and the gap after a lift is unknown
    RL_REFUSED_VALUE,        // an observation that cannot be a chamber (not finite, out of range)
    RL_TRAVEL_LIMIT          // out of lock and the actuator is at the end of its travel
} rl_result;

typedef struct {
    rl_config cfg;
    float err_mm;            // target gap - gap, by the last observation less the steps since
    float c_ms, gap_mm;      // the last LightRead observation (0 from a sweep)
    float offset_mm;         // sum of the steps commanded: where the actuator is from gap_ref
    uint32_t frame, obs_frame, steps;
    uint8_t source;          // rl_source
    bool have, locked;
} rl_state;

rl_config rl_default_config(void);
void rl_init(rl_state *s, const rl_config *c);
// Sound speed of air at t_c (331.3 sqrt(1 + t / 273.15), dry air; DERIVED).
float rl_c_air(float t_c);
// d gap / d T that holds gap / c: gap_ref / (2 T). 0.409 mm/K at 240 mm, 20 C.
float rl_mm_per_k(const rl_config *c);
// The gap that keeps gap / c at the calibrated value for this sound speed.
float rl_target_gap_mm(const rl_config *c, float c_ms);
// Half a wavelength of the tone: the gap period of the resonance (1.072 mm).
float rl_resonance_period_mm(const rl_config *c);

// A LightRead fit. Refused unless finite, 300 < c < 380 m/s, gap within 2 mm of gap_ref.
rl_result rl_observe_lightread(rl_state *s, float c_ms, float gap_mm);
// A sweep: the resonance nearest the tone peaks at tone + detune_hz, and the
// resonances are fsr_hz apart. The detune is folded into +-fsr/2. Refused
// unless finite and fsr within 10 % of c_ref / (2 gap_ref).
rl_result rl_observe_sweep(rl_state *s, float detune_hz, float fsr_hz);
// Once per frame. *step_mm is the gap move to command now (positive = wider),
// never more than step_max_mm, zero unless the result is RL_LOCKED or
// RL_SLEWING. With the head up the observation is dropped.
rl_result rl_step(rl_state *s, bool head_down, float *step_mm);
// The error as air temperature: err_mm / rl_mm_per_k.
float rl_error_k(const rl_state *s);
#endif
