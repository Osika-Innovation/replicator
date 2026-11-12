#include "fcore.h"
#include <math.h>
#include <string.h>

static const fc_hal *H;
static fc_config C;
static uint8_t buf[16 + 2 * FC_MAX_RX + FC_MAX_TONES * (8 + 4 * FC_MAX_CH) + 8];
static size_t have, need;
static enum { IDLE, HEADER, FRAME_HEAD, FRAME_BODY } state;
static uint32_t frames_left;
static uint8_t reply[12 + 512 * 40];                       // a job of 512 frames, one gate listening
static size_t reply_n;
static uint32_t reply_frames;

uint32_t fc_crc32(const uint8_t *p, size_t n) {
    uint32_t c = 0xFFFFFFFFu;
    for (size_t i = 0; i < n; i++) {
        c ^= p[i];
        for (int k = 0; k < 8; k++) c = (c & 1) ? 0xEDB88320u ^ (c >> 1) : c >> 1;
    }
    return ~c;
}

static void put(uint8_t *out, size_t *n, const void *v, size_t size) { memcpy(out + *n, v, size); *n += size; }
static uint16_t u16(const uint8_t *p) { return (uint16_t)(p[0] | p[1] << 8); }
static uint32_t u32(const uint8_t *p) { return p[0] | p[1] << 8 | p[2] << 16 | (uint32_t)p[3] << 24; }
static float f32(const uint8_t *p) { float f; memcpy(&f, p, 4); return f; }

void fc_init(const fc_hal *hal, const fc_config *cfg) { H = hal; C = *cfg; state = IDLE; have = 0; need = 4; }

// A channel is high for w steps centred on its phase: the fundamental of that
// pulse train is sin(pi w / N) of the full square wave's, at the pulse centre.
void fc_pattern(const int16_t *re_im, int channels, float scale, float v_full, uint32_t pattern[FC_STEPS]) {
    memset(pattern, 0, FC_STEPS * sizeof(uint32_t));
    for (int c = 0; c < channels && c < FC_DRIVES; c++) {
        float re = re_im[2 * c] / 32767.0f * scale, im = re_im[2 * c + 1] / 32767.0f * scale;
        float a = sqrtf(re * re + im * im) / v_full;
        if (a <= 0) continue;
        if (a > 1) a = 1;
        int w = (int)lroundf(asinf(a) / (float)M_PI * FC_STEPS);
        if (w < 1) continue;                                    // below one step: off
        float centre = -atan2f(im, re) / (2 * (float)M_PI) * FC_STEPS;
        int k0 = (int)lroundf(centre - w / 2.0f);
        for (int k = 0; k < w; k++) pattern[((k0 + k) % FC_STEPS + FC_STEPS) % FC_STEPS] |= 1u << c;
    }
}

static void send_info(void) {
    uint8_t out[64 + 255]; size_t n = 0;
    float t = H->air_celsius(), v = H->supply_volts();
    uint8_t len = (uint8_t)strlen(C.serial);
    put(out, &n, "FCI1", 4); put(out, &n, &C.channels, 2); put(out, &n, &C.per_plate, 2);
    put(out, &n, &C.gap_m, 4); put(out, &n, &C.band_lo, 4); put(out, &n, &C.band_hi, 4);
    put(out, &n, &t, 4); put(out, &n, &v, 4); put(out, &n, &len, 1); put(out, &n, C.serial, len);
    uint32_t crc = fc_crc32(out, n); put(out, &n, &crc, 4);
    H->write(out, n);
}

// One complete frame is in buf: play it, and listen if it asks.
static void play_frame(void) {
    uint16_t tones = u16(buf + 2), rx = u16(buf + 12);
    uint32_t t_us = u32(buf + 4), dur_us = u32(buf + 8);
    const uint8_t *p = buf + 14 + 2 * rx;
    uint32_t pattern[FC_STEPS];
    float hz = f32(p), scale = f32(p + 4);
    int16_t d[2 * FC_MAX_CH];
    memcpy(d, p + 8, 4u * C.channels);
    fc_pattern(d, C.channels, scale, C.v_full, pattern);
    H->wait_until_us(t_us);
    H->set_pattern(pattern, hz);
    size_t start = reply_n; uint8_t mark[2] = { 0x5A, 0 };
    uint16_t heard = rx ? tones : 0;                             // a frame that does not listen records no tone
    put(reply, &reply_n, mark, 2); put(reply, &reply_n, &heard, 2); put(reply, &reply_n, &t_us, 4);
    put(reply, &reply_n, &rx, 2); put(reply, &reply_n, buf + 14, 2u * rx);
    if (rx) put(reply, &reply_n, &hz, 4);
    for (int g = 0; g < rx; g++) {
        fc_cpx v = H->lock_in(u16(buf + 14 + 2 * g), hz, dur_us / (rx ? rx : 1));
        put(reply, &reply_n, &v, 8);
    }
    uint32_t crc = fc_crc32(reply + start, reply_n - start); put(reply, &reply_n, &crc, 4);
    reply_frames++;
    H->wait_until_us(t_us + dur_us);
}

static void finish_stream(void) {
    uint32_t off[FC_STEPS] = { 0 };
    H->set_pattern(off, C.band_lo);                              // every stream ends with the drive off
    memcpy(reply, "FCR1", 4); memcpy(reply + 4, &reply_frames, 4);
    uint32_t crc = fc_crc32(reply, 8); memcpy(reply + 8, &crc, 4);
    H->write(reply, reply_n);
}

static void refuse(void) { H->write((const uint8_t *)"FCE1", 4); state = IDLE; have = 0; need = 4; }

void fc_feed(uint8_t byte) {
    buf[have++] = byte;
    if (have < need) return;
    switch (state) {
    case IDLE:
        if (!memcmp(buf, "FCQ1", 4)) { send_info(); have = 0; }
        else if (!memcmp(buf, "FCD1", 4)) { state = HEADER; need = 24; }
        else { memmove(buf, buf + 1, 3); have = 3; }             // hunt for a magic word
        break;
    case HEADER:
        if (u32(buf + 20) != fc_crc32(buf, 20) || u16(buf + 6) != C.channels) { refuse(); break; }
        frames_left = u32(buf + 16);
        reply_n = 12; reply_frames = 0;
        H->stream_begin();
        have = 0; need = 14; state = FRAME_HEAD;
        if (frames_left == 0) { finish_stream(); state = IDLE; need = 4; }
        break;
    case FRAME_HEAD: {
        uint16_t tones = u16(buf + 2), rx = u16(buf + 12);
        if (buf[0] != 0xA5 || tones != FC_MAX_TONES || rx > FC_MAX_RX) { refuse(); break; }
        need = 14 + 2u * rx + tones * (8 + 4u * C.channels) + 4;
        state = FRAME_BODY;
        break;
    }
    case FRAME_BODY:
        if (u32(buf + need - 4) != fc_crc32(buf, need - 4)) { refuse(); break; }
        if (reply_n + 22 + 10u * u16(buf + 12) > sizeof reply) { refuse(); break; }   // more frames than the reply holds
        play_frame();
        have = 0; need = 14; state = FRAME_HEAD;
        if (--frames_left == 0) { finish_stream(); state = IDLE; need = 4; }
        break;
    }
}
