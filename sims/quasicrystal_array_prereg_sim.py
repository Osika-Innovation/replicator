#!/usr/bin/env python3
"""Pre-registered sim: icosahedral-quasicrystal volumetric array vs periodic vs random.

Pre-reg: papers/QUASICRYSTAL_ARRAY_PREREG_2026-08-01.md (frozen before first run).
Metrics: far-field array-factor peak sidelobe level (PSL) under conjugate-phase
steering; median/std/worst over 48 steering directions; 3 wavelength regimes.
"""
import json
import sys

import numpy as np

PHI = (1 + 5 ** 0.5) / 2
N_TARGET = 800
N_TOL = 0.03          # arms must land within +/-3% of N_TARGET
STEER_DIRS = 48
EVAL_DIRS = 16384
REGIMES = [0.6, 1.0, 1.6]   # s = d_c / lambda
RND_SEEDS = [20260801, 20260802, 20260803]
GAMMA = np.array([0.0131, 0.0237, 0.0347, 0.0453, 0.0561, 0.0673])
MAINLOBE_FACTOR = 3.0  # exclusion cone = 3 * lambda / D


def fibonacci_sphere(n):
    i = np.arange(n) + 0.5
    z = 1 - 2 * i / n
    r = np.sqrt(np.maximum(0.0, 1 - z * z))
    th = np.pi * (1 + 5 ** 0.5) * i
    return np.stack([r * np.cos(th), r * np.sin(th), z], axis=1)


def trim_to_sphere(pts, n_target):
    """Center points, then find radius containing ~n_target; rescale to unit sphere."""
    pts = pts - pts.mean(axis=0)
    d = np.linalg.norm(pts, axis=1)
    order = np.argsort(d)
    kept = pts[order[:n_target]]
    rmax = np.linalg.norm(kept, axis=1).max()
    return kept / rmax


def lattice_points(basis, span):
    rng = np.arange(-span, span + 1)
    ii, jj, kk = np.meshgrid(rng, rng, rng, indexing="ij")
    n = np.stack([ii.ravel(), jj.ravel(), kk.ravel()], axis=1).astype(float)
    return n @ basis


def make_sc(n_target):
    return trim_to_sphere(lattice_points(np.eye(3), 8), n_target)


def make_fcc(n_target):
    basis = 0.5 * np.array([[0, 1, 1], [1, 0, 1], [1, 1, 0]], dtype=float)
    return trim_to_sphere(lattice_points(basis, 12), n_target)


def make_random(n_target, seed):
    rng = np.random.default_rng(seed)
    pts = []
    while len(pts) < n_target:
        cand = rng.uniform(-1, 1, size=(4 * n_target, 3))
        cand = cand[np.linalg.norm(cand, axis=1) <= 1.0]
        pts.extend(cand.tolist())
    return np.array(pts[:n_target])


def make_qc(n_target):
    """Ammann-Kramer icosahedral quasicrystal via cut-and-project from Z^6."""
    s = 1.0 / np.sqrt(1 + PHI ** 2)
    par = s * np.array([
        [1, PHI, 0], [-1, PHI, 0],
        [0, 1, PHI], [0, -1, PHI],
        [PHI, 0, 1], [-PHI, 0, 1],
    ])
    conj = -1 / PHI
    sp = 1.0 / np.sqrt(1 + conj ** 2)
    perp = sp * np.array([
        [1, conj, 0], [-1, conj, 0],
        [0, 1, conj], [0, -1, conj],
        [conj, 0, 1], [-conj, 0, 1],
    ])
    # Zonotope (rhombic triacontahedron) facet test: normals from generator pairs.
    normals, supports = [], []
    for i in range(6):
        for j in range(i + 1, 6):
            m = np.cross(perp[i], perp[j])
            nm = np.linalg.norm(m)
            if nm < 1e-9:
                continue
            m = m / nm
            normals.append(m)
            supports.append(0.5 * np.abs(perp @ m).sum())
    normals = np.array(normals)
    supports = np.array(supports)

    span = 4
    rng = np.arange(-span, span + 1)
    grids = np.meshgrid(*([rng] * 6), indexing="ij")
    n6 = np.stack([g.ravel() for g in grids], axis=1).astype(float)  # (9^6 too big) -> span=4 gives 9^6? no: 9 values
    # note: span=4 -> 9 values per axis -> 9^6 = 531441 rows; fine.
    xperp = (n6 - GAMMA) @ perp
    inside = np.all(np.abs(xperp @ normals.T) <= supports[None, :] + 1e-12, axis=1)
    xpar = n6[inside] @ par
    if xpar.shape[0] < n_target:
        raise RuntimeError(f"QC generation produced only {xpar.shape[0]} points")
    return trim_to_sphere(xpar, n_target)


def psl_curve(pts, s_regime, steer, evald):
    """Peak sidelobe level (dB) per steering direction."""
    n = pts.shape[0]
    d_c = ((4.0 / 3.0) * np.pi / n) ** (1.0 / 3.0)   # unit sphere volume / N
    lam = d_c / s_regime
    k = 2 * np.pi / lam
    diam = 2 * np.linalg.norm(pts, axis=1).max()
    cone = MAINLOBE_FACTOR * lam / diam              # radians

    e_eval = np.exp(1j * k * (pts @ evald.T))        # (N, M)
    e_steer = np.exp(1j * k * (pts @ steer.T))       # (N, S)
    f = (e_eval.conj().T @ e_steer) / n              # (M, S): F(v,u)
    mag = np.abs(f)
    ang = np.arccos(np.clip(evald @ steer.T, -1, 1))  # (M, S)
    mag[ang < cone] = 0.0
    return 20 * np.log10(np.maximum(mag.max(axis=0), 1e-12))


def main():
    steer = fibonacci_sphere(STEER_DIRS)
    evald = fibonacci_sphere(EVAL_DIRS)

    arms = {"SC": make_sc(N_TARGET), "FCC": make_fcc(N_TARGET), "QC": make_qc(N_TARGET)}
    for seed in RND_SEEDS:
        arms[f"RND{seed % 100}"] = make_random(N_TARGET, seed)

    out = {}
    for name, pts in arms.items():
        assert abs(pts.shape[0] - N_TARGET) <= N_TOL * N_TARGET
        out[name] = {}
        for s in REGIMES:
            psl = psl_curve(pts, s, steer, evald)
            out[name][str(s)] = {
                "median": float(np.median(psl)),
                "std": float(np.std(psl)),
                "worst": float(np.max(psl)),
                "best": float(np.min(psl)),
            }
            print(f"{name:6s} s={s:3.1f}  median={out[name][str(s)]['median']:7.2f} dB  "
                  f"std={out[name][str(s)]['std']:5.2f}  worst={out[name][str(s)]['worst']:7.2f}",
                  flush=True)
    json.dump(out, open(sys.argv[1] if len(sys.argv) > 1 else "/tmp/qc_prereg_results.json", "w"), indent=1)


if __name__ == "__main__":
    main()
