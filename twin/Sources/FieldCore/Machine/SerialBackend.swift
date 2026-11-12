import Foundation

/// What a machine sends back over the link: its description and the records
/// of a played stream. Little-endian, CRC-32 closed, like `FCodeWire`.
///
///   query   "FCQ1"
///   info    "FCI1" · u16 channels · u16 per plate · f32 gap (m) · f32 band low · f32 band high
///           · f32 air °C · f32 supply V (NaN = not measured) · u8 n · n bytes serial · u32 crc
///   records "FCR1" · u32 frames · u32 crc
///   frame   0x5A · u8 0 · u16 tones · u32 t (µs) · u16 rx count · rx gates u16…
///           per tone: f32 frequency · rx count × (f32 re, f32 im) · u32 crc of the frame
public enum RecordWire {
    public static let query: [UInt8] = Array("FCQ1".utf8)

    public static func encode(_ m: MachineDescription, serial: String) -> [UInt8] {
        var out: [UInt8] = Array("FCI1".utf8)
        FCodeWire.put(UInt16(m.channels), &out); FCodeWire.put(UInt16(m.perPlate), &out)
        FCodeWire.put(Float(m.gap), &out); FCodeWire.put(Float(m.band[0]), &out); FCodeWire.put(Float(m.band[1]), &out)
        FCodeWire.put(Float(m.temperature ?? .nan), &out); FCodeWire.put(Float(m.supply ?? .nan), &out)
        let s = Array(serial.utf8.prefix(255))
        out.append(UInt8(s.count)); out += s
        FCodeWire.put(FCodeWire.crc32(out[...]), &out)
        return out
    }

    public static func encode(_ r: PortRecords) -> [UInt8] {
        var out: [UInt8] = Array("FCR1".utf8)
        FCodeWire.put(UInt32(r.frames.count), &out)
        FCodeWire.put(FCodeWire.crc32(out[...]), &out)
        for fr in r.frames {
            let start = out.count
            out += [0x5A, 0]
            FCodeWire.put(UInt16(fr.tones.count), &out); FCodeWire.put(UInt32((fr.t * 1e6).rounded()), &out)
            FCodeWire.put(UInt16(fr.rxGates.count), &out)
            for g in fr.rxGates { FCodeWire.put(UInt16(g), &out) }
            for tone in fr.tones {
                FCodeWire.put(Float(tone.frequency), &out)
                for v in tone.received { FCodeWire.put(Float(v.re), &out); FCodeWire.put(Float(v.im), &out) }
            }
            FCodeWire.put(FCodeWire.crc32(out[start...]), &out)
        }
        return out
    }
}

/// A machine on the other end of a byte link — a USB serial port, or a pair
/// of pipes to the firmware compiled for this computer. It is sent exactly
/// the frame log the emulated machine keeps, so a stream that plays on one
/// plays on the other.
public struct SerialBackend: MachineBackend {
    let input: FileHandle, output: FileHandle
    public private(set) var info: MachineDescription
    public private(set) var serial = ""

    public init(read: FileHandle, write: FileHandle) throws {
        input = read; output = write
        info = MachineDescription(name: "", channels: 0, perPlate: 0, gap: 0, band: [], calibrationRef: "")
        try output.write(contentsOf: Data(RecordWire.query))
        var all = try take(29)
        guard Array(all[0..<4]) == Array("FCI1".utf8) else { throw FCodeFile.Invalid.wire("no machine answered the query") }
        all += try take(Int(all[28]) + 4)
        var r = FCodeWire.Reader(bytes: all); r.at = 4
        let ch = Int(try r.take(UInt16.self)), per = Int(try r.take(UInt16.self))
        let gap = Double(try r.float()), lo = Double(try r.float()), hi = Double(try r.float())
        let temp = try r.float(), supply = try r.float()
        let n = Int(try r.take(UInt8.self))
        serial = String(decoding: all[r.at..<(r.at + n)], as: UTF8.self); r.at += n
        guard try r.take(UInt32.self) == FCodeWire.crc32(all[0..<(all.count - 4)]) else { throw FCodeFile.Invalid.wire("info checksum") }
        info = MachineDescription(name: "P0 \(serial)", channels: ch, perPlate: per, gap: gap, band: [lo, hi],
                                  calibrationRef: "hw-\(serial)", temperature: temp.isNaN ? nil : Double(temp),
                                  supply: supply.isNaN ? nil : Double(supply))
    }

    /// A serial device, put in raw mode (a USB CDC port ignores the baud rate).
    public init(port path: String) throws {
        let fd = open(path, O_RDWR | O_NOCTTY)
        guard fd >= 0 else { throw FCodeFile.Invalid.wire("cannot open \(path)") }
        var t = termios()
        tcgetattr(fd, &t); cfmakeraw(&t); tcsetattr(fd, TCSANOW, &t)
        let h = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        try self.init(read: h, write: h)
    }

    func take(_ n: Int) throws -> [UInt8] {
        var out: [UInt8] = []
        while out.count < n {
            guard let d = try input.read(upToCount: n - out.count), !d.isEmpty else { throw FCodeFile.Invalid.wire("the link closed") }
            out += d
        }
        return out
    }

    public func describe() -> MachineDescription { info }

    public func calibrate() throws -> CalibrationMatrix {
        throw FCodeFile.Invalid.wire("a machine on a link is calibrated by playing `Calibration.program`")
    }

    public mutating func play(_ stream: FCodeFile) throws -> PortRecords {
        try output.write(contentsOf: Data(try FCodeWire.encode(stream)))
        let head = try take(12)
        guard Array(head[0..<4]) == Array("FCR1".utf8) else { throw FCodeFile.Invalid.wire("the machine refused the stream") }
        var h = FCodeWire.Reader(bytes: head); h.at = 4
        let count = Int(try h.take(UInt32.self))
        guard try h.take(UInt32.self) == FCodeWire.crc32(head[0..<8]) else { throw FCodeFile.Invalid.wire("records checksum") }
        var out = PortRecords()
        for i in 0..<count {
            var b = try take(10)
            var r = FCodeWire.Reader(bytes: b); r.at = 2
            let tones = Int(try r.take(UInt16.self)), t = Double(try r.take(UInt32.self)) / 1e6, rx = Int(try r.take(UInt16.self))
            b += try take(2 * rx + tones * (4 + 8 * rx) + 4)
            r = FCodeWire.Reader(bytes: b); r.at = 10
            let gates = try (0..<rx).map { _ in Int(try r.take(UInt16.self)) }
            var ts: [PortRecords.Tone] = []
            for _ in 0..<tones {
                let f = Double(try r.float())
                ts.append(PortRecords.Tone(frequency: f, received: try (0..<rx).map { _ in Complex(Double(try r.float()), Double(try r.float())) }))
            }
            guard b[0] == 0x5A, try r.take(UInt32.self) == FCodeWire.crc32(b[0..<(b.count - 4)]) else {
                throw FCodeFile.Invalid.wire("record \(i): checksum")
            }
            out.frames.append(PortRecords.Frame(t: t, rxGates: gates, tones: ts))
        }
        return out
    }

    /// Silence, recorded: frames with no drive.
    public mutating func listen(_ gates: [Int], steps: Int) throws -> PortRecords {
        var f = FCodeFile(machine: info.name, calibrationRef: info.calibrationRef, band: info.band, channels: info.channels)
        let quiet = [Complex](repeating: .zero, count: info.channels)
        f.frames = (0..<steps).map { FCodeFile.Frame(t: Double($0) * 0.02, duration: 0.02, verb: .listen,
                                                     tones: [FCodeFile.Tone(frequency: info.band[0], drive: quiet)], rxGates: gates) }
        return try play(f)
    }
}
