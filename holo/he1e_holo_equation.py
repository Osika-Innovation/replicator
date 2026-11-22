"""HE-1e (pre-registered; see HE1E_PREREG_2026-11-22.md). Frozen gates, do not edit after first run:
  E1  median_pairs IoU(R1+)/IoU(ceiling) >= 0.80
  E2  mean_pairs IoU(R1+) - IoU(Rand+) >= 0.05
  E3  R1+ > chance-95 on >= 59/65 pairs
  E4  mean_pairs IoU(R1+) - IoU(R1) >= 0.10
Register: SIMULATED. Run: OPENBLAS_NUM_THREADS=1 nice -n 10 python3 -m holo.he1e_holo_equation
"""

from __future__ import annotations

import hashlib
import json
from multiprocessing import Pool
from pathlib import Path

import numpy as np
from scipy.optimize import minimize

from .he1_holo_equation import OPS, intensity, iou, load_targets, normalise, r1_invert

HERE = Path(__file__).resolve().parent
OUT = HERE / "runs" / "he1e_receipt.json"
MAXITER = 30


def polish(H: np.ndarray, S: np.ndarray, u0: np.ndarray) -> tuple[np.ndarray, int]:
    T, P, _ = H.shape

    def unpack(x):
        return normalise((x[: T * P] + 1j * x[T * P :]).reshape(T, P))

    def loss(x):
        l = np.log(intensity(unpack(x), H) + 1e-30)
        m = l.mean()
        return float(np.sum(np.logaddexp(0, (l[S] - m) / 0.25)) + np.sum(np.logaddexp(0, (m - l[~S]) / 0.25)))

    x0 = np.concatenate([u0.real.ravel(), u0.imag.ravel()])
    r = minimize(loss, x0, method="L-BFGS-B", options={"maxiter": MAXITER})
    return unpack(r.x), int(r.nfev)


def chance95(H: np.ndarray, S: np.ndarray) -> float:
    rng = np.random.default_rng(7)
    return float(np.percentile([iou(normalise(rng.standard_normal((5, 12)) + 1j * rng.standard_normal((5, 12))), H, S) for _ in range(1000)], 95))


def run_pair(args):
    j, si = args
    d = np.load(OPS)
    names, targets = load_targets(d["points"])
    H, S = d["H"][j], targets[si]
    u1 = r1_invert(H, S)
    up, nfev_p = polish(H, S, u1)
    ur = np.random.default_rng(100 + j).standard_normal((5, 12)) + 1j * np.random.default_rng(1100 + j).standard_normal((5, 12))
    ur = normalise(ur)
    urp, nfev_r = polish(H, S, ur)
    return {"wafer": j, "shape": names[si], "k": int(S.sum()), "chance95": chance95(H, S),
            "R1": iou(u1, H, S), "R1plus": iou(up, H, S), "Randplus": iou(urp, H, S),
            "nfev_R1plus": nfev_p, "nfev_Randplus": nfev_r}


def main() -> None:
    d = np.load(OPS)
    names, _ = load_targets(d["points"])
    he1 = json.load(open(HERE / "runs" / "he1_holo_equation_receipt.json"))
    hebc = json.load(open(HERE / "runs" / "he1bc_receipt.json"))
    ceil = {(0, r["shape"]): r["R0"] for r in he1["rows"]}
    ceil.update({(r["wafer"], r["shape"]): r["R0_refit"] for r in hebc["he1c_rows"]})
    jobs = [(j, si) for j in range(d["H"].shape[0]) for si in range(len(names))]
    with Pool(6) as pool:
        rows = pool.map(run_pair, jobs)
    for r in rows:
        r["ceiling"] = ceil[(r["wafer"], r["shape"])]
        print(r["wafer"], r["shape"], {k: round(r[k], 3) for k in ("R1", "R1plus", "Randplus", "ceiling", "chance95")})
    n = len(rows)
    e1v = float(np.median([r["R1plus"] / max(r["ceiling"], 1e-9) for r in rows]))
    e2v = float(np.mean([r["R1plus"] - r["Randplus"] for r in rows]))
    e3v = sum(r["R1plus"] > r["chance95"] for r in rows)
    e4v = float(np.mean([r["R1plus"] - r["R1"] for r in rows]))
    receipt = {
        "study": "HE-1e ranking-aware rule (hub #63)",
        "register": "SIMULATED (pressure-node proxy; no Gor'kov gradient terms)",
        "prereg": "holo/HE1E_PREREG_2026-11-22.md",
        "script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "n_pairs": n,
        "gates": {"E1": e1v >= 0.80, "E2": e2v >= 0.05, "E3": e3v >= 59, "E4": e4v >= 0.10},
        "summary": {
            "E1_median_R1plus_over_ceiling": e1v, "E2_mean_R1plus_minus_Randplus": e2v,
            "E3_R1plus_above_chance": e3v, "E4_mean_R1plus_minus_R1": e4v,
            "median_Randplus_over_ceiling": float(np.median([r["Randplus"] / max(r["ceiling"], 1e-9) for r in rows])),
            "mean_R1": float(np.mean([r["R1"] for r in rows])), "mean_R1plus": float(np.mean([r["R1plus"] for r in rows])),
            "mean_Randplus": float(np.mean([r["Randplus"] for r in rows])), "mean_ceiling": float(np.mean([r["ceiling"] for r in rows])),
            "mean_nfev_R1plus": float(np.mean([r["nfev_R1plus"] for r in rows])),
        },
        "rows": rows,
    }
    OUT.write_text(json.dumps(receipt, indent=1))
    print(json.dumps(receipt["gates"]), json.dumps(receipt["summary"]))


if __name__ == "__main__":
    main()
