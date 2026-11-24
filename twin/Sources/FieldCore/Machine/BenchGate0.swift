import Foundation

/// The host side of Bench Gate 0 (INS-40, hub #93): the first measurement on
/// the empty closed chamber. One port plays a single tone stepped from 158 to
/// 162 kHz, a port of another enable group listens, and the width of the
/// axial resonances gives the end reflection that every 160 kHz lift figure
/// assumes (SIM #82). No bead.
///
/// The messages are the firmware's (`twin/Firmware/desktop/bench_gate0.h`),
/// little-endian, each closed by a CRC-32:
///
///   start   "BG0S" · u8 tx port · u8 rx port · u8 settle frames · u8 0 · f32 f low · f32 f step · u16 points · u16 0 · u32 crc
///   point   "BG0P" · u16 index · u16 0 · f32 Hz · f32 re · f32 im · u32 crc
///   result  "BG0R" · u16 points used · u8 periods · u8 verdict · f32 fsr, detune, rho1, rho2, fwhm Hz, width mm,
///           r plane wave, r SIM anchor · u32 crc
///
/// The estimate here is the firmware's, in doubles, on the points' magnitudes.
/// Nothing has run on a board.
public enum BenchGate0 {
    public struct Plan: Equatable {
        public var fLow = 158_000.0, fStep = 20.0
        public var points = 201, txPort = 0, rxPort = 1, settleFrames = 2
        public init() {}
    }
    public struct Point: Equatable { public var index: Int; public var frequency: Double; public var value: Complex }
    public enum Verdict: UInt8 { case pass = 0, marginal = 1, fail = 2 }
    public struct Fit {
        /// Resonance spacing c / 2 gap, Hz; nearest resonance minus the tone, Hz.
        public var fsr = 0.0, detune = 0.0
        /// Round-trip amplitude factor: |C1|/C0, |C2|/|C1|, and the smaller.
        public var rho1 = 0.0, rho2 = 0.0, rho = 0.0
        /// Full width at half maximum of the power response, Hz; the same as gap, m.
        public var fwhm = 0.0, width = 0.0
        public var rPlaneWave = 0.0, rSimAnchor = 0.0
        public var pointsUsed = 0, periods = 0
        public var verdict = Verdict.fail
    }
    public enum Invalid: Error { case short, magic, checksum, value }

    public static let gate = 0.85
    /// Air absorption at 160 kHz, Np/m (ISO 9613-1 form at 20 °C, 50 % RH; DERIVED, to be checked).
    public static let alpha = 0.69

    // ------------------------------------------------------------ messages
    public static func startMessage(_ p: Plan) -> [UInt8] {
        var out: [UInt8] = Array("BG0S".utf8) + [UInt8(p.txPort), UInt8(p.rxPort), UInt8(p.settleFrames), 0]
        FCodeWire.put(Float(p.fLow), &out); FCodeWire.put(Float(p.fStep), &out)
        FCodeWire.put(UInt16(p.points), &out); FCodeWire.put(UInt16(0), &out)
        FCodeWire.put(FCodeWire.crc32(out[...]), &out)
        return out
    }

    private static func u16(_ b: [UInt8], _ at: Int) -> UInt16 { UInt16(b[at]) | UInt16(b[at + 1]) << 8 }
    private static func u32(_ b: [UInt8], _ at: Int) -> UInt32 { UInt32(u16(b, at)) | UInt32(u16(b, at + 2)) << 16 }
    private static func f32(_ b: [UInt8], _ at: Int) -> Double { Double(Float(bitPattern: u32(b, at))) }
    private static func checked(_ b: [UInt8], _ magic: String, _ n: Int) throws {
        guard b.count == n else { throw Invalid.short }
        guard Array(b[0..<4]) == Array(magic.utf8) else { throw Invalid.magic }
        guard u32(b, n - 4) == FCodeWire.crc32(b[0..<(n - 4)]) else { throw Invalid.checksum }
    }

    public static func parsePoint(_ b: [UInt8]) throws -> Point {
        try checked(b, "BG0P", 24)
        let p = Point(index: Int(u16(b, 4)), frequency: f32(b, 8), value: Complex(f32(b, 12), f32(b, 16)))
        guard p.frequency.isFinite, p.value.re.isFinite, p.value.im.isFinite else { throw Invalid.value }
        return p
    }

    public static func parseResult(_ b: [UInt8]) throws -> Fit {
        try checked(b, "BG0R", 44)
        guard let v = Verdict(rawValue: b[7]) else { throw Invalid.value }
        var f = Fit()
        f.pointsUsed = Int(u16(b, 4)); f.periods = Int(b[6]); f.verdict = v
        f.fsr = f32(b, 8); f.detune = f32(b, 12); f.rho1 = f32(b, 16); f.rho2 = f32(b, 20); f.rho = min(f.rho1, f.rho2)
        f.fwhm = f32(b, 24); f.width = f32(b, 28) * 1e-3; f.rPlaneWave = f32(b, 32); f.rSimAnchor = f32(b, 36)
        return f
    }

    // ------------------------------------------------------------ estimate
    /// Width of one line of the Airy comb with round-trip factor rho. Below
    /// rho = 0.172 the response never falls to half: the spacing is returned.
    public static func airyFWHM(rho: Double, fsr: Double) -> Double {
        guard rho > 0 else { return fsr }
        guard rho < 1 else { return 0 }
        let a = (1 - rho) / (2 * rho.squareRoot())
        return a >= 1 ? fsr : fsr * 2 / Double.pi * asin(a)
    }
    /// rho = r² exp(−2 α gap).
    public static func rPlaneWave(rho: Double, gap: Double, alpha: Double = alpha) -> Double {
        rho > 0 ? min(1, rho.squareRoot() * exp(alpha * gap)) : 0
    }
    /// SIM #82's widths in gap: 0.15 mm near-rigid, 0.25 mm = 0.88, 0.35 mm = 0.70 (SIMULATED, 0.05 mm grid).
    public static func rSimAnchor(width: Double) -> Double {
        let w = width * 1e3
        return max(0, w <= 0.15 ? 0.99 : (w <= 0.25 ? 0.99 - (w - 0.15) * 1.1 : 0.88 - (w - 0.25) * 1.8))
    }

    /// `points` in sweep order at `fLow + i fStep`. `gap` (m) and `soundSpeed`
    /// are the nominal chamber: they place the search for the spacing (±3 %)
    /// and convert widths. Nil when the response has no comb in it.
    public static func estimate(_ points: [Point], plan: Plan = Plan(), tone: Double = 160_000, gap: Double = 0.240,
                                soundSpeed: Double, alpha: Double = alpha) -> Fit? {
        let y = points.map { $0.value.magnitude * $0.value.magnitude }
        let n = y.count, span = Double(n) * plan.fStep, fsr0 = soundSpeed / (2 * gap)
        guard n >= 16, y.contains(where: { $0 > 0 }) else { return nil }
        var best = -1.0, fit = Fit(), c1 = Complex.zero
        for k in -30...30 {
            let fsr = fsr0 * (1 + 0.001 * Double(k)), m = Int(span / fsr)
            guard m >= 2 else { return nil }
            let nw = min(n, Int((Double(m) * fsr / plan.fStep).rounded())), i0 = (n - nw) / 2
            var c0 = 0.0, a1 = Complex.zero, a2 = Complex.zero
            for i in i0..<(i0 + nw) {
                let th = 2 * Double.pi * (plan.fLow + Double(i) * plan.fStep - tone) / fsr
                c0 += y[i]; a1 = a1 + Complex(cos(th), -sin(th)) * y[i]; a2 = a2 + Complex(cos(2 * th), -sin(2 * th)) * y[i]
            }
            let score = a1.magnitude / c0
            if score > best {
                best = score; c1 = a1
                fit.fsr = fsr; fit.pointsUsed = nw; fit.periods = m
                fit.rho1 = score; fit.rho2 = a1.magnitude > 0 ? a2.magnitude / a1.magnitude : 0
            }
        }
        guard fit.rho1 >= 0.05 else { return nil }
        fit.rho = min(fit.rho1, fit.rho2)
        fit.detune = -fit.fsr * atan2(c1.im, c1.re) / (2 * Double.pi)
        fit.fwhm = airyFWHM(rho: fit.rho, fsr: fit.fsr)
        fit.width = fit.fwhm * gap / tone
        fit.rPlaneWave = rPlaneWave(rho: fit.rho, gap: gap, alpha: alpha)
        fit.rSimAnchor = rSimAnchor(width: fit.width)
        let a = fit.rPlaneWave >= gate, b = fit.rSimAnchor >= gate
        fit.verdict = a && b ? .pass : (a || b ? .marginal : .fail)
        return fit
    }

    /// The gap move that puts the resonance back on the tone: gap · detune / tone
    /// (positive = wider). What the firmware's resonance lock does with a sweep.
    public static func gapCorrection(detune: Double, tone: Double = 160_000, gap: Double = 0.240) -> Double { gap * detune / tone }
    /// d gap / d T that holds gap / c: gap / 2T. 0.41 mm/K at 240 mm and 20 °C (SIM #79).
    public static func gapPerKelvin(gap: Double = 0.240, celsius: Double = 20) -> Double { gap / (2 * (273.15 + celsius)) }
}
