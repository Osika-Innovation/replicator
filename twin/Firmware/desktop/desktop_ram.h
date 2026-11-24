// Static RAM of the Card 1 brain with everything added since #77, counted as
// if one MCU carried all of it (the plinth and lock state may end up on the
// plinth MCU: then this over-counts). Flash images are not RAM.
#ifndef DESKTOP_RAM_H
#define DESKTOP_RAM_H
#include "bench_gate0.h"
#include "cadence_sparse_q8.h"
#include "frame_scheduler.h"
#include "plinth_io.h"
#include "resonance_lock.h"
#define DR_RAM_STATIC_BYTES (sizeof(csq8_work) + sizeof(lmq8_slot) + sizeof(fs_state) + sizeof(rl_state) + sizeof(bg0_sweep) + sizeof(pl_state))
_Static_assert(DR_RAM_STATIC_BYTES < DR_CADENCE_SPARSE_MAX_BYTES,
               "settle state + live-M calibration + scheduler + resonance lock + Bench Gate 0 + plinth must stay under 60 kB of RAM");
#endif
