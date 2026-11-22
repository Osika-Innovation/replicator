// Host tests for the Desktop Replicator firmware: everything that does not
// touch a pin. Build and run with ../run_host_tests.sh. Prints the measured
// numbers the README quotes.
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../cadence_sparse_q8.h"
#include "../desktop_constants.h"
#include "../frame_scheduler.h"
#include "../lockin_xor.h"
#include "../pulse_shocklet.h"
#include "../spinal_bus.h"

static int failed = 0, passed = 0;
#define CHECK(cond, ...) do { if (cond) passed++; else { failed++; printf("  FAIL %s:%d: ", __FILE__, __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)

static uint64_t rng_state = 0x9E3779B97F4A7C15ull;
static uint32_t rnd(void) { rng_state ^= rng_state << 13; rng_state ^= rng_state >> 7; rng_state ^= rng_state << 17; return (uint32_t)(rng_state >> 16); }
static double unit(void) { return (rnd() & 0xFFFFFF) / 16777216.0; }
static const double PI = 3.14159265358979323846;

// ------------------------------------------------------------------ lock-in
static double c_to_e_db(const lk_cpx *got, const double *re, const double *im, int n) {
    double sig = 0, err = 0;
    for (int k = 0; k < n; k++) {
        sig += re[k] * re[k] + im[k] * im[k];
        err += (got[k].re - re[k]) * (got[k].re - re[k]) + (got[k].im - im[k]) * (got[k].im - im[k]);
    }
    return 10 * log10(sig / (err > 0 ? err : 1e-300));
}

static void test_lockin(void) {
    printf("lock-in\n");
    // The nibble step of the sinc3 against three plain integrators.
    lk_cic s = { 0 }; uint32_t a = 0, b = 0, c = 0; int same = 1;
    for (int i = 0; i < 4000; i++) {
        unsigned nib = rnd() & 15u;
        for (int j = 0; j < 4; j++) { a += (nib >> j) & 1u; b += a; c += b; }
        lk_cic_nibble(&s, nib);
        if (s.a != a || s.b != b || s.c != c) same = 0;
    }
    CHECK(same, "sinc3 nibble update differs from bit-serial integrators");
    // A constant input of ones settles to R^3.
    lk_cic one = { 0 }; uint32_t y = 0;
    for (int i = 0; i < 12; i++) { lk_cic_nibble(&one, 15); if (i % 3 == 2) y = lk_cic_out(&one); }
    CHECK(y == LK_CIC_R * LK_CIC_R * LK_CIC_R, "sinc3 DC gain %u, expected %d", y, LK_CIC_R * LK_CIC_R * LK_CIC_R);

    // The square reference word against one made bit by bit.
    int ok = 1;
    for (int trial = 0; trial < 20000; trial++) {
        uint32_t ph = rnd() ^ (rnd() << 16), inc = (rnd() % 12000000u) + 1000u;
        for (int q = 0; q < 2; q++) {
            uint32_t want = 0;
            for (int i = 0; i < 32; i++) {
                uint32_t p = ph + (uint32_t)i * inc + (q ? 0 : 0x40000000u);
                if (!(p >> 31)) want |= 1u << i;
            }
            if (lk_square_word(ph, inc, q) != want) ok = 0;
        }
    }
    CHECK(ok, "square reference word differs from the bit-serial reference");

    // Five comb tones through a first-order 1-bit modulator on channel 3 of
    // an 8-channel capture; the other channels carry noise.
    for (int set = 0; set < 2; set++) {
        lk_tones t = { 5, { 0 } };
        const float desk[5] = DR_COMB_TONES_HZ, boro[5] = DR_BORO12_COMB_TONES_HZ;
        for (int k = 0; k < 5; k++) t.hz[k] = set ? boro[k] : desk[k];
        double re[5], im[5];
        for (int k = 0; k < 5; k++) { double amp = 0.06 + 0.08 * unit(), ph = 2 * PI * unit(); re[k] = amp * cos(ph); im[k] = amp * sin(ph); }
        size_t n_words = LK_CIC_WARMUP_NIBBLES + DR_BURST_WORDS;
        size_t n_xor = ((n_words + 7) / 8) * 8;
        uint32_t *raw = calloc(n_xor, sizeof *raw);
        double v = 0.3, fb = 1;
        for (size_t i = 0; i < 4 * n_xor; i++) {
            double x = 0;
            for (int k = 0; k < 5; k++) { double w = 2 * PI * t.hz[k] * (double)i / DR_SIGMA_DELTA_FS_HZ; x += re[k] * cos(w) - im[k] * sin(w); }
            v += x - fb;
            int bit = v >= 0; fb = bit ? 1 : -1;
            uint32_t byte = (rnd() & 0xF7u) | ((bit ? 0u : 1u) << 3);        // the reader records NOT comparator
            raw[i / 4] |= byte << (8 * (i % 4));
        }
        lk_cpx cic[5], xr[5];
        lk_cic_burst(raw, n_words, 3, DR_SIGMA_DELTA_FS_HZ, &t, 1, cic);
        lk_xor_burst(raw, n_xor, 3, DR_SIGMA_DELTA_FS_HZ, &t, 1, xr);
        double d_cic = c_to_e_db(cic, re, im, 5), d_xor = c_to_e_db(xr, re, im, 5);
        printf("  %s comb, 500 us burst: carrier-to-error sinc3+demix %.1f dB, xor+demix %.1f dB\n", set ? "boro12" : "desktop-200mm", d_cic, d_xor);
        CHECK(d_cic > 40, "sinc3 path carrier-to-error %.1f dB", d_cic);
        CHECK(d_xor > 20, "xor path carrier-to-error %.1f dB", d_xor);
        float dens = lk_ones_density(raw, n_words, 3, 1);
        CHECK(fabsf(dens - 0.5f) < 0.01f, "ones density of a zero-mean stream %.4f", dens);
        free(raw);
    }

    // De-mix alone: a fundamental polluted by exactly what a third and fifth
    // harmonic leak into a square reference.
    lk_tones t = { 5, { 32000, 64000, 96000, 128000, 160000 } };
    lk_cpx r[5] = { { 0.5f, 0.2f }, { 0, 0 }, { 0.3f, -0.6f }, { 0, 0 }, { -0.4f, 0.1f } };
    r[0].re += -r[2].re / 3 + r[4].re / 5; r[0].im += r[2].im / 3 + r[4].im / 5;
    lk_demix(&t, r);
    CHECK(fabsf(r[0].re - 0.5f) < 1e-6f && fabsf(r[0].im - 0.2f) < 1e-6f, "de-mix left %.6f %+.6fj", r[0].re, r[0].im);

    // AD7380 words: eight samples through the shift register and back.
    int16_t want[8], got[8]; uint32_t words[4] = { 0 };
    for (int ch = 0; ch < 8; ch++) want[ch] = (int16_t)(rnd() & 0xFFFF);
    for (int clk = 0; clk < 16; clk++) {                              // MSB first, shift left by 8 per clock
        uint32_t byte = 0;
        for (int ch = 0; ch < 8; ch++) byte |= (((uint16_t)want[ch] >> (15 - clk)) & 1u) << ch;
        words[clk / 4] = (words[clk / 4] << 8) | byte;
    }
    lk_adc_unpack(words, got);
    CHECK(memcmp(want, got, sizeof want) == 0, "AD7380 unpack");
    // ADC lock-in at 1.5 MSa/s over 500 us.
    {
        int16_t x[750]; double re[5], im[5];
        for (int k = 0; k < 5; k++) { double amp = 0.05 + 0.1 * unit(), ph = 2 * PI * unit(); re[k] = amp * cos(ph); im[k] = amp * sin(ph); }
        for (int i = 0; i < 750; i++) {
            double v = 0;
            for (int k = 0; k < 5; k++) { double w = 2 * PI * t.hz[k] * i / 1.5e6; v += re[k] * cos(w) - im[k] * sin(w); }
            x[i] = (int16_t)lrint(v * 32768.0);
        }
        lk_cpx z[5]; lk_adc_burst(x, 750, 1, 1.5e6f, &t, z);
        double d = c_to_e_db(z, re, im, 5);
        printf("  AD7380 path, 750 samples at 1.5 MSa/s: carrier-to-error %.1f dB (16-bit quantisation only)\n", d);
        CHECK(d > 80, "ADC path carrier-to-error %.1f dB", d);
    }
    lk_cpx one_stage = smi_tia_response(200000, 200, 20e6f, 1), two_stage = smi_tia_response(200000, 200, 20e6f, 2);
    double m1 = hypot(one_stage.re, one_stage.im), m2 = hypot(two_stage.re, two_stage.im);
    printf("  OPA320 x200 at 200 kHz: one stage %.3f, two stages %.3f of the DC gain\n", m1, m2);
    CHECK(m1 < 0.5 && m2 > 0.95, "two-stage receiver must hold the band where one stage does not");
}

// ------------------------------------------------------------------ cadence
static csq_net net;
static double overlap(const csq_c8 *s, const csq_c8 *p, int from, int to) {
    double num = 0, ss = 0, pp = 0;
    for (int i = from; i < to; i++) { num += s[i].re * p[i].re + s[i].im * p[i].im; ss += s[i].re * s[i].re + s[i].im * s[i].im; pp += p[i].re * p[i].re + p[i].im * p[i].im; }
    return ss > 0 ? num / sqrt(ss * pp) : 0;
}
static void test_cadence(void) {
    printf("sparse Cadence\n");
    csq_init(&net, 2, 3);
    while (net.n_blocks < CSQ_MAX_BLOCKS) csq_add_block(&net, (int)(rnd() % CSQ_NB), (int)(rnd() % CSQ_NB));
    csq_link(&net);
    float density = csq_density(&net);
    printf("  %zu bytes, %d stored blocks, block density %.1f %%\n", sizeof net, net.n_blocks, 100 * density);
    CHECK(sizeof net <= DR_CADENCE_SPARSE_MAX_BYTES, "size");
    CHECK(density >= DR_CADENCE_DENSITY_MIN && density <= DR_CADENCE_DENSITY_MAX + 1e-3f, "density %.3f outside 5-10 %%", density);
    CHECK(net.col_ptr[CSQ_NB] == CSQ_NB + 2 * (net.n_blocks - CSQ_NB), "links");

    enum { P = 3, CUE = CSQ_N / 2 };
    static csq_c8 pat[P][CSQ_N], s0[CSQ_N];
    for (int p = 0; p < P; p++) for (int i = 0; i < CSQ_N; i++) { pat[p][i].re = (rnd() & 1) ? 90 : -90; pat[p][i].im = (rnd() & 1) ? 90 : -90; }
    double before = 0, after = 0;
    for (int epoch = 0; epoch <= 12; epoch++) {
        double mean = 0;
        for (int p = 0; p < P; p++) {
            // Free phase: the first half of the pattern as the cue.
            csq_reset_state(&net);
            for (int i = 0; i < CSQ_N; i++) csq_set_input(&net, i, i < CUE ? pat[p][i].re : 0, i < CUE ? pat[p][i].im : 0);
            csq_relax(&net, 40);
            memcpy(s0, net.s, sizeof s0);
            mean += overlap(net.s, pat[p], CUE, CSQ_N) / P;
            if (epoch == 12) continue;
            // Nudged phase: the uncued half is pulled half way to the target.
            for (int i = CUE; i < CSQ_N; i++) csq_set_input(&net, i, (pat[p][i].re - s0[i].re) / 2, (pat[p][i].im - s0[i].im) / 2);
            csq_relax(&net, 40);
            csq_eqprop_update(&net, s0, 11);
            csq_renormalise(&net, 1.0f);
        }
        if (epoch == 0) before = mean;
        after = mean;
    }
    printf("  eqprop, %d patterns, cue = half the units: overlap on the uncued half %.2f before, %.2f after 12 epochs\n", P, before, after);
    CHECK(after > 0.8, "recall after learning %.2f", after);
    CHECK(csq_norm_bound(&net) <= 1.0f, "norm bound %.3f above 1", csq_norm_bound(&net));
    // Hermitian: the diagonal blocks are their own conjugate transpose.
    int herm = 1;
    for (int b = 0; b < CSQ_NB; b++) for (int r = 0; r < CSQ_B; r++) for (int c = 0; c < CSQ_B; c++)
        if (net.w[b][r][c].re != net.w[b][c][r].re || net.w[b][r][c].im != -net.w[b][c][r].im) herm = 0;
    CHECK(herm, "diagonal blocks are not Hermitian");
    // The settle budget of one recall.
    csq_reset_state(&net);
    for (int i = 0; i < CSQ_N; i++) csq_set_input(&net, i, i < CUE ? pat[0][i].re : 0, i < CUE ? pat[0][i].im : 0);
    int sweeps = csq_relax(&net, 40);
    uint32_t dense_pushes = (uint32_t)(sweeps + 1) * (uint32_t)net.col_ptr[CSQ_NB];
    printf("  one recall: %d sweeps, %u block pushes (every link every sweep would be %u)\n", sweeps, net.block_pushes, dense_pushes);
    printf("  settle at 150 MHz: %.1f ms at 1000 cycles per push, %.1f ms at 700\n", csq_settle_ms(&net, 1000, 150e6f), csq_settle_ms(&net, 700, 150e6f));
    CHECK(sweeps < 40, "relaxation did not settle");
    CHECK(net.block_pushes <= dense_pushes, "event-driven must not exceed dense");
}

// ---------------------------------------------------------------- scheduler
static bool head_down = false; static int hiz_calls = 0, laser_calls = 0;
static bool hal_interlock(void) { return head_down; }
static bool tx_on = true;
static void hal_hiz(bool on) { tx_on = on; if (!on) hiz_calls++; }
static void hal_lasers(void) { laser_calls++; }
static const fs_hal hal = { hal_interlock, hal_hiz, hal_lasers };

static void tone_of(const uint16_t *steps, size_t n, int ch, double hz, double *re, double *im) {
    double ar = 0, ai = 0;
    for (size_t i = 0; i < n; i++) {
        int v = fs_step_value(steps[i], ch);
        if (!v) continue;
        double w = 2 * PI * hz * ((double)i + 0.5) / DR_SYS_CLK_HZ;
        ar += v * cos(w); ai -= v * sin(w);
    }
    *re = 2 * ar / (double)n; *im = 2 * ai / (double)n;
}

static void test_scheduler(void) {
    printf("frame scheduler and interlock\n");
    fs_config cfg = fs_default_config(); fs_state st;
    fs_init(&st, &cfg, &hal);
    CHECK(fabsf(fs_cf_duty(&cfg) - 0.95f) < 1e-6f, "cf duty %.3f", fs_cf_duty(&cfg));
    int fm = 0; for (uint32_t r = 0; r < 8000; r++) fm += fs_slot_at(&cfg, r) == FS_SLOT_FM;
    CHECK(fm == 400, "FM rings %d of 8000", fm);
    CHECK(cfg.fm_rings * DR_TX_RING_TICKS / 2 == DR_BURST_SAMPLES, "the FM slot is one capture burst");

    head_down = false;
    CHECK(fs_gate(&st, FS_LISTEN_LEVEL_Q15) == FS_OK, "listen level must play with the head up");
    CHECK(fs_gate(&st, FS_LISTEN_LEVEL_Q15 + 1) == FS_REFUSED_INTERLOCK, "above listen level must be refused with the head up");
    CHECK(fs_arm(&st, 20000) == FS_REFUSED_INTERLOCK && st.armed_level_q15 == 0, "arm with the head up");
    fs_state none; fs_init(&none, &cfg, NULL);
    CHECK(fs_gate(&none, 20000) == FS_REFUSED_INTERLOCK, "no interlock reader is an open interlock");
    head_down = true;
    CHECK(fs_arm(&st, 20000) == FS_OK, "arm with the head down");
    fs_tick(&st); CHECK(!st.fault && hiz_calls == 0, "no fault while closed");
    head_down = false; fs_tick(&st);
    CHECK(st.fault && hiz_calls == 1 && laser_calls == 1 && st.armed_level_q15 == 0, "lifting the head under drive must Hi-Z and latch");
    CHECK(!tx_on && fs_rx_window(&st, false) == FS_FAULT_LATCHED && !tx_on, "a latched fault must keep the bridges high impedance");
    head_down = true;
    CHECK(fs_arm(&st, 20000) == FS_FAULT_LATCHED, "a latched fault refuses until cleared");
    head_down = false; CHECK(fs_clear_fault(&st) == FS_REFUSED_INTERLOCK, "no clear with the head up");
    head_down = true; CHECK(fs_clear_fault(&st) == FS_OK && fs_arm(&st, 20000) == FS_OK, "clear and re-arm");
    CHECK(fs_rx_window(&st, true) == FS_OK && !tx_on && fs_rx_window(&st, false) == FS_OK && tx_on, "a receive window is the enable going low and back");

    // The comb as the ternary code: each tone comes out at its commanded phasor.
    static uint16_t steps[DR_TX_RING_TICKS];
    memset(steps, 0, sizeof steps);
    const float hz[5] = DR_COMB_TONES_HZ;
    int16_t re[5], im[5]; double worst = 0;
    for (int k = 0; k < 5; k++) { double ph = 2 * PI * unit(); re[k] = (int16_t)(6000 * cos(ph)); im[k] = (int16_t)(6000 * sin(ph)); }
    uint16_t level = fs_comb_pattern(&cfg, 2, 5, hz, re, im, steps, DR_TX_RING_TICKS);
    for (int k = 0; k < 5; k++) {
        double gr, gi; tone_of(steps, DR_TX_RING_TICKS, 2, hz[k], &gr, &gi);
        double e = hypot(gr - re[k] / 32768.0, gi - im[k] / 32768.0) / (6000 / 32768.0);
        if (e > worst) worst = e;
    }
    printf("  5-tone comb, ternary code, %d-tick pulses: worst tone error %.1f %% over one 125 us ring; peak level %u\n", cfg.hold_ticks, 100 * worst, level);
    CHECK(worst < 0.05, "comb tone error %.3f", worst);
    // Edges of the code on a bridge whose zero is both legs low (a short): the
    // voltage across the port steps by V to or from zero and by 2 V on a reversal,
    // and a step of dV into C loses C dV^2 / 2 (hard-switched, no inductor).
    int edges = 0, reversals = 0, last = 0, on = 0, both_high = 0; double dv2 = 0;
    for (size_t i = 0; i < DR_TX_RING_TICKS; i++) {
        int now = fs_step_value(steps[i], 2);
        if ((steps[i] & FS_STEP_MASK(2)) == FS_STEP_MASK(2)) both_high++;
        if (now) on++;
        if (now != last) { edges++; dv2 += (now - last) * (now - last); if (now && last) reversals++; }
        last = now;
    }
    CHECK(both_high == 0, "the code set both legs high %d times", both_high);
    double ring_s = DR_TRANSMIT_RING_US * 1e-6, cv2 = DR_C0_NOMINAL_PF * 1e-12 * DR_BRIDGE_RAIL_V * DR_BRIDGE_RAIL_V;
    printf("  that code at 18 %% of full scale per tone: driven %.0f %% of the time, %d edges per ring (%d of them reversals);\n"
           "    zero = both legs low, hard-switched into %.0f pF at %.0f V: %.2f W per port (C dV^2 / 2 per edge, DERIVED, no inductor or ZVS credit)\n",
           100.0 * on / DR_TX_RING_TICKS, edges, reversals, (double)DR_C0_NOMINAL_PF, (double)DR_BRIDGE_RAIL_V, 0.5 * cv2 * dv2 / ring_s);
    // Longer pulses: fewer edges, more tone error.
    printf("    pulse length sweep (ticks: worst tone error, edges per ring, W per port):");
    static uint16_t sw[DR_TX_RING_TICKS];
    for (int hold = 16; hold <= 128; hold *= 2) {
        fs_config c2 = cfg; c2.hold_ticks = (uint16_t)hold;
        memset(sw, 0, sizeof sw); fs_comb_pattern(&c2, 2, 5, hz, re, im, sw, DR_TX_RING_TICKS);
        double w2 = 0, d2 = 0; int e2 = 0, l2 = 0;
        for (int k = 0; k < 5; k++) { double gr, gi; tone_of(sw, DR_TX_RING_TICKS, 2, hz[k], &gr, &gi); w2 = fmax(w2, hypot(gr - re[k] / 32768.0, gi - im[k] / 32768.0) / (6000 / 32768.0)); }
        for (size_t i = 0; i < DR_TX_RING_TICKS; i++) { int now = fs_step_value(sw[i], 2); if (now != l2) { e2++; d2 += (now - l2) * (now - l2); } l2 = now; }
        printf(" %d: %.1f %%, %d, %.2f;", hold, 100 * w2, e2, 0.5 * cv2 * d2 / ring_s);
    }
    printf("\n");
    int16_t big[5] = { 9000, 9000, 9000, 9000, 9000 }, zero[5] = { 0 };
    CHECK(fs_comb_pattern(&cfg, 0, 5, hz, big, zero, steps, DR_TX_RING_TICKS) == 0, "a comb over full scale must be refused");
    int others = 0; for (size_t i = 0; i < DR_TX_RING_TICKS; i++) others |= steps[i] & ~FS_STEP_MASK(2);
    CHECK(others == 0, "a channel's pattern touched another channel's pins");
    static uint32_t ring[DR_TX_RING_WORDS];
    fs_pack_ring(steps, DR_TX_RING_TICKS, ring);
    CHECK((ring[100] & 0xFFF) == steps[200] && ((ring[100] >> 12) & 0xFFF) == steps[201], "ring packing");

    // Hyperbolic FM: starts at the bottom of the band and ends at the top.
    double T = 500e-6, dt = 1e-9;
    double f_start = (fs_fm_chirp_phase(&cfg, dt, T) - fs_fm_chirp_phase(&cfg, 0, T)) / dt;
    double f_end = (fs_fm_chirp_phase(&cfg, T, T) - fs_fm_chirp_phase(&cfg, T - dt, T)) / dt;
    printf("  fm chirp: %.1f kHz -> %.1f kHz in 500 us\n", f_start / 1e3, f_end / 1e3);
    CHECK(fabs(f_start - cfg.fm_lo_hz) < 50 && fabs(f_end - cfg.fm_hi_hz) < 200, "chirp ends");
}

// ----------------------------------------------------------------- shocklet
static void test_shocklet(void) {
    printf("pulse shocklets\n");
    fs_config cfg = fs_default_config(); fs_state st; fs_init(&st, &cfg, &hal);
    static uint16_t steps[40000];
    ps_vec ports[6]; uint32_t delay[6];
    for (int i = 0; i < 6; i++) { ports[i].x = 0.070f * cosf(i * (float)PI / 3); ports[i].y = 0.070f * sinf(i * (float)PI / 3); ports[i].z = 0; }
    ps_vec target = { 0.012f, -0.007f, 0.110f };
    ps_ring_delays(ports, 6, target, 343.0f, 0, 100000, delay);
    double spread = 0, first = -1;
    for (int i = 0; i < 6; i++) {
        double d = sqrt(pow(ports[i].x - target.x, 2) + pow(ports[i].y - target.y, 2) + pow(ports[i].z - target.z, 2));
        double arrive = delay[i] / (double)DR_SYS_CLK_HZ + d / 343.0;
        if (first < 0) first = arrive;
        if (fabs(arrive - first) > spread) spread = fabs(arrive - first);
    }
    printf("  ring of 6, off-axis target: arrivals within %.1f ns\n", spread * 1e9);
    CHECK(spread < 7e-9, "arrival spread %.2e s", spread);
    uint32_t wound[6]; ps_ring_delays(ports, 6, (ps_vec){ 0, 0, 0.12f }, 343.0f, 1, 100000, wound);
    CHECK(wound[3] - wound[0] == 750, "order 1 winds half a 100 kHz period (750 ticks) across the ring, got %u", wound[3] - wound[0]);

    head_down = false; memset(steps, 0, sizeof steps);
    CHECK(ps_toroidal_pulse(&st, 6, delay, 375, 0, PS_COLD_DUTY_MAX, steps, 40000) == FS_REFUSED_INTERLOCK, "a burst with the head up");
    int any = 0; for (int i = 0; i < 40000; i++) any |= steps[i];
    CHECK(!any, "a refused burst wrote a pattern");
    head_down = true;
    CHECK(ps_toroidal_pulse(&st, 6, delay, 20, 0, PS_COLD_DUTY_MAX, steps, 40000) == FS_REFUSED_LEVEL, "a 133 ns half cycle is faster than the crystal");
    CHECK(ps_toroidal_pulse(&st, 6, delay, 375, 1500000, PS_COLD_DUTY_MAX, steps, 40000) == FS_REFUSED_DUTY, "5 us every 10 ms is 5e-4 duty");
    CHECK(ps_toroidal_pulse(&st, 6, delay, 375, 7500000, PS_COLD_DUTY_MAX, steps, 40000) == FS_OK, "5 us every 50 ms is 1e-4 duty");
    int on = 0; for (int i = 0; i < 40000; i++) on += fs_step_value(steps[i], 0) != 0;
    CHECK(on == 750, "channel 0 is driven for one cycle, got %d ticks", on);

    // One-bit time reversal through six synthetic multipath channels.
    enum { N = 400, TPS = 40 };
    static int16_t ir[6 * N]; memset(ir, 0, sizeof ir);
    for (int ch = 0; ch < 6; ch++) for (int tap = 0; tap < 14; tap++) ir[ch * N + rnd() % N] = (int16_t)((int)(rnd() % 20000) - 10000);
    memset(steps, 0, sizeof steps);
    CHECK(ps_time_reversal(&st, 6, ir, N, TPS, 200, 0, 1, steps, N * TPS) == FS_OK, "time reversal build");
    static double rx[2 * N]; memset(rx, 0, sizeof rx);
    for (int ch = 0; ch < 6; ch++) for (int i = 0; i < N; i++) {
        uint16_t sv = steps[i * TPS];
        int d = fs_step_value(sv, ch);
        if (!d) continue;
        for (int j = 0; j < N; j++) rx[i + j] += d * (double)ir[ch * N + j];
    }
    double peak = 0, side = 0; int at = 0;
    for (int i = 0; i < 2 * N; i++) if (fabs(rx[i]) > peak) { peak = fabs(rx[i]); at = i; }
    for (int i = 0; i < 2 * N; i++) if (i != at && fabs(rx[i]) > side) side = fabs(rx[i]);
    printf("  one-bit time reversal, 6 channels x 14 paths: peak at sample %d (expected %d), %.1f x the largest sidelobe\n", at, N - 1, peak / side);
    CHECK(at == N - 1 && peak > 4 * side, "time reversal focus");
}

// ---------------------------------------------------------------------- bus
static void test_bus(void) {
    printf("spinal bus\n");
    static sb_packet p, q; static uint32_t words[SB_MAX_PHASORS + 4];
    p.type = SB_DRIVE; p.source = 2; p.count = 30; p.downbeat = 123456;
    for (int i = 0; i < 30; i++) { p.phasor[i].re = (int16_t)(rnd() & 0xFFFF); p.phasor[i].im = (int16_t)(rnd() & 0xFFFF); }
    size_t n = sb_encode(&p, words);
    CHECK(n == 34 && words[0] == 16 * 33 - 1, "encode length %zu, prefix %u", n, words[0]);
    CHECK(sb_decode(words + 1, n - 1, &q) == SB_OK && q.downbeat == 123456 && q.count == 30 && memcmp(p.phasor, q.phasor, 30 * sizeof(sb_phasor)) == 0, "round trip");
    words[7] ^= 0x00010000u; CHECK(sb_decode(words + 1, n - 1, &q) == SB_BAD_CRC, "a flipped bit must fail the CRC");
    words[7] ^= 0x00010000u; CHECK(sb_decode(words + 1, 10, &q) == SB_SHORT, "a truncated packet");
    float rate = sb_bit_rate(DR_SYS_CLK_HZ);
    printf("  %.0f Mbit/s; a 30-phasor packet takes %.1f us\n", rate / 1e6, 33 * 32 / rate * 1e6);
    CHECK(rate >= 50e6f && rate <= 150e6f, "bit rate %.0f outside the 50-150 Mbit/s range", rate);
    uint16_t prog[4] = { 0x2010, 0x2090, 0x6008, 0x20C2 };        // wait 0 gpio 16; wait 1 gpio 16; out pins, 8; wait 1 irq 2
    CHECK(sb_sync_patch(prog, 4, 16) == 2 && prog[0] == 0x2000 && prog[1] == 0x2080 && prog[2] == 0x6008 && prog[3] == 0x20C2, "SYNC patch for a PIO block based at GPIO16");
    CHECK(sb_sync_patch(prog, 4, 0) == 2 && prog[1] == 0x2090, "SYNC patch back");
    CHECK(DR_TX_RING_TICKS * 4ull * 32000 == 16ull * DR_SYS_CLK_HZ / 1 * 1 && DR_TX_RING_TICKS % 2 == 0, "ring is 4 periods of 32 kHz");
    CHECK((double)DR_BURST_SAMPLES / DR_SIGMA_DELTA_FS_HZ * 32000 == 16.0 && (double)DR_BURST_SAMPLES / DR_SIGMA_DELTA_FS_HZ * 40000 == 20.0, "burst is whole periods of both combs");
}

// ------------------------------------------------------- CSQ8 image loader
static uint8_t *slurp(const char *path, size_t *len) {
    FILE *f = fopen(path, "rb"); if (!f) return NULL;
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    uint8_t *b = malloc((size_t)n + 1);
    *len = fread(b, 1, (size_t)n, f); fclose(f);
    return b;
}
static csq8_work cw;
static void test_csq8_image(const char *name) {
    const char *dir = getenv("CSQ8_DIR"), *ref_dir = getenv("CSQ8_REF");
    char path[1024]; size_t len = 0, rlen = 0;
    snprintf(path, sizeof path, "%s/%s.bin", dir ? dir : ".", name);
    uint8_t *blob = slurp(path, &len);
    if (!blob) { printf("  SKIPPED %s: no image at %s (SIM regenerates it: python -m holo.cadence_drawer sparse-receipt)\n", name, path); return; }
    csq8_image img;
    csq8_status st = csq8_load(blob, len, &img);
    CHECK(st == CSQ8_OK, "%s: load status %d", name, (int)st);
    if (st != CSQ8_OK) { free(blob); return; }
    uint8_t *again = malloc(len);
    CHECK(csq8_store(&img, again, len) == len && memcmp(blob, again, len) == 0, "%s: store(load(image)) is not the image", name);
    CHECK(csq8_store(&img, again, len - 1) == 0, "%s: store into a short buffer", name);
    size_t grid = (size_t)img.ih.n_brows * img.ih.n_bcols + (size_t)img.ho.n_brows * img.ho.n_bcols;
    double density = (double)(img.ih.n_blocks + img.ho.n_blocks) / (double)grid;
    printf("  %s: %zu bytes, %u -> %u <-> %u, %u + %u blocks (%.1f %% of the grid), %u steps, alpha %.2f, threshold %.4f\n", name, len,
           img.n_in, img.n_h, img.n_o, img.ih.n_blocks, img.ho.n_blocks, 100 * density, img.steps, img.alpha, img.delta_thr);
    CHECK(4u * img.n_h + 3u * img.n_o_p <= CSQ8_STATE_UNITS, "%s: settle state needs %u units of %u", name, 4u * img.n_h + 3u * img.n_o_p, (unsigned)CSQ8_STATE_UNITS);
    // every way the image can be damaged must be refused before anything dereferences it
    memcpy(again, blob, len); again[0] = 'X'; CHECK(csq8_load(again, len, &img) == CSQ8_BAD_MAGIC, "bad magic accepted");
    memcpy(again, blob, len); again[4] = 2; CHECK(csq8_load(again, len, &img) == CSQ8_BAD_VERSION, "bad version accepted");
    memcpy(again, blob, len); again[12] = 4; CHECK(csq8_load(again, len, &img) == CSQ8_BAD_BLOCK, "bad block size accepted");
    memcpy(again, blob, len); again[9] = 0xFF; CHECK(csq8_load(again, len, &img) == CSQ8_BAD_SHAPE, "oversize n_h accepted");
    memcpy(again, blob, len); again[CSQ8_HEADER_BYTES + 4] ^= 0x40; CHECK(csq8_load(again, len, &img) == CSQ8_BAD_INDEX, "broken row pointer accepted");
    csq8_load(blob, len, &img);
    memcpy(again, blob, len); again[img.ih.col - blob] = 0xFF; CHECK(csq8_load(again, len, &img) == CSQ8_BAD_INDEX, "column index outside the grid accepted");
    int short_ok = 1;
    for (size_t cut = 0; cut < len; cut += 97) if (csq8_load(blob, cut, &img) == CSQ8_OK) short_ok = 0;
    CHECK(short_ok && csq8_load(blob, len - 1, &img) == CSQ8_SHORT, "a truncated image was accepted");
    uint8_t *longer = malloc(len + 1); memcpy(longer, blob, len); longer[len] = 0;
    CHECK(csq8_load(longer, len + 1, &img) == CSQ8_TRAILING, "trailing bytes accepted"); free(longer);
    csq8_load(blob, len, &img);
    // the settle against the NumPy reference of SIM's arithmetic
    snprintf(path, sizeof path, "%s/%s.ref", ref_dir ? ref_dir : ".", name);
    uint8_t *ref = slurp(path, &rlen);
    if (!ref) { printf("  SKIPPED %s settle comparison: no reference at %s (needs NumPy)\n", name, path); }
    else {
        uint32_t n_in, n_o, steps; float ev;
        memcpy(&n_in, ref, 4); memcpy(&n_o, ref + 4, 4); memcpy(&steps, ref + 8, 4); memcpy(&ev, ref + 12, 4);
        CHECK(n_in == img.n_in && n_o == img.n_o && rlen == 16 + 8u * (n_in + n_o), "%s: reference shape", name);
        const csq8_cf *x = (const csq8_cf *)(void *)(ref + 16), *want = x + n_in;
        int used = csq8_settle(&img, x, &cw);
        double worst = 0, norm = 0;
        for (unsigned i = 0; i < n_o; i++) {
            double e = hypot(cw.so[i].re - want[i].re, cw.so[i].im - want[i].im);
            if (e > worst) worst = e;
            norm += want[i].re * want[i].re + want[i].im * want[i].im;
        }
        double mine = (double)cw.events / cw.units;
        printf("    settle: %d steps (reference %u), output rms %.3f, worst difference from the reference %.2e, event fraction %.3f (reference %.3f)\n",
               used, steps, sqrt(norm / n_o), worst, mine, ev);
        CHECK(worst < 2e-4, "%s: settle differs from the reference by %.2e", name, worst);
        CHECK((uint32_t)used == steps, "%s: %d steps, reference %u", name, used, steps);
        CHECK(fabs(mine - ev) < 0.02, "%s: event fraction %.3f, reference %.3f", name, mine, ev);
        size_t full = (size_t)img.ih.n_blocks * 64 + 2u * img.ho.n_blocks * 64 * (size_t)used;
        printf("    %u MACs (%.0f %% of pushing every block every step); %.1f ms at 150 MHz with SIM's ASSUMED 8 cycles per MAC and 60 per soma\n",
               cw.macs, 100.0 * cw.macs / (double)full, csq8_settle_ms(&img, &cw, 8, 60, 150e6f));
        free(ref);
    }
    // HLEQ v1: an object's goal as per-stroke output biases for this image
    size_t plen = 0, qlen = 0;
    snprintf(path, sizeof path, "%s/%s.hleq", ref_dir ? ref_dir : ".", name);
    uint8_t *pk = slurp(path, &plen);
    snprintf(path, sizeof path, "%s/%s.hleqref", ref_dir ? ref_dir : ".", name);
    uint8_t *pref = slurp(path, &qlen);
    if (!pk || !pref) { printf("  SKIPPED %s HLEQ: no packet or reference (needs NumPy)\n", name); }
    else {
        hleq_packet hp;
        hleq_status hs = hleq_load(pk, plen, img.n_o_p, &hp);
        CHECK(hs == HLEQ_OK && hp.n_strokes == 6 && hp.n_o_p == img.n_o_p && hp.bytes == plen && hp.echo_norm_q15 == 32768 && hp.verify_tol == 0.25f,
              "%s: HLEQ load status %d", name, (int)hs);
        CHECK(img.n_o_p != 64 || plen == 1556, "a 6-stroke, 64-output packet is %zu bytes, not 1556", plen);
        CHECK(hleq_stroke_bias(&hp, 0) == pk + HLEQ_HEADER_BYTES && hleq_stroke_bias(&hp, 5) == pk + HLEQ_HEADER_BYTES + 5u * 4u * img.n_o_p &&
              hleq_stroke_bias(&hp, 6) == NULL, "stroke bias pointers");
        // every single-bit error in transit is refused; in the biases and the CRC it is the CRC that says so
        uint8_t *bad = malloc(plen + 1); int accepted = 0, not_crc = 0;
        for (size_t bit = 0; bit < 8 * plen; bit++) {
            memcpy(bad, pk, plen); bad[bit / 8] ^= (uint8_t)(1u << (bit % 8));
            hleq_packet t; hleq_status r = hleq_load(bad, plen, img.n_o_p, &t);
            if (r == HLEQ_OK || t.stroke_biases) accepted++;
            if (bit / 8 >= HLEQ_HEADER_BYTES && r != HLEQ_BAD_CRC) not_crc++;
            if (bit / 8 >= 10 && bit / 8 < HLEQ_HEADER_BYTES && r != HLEQ_BAD_CRC) not_crc++;      // echo norm, tolerance
        }
        CHECK(accepted == 0 && not_crc == 0, "%s: of %zu one-bit errors %d were accepted and %d were not HLEQ_BAD_CRC", name, 8 * plen, accepted, not_crc);
        // a sender's bad numbers, with a correct CRC over them
        #define RESEAL(b) do { uint32_t c = hleq_crc32((b), plen - 4); (b)[plen - 4] = (uint8_t)c; (b)[plen - 3] = (uint8_t)(c >> 8); (b)[plen - 2] = (uint8_t)(c >> 16); (b)[plen - 1] = (uint8_t)(c >> 24); } while (0)
        hleq_packet t;
        memcpy(bad, pk, plen); bad[HLEQ_HEADER_BYTES + 41] = 0x7E; RESEAL(bad); CHECK(hleq_load(bad, plen, img.n_o_p, &t) == HLEQ_BAD_VALUE, "a NaN bias accepted");
        memcpy(bad, pk, plen); bad[plen - 6] = 0x00; bad[plen - 5] = 0xFC; RESEAL(bad); CHECK(hleq_load(bad, plen, img.n_o_p, &t) == HLEQ_BAD_VALUE, "an infinite bias accepted");
        memcpy(bad, pk, plen); memset(bad + 12, 0, 4); RESEAL(bad); CHECK(hleq_load(bad, plen, img.n_o_p, &t) == HLEQ_BAD_VALUE, "verify_tol 0 accepted");
        memcpy(bad, pk, plen); bad[14] = 0xC0; bad[15] = 0x7F; RESEAL(bad); CHECK(hleq_load(bad, plen, img.n_o_p, &t) == HLEQ_BAD_VALUE, "verify_tol NaN accepted");
        memcpy(bad, pk, plen); bad[7] = 2; RESEAL(bad); CHECK(hleq_load(bad, plen, img.n_o_p, &t) == HLEQ_BAD_VALUE, "a reserved flag accepted");
        memcpy(bad, pk, plen); bad[6] = 17; RESEAL(bad); CHECK(hleq_load(bad, plen, img.n_o_p, &t) == HLEQ_BAD_SHAPE, "17 strokes accepted");
        memcpy(bad, pk, plen); bad[6] = 0; RESEAL(bad); CHECK(hleq_load(bad, plen, img.n_o_p, &t) == HLEQ_BAD_SHAPE, "0 strokes accepted");
        CHECK(hleq_load(pk, plen, (uint16_t)(img.n_o_p + 8), &t) == HLEQ_BAD_SHAPE, "a packet for another output width accepted");
        memcpy(bad, pk, plen); bad[4] = 2; CHECK(hleq_load(bad, plen, img.n_o_p, &t) == HLEQ_BAD_VERSION, "version 2 accepted");
        memcpy(bad, pk, plen); bad[0] = 'X'; CHECK(hleq_load(bad, plen, img.n_o_p, &t) == HLEQ_BAD_MAGIC, "bad magic accepted");
        CHECK(hleq_load(pk, plen - 1, img.n_o_p, &t) == HLEQ_SHORT && hleq_load(pk, 12, img.n_o_p, &t) == HLEQ_SHORT, "a short packet accepted");
        memcpy(bad, pk, plen); bad[plen] = 0; CHECK(hleq_load(bad, plen + 1, img.n_o_p, &t) == HLEQ_TRAILING, "trailing bytes accepted");
        free(bad);
        // each stroke's settle against NumPy; the image's own bias through the same door
        uint32_t ns, n_o; memcpy(&ns, pref, 4); memcpy(&n_o, pref + 4, 4);
        size_t xlen = 0; snprintf(path, sizeof path, "%s/%s.ref", ref_dir ? ref_dir : ".", name);
        uint8_t *xr = slurp(path, &xlen);
        CHECK(xr && ns == 6 && n_o == img.n_o && qlen == 8 + ns * (4 + 16u * n_o), "%s: HLEQ reference shape", name);
        if (xr && ns == 6 && n_o == img.n_o) {
            const csq8_cf *x = (const csq8_cf *)(void *)(xr + 16);
            static csq8_cf plain[CSQ8_MAX_NO]; const size_t so_bytes = img.n_o_p * sizeof plain[0];
            csq8_settle(&img, x, &cw); memcpy(plain, cw.so, so_bytes);
            csq8_settle_biased(&img, x, img.bias, &cw);
            CHECK(memcmp(plain, cw.so, so_bytes) == 0, "csq8_settle is not csq8_settle_biased with the image's bias");
            // Exact comparison with the event threshold off. With it on, a unit that lands within
            // rounding of the threshold announces in one implementation and not the other, and
            // the outputs part by about the threshold times a weight: bounded, not bit-true.
            csq8_image exact = img; exact.delta_thr = 0;
            double worst0 = 0, worst = 0, moved = 1e9; int steps_same = 0;
            for (unsigned k = 0; k < ns; k++) {
                const uint8_t *rec = pref + 8 + k * (4 + 16u * n_o);
                uint32_t steps; memcpy(&steps, rec, 4);
                const csq8_cf *want = (const csq8_cf *)(void *)(rec + 4), *want0 = want + n_o;
                csq8_settle_biased(&exact, x, hleq_stroke_bias(&hp, k), &cw);
                for (unsigned i = 0; i < n_o; i++) worst0 = fmax(worst0, hypot(cw.so[i].re - want0[i].re, cw.so[i].im - want0[i].im));
                int used = csq8_settle_biased(&img, x, hleq_stroke_bias(&hp, k), &cw);
                if ((uint32_t)used == steps) steps_same++;
                double away = 0;
                for (unsigned i = 0; i < n_o; i++) {
                    worst = fmax(worst, hypot(cw.so[i].re - want[i].re, cw.so[i].im - want[i].im));
                    away = fmax(away, hypot(cw.so[i].re - plain[i].re, cw.so[i].im - plain[i].im));
                }
                if (away < moved) moved = away;
            }
            printf("    HLEQ %zu bytes, %u strokes: biased settle against NumPy, worst difference %.2e with the event threshold off, %.2e with it on (threshold %.3f);\n"
                   "      same step count on %d of %u strokes; every stroke moves the output by at least %.2f\n", plen, ns, worst0, worst, img.delta_thr, steps_same, ns, moved);
            // HOLO_EQUATION_SPEC 5.3 asks for < 2e-7. That is under two float32 rounding steps at
            // unit magnitude; two correct float32 implementations that add in a different order
            // sit at 1e-7 to 4e-7 (NumPy against SIM's own class: 1.2e-7). The bound held here is
            // 1e-6, and the run says whether the spec's figure was met.
            CHECK(worst0 < 1e-6, "%s: threshold-free biased settle differs from NumPy by %.2e", name, worst0);
            printf("      spec figure (< 2e-7) %s: %.2e\n", worst0 < 2e-7 ? "met" : "NOT met", worst0);
            CHECK(worst < img.delta_thr, "%s: thresholded biased settle differs from NumPy by %.2e, more than the event threshold", name, worst);
            CHECK(moved > 0.01, "%s: a stroke's bias did not change the output", name);
        }
        free(xr);
    }
    free(pk); free(pref);
    // SIM's golden packet (holo/runs/hleq_v1_fixture.bin, hub #39) through the same loader and settle
    size_t flen = 0, frlen = 0, xlen2 = 0;
    snprintf(path, sizeof path, "%s/hleq_v1_fixture.bin", dir ? dir : ".");
    uint8_t *fx = slurp(path, &flen);
    snprintf(path, sizeof path, "%s/%s.fixref", ref_dir ? ref_dir : ".", name);
    uint8_t *fr = slurp(path, &frlen);
    snprintf(path, sizeof path, "%s/%s.ref", ref_dir ? ref_dir : ".", name);
    uint8_t *xr2 = slurp(path, &xlen2);
    if (!fx || !fr || !xr2) printf("  SKIPPED %s HLEQ fixture: no fixture or reference\n", name);
    else {
        hleq_packet fp; hleq_status fs_ = hleq_load(fx, flen, img.n_o_p, &fp);
        uint32_t ns, n_o; memcpy(&ns, fr, 4); memcpy(&n_o, fr + 4, 4);
        CHECK(fs_ == HLEQ_OK && ns == fp.n_strokes && n_o == img.n_o && frlen == 8 + ns * (4 + 16u * n_o), "%s: fixture status %d or reference shape", name, (int)fs_);
        if (fs_ == HLEQ_OK && ns == fp.n_strokes && n_o == img.n_o) {
            const csq8_cf *x = (const csq8_cf *)(void *)(xr2 + 16);
            csq8_image exact = img; exact.delta_thr = 0;
            double worst0 = 0, worst = 0;
            for (unsigned k = 0; k < ns; k++) {
                const csq8_cf *want = (const csq8_cf *)(void *)(fr + 8 + k * (4 + 16u * n_o) + 4), *want0 = want + n_o;
                csq8_settle_biased(&exact, x, hleq_stroke_bias(&fp, k), &cw);
                for (unsigned i = 0; i < n_o; i++) worst0 = fmax(worst0, hypot(cw.so[i].re - want0[i].re, cw.so[i].im - want0[i].im));
                csq8_settle_biased(&img, x, hleq_stroke_bias(&fp, k), &cw);
                for (unsigned i = 0; i < n_o; i++) worst = fmax(worst, hypot(cw.so[i].re - want[i].re, cw.so[i].im - want[i].im));
            }
            printf("    SIM fixture (%zu bytes, %u strokes): settle against NumPy, worst difference %.2e with the event threshold off, %.2e with it on\n", flen, ns, worst0, worst);
            CHECK(worst0 <= 1e-6, "%s: fixture settle differs from NumPy by %.2e with the threshold off", name, worst0);
            CHECK(worst <= 1e-3, "%s: fixture settle differs from NumPy by %.2e with the threshold on", name, worst);
        }
    }
    free(fx); free(fr); free(xr2);
    free(again); free(blob);
}
// SIM's golden HLEQ v1 packet, byte for byte as holo/holo_equation.py wrote it (receipt
// holo/runs/holo_equation_receipt.json "hleq_fixture").
static void test_hleq_fixture(void) {
    const char *dir = getenv("CSQ8_DIR"); char path[512]; size_t len = 0;
    snprintf(path, sizeof path, "%s/hleq_v1_fixture.bin", dir ? dir : ".");
    uint8_t *fx = slurp(path, &len);
    if (!fx) { printf("  SKIPPED: %s not found\n", path); return; }
    static const uint8_t header[16] = { 0x48, 0x4c, 0x45, 0x51, 0x01, 0x00, 0x06, 0x01, 0x40, 0x00, 0x39, 0x30, 0x00, 0x00, 0x00, 0x3e };
    hleq_packet p; hleq_status s = hleq_load(fx, len, 64, &p);
    CHECK(len == 1556 && memcmp(fx, header, 16) == 0, "fixture is %zu bytes or its header differs from the receipt", len);
    CHECK(s == HLEQ_OK && p.n_strokes == 6 && p.flags == 1 && p.n_o_p == 64 && p.echo_norm_q15 == 12345 && p.verify_tol == 0.125f && p.bytes == 1556,
          "fixture load status %d", (int)s);
    CHECK(len >= 20 && hleq_crc32(fx, len - 4) == 0x42db485cu, "fixture CRC is not the receipt's 42db485c");
    if (s == HLEQ_OK) {
        // first and last bias as the receipt lists them: binary16 0.367919921875 = 0x35E3, -0.320068359375 = 0xB51F
        const uint8_t *b0 = hleq_stroke_bias(&p, 0), *b5 = hleq_stroke_bias(&p, 5);
        CHECK(b0[0] == 0xE3 && b0[1] == 0x35 && b5[4 * 64 - 2] == 0x1F && b5[4 * 64 - 1] == 0xB5, "fixture first or last bias bytes");
        hleq_packet t;
        CHECK(hleq_load(fx, len, 72, &t) == HLEQ_BAD_SHAPE, "the fixture loaded for another output width");
        fx[700] ^= 0x10; CHECK(hleq_load(fx, len, 64, &t) == HLEQ_BAD_CRC, "a damaged fixture loaded"); fx[700] ^= 0x10;
    }
    printf("  SIM fixture hleq_v1_fixture.bin: %zu bytes, status %d, CRC %08x\n", len, (int)s, len >= 20 ? hleq_crc32(fx, len - 4) : 0u);
    free(fx);
}
static void test_csq8(void) {
    // the CRC is the standard one, and the bus's
    CHECK(hleq_crc32((const uint8_t *)"123456789", 9) == 0xCBF43926u, "CRC-32 check value");
    uint32_t wv[3] = { 0x04030201u, 0x08070605u, 0xDEADBEEFu }; uint8_t bv[12];
    for (int i = 0; i < 12; i++) bv[i] = (uint8_t)(wv[i / 4] >> (8 * (i % 4)));
    CHECK(hleq_crc32(bv, 12) == sb_crc32(wv, 3), "hleq_crc32 and sb_crc32 disagree over the same bytes");
    printf("CSQ8 v1 weight image\n");
    test_csq8_image("sparse_cadence_q8");
    test_csq8_image("sparse_cadence_q8_quick");
    test_hleq_fixture();
}

// ------------------------------------------------- drive patterns (#58)
// One Fourier line of the code on a port as the bridge plays it: each step
// held for step_ticks (zero-order hold), amplitude in units of the rail and
// phase in turns of v = A cos(2 pi f t + phase).
static double line_of(const uint16_t *steps, size_t n, int ch, unsigned st, double hz, double *turns) {
    double ar = 0, ai = 0, dt = (double)st / DR_SYS_CLK_HZ;
    for (size_t i = 0; i < n; i++) {
        int v = fs_step_value(steps[i], ch);
        if (!v) continue;
        double w = 2 * PI * hz * ((double)i + 0.5) * dt;
        ar += v * cos(w); ai -= v * sin(w);
    }
    double x = PI * hz * dt, hold = x > 0 ? sin(x) / x : 1.0;
    if (turns) *turns = atan2(ai, ar) / (2 * PI);
    return 2 * hypot(ar, ai) / (double)n * hold;
}
static void edges_of(const uint16_t *steps, size_t n, int ch, int *edges, int *reversals, int *both_high, double *dv2) {
    int last = fs_step_value(steps[n - 1], ch);                  // the ring repeats
    *edges = *reversals = *both_high = 0; *dv2 = 0;
    for (size_t i = 0; i < n; i++) {
        int now = fs_step_value(steps[i], ch);
        if ((steps[i] & FS_STEP_MASK(ch)) == FS_STEP_MASK(ch)) (*both_high)++;
        if (now != last) { (*edges)++; *dv2 += (now - last) * (now - last); if (now && last) (*reversals)++; }
        last = now;
    }
}
static int cmp_double(const void *a, const void *b) { double x = *(const double *)a, y = *(const double *)b; return (x > y) - (x < y); }

static void test_drive_patterns(void) {
    printf("drive patterns: three-level single tone and comb profiles\n");
    static uint16_t steps[DR_TX_RING_TICKS];
    const float hz[5] = DR_COMB_TONES_HZ;
    const double ring_s = DR_TRANSMIT_RING_US * 1e-6, cv2 = DR_C0_NOMINAL_PF * 1e-12 * DR_BRIDGE_RAIL_V * DR_BRIDGE_RAIL_V;
    const double ideal = 4 / PI * cos(PI / 6), ring_hz = 1 / ring_s;
    const unsigned grids[2] = { FS_GRID_FINE_TICKS, FS_GRID_100NS_TICKS };
    CHECK(DR_TX_RING_TICKS == DR_TX_RING_STEPS_100NS * DR_TX_GRID_100NS_DIV && DR_TX_RING_STEPS_100NS == 2 * DR_TX_RING_WORDS_100NS &&
          FS_GRID_100NS_TICKS == DR_TX_GRID_100NS_DIV, "100 ns ring arithmetic");
    CHECK(fabs(ideal * DR_BRIDGE_RAIL_V - 19.85) < 0.01, "three-level fundamental at the rail: %.2f V", ideal * DR_BRIDGE_RAIL_V);

    // Three-level, 120 degrees. Everything a ring-periodic code holds sits on
    // multiples of the ring rate (8 kHz), so the lines below are all of it up to 1 MHz.
    for (int g = 0; g < 2; g++) {
        fs_config c = fs_profile_config(FS_COMB_FINE, (uint16_t)grids[g]);
        size_t n = fs_ring_steps(&c);
        CHECK(n == DR_TX_RING_TICKS / grids[g], "ring steps %zu", n);
        printf("  three-level 120 deg on the %.2f ns grid (%zu steps per ring), worst over 48 phases:\n"
               "    tone kHz | steps/period | fundamental V at %.0f V (ideal %.2f) | phase error deg | 3rd | 5th (ideal 20 %%) | worst other line (kHz) | edges/ring | W/port\n",
               1e9 * grids[g] / DR_SYS_CLK_HZ, n, (double)DR_BRIDGE_RAIL_V, ideal * DR_BRIDGE_RAIL_V);
        for (int k = 0; k < 5; k++) {
            double lo = 9, hi = 0, perr = 0, h3 = 0, h5lo = 9, h5hi = 0, spur = 0, spur_hz = 0, w = 0; int e_lo = 1 << 30, e_hi = 0;
            for (int p = 0; p < 48; p++) {
                float phase = (float)(p / 48.0 + 0.0037);
                memset(steps, 0, n * sizeof steps[0]);
                uint16_t level = fs_three_level_pattern(&c, 3, hz[k], phase, steps, n);
                double turns, a = line_of(steps, n, 3, grids[g], hz[k], &turns);
                double d = turns - phase; d -= floor(d + 0.5);
                int edges, rev, both; double dv2; edges_of(steps, n, 3, &edges, &rev, &both, &dv2);
                if (p == 0) {
                    int others = 0; for (size_t i = 0; i < n; i++) others |= steps[i] & ~FS_STEP_MASK(3);
                    CHECK(level == 32767 && others == 0 && both == 0 && rev == 0, "three-level %g Hz: level %u, other pins %d, both high %d, reversals %d", (double)hz[k], level, others, both, rev);
                    int on = 0; for (size_t i = 0; i < n; i++) on += fs_step_value(steps[i], 3) != 0;
                    CHECK(fabs((double)on / (double)n - 2.0 / 3.0) < (g ? 0.004 : 0.0005), "three-level conducts %.4f of the ring, not 2/3", (double)on / (double)n);
                }
                lo = fmin(lo, a); hi = fmax(hi, a); perr = fmax(perr, fabs(d) * 360);
                h3 = fmax(h3, line_of(steps, n, 3, grids[g], 3 * hz[k], NULL) / a);
                double a5 = line_of(steps, n, 3, grids[g], 5 * hz[k], NULL) / a; h5lo = fmin(h5lo, a5); h5hi = fmax(h5hi, a5);
                for (int m = 1; m <= 125; m++) {
                    double f = m * ring_hz, q = f / hz[k];
                    if (fabs(q - floor(q + 0.5)) < 1e-9 && ((long)floor(q + 0.5) & 1)) continue;      // the tone and its odd harmonics
                    double s = line_of(steps, n, 3, grids[g], f, NULL) / a;
                    if (s > spur) { spur = s; spur_hz = f; }
                }
                e_lo = edges < e_lo ? edges : e_lo; e_hi = edges > e_hi ? edges : e_hi;
                w = fmax(w, 0.5 * cv2 * dv2 / ring_s);
            }
            printf("    %5.0f | %8.3f | %.2f..%.2f | %.3f | %.2f %% | %.1f..%.1f %% | %.2f %% (%.0f) | %d..%d | %.2f\n",
                   hz[k] / 1e3, DR_SYS_CLK_HZ / (hz[k] * grids[g]), lo * DR_BRIDGE_RAIL_V, hi * DR_BRIDGE_RAIL_V, perr, 100 * h3, 100 * h5lo, 100 * h5hi,
                   100 * spur, spur_hz / 1e3, e_lo, e_hi, w);
            int periods = (int)(hz[k] * ring_s + 0.5);
            CHECK(e_lo == 4 * periods && e_hi == 4 * periods, "three-level %g Hz: %d..%d edges per ring, not 4 per period", (double)hz[k], e_lo, e_hi);
            CHECK(fabs(lo / ideal - 1) < (g ? 0.01 : 0.001) && fabs(hi / ideal - 1) < (g ? 0.01 : 0.001), "three-level %g Hz fundamental %.4f..%.4f of the rail", (double)hz[k], lo, hi);
            CHECK(perr < (g ? 3.0 : 0.25), "three-level %g Hz phase error %.3f deg", (double)hz[k], perr);
            CHECK(h3 < (g ? 0.04 : 0.003) && spur < (g ? 0.04 : 0.003), "three-level %g Hz: third harmonic %.4f, other line %.4f", (double)hz[k], h3, spur);
        }
    }
    fs_config c100 = fs_profile_config(FS_COMB_FINE, FS_GRID_100NS_TICKS);
    CHECK(fs_three_level_pattern(&c100, 0, 1.0e6f, 0, steps, 16) == 0 && fs_three_level_pattern(&c100, 0, 0, 0, steps, 16) == 0, "a tone the grid cannot hold must be refused");

    // Comb profiles: 32 random phase sets of the five tones at 18 % of full scale each.
    static const char *const names[3] = { "FS_COMB_FINE", "FS_COMB_LOW_LOSS", "FS_COMB_LOWEST_LOSS" };
    static int16_t re[32][5], im[32][5];
    for (int s = 0; s < 32; s++) for (int k = 0; k < 5; k++) { double ph = 2 * PI * unit(); re[s][k] = (int16_t)(6000 * cos(ph)); im[s][k] = (int16_t)(6000 * sin(ph)); }
    printf("  comb profiles, 5 tones at 18 %% each, 32 phase sets: pulse | tone error median, worst | edges per ring | W per port (hard-switched, DERIVED)\n");
    for (int g = 0; g < 2; g++) {
        double w_prev = 1e9;
        for (int p = 0; p < 3; p++) {
            fs_config c = fs_profile_config((fs_comb_profile)p, (uint16_t)grids[g]);
            size_t n = fs_ring_steps(&c);
            CHECK(c.hold_ticks == (g ? 15u : 16u) << p && c.hold_ticks % c.step_ticks == 0, "%s pulse %u ticks", names[p], c.hold_ticks);
            double err[32], w = 0, e_mean = 0; int both_all = 0;
            for (int s = 0; s < 32; s++) {
                memset(steps, 0, n * sizeof steps[0]);
                fs_comb_pattern(&c, 1, 5, hz, re[s], im[s], steps, n);
                err[s] = 0;
                for (int k = 0; k < 5; k++) {
                    double turns, a = line_of(steps, n, 1, grids[g], hz[k], &turns);
                    err[s] = fmax(err[s], hypot(a * cos(2 * PI * turns) - re[s][k] / 32768.0, a * sin(2 * PI * turns) - im[s][k] / 32768.0) / (6000 / 32768.0));
                }
                int edges, rev, both; double dv2; edges_of(steps, n, 1, &edges, &rev, &both, &dv2);
                w += 0.5 * cv2 * dv2 / ring_s / 32; e_mean += edges / 32.0; (void)rev; both_all += both;
            }
            qsort(err, 32, sizeof err[0], cmp_double);
            printf("    %-19s %3u ticks (%5.1f ns) on the %.2f ns grid | %4.1f %%, %4.1f %% | %4.0f | %.2f\n", names[p], c.hold_ticks, 1e9 * c.hold_ticks / DR_SYS_CLK_HZ,
                   1e9 * grids[g] / DR_SYS_CLK_HZ, 100 * err[16], 100 * err[31], e_mean, w);
            // bounds a little over what this run gives; the low-loss profiles pay in tone error
            static const double median_ok[3] = { 0.03, 0.08, 0.20 }, worst_ok[3] = { 0.07, 0.15, 0.32 };
            CHECK(err[16] < median_ok[p] && err[31] < worst_ok[p], "%s on grid %u: tone error median %.3f, worst %.3f", names[p], grids[g], err[16], err[31]);
            CHECK(both_all == 0, "%s set both legs high", names[p]);
            CHECK(w < 0.6 * w_prev, "%s: %.2f W is not well under the shorter pulse's %.2f W", names[p], w, w_prev);
            w_prev = w;
        }
    }
    // the chirp runs on the 100 ns grid too, and a ring packs into half as many words as steps
    memset(steps, 0, sizeof steps);
    fs_fm_chirp_pattern(&c100, 0, 20000, steps, 4 * fs_ring_steps(&c100));
    int driven = 0; for (size_t i = 0; i < 4 * fs_ring_steps(&c100); i++) driven += fs_step_value(steps[i], 0) != 0;
    CHECK(driven > 1000 && driven < 4500, "chirp on the 100 ns grid drove %d of 5000 steps", driven);
    static uint32_t words[DR_TX_RING_WORDS_100NS];
    fs_pack_ring(steps, fs_ring_steps(&c100), words);
    CHECK((words[7] & 0xFFF) == steps[14] && ((words[7] >> 12) & 0xFFF) == steps[15], "ring packing on the 100 ns grid");
}

// ------------------------------------------------------ live-M calibration (#77)
// The chamber's side of LISTEN is a calibration image in RAM (LMQ8); the object's
// side is an HLEQ packet. One packet, three chamber temperatures, a new image per
// temperature and nothing reflashed. Scenes, images and expected estimates come from
// tests/lmq8_reference.py on SIM's operators (SIMULATED).
static lmq8_slot slot;
static lmq8_status download(const uint8_t *img, size_t len, size_t chunk) {
    lmq8_slot_begin(&slot);
    for (size_t at = 0; at < len; at += chunk) {
        lmq8_status r = lmq8_slot_write(&slot, img + at, len - at < chunk ? len - at : chunk);
        if (r != LMQ8_OK) return r;
    }
    return lmq8_slot_commit(&slot);
}
static void test_live_m(void) {
    printf("live-M calibration image (LMQ8) under one HLEQ packet\n");
    printf("  RAM: settle state %zu + calibration slot %zu = %zu bytes of %u\n", sizeof cw, sizeof slot, sizeof cw + sizeof slot, DR_CADENCE_SPARSE_MAX_BYTES);
    CHECK(sizeof cw + sizeof slot < DR_CADENCE_SPARSE_MAX_BYTES, "settle state + calibration slot over the RAM budget");
    const char *dir = getenv("CSQ8_DIR"), *ref_dir = getenv("CSQ8_REF"); char path[1024];
    size_t plen = 0, slen = 0, blen = 0;
    snprintf(path, sizeof path, "%s/lmq8_goal.hleq", ref_dir ? ref_dir : "."); uint8_t *pk = slurp(path, &plen);
    snprintf(path, sizeof path, "%s/lmq8_stale.bin", ref_dir ? ref_dir : "."); uint8_t *stale = slurp(path, &slen);
    snprintf(path, sizeof path, "%s/goal_cadence_csq8.bin", dir ? dir : "."); uint8_t *flash = slurp(path, &blen);
    if (!pk || !stale) { printf("  SKIPPED: no LMQ8 reference (needs holo/runs/goal_cadence_live_operators.npz and NumPy)\n"); free(pk); free(stale); free(flash); return; }
    hleq_packet hp;
    CHECK(hleq_load(pk, plen, 64, &hp) == HLEQ_OK && hp.n_strokes == 16, "the goal packet must load: 16 strokes x 64 sites");
    const uint32_t packet_crc = hleq_crc32(pk, plen), flash_crc = flash ? hleq_crc32(flash, blen) : 0;
    // the shared network in flash, where there is one: its answer must not depend on which calibration is held
    csq8_image net; bool have_net = flash && csq8_load(flash, blen, &net) == CSQ8_OK && net.n_o_p == 64;
    static csq8_cf net_before[64]; bool net_set = false, net_same = true;
    if (!have_net) printf("  (no goal_cadence_csq8.bin: the flash-network independence check is skipped)\n");

    // before any calibration, and while one is arriving, LISTEN is refused
    static float est[CSQ8_MAX_NO]; uint8_t occ[(CSQ8_MAX_NO + 7) / 8]; int mism = -1;
    static csq8_cf zero_x[CSQ8_MAX_NIN];
    lmq8_slot_begin(&slot);
    CHECK(lmq8_listen(&slot, &hp, 0, zero_x, est, occ, &mism) == LMQ8_NO_CALIBRATION, "LISTEN without a calibration must be refused");

    static const char *const tags[3] = { "p0", "p03", "p1" }; static const double kelvin[3] = { 0.0, 0.3, 1.0 };
    uint32_t swaps0 = slot.swaps;
    for (int c = 0; c < 3; c++) {
        size_t ilen = 0, rlen = 0;
        snprintf(path, sizeof path, "%s/lmq8_%s.bin", ref_dir ? ref_dir : ".", tags[c]); uint8_t *im = slurp(path, &ilen);
        snprintf(path, sizeof path, "%s/lmq8_%s.ref", ref_dir ? ref_dir : ".", tags[c]); uint8_t *ref = slurp(path, &rlen);
        if (!im || !ref) { CHECK(0, "missing LMQ8 reference for %s", tags[c]); free(im); free(ref); continue; }
        uint32_t n, n_in, n_out, reps; memcpy(&n, ref, 4); memcpy(&n_in, ref + 4, 4); memcpy(&n_out, ref + 8, 4); memcpy(&reps, ref + 12, 4);
        const size_t xb = 8u * (size_t)n * n_in, eb = 4u * (size_t)n * n_out;
        CHECK(n_out == 64 && rlen == 16 + 2 * (xb + eb) + (size_t)n * 8 + 8, "%s: reference shape", tags[c]);
        const csq8_cf *x_live = (const csq8_cf *)(void *)(ref + 16), *x_stale = (const csq8_cf *)(void *)(ref + 16 + xb + eb);
        const float *e_live = (const float *)(void *)(ref + 16 + xb), *e_stale = (const float *)(void *)(ref + 16 + 2 * xb + eb);
        const uint8_t *truth = ref + 16 + 2 * (xb + eb);
        float want_live, want_stale; memcpy(&want_live, truth + (size_t)n * 8, 4); memcpy(&want_stale, truth + (size_t)n * 8 + 4, 4);

        for (int arm = 0; arm < 2; arm++) {                      // 0: the calibration made at this temperature; 1: the stale one
            const uint8_t *image = arm ? stale : im; size_t len = arm ? slen : ilen;
            lmq8_status st = download(image, len, 1024);         // as the bus delivers it, 1 kB at a time
            CHECK(st == LMQ8_OK && slot.valid && slot.img.n_in == n_in && slot.img.n_out == 64 && slot.img.bytes == len, "%s arm %d: download status %d", tags[c], arm, (int)st);
            if (st != LMQ8_OK) continue;
            if (!arm) CHECK(fabsf(slot.img.air_temp_offset_k - (float)kelvin[c]) < 1e-6f && slot.img.calibration_seq == (uint32_t)c + 1 && slot.img.threshold == 0.5f,
                            "%s: the image does not say which calibration it is", tags[c]);
            const csq8_cf *x = arm ? x_stale : x_live; const float *want = arm ? e_stale : e_live;
            double worst = 0; int exact = 0, differ = 0, flagged = 0, wrong_scenes = 0, false_alarms = 0;
            for (uint32_t i = 0; i < n; i++) {
                lmq8_status ls = lmq8_listen(&slot, &hp, i / reps, x + (size_t)i * n_in, est, occ, &mism);
                if (ls != LMQ8_OK) { differ++; continue; }
                bool same = true;
                for (unsigned k = 0; k < 64; k++) {
                    double d = fabs((double)est[k] - want[(size_t)i * 64 + k]); if (d > worst) worst = d;
                    bool mine = (occ[k / 8] >> (k % 8)) & 1, numpy = want[(size_t)i * 64 + k] > 0.5f;
                    if (mine != numpy && fabs((double)want[(size_t)i * 64 + k] - 0.5) > 1e-4) differ++;
                    if (mine != (bool)((truth[(size_t)i * 8 + k / 8] >> (k % 8)) & 1)) same = false;
                }
                exact += same;
                // the goal is in the packet, so "is the chamber as the file says" needs nothing else
                int goal_vs_truth = 0; const uint8_t *goal = hleq_stroke_bias(&hp, i / reps);
                for (unsigned k = 0; k < 64; k++) {
                    bool g = (goal[4 * k] | goal[4 * k + 1]) != 0;       // a goal site's real part is 0.8, every other is 0
                    goal_vs_truth += g != (bool)((truth[(size_t)i * 8 + k / 8] >> (k % 8)) & 1);
                }
                if (goal_vs_truth) { wrong_scenes++; if (mism > 0) flagged++; }
                else if (mism > 0) false_alarms++;
            }
            double acc = (double)exact / n;
            printf("  +%.1f K, %s calibration: exact occupancy %.3f on %u scenes (NumPy %.3f); estimate off NumPy by %.1e at most;\n"
                   "    disturbed scenes flagged %d of %d, undisturbed scenes falsely flagged %d of %d\n",
                   kelvin[c], arm ? "STALE nominal" : "live", acc, n, (double)(arm ? want_stale : want_live), worst, flagged, wrong_scenes, false_alarms, (int)n - wrong_scenes);
            CHECK(worst < 2e-4 && differ == 0, "%s arm %d: estimate differs from NumPy by %.2e, %d occupancy bits differ", tags[c], arm, worst, differ);
            CHECK(fabs(acc - (double)(arm ? want_stale : want_live)) < 0.005, "%s arm %d: exact occupancy %.3f, NumPy %.3f", tags[c], arm, acc, (double)(arm ? want_stale : want_live));
            if (!arm) CHECK(acc >= 0.99 && false_alarms == 0, "+%.1f K with its own calibration reads only %.3f, %d false alarms", kelvin[c], acc, false_alarms);
            if (arm && c > 0) CHECK(acc < 0.5, "+%.1f K with the stale calibration still reads %.3f: the test would not show the failure", kelvin[c], acc);
            // the flash network's settle for stroke 0 is the same whatever calibration is held
            if (have_net && net.n_in == n_in) {
                csq8_settle_biased(&net, x_live, hleq_stroke_bias(&hp, 0), &cw);
                if (!net_set && c == 0 && arm == 0) { memcpy(net_before, cw.so, sizeof net_before); net_set = true; }
            }
        }
        free(im); free(ref);
    }
    CHECK(slot.swaps == swaps0 + 6, "six calibrations were swapped in, the slot counted %u", slot.swaps - swaps0);
    // nothing but the slot changed: the packet and the flash image are the bytes they were
    CHECK(hleq_crc32(pk, plen) == packet_crc, "the goal packet changed during the swaps");
    if (flash) CHECK(hleq_crc32(flash, blen) == flash_crc, "the flash image changed during the swaps");
    if (have_net && net_set) {
        size_t rl = 0; snprintf(path, sizeof path, "%s/lmq8_p0.ref", ref_dir ? ref_dir : "."); uint8_t *r0 = slurp(path, &rl);
        if (r0) { csq8_settle_biased(&net, (const csq8_cf *)(void *)(r0 + 16), hleq_stroke_bias(&hp, 0), &cw); net_same = memcmp(net_before, cw.so, sizeof net_before) == 0; }
        free(r0);
        CHECK(net_same, "the flash network's settle changed after the calibration swaps");
    }

    // downloads that must not become the calibration
    uint8_t *bad = malloc(slen + 8); lmq8_image t;
    CHECK(download(stale, slen, 4096) == LMQ8_OK && slot.valid, "a good image, to damage copies of");
    CHECK(lmq8_slot_write(&slot, stale, 16) == LMQ8_BAD_SHAPE && slot.valid, "writing into a committed calibration without begin");
    lmq8_slot_begin(&slot); lmq8_slot_write(&slot, stale, slen / 2);
    CHECK(lmq8_listen(&slot, &hp, 0, zero_x, est, occ, NULL) == LMQ8_NO_CALIBRATION, "LISTEN during a download must be refused");
    CHECK(lmq8_slot_commit(&slot) == LMQ8_SHORT && !slot.valid, "half an image committed");
    int accepted = 0;
    for (size_t bit = 0; bit < 8 * slen; bit += 97) {            // every 97th bit: 3 571 single-bit errors
        memcpy(bad, stale, slen); bad[bit / 8] ^= (uint8_t)(1u << (bit % 8));
        if (lmq8_load(bad, slen, &t) == LMQ8_OK || t.q) accepted++;
    }
    CHECK(accepted == 0, "%d damaged calibration images were accepted", accepted);
    memcpy(bad, stale, slen); bad[100] ^= 1; CHECK(download(bad, slen, 1024) == LMQ8_BAD_CRC && !slot.valid, "a damaged download became the calibration");
    #define LSEAL(b, n) do { uint32_t c = hleq_crc32((b), (n) - 4); (b)[(n) - 4] = (uint8_t)c; (b)[(n) - 3] = (uint8_t)(c >> 8); (b)[(n) - 2] = (uint8_t)(c >> 16); (b)[(n) - 1] = (uint8_t)(c >> 24); } while (0)
    memcpy(bad, stale, slen); bad[14] = 0xC0; bad[15] = 0x7F; LSEAL(bad, slen); CHECK(lmq8_load(bad, slen, &t) == LMQ8_BAD_VALUE, "a NaN threshold accepted");
    memcpy(bad, stale, slen); bad[LMQ8_HEADER_BYTES + 3] = 0x7F; bad[LMQ8_HEADER_BYTES + 2] = 0x80; LSEAL(bad, slen); CHECK(lmq8_load(bad, slen, &t) == LMQ8_BAD_VALUE, "an infinite row scale accepted");
    memcpy(bad, stale, slen); bad[4] = 2; CHECK(lmq8_load(bad, slen, &t) == LMQ8_BAD_VERSION, "version 2 accepted");
    memcpy(bad, stale, slen); bad[0] = 'X'; CHECK(lmq8_load(bad, slen, &t) == LMQ8_BAD_MAGIC, "bad magic accepted");
    memcpy(bad, stale, slen); bad[8] = 65; CHECK(lmq8_load(bad, slen, &t) == LMQ8_TOO_BIG, "65 sites x 336 inputs is over the slot and was accepted");
    memcpy(bad, stale, slen); bad[8] = 0; CHECK(lmq8_load(bad, slen, &t) == LMQ8_BAD_SHAPE, "0 sites accepted");
    CHECK(lmq8_load(stale, slen - 1, &t) == LMQ8_SHORT && lmq8_load(stale, 20, &t) == LMQ8_SHORT, "a short image accepted");
    memcpy(bad, stale, slen); bad[slen] = 0; CHECK(lmq8_load(bad, slen + 1, &t) == LMQ8_TRAILING, "trailing bytes accepted");
    lmq8_slot_begin(&slot);
    CHECK(lmq8_slot_write(&slot, stale, slen) == LMQ8_OK && lmq8_slot_write(&slot, stale, 1) == LMQ8_TOO_BIG, "a download longer than the slot was taken");
    // a packet that does not fit the calibration
    CHECK(download(stale, slen, 4096) == LMQ8_OK, "restore a calibration");
    CHECK(lmq8_listen(&slot, &hp, 16, zero_x, est, occ, NULL) == LMQ8_BAD_SHAPE, "a stroke the packet does not have");
    hleq_packet narrow = hp; narrow.n_o_p = 56;
    CHECK(lmq8_listen(&slot, &narrow, 0, zero_x, est, occ, NULL) == LMQ8_BAD_SHAPE, "a packet narrower than the calibration's sites");
    // no echo error and no goal: nothing is there
    CHECK(lmq8_read(&slot.img, zero_x, NULL, est, occ) == 0, "an empty chamber with no goal read as occupied");
    // 43 008 real multiply-adds per read
    printf("  one read: %u multiply-adds; %.1f ms at 150 MHz at an ASSUMED 8 cycles each\n", 2u * slot.img.n_in * slot.img.n_out, 2.0 * slot.img.n_in * slot.img.n_out * 8 / 150e6 * 1e3);
    free(bad); free(pk); free(stale); free(flash);
}

int main(void) {
    test_lockin(); test_cadence(); test_csq8(); test_scheduler(); test_shocklet(); test_bus(); test_drive_patterns(); test_live_m();
    printf("%d checks passed, %d failed\n", passed, failed);
    return failed ? 1 : 0;
}
