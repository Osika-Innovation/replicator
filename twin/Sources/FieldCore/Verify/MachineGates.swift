import Foundation

/// Gates for the machine program layer (spec §19, milestone M9): the `.fcode`
/// file, the frame log, and the emulated backend behind `MachineBackend`.
public enum MachineGates {

    static func fixture(perPlate: Int = 24) -> (EmulatedBackend, FCodeFile) {
        let b = EmulatedBackend(array: PlateArray(perPlate: perPlate), calibrationTones: [40_000, 70_000])
        return (b, FCodePrograms.demo(backend: b))
    }

    /// G-FC1: `.fcode` JSON reads back as the same value and the same bytes.
    public static func jsonRoundTrip() -> GateResult {
        let (_, f) = fixture()
        var bad = 1.0, detail = "threw"
        if let j = try? f.json(), let g = try? FCodeFile.read(j), let j2 = try? g.json() {
            bad = (g == f ? 0 : 1) + (j == j2 ? 0 : 1)
            detail = "\(f.frames.count) frames, \(f.channels) channels, \(j.count) bytes"
        }
        return GateResult(id: "G-FC1", name: ".fcode JSON round trip (value and bytes)", measured: bad, threshold: 0.5, detail: detail)
    }

    /// G-FC2: the frame log is stable — decoding it and encoding again gives
    /// the same bytes — and the 16-bit drive is within half a step of the file.
    public static func wire() -> [GateResult] {
        let (_, f) = fixture()
        guard let w1 = try? FCodeWire.encode(f), let g = try? FCodeWire.decode(w1), let w2 = try? FCodeWire.encode(g) else {
            return [GateResult(id: "G-FC2", name: "frame log re-encodes byte for byte", measured: 1, threshold: 0.5, detail: "threw")]
        }
        var diff = abs(w1.count - w2.count)
        for i in 0..<min(w1.count, w2.count) where w1[i] != w2[i] { diff += 1 }
        var worst = 0.0
        for (a, b) in zip(f.frames, g.frames) { for (ta, tb) in zip(a.tones, b.tones) {
            let peak = max(ta.re.map(abs).max() ?? 0, ta.im.map(abs).max() ?? 0)
            for c in 0..<f.channels { worst = max(worst, abs(ta.re[c] - tb.re[c]) / peak, abs(ta.im[c] - tb.im[c]) / peak) }
        } }
        var corrupt = w1
        corrupt[w1.count / 2] ^= 0x10
        let caught = (try? FCodeWire.decode(corrupt)) == nil
        return [
            GateResult(id: "G-FC2", name: "frame log re-encodes byte for byte (differing bytes)", measured: Double(diff),
                       threshold: 0.5, detail: "\(w1.count) bytes; a flipped bit is \(caught ? "rejected by the CRC" : "NOT caught")"),
            GateResult(id: "G-FC2b", name: "16-bit drive vs the file (fraction of full scale)", measured: caught ? worst : 1,
                       threshold: 2e-5, detail: "half a step is 1.53e-5"),
        ]
    }

    /// G-FC3: a recorded stream replays identically through the emulator —
    /// same records, same frame log — noise included (the seed is state).
    public static func replay() -> GateResult {
        var (a, f) = fixture()
        a.world = EmulatedBackend.World(scatterers: [a.array.centre + Vec3(1e-3, 0, 2e-3)])
        a.snrDB = 40
        var b = a
        var bad = 1.0, detail = "threw"
        if let ra = try? a.play(f), let rb = try? b.play(f), let w = try? FCodeWire.encode(f) {
            bad = (ra == rb ? 0 : 1) + (a.frameLog == b.frameLog ? 0 : 1) + (a.frameLog == w ? 0 : 1)
            detail = "\(ra.frames.count) frames, \(a.frameLog.count) log bytes; the log is the wire encoding of the file"
        }
        return GateResult(id: "G-FC3", name: "replay through the emulated backend is identical (M9)", measured: bad, threshold: 0.5, detail: detail)
    }

    /// G-FC4: the empty machine is reciprocal: rx ← tx equals tx ← rx.
    public static func reciprocity(array: PlateArray = PlateArray(perPlate: 24), id: String = "G-FC4") -> GateResult {
        let b = EmulatedBackend(array: array)
        var worst = 0.0, peak = 0.0
        for f in [40_000.0, 70_000] {
            let h = b.transfer(frequency: f)
            for e in 0..<h.count { for t in 0..<e {
                worst = max(worst, (h[e][t] - h[t][e]).magnitude); peak = max(peak, h[e][t].magnitude)
            } }
        }
        return GateResult(id: id, name: "calibration matrix reciprocity, \(array.channels) channels", measured: worst / peak, threshold: 1e-9,
                          detail: "max |H_et − H_te| / max |H| at 40 and 70 kHz")
    }

    /// G-FC5: through the backend's four calls alone, find what is in the
    /// chamber: play a coded pulse, subtract the calibration, and the matched
    /// filter peaks on the scatterer.
    public static func locate() -> GateResult {
        let array = PlateArray(perPlate: 24)
        let truth = array.centre + Vec3(2e-3, -1e-3, 3e-3)
        var b = EmulatedBackend(array: array, world: EmulatedBackend.World(scatterers: [truth]))
        let tones = (0..<6).map { 30_000 + 10_000 * Double($0) }
        var f = FCodeFile(machine: b.name, calibrationRef: b.calibrationRef, band: b.band, channels: array.channels)
        f.frames = [FCodePrograms.codedPulse(array: array, upperPlate: false, tones: tones, seed: 5, t: 0, duration: 5e-3)]
        guard let rec = try? b.play(f), let sent = try? FCodeWire.decode(b.frameLog) else {
            return GateResult(id: "G-FC5", name: "locate a scatterer through the backend", measured: 1, threshold: 0.3e-3, detail: "threw")
        }
        let empty = EmulatedBackend(array: array)
        let echo = MachineImaging.echo(of: rec.frames[0], sent: sent.frames[0]) { empty.transfer(frequency: $0) }
        var best = 0.0, at = Vec3.zero
        for axis in 0..<3 { for i in -24...24 {
            let s = Double(i) * 0.25e-3
            let x = truth + Vec3(axis == 0 ? s : 0, axis == 1 ? s : 0, axis == 2 ? s : 0)
            let m = MachineImaging.match(echo: echo, sent: sent.frames[0], rxGates: rec.frames[0].rxGates, at: x,
                                         array: array, medium: b.medium, radius: b.world.radius)
            if m > best { best = m; at = x }
        } }
        return GateResult(id: "G-FC5", name: "locate a scatterer through play + calibrate alone (m)", measured: (at - truth).length,
                          threshold: 0.3e-3, detail: String(format: "matched filter %.4f at the peak; searched ±6 mm along x, y, z at 0.25 mm", best))
    }

    public static func runAll() -> [GateResult] {
        [jsonRoundTrip()] + wire() + [replay(), reciprocity(), reciprocity(array: PlateArray.rh1(), id: "G-FC4b"), locate()]
    }
}
