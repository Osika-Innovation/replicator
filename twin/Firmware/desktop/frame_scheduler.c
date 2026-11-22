#include "frame_scheduler.h"
#include <math.h>

fs_config fs_default_config(void) {
    fs_config c = { 80, 4, DR_GOLOMB_BAND_LO_HZ, DR_GOLOMB_BAND_HI_HZ, 16, FS_GRID_FINE_TICKS };
    return c;
}

fs_config fs_profile_config(fs_comb_profile p, uint16_t step_ticks) {
    fs_config c = fs_default_config();
    unsigned shift = p == FS_COMB_LOWEST_LOSS ? 2u : (p == FS_COMB_LOW_LOSS ? 1u : 0u);
    c.step_ticks = step_ticks == FS_GRID_100NS_TICKS ? FS_GRID_100NS_TICKS : FS_GRID_FINE_TICKS;
    c.hold_ticks = (uint16_t)((c.step_ticks == FS_GRID_100NS_TICKS ? 15u : 16u) << shift);
    return c;
}

static unsigned step_ticks(const fs_config *c) { return c->step_ticks ? c->step_ticks : 1u; }
// The comb pulse in steps: at least one.
static size_t hold_steps(const fs_config *c) { unsigned h = c->hold_ticks / step_ticks(c); return h ? h : 1u; }
size_t fs_ring_steps(const fs_config *c) { return DR_TX_RING_TICKS / step_ticks(c); }

float fs_cf_duty(const fs_config *c) { return 1.0f - (float)c->fm_rings / (float)c->rings_per_frame; }

void fs_init(fs_state *s, const fs_config *c, const fs_hal *hal) {
    s->cfg = *c; s->hal = hal; s->ring = 0; s->armed_level_q15 = 0; s->fault = false;
}

fs_slot fs_slot_at(const fs_config *c, uint32_t ring) {
    return (ring % c->rings_per_frame) >= (uint32_t)(c->rings_per_frame - c->fm_rings) ? FS_SLOT_FM : FS_SLOT_CF;
}

fs_result fs_gate(const fs_state *s, uint16_t level_q15) {
    if (s->fault) return FS_FAULT_LATCHED;
    if (level_q15 > 32767) return FS_REFUSED_LEVEL;
    if (level_q15 <= FS_LISTEN_LEVEL_Q15) return FS_OK;
    // Above listen level: only with the head down. A missing interlock
    // reader counts as an open interlock.
    if (!s->hal || !s->hal->interlock_asserted || !s->hal->interlock_asserted()) return FS_REFUSED_INTERLOCK;
    return FS_OK;
}

fs_result fs_arm(fs_state *s, uint16_t level_q15) {
    fs_result r = fs_gate(s, level_q15);
    if (r == FS_OK) s->armed_level_q15 = level_q15;
    return r;
}

fs_slot fs_tick(fs_state *s) {
    if (s->armed_level_q15 > FS_LISTEN_LEVEL_Q15 &&
        !(s->hal && s->hal->interlock_asserted && s->hal->interlock_asserted())) {
        if (s->hal && s->hal->tx_enable) s->hal->tx_enable(false);
        if (s->hal && s->hal->lasers_off) s->hal->lasers_off();
        s->armed_level_q15 = 0; s->fault = true;
    }
    s->ring++;
    return fs_slot_at(&s->cfg, s->ring);
}

fs_result fs_rx_window(fs_state *s, bool open) {
    if (!open && s->fault) return FS_FAULT_LATCHED;
    if (s->hal && s->hal->tx_enable) s->hal->tx_enable(!open);
    return FS_OK;
}

fs_result fs_clear_fault(fs_state *s) {
    if (!(s->hal && s->hal->interlock_asserted && s->hal->interlock_asserted())) return FS_REFUSED_INTERLOCK;
    s->fault = false;
    return FS_OK;
}

// First-order error feedback to {-1, 0, +1} (0 = both bridge legs low), one decision per hold_ticks.
typedef struct { float e; } quant;
static int quantise(quant *q, float v) {
    float u = v + q->e;
    int out = u > 0.5f ? 1 : (u < -0.5f ? -1 : 0);
    q->e = u - (float)out;
    return out;
}
static void put(uint16_t *steps, size_t at, size_t n, size_t limit, int ch, int out) {
    if (out == 0) return;                                        // zero: both legs stay low
    uint16_t bits = (uint16_t)(out > 0 ? FS_STEP_INA(ch) : FS_STEP_INB(ch));
    for (size_t i = at; i < at + n && i < limit; i++) steps[i] |= bits;
}

uint16_t fs_comb_pattern(const fs_config *c, int ch, int n_tones, const float *hz, const int16_t *re, const int16_t *im,
                         uint16_t *steps, size_t n_steps) {
    float peak = 0;
    for (int k = 0; k < n_tones; k++) peak += sqrtf((float)re[k] * re[k] + (float)im[k] * im[k]);
    if (peak > 32767.0f) return 0;
    quant q = { 0 };
    const double step = (double)step_ticks(c) / DR_SYS_CLK_HZ;
    const size_t hold = hold_steps(c);
    for (size_t i = 0; i < n_steps; i += hold) {
        double t = ((double)i + 0.5 * (double)hold) * step;      // the middle of the held pulse
        float v = 0;
        for (int k = 0; k < n_tones; k++) {
            double a = 2.0 * 3.14159265358979323846 * hz[k] * t;
            v += (float)(re[k] * cos(a) - im[k] * sin(a));
        }
        put(steps, i, hold, n_steps, ch, quantise(&q, v / 32768.0f));
    }
    return (uint16_t)(peak + 0.5f);
}

uint16_t fs_three_level_pattern(const fs_config *c, int ch, float hz, float phase_turns, uint16_t *steps, size_t n_steps) {
    const double turns_per_step = (double)hz * (double)step_ticks(c) / DR_SYS_CLK_HZ;
    if (!(turns_per_step > 0.0) || turns_per_step > 1.0 / 12.0) return 0;
    for (size_t i = 0; i < n_steps; i++) {
        double x = ((double)i + 0.5) * turns_per_step + (double)phase_turns;
        x -= floor(x);                                           // phase in turns, [0, 1)
        // cos > 0.5 within 1/6 turn of 0; cos < -0.5 within 1/6 turn of 1/2
        int out = (x < 1.0 / 6.0 || x > 5.0 / 6.0) ? 1 : ((x > 1.0 / 3.0 && x < 2.0 / 3.0) ? -1 : 0);
        put(steps, i, 1, n_steps, ch, out);
    }
    return 32767;
}

double fs_fm_chirp_phase(const fs_config *c, double t, double T) {
    // Hyperbolic FM (linear period): f(t) = f0 f1 T / (f1 T - (f1 - f0) t).
    double f0 = c->fm_lo_hz, f1 = c->fm_hi_hz, k = (f1 - f0) / (f1 * T);
    return -(f0 / k) * log(1.0 - k * t);
}

void fs_fm_chirp_pattern(const fs_config *c, int ch, uint16_t level_q15, uint16_t *steps, size_t n_steps) {
    quant q = { 0 };
    const double step = (double)step_ticks(c) / DR_SYS_CLK_HZ, T = (double)n_steps * step;
    const size_t hold = hold_steps(c);
    float a = (float)level_q15 / 32768.0f;
    for (size_t i = 0; i < n_steps; i += hold) {
        double ph = fs_fm_chirp_phase(c, ((double)i + 0.5 * (double)hold) * step, T);
        put(steps, i, hold, n_steps, ch, quantise(&q, a * (float)cos(2.0 * 3.14159265358979323846 * ph)));
    }
}

void fs_pack_ring(const uint16_t *steps, size_t n_steps, uint32_t *words) {
    for (size_t i = 0; i + 1 < n_steps; i += 2) words[i / 2] = (uint32_t)(steps[i] & 0xFFFu) | ((uint32_t)(steps[i + 1] & 0xFFFu) << 12);
}
