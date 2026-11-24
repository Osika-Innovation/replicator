#include "lockin_xor.h"
#include <math.h>

#define LK_PI 3.14159265358979323846f

uint32_t lk_pack_channel(const uint32_t raw[8], int ch) {
    uint32_t w = 0;
    for (int i = 0; i < 8; i++) w |= (uint32_t)lk_nibble(raw[i], ch) << (4 * i);
    return w;
}

static inline unsigned popcount32(uint32_t v) {      // the M33 has no popcount instruction
    v = v - ((v >> 1) & 0x55555555u);
    v = (v & 0x33333333u) + ((v >> 2) & 0x33333333u);
    return (((v + (v >> 4)) & 0x0F0F0F0Fu) * 0x01010101u) >> 24;
}

// sign(cos) is positive in the first and last quarter turn; sign(sin) in the
// first half. Shifting cos's phase by a quarter turn makes both "top bit clear".
uint32_t lk_square_word(uint32_t phase, uint32_t inc, int quadrature) {
    uint32_t p = quadrature ? phase : phase + 0x40000000u;
    uint32_t first = p >> 31, last = (p + 31u * inc) >> 31;
    if (first == last) return first ? 0u : 0xFFFFFFFFu;      // no edge in this word (most words)
    int lo = 0, hi = 31;                                      // one edge: bisect for the first bit after it
    while (hi - lo > 1) {
        int mid = (lo + hi) / 2;
        if (((p + (uint32_t)mid * inc) >> 31) == first) lo = mid; else hi = mid;
    }
    uint32_t low_bits = (1u << hi) - 1u;                      // bits 0...hi-1 carry `first`
    return first ? ~low_bits : low_bits;
}

// Four samples x1...x4 (x1 in bit 0) through a += x; b += a; c += b:
//   a' = a + sum x
//   b' = b + 4a + (4 x1 + 3 x2 + 2 x3 + x4)
//   c' = c + 4b + 10a + (10 x1 + 6 x2 + 3 x3 + x4)
static const uint8_t S1[16] = { 0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4 };
static const uint8_t S2[16] = { 0, 4, 3, 7, 2, 6, 5, 9, 1, 5, 4, 8, 3, 7, 6, 10 };
static const uint8_t S3[16] = { 0, 10, 6, 16, 3, 13, 9, 19, 1, 11, 7, 17, 4, 14, 10, 20 };

void lk_cic_nibble(lk_cic *s, unsigned n) {
    uint32_t a = s->a, b = s->b;
    s->c += (b << 2) + (a << 3) + (a << 1) + S3[n];
    s->b = b + (a << 2) + S2[n];
    s->a = a + S1[n];
}

uint32_t lk_cic_out(lk_cic *s) {
    uint32_t y1 = s->c - s->d1; s->d1 = s->c;
    uint32_t y2 = y1 - s->d2; s->d2 = y1;
    uint32_t y3 = y2 - s->d3; s->d3 = y2;
    return y3;
}

static uint32_t phase_inc(float hz, float fs) { return (uint32_t)((double)hz / (double)fs * 4294967296.0 + 0.5); }

void lk_demix(const lk_tones *t, lk_cpx r[LK_MAX_TONES]) {
    for (int k = t->n - 1; k >= 0; k--) {
        for (int m = 3; m <= 9; m += 2) {
            for (int h = k + 1; h < t->n; h++) {
                if (fabsf(t->hz[h] - (float)m * t->hz[k]) > 0.5f) continue;
                float s = (m % 4 == 3) ? -1.0f : 1.0f;
                r[k].re -= s * r[h].re / (float)m;
                r[k].im -= r[h].im / (float)m;
            }
        }
    }
}

// The sinc3's gain and delay at hz, divided out of a raw estimate.
static lk_cpx cic_correct(lk_cpx r, float hz, float fs) {
    float x = LK_PI * hz / fs;
    float g = sinf(x * LK_CIC_R) / (LK_CIC_R * sinf(x));
    g = g * g * g;
    float ph = 2.0f * LK_PI * hz * 1.5f * (LK_CIC_R - 1) / fs;         // r = c g exp(-j ph)
    float cr = cosf(ph) / g, ci = sinf(ph) / g;
    lk_cpx o = { r.re * cr - r.im * ci, r.re * ci + r.im * cr };
    return o;
}

void lk_cic_burst(const uint32_t *raw, size_t n_words, int ch, float fs, const lk_tones *t, int inverted, lk_cpx out[LK_MAX_TONES]) {
    lk_cic s = { 0, 0, 0, 0, 0, 0 };
    uint32_t inc[LK_MAX_TONES], ph[LK_MAX_TONES];
    int32_t si[LK_MAX_TONES], sq[LK_MAX_TONES];
    const int32_t mid = LK_CIC_R * LK_CIC_R * LK_CIC_R / 2;
    for (int k = 0; k < t->n; k++) {
        inc[k] = phase_inc(t->hz[k], fs) * LK_CIC_R;
        // The first output kept is the one after sample index (W + R) - 1,
        // W = 4 * LK_CIC_WARMUP_NIBBLES.
        ph[k] = phase_inc(t->hz[k], fs) * (uint32_t)(4 * LK_CIC_WARMUP_NIBBLES + LK_CIC_R - 1);
        si[k] = sq[k] = 0;
    }
    size_t nibbles = 0, outputs = 0;
    for (size_t w = 0; w < n_words; w++) {
        lk_cic_nibble(&s, lk_nibble(raw[w], ch));
        if (++nibbles % (LK_CIC_R / 4) != 0) continue;
        int32_t y = (int32_t)lk_cic_out(&s) - mid;            // -R^3/2 ... R^3/2
        if (nibbles <= LK_CIC_WARMUP_NIBBLES) continue;
        for (int k = 0; k < t->n; k++) {
            si[k] += ((ph[k] + 0x40000000u) >> 31) ? -y : y;
            sq[k] += (ph[k] >> 31) ? -y : y;
            ph[k] += inc[k];
        }
        outputs++;
    }
    // y / (R^3/2) is the +/-1 signal; (I - jQ) pi/2 is its phasor.
    float scale = (inverted ? -1.0f : 1.0f) * (LK_PI / 2.0f) / ((float)mid * (float)(outputs ? outputs : 1));
    lk_cpx r[LK_MAX_TONES];
    for (int k = 0; k < t->n; k++) { r[k].re = scale * (float)si[k]; r[k].im = -scale * (float)sq[k]; }
    lk_demix(t, r);
    for (int k = 0; k < t->n; k++) out[k] = cic_correct(r[k], t->hz[k], fs);
}

void lk_xor_burst(const uint32_t *raw, size_t n_words, int ch, float fs, const lk_tones *t, int inverted, lk_cpx out[LK_MAX_TONES]) {
    uint32_t inc[LK_MAX_TONES], ph[LK_MAX_TONES];
    int32_t si[LK_MAX_TONES], sq[LK_MAX_TONES];
    for (int k = 0; k < t->n; k++) { inc[k] = phase_inc(t->hz[k], fs); ph[k] = 0; si[k] = sq[k] = 0; }
    size_t groups = n_words / 8;
    for (size_t g = 0; g < groups; g++) {
        uint32_t x = lk_pack_channel(raw + 8 * g, ch);
        for (int k = 0; k < t->n; k++) {
            // sum of (+/-1 x)(+/-1 ref) over 32 samples = 2 popcount(~(x ^ ref)) - 32
            si[k] += 2 * (int32_t)popcount32(~(x ^ lk_square_word(ph[k], inc[k], 0))) - 32;
            sq[k] += 2 * (int32_t)popcount32(~(x ^ lk_square_word(ph[k], inc[k], 1))) - 32;
            ph[k] += 32u * inc[k];
        }
    }
    float scale = (inverted ? -1.0f : 1.0f) * (LK_PI / 2.0f) / (float)(groups ? groups * 32 : 1);
    for (int k = 0; k < t->n; k++) { out[k].re = scale * (float)si[k]; out[k].im = -scale * (float)sq[k]; }
    lk_demix(t, out);
}

void lk_adc_unpack(const uint32_t words[4], int16_t out[8]) {
    // Shift left: within a word the first clock is the top byte, so a line's
    // four bits read as a nibble with the first clock as its top bit.
    for (int ch = 0; ch < 8; ch++) {
        uint32_t v = 0;
        for (int w = 0; w < 4; w++) v = (v << 4) | lk_nibble(words[w], ch);
        out[ch] = (int16_t)(uint16_t)v;
    }
}

void lk_adc_burst(const int16_t *x, size_t n, size_t stride, float fs, const lk_tones *t, lk_cpx out[LK_MAX_TONES]) {
    for (int k = 0; k < t->n; k++) {
        // exp(-j w n) by rotation: one multiply-accumulate pair per sample on the FPU.
        double w = 2.0 * 3.14159265358979323846 * (double)t->hz[k] / (double)fs;
        float cr = (float)cos(w), ci = (float)-sin(w), pr = 1.0f, pi = 0.0f, ar = 0.0f, ai = 0.0f;
        for (size_t i = 0; i < n; i++) {
            float v = (float)x[i * stride];
            ar += v * pr; ai += v * pi;
            float nr = pr * cr - pi * ci; pi = pr * ci + pi * cr; pr = nr;
            if ((i & 255u) == 255u) {                          // keep the rotor on the unit circle
                double a = w * (double)(i + 1);
                pr = (float)cos(a); pi = (float)-sin(a);
            }
        }
        float s = 2.0f / (32768.0f * (float)(n ? n : 1));
        out[k].re = s * ar; out[k].im = s * ai;
    }
}

float lk_ones_density(const uint32_t *raw, size_t n_words, int ch, int inverted) {
    uint32_t ones = 0;
    for (size_t w = 0; w < n_words; w++) ones += S1[lk_nibble(raw[w], ch)];
    float d = n_words ? (float)ones / (float)(4 * n_words) : 0.0f;
    return inverted ? 1.0f - d : d;
}

lk_cpx smi_tia_response(float hz, float gain_total, float gbw_hz, int stages) {
    float pole = gbw_hz / powf(gain_total, 1.0f / (float)stages);     // each stage's bandwidth
    lk_cpx h = { 1.0f, 0.0f };
    for (int i = 0; i < stages; i++) {                                 // 1 / (1 + j f / pole) per stage
        float x = hz / pole, d = 1.0f + x * x;
        lk_cpx n = { (h.re + h.im * x) / d, (h.im - h.re * x) / d };
        h = n;
    }
    return h;
}
