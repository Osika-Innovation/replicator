// P0 controller on an RP2350B board (48 GPIO): the board side of fcore.h.
//
// COMPILED, NEVER FLASHED OR RUN (FIRMWARE.md): it builds for the RP2350B with
// the official SDK and toolchain, and no board has executed it. fcore.c is
// tested on a computer (sim_main.c, `fieldc p0 link`); this file is the part
// that test cannot reach. First bench task: check each numbered assumption
// below with an oscilloscope.
//
// Pins:  GPIO0–31   drive outputs, channel = GPIO number (0–15 lower plate, 16–31 upper)
//        GPIO40     ADC0: the probe receiver between this pin and GND (wire gate 32);
//                   the pad's own pull-up and pull-down together hold it at mid-rail
//        GPIO32/33  I2C0 SDA/SCL: TMP117 air-temperature sensor at 0x48
//        USB        CDC serial to the twin (`fieldc p0 job --port /dev/cu.usbmodem…`)
#include "fcore.h"
#include "p0.pio.h"
#include "hardware/adc.h"
#include "hardware/clocks.h"
#include "hardware/dma.h"
#include "hardware/i2c.h"
#include "hardware/pio.h"
#include "pico/stdlib.h"
#include <math.h>
#include <stdio.h>
#include <string.h>

static uint32_t ring[FC_STEPS] __attribute__((aligned(2048)));  // 512 words = 2^11 bytes: the DMA ring
static int dma_ch;
static uint sm = 0;
static absolute_time_t stream_t0;

static void hal_write(const uint8_t *b, size_t n) { fwrite(b, 1, n, stdout); fflush(stdout); }
static void hal_begin(void) { stream_t0 = get_absolute_time(); }
static void hal_wait(uint32_t t_us) { sleep_until(delayed_by_us(stream_t0, t_us)); }

// (1) A new pattern is copied into the live ring; for up to one period
// (25 µs) the pins play a mix of the old and the new.
static void hal_pattern(const uint32_t p[FC_STEPS], float hz) {
    pio_sm_set_clkdiv(pio0, sm, (float)clock_get_hz(clk_sys) / (hz * FC_STEPS));
    memcpy(ring, p, sizeof ring);
}

// (2) The phase reference is the ring position when sampling starts, read
// from the DMA read address; a fixed latency of a few steps is common to
// every channel and drops out of a calibration.
static fc_cpx hal_lock_in(int gate, float hz, uint32_t us) {
    (void)gate;                                                  // one gate: the probe on ADC0
    adc_select_input(0);
    const float fs = 500e3f;                                     // (3) free-running conversion, 96 cycles of 48 MHz
    int n = (int)(us * 1e-6f * fs);
    adc_fifo_drain();
    adc_run(true);
    uint32_t step0 = (dma_hw->ch[dma_ch].read_addr - (uintptr_t)ring) / 4;
    float ph0 = 2 * (float)M_PI * step0 / FC_STEPS, dph = 2 * (float)M_PI * hz / fs;
    float sre = 0, sim = 0, mean = 0;
    static uint16_t s[16384];
    if (n > 16384) n = 16384;
    for (int k = 0; k < n; k++) { s[k] = adc_fifo_get_blocking(); mean += s[k]; }
    adc_run(false);
    mean /= n;
    for (int k = 0; k < n; k++) { float a = ph0 + dph * k; sre += (s[k] - mean) * cosf(a); sim -= (s[k] - mean) * sinf(a); }
    fc_cpx out = { 2 * sre / n, 2 * sim / n };                   // ADC counts
    return out;
}

static float hal_air(void) {                                     // TMP117: 0.0078125 °C per count, register 0
    uint8_t reg = 0, raw[2];
    if (i2c_write_timeout_us(i2c0, 0x48, &reg, 1, true, 2000) != 1) return NAN;
    if (i2c_read_timeout_us(i2c0, 0x48, raw, 2, false, 2000) != 2) return NAN;
    return (int16_t)(raw[0] << 8 | raw[1]) * 0.0078125f;
}

static float hal_supply(void) { return NAN; }                    // not measured on the board: read it off the supply

int main(void) {
    stdio_init_all();
    adc_init(); adc_gpio_init(40);
    gpio_set_pulls(40, true, true);                              // (5) both pulls on: about 1.65 V of bias, no resistors
    adc_fifo_setup(true, false, 1, false, false);
    adc_set_clkdiv(0);
    i2c_init(i2c0, 400000);
    gpio_set_function(32, GPIO_FUNC_I2C); gpio_set_function(33, GPIO_FUNC_I2C);
    gpio_pull_up(32); gpio_pull_up(33);

    uint offset = pio_add_program(pio0, &p0_drive_program);
    pio_sm_config c = p0_drive_program_get_default_config(offset);
    for (uint pin = 0; pin < 32; pin++) pio_gpio_init(pio0, pin);
    pio_sm_set_consecutive_pindirs(pio0, sm, 0, 32, true);
    sm_config_set_out_pins(&c, 0, 32);
    sm_config_set_out_shift(&c, true, true, 32);                 // autopull a word per step
    sm_config_set_fifo_join(&c, PIO_FIFO_JOIN_TX);
    pio_sm_init(pio0, sm, offset, &c);

    dma_ch = dma_claim_unused_channel(true);
    dma_channel_config d = dma_channel_get_default_config(dma_ch);
    channel_config_set_transfer_data_size(&d, DMA_SIZE_32);
    channel_config_set_read_increment(&d, true);
    channel_config_set_write_increment(&d, false);
    channel_config_set_ring(&d, false, 11);                      // wrap the read address every 2^11 bytes
    channel_config_set_dreq(&d, pio_get_dreq(pio0, sm, true));
    // (4) an endless transfer on RP2350: the count's top bits select "endless" mode
    dma_channel_configure(dma_ch, &d, &pio0->txf[sm], ring, 0xF0000000u | 1, true);
    pio_sm_set_enabled(pio0, sm, true);

    static const fc_hal hal = { hal_write, hal_pattern, hal_wait, hal_begin, hal_lock_in, hal_air, hal_supply };
    // v_full: face velocity at a 50 % duty cycle, from the element coupon (HW-01);
    // until measured, the datasheet level at a 0–15 V square wave.
    fc_config cfg = { 33, 16, 0.046f, 39000, 41000, 1.52f, "P0-0001" };
    fc_init(&hal, &cfg);
    for (;;) { int ch = getchar_timeout_us(1000); if (ch >= 0) fc_feed((uint8_t)ch); }
}
