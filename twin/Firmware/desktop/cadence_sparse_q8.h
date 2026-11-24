// Card 1 brain: a block-sparse, event-driven, complex int8 Hermitian Cadence
// with equilibrium-propagation (eqprop) learning, for the RP2350B (INS-04).
//
// N = 432 complex units in 54 blocks of 8. The coupling W is Hermitian
// (reciprocity): only blocks (I, J) with I <= J are stored, 8 x 8 complex
// int8 each (128 bytes); block (J, I) is the conjugate transpose and is never
// stored. Dense, W would be 2 N^2 = 373 kB. At 10 % of the block grid it is
// 54 diagonal + 119 off-diagonal stored blocks = 22 kB, and the whole
// structure with its state is under 60 kB (checked at compile time).
//
// Fixed point: states are Q7 (127 = 1.0), weights are Q7 with a shared
// right shift, so |W s| stays in int32 without saturation logic in the loop.
//
// What is and is not evidenced (INS-26): this file shows the arithmetic fits
// and settles on the host. Accuracy of a 5-10 % sparse Cadence on the real
// task against the dense bar is SIM's to show; nothing here claims it.
#ifndef CADENCE_SPARSE_Q8_H
#define CADENCE_SPARSE_Q8_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define CSQ_N 432
#define CSQ_B 8
#define CSQ_NB (CSQ_N / CSQ_B)                  // 54
#define CSQ_MAX_OFFDIAG 119                     // 54 + 2 * 119 = 292 = 10.0 % of 54^2
#define CSQ_MAX_BLOCKS (CSQ_NB + CSQ_MAX_OFFDIAG)
#define CSQ_MAX_LINKS (CSQ_NB + 2 * CSQ_MAX_OFFDIAG)

typedef struct { int8_t re, im; } csq_c8;

typedef struct {
    // Weights: stored block b couples block row blk_i[b] to column blk_j[b] (i <= j).
    csq_c8 w[CSQ_MAX_BLOCKS][CSQ_B][CSQ_B];
    uint8_t blk_i[CSQ_MAX_BLOCKS], blk_j[CSQ_MAX_BLOCKS];
    uint16_t n_blocks;
    // Block CSR over the FULL grid: for source block J, the links
    // link[col_ptr[J] ... col_ptr[J+1]) name a stored block and whether it is
    // used as stored (target = blk_i, source = blk_j) or conjugate-transposed.
    uint16_t col_ptr[CSQ_NB + 1];
    uint16_t link[CSQ_MAX_LINKS];               // stored block index | 0x8000 if transposed
    uint8_t shift;                              // weights are w * 2^-(7 + shift)
    // State.
    csq_c8 s[CSQ_N];                            // unit states, Q7, |re|,|im| <= 127
    csq_c8 sent[CSQ_N];                         // the state each unit last announced
    int32_t u_re[CSQ_N], u_im[CSQ_N];           // W * sent, Q14 >> shift
    int16_t in_re[CSQ_N], in_im[CSQ_N];         // external input, Q7
    uint8_t dirty[CSQ_NB];                      // block has units that moved past the threshold
    uint8_t threshold;                          // Q7 change that makes a unit announce (event)
    // Counters for the settle budget.
    uint32_t block_pushes, sweeps;
} csq_net;

_Static_assert(sizeof(csq_net) <= 60000, "sparse Cadence must fit 60 kB (cadence_sparse_max_kb)");

void csq_init(csq_net *n, uint8_t shift, uint8_t threshold);
// Add an (empty) stored block coupling block i and block j. Returns its
// index, the existing one if already present, or -1 when full.
int csq_add_block(csq_net *n, int bi, int bj);
// Rebuild the CSR links after blocks were added.
void csq_link(csq_net *n);
// Fraction of the 54 x 54 block grid that is non-zero (both triangles).
float csq_density(const csq_net *n);

void csq_set_input(csq_net *n, int unit, int re_q7, int im_q7);
void csq_reset_state(csq_net *n);
// Relax: s <- clip(in + W s), units announcing only when they moved by more
// than the threshold, until no block is dirty or max_sweeps. Returns sweeps.
int csq_relax(csq_net *n, int max_sweeps);

// eqprop: contrast a nudged phase against a free phase.
//   free:   relax with the input            -> s0
//   nudged: relax with input + beta (target - s) on the output units -> s1
//   update: W_ij += lr (s1_i conj(s1_j) - s0_i conj(s0_j)), stored blocks
//           only. A difference of two Hermitian outer products is Hermitian,
//           so the stored triangle stays a complete description.
// `free_state` is s0 (CSQ_N entries), the net holds s1. lr_shift: the update
// is the Q14 product difference >> lr_shift, saturated to int8.
void csq_eqprop_update(csq_net *n, const csq_c8 *free_state, int lr_shift);

// An upper bound on the spectral norm of W (largest absolute row sum of the
// full Hermitian matrix), in units of 1.0. The relaxation is a contraction
// when this is below 1 (spectral_norm_max).
float csq_norm_bound(const csq_net *n);
// Raise `shift` until csq_norm_bound() <= limit. Returns the shift.
int csq_renormalise(csq_net *n, float limit);

// Settle time on the RP2350B from the counters: block_pushes x cycles per
// 8 x 8 complex block push, at f_cpu. DERIVED from an instruction count
// (README), not measured on the part.
float csq_settle_ms(const csq_net *n, float cycles_per_push, float f_cpu_hz);
// ---------------------------------------------------------------------------
// CSQ8 v1: the weight image SIM trains and exports (holo/cadence_drawer.py,
// SparseCadenceQ8.export_blob). A different network from csq_net above:
// n_in -> n_h <-> n_o with tied feedback W_fb = W_ho^H, float state, int8
// weights. Little-endian, unaligned:
//   "CSQ8" u16 version=1, u16 n_in, n_h, n_o, u8 block=8, u8 steps,
//   f32 alpha, drive_scale, delta_thr, scale_ih, scale_ho            (34 bytes)
//   W_ih then W_ho, each: u16 n_blocks, u16 row_ptr[n_h/8 + 1],
//                         u8 col[n_blocks], int8 tile[n_blocks][8][8][re,im]
//   output bias: f16 [ceil8(n_o)][re,im]
// The loader copies nothing: csq8_image points into the blob, which stays in
// flash. Only csq8_work (15.4 kB) is RAM.
#define CSQ8_HEADER_BYTES 34
#define CSQ8_MAX_NIN 392
#define CSQ8_MAX_NH 384
#define CSQ8_MAX_NO 344

typedef enum { CSQ8_OK = 0, CSQ8_SHORT, CSQ8_BAD_MAGIC, CSQ8_BAD_VERSION, CSQ8_BAD_BLOCK,
               CSQ8_BAD_SHAPE, CSQ8_BAD_INDEX, CSQ8_BAD_VALUE, CSQ8_TRAILING } csq8_status;

typedef struct {
    uint16_t n_blocks, n_brows, n_bcols;
    const uint8_t *row_ptr;                     // u16 LE x (n_brows + 1), may be unaligned
    const uint8_t *col;                         // strictly increasing inside a row
    const int8_t *tile;                         // [n_blocks][8][8][2]
    float scale;                                // weight = tile * scale
} csq8_matrix;

typedef struct {
    uint16_t n_in, n_h, n_o, n_in_p, n_o_p;     // _p: padded up to a multiple of 8
    uint8_t steps;
    float alpha, drive_scale, delta_thr;
    csq8_matrix ih, ho;
    const uint8_t *bias;                        // f16 LE x n_o_p x 2
    size_t bytes;                               // length of the image
} csq8_image;

typedef struct { float re, im; } csq8_cf;

// Settle state: four vectors of n_h and three of n_o_p, cut from one pool, so
// an image may be wide in the hidden layer or in the output but not both:
//   4 n_h + 3 n_o_p <= CSQ8_STATE_UNITS   (384 with up to 128, or 344 outputs with up to 216 hidden)
// csq8_load refuses an image that does not fit. The pointers are set by each
// settle and are valid until the next one.
#define CSQ8_STATE_UNITS 1920
typedef struct {
    csq8_cf pool[CSQ8_STATE_UNITS];
    csq8_cf *dh, *zh, *sh, *fb;                 // n_h each
    csq8_cf *zo, *so, *ff;                      // n_o_p each; so is the result
    uint32_t macs;                              // complex multiply-accumulates done
    uint32_t events, units;                     // announced units / unit-steps
    uint16_t steps_used;
} csq8_work;

// Check every length, pointer and index of the image before anything reads
// it. Rejects trailing bytes: the length must be exactly the image.
csq8_status csq8_load(const uint8_t *blob, size_t len, csq8_image *img);
// Write the image back out. Returns the byte count, 0 when cap is too small.
// csq8_store(csq8_load(b)) is b, byte for byte.
size_t csq8_store(const csq8_image *img, uint8_t *out, size_t cap);
// Free-phase settle, the arithmetic of SparseCadenceQ8.settle, event-driven:
// a unit's change is pushed through W_ho only when it moved by >= delta_thr.
// x: n_in complex inputs. Result: w->so[0 .. n_o). Returns the steps used.
int csq8_settle(const csq8_image *img, const csq8_cf *x, csq8_work *w);
// The same settle with another output bias in place of the image's:
// bias_f16 is f16 LE [n_o_p][re, im], read where it lies (a stroke of an HLEQ
// packet). Nothing is copied and csq8_work is unchanged, so swapping the
// goal costs no RAM. csq8_settle(img, x, w) is this with img->bias.
int csq8_settle_biased(const csq8_image *img, const csq8_cf *x, const uint8_t *bias_f16, csq8_work *w);
// DERIVED settle time from the counters, SIM's ASSUMED cycle costs
// (cadence_drawer.py: 8 cycles per complex MAC, 60 per soma update).
float csq8_settle_ms(const csq8_image *img, const csq8_work *w, float cycles_per_mac, float cycles_per_soma, float f_cpu_hz);

// The CSQ8 image is flash and is not counted as RAM (the images that exist
// are 35 707 and 39 094 bytes). What is RAM is counted below, after LMQ8.

// ---------------------------------------------------------------------------
// HLEQ v1: one object's goal for the shared CSQ8 network, as a set of output
// biases, one per stroke (coordination/HOLO_EQUATION_SPEC.md section 5).
// Little-endian, unaligned:
//   "HLEQ" u16 version=1, u8 n_strokes (1..16), u8 flags (bit 0 only),
//   u16 n_o_p, u16 echo_norm_q15, f32 verify_tol (0 < tol <= 1)   (16 bytes)
//   f16 bias[n_strokes][n_o_p][re, im]
//   u32 CRC-32 (IEEE, reflected 0xEDB88320) over everything before it
// 6 strokes x 64 outputs = 1 556 bytes.
#define HLEQ_HEADER_BYTES 16
#define HLEQ_MAX_STROKES 16

typedef enum { HLEQ_OK = 0, HLEQ_SHORT, HLEQ_BAD_MAGIC, HLEQ_BAD_VERSION, HLEQ_BAD_SHAPE,
               HLEQ_BAD_VALUE, HLEQ_BAD_CRC, HLEQ_TRAILING } hleq_status;

typedef struct {
    uint8_t n_strokes, flags;
    uint16_t n_o_p, echo_norm_q15;
    float verify_tol;
    const uint8_t *stroke_biases;               // inside the caller's packet buffer
    size_t bytes;
} hleq_packet;

// Check a packet before anything reads its biases. Order: length of the
// header, magic, version, shape, exact length, CRC, then the values. So a
// packet damaged in transit fails the CRC, and HLEQ_BAD_VALUE means the
// sender made a packet with a bad number in it. expected_n_o_p: the loaded
// image's n_o_p. pkt is zeroed unless HLEQ_OK.
hleq_status hleq_load(const uint8_t *buf, size_t len, uint16_t expected_n_o_p, hleq_packet *pkt);
// The bias of one stroke, for csq8_settle_biased. NULL when out of range.
const uint8_t *hleq_stroke_bias(const hleq_packet *pkt, unsigned stroke_idx);
// IEEE CRC-32 over bytes; the same polynomial and result as sb_crc32 over
// the same bytes taken as little-endian words.
uint32_t hleq_crc32(const uint8_t *bytes, size_t n);

// ------------------------------------------------------------------ LMQ8 v1
// LMQ8 v1: the chamber's side of LISTEN, per calibration (INS-38; SIM #69,
// #71: holo/goal_cadence.py ridge_inverse + quantize_inverse).
//
// WHY THIS IS NOT IN THE CSQ8 IMAGE. A read-out trained into flash stops
// working when the air warms by 0.3 K. A linear inverse rebuilt from the
// transfer the machine has just measured does not. So what depends on the
// chamber is this image: it lives in RAM and is replaced after every
// calibration, with no reflash. What depends on the object is the HLEQ
// packet, and it is the same bytes in every chamber and at every temperature.
//
//   occupancy estimate  est_i = goal_scale * Re(goal_i) + scale_i * sum_j q_ij v_j
//   v = [Re x_0 .. Re x_{n_in-1}, Im x_0 .. Im x_{n_in-1}],  x = measured echo - predicted echo
//   site i is occupied when est_i > threshold
//
//   "LMQ8" u16 version=1, u16 n_in, u16 n_out, u16 tone_mask,
//   f32 threshold, f32 goal_scale, u32 calibration_seq, f32 air_temp_offset_k,
//   f32 scale[n_out], int8 q[n_out][2 n_in], u32 CRC-32 (IEEE, as HLEQ)
//
// tone_mask, calibration_seq and air_temp_offset_k say which calibration
// this is; the arithmetic does not use them. 64 sites x 336 inputs: 43 296 B.
#define LMQ8_HEADER_BYTES 28
#define LMQ8_MAX_BYTES 43296

typedef enum { LMQ8_OK = 0, LMQ8_SHORT, LMQ8_BAD_MAGIC, LMQ8_BAD_VERSION, LMQ8_BAD_SHAPE, LMQ8_BAD_VALUE,
               LMQ8_BAD_CRC, LMQ8_TRAILING, LMQ8_TOO_BIG, LMQ8_NO_CALIBRATION } lmq8_status;

typedef struct {
    uint16_t n_in, n_out, tone_mask;
    float threshold, goal_scale, air_temp_offset_k;
    uint32_t calibration_seq;
    const uint8_t *scale;                       // f32 LE [n_out], unaligned
    const int8_t *q;                            // [n_out][2 n_in]
    size_t bytes;
} lmq8_image;

// Same order as hleq_load: lengths, magic, version, shape, exact length,
// CRC, then values. img is zeroed unless LMQ8_OK.
lmq8_status lmq8_load(const uint8_t *buf, size_t len, lmq8_image *img);
// One read. x: n_in echo errors. goal_f16: f16 LE [>= n_out][re, im], a
// stroke of an HLEQ packet, or NULL for no goal. est: n_out floats.
// occupied: (n_out + 7) / 8 bytes, bit i of byte i / 8. Returns the number
// of occupied sites.
int lmq8_read(const lmq8_image *img, const csq8_cf *x, const uint8_t *goal_f16, float *est, uint8_t *occupied);

// The one calibration the machine holds. A new one is streamed over the old:
// begin (from here every read is refused), write the chunks in order, commit
// (checks it; valid again only on LMQ8_OK). There is no second copy, so a
// download that fails leaves the machine without a calibration until the
// next one arrives. That is intended: the old one described a chamber that
// has since changed.
typedef struct {
    uint8_t bytes[LMQ8_MAX_BYTES];
    uint32_t len;
    uint32_t swaps;                             // commits that succeeded
    lmq8_image img;
    bool valid;
} lmq8_slot;

void lmq8_slot_begin(lmq8_slot *s);
lmq8_status lmq8_slot_write(lmq8_slot *s, const uint8_t *chunk, size_t n);
lmq8_status lmq8_slot_commit(lmq8_slot *s);
// LISTEN for one stroke of an object's packet through the calibration held
// now. mismatch (may be NULL): sites whose occupancy differs from the goal
// (goal site = goal_scale * Re(goal) > threshold). LMQ8_NO_CALIBRATION when
// the slot holds none; LMQ8_BAD_SHAPE when the stroke does not exist or the
// packet is narrower than the calibration's site count.
lmq8_status lmq8_listen(const lmq8_slot *s, const hleq_packet *pkt, unsigned stroke_idx, const csq8_cf *x,
                        float *est, uint8_t *occupied, int *mismatch);

// RAM of the Card 1 brain: the settle state and the calibration slot. The
// CSQ8 weights are flash; an HLEQ packet is read where the bus left it.
_Static_assert(sizeof(csq8_work) + sizeof(lmq8_slot) < 60000, "settle state + live-M calibration must stay under 60 kB of RAM (cadence_sparse_max_kb)");
#endif
