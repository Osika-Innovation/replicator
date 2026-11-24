// Broadband bursts: what the CW comb cannot do (INS-12).
//
//   ps_time_reversal()  one-bit Fink time reversal: play each channel's
//                       measured impulse response backwards, sign only. The
//                       bursts arrive together where the response was
//                       measured from.
//   ps_toroidal_pulse() one cycle from every port of a ring, delayed so the
//                       cycles meet at a point; azimuthal order m winds the
//                       delays round the ring (m = 0 a focus, m != 0 a null
//                       on the axis with the energy in a ring round it).
//
// A PZT-8 disc answers in 90-250 ns (thickness / sound speed), so a half
// cycle shorter than PS_MIN_HALF_TICKS is not played. Bursts are far above
// listen level: both builders go through the frame scheduler's interlock
// gate, and through a duty limit (1e-4 for cold debonding).
// Status: generators and their arithmetic are tested on the host. What the
// bursts do in the chamber is OPEN.
#ifndef PULSE_SHOCKLET_H
#define PULSE_SHOCKLET_H
#include "frame_scheduler.h"

#define PS_MIN_HALF_TICKS 38            // 250 ns at 6.67 ns per tick
#define PS_COLD_DUTY_MAX 1e-4f

typedef struct { float x, y, z; } ps_vec;

// Ticks each port waits so that all arrive at `target` together (sound speed
// c, m/s), plus m turns of the centre period wound round the ring by each
// port's azimuth about the z axis through `target`. Returns the longest delay.
uint32_t ps_ring_delays(const ps_vec *ports, int n, ps_vec target, float c, int order_m, float centre_hz, uint32_t *delay_ticks);

// One cycle (+ then -) of half_ticks each on every channel at its delay.
// repeat_ticks: the period at which the caller will repeat the burst (0 =
// once); refused if the duty exceeds max_duty.
fs_result ps_toroidal_pulse(const fs_state *gate, int n, const uint32_t *delay_ticks, uint32_t half_ticks,
                            uint32_t repeat_ticks, float max_duty, uint16_t *steps, size_t n_ticks);

// ir: n_ch impulse responses, n samples each, one sample per `ticks_per_sample`.
// Samples within dead_zone of zero play as off. The drive for sample i is
// the sign of ir[n - 1 - i].
fs_result ps_time_reversal(const fs_state *gate, int n_ch, const int16_t *ir, size_t n, uint32_t ticks_per_sample,
                           int16_t dead_zone, uint32_t repeat_ticks, float max_duty, uint16_t *steps, size_t n_ticks);
#endif
