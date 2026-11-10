import Foundation

/// The `.fcode` file (spec §19): what the compiler emits and a machine plays.
/// A time-ordered list of frames; each frame is a chord — per tone, one
/// complex drive per channel — with a verb and the gates to record on.
///
/// Deviation from the spec's sketch, stated: the spec lists the drive as
/// `per-channel { band, re, im }`. Here a frame holds its tones and each tone
/// holds every channel's (re, im). Same information, one frequency stored
/// once per tone instead of once per channel.
public struct FCodeFile: Codable, Sendable, Equatable {
    public static let currentVersion = "fcode/0.1"

    public enum Verb: String, Codable, Sendable, CaseIterable {
        case add = "ADD", remove = "REMOVE", listen = "LISTEN"

        public init(_ v: ChordDrive.Verb) {
            switch v { case .assemble: self = .add; case .dissolve: self = .remove; case .listen: self = .listen }
        }
        public var chordVerb: ChordDrive.Verb {
            switch self { case .add: return .assemble; case .remove: return .dissolve; case .listen: return .listen }
        }
    }

    public struct Tone: Codable, Sendable, Equatable {
        public var frequency: Double          // Hz
        public var re: [Double]               // per channel, element face velocity (m/s)
        public var im: [Double]
        public init(frequency: Double, drive: [Complex]) {
            self.frequency = frequency; re = drive.map(\.re); im = drive.map(\.im)
        }
        public var drive: [Complex] { zip(re, im).map { Complex($0, $1) } }
    }

    public struct Frame: Codable, Sendable, Equatable {
        public var t: Double                  // start, seconds from the stream's start
        public var duration: Double           // seconds the chord is held
        public var verb: Verb
        public var tones: [Tone]
        public var rxGates: [Int]
        public init(t: Double, duration: Double, verb: Verb, tones: [Tone], rxGates: [Int] = []) {
            self.t = t; self.duration = duration; self.verb = verb; self.tones = tones; self.rxGates = rxGates
        }
        public init(t: Double, duration: Double, chord: ChordDrive) {
            self.init(t: t, duration: duration, verb: Verb(chord.verb),
                      tones: chord.tones.map { Tone(frequency: $0.frequency, drive: $0.gates) }, rxGates: chord.rxGates)
        }
        public var chord: ChordDrive {
            ChordDrive(tones: tones.map { ChordDrive.Tone(frequency: $0.frequency, gates: $0.drive) },
                       verb: verb.chordVerb, rxGates: rxGates)
        }
    }

    public var version: String
    public var machine: String
    public var calibrationRef: String
    public var band: [Double]                 // [low, high] Hz
    public var channels: Int
    public var frames: [Frame]

    public init(machine: String, calibrationRef: String, band: [Double], channels: Int, frames: [Frame] = []) {
        version = FCodeFile.currentVersion
        self.machine = machine; self.calibrationRef = calibrationRef
        self.band = band; self.channels = channels; self.frames = frames
    }

    public enum Invalid: Error, CustomStringConvertible, Equatable {
        case version(String), band, channelCount(frame: Int, tone: Int, got: Int)
        case rxGate(frame: Int, gate: Int), order(frame: Int), frequency(frame: Int, Double)
        case notFinite(frame: Int), wire(String)
        public var description: String {
            switch self {
            case .version(let v): return "not an fcode file this reader knows (version \(v))"
            case .band: return "band must be [low, high] with 0 < low < high"
            case .channelCount(let f, let t, let n): return "frame \(f) tone \(t): \(n) drives, not one per channel"
            case .rxGate(let f, let g): return "frame \(f): rx gate \(g) is not a channel"
            case .order(let f): return "frame \(f) starts before the previous frame ends"
            case .frequency(let f, let hz): return "frame \(f): tone at \(hz) Hz is outside the band"
            case .notFinite(let f): return "frame \(f): a drive, time or frequency is not finite"
            case .wire(let why): return "frame log: \(why)"
            }
        }
    }

    /// A file a machine may play: right version, every tone one drive per
    /// channel and inside the band, frames in time order, rx gates real.
    public func validate() throws {
        guard version.hasPrefix("fcode/0.") else { throw Invalid.version(version) }
        guard band.count == 2, band[0] > 0, band[1] > band[0] else { throw Invalid.band }
        var end = 0.0
        for (i, f) in frames.enumerated() {
            guard f.t.isFinite, f.duration.isFinite, f.duration >= 0 else { throw Invalid.notFinite(frame: i) }
            guard f.t >= end - 1e-9 else { throw Invalid.order(frame: i) }
            end = f.t + f.duration
            for g in f.rxGates where g < 0 || g >= channels { throw Invalid.rxGate(frame: i, gate: g) }
            for (j, tone) in f.tones.enumerated() {
                guard tone.re.count == channels, tone.im.count == channels else {
                    throw Invalid.channelCount(frame: i, tone: j, got: min(tone.re.count, tone.im.count))
                }
                guard tone.frequency.isFinite else { throw Invalid.notFinite(frame: i) }
                guard tone.frequency >= band[0] * (1 - 1e-9), tone.frequency <= band[1] * (1 + 1e-9) else {
                    throw Invalid.frequency(frame: i, tone.frequency)
                }
                guard tone.re.allSatisfy(\.isFinite), tone.im.allSatisfy(\.isFinite) else { throw Invalid.notFinite(frame: i) }
            }
        }
    }

    /// Canonical JSON: sorted keys, shortest round-trip numbers, so the same
    /// stream is the same bytes.
    public func json() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(self)
    }

    public static func read(_ data: Data) throws -> FCodeFile {
        let f = try JSONDecoder().decode(FCodeFile.self, from: data)
        try f.validate()
        return f
    }
}

/// The frame log: `.fcode` as the bytes a serial link carries to the drive
/// electronics. Little-endian, every frame closed by a CRC-32.
///
///   header  "FCD1" · u16 wire version · u16 channels · f32 band low · f32 band high · u32 frames · u32 crc
///   frame   0xA5 · u8 verb · u16 tones · u32 t (µs) · u32 duration (µs) · u16 rx count · rx gates u16…
///           per tone: f32 frequency · f32 full scale (m/s) · channels × (i16 re, i16 im)
///           u32 crc of the frame
///
/// Drives are 16-bit signed fractions of the tone's full scale — what a DAC
/// channel takes. Encoding therefore quantises; decoding a log and encoding it
/// again gives the same bytes, and the emulated machine plays the decoded
/// (quantised) stream, so it plays what hardware would be sent.
public enum FCodeWire {
    public static let magic: [UInt8] = Array("FCD1".utf8)
    public static let wireVersion: UInt16 = 1

    static let crcTable: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = c & 1 == 1 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }
    public static func crc32(_ bytes: ArraySlice<UInt8>) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for b in bytes { c = crcTable[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }

    static func put<T: FixedWidthInteger>(_ v: T, _ out: inout [UInt8]) {
        withUnsafeBytes(of: v.littleEndian) { out.append(contentsOf: $0) }
    }
    static func put(_ v: Float, _ out: inout [UInt8]) { put(v.bitPattern, &out) }

    static func verbCode(_ v: FCodeFile.Verb) -> UInt8 {
        switch v { case .add: return 1; case .remove: return 2; case .listen: return 3 }
    }

    public static func encode(_ f: FCodeFile) throws -> [UInt8] {
        try f.validate()
        guard f.channels <= Int(UInt16.max), f.frames.count <= Int(UInt32.max) else { throw FCodeFile.Invalid.wire("too large") }
        var out: [UInt8] = magic
        put(wireVersion, &out); put(UInt16(f.channels), &out)
        put(Float(f.band[0]), &out); put(Float(f.band[1]), &out)
        put(UInt32(f.frames.count), &out)
        put(crc32(out[...]), &out)
        for fr in f.frames {
            let start = out.count
            out.append(0xA5); out.append(verbCode(fr.verb))
            put(UInt16(fr.tones.count), &out)
            put(UInt32((fr.t * 1e6).rounded()), &out); put(UInt32((fr.duration * 1e6).rounded()), &out)
            put(UInt16(fr.rxGates.count), &out)
            for g in fr.rxGates { put(UInt16(g), &out) }
            for tone in fr.tones {
                var peak = 0.0
                for c in 0..<f.channels { peak = max(peak, abs(tone.re[c]), abs(tone.im[c])) }
                let scale = Float(peak)
                put(Float(tone.frequency), &out); put(scale, &out)
                let s = Double(scale)
                for c in 0..<f.channels {
                    let re = s > 0 ? (tone.re[c] / s * 32767).rounded() : 0
                    let im = s > 0 ? (tone.im[c] / s * 32767).rounded() : 0
                    put(Int16(max(-32767, min(32767, re))), &out)
                    put(Int16(max(-32767, min(32767, im))), &out)
                }
            }
            put(crc32(out[start...]), &out)
        }
        return out
    }

    struct Reader {
        let bytes: [UInt8]
        var at = 0
        mutating func take<T: FixedWidthInteger>(_: T.Type) throws -> T {
            let n = MemoryLayout<T>.size
            guard at + n <= bytes.count else { throw FCodeFile.Invalid.wire("truncated at byte \(at)") }
            var v: T = 0
            withUnsafeMutableBytes(of: &v) { $0.copyBytes(from: bytes[at..<(at + n)]) }
            at += n
            return T(littleEndian: v)
        }
        mutating func float() throws -> Float { Float(bitPattern: try take(UInt32.self)) }
    }

    /// Decode a frame log. `machine` and `calibrationRef` are not on the wire
    /// (the link is point to point); the caller says which machine it was for.
    public static func decode(_ bytes: [UInt8], machine: String = "", calibrationRef: String = "") throws -> FCodeFile {
        var r = Reader(bytes: bytes)
        guard bytes.count >= 24, Array(bytes[0..<4]) == magic else { throw FCodeFile.Invalid.wire("not a frame log") }
        r.at = 4
        guard try r.take(UInt16.self) == wireVersion else { throw FCodeFile.Invalid.wire("unknown wire version") }
        let channels = Int(try r.take(UInt16.self))
        let lo = Double(try r.float()), hi = Double(try r.float())
        let count = Int(try r.take(UInt32.self))
        guard try r.take(UInt32.self) == crc32(bytes[0..<20]) else { throw FCodeFile.Invalid.wire("header checksum") }
        var file = FCodeFile(machine: machine, calibrationRef: calibrationRef, band: [lo, hi], channels: channels)
        for i in 0..<count {
            let start = r.at
            guard try r.take(UInt8.self) == 0xA5 else { throw FCodeFile.Invalid.wire("frame \(i): lost sync") }
            let verb: FCodeFile.Verb
            switch try r.take(UInt8.self) {
            case 1: verb = .add
            case 2: verb = .remove
            case 3: verb = .listen
            default: throw FCodeFile.Invalid.wire("frame \(i): unknown verb")
            }
            let tones = Int(try r.take(UInt16.self))
            let t = Double(try r.take(UInt32.self)) / 1e6, dur = Double(try r.take(UInt32.self)) / 1e6
            let rx = try (0..<Int(try r.take(UInt16.self))).map { _ in Int(try r.take(UInt16.self)) }
            var ts: [FCodeFile.Tone] = []
            for _ in 0..<tones {
                let freq = Double(try r.float()), s = Double(try r.float())
                var d = [Complex](repeating: .zero, count: channels)
                for c in 0..<channels {
                    let re = Double(try r.take(Int16.self)), im = Double(try r.take(Int16.self))
                    d[c] = Complex(re / 32767 * s, im / 32767 * s)
                }
                ts.append(FCodeFile.Tone(frequency: freq, drive: d))
            }
            let end = r.at
            guard try r.take(UInt32.self) == crc32(bytes[start..<end]) else { throw FCodeFile.Invalid.wire("frame \(i): checksum") }
            file.frames.append(FCodeFile.Frame(t: t, duration: dur, verb: verb, tones: ts, rxGates: rx))
        }
        guard r.at == bytes.count else { throw FCodeFile.Invalid.wire("\(bytes.count - r.at) bytes after the last frame") }
        return file
    }
}
