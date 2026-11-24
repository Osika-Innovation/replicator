#!/usr/bin/env python3
"""Reference for the CSQ8 loader test: read SIM's exported image with NumPy alone (the layout and settle of
holo/cadence_drawer.py SparseCadenceQ8.from_blob / .settle, dense arithmetic), settle one seeded input and
write input + expected output for tests/host_test.c.

    csq8_reference.py <image.bin> <out.ref>

When holo.cadence_drawer imports (it needs MLX), the same input is also settled by SIM's own class and the two
must agree; otherwise that cross-check is reported as skipped."""
import pathlib, struct, sys
import numpy as np
np.seterr(all="ignore")   # Accelerate's matmul raises spurious FP flags on macOS; the C test compares the numbers

B = 8
def parse(blob):
    hdr = struct.calcsize("<4sHHHHBBfffff")
    magic, ver, n_in, n_h, n_o, blk, steps, alpha, dscale, dthr, s_ih, s_ho = struct.unpack("<4sHHHHBBfffff", blob[:hdr])
    assert magic == b"CSQ8" and ver == 1 and blk == B
    n_in_p, n_o_p = -(-n_in // B) * B, -(-n_o // B) * B
    off, mats = hdr, []
    for ncol, sc in ((n_in_p, s_ih), (n_o_p, s_ho)):
        nbr, nbc = n_h // B, ncol // B
        (nblk,) = struct.unpack("<H", blob[off:off + 2]); off += 2
        ptr = np.frombuffer(blob, "<u2", nbr + 1, off).astype(np.int64); off += 2 * (nbr + 1)
        cols = np.frombuffer(blob, "u1", nblk, off); off += nblk
        q = np.frombuffer(blob, "i1", nblk * B * B * 2, off).reshape(nblk, B, B, 2); off += nblk * B * B * 2
        rows = np.repeat(np.arange(nbr), np.diff(ptr))
        dense = np.zeros((nbr, nbc, B, B), dtype=np.complex64)
        dense[rows, cols] = (q[..., 0].astype(np.float32) + 1j * q[..., 1].astype(np.float32)) * np.float32(sc)
        mats.append(dense.transpose(0, 2, 1, 3).reshape(n_h, ncol))
    b = np.frombuffer(blob, "<f2", n_o_p * 2, off).reshape(-1, 2).astype(np.float32); off += 4 * n_o_p
    assert off == len(blob)
    return dict(n_in=n_in, n_h=n_h, n_o=n_o, steps=steps, alpha=alpha, dscale=dscale, dthr=dthr, W_ih=mats[0], W_ho=mats[1],
                b_o=(b[:, 0] + 1j * b[:, 1]).astype(np.complex64))

def soma(z):
    r = np.abs(z)
    return (np.tanh(r) / np.maximum(r, 1e-8) * z).astype(np.complex64)

def settle(n, x, b_o=None, thr=None):
    b_o = n["b_o"] if b_o is None else b_o
    xp = np.zeros(n["W_ih"].shape[1], dtype=np.complex64); xp[: n["n_in"]] = x * np.float32(n["dscale"])
    d_h = n["W_ih"] @ xp
    zh, zo = d_h.copy(), np.zeros(n["W_ho"].shape[1], dtype=np.complex64)
    sh, so = soma(zh), soma(zo)
    a, thr, used, ev = np.float32(n["alpha"]), (n["dthr"] if thr is None else thr), n["steps"], []
    for s in range(n["steps"]):
        fb_h, ff_o = n["W_ho"].conj() @ so, sh @ n["W_ho"] + b_o
        zh = (1 - a) * zh + a * (d_h + fb_h); zo = (1 - a) * zo + a * ff_o
        sh_n, so_n = soma(zh), soma(zo)
        eh, eo = np.abs(sh_n - sh) >= thr, np.abs(so_n - so) >= thr
        if thr > 0.0: sh, so = np.where(eh, sh_n, sh), np.where(eo, so_n, so)
        else: sh, so = sh_n, so_n
        ev.append(float((eh.sum() + eo.sum()) / (eh.size + eo.size)))
        if thr > 0.0 and ev[-1] == 0.0: used = s + 1; break
    return so[: n["n_o"]], used, float(np.mean(ev))

src, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
blob = src.read_bytes()
n = parse(blob)
rng = np.random.default_rng(27)
x = ((rng.normal(size=n["n_in"]) + 1j * rng.normal(size=n["n_in"])) * 0.5).astype(np.complex64)
so, used, ev = settle(n, x)
note = "SIM class cross-check skipped (holo.cadence_drawer needs MLX)"
try:
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[4]))
    from holo.cadence_drawer import SparseCadenceQ8
    net = SparseCadenceQ8.from_blob(blob)
    assert net.export_blob() == blob, "SIM export_blob(from_blob(b)) != b"
    theirs = net.settle(x[None, :])
    err = float(np.max(np.abs(theirs["so"][0] - so)))
    assert err < 1e-4 and theirs["steps_used"] == used, "reference differs from SparseCadenceQ8.settle: %g, steps %s vs %s" % (err, theirs["steps_used"], used)
    note = "agrees with SparseCadenceQ8.settle to %.1e" % err
except ImportError:
    pass
# HLEQ v1 (coordination/HOLO_EQUATION_SPEC.md section 5): 6 strokes of output bias for this image, written here
# byte by byte from the spec's table, CRC from zlib. SIM's own golden packet is checked further down.
import zlib
n_o_p, strokes = n["W_ho"].shape[1], 6
bias = (n["b_o"][None, :] + (rng.normal(size=(strokes, n_o_p)) + 1j * rng.normal(size=(strokes, n_o_p))) * 0.2)
bias16 = np.stack([bias.real, bias.imag], axis=-1).astype("<f2")
body = struct.pack("<4sHBBHHf", b"HLEQ", 1, strokes, 0, n_o_p, 32768, 0.25) + bias16.tobytes()
packet = body + struct.pack("<I", zlib.crc32(body) & 0xFFFFFFFF)
dst.with_suffix(".hleq").write_bytes(packet)
ref, worst_sim = struct.pack("<II", strokes, n["n_o"]), None
for k in range(strokes):
    bk = (bias16[k, :, 0].astype(np.float32) + 1j * bias16[k, :, 1].astype(np.float32)).astype(np.complex64)
    so_k, used_k, _ = settle(n, x, bk)
    so_0, _, _ = settle(n, x, bk, thr=0.0)
    ref += struct.pack("<I", used_k) + so_k.astype(np.complex64).tobytes() + so_0.astype(np.complex64).tobytes()
    try:
        net.b_o = bk
        theirs = net.settle(x[None, :])
        e = float(np.max(np.abs(theirs["so"][0] - so_k)))
        # with the event threshold on, a unit that lands within rounding of the threshold announces in one
        # implementation and not the other, and the outputs part by about the threshold times a weight: compare
        # exactly with it off, and to the threshold with it on
        assert e < n["dthr"] + 1e-6, "biased reference differs from SparseCadenceQ8.settle by %g, more than the event threshold" % e
        e0 = float(np.max(np.abs(net.settle(x[None, :], delta_thr=0.0)["so"][0] - so_0)))
        assert e0 < 1e-6, "threshold-free biased reference differs from SparseCadenceQ8.settle: %g" % e0
        worst_sim = e0 if worst_sim is None else max(worst_sim, e0)
    except NameError:
        pass
dst.with_suffix(".hleqref").write_bytes(ref)
print("hleq reference: %d strokes x %d outputs, %d bytes%s" % (strokes, n_o_p, len(packet),
      "" if worst_sim is None else "; threshold-free biased settles agree with SparseCadenceQ8.settle to %.1e" % worst_sim))
# SIM's golden packet (holo/holo_equation.py, hub #39): the same per-stroke settles from its bytes, parsed here
# from the spec's table and, when holo.holo_equation imports, by SIM's own parser as well.
fx = src.parent / "hleq_v1_fixture.bin"
if fx.exists():
    fb = fx.read_bytes()
    magic, ver, fs_, flags, f_nop, norm, tol = struct.unpack("<4sHBBHHf", fb[:16])
    assert magic == b"HLEQ" and ver == 1 and len(fb) == 16 + 4 * fs_ * f_nop + 4 and struct.unpack("<I", fb[-4:])[0] == zlib.crc32(fb[:-4]) & 0xFFFFFFFF
    fnote = "SIM parser not imported"
    try:
        from holo.holo_equation import parse_hleq_blob, export_hleq_blob
        got = parse_hleq_blob(fb, f_nop)
        assert got["status"] == "HLEQ_OK" and export_hleq_blob(got["stroke_biases"], echo_norm_q15=norm, verify_tol=tol, flags=flags) == fb
        fnote = "SIM's parse_hleq_blob accepts it and export_hleq_blob reproduces it byte for byte"
    except ImportError:
        pass
    if f_nop == n_o_p:
        b16 = np.frombuffer(fb, "<f2", fs_ * f_nop * 2, 16).reshape(fs_, f_nop, 2).astype(np.float32)
        ref = struct.pack("<II", fs_, n["n_o"])
        for k in range(fs_):
            bk = (b16[k, :, 0] + 1j * b16[k, :, 1]).astype(np.complex64)
            so_k, used_k, _ = settle(n, x, bk)
            so_0, _, _ = settle(n, x, bk, thr=0.0)
            ref += struct.pack("<I", used_k) + so_k.astype(np.complex64).tobytes() + so_0.astype(np.complex64).tobytes()
        dst.with_suffix(".fixref").write_bytes(ref)
        print("hleq fixture reference: %s, %d strokes x %d outputs; %s" % (fx.name, fs_, f_nop, fnote))
    else:
        print("hleq fixture reference: not made, the fixture is for %d outputs and this image has %d" % (f_nop, n_o_p))
dst.write_bytes(struct.pack("<IIIf", n["n_in"], n["n_o"], used, ev) + x.tobytes() + so.astype(np.complex64).tobytes())
print("csq8 reference: %s, %d -> %d <-> %d, %d steps, mean event fraction %.3f; %s" % (src.name, n["n_in"], n["n_h"], n["n_o"], used, ev, note))
