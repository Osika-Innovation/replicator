// P0 controller core: everything that does not touch a pin.
// The same file runs on the RP2350 (pico_main.c) and on a computer
// (sim_main.c), where the twin tests it over a pipe: the frame log in,
// drive patterns out, records back. Wire formats: FieldCore `FCodeWire`
// and `RecordWire` (twin/Sources/FieldCore).
#ifndef FCORE_H
#define FCORE_H
#include <stddef.h>
#include <stdint.h>

#define FC_STEPS 512        // pattern steps per period: 0.7 degrees of phase each
#define FC_DRIVES 32        // drive outputs: one bit of a pattern word each
#define FC_MAX_CH 40        // channels on the wire: the drives, then listen-only gates
#define FC_MAX_RX 8
#define FC_MAX_TONES 1      // P0 plays one tone

typedef struct { float re, im; } fc_cpx;

// What the board must provide.
typedef struct {
    void (*write)(const uint8_t *bytes, size_t n);              // to the host
    // Start (or replace, at a period boundary) the pattern at `hz`.
    void (*set_pattern)(const uint32_t pattern[FC_STEPS], float hz);
    void (*wait_until_us)(uint32_t t_us);                       // since the stream began
    void (*stream_begin)(void);
    // Listen on rx gate `gate` (a wire channel number) for `us` microseconds and
    // return its complex amplitude at `hz`, phase measured against pattern step 0.
    fc_cpx (*lock_in)(int gate, float hz, uint32_t us);
    float (*air_celsius)(void);                                 // NaN if not fitted
    float (*supply_volts)(void);                                // NaN if not measured
} fc_hal;

typedef struct {
    uint16_t channels, per_plate;
    float gap_m, band_lo, band_hi;
    float v_full;           // face velocity (m/s, peak) at a 50 % duty cycle: from the element coupon
    const char *serial;
} fc_config;

void fc_init(const fc_hal *hal, const fc_config *cfg);
void fc_feed(uint8_t byte);                                     // every byte from the host
// One channel's drive (i16 fractions of `scale` m/s) as bits of the pattern.
void fc_pattern(const int16_t *re_im, int channels, float scale, float v_full, uint32_t pattern[FC_STEPS]);
uint32_t fc_crc32(const uint8_t *p, size_t n);
#endif
