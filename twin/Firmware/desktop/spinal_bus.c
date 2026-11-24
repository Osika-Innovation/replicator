#include "spinal_bus.h"

uint32_t sb_crc32(const uint32_t *words, size_t n) {
    uint32_t c = 0xFFFFFFFFu;
    for (size_t i = 0; i < n; i++) {
        for (int b = 0; b < 4; b++) {
            c ^= (words[i] >> (8 * b)) & 0xFFu;
            for (int k = 0; k < 8; k++) c = (c >> 1) ^ (0xEDB88320u & (0u - (c & 1u)));
        }
    }
    return ~c;
}

size_t sb_encode(const sb_packet *p, uint32_t *out) {
    size_t n = 0;
    uint32_t *w = out + 1;
    w[n++] = SB_MAGIC | ((uint32_t)p->type << 8) | ((uint32_t)p->source << 16) | ((uint32_t)p->count << 24);
    w[n++] = p->downbeat;
    for (int i = 0; i < p->count; i++) w[n++] = (uint16_t)p->phasor[i].re | ((uint32_t)(uint16_t)p->phasor[i].im << 16);
    w[n] = sb_crc32(w, n); n++;
    out[0] = (uint32_t)(16 * n - 1);                           // 16 bit pairs per word
    return n + 1;
}

sb_result sb_decode(const uint32_t *w, size_t n, sb_packet *p) {
    if (n < 3) return SB_SHORT;
    if ((w[0] & 0xFFu) != SB_MAGIC) return SB_BAD_MAGIC;
    size_t count = w[0] >> 24;
    if (n < count + 3) return SB_SHORT;
    if (sb_crc32(w, count + 2) != w[count + 2]) return SB_BAD_CRC;
    p->type = (uint8_t)(w[0] >> 8); p->source = (uint8_t)(w[0] >> 16); p->count = (uint8_t)count; p->downbeat = w[1];
    for (size_t i = 0; i < count; i++) { p->phasor[i].re = (int16_t)(w[2 + i] & 0xFFFFu); p->phasor[i].im = (int16_t)(w[2 + i] >> 16); }
    return SB_OK;
}

float sb_bit_rate(float sys_clk_hz) { return 2.0f * sys_clk_hz / SB_BIT_PAIR_TICKS; }

int sb_sync_patch(uint16_t *prog, size_t n, unsigned gpio_base) {
    int changed = 0;
    for (size_t i = 0; i < n; i++) {
        // WAIT: 001 ddddd p ss iiiii; source 00 = GPIO.
        if ((prog[i] & 0xE060u) != 0x2000u) continue;
        uint16_t want = (uint16_t)((prog[i] & ~0x1Fu) | ((SB_SYNC_GPIO - gpio_base) & 0x1Fu));
        if (want != prog[i]) { prog[i] = want; changed++; }
    }
    return changed;
}

#ifdef SB_ON_DEVICE
// Written against pico-sdk 2.x and NOT yet compiled or run on a board.
#include "hardware/clocks.h"
#include "hardware/gpio.h"
#include "hardware/pll.h"
#include "hardware/xosc.h"

void sb_clock_init_xin(void) {
    // The XIN pin takes the star's 12.000 MHz square wave; the oscillator
    // block only buffers it. Run from it while the PLL is reprogrammed.
    xosc_init();
    clock_configure(clk_sys, CLOCKS_CLK_SYS_CTRL_SRC_VALUE_CLKSRC_CLK_SYS_AUX,
                    CLOCKS_CLK_SYS_CTRL_AUXSRC_VALUE_XOSC_CLKSRC, 12 * MHZ, 12 * MHZ);
    pll_init(pll_sys, 1, 1500 * MHZ, 5, 2);                    // reference divider 1: the VCO locks to XIN's own edges
    clock_configure(clk_sys, CLOCKS_CLK_SYS_CTRL_SRC_VALUE_CLKSRC_CLK_SYS_AUX,
                    CLOCKS_CLK_SYS_CTRL_AUXSRC_VALUE_CLKSRC_PLL_SYS, 150 * MHZ, 150 * MHZ);
}

static int sb_master;
void sb_sync_init(int master) {
    sb_master = master;
    gpio_init(SB_SYNC_GPIO);
    if (master) { gpio_put(SB_SYNC_GPIO, 0); gpio_set_dir(SB_SYNC_GPIO, GPIO_OUT); }
    else { gpio_set_dir(SB_SYNC_GPIO, GPIO_IN); gpio_disable_pulls(SB_SYNC_GPIO); }
}

void sb_sync_downbeat(void) {
    if (!sb_master) return;
    gpio_put(SB_SYNC_GPIO, 0);                                 // every program is in `wait 0`, then `wait 1`
    busy_wait_us_32(10);
    gpio_put(SB_SYNC_GPIO, 1);
}
#endif
