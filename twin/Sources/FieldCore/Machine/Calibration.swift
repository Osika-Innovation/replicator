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
    /// the phase of their weighted mean is applied and their spread recorded:
    /// pairs that disagree mean the can was not square to the mid-plane.
    public static func run<B: MachineBackend>(_ backend: inout B, array: PlateArray, medium: Medium, probe: Vec3,
                                              probeGate: Int, velocity: Double, date: String,
                                              kind: Probe = .can(radius: 5e-3), reference: Bool = false, extra: [Vec3] = [],
                                              frequency: Double? = nil,
                                              before: (Int, inout B) -> Void = { _, _ in }) throws -> Record {
        let m = backend.describe()
        let f = frequency ?? array.tones?.first ?? m.band[0], k = medium.wavenumber(at: f)
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
                // Only the phase is taken: by symmetry the plates' amplitude ratio is
                // already in the two facing passes, and a tilted can corrupts it here.
                let mean = sum * (1 / weights)
                let s = mean.magnitude > 0 ? mean * (1 / mean.magnitude) : Complex.one
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

// MARK: - Desktop Replicator: the whole comb, in the chamber, while it stays true

public extension Calibration {

    /// A calibration of every tone of a body, and what must stay true for it
    /// to be used: the chamber air within `airTempTolerance` of what it was,
    /// and the head not lifted since.
    ///
    /// Why both. Sound crosses the 240 mm gap in about 112 periods at
    /// 160 kHz, so a kelvin of air turns the path phase by some 50° (INS-20).
    /// And the glass cylinder rides on the head: every lift puts the lateral
    /// wall back somewhere slightly new, so the chamber's transfer is a new
    /// one (INS-30). SIM's closed-chamber field correlation against the
    /// calibrated one: 0.97 at 0.1 K of drift, 0.63 at 0.5 K.
    struct ChamberRecord: Codable, Sendable, Equatable {
        public var machine: String
        public var date: String
        /// One record per tone, in the body's own order (`BodyResponse.frequencies`).
        public var tones: [Record]
        /// Chamber air (°C) when measured; nil = the machine has no sensor, and the record never validates.
        public var airTemperature: Double?
        /// The head-lift count when measured.
        public var headLift: Int
        public var frequencies: [Double] { tones.map(\.frequency) }
    }

    enum Stale: Error, Equatable, CustomStringConvertible {
        case noTemperature
        case temperatureDrift(kelvin: Double, tolerance: Double)
        case headLifted(since: Int)
        public var description: String {
            switch self {
            case .noTemperature: return "no chamber air temperature: the calibration cannot be shown to hold"
            case .temperatureDrift(let k, let tol): return String(format: "air has moved %.2f K since calibration (tolerance %.2f K): recalibrate", k, tol)
            case .headLifted(let n): return "the head was lifted \(n) time(s) since calibration: recalibrate"
            }
        }
    }

    /// air_temp_tolerance_k in coordination/system_constants.json.
    static let airTempTolerance = 0.1

    /// Calibrate every tone: `run` once per frequency. `frequencies` are the
    /// body's (`array.inputs.frequencies`), or the plate's tones, or the one
    /// tone a plain array has.
    static func multiTone<B: MachineBackend>(_ backend: inout B, array: PlateArray, medium: Medium, probe: Vec3, probeGate: Int,
                                             velocity: Double, date: String, kind: Probe = .point, reference: Bool = false,
                                             extra: [Vec3] = [], headLift: Int = 0,
                                             before: (Int, inout B) -> Void = { _, _ in }) throws -> ChamberRecord {
        let m = backend.describe()
        let frequencies = array.inputs?.frequencies ?? array.tones ?? [m.band[0]]
        var records: [Record] = []
        for q in frequencies.indices {
            records.append(try run(&backend, array: array, medium: medium, probe: probe, probeGate: probeGate, velocity: velocity,
                                   date: date, kind: kind, reference: reference, extra: extra, frequency: frequencies[q], before: before))
        }
        return ChamberRecord(machine: m.name, date: date, tones: records, airTemperature: m.temperature, headLift: headLift)
    }

    /// Does `record` still describe the chamber? nil = yes. Otherwise the
    /// reason to recalibrate, which a planner turns into a refusal.
    static func stale(_ record: ChamberRecord, airTemperature now: Double?, headLift: Int,
                      tolerance: Double = airTempTolerance) -> Stale? {
        if headLift != record.headLift { return .headLifted(since: headLift - record.headLift) }     // recalibrateOnLift
        guard let was = record.airTemperature, let now else { return .noTemperature }
        let airTempDrift = abs(now - was)
        // A drift exactly at the tolerance is inside it; the sum is not exact in binary.
        return airTempDrift > tolerance * (1 + 1e-9) ? .temperatureDrift(kelvin: airTempDrift, tolerance: tolerance) : nil
    }

    /// The field correlation to expect after the air has drifted, from SIM's
    /// two closed-chamber points (0.97 at 0.1 K, 0.63 at 0.5 K), joined by
    /// exp(−(ΔT / T₀)^p). The two numbers are SIMULATED; the curve between
    /// and beyond them is this file's interpolation, not a result.
    static func expectedCorrelation(airTempDrift dT: Double) -> Double {
        let p = log(log(1 / 0.63) / log(1 / 0.97)) / log(5.0)
        let t0 = 0.1 / pow(log(1 / 0.97), 1 / p)
        return exp(-pow(abs(dT) / t0, p))
    }

    // MARK: resonance tracking (INS-29)

    /// One point of a chamber sweep: what the probe heard per unit drive at a frequency.
    struct SweepPoint: Sendable, Equatable { public var frequency: Double; public var gain: Double }

    /// Drive `channel` alone at each of `frequencies` and record the probe's
    /// magnitude per unit drive: the port-to-field transfer of one wafer as
    /// it is in the chamber. The plate reverberates, so this cannot be
    /// predicted offline (solid FEM against the ray surrogate: 0.06).
    static func resonanceSweep<B: MachineBackend>(_ backend: inout B, channel: Int, probeGate: Int, frequencies: [Double],
                                                  velocity: Double) throws -> [SweepPoint] {
        let m = backend.describe()
        var out: [SweepPoint] = []
        for f in frequencies {
            let rec = try backend.play(program(m, drive: channel..<(channel + 1), probeGate: probeGate, frequency: f, velocity: velocity))
            guard let got = rec.frames.first?.tones.first?.received.first else { throw FCodeFile.Invalid.wire("sweep: no record at \(f) Hz") }
            out.append(SweepPoint(frequency: f, gain: got.magnitude / velocity))
        }
        return out
    }

    /// Where to play a comb tone so it sits on a plate resonance: the swept
    /// frequency with the largest gain within `window` (a fraction) of
    /// `nominal`, among those the firmware can play coherently (multiples of
    /// `grid`: 2 kHz for a 500 µs transmit ring, 8 kHz for the 125 µs one).
    /// `authority` is that gain over the gain at the nominal tone: SIM found
    /// 1.3 to 3.7 on the desktop wafer. Nothing in the window: the nominal
    /// tone, authority 1.
    static func toneOnResonance(_ sweep: [SweepPoint], nominal: Double, window: Double = 0.05,
                                grid: Double = 2_000) -> (frequency: Double, authority: Double) {
        func onGrid(_ f: Double) -> Bool { grid <= 0 || abs(f / grid - (f / grid).rounded()) < 1e-6 }
        let near = sweep.filter { abs($0.frequency - nominal) <= window * nominal && onGrid($0.frequency) }
        guard let base = sweep.min(by: { abs($0.frequency - nominal) < abs($1.frequency - nominal) }), base.gain > 0,
              let best = near.max(by: { $0.gain < $1.gain }), best.gain > base.gain else { return (nominal, 1) }
        return (best.frequency, best.gain / base.gain)
    }

    /// The whole comb retuned, one tone at a time. Retuned tones are no
    /// longer harmonics of one another; the firmware's de-mix only acts on
    /// tones that are (lk_demix), so nothing else changes there.
    static func combRetune(_ sweep: [SweepPoint], comb: [Double], window: Double = 0.05,
                           grid: Double = 2_000) -> [(frequency: Double, authority: Double)] {
        comb.map { toneOnResonance(sweep, nominal: $0, window: window, grid: grid) }
    }

    // MARK: planner policy (INS-23)

    /// What the Desktop planner will and will not send to the machine.
    /// Versioned: a receipt names the policy that admitted its stream.
    struct PlannerPolicy: Codable, Sendable, Equatable {
        public var version = "Desktop-planner/1"
        /// Largest move of a trap between frames (m).
        public var maxStep = 0.3e-3
        /// Largest change of drive between successive frames, as `FCodePrograms.largestStep` measures it.
        public var maxDriveStep = 0.5
        public var airTempTolerance = Calibration.airTempTolerance
        /// calibration_phase_tol_deg, calibration_gain_tol_pct.
        public var phaseToleranceDegrees = 5.0
        public var gainTolerance = 0.02
        /// Drive (fraction of full) at or under which the head may be up: the firmware's listen level.
        public var listenLevel = 1e-3
        public init() {}
    }
    static let desktopPlannerPolicy = PlannerPolicy()

    /// Why a stream was not played. Distinct from a stream that was played
    /// and did not do its job: a refusal moved nothing.
    enum Refusal: Error, Equatable, CustomStringConvertible {
        case stale(Stale)
        case step(Double, limit: Double)
        case interlock(level: Double)
        public var description: String {
            switch self {
            case .stale(let s): return "refused: \(s)"
            case .step(let s, let l): return String(format: "refused: the drive changes by %.2f between frames (limit %.2f): ramp it", s, l)
            case .interlock(let l): return String(format: "refused: drive at %.3g of full with the head up", l)
            }
        }
    }

    /// How a job ended.
    enum Outcome: Sendable, Equatable {
        case refused(Refusal)                         // nothing was played
        case played(PortRecords)                      // played, and `check` accepted the records
        case playedAndFailed(String, PortRecords)     // played; the machine did not do what was asked
    }

    /// Ask the policy, then play. `level`: the stream's peak drive as a
    /// fraction of the machine's full drive. `check` judges the records
    /// (nil = it worked, else what went wrong).
    static func play<B: MachineBackend>(_ stream: FCodeFile, on backend: inout B, policy: PlannerPolicy = desktopPlannerPolicy,
                                        calibration: ChamberRecord, airTemperature: Double?, headLift: Int, headDown: Bool,
                                        level: Double, check: (PortRecords) -> String? = { _ in nil }) -> Outcome {
        if level > policy.listenLevel, !headDown { return .refused(.interlock(level: level)) }
        if let s = stale(calibration, airTemperature: airTemperature, headLift: headLift, tolerance: policy.airTempTolerance) { return .refused(.stale(s)) }
        let step = FCodePrograms.largestStep(stream.frames.filter { $0.verb != .listen })
        if step > policy.maxDriveStep { return .refused(.step(step, limit: policy.maxDriveStep)) }
        do {
            let records = try backend.play(stream)
            if let why = check(records) { return .playedAndFailed(why, records) }
            return .played(records)
        } catch {
            return .playedAndFailed("the machine rejected the stream: \(error)", PortRecords())
        }
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

    /// These plates as a chamber calibration measured them, tone by tone.
    ///
    /// A body takes each tone's record at the listed frequency it was
    /// measured at; a frequency no record is within `match` (a fraction) of
    /// stays as modelled and is named by `uncalibratedTones`. Resonant
    /// elements each take the record of their own tone. Broadband pistons
    /// have one error per channel and take the first record.
    func calibrated(_ r: Calibration.ChamberRecord, match: Double = 1e-3) -> PlateArray {
        var a = self
        if let m = a.inputs {
            for q in m.frequencies.indices {
                guard let rec = r.record(near: m.frequencies[q], match: match), rec.errors.count == m.plateOf.count else { continue }
                a.inputs!.setError(rec.errors, at: m.frequencies[q])
            }
        } else if let t = tones, let of = toneOf {
            var e = channelError ?? [Complex](repeating: .one, count: channels)
            for c in 0..<channels { if let rec = r.record(near: t[of[c]], match: match), c < rec.errors.count { e[c] = rec.errors[c] } }
            a.channelError = e
        } else if let rec = r.tones.first {
            a.channelError = rec.errors
        }
        a.label = tag + "-cal"
        return a
    }

    /// The frequencies these plates play that `r` has no record for: a
    /// planner must not use them as calibrated.
    func uncalibratedTones(_ r: Calibration.ChamberRecord, match: Double = 1e-3) -> [Double] {
        (inputs?.frequencies ?? tones ?? []).filter { r.record(near: $0, match: match) == nil }
    }
}

public extension Calibration.ChamberRecord {
    /// The record measured within `match` (a fraction) of f, nearest first.
    func record(near f: Double, match: Double = 1e-3) -> Calibration.Record? {
        guard let rec = tones.min(by: { abs($0.frequency - f) < abs($1.frequency - f) }),
              abs(rec.frequency - f) <= match * f else { return nil }
        return rec
    }
}
