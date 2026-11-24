#include "bench_gate0.h"
#include <math.h>
#include <string.h>
#include "cadence_sparse_q8.h"   // hleq_crc32: byte-wise IEEE CRC-32

static const float TWO_PI = 6.28318530717958647692f;

bg0_plan bg0_default_plan(void) {
    bg0_plan p = { BG0_F_LO_HZ, BG0_F_STEP_HZ, BG0_POINTS, 0, 1, BG0_SETTLE_FRAMES };
    return p;
}

static bool plan_ok(const bg0_plan *p, const fs_config *c) {
    if (!(p->n >= 16 && p->n <= BG0_POINTS) || p->settle_frames == 0) return false;
    if (!isfinite(p->f_lo_hz) || !isfinite(p->f_step_hz) || !(p->f_lo_hz > 0) || !(p->f_step_hz > 0)) return false;
    // the three-level pattern needs 12 steps per period at the top of the sweep
    float hi = p->f_lo_hz + p->f_step_hz * (float)(p->n - 1);
    return hi * (float)(c->step_ticks ? c->step_ticks : 1u) / (float)DR_SYS_CLK_HZ <= 1.0f / 12.0f;
}

bg0_result bg0_begin(bg0_sweep *w, const bg0_plan *p, fs_state *fs) {
    w->running = false; w->done = false; w->at = 0;
    if (!plan_ok(p, &fs->cfg)) return BG0_REFUSED_PLAN;
    // A port of a driving group is loaded by its bridge and cannot be heard.
    if (p->tx_port >= FS_CHANNELS || p->rx_port >= FS_CHANNELS || fs_port_group(p->tx_port) == fs_port_group(p->rx_port)) return BG0_REFUSED_PORTS;
    fs_result a = fs_arm(fs, 32767);
    if (a == FS_FAULT_LATCHED) return BG0_REFUSED_FAULT;
    if (a != FS_OK) return BG0_REFUSED_INTERLOCK;
    if (fs_rx_window_group(fs, (uint8_t)(1u << fs_port_group(p->rx_port)), true) != FS_OK) { fs_arm(fs, 0); return BG0_REFUSED_PORTS; }
    w->plan = *p; w->wait = p->settle_frames; w->running = true;
    memset(w->rms_q1, 0, sizeof w->rms_q1);
    return BG0_OK;
}

float bg0_frequency(const bg0_sweep *w) { return w->plan.f_lo_hz + w->plan.f_step_hz * (float)w->at; }

bool bg0_frame(bg0_sweep *w, const fs_state *fs) {
    if (!w->running) return false;
    if (fs->fault || fs->armed_level_q15 == 0) { w->running = false; return false; }   // the head lifted: the sweep is void
    if (w->wait) w->wait--;
    return w->wait == 0;
}

bg0_result bg0_record(bg0_sweep *w, float re, float im) {
    if (!w->running) return BG0_NOT_RUNNING;
    float m = 2.0f * hypotf(re, im);
    w->rms_q1[w->at] = !(m >= 0) ? 0 : (m > 65535.0f ? 65535u : (uint16_t)(m + 0.5f));
    w->wait = w->plan.settle_frames;
    if (++w->at >= w->plan.n) { w->running = false; w->done = true; }
    return BG0_OK;
}

void bg0_end(bg0_sweep *w, fs_state *fs) {
    w->running = false;
    fs_rx_window_group(fs, (uint8_t)(1u << fs_port_group(w->plan.rx_port)), false);   // refused under a fault: stays Hi-Z
    fs_arm(fs, 0);
}

float bg0_airy_fwhm_hz(float rho, float fsr_hz) {
    if (!(rho > 0) || rho >= 1) return rho >= 1 ? 0 : fsr_hz;
    float a = (1.0f - rho) / (2.0f * sqrtf(rho));
    return a >= 1.0f ? fsr_hz : fsr_hz * (2.0f / 3.14159265358979f) * asinf(a);       // no half maximum below rho = 0.172
}

float bg0_r_plane_wave(float rho, float gap_mm, float alpha) {
    if (!(rho > 0)) return 0;
    float r = sqrtf(rho) * expf(alpha * gap_mm * 1e-3f);
    return r > 1.0f ? 1.0f : r;
}

float bg0_r_sim_anchor(float w) {
    float r = w <= 0.15f ? 0.99f : (w <= 0.25f ? 0.99f - (w - 0.15f) * 1.1f : 0.88f - (w - 0.25f) * 1.8f);
    return r < 0 ? 0 : r;
}

bg0_result bg0_estimate(const uint16_t *q, size_t n, float f_lo, float f_step, float tone, float gap_mm, float c_ms,
                        float alpha, bg0_fit *fit) {
    memset(fit, 0, sizeof *fit);
    if (n < 16 || !(gap_mm > 0) || !(c_ms > 0) || !(f_step > 0)) return BG0_REFUSED_PLAN;
    float peak = 0;
    for (size_t i = 0; i < n; i++) if ((float)q[i] > peak) peak = (float)q[i];
    if (!(peak > 0)) return BG0_NO_RESONANCE;
    const float fsr0 = 500.0f * c_ms / gap_mm, span = (float)n * f_step;
    float best = -1, b_fsr = 0, b_c0 = 0, b_re1 = 0, b_im1 = 0, b_re2 = 0, b_im2 = 0; size_t b_nw = 0; unsigned b_m = 0;
    for (int k = -30; k <= 30; k++) {
        float fsr = fsr0 * (1.0f + 0.001f * (float)k);
        unsigned m = (unsigned)(span / fsr);
        if (m < 2) return BG0_REFUSED_PLAN;                           // the sweep must hold two spacings
        size_t nw = (size_t)((float)m * fsr / f_step + 0.5f);
        if (nw > n) nw = n;
        size_t i0 = (n - nw) / 2;
        // rotor: theta_i = 2 pi (f_i - tone) / fsr
        float th = TWO_PI * (f_lo + (float)i0 * f_step - tone) / fsr, dth = TWO_PI * f_step / fsr;
        float cr = cosf(th), ci = sinf(th), sr = cosf(dth), si = sinf(dth);
        float c0 = 0, re1 = 0, im1 = 0, re2 = 0, im2 = 0;
        for (size_t i = 0; i < nw; i++) {
            float a = (float)q[i0 + i] / peak, y = a * a;
            c0 += y; re1 += y * cr; im1 -= y * ci;
            re2 += y * (cr * cr - ci * ci); im2 -= y * 2.0f * cr * ci;
            float t = cr * sr - ci * si; ci = cr * si + ci * sr; cr = t;
        }
        float score = hypotf(re1, im1) / c0;
        if (score > best) { best = score; b_fsr = fsr; b_c0 = c0; b_re1 = re1; b_im1 = im1; b_re2 = re2; b_im2 = im2; b_nw = nw; b_m = m; }
    }
    float m1 = hypotf(b_re1, b_im1);
    fit->fsr_hz = b_fsr; fit->points_used = (uint16_t)b_nw; fit->periods = (uint8_t)b_m;
    fit->rho1 = m1 / b_c0; fit->rho2 = m1 > 0 ? hypotf(b_re2, b_im2) / m1 : 0;
    fit->rho = fit->rho1 < fit->rho2 ? fit->rho1 : fit->rho2;
    if (!(fit->rho1 >= 0.05f)) { fit->verdict = BG0_FAIL; return BG0_NO_RESONANCE; }
    fit->detune_hz = -b_fsr * atan2f(b_im1, b_re1) / TWO_PI;
    fit->fwhm_hz = bg0_airy_fwhm_hz(fit->rho, b_fsr);
    fit->width_mm = fit->fwhm_hz * gap_mm / tone;
    fit->r_plane_wave = bg0_r_plane_wave(fit->rho, gap_mm, alpha);
    fit->r_sim_anchor = bg0_r_sim_anchor(fit->width_mm);
    bool a = fit->r_plane_wave >= BG0_R_GATE, b = fit->r_sim_anchor >= BG0_R_GATE;
    fit->verdict = (uint8_t)(a && b ? BG0_PASS : (a || b ? BG0_MARGINAL : BG0_FAIL));
    return BG0_OK;
}

// ------------------------------------------------------------------ wire
static void p16(uint8_t *o, uint16_t v) { o[0] = (uint8_t)v; o[1] = (uint8_t)(v >> 8); }
static void p32(uint8_t *o, uint32_t v) { p16(o, (uint16_t)v); p16(o + 2, (uint16_t)(v >> 16)); }
static void pf(uint8_t *o, float f) { uint32_t u; memcpy(&u, &f, 4); p32(o, u); }
static uint16_t g16(const uint8_t *b) { return (uint16_t)(b[0] | (b[1] << 8)); }
static uint32_t g32(const uint8_t *b) { return (uint32_t)g16(b) | ((uint32_t)g16(b + 2) << 16); }
static float gf(const uint8_t *b) { uint32_t u = g32(b); float f; memcpy(&f, &u, 4); return f; }
static size_t seal(uint8_t *o, size_t n) { p32(o + n - 4, hleq_crc32(o, n - 4)); return n; }

size_t bg0_encode_start(const bg0_plan *p, uint8_t o[BG0_START_BYTES]) {
    memcpy(o, "BG0S", 4); o[4] = p->tx_port; o[5] = p->rx_port; o[6] = p->settle_frames; o[7] = 0;
    pf(o + 8, p->f_lo_hz); pf(o + 12, p->f_step_hz); p16(o + 16, p->n); p16(o + 18, 0);
    return seal(o, BG0_START_BYTES);
}

bg0_result bg0_parse_start(const uint8_t *b, size_t n, bg0_plan *p) {
    if (n < BG0_START_BYTES) return BG0_SHORT;
    if (memcmp(b, "BG0S", 4) != 0) return BG0_BAD_MAGIC;
    if (g32(b + BG0_START_BYTES - 4) != hleq_crc32(b, BG0_START_BYTES - 4)) return BG0_BAD_CRC;
    bg0_plan q = { gf(b + 8), gf(b + 12), g16(b + 16), b[4], b[5], b[6] };
    if (b[7] != 0 || g16(b + 18) != 0 || q.n < 16 || q.n > BG0_POINTS || q.settle_frames == 0 ||
        !isfinite(q.f_lo_hz) || !isfinite(q.f_step_hz) || !(q.f_lo_hz > 0) || !(q.f_step_hz > 0)) return BG0_REFUSED_PLAN;
    *p = q;
    return BG0_OK;
}

size_t bg0_encode_point(uint16_t index, float hz, float re, float im, uint8_t o[BG0_POINT_BYTES]) {
    memcpy(o, "BG0P", 4); p16(o + 4, index); p16(o + 6, 0); pf(o + 8, hz); pf(o + 12, re); pf(o + 16, im);
    return seal(o, BG0_POINT_BYTES);
}

size_t bg0_encode_result(const bg0_fit *f, uint8_t o[BG0_RESULT_BYTES]) {
    memcpy(o, "BG0R", 4); p16(o + 4, f->points_used); o[6] = f->periods; o[7] = f->verdict;
    const float v[8] = { f->fsr_hz, f->detune_hz, f->rho1, f->rho2, f->fwhm_hz, f->width_mm, f->r_plane_wave, f->r_sim_anchor };
    for (int i = 0; i < 8; i++) pf(o + 8 + 4 * i, v[i]);
    return seal(o, BG0_RESULT_BYTES);
}
