#include "pulse_shocklet.h"
#include <math.h>

uint32_t ps_ring_delays(const ps_vec *ports, int n, ps_vec target, float c, int order_m, float centre_hz, uint32_t *delay) {
    float t[FS_CHANNELS], latest = 0;
    if (n > FS_CHANNELS) n = FS_CHANNELS;
    for (int i = 0; i < n; i++) {
        float dx = ports[i].x - target.x, dy = ports[i].y - target.y, dz = ports[i].z - target.z;
        t[i] = sqrtf(dx * dx + dy * dy + dz * dz) / c;
        if (t[i] > latest) latest = t[i];
    }
    uint32_t longest = 0;
    for (int i = 0; i < n; i++) {
        float az = atan2f(ports[i].y - target.y, ports[i].x - target.x);
        if (az < 0) az += 2.0f * 3.14159265f;
        float wind = order_m ? (float)(order_m < 0 ? -order_m : order_m) * (order_m < 0 ? 2.0f * 3.14159265f - az : az) / (2.0f * 3.14159265f * centre_hz) : 0;
        delay[i] = (uint32_t)(((latest - t[i]) + wind) * (float)DR_SYS_CLK_HZ + 0.5f);     // the farthest port fires first
        if (delay[i] > longest) longest = delay[i];
    }
    return longest;
}

static void put(uint16_t *steps, size_t at, size_t n, size_t limit, int ch, int positive) {
    uint16_t bits = (uint16_t)(positive ? FS_STEP_INA(ch) : FS_STEP_INB(ch));
    for (size_t i = at; i < at + n && i < limit; i++) steps[i] = (uint16_t)((steps[i] & ~FS_STEP_MASK(ch)) | bits);
}

static fs_result admit(const fs_state *gate, uint64_t active_ticks, uint32_t repeat_ticks, float max_duty) {
    fs_result r = fs_gate(gate, 32767);                         // a burst is full drive
    if (r != FS_OK) return r;
    if (repeat_ticks && (float)active_ticks > max_duty * (float)repeat_ticks) return FS_REFUSED_DUTY;
    return FS_OK;
}

fs_result ps_toroidal_pulse(const fs_state *gate, int n, const uint32_t *delay, uint32_t half, uint32_t repeat_ticks,
                            float max_duty, uint16_t *steps, size_t n_ticks) {
    if (half < PS_MIN_HALF_TICKS) return FS_REFUSED_LEVEL;      // faster than the crystal answers
    fs_result r = admit(gate, 2ull * half, repeat_ticks, max_duty);
    if (r != FS_OK) return r;
    for (int ch = 0; ch < n && ch < FS_CHANNELS; ch++) {
        put(steps, delay[ch], half, n_ticks, ch, 1);
        put(steps, delay[ch] + half, half, n_ticks, ch, 0);
    }
    return FS_OK;
}

fs_result ps_time_reversal(const fs_state *gate, int n_ch, const int16_t *ir, size_t n, uint32_t tps, int16_t dead,
                           uint32_t repeat_ticks, float max_duty, uint16_t *steps, size_t n_ticks) {
    if (tps < PS_MIN_HALF_TICKS) return FS_REFUSED_LEVEL;
    uint64_t busiest = 0;
    for (int ch = 0; ch < n_ch; ch++) {
        uint64_t on = 0;
        for (size_t i = 0; i < n; i++) { int v = ir[(size_t)ch * n + i]; if (v > dead || v < -dead) on += tps; }
        if (on > busiest) busiest = on;
    }
    fs_result r = admit(gate, busiest, repeat_ticks, max_duty);
    if (r != FS_OK) return r;
    for (int ch = 0; ch < n_ch && ch < FS_CHANNELS; ch++) {
        for (size_t i = 0; i < n; i++) {
            int v = ir[(size_t)ch * n + (n - 1 - i)];
            if (v > dead) put(steps, i * tps, tps, n_ticks, ch, 1);
            else if (v < -dead) put(steps, i * tps, tps, n_ticks, ch, 0);
        }
    }
    return FS_OK;
}
