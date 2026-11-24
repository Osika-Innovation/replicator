#include "plinth_io.h"
#include <math.h>

// Lamina MCU, AD7380-only build: 35 of 48. GPIO 18-24 and 28-33 (the
// comparator and feedback pins of the one-bit path) are spare. With the
// one-bit path populated as well, 26 and 27 are FB_A and FB_B and the two
// extra enable groups have nowhere to go: three groups need this build.
// Plinth MCU: 21 of 48. USB is on the part's dedicated pins.
const pl_pin_span pl_pin_map[] = {
    { PL_MCU_LAMINA, 0, 12, "TX: 6 x (INA, INB)" },
    { PL_MCU_LAMINA, 12, 4, "spinal bus: D0, D1, FRAME out; FRAME in" },
    { PL_MCU_LAMINA, 16, 1, "SYNC" },
    { PL_MCU_LAMINA, 17, 1, "head-down interlock" },
    { PL_MCU_LAMINA, PL_LAMINA_EN_GPIO, 3, "bridge enable groups A, B, C" },
    { PL_MCU_LAMINA, 34, 2, "AD7380 SCLK, /CS" },
    { PL_MCU_LAMINA, 36, 8, "AD7380 SDOA/SDOB x 4" },
    { PL_MCU_LAMINA, 44, 2, "spinal bus D0, D1 in" },
    { PL_MCU_LAMINA, 46, 2, "I2C: TMP117 chamber air sensors" },
    { PL_MCU_PLINTH, 0, 3, "load cell DOUT: powder, liquid, seed" },
    { PL_MCU_PLINTH, 3, 1, "load cell SCK, shared" },
    { PL_MCU_PLINTH, 4, 3, "pump IN_A, IN_B, EN" },
    { PL_MCU_PLINTH, PL_PLINTH_HEAD_DOWN_GPIO, 1, "head-down interlock (second read of the switch)" },
    { PL_MCU_PLINTH, 8, 2, "I2C: humidity and temperature" },
    { PL_MCU_PLINTH, 10, 4, "gap actuator STEP, DIR, EN, HOME" },
    { PL_MCU_PLINTH, 14, 1, "SYNC" },
    { PL_MCU_PLINTH, 15, 6, "spinal bus" },
};
const size_t pl_pin_map_count = sizeof pl_pin_map / sizeof pl_pin_map[0];

int pl_pins_used(pl_mcu mcu) {
    uint64_t seen = 0; int used = 0;
    for (size_t i = 0; i < pl_pin_map_count; i++) {
        const pl_pin_span *p = &pl_pin_map[i];
        if (p->mcu != mcu) continue;
        if (p->count == 0 || p->gpio_first + p->count > PL_GPIO_COUNT) return -1;
        uint64_t m = ((1ull << p->count) - 1) << p->gpio_first;
        if (seen & m) return -1;
        seen |= m; used += p->count;
    }
    return used;
}

pl_config pl_default_config(void) {
    pl_config c = { 45.0f, 55.0f, 500, { 420.0f, 420.0f, 420.0f }, { 0, 0, 0 }, -50.0f, 3000.0f,
                    250.0f, 50.0f, 300, 0.5f, 6000, 500 };
    return c;
}

void pl_init(pl_state *s, const pl_config *c, const pl_hal *hal) {
    *s = (pl_state){ 0 };
    s->cfg = *c; s->hal = hal;
    if (hal && hal->pump) hal->pump(0);
}

static bool head_down(const pl_state *s) { return s->hal && s->hal->head_down && s->hal->head_down(); }
static void pump_set(pl_state *s, int dir) {
    s->pump = (int8_t)dir; s->pump_frames = 0;
    if (s->hal && s->hal->pump) s->hal->pump(dir);
}
static pl_fault trip(pl_state *s, pl_fault f) { pump_set(s, 0); s->fault = (uint8_t)f; return f; }

pl_result pl_rh_sample(pl_state *s, float rh, float temp_c) {
    if (!isfinite(rh) || !isfinite(temp_c) || rh < 0 || rh > 100) { s->rh_have = false; return PL_REFUSED_VALUE; }
    s->rh_pct = rh; s->temp_c = temp_c; s->rh_frame = s->frame; s->rh_have = true;
    s->rh_out_flag = rh < s->cfg.rh_lo_pct || rh > s->cfg.rh_hi_pct;
    return PL_OK;
}

pl_result pl_cell_sample(pl_state *s, int cell, int32_t counts) {
    if (cell < 0 || cell >= PL_CELLS || !(s->cfg.counts_per_g[cell] > 0)) return PL_REFUSED_VALUE;
    float g = (float)(counts - s->cfg.tare[cell]) / s->cfg.counts_per_g[cell];
    s->mass_g[cell] = g;
    if (g < s->cfg.cell_min_g || g > s->cfg.cell_max_g) { s->cell_ok &= (uint8_t)~(1u << cell); return PL_REFUSED_CELL; }
    s->cell_ok |= (uint8_t)(1u << cell);
    return PL_OK;
}

pl_result pl_gate(const pl_state *s, pl_op op) {
    if (s->fault) return PL_FAULT_LATCHED;
    if (!head_down(s)) return PL_REFUSED_HEAD_UP;
    if (op == PL_OP_MATTER_DRIVE) {
        if (!s->rh_have || s->frame - s->rh_frame > s->cfg.rh_stale_frames) return PL_REFUSED_RH_STALE;
        if (s->rh_pct < s->cfg.rh_lo_pct) return PL_REFUSED_RH_LOW;
        if (s->rh_pct > s->cfg.rh_hi_pct) return PL_REFUSED_RH_HIGH;
    }
    if (op == PL_OP_PUMP && !((s->cell_ok >> PL_CELL_LIQUID) & 1u)) return PL_REFUSED_CELL;
    return PL_OK;
}

pl_result pl_dose_begin(pl_state *s, float grams) {
    pl_result g = pl_gate(s, PL_OP_PUMP);
    if (g != PL_OK) return g;
    if (s->pump != PL_PUMP_OFF) return PL_REFUSED_BUSY;
    if (!isfinite(grams) || !(grams > 0) || grams > s->cfg.dose_max_g) return PL_REFUSED_VALUE;
    if (s->mass_g[PL_CELL_LIQUID] - grams < s->cfg.reserve_g) return PL_REFUSED_EMPTY;
    s->dose_target_g = grams; s->dose_start_g = s->mass_g[PL_CELL_LIQUID];
    pump_set(s, PL_PUMP_DOSE);
    return PL_OK;
}

pl_result pl_draw_back_begin(pl_state *s, uint16_t frames) {
    if (s->fault) return PL_FAULT_LATCHED;
    if (!head_down(s)) return PL_REFUSED_HEAD_UP;
    if (s->pump != PL_PUMP_OFF) return PL_REFUSED_BUSY;
    if (frames == 0 || frames > s->cfg.draw_back_max_frames) return PL_REFUSED_VALUE;
    s->draw_back_frames = frames;
    pump_set(s, PL_PUMP_DRAW_BACK);
    return PL_OK;
}

void pl_pump_stop(pl_state *s) { pump_set(s, 0); }

pl_fault pl_tick(pl_state *s) {
    s->frame++;
    if (s->pump == PL_PUMP_OFF) return (pl_fault)s->fault;
    if (!head_down(s)) return trip(s, PL_FAULT_HEAD_LIFT);
    s->pump_frames++;
    if (s->pump == PL_PUMP_DRAW_BACK) {
        if (s->pump_frames >= s->draw_back_frames) pump_set(s, 0);
        return (pl_fault)s->fault;
    }
    if (!((s->cell_ok >> PL_CELL_LIQUID) & 1u)) return trip(s, PL_FAULT_CELL);
    float gone = s->dose_start_g - s->mass_g[PL_CELL_LIQUID];
    if (gone >= s->dose_target_g) { s->last_dose_g = gone; s->doses++; pump_set(s, 0); return PL_FAULT_NONE; }
    if (s->pump_frames >= s->cfg.no_flow_frames && gone < s->cfg.no_flow_g) { s->last_dose_g = gone; return trip(s, PL_FAULT_NO_FLOW); }
    if (s->pump_frames >= s->cfg.dose_max_frames) { s->last_dose_g = gone; return trip(s, PL_FAULT_OVERRUN); }
    return PL_FAULT_NONE;
}

pl_result pl_clear_fault(pl_state *s) {
    if (!head_down(s)) return PL_REFUSED_HEAD_UP;
    s->fault = PL_FAULT_NONE;
    return PL_OK;
}
