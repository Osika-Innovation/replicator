#!/usr/bin/env python3
"""Reference for the LMQ8 (live-M calibration image) host test, hub #77.

    lmq8_reference.py <out_dir>

Takes SIM's sensing operators at +0, +0.3 and +1 K (holo/runs/goal_cadence_live_operators.npz, hub #69) and SIM's
own ridge_inverse / quantize_inverse / sense (holo/goal_cadence.py), and writes for tests/host_test.c:
  lmq8_goal.hleq         ONE HLEQ v1 packet: 16 goals (8 single sites, 8 neighbour pairs) on held-out sites
  lmq8_<case>.bin        the calibration image rebuilt from that temperature's probe-fitted M
  lmq8_stale.bin         the image built from the nominal operator, which a machine that never recalibrates keeps
  lmq8_<case>.ref        scenes: echo errors, the estimate NumPy gets from the same int8 image, and the truth
SIMULATED: first-Born bead echoes on the solved r = 120 mm chamber, noise 30 dB below the signal."""
import pathlib, struct, sys, zlib
import numpy as np
repo = pathlib.Path(__file__).resolve().parents[4]
sys.path.insert(0, str(repo))
out = pathlib.Path(sys.argv[1])
src = repo / "holo/runs/goal_cadence_live_operators.npz"
if not src.exists():
    print("lmq8 reference: not made, %s is missing" % src.name); sys.exit(0)
from holo import goal_cadence as gc
from holo import holo_equation as he
z = np.load(src)
n_echo, n_sites, REPS = int(z["n_echo"]), 64, 20
CASES = (("p0", "air_plus_0K", 0.0), ("p03", "air_plus_0.3K", 0.3), ("p1", "air_plus_1K", 1.0))

def image(S_model, seq, temp):
    q = gc.quantize_inverse(gc.ridge_inverse(S_model))
    n_out, cols = q["q"].shape
    body = struct.pack("<4sHHHHffIf", b"LMQ8", 1, cols // 2, n_out, 0x1E, 0.5, 1.0 / gc.BIAS_GAIN, seq, temp)
    body += q["scale"].astype("<f4").tobytes() + q["q"].tobytes()
    return body + struct.pack("<I", zlib.crc32(body) & 0xFFFFFFFF), q

# 16 goals on sites no network ever trained on as goals, and for each REPS scenes of what is really there
rng = np.random.default_rng(77)
held = gc.held_out_sites()
pairs = [p for p in gc.neighbour_pairs(gc.site_points()) if p[0] in set(held.tolist()) or p[1] in set(held.tolist())]          # SIM's rule (_unseen_sets)
goals = [[int(s)] for s in held[:8]] + [list(pairs[int(i)]) for i in rng.choice(len(pairs), 8, replace=False)]
Gs = np.zeros((16, n_sites), dtype=np.float32)
for k, g in enumerate(goals): Gs[k, g] = 1.0
packet = he.export_hleq_blob((gc.BIAS_GAIN * Gs).astype(np.complex64), echo_norm_q15=32768, verify_tol=0.25)
(out / "lmq8_goal.hleq").write_bytes(packet)
goal16 = np.frombuffer(packet, "<f2", 16 * n_sites * 2, 16).reshape(16, n_sites, 2)[..., 0].astype(np.float64)
G = np.repeat(Gs, REPS, axis=0); O = G.copy()
kind = rng.choice(4, size=len(G), p=[0.40, 0.25, 0.15, 0.20])           # hold, displaced, missing, extra (as make_scenes)
for i in range(len(G)):
    o = set(np.flatnonzero(G[i]).tolist()); free = [s for s in range(n_sites) if s not in o]
    if kind[i] == 1: o.remove(int(rng.choice(sorted(o)))); o.add(int(rng.choice(free)))
    elif kind[i] == 2: o.remove(int(rng.choice(sorted(o))))
    elif kind[i] == 3: o.add(int(rng.choice(free)))
    O[i] = 0; O[i, sorted(o)] = 1.0
sc = {"G": G, "O": O, "kind": kind}

def estimate(q, X):                                                    # the arithmetic of lmq8_read, in float64
    v = np.concatenate([X.real, X.imag], axis=1).astype(np.float64)
    return (1.0 / gc.BIAS_GAIN) * np.repeat(goal16, REPS, axis=0) + (v @ q["q"].astype(np.float64).T) * q["scale"].astype(np.float32).astype(np.float64).T

stale_blob, stale_q = image(z[CASES[0][1] + "|M_stale_nominal"], 0, 0.0)
(out / "lmq8_stale.bin").write_bytes(stale_blob)
for n, (tag, case, temp) in enumerate(CASES):
    S_true, S_ref = z[case + "|true_operator_yardstick"], z[case + "|S_ref"]
    S_live, S_stale = z[case + "|M_probe_fitted_live"], z[case + "|M_stale_nominal"]
    blob, q = image(S_live, n + 1, temp)
    (out / ("lmq8_%s.bin" % tag)).write_bytes(blob)
    X_live = gc.sense(S_true, S_live, sc, np.random.default_rng(770 + n), n_echo, S_noise_ref=S_ref)
    X_stale = gc.sense(S_true, S_stale, sc, np.random.default_rng(770 + n), n_echo, S_noise_ref=S_ref)
    e_live, e_stale = estimate(q, X_live), estimate(stale_q, X_stale)
    # SIM's own read-out on the same int8 matrix must give the same occupancy as this script's estimate
    sim = gc.read_with_inverse(q["P"], X_live, G)
    assert np.array_equal(sim, (e_live > 0.5).astype(np.float32)) or np.abs(e_live - 0.5).min() < 2e-3, "estimate() differs from SIM's read_with_inverse"
    acc = lambda e: float(np.mean(np.all((e > 0.5) == (O > 0.5), axis=1)))
    ref = struct.pack("<IIII", len(G), X_live.shape[1], n_sites, REPS)
    ref += X_live.astype(np.complex64).tobytes() + e_live.astype("<f4").tobytes()
    ref += X_stale.astype(np.complex64).tobytes() + e_stale.astype("<f4").tobytes()
    ref += np.packbits(O.astype(np.uint8), axis=1, bitorder="little").tobytes()
    ref += struct.pack("<ff", acc(e_live), acc(e_stale))
    (out / ("lmq8_%s.ref" % tag)).write_bytes(ref)
    print("lmq8 reference %s (+%.1f K): image %d bytes, %d scenes, exact occupancy live %.3f, stale %.3f" % (tag, temp, len(blob), len(G), acc(e_live), acc(e_stale)))
