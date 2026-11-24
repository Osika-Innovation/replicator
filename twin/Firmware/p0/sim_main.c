// The P0 controller core on a computer: bytes on stdin/stdout, pins and
// microphone simulated. The pin waveforms are the real patterns; each
// channel's velocity is the fundamental of its own pulse train, so the phase
// and amplitude steps of the hardware are in what the twin gets back.
//
//   p0sim <v_full m/s> <transfer file>
// transfer file: per listen gate, u16 gate · u16 n · n × (f32 re, f32 im):
// ADC counts at that gate per m/s of each drive channel (the acoustics and
// the microphone, supplied by the test).
#include "fcore.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static float complex_re[FC_DRIVES], complex_im[FC_DRIVES];      // each drive's velocity phasor now
static float v_full;
static struct { int gate; float re[FC_DRIVES], im[FC_DRIVES]; } rows[FC_MAX_RX];
static int row_count;

static void hal_write(const uint8_t *b, size_t n) { fwrite(b, 1, n, stdout); fflush(stdout); }
static void hal_wait(uint32_t t) { (void)t; }
static void hal_begin(void) {}
static float hal_air(void) { return 20.0f; }
static float hal_supply(void) { return 18.0f; }

static void hal_pattern(const uint32_t p[FC_STEPS], float hz) {
    (void)hz;
    for (int c = 0; c < FC_DRIVES; c++) {
        double re = 0, im = 0;
        for (int k = 0; k < FC_STEPS; k++) if (p[k] >> c & 1) {
            double a = -2 * M_PI * (k + 0.5) / FC_STEPS;
            re += cos(a); im += sin(a);
        }
        complex_re[c] = (float)(v_full * sin(M_PI / FC_STEPS) * re);
        complex_im[c] = (float)(v_full * sin(M_PI / FC_STEPS) * im);
    }
}

// A 12-bit converter at 500 kS/s on the gate's input, then the lock-in the
// board runs: 2/n Σ s e^{-iωt}.
static fc_cpx hal_lock_in(int gate, float hz, uint32_t us) {
    double are = 0, aim = 0;
    for (int r = 0; r < row_count; r++) if (rows[r].gate == gate)
        for (int c = 0; c < FC_DRIVES; c++) {
            are += rows[r].re[c] * complex_re[c] - rows[r].im[c] * complex_im[c];
            aim += rows[r].re[c] * complex_im[c] + rows[r].im[c] * complex_re[c];
        }
    const double fs = 500e3;
    int n = (int)(us * 1e-6 * fs);
    n -= n % (int)lround(fs / hz * 2);                           // whole periods (25 samples = 2 periods at 40 kHz)
    double sre = 0, sim = 0;
    for (int k = 0; k < n; k++) {
        double wt = 2 * M_PI * hz * k / fs;
        double s = floor(2048.5 + are * cos(wt) - aim * sin(wt));
        if (s < 0) s = 0;
        if (s > 4095) s = 4095;
        sre += (s - 2048) * cos(wt); sim -= (s - 2048) * sin(wt);
    }
    fc_cpx out = { n ? (float)(2 * sre / n) : 0, n ? (float)(2 * sim / n) : 0 };
    return out;
}

int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: p0sim <v_full> <transfer file>\n"); return 2; }
    v_full = (float)atof(argv[1]);
    FILE *f = fopen(argv[2], "rb");
    if (!f) return 2;
    uint16_t head[2];
    while (row_count < FC_MAX_RX && fread(head, 2, 2, f) == 2) {
        rows[row_count].gate = head[0];
        for (int c = 0; c < head[1]; c++) {
            float v[2];
            if (fread(v, 4, 2, f) != 2) return 2;
            if (c < FC_DRIVES) { rows[row_count].re[c] = v[0]; rows[row_count].im[c] = v[1]; }
        }
        row_count++;
    }
    fclose(f);
    static const fc_hal hal = { hal_write, hal_pattern, hal_wait, hal_begin, hal_lock_in, hal_air, hal_supply };
    fc_config cfg = { FC_DRIVES + 1, FC_DRIVES / 2, 0.046f, 39000, 41000, v_full, "SIM0001" };
    if (argc > 3) cfg.gap_m = (float)atof(argv[3]);
    fc_init(&hal, &cfg);
    int ch;
    while ((ch = getchar()) != EOF) fc_feed((uint8_t)ch);
    return 0;
}
