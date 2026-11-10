import Foundation
import FieldCore

/// `fieldc fcode …`, `fieldc play …`, `fieldc backend` — the machine program
/// layer (spec §19, M9): write a stream, play it through the emulated
/// backend, keep the frame log a serial link would carry.
enum MachineCommand {

    static func arg(_ args: [String], _ name: String) -> String? {
        args.firstIndex(of: name).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
    }

    static func world(_ name: String?, centre: Vec3) -> EmulatedBackend.World {
        switch name {
        case "point": return .init(scatterers: [centre + Vec3(2e-3, -1e-3, 3e-3)])
        case "ring":
            return .init(scatterers: (0..<48).map { q in
                let th = 2 * Double.pi * Double(q) / 48
                return centre + Vec3(8e-3 * cos(th), 8e-3 * sin(th), 0)
            })
        default: return .init()
        }
    }

    static func run(_ args: [String]) -> Int32 {
        let t0 = Date()
        switch args.first {

        case "backend":
            let r = Receipt(name: "backend", gates: MachineGates.runAll(), durationSeconds: Date().timeIntervalSince(t0),
                            device: deviceName(), gitSHA: gitSHA())
            print(r.summary)
            if args.contains("--receipt") { writeReceipt(r) }
            return r.allPassed ? 0 : 1

        case "fcode":
            // fieldc fcode demo [--array cad] [--out demo.fcode]
            let b = EmulatedBackend(array: plateArray(args))
            let f = FCodePrograms.demo(backend: b)
            let out = arg(args, "--out") ?? "demo.fcode"
            do {
                try f.json().write(to: URL(fileURLWithPath: out))
                let d = b.describe()
                print("\(out): \(f.frames.count) frames for \(d.name), \(d.channels) channels (\(b.array.tag)), calibration \(d.calibrationRef)")
                for fr in f.frames {
                    print(String(format: "  t %6.1f ms  %-6@ %d tones, %.1f ms, rx %d", fr.t * 1e3, fr.verb.rawValue as NSString,
                                 fr.tones.count, fr.duration * 1e3, fr.rxGates.count))
                }
                return 0
            } catch { print("could not write \(out): \(error)"); return 1 }

        case "play":
            // fieldc play <file.fcode> [--array cad] [--object point|ring] [--snr dB] [--log out.fcodelog] [--receipt]
            guard args.count > 1, let data = FileManager.default.contents(atPath: args[1]) else {
                print("usage: fieldc play <file.fcode> [--array cad] [--object point|ring] [--snr dB] [--log out.fcodelog] [--receipt]")
                return 2
            }
            do {
                let f = try FCodeFile.read(data)
                var b = EmulatedBackend(array: plateArray(args))
                b.world = world(arg(args, "--object"), centre: b.array.centre)
                b.snrDB = arg(args, "--snr").flatMap(Double.init)
                let d = b.describe()
                if f.calibrationRef != d.calibrationRef {
                    print("note: the stream was compiled for calibration \(f.calibrationRef); this machine is \(d.calibrationRef)")
                }
                let rec = try b.play(f)
                let empty = EmulatedBackend(array: b.array)
                var cache: [UInt64: [[Complex]]] = [:]
                let sent = try FCodeWire.decode(b.frameLog)
                print("\(d.name): \(d.channels) channels, \(b.world.scatterers.count) scatterers in the chamber")
                var worstEcho = 0.0
                for (i, fr) in rec.frames.enumerated() {
                    let s = sent.frames[i]
                    var line = String(format: "  t %6.1f ms  %-6@ %d tones", fr.t * 1e3, s.verb.rawValue as NSString, s.tones.count)
                    if !fr.rxGates.isEmpty {
                        let echo = MachineImaging.echo(of: fr, sent: s) { fq in
                            if cache[fq.bitPattern] == nil { cache[fq.bitPattern] = empty.transfer(frequency: fq) }
                            return cache[fq.bitPattern]!
                        }
                        let total = fr.tones.flatMap(\.received).reduce(0.0) { $0 + $1.magnitudeSquared }
                        let e = echo.flatMap { $0 }.reduce(0.0) { $0 + $1.magnitudeSquared }
                        let dB = e > 0 ? 10 * log10(e / total) : -Double.infinity
                        worstEcho = max(worstEcho, e > 0 ? dB : -400)
                        line += String(format: "  recorded on %d gates; echo of the chamber's contents %.0f dB below the plates' own crosstalk", fr.rxGates.count, -dB)
                    } else {
                        let v = s.tones.map { t in (zip(t.re, t.im).reduce(0.0) { $0 + $1.0 * $1.0 + $1.1 * $1.1 } / Double(f.channels)).squareRoot() }
                        line += String(format: "  drive %.3g m/s rms per channel", v.max() ?? 0)
                    }
                    print(line)
                }
                let log = arg(args, "--log") ?? (args[1] as NSString).deletingPathExtension + ".fcodelog"
                try Data(b.frameLog).write(to: URL(fileURLWithPath: log))
                print("frame log: \(log), \(b.frameLog.count) bytes (what a serial backend puts on the link)")
                // M9: replay the log and compare.
                var again = EmulatedBackend(array: b.array, world: b.world, snrDB: b.snrDB)
                let rec2 = try again.play(sent)
                let same = rec2 == rec && again.frameLog == b.frameLog
                let gates = [GateResult(id: "G-FC3", name: "the frame log replays identically (records and bytes)",
                                        measured: same ? 0 : 1, threshold: 0.5,
                                        detail: "\(rec.frames.count) frames, \(b.frameLog.count) bytes, \(b.array.tag)")]
                let r = Receipt(name: "play-\((args[1] as NSString).lastPathComponent)", gates: gates,
                                durationSeconds: Date().timeIntervalSince(t0), device: deviceName(), gitSHA: gitSHA())
                print(r.summary)
                if args.contains("--receipt") { writeReceipt(r) }
                return r.allPassed ? 0 : 1
            } catch { print("cannot play \(args[1]): \(error)"); return 1 }

        default:
            print("usage: fieldc backend [--receipt] | fieldc fcode demo [--array cad] [--out f.fcode] | fieldc play <f.fcode> [--object point|ring]")
            return 2
        }
    }
}
