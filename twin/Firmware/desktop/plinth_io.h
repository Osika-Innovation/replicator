// Lower cylindrical plinth I/O (INS-40 unified stack, CAD #84, INS-31):
// three bottle load cells, the reversible metering pump, the humidity
// sensor, and the pins for them, for the gap actuator and for the three
// enable groups of a lamina.
//
// Interlocks, each its own rule:
//   pump         runs only with the head down. A missing reader is an open
//                head. If the head lifts while it runs: pump off, fault
//                latched until cleared with the head down.
//   humidity     a drive that will carry matter starts only at 45-55 % RH
//                (INS-31: with a grounded bleed path that keeps a bead under
//                0.2 pC) from a reading no older than rh_stale_frames. It is
//                a start gate and a flag, not a trip: dropping the field
//                under a bead because the air dried would drop the bead.
//                The empty-chamber sweep (Bench Gate 0) does not need it.
//   load cells   a dose is metered by loss of weight of the liquid bottle
//                and stops at the target, at a cell that stops answering, at
//                no loss of weight (dry line, stalled pump) or at a time
//                limit; the last three latch a fault.
// This is the firmware half. The pump driver's enable should also run
// through the head-down switch in hardware, as the bridge enables do.
//
// Parts are OPEN (CAD #84: "parts are OPEN, no pins assigned"). ASSUMED
// here: HX711-class 24-bit bridge ADCs with one shared clock, a two-input
// reversible pump bridge with an enable, an I2C humidity sensor, a
// step/direction gap actuator. Nothing has run on a board.
#ifndef PLINTH_IO_H
#define PLINTH_IO_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define PL_CELLS 3
typedef enum { PL_CELL_POWDER = 0, PL_CELL_LIQUID = 1, PL_CELL_SEED = 2 } pl_cell;

// ------------------------------------------------------------------ pins
typedef enum { PL_MCU_LAMINA = 0, PL_MCU_PLINTH = 1 } pl_mcu;
typedef struct { uint8_t mcu, gpio_first, count; const char *use; } pl_pin_span;
// The whole budget: the lamina MCU in its AD7380-only build (INS-28 fallback
// triggered: the 16 one-bit pins are not populated) and the plinth MCU.
extern const pl_pin_span pl_pin_map[];
extern const size_t pl_pin_map_count;
#define PL_GPIO_COUNT 48
// Pins used on one MCU; -1 if two spans overlap or one leaves 0...47.
int pl_pins_used(pl_mcu mcu);
#define PL_LAMINA_EN_GPIO 25      // enable groups A, B, C on 25, 26, 27
#define PL_PLINTH_HEAD_DOWN_GPIO 7

// ------------------------------------------------------------------ interlocks
typedef enum {
    PL_OK = 0, PL_REFUSED_HEAD_UP, PL_REFUSED_RH_LOW, PL_REFUSED_RH_HIGH, PL_REFUSED_RH_STALE,
    PL_REFUSED_CELL, PL_REFUSED_EMPTY, PL_REFUSED_VALUE, PL_REFUSED_BUSY, PL_FAULT_LATCHED
} pl_result;
typedef enum { PL_FAULT_NONE = 0, PL_FAULT_HEAD_LIFT, PL_FAULT_NO_FLOW, PL_FAULT_OVERRUN, PL_FAULT_CELL } pl_fault;
typedef enum {
    PL_OP_EMPTY_SWEEP = 0,   // full drive in an empty chamber: head down
    PL_OP_MATTER_DRIVE,      // a drive that will carry matter: head down and humidity
    PL_OP_PUMP               // head down and the liquid bottle's cell answering
} pl_op;
typedef enum { PL_PUMP_OFF = 0, PL_PUMP_DOSE = 1, PL_PUMP_DRAW_BACK = -1 } pl_pump_dir;

typedef struct {
    bool (*head_down)(void);         // true = chamber closed
    void (*pump)(int dir);           // +1 dose, -1 draw back, 0 off (enable low)
} pl_hal;

typedef struct {
    float rh_lo_pct, rh_hi_pct;      // 45, 55 (electrostatics_and_matter_loop.chamber_ambient_rh_pct_range)
    uint16_t rh_stale_frames;        // 500 = 5 s
    float counts_per_g[PL_CELLS];    // ASSUMED 420 (HX711 at gain 128 on a 3 kg cell, 1 mV/V)
    int32_t tare[PL_CELLS];          // counts with the empty cradle
    float cell_min_g, cell_max_g;    // a reading outside is not a bottle: -50 g, 3000 g
    float reserve_g;                 // a dose may not take the bottle below this (bottle and cap, empty)
    float dose_max_g;                // largest single dose
    uint16_t no_flow_frames;         // after this long ...
    float no_flow_g;                 // ... at least this much must have left the bottle
    uint16_t dose_max_frames;        // time limit of one dose
    uint16_t draw_back_max_frames;   // a draw back is timed, not weighed
} pl_config;

typedef struct {
    pl_config cfg;
    const pl_hal *hal;
    uint32_t frame, rh_frame;
    float rh_pct, temp_c;
    float mass_g[PL_CELLS];
    uint8_t cell_ok;                 // bit i: cell i gave a plausible reading
    bool rh_have, rh_out_flag;       // rh_out_flag: humidity left the range (cleared by a reading back inside)
    int8_t pump;                     // pl_pump_dir
    uint8_t fault;                   // pl_fault
    float dose_target_g, dose_start_g, last_dose_g;
    uint16_t pump_frames, draw_back_frames;
    uint32_t doses;
} pl_state;

pl_config pl_default_config(void);
void pl_init(pl_state *s, const pl_config *c, const pl_hal *hal);
// A humidity reading. Not finite or outside 0...100 % forgets the sensor.
pl_result pl_rh_sample(pl_state *s, float rh_pct, float temp_c);
// A load cell reading in ADC counts. Returns PL_REFUSED_CELL and marks the
// cell if the mass is outside cell_min_g...cell_max_g.
pl_result pl_cell_sample(pl_state *s, int cell, int32_t counts);
// May this start now?
pl_result pl_gate(const pl_state *s, pl_op op);
// Dose `grams` from the liquid bottle, metered by its loss of weight.
pl_result pl_dose_begin(pl_state *s, float grams);
// Run the pump backwards for `frames` (draw the crucible back).
pl_result pl_draw_back_begin(pl_state *s, uint16_t frames);
void pl_pump_stop(pl_state *s);
// Once per 10 ms frame. Returns the fault it holds (PL_FAULT_NONE if none).
pl_fault pl_tick(pl_state *s);
// Only with the head down.
pl_result pl_clear_fault(pl_state *s);
#endif
