"""HE-1: is a `.holo` an equation? (pre-registered; see HE1_HOLO_EQUATION_PREREG_2026-11-22.md)

Frozen gates (copied from the pre-registration; do not edit after the first run):
  H0  R0 IoU > chance-95 on >= 10 included shapes, else H1-H3 NOT EVALUABLE.
  H1  median IoU(R3)/IoU(R0) >= 0.90 AND R3 > chance-95 on >= 9 included shapes (H1b: same for R1).
  H2  median shape reaches 0.95 x IoU(R0) in R2 with m <= 4 per tone.
  H3  mean IoU drop member0 -> members1-4 (drives fixed) is >= 0.02 smaller for R3 than for R0.

Register: SIMULATED. Reads holo/runs/cadence_closed_chamber_ops.npz and holo.curriculum read-only.
Run: OPENBLAS_NUM_THREADS=1 python3 -m holo.he1_holo_equation
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from scipy.linalg import eigh
from scipy.optimize import minimize

HERE = Path(__file__).resolve().parent
OPS = HERE / "runs" / "cadence_closed_chamber_ops.npz"
OUT = HERE / "runs" / "he1_holo_equation_receipt.json"
HALF, GRID, THRESH = 0.012, 28, 0.35
M_LIST = (1, 2, 4, 8, 12)


def load_targets(points: np.ndarray) -> tuple[list[str], np.ndarray]:
    from .curriculum import CURRICULUM_SPECS, build_curriculum_volumes

    vols, _ = build_curriculum_volumes(grid_size=GRID, half_extent=HALF, poly_mode="solid", rotations=None)
    idx = np.clip(np.rint((points + HALF) / (2 * HALF) * (GRID - 1)).astype(int), 0, GRID - 1)
    samp = vols[:, idx[:, 0], idx[:, 1], idx[:, 2]] >= THRESH
    return [s.id for s in CURRICULUM_SPECS], samp


def normalise(u: np.ndarray) -> np.ndarray:
    return u / (np.linalg.norm(u, axis=1, keepdims=True) + 1e-30)


def intensity(u: np.ndarray, H: np.ndarray) -> np.ndarray:
    return np.sum(np.abs(np.einsum("tp,tps->ts", u, H)) ** 2, axis=0)


def iou(u: np.ndarray, H: np.ndarray, S: np.ndarray) -> float:
    k = int(S.sum())
    pred = np.zeros_like(S)
    pred[np.argsort(intensity(u, H))[:k]] = True
    return float((pred & S).sum() / max((pred | S).sum(), 1))


def r0_lookup(H: np.ndarray, S: np.ndarray) -> np.ndarray:
    T, P, _ = H.shape

    def unpack(x):
        return normalise((x[: T * P] + 1j * x[T * P :]).reshape(T, P))

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


def r1_invert(H: np.ndarray, S: np.ndarray) -> np.ndarray:
    T, P, _ = H.shape
    a = np.where(S, 0.0, 1.0)
    u = np.zeros((T, P), complex)
    for t in range(T):
        phi = np.zeros(a.shape)
        for _ in range(100):
            ut, *_ = np.linalg.lstsq(H[t].T, a * np.exp(1j * phi), rcond=None)
            phi = np.angle(ut @ H[t])
        u[t] = ut
    return normalise(u)


def r3_listen(H: np.ndarray, S: np.ndarray, m: int | None = None) -> np.ndarray:
    T, P, _ = H.shape
    u = np.zeros((T, P), complex)
    for t in range(T):
        B = np.eye(P, dtype=complex)
        if m is not None and m < P:
            B = np.linalg.svd(H[t], full_matrices=False)[0][:, :m]
        Hs, Hn = B.conj().T @ H[t][:, S], B.conj().T @ H[t][:, ~S]
        As, An = Hs @ Hs.conj().T, Hn @ Hn.conj().T
        An = An + 1e-9 * np.trace(An).real / An.shape[0] * np.eye(An.shape[0])
        w, v = eigh(As, An)
        u[t] = B @ v[:, 0]
    return normalise(u)


def main() -> None:
    d = np.load(OPS)
    Hall, pts = d["H"], d["points"]
    H0 = Hall[0]
    names, targets = load_targets(pts)
    rng = np.random.default_rng(7)
    rows = []
    for name, S in zip(names, targets):
        k = int(S.sum())
        if k < 5 or k > 171:
            rows.append({"shape": name, "k": k, "excluded": True})
            continue
        chance = [iou(normalise(rng.standard_normal((5, 12)) + 1j * rng.standard_normal((5, 12))), H0, S) for _ in range(1000)]
        drives = {"R0": r0_lookup(H0, S), "R1": r1_invert(H0, S), "R3": r3_listen(H0, S)}
        row = {"shape": name, "k": k, "excluded": False, "chance95": float(np.percentile(chance, 95))}
        for r, u in drives.items():
            row[r] = iou(u, H0, S)
            row[r + "_members"] = [iou(u, Hall[j], S) for j in range(1, Hall.shape[0])]
        row["R2"] = {str(m): iou(r3_listen(H0, S, m), H0, S) for m in M_LIST}
        rows.append(row)
        print(name, k, {r: round(row[r], 3) for r in ("R0", "R1", "R3")}, "chance95", round(row["chance95"], 3))

    inc = [r for r in rows if not r["excluded"]]
    n = len(inc)
    above = lambda key: sum(r[key] > r["chance95"] for r in inc)
    h0 = above("R0") >= 10
    ratio = lambda key: float(np.median([r[key] / max(r["R0"], 1e-9) for r in inc]))
    h1 = h0 and ratio("R3") >= 0.90 and above("R3") >= 9
    h1b = h0 and ratio("R1") >= 0.90 and above("R1") >= 9
    m_reach = []
    for r in inc:
        ok = [m for m in M_LIST if r["R2"][str(m)] >= 0.95 * r["R0"]]
        m_reach.append(min(ok) if ok else 99)
    h2 = h0 and float(np.median(m_reach)) <= 4
    drop = lambda key: float(np.mean([r[key] - np.mean(r[key + "_members"]) for r in inc]))
    h3 = h0 and (drop("R0") - drop("R3")) >= 0.02
    receipt = {
        "study": "HE-1 is a .holo an equation (hub #42)",
        "register": "SIMULATED (pressure-node proxy; no Gor'kov gradient terms)",
        "prereg": "holo/HE1_HOLO_EQUATION_PREREG_2026-11-22.md",
        "script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "n_included": n,
        "gates": {"H0": h0, "H1": h1, "H1b": h1b, "H2": h2, "H3": h3},
        "summary": {
            "R0_above_chance": above("R0"), "R3_above_chance": above("R3"), "R1_above_chance": above("R1"),
            "median_R3_over_R0": ratio("R3"), "median_R1_over_R0": ratio("R1"),
            "median_m_reach": float(np.median(m_reach)), "drop_R0": drop("R0"), "drop_R3": drop("R3"),
        },
        "rows": rows,
    }
    OUT.write_text(json.dumps(receipt, indent=1))
    print(json.dumps(receipt["gates"]), json.dumps(receipt["summary"]))


if __name__ == "__main__":
    main()
