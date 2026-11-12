import Foundation

/// Calibration as a program any machine plays: every drive channel alone,
/// one microphone listening. What comes back, divided by what the drawing
/// says the microphone should hear, is each channel's error — its gain and
/// phase as built — and the plates with those errors are the machine the
/// next job is compiled on.
public enum Calibration {

    /// What one calibration measured, and of which machine under which
    /// conditions: the record a compile cites.
    public struct Record: Codable, Sendable, Equatable {
        public var machine: String
        public var calibrationRef: String
        public var date: String
        public var frequency: Double          // Hz
        public var velocity: Double           // m/s commanded while measuring
        public var temperature: Double?       // °C of the chamber air, if the machine reports it
        public var supply: Double?            // V at the drivers, if the machine reports it
        public var probe: [Double]            // m, where the microphone's port was
        /// Per drive channel, measured ÷ drawn; each plate's mean is 1 (the
        /// microphone's sensitivity and delay, and its turn between the
        /// plates, are not known).
        public var re: [Double], im: [Double]
        /// From a reference pass: the upper plate's mean ÷ the lower's, already
        /// applied to `re`/`im`, and how far the pairs disagree about its phase.
        public var plateRatio: [Double]? = nil
        public var plateRatioSpreadDegrees: Double? = nil
        public var errors: [Complex] { zip(re, im).map { Complex($0, $1) } }
    }

    /// Each of `drive` channels alone for `dwell` s at `velocity`, the gate
    /// `probeGate` listening; `settle` s of silence between.
    public static func program(_ m: MachineDescription, drive: Range<Int>, probeGate: Int, frequency: Double,
                               velocity: Double, dwell: Double = 0.02, settle: Double = 0.01, probes: Int = 1) -> FCodeFile {
        var f = FCodeFile(machine: m.name, calibrationRef: m.calibrationRef, band: m.band, channels: m.channels)
        for (i, c) in drive.enumerated() {
            var d = [Complex](repeating: .zero, count: m.channels)
            d[c] = Complex(velocity, 0)
            f.frames.append(FCodeFile.Frame(t: Double(i) * (dwell + settle), duration: dwell, verb: .listen,
                                            tones: [FCodeFile.Tone(frequency: frequency, drive: d)], rxGates: Array(probeGate..<(probeGate + probes))))
        }
        return f
    }

    /// What listens. A point microphone hears both plates alike: one pass,
    /// nothing ambiguous. A receiver can hears the plate it faces: one pass
    /// per plate, each normalised on its own, and the phase between the
    /// plates unmeasured unless a reference pass follows.
    public enum Probe: Sendable, Equatable { case point, can(radius: Double) }

    /// Play the program and reduce the records to a `Record`.
    /// `before(pass, &backend)` is where a person turns the probe: pass 0 a
    /// can facing the lower plate (or the point microphone), 1 facing the
    /// upper, 2 (with `reference`) lying in the mid-plane facing +x.
    ///
    /// `extra`: further microphone points (gates after `probeGate`), for a
    /// machine whose inputs include one that is silent at the first point;
    /// each channel is fitted over all of them.
    ///
    /// The reference pass: a can on its side hears a lower element and the
    /// upper element facing it at mirror angles, so whatever its directivity
    /// is, it is the same for both. Each such pair gives the plates' ratio;
    /// their weighted mean is taken and their spread recorded.
    public static func run<B: MachineBackend>(_ backend: inout B, array: PlateArray, medium: Medium, probe: Vec3,
                                              probeGate: Int, velocity: Double, date: String,
                                              kind: Probe = .can(radius: 5e-3), reference: Bool = false, extra: [Vec3] = [],
                                              before: (Int, inout B) -> Void = { _, _ in }) throws -> Record {
        let m = backend.describe()
        let f = array.tones?.first ?? m.band[0], k = medium.wavenumber(at: f)
        let points = [probe] + extra
        let raws = points.map { array.reference(frequency: f, medium: medium).gateRow(at: $0) }
        let els = array.elements(), count = array.driveChannels
        /// What each channel should put at each microphone point: per element,
        /// through the can as drawn (a piston of radius a facing along z) if
        /// there is one, then through a body's inputs. [point][channel]
        func drawn(can: Bool) -> [[Complex]] {
            points.indices.map { q in
                var row = raws[q]
                if can, case .can(let a) = kind {
                    for e in row.indices {
                        let to = els[e].position - points[q]
                        row[e] = row[e] * Propagator.pistonDirectivity(k: k, a: a, cosTheta: abs(to.z) / max(to.length, 1e-12))
                    }
                }
                return array.channelRow(row, frequency: f)
            }
        }
        /// [channel in the list][point]
        func heard(_ pass: Int, _ channels: [Int]) throws -> [[Complex]] {
            before(pass, &backend)
            var out: [[Complex]] = []
            for c in channels {                                  // one program per channel keeps `program` a plain range
                let rec = try backend.play(program(m, drive: c..<(c + 1), probeGate: probeGate, frequency: f, velocity: velocity, probes: points.count))
                guard rec.frames.count == 1, let got = rec.frames[0].tones.first?.received, got.count == points.count else {
                    throw FCodeFile.Invalid.wire("calibration: no record for channel \(c)")
                }
                out.append(got)
            }
            return out
        }
        var e = [Complex](repeating: .one, count: count)
        let lower = (0..<count).filter { array.plate(of: $0) == 0 }, upper = (0..<count).filter { array.plate(of: $0) == 1 }
        let facing = drawn(can: true)
        let groups: [[Int]] = kind == .point ? [lower + upper] : [lower, upper]
        for (pass, plate) in groups.enumerated() {
            let h = try heard(pass, plate)
            var mean = Complex.zero
            for (i, c) in plate.enumerated() {
                var num = Complex.zero, den = 0.0                 // least squares over the microphone points
                for q in points.indices { let want = facing[q][c] * velocity; num += h[i][q] * want.conjugate; den += want.magnitudeSquared }
                e[c] = den > 0 ? num * (1 / den) : .zero
                mean += e[c] * (1 / Double(plate.count))
            }
            if mean.magnitudeSquared == 0 { mean = .one }
            for c in plate { e[c] = e[c] * mean.conjugate * (1 / mean.magnitudeSquared) }
        }
        var ratio: Complex? = nil, spread: Double? = nil
        if reference, kind != .point, lower.count == upper.count {
            let h = try heard(2, lower + upper), n = lower.count, side = drawn(can: false)
            var sum = Complex.zero, weights = 0.0, each: [(Complex, Double)] = []
            for i in 0..<n {
                let lo = e[lower[i]] * side[0][lower[i]], up = e[upper[i]] * side[0][upper[i]]
                let hl = h[i][0], hu = h[i + n][0]
                guard hl.magnitudeSquared > 0, up.magnitudeSquared > 0 else { continue }
                let r = hu * hl.conjugate * (1 / hl.magnitudeSquared) * lo * up.conjugate * (1 / up.magnitudeSquared)
                let w = hl.magnitude * hu.magnitude
                sum += r * w; weights += w; each.append((r, w))
            }
            if weights > 0 {
                let s = sum * (1 / weights)
                for c in upper { e[c] = e[c] * s }
                var v = 0.0
                for (r, w) in each { let d = atan2((r * s.conjugate).im, (r * s.conjugate).re); v += w * d * d }
                ratio = s; spread = (v / weights).squareRoot() * 180 / Double.pi
            }
        }
        return Record(machine: m.name, calibrationRef: m.calibrationRef, date: date, frequency: f, velocity: velocity,
                      temperature: m.temperature, supply: m.supply, probe: [probe.x, probe.y, probe.z],
                      re: e.map(\.re), im: e.map(\.im), plateRatio: ratio.map { [$0.re, $0.im] }, plateRatioSpreadDegrees: spread)
    }
}

public extension PlateArray {
    /// These plates as a calibration measured them: the drawing's sites with
    /// each channel's measured gain and phase.
    func calibrated(_ r: Calibration.Record) -> PlateArray {
        var a = self
        if a.inputs != nil { a.inputs!.error = r.errors } else { a.channelError = r.errors }
        a.label = tag + "-cal"
        return a
    }
}
