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
            case "matrix": return try matrix(args, t0)
            case "body":
                // fieldc p0 body [--out dir]: write the two reference body-response files.
                let dir = URL(fileURLWithPath: MachineCommand.arg(args, "--out") ?? "Design/bodies")
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
                for b in [BodyResponse.p0Identity(), BodyResponse.threeInputDemo()] {
                    try b.validate()
                    try enc.encode(b).write(to: dir.appendingPathComponent(b.name + ".json"))
                    print("wrote \(dir.path)/\(b.name).json: \(b.inputs.count) inputs, \(b.patches.count) patches [\(b.provenance.status)]")
                }
                return 0
            case "cad": return try cad(args, t0)
            default:
                print("usage: fieldc p0 cad [--out dir] | link | matrix | body | job [--body file.json] [--port /dev/cu.usbmodem…] [--gap mm] [--out dir] [--receipt]")
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
                let mean = truth.reduce(Complex.zero, +) * (1 / Double(n))     // a point microphone: one normalisation
                let t = truth[c] * mean.conjugate * (1 / mean.magnitudeSquared), q = r.errors[c] * t.conjugate * (1 / t.magnitudeSquared)
                da = max(da, abs(q.magnitude - 1)); dp = max(dp, abs(atan2(q.im, q.re)) * 180 / Double.pi)
            }
            return (da, dp)
        }
        let date = ISO8601DateFormatter().string(from: Date())
        let calEmu = try Calibration.run(&emu, array: drawn, medium: air, probe: drawn.centre, probeGate: probeGate, velocity: calibrationVelocity, date: date, kind: .point)
        let calHW = try Calibration.run(&hw, array: drawn, medium: air, probe: drawn.centre, probeGate: probeGate, velocity: calibrationVelocity, date: date, kind: .point)
        let (ea, ep) = worst(calEmu), (ha, hp) = worst(calHW)
        let sameBytes = (try FCodeWire.encode(program)) == Array(emu.frameLog.prefix(try FCodeWire.encode(program).count))
        let gates = [
            GateResult(id: "G-HW1", name: "the controller's records vs the emulated machine's, calibration program (amplitude, fraction)",
                       measured: worstAmp, threshold: 0.02,
                       detail: String(format: "%d channels one at a time; worst phase difference %.2f°; 12-bit converter, pulse width %d steps of %d; the frame log sent is %@ the emulator's",
                                      n, worstDeg, 16, pulseSteps, sameBytes ? "byte for byte" : "NOT")),
            GateResult(id: "G-HW2", name: "the controller's records vs the emulated machine's (phase, degrees)", measured: worstDeg, threshold: 1.0, detail: ""),
            GateResult(id: "G-HW3", name: "calibration through the link finds each channel's phase at the probe (degrees, worst channel)", measured: hp, threshold: 1,
                       detail: String(format: "build: %@; through the link gain within %.2f %%, phase within %.2f°; through the emulator %.2f %%, %.2f°. One microphone at one point: an element's misplacement is found as phase there, not as position. The link test uses a point microphone, which hears both plates",
                                      Self.build.text, 100 * ha, hp, 100 * ea, ep)),
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

    /// A machine as the bench simulation needs it: the drawing, how a real
    /// one differs from it, and what the planner may assume it has not seen.
    struct Setup {
        var drawn: PlateArray
        /// One real machine (held-out truth), by seed.
        var truth: (UInt64) -> PlateArray
        /// A copy of the calibrated model moved by what calibration cannot
        /// see, the upper plate turned by `turn` degrees.
        var copy: (_ calibrated: PlateArray, _ seed: UInt64, _ turn: Double) -> PlateArray
        /// Full drive of one channel, in the drive's unit, and the drive calibration plays.
        var full: Double, calibration: Double
        var pulse: (steps: Int, full: Double)?
        var buildText: String

        static func turned(_ a: PlateArray, _ degrees: Double) -> PlateArray {
            var a = a
            let t = Complex.expi(degrees * Double.pi / 180), n = a.driveChannels
            if a.inputs != nil {
                var e = a.inputs!.error ?? [Complex](repeating: .one, count: n)
                for c in 0..<n where a.plate(of: c) == 1 { e[c] = e[c] * t }
                a.inputs!.error = e
            } else if var e = a.channelError {
                for c in 0..<n where a.plate(of: c) == 1 { e[c] = e[c] * t }
                a.channelError = e
            }
            return a
        }

        static func plates(_ drawn: PlateArray) -> Setup {
            Setup(drawn: drawn, truth: { drawn.asBuilt(build, seed: $0) },
                  copy: { cal, seed, turn in turned(seed == 0 ? cal : cal.asBuilt(unseen, seed: seed), turn) },
                  full: fullVelocity, calibration: calibrationVelocity, pulse: (pulseSteps, fullVelocity), buildText: build.text)
        }

        /// A body file: the real body is one draw of the file's uncertainty.
        /// A copy is another draw, each input rescaled so that at the
        /// microphone's first point it does what calibration measured: what
        /// stays unseen is the shape of each input's pattern, not its size.
        static func body(_ b: BodyResponse) -> Setup {
            let full = b.inputs.map(\.maxDrive).min() ?? 1
            let drawn = b.array(), f = b.frequencies[0]
            let raw = drawn.reference(frequency: f, medium: air).gateRow(at: drawn.centre + probeOffsets(drawn)[0])
            let nominal = drawn.channelRow(raw, frequency: f)
            return Setup(drawn: drawn, truth: { b.array(seed: $0) },
                         copy: { cal, seed, turn in
                             var a = seed == 0 ? cal : b.array(seed: seed)
                             if seed != 0 {
                                 let here = a.channelRow(raw, frequency: f), measured = cal.inputs?.error ?? [Complex](repeating: .one, count: nominal.count)
                                 a.inputs!.error = nominal.indices.map { i in
                                     here[i].magnitudeSquared > 0 ? measured[i] * nominal[i] * here[i].conjugate * (1 / here[i].magnitudeSquared) : measured[i]
                                 }
                             }
                             return turned(a, turn)
                         },
                         full: full, calibration: 0.05 * full, pulse: nil,
                         buildText: String(format: "body %@ (%@): every response entry ±%.0f %%, ±%.0f°", b.name, b.provenance.status, 100 * b.uncertainty.gain, b.uncertainty.phaseDegrees))
        }
    }

    /// Where the microphone goes, from the centre: one point for plates; for a
    /// body two, so that an input silent on the axis is still heard.
    static func probeOffsets(_ a: PlateArray) -> [Vec3] { a.inputs == nil ? [Vec3(0, 0, 0)] : [Vec3(4e-3, 3e-3, 0), Vec3(0, 0, 0)] }

    /// The planner's policy, frozen as "P0-planner/2" (2026-11-12). It sees
    /// the drawing, the calibration record and these constants — never the
    /// emulated build's own errors. It tries drive levels in this order, then
    /// step times, and takes the first job that (a) asks no channel for more
    /// than `ceiling` of full drive, (b) carries the bead on the calibrated
    /// model with its travel within `modelBar`, and (c) still carries it
    /// within `copyBar` on two copies of that model moved by what the
    /// calibration cannot see: every element ±0.2 mm, and the upper plate
    /// turned against the lower. The turn is ±15° without a reference; with
    /// one, twice the spread its pairs reported but at least ±5° — and ±15°
    /// again if that spread is over 7.5°, a reference that cannot be
    /// trusted. No job passing all three: it plays nothing.
    /// (/1 trusted any reference to ±5°: a can tilted 3° on the side pass
    /// then lost the bead in 3 of 3, receipts `p0-mx-ref-f-tilt3`.)
    enum Planner {
        static let name = "P0-planner/2"
        static let levels = [4.0, 6, 8], steps = [0.04, 0.08]
        static let modelBar = 0.25e-3, copyBar = 0.5e-3
        /// `spread`: the reference pairs' disagreement (degrees); nil with no
        /// reference pass; 0 for a point microphone.
        static func turn(spread: Double?) -> Double {
            guard let s = spread, s <= 7.5 else { return 15 }
            return max(5, 2 * s)
        }
    }

    static func choose(_ ctx: MetalContext, _ plan: Plan, calibrated: PlateArray, setup: Setup, machine m: MachineDescription, spread: Double? = nil)
        throws -> (job: FCodeFile, hardest: Double, level: Double, step: Double, predicted: Double)? {
        let turn = Planner.turn(spread: spread)
        for level in Planner.levels { for step in Planner.steps {
            let c = plan.stream(m, level: level, step: step)
            guard c.hardest < ceiling * setup.full else { continue }
            var worst = 0.0
            for (seed, turn) in [(UInt64(0), 0.0), (101, turn), (102, -turn)] {
                var m2 = EmulatedBackend(array: setup.copy(calibrated, seed, turn), band: m.band)
                m2.pulse = setup.pulse
                let r = try ride(ctx, c.job, path: plan.path, step: step, on: m2)
                if ProcessInfo.processInfo.environment["FIELDC_VERBOSE"] != nil {
                    print(String(format: "  plan %.0f× %.0f ms, hardest %.2f, copy %d (%+.0f°): %@", level, step * 1000, c.hardest / setup.full, Int(seed), turn,
                                 r.map { String(format: "travel error %.2f mm, absolute %.2f, lag %.2f", $0.end * 1000, $0.absolute * 1000, $0.worst * 1000) } ?? "left the trap"))
                }
                guard let r, r.end < (seed == 0 ? Planner.modelBar : Planner.copyBar) else { worst = .infinity; break }
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
            field.potential([fr.tones[0].drive.prefix(machine.array.driveChannels).map(machine.pulsed)], particle: rig.particle)
        }
        let r = PlaceCommand.ride(Us: Us, lattice: fb, path: path, power: 1, stepTime: step, particle: rig.particle,
                                  settling: max(rig.settling, machine.array.inputs?.settling ?? 0))
        return r.escaped ? nil : (((r.end - r.start) - (path.last! - path[0])).length, r.worst, (r.end - path.last!).length)
    }

    /// Calibrate, compile, play: on the emulated build, or on the bench with
    /// --port. The same calls either way; on the bench the camera judges.
    static func job(_ args: [String], _ t0: Date) throws -> Int32 {
        let ctx = try MetalContext()
        // --body file.json: a body-response file stands in for the plates.
        let setup: Setup
        if let path = MachineCommand.arg(args, "--body") {
            guard let data = FileManager.default.contents(atPath: path) else { print("cannot read \(path)"); return 2 }
            let b = try BodyResponse.read(data)
            print("body \(b.name) [\(b.provenance.status)]: \(b.inputs.count) inputs (\(b.driveUnit)), \(b.patches.count) patches, \(b.frequencies.count) frequency; \(b.provenance.note)")
            setup = .body(b)
        } else { setup = .plates(plateArray(["--array", "p0"] + args)) }
        let drawn = setup.drawn, n = drawn.driveChannels
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
            let cal = try Calibration.run(&hw, array: drawn, medium: air, probe: drawn.centre, probeGate: n, velocity: setup.calibration, date: date, reference: true) { pass, _ in
                print(["fit the probe bar on its spacers, receiver facing DOWN, then press return",
                       "turn the bar over, without the spacers, receiver facing UP, then press return",
                       "lay the receiver on its side on the mid-plane, facing +x, then press return"][pass])
                _ = readLine()
            }
            let worstDeg = cal.errors.map { abs(atan2($0.im, $0.re)) * 180 / Double.pi }.max() ?? 0
            print(String(format: "calibrated: gains %.2f–%.2f of their mean, phases within %.0f° of it", cal.errors.map(\.magnitude).min() ?? 0, cal.errors.map(\.magnitude).max() ?? 0, worstDeg))
            print("remove the probe, then press return to play the job"); _ = readLine()
            let calibrated = drawn.calibrated(cal)
            guard let pl = try plan(ctx, on: calibrated), let p = try choose(ctx, pl, calibrated: calibrated, setup: setup, machine: d, spread: cal.plateRatioSpreadDegrees) else { print("no job the model carries"); return 1 }
            try save(cal, p.job)
            _ = try hw.play(p.job)
            print(String(format: "played: %d frames at %.0f× holding, %.0f ms per step, hardest element at %.2f of full drive; the model predicts the bead %.2f mm from the drop-off. The camera record judges it (P0 acceptance protocol).",
                         p.job.frames.count, p.level, p.step * 1000, p.hardest / setup.full, p.predicted * 1000))
            return 0
        }
        let o = Options(args)
        guard let r = try simulate(ctx, setup, seed: MachineCommand.arg(args, "--seed").flatMap(UInt64.init) ?? 7, o, save: save) else { return 1 }
        guard let level = r.level else { print("no job the model carries (\(Planner.name)); calibration left the plates \(String(format: "%+.1f", r.betweenPlatesError))° apart"); return 1 }
        func text(_ t: Double?, _ a: Double?) -> String {
            t.map { String(format: "travel off by %.2f mm; %.2f mm from the drawing's drop-off", $0 * 1000, (a ?? .nan) * 1000) } ?? "the bead left the trap"
        }
        let gates = [
            GateResult(id: "G-P0a", name: "hold, 5 mm up, 5 mm across, hold: a \(PlaceCommand.bead(drawn).name) bead on the emulated build, job compiled on its calibration (its travel vs the travel asked, mm)",
                       measured: r.travel.map { $0 * 1000 } ?? .infinity, threshold: 0.5,
                       detail: "\(drawn.tag), build: \(setup.buildText); \(o.text); \(String(format: "%.0f× holding, %.0f ms per 0.25 mm (%@; worst predicted travel error %.2f mm)", level, (r.step ?? 0) * 1000, Planner.name, (r.predicted ?? .nan) * 1000)); 16-bit wire, pulse widths of \(pulseSteps) steps; \(text(r.travel, r.absolute))"),
            GateResult(id: "G-P0b", name: "the job's hardest-driven channel ÷ its full drive", measured: (r.hardest ?? .infinity) / setup.full, threshold: ceiling,
                       detail: String(format: "%.2f of %.2f%@; the bar is a −3 dB unit", r.hardest ?? .nan, setup.full, drawn.inputs == nil ? " m/s (the datasheet level at a 0–15 V square wave)" : " (the body file's input limit)")),
            GateResult(id: "P0-ABS", name: "where the bead ends against the drawing's drop-off point (mm): placement, not travel", measured: r.absolute.map { $0 * 1000 } ?? .infinity,
                       threshold: 0.5, comparison: .informational,
                       detail: String(format: "calibration left the plates %+.1f° apart (about %.2f mm of height); the probe sat %.2f mm off the mid-plane", r.betweenPlatesError, abs(r.betweenPlatesError) / 360 * 4.29, o.probeOff * 1000)),
            GateResult(id: "P0-RAW", name: "control: the same job compiled on the drawing, uncalibrated, on the same build (travel error, mm)",
                       measured: r.rawTravel.map { $0 * 1000 } ?? .infinity, threshold: 0.5, comparison: .informational, detail: text(r.rawTravel, nil)),
        ]
        for g in gates { print(g.line) }
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "p0-job-\(drawn.tag)", gates: gates, durationSeconds: Date().timeIntervalSince(t0), device: deviceName(), gitSHA: gitSHA()))
        }
        return gates.filter { $0.comparison != .informational }.allSatisfy(\.passed) ? 0 : 1
    }

    /// How the emulated bench differs from the ideal: what listens, and what
    /// goes wrong while it does.
    struct Options {
        var probe = Calibration.Probe.can(radius: 5e-3)
        var reference = false
        /// Receiver noise during calibration, dB below each record; nil = none.
        var noise: Double? = nil
        /// Air warming over the calibration passes, K in all.
        var drift = 0.0
        /// The probe's true height above the mid-plane (m) and its tilt on the side pass (degrees).
        var probeOff = 0.0, tilt = 0.0
        init(_ args: [String]) {
            if MachineCommand.arg(args, "--probe") == "point" { probe = .point }
            reference = args.contains("--reference")
            noise = MachineCommand.arg(args, "--noise").flatMap(Double.init)
            drift = MachineCommand.arg(args, "--drift").flatMap(Double.init) ?? 0
            probeOff = (MachineCommand.arg(args, "--probe-off").flatMap(Double.init) ?? 0) * 1e-3
            tilt = MachineCommand.arg(args, "--tilt").flatMap(Double.init) ?? 0
        }
        var text: String {
            (probe == .point ? "point microphone, one pass" : "receiver can, one pass per plate" + (reference ? " and a side reference pass" : ""))
                + (noise.map { String(format: ", noise %.0f dB down", $0) } ?? "") + (drift != 0 ? String(format: ", air %.1f K warmer by the last pass", drift) : "")
                + (probeOff != 0 ? String(format: ", probe %.2f mm high", probeOff * 1000) : "") + (tilt != 0 ? String(format: ", tilted %.0f°", tilt) : "")
        }
    }

    struct Outcome {
        var level: Double?, step: Double?, hardest: Double?, predicted: Double?
        var travel: Double?, absolute: Double?, rawTravel: Double?
        /// Calibrated minus true phase of the upper plate against the lower, degrees.
        var betweenPlatesError = 0.0
        var spread: Double?
    }

    /// One emulated bench session: build → calibrate → plan → play → the bead.
    /// The plan sees `drawn` and the calibration record; the build's own
    /// errors are used only to radiate and to score.
    static func simulate(_ ctx: MetalContext, _ setup: Setup, seed: UInt64, _ o: Options,
                         save: (Calibration.Record, FCodeFile) throws -> Void = { _, _ in }) throws -> Outcome? {
        let drawn = setup.drawn, n = drawn.driveChannels
        let f0: Double = drawn.tones?.first ?? drawn.inputs?.frequencies.first ?? 40_000
        var emu = EmulatedBackend(array: setup.truth(seed), name: "\(drawn.tag) (emulated build \(seed))", band: [f0 - 1000, f0 + 1000])
        let offs = probeOffsets(drawn)
        emu.probes = offs.map { drawn.centre + $0 + Vec3(0, 0, o.probeOff) }
        emu.pulse = setup.pulse
        emu.snrDB = o.noise
        let passes = o.probe == .point ? 1.0 : (o.reference ? 3.0 : 2.0), c0 = emu.medium.soundSpeed
        let cal = try Calibration.run(&emu, array: drawn, medium: air, probe: drawn.centre + offs[0], probeGate: n, velocity: setup.calibration,
                                      date: ISO8601DateFormatter().string(from: Date()), kind: o.probe, reference: o.reference,
                                      extra: offs.dropFirst().map { drawn.centre + $0 }) { pass, b in
            let t = o.tilt * Double.pi / 180
            b.probeFacing = o.probe == .point ? [] : [Vec3](repeating: [Vec3(0, 0, -1), Vec3(0, 0, 1), Vec3(cos(t), 0, sin(t))][pass], count: offs.count)
            b.medium.soundSpeed = c0 * (1 + 0.00171 * o.drift * Double(pass) / max(1, passes - 1))   // 0.17 % per kelvin
        }
        emu.snrDB = nil; emu.medium.soundSpeed = c0
        // Held-out truth, for scoring only: what each channel does at the drawing's centre.
        var builtRow: [Complex] = emu.array.reference(frequency: f0, medium: air).gateRow(at: drawn.centre)
        if let g = emu.array.gains([f0], curve: true)?[0] { for e in builtRow.indices { builtRow[e] = builtRow[e] * g[e] } }
        let rowB: [Complex] = emu.array.channelRow(builtRow, frequency: f0)
        let rowD: [Complex] = drawn.channelRow(drawn.reference(frequency: f0, medium: air).gateRow(at: drawn.centre), frequency: f0)
        var up = Complex.zero, lo = Complex.zero
        let loudest = rowD.map(\.magnitude).max() ?? 0
        for c in 0..<n where rowD[c].magnitude > 0.1 * loudest {       // a channel silent at the centre says nothing here
            let truth: Complex = rowB[c] * rowD[c].conjugate * (1 / rowD[c].magnitudeSquared)
            let q: Complex = cal.errors[c] * truth.conjugate
            if drawn.plate(of: c) == 0 { lo += q } else { up += q }
        }
        var out = Outcome()
        out.betweenPlatesError = atan2((up * lo.conjugate).im, (up * lo.conjugate).re) * 180 / Double.pi
        out.spread = cal.plateRatioSpreadDegrees
        let calibrated = drawn.calibrated(cal)
        guard let pl = try plan(ctx, on: calibrated) else { return nil }
        guard let p = try choose(ctx, pl, calibrated: calibrated, setup: setup, machine: emu.describe(),
                                 spread: o.probe == .point ? 0 : cal.plateRatioSpreadDegrees) else { return out }
        try save(cal, p.job)
        _ = try emu.play(p.job)
        let rode = try ride(ctx, p.job, path: pl.path, step: p.step, on: emu)
        out.level = p.level; out.step = p.step; out.hardest = p.hardest; out.predicted = p.predicted
        out.travel = rode?.end; out.absolute = rode?.absolute
        if let rawPlan = try plan(ctx, on: drawn) {
            out.rawTravel = try ride(ctx, rawPlan.stream(emu.describe(), level: p.level, step: p.step).job, path: rawPlan.path, step: p.step, on: emu)?.end
        }
        return out
    }

    /// `fieldc p0 matrix --gaps 45,46,47 --reflects 0,0.5,0.9 --seeds 7-12 [--order n] [--probe point] [--reference] …`
    /// Every case under the frozen planner policy; one CSV row each.
    static func matrix(_ args: [String], _ t0: Date) throws -> Int32 {
        let ctx = try MetalContext()
        func list(_ name: String, _ d: [Double]) -> [Double] { MachineCommand.arg(args, name)?.split(separator: ",").compactMap { Double($0) } ?? d }
        let gaps = list("--gaps", [46]), reflects = list("--reflects", [0, 0.5, 0.9]), orders = list("--orders", [3])
        let sr = MachineCommand.arg(args, "--seeds")?.split(separator: "-").compactMap { UInt64($0) } ?? [7, 12]
        let o = Options(args)
        var csv = "policy,gap_mm,reflection,image_order,seed,calibration,outcome,level,step_ms,hardest_of_full,predicted_travel_mm,travel_mm,absolute_mm,between_plates_deg,pair_spread_deg\n"
        var pass = 0, lost = 0, refused = 0, travels: [Double] = [], absolutes: [Double] = [], between: [Double] = []
        for gap in gaps { for R in reflects { for order in orders { for seed in sr[0]...sr[sr.count - 1] {
            var d = P0Design(); d.gap = gap; d.reflection = R
            var drawn = PlateArray.p0(d); drawn.imageOrder = Int(order)
            guard let r = try simulate(ctx, .plates(drawn), seed: seed, o) else { continue }
            let outcome = r.level == nil ? "refused" : (r.travel.map { $0 < 0.5e-3 ? "pass" : "off" } ?? "lost")
            if outcome == "pass" { pass += 1 } else if outcome == "refused" { refused += 1 } else { lost += 1 }
            if let t = r.travel { travels.append(t * 1000) }
            if let a = r.absolute { absolutes.append(a * 1000) }
            between.append(abs(r.betweenPlatesError))
            func f(_ v: Double?, _ k: Double = 1) -> String { v.map { String(format: "%.3f", $0 * k) } ?? "" }
            let line = "\(Planner.name),\(gap),\(R),\(Int(order)),\(seed),\"\(o.text)\",\(outcome),\(f(r.level)),\(f(r.step, 1000)),\(f(r.hardest.map { $0 / fullVelocity })),\(f(r.predicted, 1000)),\(f(r.travel, 1000)),\(f(r.absolute, 1000)),\(f(r.betweenPlatesError)),\(f(r.spread))"
            csv += line + "\n"
            print(line); fflush(stdout)
        } } } }
        let total = pass + lost + refused
        func range(_ v: [Double]) -> String { v.isEmpty ? "—" : String(format: "%.2f–%.2f (median %.2f)", v.min()!, v.max()!, v.sorted()[v.count / 2]) }
        let summary = "\(pass) of \(total) pass, \(refused) refused by the planner, \(lost) played and failed; travel error \(range(travels)) mm; absolute \(range(absolutes)) mm; plates left \(range(between))° apart"
        print(summary)
        let tag = MachineCommand.arg(args, "--tag") ?? "matrix"
        if args.contains("--receipt") {
            try? csv.write(toFile: "Receipts/p0_\(tag).csv", atomically: true, encoding: .utf8)
            let gates = [
                GateResult(id: "P0-MX", name: "P0 job matrix (\(Planner.name); \(o.text)): cases that pass ÷ cases", measured: Double(pass) / Double(max(1, total)), threshold: 0,
                           comparison: .informational, detail: "gaps \(gaps) mm × reflection \(reflects) × image order \(orders) × builds \(sr[0])–\(sr[sr.count - 1]): " + summary),
                GateResult(id: "P0-MX2", name: "P0 job matrix: jobs played that lost the bead or missed the travel bar ÷ cases", measured: Double(lost) / Double(max(1, total)), threshold: 0,
                           comparison: .informational, detail: "a refusal is the planner declining; this is the planner being wrong"),
            ]
            writeReceipt(Receipt(name: "p0-\(tag)", gates: gates, durationSeconds: Date().timeIntervalSince(t0), device: deviceName(), gitSHA: gitSHA()))
        }
        return 0
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
        struct Rec: Decodable { var id, what, by, gain, status: String; var needs: [String]; var anyOf: [String]?; var tolerance, inspection: String?; var humanMinutes: Double }
        struct File: Decodable { var records: [Rec] }
        guard let data = FileManager.default.contents(atPath: "Design/upgrade_graph.json"), let file = try? JSONDecoder().decode(File.self, from: data) else {
            print("cannot read Design/upgrade_graph.json"); return 2
        }
        let byID = Dictionary(uniqueKeysWithValues: file.records.map { ($0.id, $0) })
        var order: [Rec] = [], done = Set<String>(), left = file.records
        while !left.isEmpty {
            let ready = left.filter { $0.needs.allSatisfy(done.contains) && ($0.anyOf.map { $0.contains(where: done.contains) } ?? true) }
            if ready.isEmpty { break }
            order += ready; done.formUnion(ready.map(\.id)); left.removeAll { done.contains($0.id) }
        }
        let unknown = file.records.flatMap { r in (r.needs + (r.anyOf ?? [])).filter { byID[$0] == nil }.map { "\(r.id) needs \($0)" } }
        let bare = file.records.filter { $0.by != "external" && ($0.tolerance == nil || $0.inspection == nil) }.map(\.id)
        print("| # | id | what | by | needs | status | human min (est.) |\n|---:|---|---|---|---|---|---:|")
        for (i, r) in order.enumerated() {
            print("| \(i + 1) | \(r.id) | \(r.what) | \(r.by) | \(r.needs.joined(separator: ", "))\(r.anyOf.map { " + one of: " + $0.joined(separator: ", ") } ?? "") | \(r.status) | \(Int(r.humanMinutes)) |")
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
