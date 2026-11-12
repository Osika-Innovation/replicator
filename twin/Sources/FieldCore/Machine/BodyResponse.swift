import Foundation

/// The response of a pair of structured bodies driven through a few inputs,
/// as another session's coupled model (or a bench) hands it to the twin:
/// what each input makes the radiating faces do, per frequency.
///
/// Format `body-response/0.1`. SI units throughout. The radiating faces are
/// sampled as flat patches on two facing planes (z = 0 looking up, z = gap
/// looking down), the same number on each; a patch is a small baffled piston.
/// A face that is not flat, or patches that differ in count between the
/// bodies, need 0.2. The twin does not model the body: it trusts this file,
/// perturbs it by `uncertainty`, and corrects each input by calibration.
public struct BodyResponse: Codable, Sendable, Equatable {
    public static let format = "body-response/0.1"
    public struct Provenance: Codable, Sendable, Equatable {
        /// REFERENCE (made up to exercise the interface), SIMULATED or MEASURED.
        public var status: String
        public var source: String            // who or what produced it: session, solver and version, bench
        public var date: String
        public var geometry: String          // the body's CAD file or its hash
        public var note: String
    }
    public struct Patch: Codable, Sendable, Equatable { public var x, y: Double; public var plate: Int; public var radius: Double }
    public struct Input: Codable, Sendable, Equatable {
        public var name: String
        public var plate: Int
        /// The largest drive the input takes, in `driveUnit`.
        public var maxDrive: Double
    }
    public struct Uncertainty: Codable, Sendable, Equatable {
        /// One standard deviation of each response entry: relative gain, phase (degrees).
        public var gain: Double, phaseDegrees: Double
    }
    public var format: String
    public var name: String
    public var provenance: Provenance
    /// The unit of an input's drive ("V rms", or "m/s" for a reference set).
    public var driveUnit: String
    /// Face to face (m), and the fraction of sound the faces return.
    public var gap: Double, reflection: Double
    public var patches: [Patch]
    public var inputs: [Input]
    public var frequencies: [Double]
    /// [frequency][input][patch] → [re, im]: patch normal velocity, m/s peak, per unit drive.
    public var response: [[[[Double]]]]
    public var uncertainty: Uncertainty

    public enum Invalid: Error, Equatable { case format(String), shape(String) }

    public func validate() throws {
        guard format == BodyResponse.format else { throw Invalid.format(format) }
        let lower = patches.filter { $0.plate == 0 }.count
        guard lower * 2 == patches.count, patches.allSatisfy({ $0.plate == 0 || $0.plate == 1 }) else { throw Invalid.shape("patches: the same number on each body") }
        guard patches.prefix(lower).allSatisfy({ $0.plate == 0 }) else { throw Invalid.shape("patches: the lower body's first") }
        guard !inputs.isEmpty, !frequencies.isEmpty, response.count == frequencies.count else { throw Invalid.shape("one response per frequency") }
        for f in response {
            guard f.count == inputs.count, f.allSatisfy({ $0.count == patches.count && $0.allSatisfy { $0.count == 2 && $0[0].isFinite && $0[1].isFinite } }) else {
                throw Invalid.shape("response: [frequency][input][patch][re, im]")
            }
        }
        guard gap > 0, inputs.allSatisfy({ $0.maxDrive > 0 }), patches.allSatisfy({ $0.radius > 0 }) else { throw Invalid.shape("gap, limits and radii are positive") }
    }

    public static func read(_ data: Data) throws -> BodyResponse {
        let b = try JSONDecoder().decode(BodyResponse.self, from: data)
        try b.validate()
        return b
    }

    /// The bodies as the engine's plates: patches as elements, inputs as channels.
    /// `seed`: one draw of the file's own uncertainty on every entry — a body
    /// as it might really be; nil = as given.
    public func array(seed: UInt64? = nil) -> PlateArray {
        let n = patches.count / 2
        var a = PlateArray(perPlate: n, plateRadius: patches.map { ($0.x * $0.x + $0.y * $0.y).squareRoot() + $0.radius }.max() ?? 0,
                           gap: gap, elementRadius: patches[0].radius, reflection: reflection)
        a.lowerSites = patches.prefix(n).map { PlateArray.Site(x: $0.x, y: $0.y, radius: $0.radius) }
        a.upperSites = patches.suffix(n).map { PlateArray.Site(x: $0.x, y: $0.y, radius: $0.radius) }
        var rng = SplitMix64(seed: seed ?? 0)
        func gauss() -> Double {
            let u1 = max(rng.nextUnit(), 1e-300), u2 = rng.nextUnit()
            return (-2 * log(u1)).squareRoot() * cos(2 * Double.pi * u2)
        }
        func entry(_ v: [Double]) -> Complex {
            let z = Complex(v[0], v[1])
            guard seed != nil else { return z }
            return z * Complex.expi(uncertainty.phaseDegrees * Double.pi / 180 * gauss()) * max(0, 1 + uncertainty.gain * gauss())
        }
        var w: [[[Complex]]] = []
        for f in response { var rows: [[Complex]] = []; for row in f { rows.append(row.map(entry)) }; w.append(rows) }
        a.inputs = PlateArray.InputMap(frequencies: frequencies, weights: w, plateOf: inputs.map(\.plate), maxDrive: inputs.map(\.maxDrive))
        a.label = "body-" + name + (seed.map { "-as\($0)" } ?? "")
        return a
    }

    /// Reference set 1: P0 itself written as a body — 32 inputs, each moving
    /// one patch at 1 m/s per unit. Through the interface it must behave as
    /// the native P0 plates do.
    public static func p0Identity(_ d: P0Design = P0Design()) -> BodyResponse {
        let r = ElementSpec.openType40k(medium: RH1Freestanding.roomAir).radius
        let sites = d.sites.map { ($0.x * 1e-3, $0.y * 1e-3) }
        let patches = [0, 1].flatMap { p in sites.map { Patch(x: $0.0, y: $0.1, plate: p, radius: r) } }
        let n = patches.count
        let resp = [(0..<n).map { i in (0..<n).map { e in e == i ? [1.0, 0.0] : [0.0, 0.0] } }]
        return BodyResponse(format: format, name: "p0-identity",
                            provenance: Provenance(status: "REFERENCE", source: "fieldc body reference", date: "2026-11-12", geometry: "P0Design, aperture A1",
                                                   note: "P0's 32 transmitters as 32 inputs of one patch each: a check of the interface, not a body"),
                            driveUnit: "m/s", gap: d.gap * 1e-3, reflection: d.reflection, patches: patches,
                            inputs: (0..<n).map { Input(name: "T\($0)", plate: $0 < n / 2 ? 0 : 1, maxDrive: d.fullVelocity) },
                            frequencies: [d.tone], response: resp, uncertainty: Uncertainty(gain: 0.1, phaseDegrees: 20))
    }

    /// Reference set 2: three inputs per body, each moving the whole face in
    /// a pattern of its own (one in phase, two tilted across x and y), with
    /// the phase of a lens that focuses on the centre of the gap. Made up:
    /// it says nothing of what a printed body does. It exists so that a
    /// six-input machine runs through calibration and the job.
    public static func threeInputDemo(gap: Double = 0.046, side: Int = 6, pitch: Double = 5e-3, maxVolts: Double = 100) -> BodyResponse {
        let air = RH1Freestanding.roomAir, f = 40_000.0, k = air.wavenumber(at: f)
        var pts: [(Double, Double)] = []
        for j in 0..<side { for i in 0..<side { pts.append((pitch * (Double(i) - Double(side - 1) / 2), pitch * (Double(j) - Double(side - 1) / 2))) } }
        let half = pitch * Double(side) / 2
        let patches = [0, 1].flatMap { p in pts.map { Patch(x: $0.0, y: $0.1, plate: p, radius: pitch / 2) } }
        let n = pts.count
        func row(_ plate: Int, _ shape: (Double, Double) -> Double) -> [[Double]] {
            (0..<(2 * n)).map { e in
                guard e / n == plate else { return [0, 0] }
                let (x, y) = pts[e % n]
                let lens = Complex.expi(-k * (x * x + y * y + gap * gap / 4).squareRoot())      // in phase at the centre
                let v = lens * (0.02 * shape(x / half, y / half))                                // 0.02 m/s per volt at most
                return [v.re, v.im]
            }
        }
        let shapes: [(Double, Double) -> Double] = [{ _, _ in 1 }, { x, _ in x }, { _, y in y }]
        let resp = [[0, 1].flatMap { p in shapes.map { row(p, $0) } }]
        return BodyResponse(format: format, name: "three-input-demo",
                            provenance: Provenance(status: "REFERENCE", source: "fieldc body reference", date: "2026-11-12", geometry: "none: a \(side) × \(side) patch square per body",
                                                   note: "synthetic: one uniform and two tilted patterns per body behind a fixed lens phase. Not a design and not a prediction"),
                            driveUnit: "V rms", gap: gap, reflection: 0.9, patches: patches,
                            inputs: [0, 1].flatMap { p in ["uniform", "tilt-x", "tilt-y"].map { Input(name: "\(p == 0 ? "lower" : "upper") \($0)", plate: p, maxDrive: maxVolts) } },
                            frequencies: [f], response: resp, uncertainty: Uncertainty(gain: 0.1, phaseDegrees: 10))
    }
}
