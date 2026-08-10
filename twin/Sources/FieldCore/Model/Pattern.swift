import Foundation

/// The `.pattern` file (§19). Scan output, and — because the scan output is also
/// the build acceptance criterion (§4) — the thing the builder plays.
public struct PatternFile: Codable, Sendable {
    public var version = "pattern/0.2"
    public var meta: Meta
    public var material: MaterialRef
    public var band: [Double]                 // [low, high] Hz
    public var chords: [ChordRecord]

    public struct Meta: Codable, Sendable {
        public var name: String
        public var date: String
        public var source: String             // "emulated-scan" | "hardware"
        public var machine: String
        public var calibrationRef: String
        public var reconstruction: Reconstruction
        public var counts: Counts

        public struct Reconstruction: Codable, Sendable {
            public var rung: String
            public var greensFunction: String  // "measured" | "modelled"
            public init(rung: String, greensFunction: String) {
                self.rung = rung; self.greensFunction = greensFunction
            }
        }
        public struct Counts: Codable, Sendable {
            public var measured: Int
            public var inferred: Int
            public init(measured: Int, inferred: Int) {
                self.measured = measured; self.inferred = inferred
            }
        }
        public init(name: String, date: String, source: String, machine: String,
                    calibrationRef: String, reconstruction: Reconstruction,
                    counts: Counts) {
            self.name = name; self.date = date; self.source = source
            self.machine = machine; self.calibrationRef = calibrationRef
            self.reconstruction = reconstruction; self.counts = counts
        }
    }

    public struct MaterialRef: Codable, Sendable {
        public var name: String
        public var density: Double
        public var soundSpeed: Double
        public init(name: String, density: Double, soundSpeed: Double) {
            self.name = name; self.density = density; self.soundSpeed = soundSpeed
        }
    }

    /// One chord. `provenance` is REQUIRED and has NO DEFAULT (§16.3, G17): a
    /// reader that meets a chord without it must reject the file rather than
    /// assume "measured", because the assumption is the failure mode.
    public struct ChordRecord: Codable, Sendable {
        public var p: [Double]                // [re, im] rad/s
        public var r: [[Double]]              // per-gate [re, im]
        public var weight: Double
        public var provenance: String         // "measured" | "inferred"
        public var inferredBy: String?        // REQUIRED iff inferred
        public var coverage: Double?

        enum CodingKeys: String, CodingKey {
            case p, r, weight, provenance, inferredBy, coverage
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            p = try c.decode([Double].self, forKey: .p)
            r = try c.decode([[Double]].self, forKey: .r)
            weight = try c.decode(Double.self, forKey: .weight)
            // No decodeIfPresent, and no default: this is the enforcement point.
            guard let prov = try c.decodeIfPresent(String.self, forKey: .provenance) else {
                throw PatternError.missingProvenance
            }
            guard prov == "measured" || prov == "inferred" else {
                throw PatternError.badProvenance(prov)
            }
            provenance = prov
            inferredBy = try c.decodeIfPresent(String.self, forKey: .inferredBy)
            if prov == "inferred" && (inferredBy?.isEmpty ?? true) {
                throw PatternError.inferredWithoutSource
            }
            coverage = try c.decodeIfPresent(Double.self, forKey: .coverage)
        }

        public init(p: [Double], r: [[Double]], weight: Double,
                    provenance: String, inferredBy: String? = nil,
                    coverage: Double? = nil) {
            self.p = p; self.r = r; self.weight = weight
            self.provenance = provenance; self.inferredBy = inferredBy
            self.coverage = coverage
        }
    }

    public enum PatternError: Error, CustomStringConvertible, Equatable {
        case missingProvenance
        case badProvenance(String)
        case inferredWithoutSource
        case countsMismatch(declared: Int, actual: Int)

        public var description: String {
            switch self {
            case .missingProvenance:
                return "chord has no provenance — REJECTED. A missing tag must "
                     + "never be read as 'measured'; the assumption is the bug."
            case .badProvenance(let s):
                return "unknown provenance '\(s)' — expected measured|inferred"
            case .inferredWithoutSource:
                return "inferred chord without inferredBy — a fabricated interior "
                     + "must always be traceable to what fabricated it"
            case .countsMismatch(let d, let a):
                return "meta.counts says \(d) chords, chord list has \(a)"
            }
        }
    }

    public init(name: String, machine: String, calibrationRef: String,
                material: MaterialRef, band: [Double],
                chords: [MatrixPencil.Chord], rung: String,
                greensFunctionMeasured: Bool, source: String = "emulated-scan") {
        let recs = chords.map { ch in
            ChordRecord(p: [ch.pole.re, ch.pole.im],
                        r: ch.portVector.map { [$0.re, $0.im] },
                        weight: ch.weight,
                        provenance: ch.provenance.rawValue,
                        inferredBy: ch.provenance == .inferred ? "unspecified-prior" : nil)
        }
        self.meta = Meta(
            name: name, date: ISO8601DateFormatter().string(from: Date()),
            source: source, machine: machine, calibrationRef: calibrationRef,
            reconstruction: .init(rung: rung,
                                  greensFunction: greensFunctionMeasured
                                      ? "measured" : "modelled"),
            counts: .init(measured: recs.filter { $0.provenance == "measured" }.count,
                          inferred: recs.filter { $0.provenance == "inferred" }.count))
        self.material = material
        self.band = band
        self.chords = recs
    }

    /// Validate the schema rules G17 enforces.
    public func validate() throws {
        let m = chords.filter { $0.provenance == "measured" }.count
        let i = chords.filter { $0.provenance == "inferred" }.count
        if m != meta.counts.measured {
            throw PatternError.countsMismatch(declared: meta.counts.measured, actual: m)
        }
        if i != meta.counts.inferred {
            throw PatternError.countsMismatch(declared: meta.counts.inferred, actual: i)
        }
    }

    /// Chords a build may fabricate to. Inferred content is excluded BY DEFAULT
    /// (§16.3): you may look at it, you may not fabricate to it.
    public var buildableChords: [ChordRecord] {
        chords.filter { $0.provenance == "measured" }
    }

    public func encoded() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try e.encode(self)
    }

    public static func decode(_ data: Data) throws -> PatternFile {
        let p = try JSONDecoder().decode(PatternFile.self, from: data)
        try p.validate()
        return p
    }
}
