#include "cadence_sparse_q8.h"
#include <string.h>

void csq_init(csq_net *n, uint8_t shift, uint8_t threshold) {
    memset(n, 0, sizeof *n);
    n->shift = shift; n->threshold = threshold;
    for (int b = 0; b < CSQ_NB; b++) { n->blk_i[b] = n->blk_j[b] = (uint8_t)b; }   // the diagonal blocks, always present
    n->n_blocks = CSQ_NB;
    csq_link(n);
}

int csq_add_block(csq_net *n, int bi, int bj) {
    if (bi > bj) { int t = bi; bi = bj; bj = t; }
    if (bi < 0 || bj >= CSQ_NB) return -1;
    for (int b = 0; b < n->n_blocks; b++) if (n->blk_i[b] == bi && n->blk_j[b] == bj) return b;
    if (n->n_blocks >= CSQ_MAX_BLOCKS) return -1;
    int b = n->n_blocks++;
    n->blk_i[b] = (uint8_t)bi; n->blk_j[b] = (uint8_t)bj;
    memset(n->w[b], 0, sizeof n->w[b]);
    return b;
}

void csq_link(csq_net *n) {
    uint16_t count[CSQ_NB + 1];
    memset(count, 0, sizeof count);
    for (int b = 0; b < n->n_blocks; b++) {
        count[n->blk_j[b]]++;                                   // as stored: source j
        if (n->blk_i[b] != n->blk_j[b]) count[n->blk_i[b]]++;   // transposed: source i
    }
    uint16_t at = 0;
    for (int j = 0; j < CSQ_NB; j++) { n->col_ptr[j] = at; at = (uint16_t)(at + count[j]); count[j] = n->col_ptr[j]; }
    n->col_ptr[CSQ_NB] = at;
    for (int b = 0; b < n->n_blocks; b++) {
        n->link[count[n->blk_j[b]]++] = (uint16_t)b;
        if (n->blk_i[b] != n->blk_j[b]) n->link[count[n->blk_i[b]]++] = (uint16_t)(b | 0x8000);
    }
}

float csq_density(const csq_net *n) {
    return (float)(CSQ_NB + 2 * (n->n_blocks - CSQ_NB)) / (float)(CSQ_NB * CSQ_NB);
}

void csq_set_input(csq_net *n, int unit, int re, int im) {
    n->in_re[unit] = (int16_t)re; n->in_im[unit] = (int16_t)im;
    n->dirty[unit / CSQ_B] = 1;
}

void csq_reset_state(csq_net *n) {
    memset(n->s, 0, sizeof n->s); memset(n->sent, 0, sizeof n->sent);
    memset(n->u_re, 0, sizeof n->u_re); memset(n->u_im, 0, sizeof n->u_im);
    memset(n->dirty, 1, sizeof n->dirty);
    n->block_pushes = n->sweeps = 0;
}

static inline int clip7(int32_t v) { return v > 127 ? 127 : (v < -127 ? -127 : (int)v); }

// Source block J changed by d[8] (Q7): add W[:, J] d to u for every linked block.
static void push_block(csq_net *n, int J, const int16_t dre[CSQ_B], const int16_t dim[CSQ_B]) {
    for (int l = n->col_ptr[J]; l < n->col_ptr[J + 1]; l++) {
        int b = n->link[l] & 0x7FFF, transposed = n->link[l] >> 15;
        const csq_c8 (*w)[CSQ_B] = n->w[b];
        int I = transposed ? n->blk_j[b] : n->blk_i[b];
        int32_t *ur = n->u_re + I * CSQ_B, *ui = n->u_im + I * CSQ_B;
        for (int r = 0; r < CSQ_B; r++) {
            int32_t ar = 0, ai = 0;
            for (int c = 0; c < CSQ_B; c++) {
                // as stored: W[r][c]; transposed: conj(W[c][r])
                int wr = transposed ? w[c][r].re : w[r][c].re;
                int wi = transposed ? -w[c][r].im : w[r][c].im;
                ar += wr * dre[c] - wi * dim[c];
                ai += wr * dim[c] + wi * dre[c];
            }
            ur[r] += ar; ui[r] += ai;
        }
        n->block_pushes++;
    }
}

int csq_relax(csq_net *n, int max_sweeps) {
    int sweep = 0;
    for (; sweep < max_sweeps; sweep++) {
        int any = 0;
        // 1. Units that moved past the threshold announce their change (events).
        for (int J = 0; J < CSQ_NB; J++) {
            if (!n->dirty[J]) continue;
            int16_t dre[CSQ_B], dim[CSQ_B]; int moved = 0;
            for (int c = 0; c < CSQ_B; c++) {
                int u = J * CSQ_B + c;
                int dr = n->s[u].re - n->sent[u].re, di = n->s[u].im - n->sent[u].im;
                int big = (dr > n->threshold || -dr > n->threshold || di > n->threshold || -di > n->threshold);
                dre[c] = (int16_t)(big ? dr : 0); dim[c] = (int16_t)(big ? di : 0);
                if (big) { n->sent[u] = n->s[u]; moved = 1; }
            }
            if (moved) { push_block(n, J, dre, dim); any = 1; }
        }
        // 2. Every unit takes its new state from its input and what it has been told.
        int changed = 0;
        for (int I = 0; I < CSQ_NB; I++) {
            int d = 0;
            for (int r = 0; r < CSQ_B; r++) {
                int u = I * CSQ_B + r;
                int re = clip7(n->in_re[u] + (n->u_re[u] >> (7 + n->shift)));
                int im = clip7(n->in_im[u] + (n->u_im[u] >> (7 + n->shift)));
                int dr = re - n->sent[u].re, di = im - n->sent[u].im;
                if (dr > n->threshold || -dr > n->threshold || di > n->threshold || -di > n->threshold) d = 1;
                n->s[u].re = (int8_t)re; n->s[u].im = (int8_t)im;
            }
            n->dirty[I] = (uint8_t)d; changed |= d;
        }
        n->sweeps++;
        if (!any && !changed) break;
    }
    return sweep;
}

static inline int8_t sat8(int32_t v) { return (int8_t)(v > 127 ? 127 : (v < -127 ? -127 : v)); }

void csq_eqprop_update(csq_net *n, const csq_c8 *s0, int lr_shift) {
    const csq_c8 *s1 = n->s;
    int32_t half = lr_shift > 0 ? (1 << (lr_shift - 1)) : 0;
    for (int b = 0; b < n->n_blocks; b++) {
        int I = n->blk_i[b] * CSQ_B, J = n->blk_j[b] * CSQ_B;
        for (int r = 0; r < CSQ_B; r++) {
            for (int c = 0; c < CSQ_B; c++) {
                if (I == J && c < r) continue;                // lower half of a diagonal block: mirrored below
                // s_i conj(s_j)
                int32_t p1r = s1[I + r].re * s1[J + c].re + s1[I + r].im * s1[J + c].im;
                int32_t p1i = s1[I + r].im * s1[J + c].re - s1[I + r].re * s1[J + c].im;
                int32_t p0r = s0[I + r].re * s0[J + c].re + s0[I + r].im * s0[J + c].im;
                int32_t p0i = s0[I + r].im * s0[J + c].re - s0[I + r].re * s0[J + c].im;
                int32_t dr = (p1r - p0r + half) >> lr_shift, di = (p1i - p0i + half) >> lr_shift;
                csq_c8 *w = &n->w[b][r][c];
                w->re = sat8(w->re + dr);
                w->im = (I == J && r == c) ? 0 : sat8(w->im + di);     // a Hermitian diagonal is real
                if (I == J && c > r) { n->w[b][c][r].re = w->re; n->w[b][c][r].im = (int8_t)-w->im; }
            }
        }
    }
    // The announced state no longer matches u = W sent: start the next relax clean.
    csq_c8 keep[CSQ_N]; memcpy(keep, n->s, sizeof keep);
    csq_reset_state(n);
    memcpy(n->s, keep, sizeof keep);
}

float csq_norm_bound(const csq_net *n) {
    uint32_t row[CSQ_N];
    memset(row, 0, sizeof row);
    for (int b = 0; b < n->n_blocks; b++) {
        int I = n->blk_i[b] * CSQ_B, J = n->blk_j[b] * CSQ_B;
        for (int r = 0; r < CSQ_B; r++) for (int c = 0; c < CSQ_B; c++) {
            int wr = n->w[b][r][c].re, wi = n->w[b][r][c].im;
            uint32_t a = (uint32_t)((wr < 0 ? -wr : wr) + (wi < 0 ? -wi : wi));       // >= |w|
            row[I + r] += a;
            if (I != J) row[J + c] += a;
        }
    }
    uint32_t worst = 0;
    for (int i = 0; i < CSQ_N; i++) if (row[i] > worst) worst = row[i];
    return (float)worst / (float)(1u << (7 + n->shift));
}

int csq_renormalise(csq_net *n, float limit) {
    while (csq_norm_bound(n) > limit && n->shift < 16) n->shift++;
    return n->shift;
}

float csq_settle_ms(const csq_net *n, float cycles_per_push, float f_cpu_hz) {
    return 1e3f * (float)n->block_pushes * cycles_per_push / f_cpu_hz;
}

// ------------------------------------------------------------------ CSQ8 v1
#include <math.h>
#include <string.h>

static uint16_t rd16(const uint8_t *p) { return (uint16_t)(p[0] | (p[1] << 8)); }
static float rdf32(const uint8_t *p) {
    uint32_t u = (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
    float f; memcpy(&f, &u, 4); return f;
}
static void wr16(uint8_t *p, uint16_t v) { p[0] = (uint8_t)v; p[1] = (uint8_t)(v >> 8); }
static void wrf32(uint8_t *p, float f) {
    uint32_t u; memcpy(&u, &f, 4);
    p[0] = (uint8_t)u; p[1] = (uint8_t)(u >> 8); p[2] = (uint8_t)(u >> 16); p[3] = (uint8_t)(u >> 24);
}
static float rdf16(const uint8_t *p) {
    unsigned h = rd16(p), e = (h >> 10) & 31u, m = h & 1023u;
    float v = e == 0 ? ldexpf((float)m, -24) : e == 31 ? (m ? NAN : INFINITY) : ldexpf((float)(m | 1024u), (int)e - 25);
    return (h & 0x8000u) ? -v : v;
}

static size_t matrix_bytes(const csq8_matrix *m) { return 2u + 2u * (m->n_brows + 1u) + m->n_blocks + 128u * m->n_blocks; }

static csq8_status load_matrix(const uint8_t *blob, size_t len, size_t *off, csq8_matrix *m) {
    if (*off + 2 > len) return CSQ8_SHORT;
    m->n_blocks = rd16(blob + *off);
    if ((uint32_t)m->n_blocks > (uint32_t)m->n_brows * m->n_bcols) return CSQ8_BAD_INDEX;
    if (*off + matrix_bytes(m) > len) return CSQ8_SHORT;
    m->row_ptr = blob + *off + 2;
    m->col = m->row_ptr + 2u * (m->n_brows + 1u);
    m->tile = (const int8_t *)(m->col + m->n_blocks);
    if (rd16(m->row_ptr) != 0 || rd16(m->row_ptr + 2u * m->n_brows) != m->n_blocks) return CSQ8_BAD_INDEX;
    for (unsigned r = 0; r < m->n_brows; r++) {
        unsigned a = rd16(m->row_ptr + 2 * r), b = rd16(m->row_ptr + 2 * r + 2);
        if (b < a || b > m->n_blocks) return CSQ8_BAD_INDEX;
        for (unsigned k = a; k < b; k++)
            if (m->col[k] >= m->n_bcols || (k > a && m->col[k] <= m->col[k - 1])) return CSQ8_BAD_INDEX;
    }
    *off += matrix_bytes(m);
    return CSQ8_OK;
}

csq8_status csq8_load(const uint8_t *blob, size_t len, csq8_image *img) {
    memset(img, 0, sizeof *img);
    if (len < CSQ8_HEADER_BYTES) return CSQ8_SHORT;
    if (memcmp(blob, "CSQ8", 4) != 0) return CSQ8_BAD_MAGIC;
    if (rd16(blob + 4) != 1) return CSQ8_BAD_VERSION;
    if (blob[12] != CSQ_B) return CSQ8_BAD_BLOCK;
    img->n_in = rd16(blob + 6); img->n_h = rd16(blob + 8); img->n_o = rd16(blob + 10);
    img->steps = blob[13];
    img->alpha = rdf32(blob + 14); img->drive_scale = rdf32(blob + 18); img->delta_thr = rdf32(blob + 22);
    img->ih.scale = rdf32(blob + 26); img->ho.scale = rdf32(blob + 30);
    if (!img->n_in || !img->n_h || !img->n_o || img->n_h % CSQ_B) return CSQ8_BAD_SHAPE;
    img->n_in_p = (uint16_t)((img->n_in + CSQ_B - 1) / CSQ_B * CSQ_B);
    img->n_o_p = (uint16_t)((img->n_o + CSQ_B - 1) / CSQ_B * CSQ_B);
    if (img->n_in_p > CSQ8_MAX_NIN || img->n_h > CSQ8_MAX_NH || img->n_o_p > CSQ8_MAX_NO) return CSQ8_BAD_SHAPE;
    if (4u * img->n_h + 3u * img->n_o_p > CSQ8_STATE_UNITS) return CSQ8_BAD_SHAPE;      // would not fit csq8_work's pool
    // not-a-number fails every comparison, so these also reject NaN
    if (!(img->alpha > 0 && img->alpha <= 1) || !img->steps || !(img->delta_thr >= 0 && img->delta_thr < 1e3f) ||
        !(fabsf(img->drive_scale) < 1e6f) || !(img->ih.scale > 0 && img->ih.scale < 1e3f) || !(img->ho.scale > 0 && img->ho.scale < 1e3f))
        return CSQ8_BAD_VALUE;
    img->ih.n_brows = img->ho.n_brows = (uint16_t)(img->n_h / CSQ_B);
    img->ih.n_bcols = (uint16_t)(img->n_in_p / CSQ_B); img->ho.n_bcols = (uint16_t)(img->n_o_p / CSQ_B);
    size_t off = CSQ8_HEADER_BYTES;
    csq8_status st;
    if ((st = load_matrix(blob, len, &off, &img->ih)) != CSQ8_OK) return st;
    if ((st = load_matrix(blob, len, &off, &img->ho)) != CSQ8_OK) return st;
    if (off + 4u * img->n_o_p > len) return CSQ8_SHORT;
    img->bias = blob + off; off += 4u * img->n_o_p;
    for (unsigned i = 0; i < 2u * img->n_o_p; i++) if (!isfinite(rdf16(img->bias + 2 * i))) return CSQ8_BAD_VALUE;
    if (off != len) return CSQ8_TRAILING;
    img->bytes = off;
    return CSQ8_OK;
}

size_t csq8_store(const csq8_image *img, uint8_t *out, size_t cap) {
    size_t need = CSQ8_HEADER_BYTES + matrix_bytes(&img->ih) + matrix_bytes(&img->ho) + 4u * img->n_o_p;
    if (need > cap) return 0;
    memcpy(out, "CSQ8", 4); wr16(out + 4, 1); wr16(out + 6, img->n_in); wr16(out + 8, img->n_h); wr16(out + 10, img->n_o);
    out[12] = CSQ_B; out[13] = img->steps;
    wrf32(out + 14, img->alpha); wrf32(out + 18, img->drive_scale); wrf32(out + 22, img->delta_thr);
    wrf32(out + 26, img->ih.scale); wrf32(out + 30, img->ho.scale);
    size_t off = CSQ8_HEADER_BYTES;
    for (int k = 0; k < 2; k++) {
        const csq8_matrix *m = k ? &img->ho : &img->ih;
        wr16(out + off, m->n_blocks); off += 2;
        memcpy(out + off, m->row_ptr, 2u * (m->n_brows + 1u)); off += 2u * (m->n_brows + 1u);
        memcpy(out + off, m->col, m->n_blocks); off += m->n_blocks;
        memcpy(out + off, m->tile, 128u * m->n_blocks); off += 128u * m->n_blocks;
    }
    memcpy(out + off, img->bias, 4u * img->n_o_p);
    return need;
}

static csq8_cf soma(csq8_cf z) {
    float r = hypotf(z.re, z.im), g = tanhf(r) / (r > 1e-8f ? r : 1e-8f);
    return (csq8_cf){ g * z.re, g * z.im };
}

// out[i] += scale * sum_j t[i][j] d[j]   (conj: conj(t[i][j]) instead)
static void tile_rows(const int8_t *t, float scale, const csq8_cf *d, csq8_cf *out, int conj) {
    for (int i = 0; i < CSQ_B; i++) {
        float re = 0, im = 0;
        for (int j = 0; j < CSQ_B; j++) {
            float a = t[(i * CSQ_B + j) * 2], b = t[(i * CSQ_B + j) * 2 + 1];
            if (conj) b = -b;
            re += a * d[j].re - b * d[j].im; im += a * d[j].im + b * d[j].re;
        }
        out[i].re += scale * re; out[i].im += scale * im;
    }
}
// out[j] += scale * sum_i d[i] t[i][j]
static void tile_cols(const int8_t *t, float scale, const csq8_cf *d, csq8_cf *out) {
    for (int j = 0; j < CSQ_B; j++) {
        float re = 0, im = 0;
        for (int i = 0; i < CSQ_B; i++) {
            float a = t[(i * CSQ_B + j) * 2], b = t[(i * CSQ_B + j) * 2 + 1];
            re += a * d[i].re - b * d[i].im; im += a * d[i].im + b * d[i].re;
        }
        out[j].re += scale * re; out[j].im += scale * im;
    }
}

// New somas of one block against the announced ones; writes the change into
// d and the announced values into s. Returns the number of units that moved.
static int announce(const csq8_cf *z, csq8_cf *s, csq8_cf *d, float thr) {
    int moved = 0;
    for (int i = 0; i < CSQ_B; i++) {
        csq8_cf n = soma(z[i]);
        csq8_cf e = { n.re - s[i].re, n.im - s[i].im };
        if (thr > 0 && hypotf(e.re, e.im) < thr) { d[i] = (csq8_cf){ 0, 0 }; continue; }
        if (thr > 0 || e.re != 0 || e.im != 0) moved++;
        d[i] = e; s[i] = n;
    }
    return moved;
}

int csq8_settle(const csq8_image *img, const csq8_cf *x, csq8_work *w) { return csq8_settle_biased(img, x, img->bias, w); }

int csq8_settle_biased(const csq8_image *img, const csq8_cf *x, const uint8_t *bias_f16, csq8_work *w) {
    const csq8_matrix *ih = &img->ih, *ho = &img->ho;
    const float a = img->alpha, thr = img->delta_thr;
    memset(w, 0, sizeof *w);
    w->dh = w->pool; w->zh = w->dh + img->n_h; w->sh = w->zh + img->n_h; w->fb = w->sh + img->n_h;
    w->zo = w->fb + img->n_h; w->so = w->zo + img->n_o_p; w->ff = w->so + img->n_o_p;
    // input drive, once: d_h = W_ih (drive_scale * x), x zero-padded to n_in_p
    for (unsigned r = 0; r < ih->n_brows; r++)
        for (unsigned k = rd16(ih->row_ptr + 2 * r); k < rd16(ih->row_ptr + 2 * r + 2); k++) {
            csq8_cf xin[CSQ_B];
            for (int j = 0; j < CSQ_B; j++) {
                unsigned u = ih->col[k] * CSQ_B + (unsigned)j;
                xin[j] = u < img->n_in ? (csq8_cf){ x[u].re * img->drive_scale, x[u].im * img->drive_scale } : (csq8_cf){ 0, 0 };
            }
            tile_rows(ih->tile + 128u * k, ih->scale, xin, w->dh + r * CSQ_B, 0);
            w->macs += 64;
        }
    // z_h = d_h, s_h = soma(z_h) announced in full; z_o = s_o = 0
    for (unsigned r = 0; r < ho->n_brows; r++) {
        csq8_cf d[CSQ_B];
        memcpy(w->zh + r * CSQ_B, w->dh + r * CSQ_B, sizeof d);
        for (int i = 0; i < CSQ_B; i++) d[i] = w->sh[r * CSQ_B + i] = soma(w->zh[r * CSQ_B + i]);
        for (unsigned k = rd16(ho->row_ptr + 2 * r); k < rd16(ho->row_ptr + 2 * r + 2); k++) {
            tile_cols(ho->tile + 128u * k, ho->scale, d, w->ff + ho->col[k] * CSQ_B);
            w->macs += 64;
        }
    }
    int used = img->steps;
    for (int step = 0; step < img->steps; step++) {
        // leaky update of both layers from the feedback and feedforward sums as they stood
        for (unsigned i = 0; i < img->n_h; i++) {
            w->zh[i].re = (1 - a) * w->zh[i].re + a * (w->dh[i].re + w->fb[i].re);
            w->zh[i].im = (1 - a) * w->zh[i].im + a * (w->dh[i].im + w->fb[i].im);
        }
        for (unsigned i = 0; i < img->n_o_p; i++) {
            w->zo[i].re = (1 - a) * w->zo[i].re + a * (w->ff[i].re + rdf16(bias_f16 + 4 * i));
            w->zo[i].im = (1 - a) * w->zo[i].im + a * (w->ff[i].im + rdf16(bias_f16 + 4 * i + 2));
        }
        // announce what moved and push only that through W_ho and W_ho^H
        uint32_t moved = 0;
        for (unsigned r = 0; r < ho->n_brows; r++) {
            csq8_cf d[CSQ_B];
            int m = announce(w->zh + r * CSQ_B, w->sh + r * CSQ_B, d, thr);
            if (!m) continue;
            moved += (uint32_t)m;
            for (unsigned k = rd16(ho->row_ptr + 2 * r); k < rd16(ho->row_ptr + 2 * r + 2); k++) {
                tile_cols(ho->tile + 128u * k, ho->scale, d, w->ff + ho->col[k] * CSQ_B);
                w->macs += 64;
            }
        }
        for (unsigned c = 0; c < ho->n_bcols; c++) {
            csq8_cf d[CSQ_B];
            int m = announce(w->zo + c * CSQ_B, w->so + c * CSQ_B, d, thr);
            if (!m) continue;
            moved += (uint32_t)m;
            for (unsigned r = 0; r < ho->n_brows; r++)
                for (unsigned k = rd16(ho->row_ptr + 2 * r); k < rd16(ho->row_ptr + 2 * r + 2); k++)
                    if (ho->col[k] == c) { tile_rows(ho->tile + 128u * k, ho->scale, d, w->fb + r * CSQ_B, 1); w->macs += 64; }
        }
        w->events += moved; w->units += (uint32_t)img->n_h + img->n_o_p;
        if (thr > 0 && moved == 0) { used = step + 1; break; }
    }
    w->steps_used = (uint16_t)used;
    return used;
}

float csq8_settle_ms(const csq8_image *img, const csq8_work *w, float cycles_per_mac, float cycles_per_soma, float f_cpu_hz) {
    float cycles = cycles_per_mac * (float)w->macs + cycles_per_soma * (float)(img->n_h + img->n_o_p) * (float)w->steps_used;
    return 1e3f * cycles / f_cpu_hz;
}

// ------------------------------------------------------------------ HLEQ v1
uint32_t hleq_crc32(const uint8_t *bytes, size_t n) {
    uint32_t c = 0xFFFFFFFFu;
    for (size_t i = 0; i < n; i++) {
        c ^= bytes[i];
        for (int k = 0; k < 8; k++) c = (c >> 1) ^ (0xEDB88320u & (0u - (c & 1u)));
    }
    return ~c;
}

hleq_status hleq_load(const uint8_t *buf, size_t len, uint16_t expected_n_o_p, hleq_packet *pkt) {
    memset(pkt, 0, sizeof *pkt);
    if (len < HLEQ_HEADER_BYTES + 4) return HLEQ_SHORT;
    if (memcmp(buf, "HLEQ", 4) != 0) return HLEQ_BAD_MAGIC;
    if (rd16(buf + 4) != 1) return HLEQ_BAD_VERSION;
    unsigned n_strokes = buf[6], n_o_p = rd16(buf + 8);
    if (n_strokes < 1 || n_strokes > HLEQ_MAX_STROKES) return HLEQ_BAD_SHAPE;
    if (n_o_p == 0 || n_o_p % CSQ_B || n_o_p > CSQ8_MAX_NO || n_o_p != expected_n_o_p) return HLEQ_BAD_SHAPE;
    size_t body = 4u * n_strokes * n_o_p, need = HLEQ_HEADER_BYTES + body + 4;
    if (len < need) return HLEQ_SHORT;
    if (len > need) return HLEQ_TRAILING;
    const uint8_t *tail = buf + HLEQ_HEADER_BYTES + body;
    uint32_t crc = (uint32_t)tail[0] | ((uint32_t)tail[1] << 8) | ((uint32_t)tail[2] << 16) | ((uint32_t)tail[3] << 24);
    if (hleq_crc32(buf, HLEQ_HEADER_BYTES + body) != crc) return HLEQ_BAD_CRC;
    float tol = rdf32(buf + 12);
    if ((buf[7] & 0xFEu) || !(tol > 0.0f && tol <= 1.0f)) return HLEQ_BAD_VALUE;        // not-a-number fails both comparisons
    // finite f16: the exponent field is not all ones
    for (size_t i = 0; i < body; i += 2) if ((buf[HLEQ_HEADER_BYTES + i + 1] & 0x7Cu) == 0x7Cu) return HLEQ_BAD_VALUE;
    pkt->n_strokes = (uint8_t)n_strokes; pkt->flags = buf[7]; pkt->n_o_p = (uint16_t)n_o_p;
    pkt->echo_norm_q15 = rd16(buf + 10); pkt->verify_tol = tol;
    pkt->stroke_biases = buf + HLEQ_HEADER_BYTES; pkt->bytes = need;
    return HLEQ_OK;
}

const uint8_t *hleq_stroke_bias(const hleq_packet *pkt, unsigned stroke_idx) {
    if (!pkt->stroke_biases || stroke_idx >= pkt->n_strokes) return NULL;
    return pkt->stroke_biases + 4u * (size_t)stroke_idx * pkt->n_o_p;
}

// ------------------------------------------------------------------ LMQ8 v1
static uint32_t rd32(const uint8_t *p) { return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24); }

lmq8_status lmq8_load(const uint8_t *buf, size_t len, lmq8_image *img) {
    memset(img, 0, sizeof *img);
    if (len < LMQ8_HEADER_BYTES + 4) return LMQ8_SHORT;
    if (memcmp(buf, "LMQ8", 4) != 0) return LMQ8_BAD_MAGIC;
    if (rd16(buf + 4) != 1) return LMQ8_BAD_VERSION;
    unsigned n_in = rd16(buf + 6), n_out = rd16(buf + 8);
    if (n_in == 0 || n_in > CSQ8_MAX_NIN || n_out == 0 || n_out > CSQ8_MAX_NO) return LMQ8_BAD_SHAPE;
    size_t body = 4u * (size_t)n_out + 2u * (size_t)n_out * n_in, need = LMQ8_HEADER_BYTES + body + 4;
    if (need > LMQ8_MAX_BYTES) return LMQ8_TOO_BIG;
    if (len < need) return LMQ8_SHORT;
    if (len > need) return LMQ8_TRAILING;
    if (hleq_crc32(buf, need - 4) != rd32(buf + need - 4)) return LMQ8_BAD_CRC;
    float thr = rdf32(buf + 12), gs = rdf32(buf + 16), temp = rdf32(buf + 24);
    if (!isfinite(thr) || !isfinite(gs) || gs < 0.0f || !isfinite(temp)) return LMQ8_BAD_VALUE;
    for (unsigned i = 0; i < n_out; i++) {
        float sc = rdf32(buf + LMQ8_HEADER_BYTES + 4u * i);
        if (!isfinite(sc) || sc < 0.0f) return LMQ8_BAD_VALUE;
    }
    img->n_in = (uint16_t)n_in; img->n_out = (uint16_t)n_out; img->tone_mask = rd16(buf + 10);
    img->threshold = thr; img->goal_scale = gs; img->calibration_seq = rd32(buf + 20); img->air_temp_offset_k = temp;
    img->scale = buf + LMQ8_HEADER_BYTES; img->q = (const int8_t *)(buf + LMQ8_HEADER_BYTES + 4u * n_out);
    img->bytes = need;
    return LMQ8_OK;
}

int lmq8_read(const lmq8_image *img, const csq8_cf *x, const uint8_t *goal_f16, float *est, uint8_t *occupied) {
    const unsigned n_in = img->n_in;
    int count = 0;
    memset(occupied, 0, (img->n_out + 7u) / 8u);
    for (unsigned i = 0; i < img->n_out; i++) {
        const int8_t *qr = img->q + 2u * (size_t)i * n_in, *qi = qr + n_in;
        float acc = 0.0f;
        for (unsigned j = 0; j < n_in; j++) acc += (float)qr[j] * x[j].re + (float)qi[j] * x[j].im;
        float e = rdf32(img->scale + 4u * i) * acc;
        if (goal_f16) e += img->goal_scale * rdf16(goal_f16 + 4u * i);
        est[i] = e;
        if (e > img->threshold) { occupied[i / 8u] |= (uint8_t)(1u << (i % 8u)); count++; }
    }
    return count;
}

void lmq8_slot_begin(lmq8_slot *s) { s->valid = false; s->len = 0; memset(&s->img, 0, sizeof s->img); }

lmq8_status lmq8_slot_write(lmq8_slot *s, const uint8_t *chunk, size_t n) {
    if (s->valid) return LMQ8_BAD_SHAPE;                          // no begin: a committed calibration is not written into
    if (n > LMQ8_MAX_BYTES - (size_t)s->len) return LMQ8_TOO_BIG;
    memcpy(s->bytes + s->len, chunk, n);
    s->len += (uint32_t)n;
    return LMQ8_OK;
}

lmq8_status lmq8_slot_commit(lmq8_slot *s) {
    if (s->valid) return LMQ8_OK;
    lmq8_status r = lmq8_load(s->bytes, s->len, &s->img);
    if (r == LMQ8_OK) { s->valid = true; s->swaps++; }
    return r;
}

lmq8_status lmq8_listen(const lmq8_slot *s, const hleq_packet *pkt, unsigned stroke_idx, const csq8_cf *x,
                        float *est, uint8_t *occupied, int *mismatch) {
    if (!s->valid) return LMQ8_NO_CALIBRATION;
    const uint8_t *goal = hleq_stroke_bias(pkt, stroke_idx);
    if (!goal || pkt->n_o_p < s->img.n_out) return LMQ8_BAD_SHAPE;
    lmq8_read(&s->img, x, goal, est, occupied);
    if (mismatch) {
        int m = 0;
        for (unsigned i = 0; i < s->img.n_out; i++) {
            bool want = s->img.goal_scale * rdf16(goal + 4u * i) > s->img.threshold;
            bool have = (occupied[i / 8u] >> (i % 8u)) & 1u;
            m += want != have;
        }
        *mismatch = m;
    }
    return LMQ8_OK;
}
