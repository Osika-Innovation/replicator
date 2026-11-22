// Lock-in for the HAPTIC and SMI receive paths. Nothing here touches a pin:
// the same file runs on the RP2350B and in tests/host_test.c.
//
// Three ways from a capture burst to one complex amplitude per comb tone:
//   lk_cic_burst()  1-bit stream -> adds-only sinc3 (CIC) decimate by 12 ->
//                   square add/subtract lock-in -> de-mix of the 1/3 and 1/5
//                   harmonics. The default 1-bit path (INS-28).
//   lk_xor_burst()  1-bit stream -> XOR/popcount against square references ->
//                   the same de-mix. Kept as the INS-01 baseline; it folds the
//                   shaped quantisation noise in from every odd harmonic.
//   lk_adc_burst()  AD7380 int16 samples -> sine-reference lock-in. No de-mix
//                   needed. The fallback path the SFDR gate triggered.
// All three return the phasor c of x(t) ~ Re(sum c exp(j w t)), t = 0 at the
// burst's first sample, in units of full scale (1-bit: +/-1; ADC: 32768).
#ifndef LOCKIN_XOR_H
#define LOCKIN_XOR_H
#include <stddef.h>
#include <stdint.h>

#define LK_MAX_TONES 5
#define LK_CIC_R 12                 // decimation: 75 MSa/s -> 6.25 MSa/s
#define LK_CIC_WARMUP_NIBBLES 9     // 3 R samples: the sinc3 has filled

typedef struct { float re, im; } lk_cpx;

typedef struct {
    int n;
    float hz[LK_MAX_TONES];         // ascending; integer multiples of hz[0] are de-mixed
} lk_tones;

// A capture word from haptic_sd_reader8 / smi_bank_reader holds four samples
// of eight channels: sample s in byte s, channel k in bit k. The four
// successive samples of channel `ch`, earliest in bit 0.
static inline unsigned lk_nibble(uint32_t word, int ch) {
    return (unsigned)((((word >> ch) & 0x01010101u) * 0x10204080u) >> 28);
}

// Channel `ch` of 8 capture words as one word of 32 successive samples.
uint32_t lk_pack_channel(const uint32_t raw[8], int ch);

// 32 successive samples of the square reference sign(cos) or sign(sin)
// (1 = positive) whose phase at the word's first sample is `phase`
// (2^32 = one turn), advancing `inc` per sample. inc < 2^27.
uint32_t lk_square_word(uint32_t phase, uint32_t inc, int quadrature);

// Sinc3 decimator state: three integrators at the input rate, three combs at
// the output rate. Wrapping uint32 arithmetic is exact (needs 11 bits).
typedef struct { uint32_t a, b, c, d1, d2, d3; } lk_cic;
void lk_cic_nibble(lk_cic *s, unsigned nibble);      // four input samples
uint32_t lk_cic_out(lk_cic *s);                      // after every LK_CIC_R samples: 0...R^3

// `raw`: n_words capture words (4 samples each) of 8 interleaved channels;
// fs: the sample rate (75e6). `inverted`: the stream is the feedback pin
// (NOT comparator), as the PIO readers record it. The burst should hold a
// whole number of periods of every tone after the warm-up; with
// LK_CIC_WARMUP_NIBBLES + DR_BURST_WORDS words it does for both comb sets.
void lk_cic_burst(const uint32_t *raw, size_t n_words, int ch, float fs, const lk_tones *t, int inverted, lk_cpx out[LK_MAX_TONES]);
void lk_xor_burst(const uint32_t *raw, size_t n_words, int ch, float fs, const lk_tones *t, int inverted, lk_cpx out[LK_MAX_TONES]);

// The raw square-reference estimates r[k] (before any filter correction)
// with the odd harmonics that are themselves comb tones taken out:
// r[k] -= (s Re r[m k] + j Im r[m k]) / m, s = -1 for m = 3, 7, ..., highest
// tone first. In place.
void lk_demix(const lk_tones *t, lk_cpx r[LK_MAX_TONES]);

// AD7380: four capture words of ad7380_x4 -> eight int16 samples.
void lk_adc_unpack(const uint32_t words[4], int16_t out[8]);
// n samples of one channel, `stride` apart, at rate fs.
void lk_adc_burst(const int16_t *x, size_t n, size_t stride, float fs, const lk_tones *t, lk_cpx out[LK_MAX_TONES]);

// DC occlusion of an SMI channel: the ones density of its stream, 0...1,
// in comparator sense.
float lk_ones_density(const uint32_t *raw, size_t n_words, int ch, int inverted);

// The two-stage OPA320 receiver of the SMI strip at `hz`: complex gain
// relative to its DC gain. One stage at x200 on a 20 MHz gain-bandwidth part
// has 100 kHz of bandwidth, half what the comb needs; two stages of
// sqrt(200) have 1.41 MHz each and 0.91 MHz together. Divide a LightRead
// phasor by this before using its phase.
lk_cpx smi_tia_response(float hz, float gain_total, float gbw_hz, int stages);
#endif
