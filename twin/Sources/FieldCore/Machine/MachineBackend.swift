import Foundation

/// What a machine says about itself.
public struct MachineDescription: Codable, Sendable, Equatable {
    public var name: String
    public var channels: Int
    public var perPlate: Int
    public var gap: Double                    // m, between the two radiating faces
    public var band: [Double]                 // Hz
    /// Stable identifier of the geometry and medium the calibration belongs to.
    public var calibrationRef: String
}

/// The empty machine's transfer between its own channels, per tone:
/// h[tone][rx][tx], in the units of `PortRecords`.
public struct CalibrationMatrix: Sendable {
    public var ref: String
    public var frequencies: [Double]
    public var h: [[[Complex]]]
}

/// What the rx gates recorded while frames played: per frame, per tone, one
/// complex amplitude per rx gate (in the frame's rx order).
///
/// Units: the element's reciprocal receive signal, i ρ c k / 4π × the force on
/// its face (N) — the same convention as the scan model's `scattered`, so a
/// record minus the calibration is directly the echo of what is in the chamber.
/// A bench calibration fixes the scale to volts; the twin does not model the
/// transducer's electrical side.
public struct PortRecords: Sendable, Equatable {
    public struct Tone: Sendable, Equatable {
        public var frequency: Double
        public var received: [Complex]
    }
    public struct Frame: Sendable, Equatable {
        public var t: Double
        public var rxGates: [Int]
        public var tones: [Tone]
    }
    public var frames: [Frame]
    public init(frames: [Frame] = []) { self.frames = frames }
}

/// The line between the software and a machine (spec §19). Everything above
/// it — compile, scan, build, the UI — talks to a machine only through these
/// four calls, so the emulator's API is the hardware's API. Synchronous here:
/// the CLI is; the spec's `async` belongs to the serial link.
public protocol MachineBackend {
    func describe() -> MachineDescription
    func calibrate() throws -> CalibrationMatrix
    mutating func play(_ frames: FCodeFile) throws -> PortRecords
    mutating func listen(_ gates: [Int], steps: Int) throws -> PortRecords
}

/// The machine, emulated: two plates of independently driven elements in open
/// air (`PlateArray`), with whatever is in the chamber as small rigid
/// scatterers. CPU only and FieldCore only, so it runs wherever Swift does.
///
/// It plays the frame log, not the file: every stream is encoded to the wire
/// (`FCodeWire`) and decoded again first, so the drive it radiates is the
/// 16-bit drive hardware would be sent, and `frameLog` is byte for byte what
/// a serial backend would put on the link.
public struct EmulatedBackend: MachineBackend {

    /// What is in the chamber: rigid spheres much smaller than a wavelength.
    public struct World: Sendable {
        public var scatterers: [Vec3]
        public var radius: Double
        public init(scatterers: [Vec3] = [], radius: Double = 0.3e-3) { self.scatterers = scatterers; self.radius = radius }
    }

    public var array: PlateArray
    public var medium: Medium
    public var world: World
    public var name: String
    public var band: [Double]
    /// The tones `calibrate()` measures.
    public var calibrationTones: [Double]
    /// Receiver noise, dB below each tone's rms record; nil = noiseless.
    public var snrDB: Double?
    public var seed: UInt64
    /// Everything played so far, as wire bytes.
    public private(set) var frameLog: [UInt8] = []

    private let elements: [Element]

    public init(array: PlateArray, medium: Medium = RH1Freestanding.roomAir, world: World = World(),
                name: String = "RH-1 open air (emulated)", band: [Double] = [30_000, 100_000],
                calibrationTones: [Double] = [40_000], snrDB: Double? = nil, seed: UInt64 = 17) {
        self.array = array; self.medium = medium; self.world = world; self.name = name
        self.band = band; self.calibrationTones = calibrationTones; self.snrDB = snrDB; self.seed = seed
        elements = array.elements()
    }

    public var calibrationRef: String {
        // FNV-1a over the numbers a calibration depends on.
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        func mix(_ v: Double) { withUnsafeBytes(of: v.bitPattern) { for b in $0 { h = (h ^ UInt64(b)) &* 0x0000_0100_0000_01B3 } } }
        for e in elements { mix(e.position.x); mix(e.position.y); mix(e.position.z); mix(e.area) }
        mix(array.gap); mix(array.reflection); mix(Double(array.imageOrder)); mix(medium.soundSpeed); mix(medium.density)
        return String(format: "emu-%016llx", h)
    }

    public func describe() -> MachineDescription {
        MachineDescription(name: name, channels: array.channels, perPlate: array.perPlate, gap: array.gap,
                           band: band, calibrationRef: calibrationRef)
    }

    /// Reciprocal units of a record (see `PortRecords`): i ρ c k / 4π.
    func receiveUnit(_ f: Double) -> Complex {
        Complex(0, medium.density * medium.soundSpeed * medium.wavenumber(at: f) / (4 * Double.pi))
    }

    /// What each element makes of a drive at f, and of what it hears: its
    /// resonance curve and, on a built plate, its error (`PlateArray.gains`).
    /// nil for ideal broadband elements.
    func gains(_ f: Double) -> [Complex]? { array.gains([f], curve: true)?[0] }

    /// Empty-chamber transfer rx ← tx at one tone: the Rayleigh integral of
    /// the tx piston with its plate images, weighted by the rx face's own
    /// directivity and area. The direct term of an element onto itself is
    /// its electrical self-impedance, which the twin does not model: left out.
    /// What an element hears of itself is its echo off the far plate.
    public func transfer(frequency f: Double) -> [[Complex]] {
        let k = medium.wavenumber(at: f), alpha = medium.absorption(at: f)
        let pre = medium.density * medium.soundSpeed * k / (2 * Double.pi)
        let unit = receiveUnit(f)
        let walls = array.walls
        let n = elements.count
        let images = elements.map { walls.images(of: $0.position.z) }
        let g = gains(f)
        var h = [[Complex]](repeating: [Complex](repeating: .zero, count: n), count: n)
        h.withUnsafeMutableBufferPointer { rows in
            let out = UncheckedSendableBuffer(rows)
            DispatchQueue.concurrentPerform(iterations: n) { e in
                let rx = elements[e]
                var row = [Complex](repeating: .zero, count: n)
                for (t, tx) in elements.enumerated() {
                    var acc = Complex.zero
                    for (m, img) in images[t].enumerated() {
                        if m == 0 && t == e { continue }
                        let d = rx.position - Vec3(tx.position.x, tx.position.y, img.z)
                        let r = max(d.length, 1e-9), c = abs(d.z) / r
                        let dir = Propagator.pistonDirectivity(k: k, a: tx.equivalentRadius, cosTheta: c)
                            * Propagator.pistonDirectivity(k: k, a: rx.equivalentRadius, cosTheta: c)
                        let ph = Complex.expi(k * r)
                        acc += Complex(-ph.im, ph.re) * (pre * tx.area * rx.area * dir * img.weight * exp(-alpha * r) / r)
                    }
                    row[t] = acc * unit
                    if let g { row[t] = row[t] * g[t] * g[e] }     // sent through tx's resonance, heard through rx's
                }
                out.base[e] = row
            }
        }
        return h
    }

    public func calibrate() throws -> CalibrationMatrix {
        CalibrationMatrix(ref: calibrationRef, frequencies: calibrationTones,
                          h: calibrationTones.map { transfer(frequency: $0) })
    }

    /// What every element receives from the scatterers when `drive` plays at
    /// `f` (Born, by reciprocity): r_e = Σ_s cM g_e(x_s) p(x_s) + cD ∇g_e·∇p.
    public func echo(frequency f: Double, drive sent: [Complex]) -> [Complex] {
        var r = [Complex](repeating: .zero, count: elements.count)
        guard !world.scatterers.isEmpty else { return r }
        let g = gains(f)
        let drive = g.map { g in sent.indices.map { sent[$0] * g[$0] } } ?? sent
        let prop = array.reference(frequency: f, medium: medium)
        let k = medium.wavenumber(at: f), a3 = pow(world.radius, 3)
        let cM = -k * k * a3 / 3, cD = -a3 / 2
        for x in world.scatterers {
            let rows = prop.gateGradientRows(at: x)
            var p = Complex.zero, gx = Complex.zero, gy = Complex.zero, gz = Complex.zero
            for c in 0..<drive.count {
                p += rows.p[c] * drive[c]
                gx += rows.grad[0][c] * drive[c]; gy += rows.grad[1][c] * drive[c]; gz += rows.grad[2][c] * drive[c]
            }
            for e in 0..<r.count {
                r[e] += rows.p[e] * p * cM + (rows.grad[0][e] * gx + rows.grad[1][e] * gy + rows.grad[2][e] * gz) * cD
            }
        }
        if let g { for e in r.indices { r[e] = r[e] * g[e] } }
        return r
    }

    public mutating func play(_ stream: FCodeFile) throws -> PortRecords {
        guard stream.channels == array.channels else {
            throw FCodeFile.Invalid.wire("stream has \(stream.channels) channels, the machine \(array.channels)")
        }
        let bytes = try FCodeWire.encode(stream)
        frameLog.append(contentsOf: bytes)
        let sent = try FCodeWire.decode(bytes, machine: stream.machine, calibrationRef: stream.calibrationRef)
        var rng = SplitMix64(seed: seed)
        func gauss() -> Double {
            let u1 = max(rng.nextUnit(), 1e-300), u2 = rng.nextUnit()
            return (-2 * log(u1)).squareRoot() * cos(2 * Double.pi * u2)
        }
        var transfers: [UInt64: [[Complex]]] = [:]
        var out = PortRecords()
        for fr in sent.frames {
            var tones: [PortRecords.Tone] = []
            for tone in fr.tones where !fr.rxGates.isEmpty {
                let d = tone.drive
                let key = tone.frequency.bitPattern
                if transfers[key] == nil { transfers[key] = transfer(frequency: tone.frequency) }
                let h = transfers[key]!
                let sc = echo(frequency: tone.frequency, drive: d)
                var rec = fr.rxGates.map { e -> Complex in
                    var v = sc[e]
                    for t in 0..<d.count { v += h[e][t] * d[t] }
                    return v
                }
                if let snr = snrDB, !rec.isEmpty {
                    let rms = (rec.reduce(0.0) { $0 + $1.magnitudeSquared } / Double(rec.count)).squareRoot()
                    let sigma = rms * pow(10, -snr / 20) / 2.0.squareRoot()
                    for i in rec.indices { rec[i] += Complex(gauss() * sigma, gauss() * sigma) }
                }
                tones.append(PortRecords.Tone(frequency: tone.frequency, received: rec))
            }
            out.frames.append(PortRecords.Frame(t: fr.t, rxGates: fr.rxGates, tones: tones))
        }
        return out
    }

    /// Record with nothing playing: silence, or the receiver noise floor
    /// (unit variance per quadrature) when `snrDB` is set.
    public mutating func listen(_ gates: [Int], steps: Int) throws -> PortRecords {
        var rng = SplitMix64(seed: seed)
        var out = PortRecords()
        for s in 0..<steps {
            let rec = gates.map { _ -> Complex in
                guard snrDB != nil else { return .zero }
                let u1 = max(rng.nextUnit(), 1e-300), u2 = rng.nextUnit()
                let m = (-2 * log(u1)).squareRoot()
                return Complex(m * cos(2 * Double.pi * u2), m * sin(2 * Double.pi * u2)) * 2.0.squareRoot().reciprocalValue
            }
            out.frames.append(PortRecords.Frame(t: Double(s), rxGates: gates,
                                                tones: [PortRecords.Tone(frequency: 0, received: rec)]))
        }
        return out
    }
}

private extension Double {
    var reciprocalValue: Double { 1 / self }
}

/// What a controller does with records: things any backend's output supports.
public enum MachineImaging {

    /// The echo: records minus what the empty machine returns for the same
    /// drive (the calibration), per tone, for a frame that listened on every
    /// channel.
    public static func echo(of frame: PortRecords.Frame, sent: FCodeFile.Frame, transfer: (Double) -> [[Complex]]) -> [[Complex]] {
        zip(frame.tones, sent.tones).map { rec, tone in
            let h = transfer(tone.frequency), d = tone.drive
            return frame.rxGates.enumerated().map { i, e in
                var v = rec.received[i]
                for t in 0..<d.count { v -= h[e][t] * d[t] }
                return v
            }
        }
    }

    /// Normalised matched filter: how well the echo matches what one small
    /// scatterer at `x` would return, 0…1. Its maximum over x is where a lone
    /// scatterer is (Cauchy–Schwarz), whatever the drive.
    public static func match(echo: [[Complex]], sent: FCodeFile.Frame, rxGates: [Int], at x: Vec3,
                             array: PlateArray, medium: Medium, radius: Double) -> Double {
        var num = Complex.zero, mm = 0.0, rr = 0.0
        for (ti, tone) in sent.tones.enumerated() {
            let prop = array.reference(frequency: tone.frequency, medium: medium)
            let k = medium.wavenumber(at: tone.frequency), a3 = pow(radius, 3)
            let cM = -k * k * a3 / 3, cD = -a3 / 2
            let rows = prop.gateGradientRows(at: x)
            let g = array.gains([tone.frequency], curve: true)?[0]
            let d = g.map { g in tone.drive.indices.map { tone.drive[$0] * g[$0] } } ?? tone.drive
            var p = Complex.zero, gx = Complex.zero, gy = Complex.zero, gz = Complex.zero
            for c in 0..<d.count {
                p += rows.p[c] * d[c]
                gx += rows.grad[0][c] * d[c]; gy += rows.grad[1][c] * d[c]; gz += rows.grad[2][c] * d[c]
            }
            for (i, e) in rxGates.enumerated() {
                var m = rows.p[e] * p * cM + (rows.grad[0][e] * gx + rows.grad[1][e] * gy + rows.grad[2][e] * gz) * cD
                if let g { m = m * g[e] }
                let r = echo[ti][i]
                num += m.conjugate * r; mm += m.magnitudeSquared; rr += r.magnitudeSquared
            }
        }
        return mm > 0 && rr > 0 ? num.magnitude / (mm * rr).squareRoot() : 0
    }
}
