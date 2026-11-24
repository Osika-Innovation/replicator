#include "resonance_lock.h"
#include <math.h>

rl_config rl_default_config(void) {
    rl_config c = { 240.0f, 343.2146f, 160000.0f, 0.02f, 0.002f, 0.06f, 0.15f, 0.6f, 100 };
    return c;
}

void rl_init(rl_state *s, const rl_config *c) {
    s->cfg = *c; s->err_mm = 0; s->c_ms = 0; s->gap_mm = 0; s->offset_mm = 0;
    s->frame = 0; s->obs_frame = 0; s->steps = 0; s->source = RL_SRC_NONE; s->have = false; s->locked = false;
}

float rl_c_air(float t_c) { return 331.3f * sqrtf(1.0f + t_c / 273.15f); }

// c = 331.3 sqrt(T / 273.15), so T = 273.15 (c / 331.3)^2 and d gap / d T = gap / (2 T).
float rl_mm_per_k(const rl_config *c) {
    float r = c->c_ref_ms / 331.3f;
    return c->gap_ref_mm / (2.0f * 273.15f * r * r);
}

float rl_target_gap_mm(const rl_config *c, float c_ms) { return c->gap_ref_mm * c_ms / c->c_ref_ms; }
float rl_resonance_period_mm(const rl_config *c) { return 500.0f * c->c_ref_ms / c->tone_hz; }
float rl_error_k(const rl_state *s) { return s->err_mm / rl_mm_per_k(&s->cfg); }

static float lock_tol(const rl_config *c) {
    float k = c->lock_tol_k * rl_mm_per_k(c);
    return k < c->lock_tol_mm ? k : c->lock_tol_mm;
}

static void observed(rl_state *s, float err_mm, rl_source src) {
    s->err_mm = err_mm; s->obs_frame = s->frame; s->source = (uint8_t)src; s->have = true;
}

rl_result rl_observe_lightread(rl_state *s, float c_ms, float gap_mm) {
    if (!isfinite(c_ms) || !isfinite(gap_mm) || !(c_ms > 300.0f && c_ms < 380.0f) ||
        !(fabsf(gap_mm - s->cfg.gap_ref_mm) <= 2.0f)) return RL_REFUSED_VALUE;
    s->c_ms = c_ms; s->gap_mm = gap_mm;
    observed(s, rl_target_gap_mm(&s->cfg, c_ms) - gap_mm, RL_SRC_LIGHTREAD);
    return RL_LOCKED;
}

rl_result rl_observe_sweep(rl_state *s, float detune_hz, float fsr_hz) {
    float fsr0 = 500.0f * s->cfg.c_ref_ms / s->cfg.gap_ref_mm;       // c / (2 gap), gap in mm
    if (!isfinite(detune_hz) || !isfinite(fsr_hz) || !(fabsf(fsr_hz - fsr0) <= 0.1f * fsr0)) return RL_REFUSED_VALUE;
    detune_hz -= fsr_hz * floorf(detune_hz / fsr_hz + 0.5f);         // the nearest resonance: +-fsr/2
    s->c_ms = 0; s->gap_mm = 0;
    // The resonance is above the tone when the cavity is short for this air: widen by gap * detune / tone.
    observed(s, s->cfg.gap_ref_mm * detune_hz / s->cfg.tone_hz, RL_SRC_SWEEP);
    return RL_LOCKED;
}

rl_result rl_step(rl_state *s, bool head_down, float *step_mm) {
    if (step_mm) *step_mm = 0;
    s->frame++;
    if (!head_down) { s->have = false; s->locked = false; s->source = RL_SRC_NONE; return RL_REFUSED_INTERLOCK; }
    if (!s->have) { s->locked = false; return RL_NO_OBSERVATION; }
    if (s->frame - s->obs_frame > s->cfg.stale_frames) { s->locked = false; return RL_STALE; }
    const rl_config *c = &s->cfg;
    float step = 0;
    if (fabsf(s->err_mm) > c->deadband_mm) {
        step = s->err_mm > c->step_max_mm ? c->step_max_mm : (s->err_mm < -c->step_max_mm ? -c->step_max_mm : s->err_mm);
        // the end of the actuator's travel
        if (s->offset_mm + step > c->travel_mm) step = c->travel_mm - s->offset_mm;
        if (s->offset_mm + step < -c->travel_mm) step = -c->travel_mm - s->offset_mm;
    }
    // Between observations the error is the last one less what has been moved since.
    s->offset_mm += step; s->err_mm -= step;
    if (step != 0) s->steps++;
    if (step_mm) *step_mm = step;
    s->locked = fabsf(s->err_mm) <= lock_tol(c);
    if (s->locked) return RL_LOCKED;
    return step == 0 ? RL_TRAVEL_LIMIT : RL_SLEWING;
}
