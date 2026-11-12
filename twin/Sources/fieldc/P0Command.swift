import FieldCore
import FieldGPU
import Foundation

/// `fieldc p0 …` — prototype P0, the platform's first configuration: the
/// link to its controller, its calibration and its hold / move / release job.
enum P0Command {

    /// The bench machine the twin stands in for: P0 as one random build.
    static let build: PlateArray.Tolerance = {
        var t = PlateArray.Tolerance()
        t.gain = 0.10; t.phaseDegrees = 20; t.position = 0.2e-3; t.resonance = 0.003
        return t
    }()
    /// What a calibration at one point leaves unmeasured: where each element is.
    static let unseen: PlateArray.Tolerance = { var t = PlateArray.Tolerance(); t.position = 0.2e-3; return t }()
    static let air = RH1Freestanding.roomAir
    /// Calibration plays each element at a pulse 16 steps wide of 512: quiet
    /// enough for a microphone 30 mm away, and a width the controller makes exactly.
    static let pulseSteps = 512
    static var fullVelocity: Double { P0Design().fullVelocity }
    /// A job may ask an element for this share of the datasheet's nominal
    /// full drive: a unit at the datasheet's −3 dB limit still gives it.
    static let ceiling = 0.708
    static var calibrationVelocity: Double { fullVelocity * sin(Double.pi * 16 / Double(pulseSteps)) }

    static func machine(_ args: [String], seed: UInt64 = 7) -> EmulatedBackend {
        let drawn = plateArray(["--array", "p0"] + args)
        var b = EmulatedBackend(array: drawn.asBuilt(build, seed: seed), name: "P0 (emulated build \(seed))", band: [39_000, 41_000])
        b.probes = [drawn.centre]
        b.pulse = (pulseSteps, fullVelocity)
        return b
    }

    /// The controller core compiled for this computer, on a pair of pipes.
    /// `transfer`: ADC counts at the probe per m/s of each drive channel.
    static func simulator(transfer: [Complex], channels: Int, gap: Double) throws -> (SerialBackend, Process) {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("p0sim-\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let exe = tmp.appendingPathComponent("p0sim").path
        let cc = Process()
        cc.executableURL = URL(fileURLWithPath: "/usr/bin/cc")
        cc.arguments = ["-O2", "-o", exe, "Firmware/p0/fcore.c", "Firmware/p0/sim_main.c", "-lm"]
        try cc.run(); cc.waitUntilExit()
        guard cc.terminationStatus == 0 else { throw FCodeFile.Invalid.wire("the firmware did not compile") }
        var file: [UInt8] = []
        FCodeWire.put(UInt16(channels), &file); FCodeWire.put(UInt16(transfer.count), &file)
        for v in transfer { FCodeWire.put(Float(v.re), &file); FCodeWire.put(Float(v.im), &file) }
        let tf = tmp.appendingPathComponent("transfer.bin")
        try Data(file).write(to: tf)
        let p = Process(), toSim = Pipe(), fromSim = Pipe()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = [String(fullVelocity), tf.path, String(gap)]
        p.standardInput = toSim; p.standardOutput = fromSim
        try p.run()
        return (try SerialBackend(read: fromSim.fileHandleForReading, write: toSim.fileHandleForWriting), p)
    }

    static func run(_ args: [String]) -> Int32 {
        let t0 = Date()
        do {
            switch args.dropFirst().first {
            case "link": return try link(args, t0)
            case "job": return try job(args, t0)
            case "cad": return try cad(args, t0)
            default:
                print("usage: fieldc p0 cad [--out dir] | link | job [--port /dev/cu.usbmodem…] [--gap mm] [--out dir] [--receipt]")
                return 2
            }
        } catch { print("p0: \(error)"); return 1 }
    }

    /// G-HW1…3: the same calibration program through the emulated machine and
    /// through the controller's own code on a byte link.
    static func link(_ args: [String], _ t0: Date) throws -> Int32 {
        var emu = machine(args)
        let drawn = plateArray(["--array", "p0"] + args), built = emu.array
        let n = drawn.channels, probeGate = n
        // What the microphone makes of the field: 1 Pa = `counts` ADC counts, and a delay.
        let row = built.reference(frequency: 40_000, medium: air).gateRow(at: drawn.centre)
        let g = built.gains([40_000], curve: true)![0]
        let loudest = (0..<n).map { (row[$0] * g[$0]).magnitude }.max()! * calibrationVelocity
        let mic = Complex.expi(1.1) * (1500 / loudest)                 // the loudest channel at 1500 of ±2048 counts
        let (hw0, proc) = try simulator(transfer: (0..<n).map { row[$0] * g[$0] * mic }, channels: probeGate, gap: drawn.gap)
        var hw = hw0
        defer { proc.terminate() }
        let d = hw.describe()
        print("link: \(d.name), \(d.channels) channels, gap \(String(format: "%.0f", d.gap * 1000)) mm, air \(d.temperature ?? .nan) °C, supply \(d.supply ?? .nan) V")
        let program = Calibration.program(emu.describe(), drive: 0..<n, probeGate: probeGate, frequency: 40_000, velocity: calibrationVelocity)
        let fromEmu = try emu.play(program), fromHW = try hw.play(program)
        // 1. the records agree (the microphone's scale and delay divided out)
        var worstAmp = 0.0, worstDeg = 0.0
        for c in 0..<n {
            let a = fromEmu.frames[c].tones[0].received[0], b = fromHW.frames[c].tones[0].received[0] * mic.conjugate * (1 / mic.magnitudeSquared)
            worstAmp = max(worstAmp, abs(b.magnitude / a.magnitude - 1))
            worstDeg = max(worstDeg, abs(atan2((b * a.conjugate).im, (b * a.conjugate).re)) * 180 / Double.pi)
        }
        // 2. each backend's calibration finds what the build does at the probe:
        // its elements' gain and phase and, through their misplacement, their path.
        let rowDrawn = drawn.reference(frequency: 40_000, medium: air).gateRow(at: drawn.centre)
        let truth = (0..<n).map { row[$0] * g[$0] * rowDrawn[$0].conjugate * (1 / rowDrawn[$0].magnitudeSquared) }
        func worst(_ r: Calibration.Record) -> (Double, Double) {
            var da = 0.0, dp = 0.0
            for c in 0..<n {
                let plate = c < n / 2 ? 0..<(n / 2) : (n / 2)..<n
                let mean = plate.reduce(Complex.zero) { $0 + truth[$1] } * (1 / Double(plate.count))
                let t = truth[c] * mean.conjugate * (1 / mean.magnitudeSquared), q = r.errors[c] * t.conjugate * (1 / t.magnitudeSquared)
                da = max(da, abs(q.magnitude - 1)); dp = max(dp, abs(atan2(q.im, q.re)) * 180 / Double.pi)
            }
            return (da, dp)
        }
        let date = ISO8601DateFormatter().string(from: Date())
        let calEmu = try Calibration.run(&emu, array: drawn, medium: air, probe: drawn.centre, probeGate: probeGate, velocity: calibrationVelocity, date: date)
        let calHW = try Calibration.run(&hw, array: drawn, medium: air, probe: drawn.centre, probeGate: probeGate, velocity: calibrationVelocity, date: date)
        let (ea, ep) = worst(calEmu), (ha, hp) = worst(calHW)
        let lowerMean = (0..<(n / 2)).reduce(Complex.zero) { $0 + truth[$1] }, upperMean = ((n / 2)..<n).reduce(Complex.zero) { $0 + truth[$1] }
        let between = atan2((upperMean * lowerMean.conjugate).im, (upperMean * lowerMean.conjugate).re) * 180 / Double.pi
        let sameBytes = (try FCodeWire.encode(program)) == Array(emu.frameLog.prefix(try FCodeWire.encode(program).count))
        let gates = [
            GateResult(id: "G-HW1", name: "the controller's records vs the emulated machine's, calibration program (amplitude, fraction)",
                       measured: worstAmp, threshold: 0.02,
                       detail: String(format: "%d channels one at a time; worst phase difference %.2f°; 12-bit converter, pulse width %d steps of %d; the frame log sent is %@ the emulator's",
                                      n, worstDeg, 16, pulseSteps, sameBytes ? "byte for byte" : "NOT")),
            GateResult(id: "G-HW2", name: "the controller's records vs the emulated machine's (phase, degrees)", measured: worstDeg, threshold: 1.0, detail: ""),
            GateResult(id: "G-HW3", name: "calibration through the link finds each channel's phase at the probe (degrees, worst channel)", measured: hp, threshold: 1,
                       detail: String(format: "build: %@; through the link gain within %.2f %%, phase within %.2f°; through the emulator %.2f %%, %.2f°. One microphone at one point: an element's misplacement is found as phase there, not as position. Not found: the phase between the plates, %.1f° on this build (%.2f mm of trap height)",
                                      Self.build.text, 100 * ha, hp, 100 * ea, ep, between, abs(between) / 360 * 4.29)),
        ]
        for g in gates { print(g.line) }
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "p0-link-\(drawn.tag)", gates: gates, durationSeconds: Date().timeIntervalSince(t0), device: deviceName(), gitSHA: gitSHA()))
        }
        return gates.allSatisfy(\.passed) ? 0 : 1
    }

    /// A hold / move / release job compiled on `array`: hold at the pick-up,
    /// carry 5 mm up and 5 mm across, hold, drive off. `stream` writes it
    /// at `level` × the drive that just holds the bead, `step` s per 0.25 mm.
    struct Plan {
        let carry: PlaceCommand.Carry
        /// Σ|g|² scale for 1× holding, (m/s)².
        let holding: Double
        var path: [Vec3] { carry.path }

        func stream(_ m: MachineDescription, level: Double, step: Double) -> (job: FCodeFile, hardest: Double) {
            let scale = (level * holding).squareRoot(), f0 = carry.rig.freqs[0]
            var f = FCodeFile(machine: m.name, calibrationRef: m.calibrationRef, band: m.band, channels: m.channels)
            var t = 0.0, hardest = 0.0
            for (i, d) in carry.drives.enumerated() {
                let dur = i == 0 ? 1.0 : (i == carry.drives.count - 1 ? 0.5 : step)
                var v = d[0].map { $0 * scale }
                hardest = max(hardest, v.map(\.magnitude).max() ?? 0)
                v += [Complex](repeating: .zero, count: m.channels - v.count)
                f.frames.append(FCodeFile.Frame(t: t, duration: dur, verb: .add, tones: [FCodeFile.Tone(frequency: f0, drive: v)]))
                t += dur
            }
            f.frames.append(FCodeFile.Frame(t: t, duration: 0.2, verb: .remove,
                                            tones: [FCodeFile.Tone(frequency: f0, drive: [Complex](repeating: .zero, count: m.channels))]))
            return (f, hardest)
        }
    }

    static func plan(_ ctx: MetalContext, on array: PlateArray) throws -> Plan? {
        guard let c = try PlaceCommand.carrySequence(ctx, [], array: array) else { return nil }
        let (lattice, field) = try box(c.path, c.rig)
        let U0 = field.potential(c.drives[0], particle: c.rig.particle)
        var up = 0.0
        for q in -15...15 { if let g = latticeGradient(lattice, U0, c.path[0] + Vec3(0, 0, Double(q) * lattice.spacing)) { up = max(up, -g.z) } }
        return up > 0 ? Plan(carry: c, holding: c.rig.particle.mass() * 9.81 / up) : nil
    }

    /// The gentlest job the machine's own model says will carry the bead:
    /// the model is the plates as calibrated, played through the same pulse
    /// widths. Tried in order of drive, then of patience. nil = none does.
    static func choose(_ ctx: MetalContext, _ plan: Plan, model: EmulatedBackend, machine m: MachineDescription)
        throws -> (job: FCodeFile, hardest: Double, level: Double, step: Double, predicted: Double)? {
        // From 4× holding: a 2× job passed its models and lost the bead on one emulated build.
        for level in [4.0, 6, 8] { for step in [0.04, 0.08] {
            let c = plan.stream(m, level: level, step: step)
            guard c.hardest < ceiling * fullVelocity else { continue }
            // …on the model, and on two copies of it with what the calibration
            // cannot see: the elements moved ±0.2 mm, and the upper plate
            // 15° ahead of or behind the lower.
            var worst = 0.0
            for (seed, turn) in [(UInt64(0), 0.0), (101, 15), (102, -15)] {
                var a = seed == 0 ? model.array : model.array.asBuilt(unseen, seed: seed)
                if turn != 0, var e = a.channelError {
                    for c in a.perPlate..<a.channels { e[c] = e[c] * Complex.expi(turn * Double.pi / 180) }
                    a.channelError = e
                }
                var m2 = EmulatedBackend(array: a, band: model.band)
                m2.pulse = model.pulse
                let r = try ride(ctx, c.job, path: plan.path, step: step, on: m2)
                if ProcessInfo.processInfo.environment["FIELDC_VERBOSE"] != nil {
                    print(String(format: "  plan %.0f× %.0f ms, hardest %.2f, variant %d (%+.0f°): %@", level, step * 1000, c.hardest / fullVelocity, Int(seed), turn,
                                 r.map { String(format: "travel error %.2f mm, absolute %.2f, lag %.2f", $0.end * 1000, $0.absolute * 1000, $0.worst * 1000) } ?? "left the trap"))
                }
                // The model itself with margin; a copy within the acceptance bar.
                guard let r, r.end < (seed == 0 ? 0.25e-3 : 0.5e-3) else { worst = .infinity; break }
                worst = max(worst, r.end)
            }
            if worst.isFinite { return (c.job, c.hardest, level, step, worst) }
        } }
        return nil
    }

    /// A 0.1 mm lattice round a path, and the field on it.
    static func box(_ path: [Vec3], _ rig: PlaceRig) throws -> (FieldLattice, ArrayFieldGPU) {
        let margin = 3e-3, fs = 0.1e-3
        let lo = Vec3(path.map(\.x).min()! - margin, path.map(\.y).min()! - margin, path.map(\.z).min()! - margin)
        let hi = Vec3(path.map(\.x).max()! + margin, path.map(\.y).max()! + margin, path.map(\.z).max()! + margin)
        let fb = FieldLattice(origin: lo, spacing: fs, nx: Int(((hi.x - lo.x) / fs).rounded()) + 1,
                              ny: Int(((hi.y - lo.y) / fs).rounded()) + 1, nz: Int(((hi.z - lo.z) / fs).rounded()) + 1)
        return (fb, try rig.field(on: fb))
    }

    /// The bead through a job as `machine` radiates it: 16-bit drives, pulse
    /// widths, the build's own elements. `end`: how far the bead's travel
    /// (from where it was first held to where it is when the drive goes off)
    /// is from the travel asked for, m — what a camera can measure. `absolute`:
    /// how far it ends from the drawing's drop-off point; that includes where
    /// the probe sat, which no bench knows better than its fixture. nil = it
    /// left the trap.
    static func ride(_ ctx: MetalContext, _ job: FCodeFile, path: [Vec3], step: Double, on machine: EmulatedBackend) throws -> (end: Double, worst: Double, absolute: Double)? {
        let sent = try FCodeWire.decode(try FCodeWire.encode(job))
        let rig = try PlaceRig(ctx: ctx, array: machine.array, freqs: [40_000], particle: PlaceCommand.bead(machine.array).material)
        let (fb, field) = try box(path, rig)
        let Us = sent.frames.dropLast().map { fr in
            field.potential([fr.tones[0].drive.prefix(machine.array.channels).map(machine.pulsed)], particle: rig.particle)
        }
        let r = PlaceCommand.ride(Us: Us, lattice: fb, path: path, power: 1, stepTime: step, particle: rig.particle, settling: rig.settling)
        return r.escaped ? nil : (((r.end - r.start) - (path.last! - path[0])).length, r.worst, (r.end - path.last!).length)
    }

    /// Calibrate, compile, play: on the emulated build, or on the bench with
    /// --port. The same calls either way; on the bench the camera judges.
    static func job(_ args: [String], _ t0: Date) throws -> Int32 {
        let ctx = try MetalContext()
        let drawn = plateArray(["--array", "p0"] + args), n = drawn.channels
        let date = ISO8601DateFormatter().string(from: Date())
        let out = MachineCommand.arg(args, "--out").map { URL(fileURLWithPath: $0) }
        func save(_ cal: Calibration.Record, _ job: FCodeFile) throws {
            guard let out else { return }
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys, .prettyPrinted]
            try enc.encode(cal).write(to: out.appendingPathComponent("calibration.json"))
            try job.json().write(to: out.appendingPathComponent("hold_move_release.fcode"))
            print("wrote calibration.json and hold_move_release.fcode to \(out.path)")
        }
        if let port = MachineCommand.arg(args, "--port") {
            var hw = try SerialBackend(port: port)
            let d = hw.describe()
            print("\(d.name): \(d.channels) channels, air \(d.temperature ?? .nan) °C, supply \(d.supply ?? .nan) V")
            let cal = try Calibration.run(&hw, array: drawn, medium: air, probe: drawn.centre, probeGate: n, velocity: calibrationVelocity, date: date) { pass in
                print(pass == 0 ? "fit the probe bar on its spacers, receiver facing DOWN, then press return"
                                : "turn the bar over, without the spacers, receiver facing UP, then press return")
                _ = readLine()
            }
            let worstDeg = cal.errors.map { abs(atan2($0.im, $0.re)) * 180 / Double.pi }.max() ?? 0
            print(String(format: "calibrated: gains %.2f–%.2f of their mean, phases within %.0f° of it", cal.errors.map(\.magnitude).min() ?? 0, cal.errors.map(\.magnitude).max() ?? 0, worstDeg))
            print("remove the probe, then press return to play the job"); _ = readLine()
            var model = EmulatedBackend(array: drawn.calibrated(cal), band: d.band)
            model.probes = [drawn.centre]; model.pulse = (pulseSteps, fullVelocity)
            guard let pl = try plan(ctx, on: model.array), let p = try choose(ctx, pl, model: model, machine: d) else { print("no job the model carries"); return 1 }
            try save(cal, p.job)
            _ = try hw.play(p.job)
            print(String(format: "played: %d frames at %.0f× holding, %.0f ms per step, hardest element at %.2f of full drive; the model predicts the bead %.2f mm from the drop-off. The camera record judges it (P0 acceptance protocol).",
                         p.job.frames.count, p.level, p.step * 1000, p.hardest / fullVelocity, p.predicted * 1000))
            return 0
        }
        var emu = machine(args, seed: MachineCommand.arg(args, "--seed").flatMap(UInt64.init) ?? 7)
        let cal = try Calibration.run(&emu, array: drawn, medium: air, probe: drawn.centre, probeGate: n, velocity: calibrationVelocity, date: date)
        var model = EmulatedBackend(array: drawn.calibrated(cal), band: emu.band)
        model.probes = emu.probes; model.pulse = emu.pulse
        guard let pl = try plan(ctx, on: model.array), let p = try choose(ctx, pl, model: model, machine: emu.describe()),
              let rawPlan = try plan(ctx, on: drawn) else { print("no job the model carries"); return 1 }
        let raw = rawPlan.stream(emu.describe(), level: p.level, step: p.step)
        try save(cal, p.job)
        _ = try emu.play(p.job)
        let rode = try ride(ctx, p.job, path: pl.path, step: p.step, on: emu), rodeRaw = try ride(ctx, raw.job, path: rawPlan.path, step: p.step, on: emu)
        func text(_ r: (end: Double, worst: Double, absolute: Double)?) -> String {
            r.map { String(format: "travel off by %.2f mm; %.2f mm from the drawing's drop-off; worst lag %.2f mm", $0.end * 1000, $0.absolute * 1000, $0.worst * 1000) } ?? "the bead left the trap"
        }
        let gates = [
            GateResult(id: "G-P0a", name: "hold, 5 mm up, 5 mm across, hold: a \(PlaceCommand.bead(drawn).name) bead on the emulated build, job compiled on its calibration (its travel vs the travel asked, mm)",
                       measured: rode.map { $0.end * 1000 } ?? .infinity, threshold: 0.5,
                       detail: "\(drawn.tag), build: \(Self.build.text); \(String(format: "%.0f× holding, %.0f ms per 0.25 mm (chosen on the calibrated model and two copies with the elements moved ±0.2 mm and the plates ±15° apart; worst predicted travel error %.2f mm)", p.level, p.step * 1000, p.predicted * 1000)); 16-bit wire, pulse widths of \(pulseSteps) steps; \(text(rode))"),
            GateResult(id: "G-P0b", name: "the job's hardest-driven element ÷ the transmitter's full drive", measured: p.hardest / fullVelocity, threshold: ceiling,
                       detail: String(format: "%.2f m/s of %.2f (the datasheet level at a 0–15 V square wave); the bar is the datasheet's −3 dB unit", p.hardest, fullVelocity)),
            GateResult(id: "P0-RAW", name: "control: the same job compiled on the drawing, uncalibrated, on the same build (travel error, mm)",
                       measured: rodeRaw.map { $0.end * 1000 } ?? .infinity, threshold: 0.5, comparison: .informational, detail: text(rodeRaw)),
        ]
        for g in gates { print(g.line) }
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "p0-job-\(drawn.tag)", gates: gates, durationSeconds: Date().timeIntervalSince(t0), device: deviceName(), gitSHA: gitSHA()))
        }
        return gates.allSatisfy(\.passed) ? 0 : 1
    }

    /// The frame's solids checked and written: STL per printed part, the
    /// design as JSON, a dimensioned drawing of the aperture plate.
    static func cad(_ args: [String], _ t0: Date) throws -> Int32 {
        var d = P0Design()
        if let g = MachineCommand.arg(args, "--gap").flatMap(Double.init) { d.gap = g }
        let m = P0Model(d)
        var open = 0, worstVolume = 0.0
        for p in m.parts {
            let t = p.mesh.welded().topology()
            if !t.isClosed { open += 1 }
            if let v = p.analyticVolume { worstVolume = max(worstVolume, abs(abs(p.volume) - v) / v) }
        }
        let bad = m.fits.filter { $0.clearance < $0.minimum }
        for f in m.fits { print(String(format: "  %@ %@  %.2f mm (min %.2f)", f.clearance >= f.minimum ? "✓" : "✗", f.what, f.clearance, f.minimum)) }
        let gates = [
            GateResult(id: "G-P0C1", name: "P0 frame: every part a closed solid", measured: Double(open), threshold: 0.5, detail: "\(m.parts.count) parts"),
            GateResult(id: "G-P0C2", name: "P0 frame: mesh volume vs closed form", measured: worstVolume, threshold: 0.01, detail: ""),
            GateResult(id: "G-P0C3", name: "P0 frame: fit checks failed", measured: Double(bad.count), threshold: 0.5,
                       detail: bad.isEmpty ? "\(m.fits.count) checks" : bad.map(\.what).joined(separator: "; ")),
        ]
        for g in gates { print(g.line) }
        if let out = MachineCommand.arg(args, "--out").map({ URL(fileURLWithPath: $0) }) {
            try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
            for p in m.parts where p.material == .polymer && !p.name.hasSuffix("upper") && !p.name.hasSuffix("2") {
                try STL.writeBinary(p.mesh.soup, to: out.appendingPathComponent(CADExport.slug(p.name.replacingOccurrences(of: " lower", with: "").replacingOccurrences(of: " 1", with: "")) + ".stl"))
            }
            let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys, .prettyPrinted]
            struct Params: Encodable { var design: P0Design; var channels: [[Double]]; var fullVelocity: Double; var plateSpacing: Double }
            let ch = d.sites.enumerated().map { [Double($0.offset), $0.element.x, $0.element.y] }
            try enc.encode(Params(design: d, channels: ch, fullVelocity: d.fullVelocity, plateSpacing: d.plateSpacing)).write(to: out.appendingPathComponent("p0_params.json"))
            try drawing(d).write(to: out.appendingPathComponent("aperture_plate.svg"), atomically: true, encoding: .utf8)
            print("wrote STL, p0_params.json and aperture_plate.svg to \(out.path)")
        }
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "p0-cad", gates: gates, durationSeconds: Date().timeIntervalSince(t0), device: deviceName(), gitSHA: gitSHA()))
        }
        return gates.allSatisfy(\.passed) ? 0 : 1
    }

    /// The aperture plate in plan, seen from the cans' side, 2 px per mm.
    static func drawing(_ d: P0Design) -> String {
        let k = 4.0, h = d.plateSize / 2, pad = 12.0, size = (d.plateSize + 2 * pad) * k
        func x(_ v: Double) -> Double { (v + h + pad) * k }
        func y(_ v: Double) -> Double { (h - v + pad) * k }
        var s = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 \(size) \(size + 220)' font-family='Helvetica' font-size='13'>\n<rect width='100%' height='100%' fill='white'/>\n"
        s += "<rect x='\(x(-h))' y='\(y(h))' width='\(d.plateSize * k)' height='\(d.plateSize * k)' fill='none' stroke='black' stroke-width='1.5'/>\n"
        for c in [(-1.0, -1.0), (1, -1), (1, 1), (-1, 1)] {
            s += "<circle cx='\(x(c.0 * d.rodSquare / 2))' cy='\(y(c.1 * d.rodSquare / 2))' r='\(d.rodHole / 2 * k)' fill='none' stroke='black'/>\n"
        }
        for (i, p) in d.sites.enumerated() {
            s += "<circle cx='\(x(p.x))' cy='\(y(p.y))' r='\(d.canDiameter / 2 * k)' fill='none' stroke='#999' stroke-dasharray='4 3'/>\n"
            for dx in [-d.pinPitch / 2, d.pinPitch / 2] { s += "<circle cx='\(x(p.x + dx))' cy='\(y(p.y))' r='\(d.pinHole / 2 * k)' fill='black'/>\n" }
            s += "<text x='\(x(p.x))' y='\(y(p.y) - 9)' text-anchor='middle' fill='#555'>\(i)</text>\n"
        }
        let notes = [
            "P0 aperture plate A1 — \(d.side) × \(d.side) transmitters, 40 kHz. Seen from the cans' side; channel numbers as the twin's.",
            "Plate \(Int(d.plateSize)) × \(Int(d.plateSize)) × \(Int(d.plateThickness)) mm, printed PETG, 4 perimeters, 40 % infill. General tolerance ±0.2 mm.",
            "4 rod holes Ø\(d.rodHole) on a \(Int(d.rodSquare)) mm square (the frame's datum). \(2 * d.perPlate) pin holes Ø\(d.pinHole): two per can, \(d.pinPitch) mm apart along x,",
            "cans at \(d.pitch) mm pitch, centred on the plate. Dashed: the can (Ø\(d.canDiameter) ± 0.3), standing on this side.",
            "Signal pin at −x of each pair, ground at +x. Print two. The upper plate is this part turned over about the x axis: its channel 16 + n is the can facing n.",
        ]
        for (i, n) in notes.enumerated() { s += "<text x='\(pad * k)' y='\(size + 30 + Double(i) * 24)'>\(n)</text>\n" }
        return s + "</svg>\n"
    }

    /// `fieldc upgrades`: the upgrade dependency graph (Design/upgrade_graph.json)
    /// in build order, checked: nothing depends on itself, and whatever is
    /// not bought names its tolerance and its inspection.
    static func upgrades(_ args: [String]) -> Int32 {
        struct Rec: Decodable { var id, what, by, gain, status: String; var needs: [String]; var tolerance, inspection: String?; var humanMinutes: Double }
        struct File: Decodable { var records: [Rec] }
        guard let data = FileManager.default.contents(atPath: "Design/upgrade_graph.json"), let file = try? JSONDecoder().decode(File.self, from: data) else {
            print("cannot read Design/upgrade_graph.json"); return 2
        }
        let byID = Dictionary(uniqueKeysWithValues: file.records.map { ($0.id, $0) })
        var order: [Rec] = [], done = Set<String>(), left = file.records
        while !left.isEmpty {
            let ready = left.filter { $0.needs.allSatisfy(done.contains) }
            if ready.isEmpty { break }
            order += ready; done.formUnion(ready.map(\.id)); left.removeAll { done.contains($0.id) }
        }
        let unknown = file.records.flatMap { r in r.needs.filter { byID[$0] == nil }.map { "\(r.id) needs \($0)" } }
        let bare = file.records.filter { $0.by != "external" && ($0.tolerance == nil || $0.inspection == nil) }.map(\.id)
        print("| # | id | what | by | needs | status | human min (est.) |\n|---:|---|---|---|---|---|---:|")
        for (i, r) in order.enumerated() {
            print("| \(i + 1) | \(r.id) | \(r.what) | \(r.by) | \(r.needs.joined(separator: ", ")) | \(r.status) | \(Int(r.humanMinutes)) |")
        }
        let gates = [
            GateResult(id: "G-UP1", name: "upgrade graph: records that depend on themselves or on nothing known", measured: Double(left.count + unknown.count), threshold: 0.5,
                       detail: left.isEmpty && unknown.isEmpty ? "\(order.count) records in build order" : (left.map(\.id) + unknown).joined(separator: "; ")),
            GateResult(id: "G-UP2", name: "upgrade graph: made or measured records without a tolerance and an inspection", measured: Double(bare.count), threshold: 0.5,
                       detail: bare.joined(separator: ", ")),
        ]
        for g in gates { print(g.line) }
        if args.contains("--receipt") { writeReceipt(Receipt(name: "upgrades", gates: gates, durationSeconds: 0, device: deviceName(), gitSHA: gitSHA())) }
        return gates.allSatisfy(\.passed) ? 0 : 1
    }
}
