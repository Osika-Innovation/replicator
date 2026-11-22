"""HE-1b / HE-1c (pre-registered; see HE1BC_PREREG_2026-11-22.md). Frozen gates, do not edit after first run:
  B0  R0j > chance-j on >= 10/13, else B1/B1w/B2 NOT EVALUABLE.
  B1  median IoU(R3j)/IoU(R0j) >= 0.90 AND R3j > chance-j on >= 9/13.   B1w  R3j > chance-j on >= 9/13.
  B2  mean I on S < mean I off S for R3j on >= 12/13.
  C1  mean_pairs IoU(R1 on H_j) - IoU(stored R0 on H_j) >= 0.10.        C2  R1 on H_j > chance on >= 37/52.
  C3  median IoU(R1 on H_j)/IoU(R0 refit on H_j) >= 0.30.               C1j same as C1 for R3j vs stored R0j.
Register: SIMULATED. Run: OPENBLAS_NUM_THREADS=1 nice -n 10 python3 -m holo.he1bc_holo_equation
"""

from __future__ import annotations

import hashlib
import json
from multiprocessing import Pool
from pathlib import Path

import numpy as np
from scipy.linalg import eigh
from scipy.optimize import minimize

from .he1_holo_equation import OPS, intensity, iou, load_targets, normalise, r0_lookup, r1_invert

HERE = Path(__file__).resolve().parent
OUT = HERE / "runs" / "he1bc_receipt.json"


def jnorm(u: np.ndarray) -> np.ndarray:
    return u / (np.linalg.norm(u) + 1e-30)


def r0j_lookup(H: np.ndarray, S: np.ndarray) -> np.ndarray:
    T, P, _ = H.shape

    def unpack(x):
        return jnorm((x[: T * P] + 1j * x[T * P :]).reshape(T, P))

    def loss(x):
        l = np.log(intensity(unpack(x), H) + 1e-30)
        m = l.mean()
        return float(np.sum(np.logaddexp(0, (l[S] - m) / 0.25)) + np.sum(np.logaddexp(0, (m - l[~S]) / 0.25)))

    best, best_u = np.inf, None
    for seed in range(4):
        x0 = np.random.default_rng(seed).standard_normal(2 * T * P)
        r = minimize(loss, x0, method="L-BFGS-B", options={"maxiter": 300})
        if r.fun < best:
            best, best_u = r.fun, unpack(r.x)
    return best_u


def r3j_listen(H: np.ndarray, S: np.ndarray) -> np.ndarray:
    T, P, _ = H.shape
    n = T * P
    As, An = np.zeros((n, n), complex), np.zeros((n, n), complex)
    for t in range(T):
        hs, hn = H[t][:, S], H[t][:, ~S]
        As[t * P:(t + 1) * P, t * P:(t + 1) * P] = hs @ hs.conj().T
        An[t * P:(t + 1) * P, t * P:(t + 1) * P] = hn @ hn.conj().T
    An = An + 1e-9 * np.trace(An).real / n * np.eye(n)
    _, v = eigh(As, An)
    return jnorm(v[:, 0].reshape(T, P))


def chance95(H: np.ndarray, S: np.ndarray, joint: bool) -> float:
    rng = np.random.default_rng(7)
    f = jnorm if joint else normalise
    return float(np.percentile([iou(f(rng.standard_normal((5, 12)) + 1j * rng.standard_normal((5, 12))), H, S) for _ in range(1000)], 95))


def _fit(args):
    kind, j, si = args
    d = np.load(OPS)
    _, targets = load_targets(d["points"])
    H, S = d["H"][j], targets[si]
    return (kind, j, si), (r0_lookup(H, S) if kind == "R0" else r0j_lookup(H, S))


def main() -> None:
    d = np.load(OPS)
    Hall = d["H"]
    names, targets = load_targets(d["points"])
    J = Hall.shape[0]
    jobs = [("R0", 0, s) for s in range(len(names))] + [("R0j", 0, s) for s in range(len(names))]
    jobs += [("R0", j, s) for j in range(1, J) for s in range(len(names))]
    with Pool(6) as pool:
        fits = dict(pool.map(_fit, jobs))

    # HE-1b
    b_rows = []
    for si, (name, S) in enumerate(zip(names, targets)):
        H0 = Hall[0]
        u3, u0 = r3j_listen(H0, S), fits[("R0j", 0, si)]
        I3 = intensity(u3, H0)
        b_rows.append({
            "shape": name, "k": int(S.sum()), "chance95_j": chance95(H0, S, True),
            "R0j": iou(u0, H0, S), "R3j": iou(u3, H0, S),
            "R3j_tone_power": [float(x) for x in np.linalg.norm(u3, axis=1) ** 2],
            "R3j_onoff": float(I3[S].mean() / I3[~S].mean()),
        })
        print("B", name, {k: round(b_rows[-1][k], 3) for k in ("R0j", "R3j", "chance95_j", "R3j_onoff")})
    above = lambda key: sum(r[key] > r["chance95_j"] for r in b_rows)
    b0 = above("R0j") >= 10
    ratio_b = float(np.median([r["R3j"] / max(r["R0j"], 1e-9) for r in b_rows]))
    b1 = b0 and ratio_b >= 0.90 and above("R3j") >= 9
    b1w = b0 and above("R3j") >= 9
    b2 = b0 and sum(r["R3j_onoff"] < 1 for r in b_rows) >= 12

    # HE-1c
    c_rows = []
    for j in range(1, J):
        Hj = Hall[j]
        for si, (name, S) in enumerate(zip(names, targets)):
            row = {
                "wafer": j, "shape": name, "chance95": chance95(Hj, S, False), "chance95_j": chance95(Hj, S, True),
                "stored_R0": iou(fits[("R0", 0, si)], Hj, S), "stored_R0j": iou(fits[("R0j", 0, si)], Hj, S),
                "R1_cal": iou(r1_invert(Hj, S), Hj, S), "R3j_cal": iou(r3j_listen(Hj, S), Hj, S),
                "R0_refit": iou(fits[("R0", j, si)], Hj, S),
            }
            c_rows.append(row)
            print("C", j, name, {k: round(v, 3) for k, v in row.items() if isinstance(v, float)})
    n = len(c_rows)
    c1_diff = float(np.mean([r["R1_cal"] - r["stored_R0"] for r in c_rows]))
    c2_count = sum(r["R1_cal"] > r["chance95"] for r in c_rows)
    c3_ratio = float(np.median([r["R1_cal"] / max(r["R0_refit"], 1e-9) for r in c_rows]))
    c1j_diff = float(np.mean([r["R3j_cal"] - r["stored_R0j"] for r in c_rows]))

    receipt = {
        "study": "HE-1b/HE-1c (hub #46)",
        "register": "SIMULATED (pressure-node proxy; no Gor'kov gradient terms)",
        "prereg": "holo/HE1BC_PREREG_2026-11-22.md",
        "script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "gates": {"B0": b0, "B1": b1, "B1w": b1w, "B2": b2,
                  "C1": c1_diff >= 0.10, "C2": c2_count >= 37, "C3": c3_ratio >= 0.30, "C1j": c1j_diff >= 0.10},
        "summary": {
            "R0j_above_chance": above("R0j"), "R3j_above_chance": above("R3j"), "median_R3j_over_R0j": ratio_b,
            "R3j_onoff_below_1": sum(r["R3j_onoff"] < 1 for r in b_rows),
            "n_pairs": n, "C1_mean_diff": c1_diff, "C2_R1cal_above_chance": c2_count, "C3_median_ratio": c3_ratio,
            "C1j_mean_diff": c1j_diff,
            "mean_stored_R0": float(np.mean([r["stored_R0"] for r in c_rows])),
            "mean_R1_cal": float(np.mean([r["R1_cal"] for r in c_rows])),
            "mean_R0_refit": float(np.mean([r["R0_refit"] for r in c_rows])),
            "mean_R3j_cal": float(np.mean([r["R3j_cal"] for r in c_rows])),
            "mean_stored_R0j": float(np.mean([r["stored_R0j"] for r in c_rows])),
            "R3j_cal_above_chance_j": sum(r["R3j_cal"] > r["chance95_j"] for r in c_rows),
        },
        "he1b_rows": b_rows, "he1c_rows": c_rows,
    }
    OUT.write_text(json.dumps(receipt, indent=1))
    print(json.dumps(receipt["gates"]), json.dumps(receipt["summary"]))


if __name__ == "__main__":
    main()
