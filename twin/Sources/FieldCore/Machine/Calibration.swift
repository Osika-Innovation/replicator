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
        public var errors: [Complex] { zip(re, im).map { Complex($0, $1) } }
    }

    /// Each of `drive` channels alone for `dwell` s at `velocity`, the gate
    /// `probeGate` listening; `settle` s of silence between.
    public static func program(_ m: MachineDescription, drive: Range<Int>, probeGate: Int, frequency: Double,
                               velocity: Double, dwell: Double = 0.02, settle: Double = 0.01) -> FCodeFile {
        var f = FCodeFile(machine: m.name, calibrationRef: m.calibrationRef, band: m.band, channels: m.channels)
        for (i, c) in drive.enumerated() {
            var d = [Complex](repeating: .zero, count: m.channels)
            d[c] = Complex(velocity, 0)
            f.frames.append(FCodeFile.Frame(t: Double(i) * (dwell + settle), duration: dwell, verb: .listen,
                                            tones: [FCodeFile.Tone(frequency: frequency, drive: d)], rxGates: [probeGate]))
        }
        return f
    }

    /// Play the program and reduce the records to a `Record`. One pass per
    /// plate: a receiver hears the plate it faces, so `before(pass)` is where
    /// a person turns the probe (0: facing the lower plate, 1: the upper).
    /// Each pass is normalised on its own — the phase between the plates is
    /// not measured, and shows as every trap sitting a little high or low.
    public static func run<B: MachineBackend>(_ backend: inout B, array: PlateArray, medium: Medium, probe: Vec3,
                                              probeGate: Int, velocity: Double, date: String,
                                              before: (Int) -> Void = { _ in }) throws -> Record {
        let m = backend.describe()
        let f = array.tones?.first ?? m.band[0]
        let drawn = array.reference(frequency: f, medium: medium).gateRow(at: probe)
        var e = [Complex](repeating: .one, count: array.channels)
        for (pass, plate) in [0..<array.perPlate, array.perPlate..<array.channels].enumerated() {
            before(pass)
            let rec = try backend.play(program(m, drive: plate, probeGate: probeGate, frequency: f, velocity: velocity))
            guard rec.frames.count == plate.count else { throw FCodeFile.Invalid.wire("calibration: \(rec.frames.count) records for \(plate.count) channels") }
            var mean = Complex.zero
            for (i, c) in plate.enumerated() {
                let heard = rec.frames[i].tones.first?.received.first ?? .zero
                let want = drawn[c] * velocity
                e[c] = want.magnitudeSquared > 0 ? heard * want.conjugate * (1 / want.magnitudeSquared) : .zero
                mean += e[c] * (1 / Double(plate.count))
            }
            if mean.magnitudeSquared == 0 { mean = .one }
            for c in plate { e[c] = e[c] * mean.conjugate * (1 / mean.magnitudeSquared) }
        }
        return Record(machine: m.name, calibrationRef: m.calibrationRef, date: date, frequency: f, velocity: velocity,
                      temperature: m.temperature, supply: m.supply, probe: [probe.x, probe.y, probe.z],
                      re: e.map(\.re), im: e.map(\.im))
    }
}

public extension PlateArray {
    /// These plates as a calibration measured them: the drawing's sites with
    /// each channel's measured gain and phase.
    func calibrated(_ r: Calibration.Record) -> PlateArray {
        var a = self
        a.channelError = r.errors
        a.label = tag + "-cal"
        return a
    }
}
