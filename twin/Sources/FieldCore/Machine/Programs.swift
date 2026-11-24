import Foundation

/// Small programs a controller plays: the pieces `.fcode` streams are made of.
public enum FCodePrograms {

    /// A coded pulse: every element of one plate at unit total power with a
    /// random phase, the same pattern at every tone; all channels listen.
    public static func codedPulse(array: PlateArray, upperPlate: Bool, tones: [Double], seed: UInt64,
                                  t: Double, duration: Double, velocity: Double = 1e-3) -> FCodeFile.Frame {
        var rng = SplitMix64(seed: seed)
        let C = array.channels, half = C / 2
        var d = [Complex](repeating: .zero, count: C)
        for e in (upperPlate ? half..<C : 0..<half) { d[e] = Complex.expi(2 * Double.pi * rng.nextUnit()) * velocity }
        return FCodeFile.Frame(t: t, duration: duration, verb: .listen,
                               tones: tones.map { FCodeFile.Tone(frequency: $0, drive: d) }, rxGates: Array(0..<C))
    }

    /// A focus at `x`: each tone's drive is the phase conjugate of what the
    /// point would radiate back (time reversal), scaled to `velocity` rms per
    /// channel.
    public static func focus(array: PlateArray, medium: Medium, at x: Vec3, tones: [Double],
                             t: Double, duration: Double, velocity: Double = 1.0) -> FCodeFile.Frame {
        let ts = tones.map { f -> FCodeFile.Tone in
            let row = array.reference(frequency: f, medium: medium).gateRow(at: x)
            let rms = (row.reduce(0.0) { $0 + $1.magnitudeSquared } / Double(row.count)).squareRoot()
            return FCodeFile.Tone(frequency: f, drive: row.map { $0.conjugate * (velocity / max(rms, 1e-300)) })
        }
        return FCodeFile.Frame(t: t, duration: duration, verb: .add, tones: ts)
    }

    /// The demonstration stream: listen, hold a focus at the centre, listen.
    public static func demo(backend: EmulatedBackend, tones: [Double] = [40_000, 55_000, 70_000]) -> FCodeFile {
        let a = backend.array
        var f = FCodeFile(machine: backend.name, calibrationRef: backend.calibrationRef, band: backend.band, channels: a.channels)
        f.frames = [
            codedPulse(array: a, upperPlate: false, tones: tones, seed: 17, t: 0, duration: 5e-3),
            focus(array: a, medium: backend.medium, at: a.centre, tones: tones, t: 10e-3, duration: 0.5),
            codedPulse(array: a, upperPlate: true, tones: tones, seed: 18, t: 0.52, duration: 5e-3),
        ]
        return f
    }
}
