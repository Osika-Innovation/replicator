import Foundation

/// An object as an equation, not as port drives (`holo-eq/0.2`,
/// coordination/HOLO_EQUATION_SPEC.md).
///
/// WHAT THIS REPLACES AND WHY. `holo-field/0.1` stored the drive of each port
/// of one chamber at one air temperature. A file made for 12 ports and a
/// 109 mm wall says nothing to 36 ports, a 120 mm wall or air 2 K warmer.
/// Here the object is the field inside a sphere around it, in regular
/// spherical waves j_l(k r) Y_l^m about its own origin, per tone and per
/// stroke; each chamber compiles that onto the transfer it has measured.
///
/// This file is the schema and its checks. It does not compile an equation
/// onto a chamber and does not rotate or translate one: SIM's solvers do
/// (`holo/holo_equation.py`). Keys this type does not name (the writer's
/// `provenance.metrics`, `object_frame.targets_m`) are read past and are not
/// written back.
public struct HoloEquation: Codable, Sendable, Equatable {
    public static let format = "holo-eq/0.2"
    /// The largest order the spec allows: 169 modes per tone.
    public static let maxOrder = 12
    public static let maxRank = 8

    public struct Provenance: Codable, Sendable, Equatable {
        /// SIMULATED until a bench measured it.
        public var status: String
        public var source: String
        public var method: String
        public var particleID: String
        enum CodingKeys: String, CodingKey { case status, source, method, particleID = "particle_id" }
        public init(status: String, source: String, method: String, particleID: String) {
            self.status = status; self.source = source; self.method = method; self.particleID = particleID
        }
    }

    public struct ObjectFrame: Codable, Sendable, Equatable {
        public var id: String
        public var originOffset: [Double]       // m, 3
        public var boundRadius: Double          // m: the sphere the expansion holds in
        public var lMax: Int
        public var frequencies: [Double]        // Hz
        public var refSoundSpeed: Double        // m/s the amplitudes were made at
        enum CodingKeys: String, CodingKey {
            case id, originOffset = "origin_offset_m", boundRadius = "bound_radius_m", lMax = "l_max"
            case frequencies = "frequencies_hz", refSoundSpeed = "ref_sound_speed_ms"
        }
        public init(id: String, originOffset: [Double] = [0, 0, 0], boundRadius: Double, lMax: Int, frequencies: [Double], refSoundSpeed: Double) {
            self.id = id; self.originOffset = originOffset; self.boundRadius = boundRadius; self.lMax = lMax
            self.frequencies = frequencies; self.refSoundSpeed = refSoundSpeed
        }
    }

    /// One spherical wave of one tone: tone index t, degree l, order m, amplitude in Pa.
    public struct Mode: Codable, Sendable, Equatable {
        public var t: Int, l: Int, m: Int
        public var re: Double, im: Double
        public init(t: Int, l: Int, m: Int, re: Double, im: Double) { self.t = t; self.l = l; self.m = m; self.re = re; self.im = im }
        public var amplitude: Complex { Complex(re, im) }
    }

    public struct Stroke: Codable, Sendable, Equatable {
        public var index: Int
        public var durationMs: Double
        public var modes: [Mode]
        enum CodingKeys: String, CodingKey { case index = "stroke_index", durationMs = "duration_ms", modes = "c_nlm_sparse" }
        public init(index: Int, durationMs: Double, modes: [Mode]) { self.index = index; self.durationMs = durationMs; self.modes = modes }
    }

    /// The object's scattering, low rank per tone: T ≈ U diag(σ) Vᴴ.
    public struct TMatrix: Codable, Sendable, Equatable {
        public struct Tone: Codable, Sendable, Equatable {
            public var t: Int
            public var sigma: [Double]
            /// Each: σ.count columns of (l_max + 1)² entries, column after
            /// column, every entry [re, im]; or empty when only σ is carried.
            ///
            /// IN THE FILE these are nested the way `holo/holo_equation.py`
            /// writes them (`_pack_c`): one list per mode, holding one
            /// [re, im] per column. That is what is written here and what
            /// SIM's reader needs. A flat column-after-column list of
            /// [re, im], which the spec's note describes, is read as well.
            public var u: [[Double]], v: [[Double]]
            enum CodingKeys: String, CodingKey { case t, sigma, u = "U_re_im", v = "V_re_im" }
            public init(t: Int, sigma: [Double], u: [[Double]] = [], v: [[Double]] = []) { self.t = t; self.sigma = sigma; self.u = u; self.v = v }

            public init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                t = try c.decode(Int.self, forKey: .t)
                sigma = try c.decode([Double].self, forKey: .sigma)
                u = try Self.columns(c, .u, rank: sigma.count)
                v = try Self.columns(c, .v, rank: sigma.count)
            }
            private static func columns(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys, rank: Int) throws -> [[Double]] {
                guard rank > 0, c.contains(key) else { return [] }      // no columns: the writer still lists one empty row per mode
                if let flat = try? c.decode([[Double]].self, forKey: key) { return flat }
                let rows = try c.decode([[[Double]]].self, forKey: key)
                guard rows.allSatisfy({ $0.count == rank }) else {
                    throw DecodingError.dataCorruptedError(forKey: key, in: c, debugDescription: "every mode row needs \(rank) [re, im] entries")
                }
                var out: [[Double]] = []
                out.reserveCapacity(rows.count * rank)
                for j in 0..<rank { for row in rows { out.append(row[j]) } }
                return out
            }
            public func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(t, forKey: .t)
                try c.encode(sigma, forKey: .sigma)
                func rows(_ side: [[Double]]) -> [[[Double]]] {
                    let r = sigma.count
                    guard r > 0, !side.isEmpty, side.count % r == 0 else { return [] }
                    let n = side.count / r
                    return (0..<n).map { i in (0..<r).map { j in side[j * n + i] } }
                }
                try c.encode(rows(u), forKey: .u)
                try c.encode(rows(v), forKey: .v)
            }

            /// T = U diag(σ) Vᴴ as [row][column], or nil when U or V is not carried.
            public func dense() -> [[Complex]]? {
                let r = sigma.count
                guard r > 0, !u.isEmpty, u.count == v.count, u.count % r == 0 else { return nil }
                let n = u.count / r
                var out = [[Complex]](repeating: [Complex](repeating: .zero, count: n), count: n)
                for j in 0..<r {
                    for a in 0..<n {
                        let ua = u[j * n + a]
                        for b in 0..<n {
                            let vb = v[j * n + b]                       // times conj(V)
                            out[a][b] = Complex(out[a][b].re + sigma[j] * (ua[0] * vb[0] + ua[1] * vb[1]),
                                                out[a][b].im + sigma[j] * (ua[1] * vb[0] - ua[0] * vb[1]))
                        }
                    }
                }
                return out
            }
        }
        public var rank: Int
        public var perTone: [Tone]
        enum CodingKeys: String, CodingKey { case rank, perTone = "per_tone" }
        public init(rank: Int, perTone: [Tone]) { self.rank = rank; self.perTone = perTone }
    }

    public var format: String
    public var version: String
    public var provenance: Provenance
    public var objectFrame: ObjectFrame
    public var strokes: [Stroke]
    public var tMatrix: TMatrix?
    enum CodingKeys: String, CodingKey { case format, version, provenance, objectFrame = "object_frame", strokes, tMatrix = "t_matrix" }

    public init(provenance: Provenance, objectFrame: ObjectFrame, strokes: [Stroke], tMatrix: TMatrix? = nil) {
        self.format = Self.format; self.version = "0.2.0"
        self.provenance = provenance; self.objectFrame = objectFrame; self.strokes = strokes; self.tMatrix = tMatrix
    }

    public enum Invalid: Error, Equatable { case format(String), shape(String), value(String) }

    /// Spherical waves per tone: (l_max + 1)².
    public var modesPerTone: Int { (objectFrame.lMax + 1) * (objectFrame.lMax + 1) }
    /// Where (l, m) sits in a tone's dense vector: l² + l + m.
    public static func modeIndex(l: Int, m: Int) -> Int { l * l + l + m }
    /// The seconds each stroke starts at, and the total.
    public var strokeStarts: [Double] { strokes.indices.map { i in strokes[..<i].reduce(0) { $0 + $1.durationMs * 1e-3 } } }
    public var duration: Double { strokes.reduce(0) { $0 + $1.durationMs * 1e-3 } }

    /// One stroke's amplitudes in full: [tone][modeIndex].
    public func dense(stroke s: Int) -> [[Complex]] {
        var out = [[Complex]](repeating: [Complex](repeating: .zero, count: modesPerTone), count: objectFrame.frequencies.count)
        for m in strokes[s].modes { out[m.t][Self.modeIndex(l: m.l, m: m.m)] = m.amplitude }
        return out
    }

    public func validate() throws {
        guard format == Self.format else { throw Invalid.format("format \(format), expected \(Self.format)") }
        guard version.hasPrefix("0.2") else { throw Invalid.format("version \(version) is not 0.2") }
        guard !provenance.status.isEmpty else { throw Invalid.format("no provenance status") }
        let o = objectFrame, tones = o.frequencies.count
        guard tones > 0, o.frequencies.allSatisfy({ $0.isFinite && $0 > 0 }), zip(o.frequencies, o.frequencies.dropFirst()).allSatisfy({ $0 < $1 })
        else { throw Invalid.shape("frequencies must be positive and increasing") }
        guard (0...Self.maxOrder).contains(o.lMax) else { throw Invalid.shape("l_max \(o.lMax) outside 0...\(Self.maxOrder)") }
        guard o.originOffset.count == 3, o.originOffset.allSatisfy(\.isFinite) else { throw Invalid.shape("origin_offset_m needs three finite numbers") }
        guard o.boundRadius.isFinite, o.boundRadius > 0, o.refSoundSpeed.isFinite, o.refSoundSpeed > 0
        else { throw Invalid.value("bound radius and sound speed must be positive") }
        guard !strokes.isEmpty else { throw Invalid.shape("no strokes") }
        for (i, s) in strokes.enumerated() {
            guard s.index == i else { throw Invalid.shape("stroke \(i) carries stroke_index \(s.index)") }
            guard s.durationMs.isFinite, s.durationMs > 0 else { throw Invalid.value("stroke \(i): duration \(s.durationMs) ms") }
            var seen = Set<Int>()
            for m in s.modes {
                guard (0..<tones).contains(m.t) else { throw Invalid.shape("stroke \(i): tone index \(m.t) of \(tones)") }
                guard (0...o.lMax).contains(m.l), abs(m.m) <= m.l else { throw Invalid.shape("stroke \(i): no mode l \(m.l) m \(m.m) under l_max \(o.lMax)") }
                guard m.re.isFinite, m.im.isFinite else { throw Invalid.value("stroke \(i): a mode amplitude is not finite") }
                guard seen.insert(m.t * modesPerTone + Self.modeIndex(l: m.l, m: m.m)).inserted
                else { throw Invalid.shape("stroke \(i): tone \(m.t) l \(m.l) m \(m.m) appears twice") }
            }
        }
        if let tm = tMatrix {
            // rank 0 with no singular values is what the writer gives an equation that has no scan yet
            guard (0...Self.maxRank).contains(tm.rank) else { throw Invalid.shape("t_matrix rank \(tm.rank) outside 0...\(Self.maxRank)") }
            for p in tm.perTone {
                guard (0..<tones).contains(p.t) else { throw Invalid.shape("t_matrix: tone index \(p.t) of \(tones)") }
                guard p.sigma.count <= tm.rank, p.sigma.allSatisfy({ $0.isFinite && $0 >= 0 }), zip(p.sigma, p.sigma.dropFirst()).allSatisfy({ $0 >= $1 })
                else { throw Invalid.value("t_matrix tone \(p.t): sigma must be at most rank \(tm.rank) values, non-negative, descending") }
                for side in [p.u, p.v] where !side.isEmpty {
                    guard side.count == p.sigma.count * modesPerTone, side.allSatisfy({ $0.count == 2 && $0[0].isFinite && $0[1].isFinite })
                    else { throw Invalid.shape("t_matrix tone \(p.t): U and V need \(p.sigma.count) x \(modesPerTone) finite [re, im] entries") }
                }
            }
        }
    }

    public static func read(_ data: Data) throws -> HoloEquation {
        let e = try JSONDecoder().decode(HoloEquation.self, from: data)
        try e.validate()
        return e
    }

    public func write() throws -> Data {
        try validate()
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(self)
    }
}

/// `HLEQ v1`: one object's goal for the shared `CSQ8` network on Card 1, as
/// an output bias per stroke. The firmware's reader is `hleq_load` in
/// twin/Firmware/desktop/cadence_sparse_q8.c; the two must agree byte for
/// byte.
///
///     "HLEQ"  u16 version 1  u8 strokes (1...16)  u8 flags (bit 0 only)
///     u16 outputs (multiple of 8, ≤ 344)  u16 echo norm, Q15  f32 verify tolerance (0 < tol ≤ 1)
///     f16 bias[stroke][output][re, im]
///     u32 CRC-32 (IEEE) of everything before it          little-endian throughout
public struct HLEQPacket: Sendable, Equatable {
    public static let headerBytes = 16, maxStrokes = 16, maxOutputs = 344

    public var flags: UInt8
    public var echoNormQ15: UInt16
    public var verifyTol: Float
    /// [stroke][output], the padded output width (a multiple of 8).
    public var biases: [[Complex]]

    public init(biases: [[Complex]], echoNormQ15: UInt16 = 32768, verifyTol: Float, flags: UInt8 = 0) {
        self.biases = biases; self.echoNormQ15 = echoNormQ15; self.verifyTol = verifyTol; self.flags = flags
    }

    public enum Invalid: Error, Equatable { case short, magic, version, shape(String), value(String), crc, trailing }

    public var strokes: Int { biases.count }
    public var outputs: Int { biases.first?.count ?? 0 }
    public static func byteCount(strokes: Int, outputs: Int) -> Int { headerBytes + 4 * strokes * outputs + 4 }

    func check() throws {
        guard (1...Self.maxStrokes).contains(strokes) else { throw Invalid.shape("\(strokes) strokes, 1...\(Self.maxStrokes) allowed") }
        guard outputs > 0, outputs % 8 == 0, outputs <= Self.maxOutputs, biases.allSatisfy({ $0.count == outputs })
        else { throw Invalid.shape("every stroke needs the same output count, a multiple of 8 up to \(Self.maxOutputs)") }
        guard flags & 0xFE == 0 else { throw Invalid.value("reserved flag bits set") }
        guard verifyTol > 0, verifyTol <= 1 else { throw Invalid.value("verify tolerance \(verifyTol) outside (0, 1]") }
    }

    /// The packet's bytes. Throws when a bias does not fit a finite f16
    /// (|x| ≥ 65520), rather than send an infinity the firmware will refuse.
    public func serialized() throws -> [UInt8] {
        try check()
        var b: [UInt8] = Array("HLEQ".utf8) + [1, 0, UInt8(strokes), flags]
        func put16(_ v: UInt16) { b.append(UInt8(v & 0xFF)); b.append(UInt8(v >> 8)) }
        put16(UInt16(outputs)); put16(echoNormQ15)
        let tol = verifyTol.bitPattern
        for k in 0..<4 { b.append(UInt8((tol >> (8 * UInt32(k))) & 0xFF)) }
        for (s, stroke) in biases.enumerated() {
            for z in stroke {
                for x in [z.re, z.im] {
                    let h = Self.half(x)
                    guard h & 0x7C00 != 0x7C00 else { throw Invalid.value("stroke \(s): bias \(x) is not a finite f16") }
                    put16(h)
                }
            }
        }
        let crc = Self.crc32(b)
        for k in 0..<4 { b.append(UInt8((crc >> (8 * UInt32(k))) & 0xFF)) }
        return b
    }

    /// Read a packet, in the firmware's order: header length, magic,
    /// version, shape, exact length, CRC, then the values.
    /// `expectedOutputs`: the loaded image's padded output width.
    public static func parse(_ b: [UInt8], expectedOutputs: Int? = nil) throws -> HLEQPacket {
        guard b.count >= headerBytes + 4 else { throw Invalid.short }
        guard Array(b[0..<4]) == Array("HLEQ".utf8) else { throw Invalid.magic }
        func u16(_ at: Int) -> UInt16 { UInt16(b[at]) | UInt16(b[at + 1]) << 8 }
        func u32(_ at: Int) -> UInt32 { UInt32(u16(at)) | UInt32(u16(at + 2)) << 16 }
        guard u16(4) == 1 else { throw Invalid.version }
        let strokes = Int(b[6]), outputs = Int(u16(8))
        guard (1...maxStrokes).contains(strokes) else { throw Invalid.shape("\(strokes) strokes") }
        guard outputs > 0, outputs % 8 == 0, outputs <= maxOutputs, expectedOutputs.map({ $0 == outputs }) ?? true
        else { throw Invalid.shape("\(outputs) outputs") }
        let need = byteCount(strokes: strokes, outputs: outputs)
        guard b.count >= need else { throw Invalid.short }
        guard b.count == need else { throw Invalid.trailing }
        guard crc32(b[0..<(need - 4)]) == u32(need - 4) else { throw Invalid.crc }
        let tol = Float(bitPattern: u32(12))
        guard b[7] & 0xFE == 0 else { throw Invalid.value("reserved flag bits set") }
        guard tol > 0, tol <= 1 else { throw Invalid.value("verify tolerance \(tol)") }
        var biases: [[Complex]] = []
        for s in 0..<strokes {
            var row: [Complex] = []
            for i in 0..<outputs {
                let at = headerBytes + 4 * (s * outputs + i)
                let re = u16(at), im = u16(at + 2)
                guard re & 0x7C00 != 0x7C00, im & 0x7C00 != 0x7C00 else { throw Invalid.value("stroke \(s) output \(i): not finite") }
                row.append(Complex(value(half: re), value(half: im)))
            }
            biases.append(row)
        }
        return HLEQPacket(biases: biases, echoNormQ15: u16(10), verifyTol: tol, flags: b[7])
    }

    /// IEEE CRC-32 (reflected 0xEDB88320), the polynomial of `sb_crc32` and `hleq_crc32`.
    public static func crc32<S: Sequence>(_ bytes: S) -> UInt32 where S.Element == UInt8 {
        var c: UInt32 = 0xFFFF_FFFF
        for byte in bytes {
            c ^= UInt32(byte)
            for _ in 0..<8 { c = (c >> 1) ^ (0xEDB8_8320 & (0 &- (c & 1))) }
        }
        return ~c
    }

    /// A number as IEEE binary16, rounded to nearest even in one step from
    /// the double (as NumPy's `astype("<f2")` does). Too large: infinity.
    public static func half(_ x: Double) -> UInt16 {
        let sign: UInt16 = x.sign == .minus ? 0x8000 : 0
        let a = abs(x)
        if a.isNaN { return 0x7E00 }
        if a.isInfinite { return sign | 0x7C00 }
        if a == 0 { return sign }
        var e = Int(a.exponent)
        if e < -14 {                                                    // subnormal, or rounds up into the smallest normal
            return sign | UInt16((a * 16_777_216).rounded(.toNearestOrEven))
        }
        var m = scalbn(a, 10 - e).rounded(.toNearestOrEven)             // 1024 ... 2048
        if m == 2048 { m = 1024; e += 1 }
        if e > 15 { return sign | 0x7C00 }
        return sign | UInt16((e + 15) << 10) | UInt16(m - 1024)
    }

    /// The value of a binary16.
    public static func value(half h: UInt16) -> Double {
        let e = Int((h >> 10) & 31), m = Double(h & 1023)
        let v: Double = e == 0 ? scalbn(m, -24) : e == 31 ? (m == 0 ? .infinity : .nan) : scalbn(m + 1024, e - 25)
        return h & 0x8000 != 0 ? -v : v
    }
}

/// A multi-material object as species and sites (`holo-eq/0.3-mm`,
/// coordination/HOLO_EQUATION_SPEC.md §6; writer `holo/multimaterial_scan.py`).
///
/// The file does not carry a scattering matrix. It names what each small
/// sphere is made of and where it sits; any carrier's response (sound in air
/// or water, eddy currents, millimetre waves) is rebuilt from the element
/// table by SIM's code. This type reads, checks and writes the file. It does
/// not hold the element table and computes no response.
public struct HoloEquationMM: Codable, Sendable, Equatable {
    public static let format = "holo-eq/0.3-mm"
    public static let structures: Set<String> = ["fcc", "bcc", "sc", "diamond", "rocksalt", "hcp"]   // holo/materials.py STRUCTURES

    public struct Provenance: Codable, Sendable, Equatable {
        public var status: String
        public var source: String
        public var factorization: String?
        public init(status: String, source: String, factorization: String? = nil) { self.status = status; self.source = source; self.factorization = factorization }
    }

    public struct ObjectFrame: Codable, Sendable, Equatable {
        public var id: String
        public var lMax: Int
        public var acousticFrequencies: [Double]    // Hz
        public var emTEFrequencies: [Double]        // Hz, eddy-current band
        public var emTMFrequencies: [Double]        // Hz, millimetre-wave band
        enum CodingKeys: String, CodingKey {
            case id, lMax = "l_max", acousticFrequencies = "acoustic_freqs_hz", emTEFrequencies = "em_te_freqs_hz", emTMFrequencies = "em_tm_freqs_hz"
        }
        public init(id: String, lMax: Int, acousticFrequencies: [Double], emTEFrequencies: [Double] = [], emTMFrequencies: [Double] = []) {
            self.id = id; self.lMax = lMax; self.acousticFrequencies = acousticFrequencies
            self.emTEFrequencies = emTEFrequencies; self.emTMFrequencies = emTMFrequencies
        }
    }

    /// One element of a formula: atomic number and how many. In the file, `[14, 1]`.
    public struct Part: Codable, Sendable, Equatable {
        public var z: Int
        public var count: Double
        public init(z: Int, count: Double) { self.z = z; self.count = count }
        public init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            let zf = try c.decode(Double.self)
            guard zf == zf.rounded(), abs(zf) < 1000 else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "atomic number \(zf) is not a whole number") }
            z = Int(zf); count = try c.decode(Double.self)
            guard c.isAtEnd else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "a formula part is [Z, count]") }
        }
        public func encode(to encoder: Encoder) throws {
            var c = encoder.unkeyedContainer()
            try c.encode(z); try c.encode(count)
        }
    }

    /// The body of a `lattice` or `medium` entry. A lattice gives structure
    /// and cell edge, and its density follows; a medium gives the density.
    /// The five electrical and optical numbers are optional in both: without
    /// them SIM falls back to an element-weighted estimate.
    public struct Solid: Codable, Sendable, Equatable {
        public var formula: [Part]
        public var structure: String?               // lattice
        public var a: Double?                       // lattice: cell edge, angstrom
        public var cOverA: Double?
        public var formulaUnitsPerCell: Double?
        public var density: Double?                 // medium: kg/m3
        public var bulkModulus: Double              // GPa
        public var shearModulus: Double?            // GPa
        public var sigma: Double?, muR: Double?, epsR: Double?, rOpt470: Double?, rOpt650: Double?
        enum CodingKeys: String, CodingKey {
            case formula, structure, a = "a_A", cOverA = "c_over_a", formulaUnitsPerCell = "formula_units_per_cell", density
            case bulkModulus = "K_GPa", shearModulus = "G_GPa", sigma, muR = "mu_r", epsR = "eps_r", rOpt470 = "r_opt_470nm", rOpt650 = "r_opt_650nm"
        }
        public init(formula: [Part], structure: String? = nil, a: Double? = nil, density: Double? = nil, bulkModulus: Double, shearModulus: Double? = nil) {
            self.formula = formula; self.structure = structure; self.a = a; self.density = density
            self.bulkModulus = bulkModulus; self.shearModulus = shearModulus
        }
    }

    /// What a site is made of. Exactly one of the five forms per entry.
    public enum Species: Codable, Sendable, Equatable {
        /// `{"Z": 29}`: the element, from the table. A solid fraction below 1 is a foam of it.
        case element(z: Int, solidFraction: Double?)
        /// `{"key": "eps_foam_30"}`: a named material SIM's table knows. The name is not checked here.
        case key(String)
        /// `{"formula": [[14, 1], [8, 2]], "solid_fraction": 1.0}`: composition alone.
        case formula([Part], solidFraction: Double?)
        /// `{"lattice": {...}}`: a crystal.
        case lattice(Solid, name: String?)
        /// `{"medium": {...}}`: a stored medium with its measured density.
        case medium(Solid, name: String?)

        enum CodingKeys: String, CodingKey { case z = "Z", key, formula, solidFraction = "solid_fraction", lattice, medium, name }

        /// A bare formula is a mass-weighted estimate: against handbook
        /// values 2–3× low in density for real compounds (spec §6.3).
        public var isEstimate: Bool { if case .formula = self { return true }; return false }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let forms: [CodingKeys] = [.z, .key, .formula, .lattice, .medium].filter { c.contains($0) }
            guard forms.count == 1, let form = forms.first else {
                throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath, debugDescription: "a species needs exactly one of Z, key, formula, lattice, medium"))
            }
            let fraction = try c.decodeIfPresent(Double.self, forKey: .solidFraction), name = try c.decodeIfPresent(String.self, forKey: .name)
            switch form {
            case .z: self = .element(z: try c.decode(Int.self, forKey: .z), solidFraction: fraction)
            case .key: self = .key(try c.decode(String.self, forKey: .key))
            case .formula: self = .formula(try c.decode([Part].self, forKey: .formula), solidFraction: fraction)
            case .lattice: self = .lattice(try c.decode(Solid.self, forKey: .lattice), name: name)
            default: self = .medium(try c.decode(Solid.self, forKey: .medium), name: name)
            }
        }
        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .element(let z, let f): try c.encode(z, forKey: .z); try c.encodeIfPresent(f, forKey: .solidFraction)
            case .key(let k): try c.encode(k, forKey: .key)
            case .formula(let p, let f): try c.encode(p, forKey: .formula); try c.encodeIfPresent(f, forKey: .solidFraction)
            case .lattice(let s, let n): try c.encode(s, forKey: .lattice); try c.encodeIfPresent(n, forKey: .name)
            case .medium(let s, let n): try c.encode(s, forKey: .medium); try c.encodeIfPresent(n, forKey: .name)
            }
        }
    }

    /// One small sphere: centre in the object's frame, radius, index into the palette.
    public struct Site: Codable, Sendable, Equatable {
        public var r: [Double]          // m, 3
        public var radius: Double       // m
        public var species: Int
        enum CodingKeys: String, CodingKey { case r = "r_m", radius = "radius_m", species = "s" }
        public init(r: [Double], radius: Double, species: Int) { self.r = r; self.radius = radius; self.species = species }
    }

    public var format: String
    public var version: String
    public var provenance: Provenance
    public var objectFrame: ObjectFrame
    public var palette: [Species]
    public var sites: [Site]
    enum CodingKeys: String, CodingKey { case format, version, provenance, objectFrame = "object_frame", palette = "species_palette", sites }

    public init(provenance: Provenance, objectFrame: ObjectFrame, palette: [Species], sites: [Site]) {
        self.format = Self.format; self.version = "0.3.0"
        self.provenance = provenance; self.objectFrame = objectFrame; self.palette = palette; self.sites = sites
    }

    public typealias Invalid = HoloEquation.Invalid

    static func checkFormula(_ parts: [Part], _ at: String) throws {
        guard !parts.isEmpty else { throw Invalid.shape("\(at): empty formula") }
        for p in parts {
            guard (1...118).contains(p.z) else { throw Invalid.value("\(at): no element Z = \(p.z)") }
            guard p.count.isFinite, p.count > 0 else { throw Invalid.value("\(at): count \(p.count) of Z = \(p.z)") }
        }
    }
    static func checkFraction(_ f: Double?, _ at: String) throws {
        if let f, !(f.isFinite && f > 0 && f <= 1) { throw Invalid.value("\(at): solid_fraction \(f) outside (0, 1]") }
    }
    static func checkSolid(_ s: Solid, lattice: Bool, _ at: String) throws {
        try checkFormula(s.formula, at)
        guard s.bulkModulus.isFinite, s.bulkModulus > 0 else { throw Invalid.value("\(at): K_GPa \(s.bulkModulus)") }
        if let g = s.shearModulus, !(g.isFinite && g >= 0) { throw Invalid.value("\(at): G_GPa \(g)") }
        if lattice {
            guard let st = s.structure, structures.contains(st) else { throw Invalid.value("\(at): structure \(s.structure ?? "missing") is not one of \(structures.sorted())") }
            guard let a = s.a, a.isFinite, a > 0 else { throw Invalid.value("\(at): a lattice needs a_A > 0") }
            if let ca = s.cOverA, !(ca.isFinite && ca > 0) { throw Invalid.value("\(at): c_over_a \(ca)") }
            if let n = s.formulaUnitsPerCell, !(n.isFinite && n > 0) { throw Invalid.value("\(at): formula_units_per_cell \(n)") }
        } else {
            guard let d = s.density, d.isFinite, d > 0 else { throw Invalid.value("\(at): a medium needs density > 0") }
        }
        for x in [s.sigma, s.muR, s.epsR, s.rOpt470, s.rOpt650] { if let x, !x.isFinite { throw Invalid.value("\(at): a non-finite electrical or optical number") } }
    }

    public func validate() throws {
        guard format == Self.format else { throw Invalid.format("format \(format), expected \(Self.format)") }
        guard version.hasPrefix("0.3") else { throw Invalid.format("version \(version) is not 0.3") }
        guard !provenance.status.isEmpty else { throw Invalid.format("no provenance status") }
        let o = objectFrame
        guard (0...HoloEquation.maxOrder).contains(o.lMax) else { throw Invalid.shape("l_max \(o.lMax) outside 0...\(HoloEquation.maxOrder)") }
        for (name, f) in [("acoustic", o.acousticFrequencies), ("em_te", o.emTEFrequencies), ("em_tm", o.emTMFrequencies)] {
            guard f.allSatisfy({ $0.isFinite && $0 > 0 }), zip(f, f.dropFirst()).allSatisfy({ $0 < $1 })
            else { throw Invalid.shape("\(name) frequencies must be positive and increasing") }
        }
        guard !(o.acousticFrequencies.isEmpty && o.emTEFrequencies.isEmpty && o.emTMFrequencies.isEmpty) else { throw Invalid.shape("no carrier frequencies") }
        guard !palette.isEmpty else { throw Invalid.shape("empty species_palette") }
        for (i, sp) in palette.enumerated() {
            let at = "species \(i)"
            switch sp {
            case .element(let z, let f):
                guard (1...118).contains(z) else { throw Invalid.value("\(at): no element Z = \(z)") }
                try Self.checkFraction(f, at)
            case .key(let k): guard !k.isEmpty else { throw Invalid.value("\(at): empty key") }
            case .formula(let p, let f): try Self.checkFormula(p, at); try Self.checkFraction(f, at)
            case .lattice(let s, _): try Self.checkSolid(s, lattice: true, at)
            case .medium(let s, _): try Self.checkSolid(s, lattice: false, at)
            }
        }
        guard !sites.isEmpty else { throw Invalid.shape("no sites") }
        for (i, s) in sites.enumerated() {
            guard s.r.count == 3, s.r.allSatisfy(\.isFinite) else { throw Invalid.shape("site \(i): r_m needs three finite numbers") }
            guard s.radius.isFinite, s.radius > 0 else { throw Invalid.value("site \(i): radius \(s.radius)") }
            guard palette.indices.contains(s.species) else { throw Invalid.shape("site \(i): species index \(s.species) of \(palette.count)") }
        }
    }

    /// The palette entries that are estimates and are used by a site.
    public var estimatedSpecies: [Int] { palette.indices.filter { i in palette[i].isEstimate && sites.contains { $0.species == i } } }

    public static func read(_ data: Data) throws -> HoloEquationMM {
        let e = try JSONDecoder().decode(HoloEquationMM.self, from: data)
        try e.validate()
        return e
    }

    public func write() throws -> Data {
        try validate()
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(self)
    }
}
