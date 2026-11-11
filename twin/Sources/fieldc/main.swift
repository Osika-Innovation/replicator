import FieldCore
import FieldGPU
import FieldUI
import SwiftUI
import Foundation

// fieldc — the CLI half of the "one core, two front-ends" law (§20 L2).
// Everything the UI can do is reachable here, through the same FieldCore calls.

func git(_ args: [String]) -> String? {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    p.arguments = args
    let pipe = Pipe(); p.standardOutput = pipe; p.standardError = Pipe()
    do { try p.run(); p.waitUntilExit() } catch { return nil }
    let d = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: d, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// HEAD, marked `+dirty` when the working tree differs from it — a receipt
/// that names a commit the numbers were not produced from is a false receipt.
func gitSHA() -> String {
    guard let sha = git(["rev-parse", "--short", "HEAD"]), !sha.isEmpty else { return "unknown" }
    let dirty = !(git(["status", "--porcelain", "--untracked-files=no", "--", "."]) ?? "").isEmpty
    return dirty ? sha + "+dirty" : sha
}

func deviceName() -> String {
    var size = 0
    sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
    guard size > 0 else { return "unknown" }
    var buf = [CChar](repeating: 0, count: size)
    sysctlbyname("machdep.cpu.brand_string", &buf, &size, nil, 0)
    return String(cString: buf)
}

/// The plate array a command runs on. Default: the machine's own plates, the
/// array the CAD's face is drawn round (`PlateArray.rh1`). `--array ideal` or
/// `--per-plate N`: study S1's idealised spiral over the whole Ø410 disc (the
/// Round 12 receipts). `--array microhorn`: the v0.4 face's drilled
/// micro-horns as elements (Round 14's comparison).
func plateArray(_ args: [String], reflection: Double = 0.9) -> PlateArray {
    func arg(_ name: String) -> String? { args.firstIndex(of: name).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
    var a: PlateArray
    if let n = arg("--per-plate").flatMap(Int.init) { a = PlateArray(perPlate: n, reflection: reflection) }
    else {
        switch arg("--array") {
        case "ideal": a = PlateArray(perPlate: 192, reflection: reflection)
        case "microhorn", "cad": a = PlateArray.fromCAD(reflection: reflection)
        default:
            // "disc": the directly radiating broadband Ø5 disc the face carried until 2026-11-12.
            var d = RH1Design()
            if arg("--array") == "disc" { d.elementTones = [] }
            if let n = arg("--elements").flatMap(Int.init) { d.elementCount = n }
            // On the resonant face --band moves the plate's tones (and with them the elements' sizes).
            if d.resonantElements, let b = arg("--band")?.split(separator: "-").compactMap({ Double($0) }), b.count == 2 {
                let T = d.elementTones.count
                let lo: Double = b[0] * 1000, step: Double = (b[1] - b[0]) * 1000 / Double(T)
                d.elementTones = (0..<T).map { q -> Double in lo + step * (Double(q) + 0.5) }
            }
            a = PlateArray.rh1(d, reflection: reflection)
        }
    }
    return a
}

func writeReceipt(_ r: Receipt) {
    let dir = URL(fileURLWithPath: "Receipts")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let stamp = r.date.replacingOccurrences(of: ":", with: "-")
    let url = dir.appendingPathComponent("\(r.name)_\(stamp).json")
    do {
        try r.json().write(to: url)
        print("receipt written: \(url.path)")
    } catch {
        print("RECEIPT NOT WRITTEN (\(url.lastPathComponent)): \(error)")
    }
}

let args = Array(CommandLine.arguments.dropFirst())
let cmd = args.first ?? "help"

switch cmd {

case "test":
    let t0 = Date()
    if args.count > 1, let hg = CoreTests.run(group: args[1]) {
        print(hg.summary)
        print(String(format: "(%.2fs)", Date().timeIntervalSince(t0)))
        exit(hg.allPassed ? 0 : 1)
    }
    let h = CoreTests.runAll()
    print(h.summary)
    print(String(format: "(%.2fs)", Date().timeIntervalSince(t0)))
    exit(h.allPassed ? 0 : 1)

case "gpu":
    // The GPU kernels must match their CPU reference. A GPU kernel with no
    // reference to be tested against is a kernel nobody can trust.
    do {
        let ctx = try MetalContext()
        print("device: \(ctx.deviceDescription)")
        var gates: [GateResult] = []
        // The open-air plate array (ENGINE.md): matrix-free forward and adjoint
        // passes vs the CPU reference — one gate per element of a 2 × 24 array,
        // R = 0.9 plates imaged to order 3, 70 kHz, on a 7³ lattice around the
        // centre. G-A1: U and the fields for a random drive. G-A3: the adjoint
        // (∂/∂g* of a random lattice weighting of U) vs the CPU adjoint built
        // from the reference rows — itself checked against finite differences
        // by the unit suite.
        do {
            let arr = PlateArray(perPlate: 24)
            let f = 70_000.0, air = RH1Freestanding.roomAir
            let h = air.wavelength(at: f) / 8
            let lat = FieldLattice(origin: arr.centre - Vec3(3 * h, 3 * h, 3 * h), spacing: h, nx: 7, ny: 7, nz: 7)
            let gpuField = try ArrayFieldGPU(ctx: ctx, array: arr, frequencies: [f], medium: air, lattice: lat)
            let ref = arr.reference(frequency: f, medium: air)
            var rows = [Complex](repeating: .zero, count: lat.count * arr.channels * 4)
            for (n, x) in lat.positions.enumerated() {
                let r = ref.gateGradientRows(at: x)
                for e in 0..<arr.channels {
                    let b = (n * arr.channels + e) * 4
                    rows[b] = r.p[e]; rows[b + 1] = r.grad[0][e]; rows[b + 2] = r.grad[1][e]; rows[b + 3] = r.grad[2][e]
                }
            }
            let cpuField = ForceCompiler.StoredRows(tones: [ForceCompiler.Tone(frequency: f, medium: air, rows: rows)],
                                                    lattice: lat, channels: arr.channels)
            var rng = SplitMix64(seed: 5)
            let drive = [(0..<arr.channels).map { _ in Complex(rng.nextUnit() - 0.5, rng.nextUnit() - 0.5) }]
            let grain = ParticleMaterial(density: 1240, soundSpeed: 2220, radius: 20e-6)
            let t0 = Date()
            let UG = gpuField.potential(drive, particle: grain)
            let UC = cpuField.potential(drive, particle: grain)
            let weights = (0..<lat.count).map { _ in rng.nextUnit() < 0.3 ? rng.nextUnit() - 0.5 : 0 }
            let AG = gpuField.adjoint(drive, weights: weights, particle: grain)[0]
            let AC = cpuField.adjoint(drive, weights: weights, particle: grain)[0]
            let tA = Date().timeIntervalSince(t0)
            func rel(_ a: [Double], _ b: [Double]) -> Double {
                (zip(a, b).reduce(0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) } / max(b.reduce(0) { $0 + $1 * $1 }, 1e-300)).squareRoot()
            }
            let g1 = GateResult(id: "G-A1", name: "open-air plate array, matrix-free GPU potential vs CPU reference (2 × 24 elements, R 0.9, 70 kHz)",
                                measured: rel(UG, UC), threshold: 1e-4,
                                detail: String(format: "%d lattice points, %d channels, images to order %d; GPU forward + adjoint %.3fs",
                                               lat.count, arr.channels, arr.imageOrder, tA))
            let g3 = GateResult(id: "G-A3", name: "open-air plate array, matrix-free GPU adjoint vs CPU adjoint from reference rows",
                                measured: AG.relativeL2(to: AC), threshold: 1e-4,
                                detail: String(format: "%d weighted points of %d", weights.filter { $0 != 0 }.count, lat.count))
            print(g1.line); print(g3.line)
            gates += [g1, g3]
        }
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "gpu", gates: gates, durationSeconds: 0,
                                 device: deviceName(), gitSHA: gitSHA()))
        }
        exit(gates.allSatisfy(\.passed) ? 0 : 1)
    } catch { print("GPU unavailable: \(error)"); exit(2) }

case "mold":
    // The single-shot acoustic mold (MoldCore.swift): one chord drive, and a
    // cloud of powder released at random through the volume that ends on the
    // shape. Default: open air between two plates of 192 elements each
    // (ENGINE.md).
    // Default objective: the sieve; `--objective wells|funnel` keep the runs
    // that showed why (the λ/4 reach of a still field).
    do {
        let ctx = try MetalContext()
        let t0 = Date()
        func arg(_ name: String) -> String? { args.firstIndex(of: name).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
        var shape = arg("--shape") ?? "ring"
        var setup = MoldSetup()
        if let v = arg("--objective") { setup.objective = v }
        if let v = arg("--tones").flatMap(Int.init) { setup.tones = v }
        if let v = arg("--band") {
            let parts = v.split(separator: "-").compactMap { Double($0) }
            if parts.count == 2 { setup.band = (parts[0] * 1000, parts[1] * 1000) }
        }
        if let v = arg("--grains").flatMap(Int.init) { setup.grains = v }
        if let v = arg("--iterations").flatMap(Int.init) { setup.iterations = v }
        if let v = arg("--seconds").flatMap(Double.init) { setup.seconds = v }
        if let v = arg("--power-x").flatMap(Double.init) { setup.powerX = v }
        if args.contains("--recirculate") { setup.recirculate = true }
        if args.contains("--no-recirculate") { setup.recirculate = false }
        setup.gravity = !args.contains("--no-gravity")
        setup.particles = !args.contains("--no-particles")
        setup.debug = args.contains("--debug")
        if let v = arg("--feedback").flatMap(Int.init) { setup.feedback = v }
        let reflection = arg("--reflection").flatMap(Double.init) ?? 0.9
        let moldArray = plateArray(args, reflection: reflection)
        let chamber: MoldChamber = .plates(moldArray)
        let L = moldArray.gap
        let centre = Vec3(0, 0, L / 2)
        var (sites, segments) = moldShape(shape, centre: centre, ringSites: arg("--sites").flatMap(Int.init) ?? 16)
        if let path = arg("--stl") {
            // The shape read from an STL (millimetres), as the app reads it:
            // placed at the centre, sites spread evenly over its surface.
            let raw = try STL.read(contentsOf: URL(fileURLWithPath: path))
            let placed = meshInMold(Mesh(triangles: raw.triangles.map { Triangle($0.a * 0.001, $0.b * 0.001, $0.c * 0.001) }), centre: centre)
            sites = meshPoints(placed.mesh, count: arg("--sites").flatMap(Int.init) ?? 16, minSpacing: 2.5e-3)
            segments = meshSegments(joining: sites)
            shape = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent + "-stl"
            let nn = sites.indices.map { i in sites.indices.filter { $0 != i }.map { (sites[$0] - sites[i]).length }.min() ?? 0 }
            print(String(format: "shape from %@: scale %.2f, %d sites, nearest-neighbour spacing %.2f–%.2f mm, %d segments",
                         path, placed.scale, sites.count, (nn.min() ?? 0) * 1000, (nn.max() ?? 0) * 1000, segments.count))
        }
        if let deg = arg("--rotate").flatMap(Double.init) {
            // Turn the shape about the vertical axis through the centre (a robustness check).
            let c = cos(deg * .pi / 180), sn = sin(deg * .pi / 180)
            func turn(_ p: Vec3) -> Vec3 {
                let d = p - centre
                return centre + Vec3(c * d.x - sn * d.y, sn * d.x + c * d.y, d.z)
            }
            sites = sites.map(turn); segments = segments.map { (turn($0.0), turn($0.1)) }
        }
        let ringSites = arg("--sites").flatMap(Int.init) ?? 16
        let rotation = arg("--rotate").flatMap(Double.init)
        let label = shape + (shape == "ring" && ringSites != 16 ? "\(ringSites)" : "")
            + (rotation.map { String(format: "-rot%g", $0) } ?? "")
        let out = try runMold(ctx: ctx, label: label, sites: sites, segments: segments, chamber: chamber, setup: setup)
        for g in out.gates { print(g.line) }
        print(String(format: "(%.1fs)", Date().timeIntervalSince(t0)))
        let tag = "-\(moldArray.tag)"
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "mold-\(label)-\(setup.objective)\(tag)", gates: out.gates,
                                 durationSeconds: Date().timeIntervalSince(t0), device: deviceName(), gitSHA: gitSHA()))
        }
        let base = "Receipts/mold_" + "\(moldArray.tag)_" + label + (setup.objective == "sieve" ? "" : "_\(setup.objective)")
        if args.contains("--light") {
            // What a 633 nm laser along x reads of the compiled field (LightRead.swift).
            let arr = moldArray
            let lf = try ArrayFieldGPU(ctx: ctx, array: arr, frequencies: out.frequencies, medium: RH1Freestanding.roomAir,
                                       lattice: FieldLattice(origin: centre, spacing: 1e-3, nx: 1, ny: 1, nz: 1))
            let view = try lightView(field: lf, drives: out.drives, power: out.power, centre: centre,
                                     halfWidth: 14e-3, spacing: 0.25e-3, pathHalfLength: 0.15)
            var lcsv = String(format: "# n=%d spacing_mm=%.4f half_mm=%.3f\nj,k,rad\n", view.n, view.spacing * 1000, view.halfWidth * 1000)
            for k in 0..<view.n { for j in 0..<view.n { lcsv += String(format: "%d,%d,%.6e\n", j, k, view.amplitude[k * view.n + j]) } }
            try? lcsv.write(toFile: base + "_light.csv", atomically: true, encoding: .utf8)
            print(String(format: "light: a 633 nm laser along x through the chamber picks up up to %.1f mrad (rms over tones) — measurable", view.peak * 1000))
        }
        if setup.particles {
            try? out.grainsCSV.write(toFile: base + "_grains.csv", atomically: true, encoding: .utf8)
            try? out.captureCSV.write(toFile: base + "_capture.csv", atomically: true, encoding: .utf8)
        }
        try? out.sitesCSV.write(toFile: base + "_targets.csv", atomically: true, encoding: .utf8)
        try? out.sinksCSV.write(toFile: base + "_sinks.csv", atomically: true, encoding: .utf8)
        if let path = arg("--fcode") {
            // The compiled mold as a stream a machine plays: one ADD frame,
            // held for the simulated time, at the drive power the run used.
            let b = EmulatedBackend(array: moldArray, band: [setup.band?.lo ?? 30_000, setup.band?.hi ?? 70_000])
            let scale = out.power.squareRoot()
            var f = FCodeFile(machine: b.name, calibrationRef: b.calibrationRef, band: b.band, channels: moldArray.channels)
            f.frames = [FCodeFile.Frame(t: 0, duration: setup.seconds, verb: .add,
                                        tones: zip(out.frequencies, out.drives).map { fq, d in FCodeFile.Tone(frequency: fq, drive: d.map { $0 * scale }) })]
            do { try f.json().write(to: URL(fileURLWithPath: path)); print("fcode written: \(path) (\(f.frames[0].tones.count) tones × \(f.channels) channels)") }
            catch { print("FCODE NOT WRITTEN: \(error)") }
        }
    } catch { print("GPU unavailable: \(error)"); exit(2) }

case "tolerance":
    // Study S5 (ToleranceCore.swift): the ring mold played on random builds of the plates.
    do {
        let t0 = Date()
        let arr = plateArray(args)
        let gates = try runTolerance(ctx: try MetalContext(), array: arr)
        print(String(format: "(%.1fs)", Date().timeIntervalSince(t0)))
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "tolerance-\(arr.tag)", gates: gates, durationSeconds: Date().timeIntervalSince(t0), device: deviceName(), gitSHA: gitSHA()))
        }
        exit(0)
    } catch { print("GPU unavailable: \(error)"); exit(2) }

case "arraysweep":
    // Study S1 (ENGINE.md): how many independently driven elements a plate is
    // worth. The RH-1 plate pair in open air (`PlateArray.rh1`: elements on
    // the face's Vogel annulus), N = 3 … 768 per plate; 1, 3 and 9 tones
    // over the mold band, 50–100 kHz (`--band lo-hi` in kHz). For each:
    // a single trap at the centre (the mold compiler with one site: rival
    // well ÷ target well, < 0.5 = unique), and the 16-site ring sieve (lift
    // contrast; where a random powder cloud ends, by the traced flow; the drive
    // per channel and the acoustic power it radiates).
    do {
        let ctx = try MetalContext()
        let t0 = Date()
        func arg(_ name: String) -> String? { args.firstIndex(of: name).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
        let counts = arg("--counts")?.split(separator: ",").compactMap { Int($0) } ?? [3, 12, 48, 192, 768]
        let toneSets = arg("--tones")?.split(separator: ",").compactMap { Int($0) } ?? [1, 3, 9]
        let reflection = arg("--reflection").flatMap(Double.init) ?? 0.9
        var band: (lo: Double, hi: Double)? = (50_000, 100_000)
        if let v = arg("--band") {
            let parts = v.split(separator: "-").compactMap { Double($0) }
            if parts.count == 2 { band = (parts[0] * 1000, parts[1] * 1000) }
        }
        let air = RH1Freestanding.roomAir
        var gates: [GateResult] = []
        var csv = "per_plate,tones,trap_ratio,sieve_contrast,on_shape,site_min,site_max,rogue,drive_rms,acoustic_W,compile_s\n"
        print(String(format: "open air: the RH-1 plate pair, R %.1f, Ø5 mm elements on the face's Vogel annulus; band %.0f–%.0f kHz",
                     reflection, (band?.lo ?? 50_000) / 1000, (band?.hi ?? 100_000) / 1000))
        print("per plate  tones  trap ratio  ring sieve: contrast  on shape  sites (fair 6.3%)  rogue   drive (m/s rms)  acoustic W   compile")
        for N in counts {
            for T in toneSets {
                // S1 is a study of ideal broadband pistons: the Ø5 disc face.
                var design = RH1Design(); design.elementCount = N; design.elementTones = []
                let arr = PlateArray.rh1(design, reflection: reflection)
                let centre = arr.centre
                var trap = MoldSetup()
                trap.objective = "wells"; trap.tones = T; trap.particles = false; trap.iterations = 300; trap.band = band
                let tOut = try runMold(ctx: ctx, label: "centre trap", sites: [centre], segments: [(centre, centre)],
                                       chamber: .plates(arr), setup: trap, log: { _ in })
                var sv = MoldSetup()
                sv.tones = T; sv.particles = false; sv.band = band; sv.feedback = 0
                let (sites, segs) = moldShape("ring", centre: centre)
                let r = try runMold(ctx: ctx, label: "ring", sites: sites, segments: segs, chamber: .plates(arr), setup: sv, log: { _ in })
                let S = Double.pi * arr.elementRadius * arr.elementRadius
                let acoustic = 0.5 * air.density * air.soundSpeed * S * Double(arr.channels * T) * r.driveRMS * r.driveRMS
                print(String(format: "  %5d     %d      %6.2f        %6.2f            %5.1f%%    %4.1f–%4.1f%%     %5.1f%%   %8.3f      %8.3f    %5.1fs",
                             N, T, min(tOut.rivalRatio, 99), r.contrast, 100 * r.basinOnShape,
                             100 * (r.basinPerSite.min() ?? 0), 100 * (r.basinPerSite.max() ?? 0), 100 * r.basinRogue,
                             r.driveRMS, acoustic, tOut.compileSeconds + r.compileSeconds))
                csv += String(format: "%d,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.5f,%.5f,%.2f\n", N, T, tOut.rivalRatio, r.contrast,
                              r.basinOnShape, r.basinPerSite.min() ?? 0, r.basinPerSite.max() ?? 0, r.basinRogue, r.driveRMS, acoustic,
                              tOut.compileSeconds + r.compileSeconds)
                gates.append(GateResult(id: "S1-\(N)x\(T)", name: "2 × \(N) elements, \(T) tone\(T == 1 ? "" : "s"): centre trap ratio; ring sieve",
                                        measured: tOut.rivalRatio, threshold: 0, comparison: .informational,
                                        detail: String(format: "trap ratio %.2f; ring sieve contrast %.2f, %.1f%% on the shape (sites %.1f–%.1f%%, rogue %.1f%%), %.3f m/s rms per channel, %.3f W acoustic",
                                                       tOut.rivalRatio, r.contrast, 100 * r.basinOnShape, 100 * (r.basinPerSite.min() ?? 0),
                                                       100 * (r.basinPerSite.max() ?? 0), 100 * r.basinRogue, r.driveRMS, acoustic)))
            }
        }
        print(String(format: "(%.1fs)", Date().timeIntervalSince(t0)))
        try? csv.write(toFile: "Receipts/arraysweep.csv", atomically: true, encoding: .utf8)
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "arraysweep", gates: gates, durationSeconds: Date().timeIntervalSince(t0),
                                 device: deviceName(), gitSHA: gitSHA()))
        }
    } catch { print("GPU unavailable: \(error)"); exit(2) }

case "scan3d":
    // Scan a 3D object (ScanCore.swift). Default: open air, the plate array
    // (2 × 192 elements) lighting the object with random chords over
    // 30–100 kHz, the echo sent back time-reversed — the matched filter.
    // Objects are clouds of small rigid scatterers (Born).
    do {
        let ctx = try MetalContext()
        let t0 = Date()
        func arg(_ name: String) -> String? { args.firstIndex(of: name).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
        let scanArray = plateArray(args)
        let perPlate = scanArray.perPlate
        let L = scanArray.gap
        let centre = Vec3(0, 0, L / 2)
        let objectName = arg("--object") ?? "tetra"
        var fHi = 100_000.0, nF = 320
        if let v = arg("--fmax").flatMap(Double.init) { fHi = v * 1000 }
        if let v = arg("--nf").flatMap(Int.init) { nF = v }
        let snrDB = arg("--snr").flatMap(Double.init) ?? 40.0
        let chords = arg("--chords").flatMap(Int.init) ?? 8
        let (object, subunit, half, h) = scanObject(objectName, centre: centre)
        let n = Int((2 * half / h).rounded()) + 1
        let grid = FieldLattice(origin: centre - Vec3(half, half, half), spacing: h, nx: n, ny: n, nz: n)
        let I: [Double]
        var setup = ArrayScanSetup()
        setup.fHi = fHi; setup.frequencies = nF; setup.chords = chords; setup.snrDB = snrDB
        let sweep = setup.sweep(on: scanArray)
        print(String(format: "scan of %@: %d scatterers (radius %.2f mm), open air, 2 × %d elements, %d frequencies %.0f–%.0f kHz × %d random chords, SNR %.0f dB; grid ±%.0f mm at %.2f mm (%d³)",
                     objectName, object.count, subunit * 1000, perPlate, sweep.count, sweep.lo / 1000, sweep.hi / 1000, chords, snrDB, half * 1000, h * 1000, n))

        setup.gate = !args.contains("--no-gate")
        setup.listenBoth = args.contains("--listen-both")
        I = try scanImageArray(ctx: ctx, array: scanArray, object: object, subunit: subunit,
                               grid: grid, setup: setup)
        // How the image sits on the object (`scanScore`). Precision hangs on
        // one number (half the PEAK voxel), so one bright scatterer moves it by
        // tens of percent (2026-11-10: 62–91 % as the array's fill radius
        // changes, the image itself hardly changing); AUC and contrast do not.
        let tol = max(2e-3, 1.5 * h)
        let sc = scanScore(image: I, grid: grid, object: object, tol: tol)
        let precision = sc.precision, recall = sc.recall, auc = sc.auc, imageContrast = sc.contrast
        let spill = sc.spill, spillReach = sc.spillReach
        print(String(format: "image: %d voxels above half the peak; %.0f%% of them within %.1f mm of the object; %.0f%% of the object has such a voxel within %.1f mm",
                     sc.hot, 100 * precision, tol * 1000, 100 * recall, tol * 1000))
        print(String(format: "image peak %.2f mm from the nearest object point", sc.peakDistance * 1000))
        print(String(format: "threshold-free: AUC %.3f (object voxel brighter than background voxel); contrast %.1f×; %.0f%% of the image energy lies beyond %.1f mm of the object, on average %.1f mm further out (object fills %.1f%% of the grid)",
                     auc, imageContrast, 100 * spill, tol * 1000, spillReach * 1000, 100 * sc.objectShare))
        var ocsv = "x_mm,y_mm,z_mm\n"
        for o in object { ocsv += String(format: "%.3f,%.3f,%.3f\n", (o.x - grid.origin.x) * 1000, (o.y - grid.origin.y) * 1000, (o.z - grid.origin.z) * 1000) }
        let tag = "-\(scanArray.tag)"
        let gate = GateResult(id: "SCAN", name: "scan of \(objectName) in open air: image overlap with the object",
                              measured: precision, threshold: 0, comparison: .informational,
                              detail: String(format: "%d scatterers, %d frequencies %.0f–%.0f kHz%@, SNR %.0f dB; precision %.0f%%, recall %.0f%% (within %.1f mm); AUC %.3f, contrast %.1f×",
                                             object.count, sweep.count, sweep.lo / 1000, sweep.hi / 1000, " × \(chords) chords, 2 × \(perPlate) elements",
                                             snrDB, 100 * precision, 100 * recall, tol * 1000, auc, imageContrast))
        let aucGate = GateResult(id: "SCAN-AUC", name: "scan of \(objectName): object voxels outrank background voxels (threshold-free)",
                                 measured: auc, threshold: 0, comparison: .informational,
                                 detail: String(format: "AUC %.3f; mean image on the object %.1f× the background; %.0f%% of the image energy beyond %.1f mm, mean reach %.1f mm",
                                                auc, imageContrast, 100 * spill, tol * 1000, spillReach * 1000))
        print(String(format: "(%.1fs)", Date().timeIntervalSince(t0)))
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "scan3d-" + objectName + tag, gates: [gate, aucGate], durationSeconds: Date().timeIntervalSince(t0),
                                 device: deviceName(), gitSHA: gitSHA()))
        }
        let base = "Receipts/scan3d_" + "\(scanArray.tag)_" + objectName
        try? mipCSV(I, grid: grid).write(toFile: base + "_mip.csv", atomically: true, encoding: .utf8)
        try? ocsv.write(toFile: base + "_object.csv", atomically: true, encoding: .utf8)
        try? String(format: "%.4f,%d\n", h * 1000, n).write(toFile: base + "_grid.csv", atomically: true, encoding: .utf8)
    } catch { print("GPU unavailable: \(error)"); exit(2) }

case "replicate":
    // The replicator's loop, in the twin, in open air: scan an object with the
    // plate array, read its shape off the image (sites at the bright peaks,
    // joined where the image stays bright between them), mold a copy from
    // powder with the sieve (the design point of study S1), scan the copy, and
    // compare — the copy against the ORIGINAL object, and the copy's scan
    // against the original's.
    do {
        let ctx = try MetalContext()
        let t0 = Date()
        func arg(_ name: String) -> String? { args.firstIndex(of: name).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
        let objectName = arg("--object") ?? "ring"
        let arr = plateArray(args)
        let perPlate = arr.perPlate
        let centre = arr.centre
        var scan = ArrayScanSetup()
        if let v = arg("--nf").flatMap(Int.init) { scan.frequencies = v }
        if let v = arg("--chords").flatMap(Int.init) { scan.chords = v }
        // --- the original: a wire object, as a cloud of 0.3 mm scatterers every 1 mm ---
        var originalSegments: [(Vec3, Vec3)] = []
        switch objectName {
        case "tetra":
            let e = 12e-3
            let v = [Vec3(0, 0, 0), Vec3(e, 0, 0), Vec3(e / 2, e * 3.0.squareRoot() / 2, 0),
                     Vec3(e / 2, e * 3.0.squareRoot() / 6, e * (2.0 / 3).squareRoot())]
            let c = (v[0] + v[1] + v[2] + v[3]) * 0.25
            for i in 0..<4 { for j in (i + 1)..<4 { originalSegments.append((centre + v[i] - c, centre + v[j] - c)) } }
        default:
            let ring = (0..<48).map { q -> Vec3 in
                let th = 2 * Double.pi * Double(q) / 48
                return centre + Vec3(8e-3 * cos(th), 8e-3 * sin(th), 0)
            }
            originalSegments = (0..<48).map { (ring[$0], ring[($0 + 1) % 48]) }
        }
        var object: [Vec3] = []
        for (a, b) in originalSegments {
            let m = max(1, Int(((b - a).length / 1e-3).rounded()))
            for q in 0...m {
                let p = a + (b - a) * (Double(q) / Double(m))
                if !object.contains(where: { ($0 - p).length < 1e-6 }) { object.append(p) }
            }
        }
        let half = 14e-3, h = 0.7e-3
        let n = Int((2 * half / h).rounded()) + 1
        let grid = FieldLattice(origin: centre - Vec3(half, half, half), spacing: h, nx: n, ny: n, nz: n)
        print(String(format: "replicate %@ in open air: 2 × %d elements; %d scatterers; scans: %d frequencies %.0f–%.0f kHz × %d chords, SNR %.0f dB, grid ±%.0f mm at %.2f mm (%d³)",
                     objectName, perPlate, object.count, scan.sweep(on: arr).count, scan.sweep(on: arr).lo / 1000, scan.sweep(on: arr).hi / 1000, scan.chords, scan.snrDB,
                     half * 1000, h * 1000, n))
        print("1. scan the original")
        let I0 = try scanImageArray(ctx: ctx, array: arr, object: object, subunit: 0.3e-3, grid: grid, setup: scan)
        // Sites only where the mold can put powder: its ±10 mm release box.
        let read = extractShape(image: I0, grid: grid, threshold: 0.5, spacing: 3e-3, within: { x in
            abs(x.x - centre.x) <= 9.5e-3 && abs(x.y - centre.y) <= 9.5e-3 && abs(x.z - centre.z) <= 9.5e-3 })
        // Resample at ~4 mm: at 3.1 mm the sieve's even fill depends on the
        // shape's orientation against the plates' spirals (Round 12).
        let siteSpacing = (arg("--spacing").flatMap(Double.init) ?? 4.0) * 1e-3
        let even = resampleShape(sites: read.sites, segments: read.segments, spacing: siteSpacing)
        print(String(format: "   read: %d peaks; resampled along the shape to %d sites ~%.1f mm apart",
                     read.sites.count, even.sites.count, siteSpacing * 1000))
        let siteOff = even.sites.map { shapeDistance($0, originalSegments) }
        let onObject = Double(siteOff.filter { $0 <= 1.5e-3 }.count) / Double(max(1, even.sites.count))
        let covered = Double(object.filter { o in even.sites.contains { ($0 - o).length <= 2.5e-3 } }.count) / Double(object.count)
        print(String(format: "2. the shape read off the scan: %d sites, %d segments; %.0f%% of the sites within 1.5 mm of the object (worst %.2f mm); %.0f%% of the object within 2.5 mm of a site",
                     even.sites.count, even.segments.count, 100 * onObject, 1000 * (siteOff.max() ?? 0), 100 * covered))
        print("3. mold the copy (the sieve on the shape read off the scan)")
        var ms = MoldSetup()
        ms.debug = args.contains("--debug")
        let mold = try runMold(ctx: ctx, label: "read \(objectName)", sites: even.sites, segments: even.segments,
                               chamber: .plates(arr), setup: ms)
        let copy = zip(mold.final, mold.onShape).filter { $0.1 }.map { $0.0 }
        let copyOff = copy.map { shapeDistance($0, originalSegments) }
        let onOriginal = Double(copyOff.filter { $0 <= 1.5e-3 }.count) / Double(max(1, ms.grains))
        let sortedOff = copyOff.sorted()
        let medianOff = sortedOff.isEmpty ? 0 : sortedOff[sortedOff.count / 2]
        print(String(format: "   the copy: %d grains on the read shape; %.0f%% of the whole cloud within 1.5 mm of the ORIGINAL object (median %.2f mm)",
                     copy.count, 100 * onOriginal, 1000 * medianOff))
        print("4. scan the copy (each grain a Ø40 µm scatterer)")
        var s1 = scan
        s1.seed = scan.seed &+ 1
        let I1 = try scanImageArray(ctx: ctx, array: arr, object: copy.isEmpty ? [centre] : copy, subunit: 20e-6, grid: grid, setup: s1)
        let corr = pearson(I0, I1)
        print(String(format: "5. the two scans correlate %.3f over the %d³ grid", corr, n))
        let detail = String(format: "%@: %d sites read (%.0f%% on the object, %.0f%% of it covered); %@; copy: %.0f%% of the cloud within 1.5 mm of the original (median %.2f mm); scans correlate %.3f",
                            objectName, even.sites.count, 100 * onObject, 100 * covered, mold.summary, 100 * onOriginal, 1000 * medianOff, corr)
        var gates = [
            GateResult(id: "G-R1", name: "replicate (\(objectName)): the shape read off the scan lies on the object (sites within 1.5 mm)",
                       measured: onObject, threshold: 0.9, comparison: .greaterThan, detail: detail),
            GateResult(id: "G-R2", name: "replicate (\(objectName)): ≥90% of the powder ends within 1.5 mm of the ORIGINAL object",
                       measured: onOriginal, threshold: 0.9, comparison: .greaterThan, detail: detail),
            GateResult(id: "G-R3", name: "replicate (\(objectName)): the copy's scan matches the original's (Pearson over the grid)",
                       measured: corr, threshold: 0.7, comparison: .greaterThan, detail: detail)]
        gates.append(contentsOf: mold.gates)
        for g in gates { print(g.line) }
        print(String(format: "(%.1fs)", Date().timeIntervalSince(t0)))
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "replicate-\(objectName)" + (arr.lowerSites == nil ? "" : "-\(arr.tag)"), gates: gates, durationSeconds: Date().timeIntervalSince(t0),
                                 device: deviceName(), gitSHA: gitSHA()))
        }
        let base = "Receipts/replicate_\(objectName)" + (arr.lowerSites == nil ? "" : "_\(arr.tag)")
        try? mipCSV(I0, grid: grid).write(toFile: base + "_scan0_mip.csv", atomically: true, encoding: .utf8)
        try? mipCSV(I1, grid: grid).write(toFile: base + "_scan1_mip.csv", atomically: true, encoding: .utf8)
        try? String(format: "%.4f,%d\n", h * 1000, n).write(toFile: base + "_grid.csv", atomically: true, encoding: .utf8)
        func rel(_ p: Vec3) -> String { String(format: "%.3f,%.3f,%.3f", (p.x - grid.origin.x) * 1000, (p.y - grid.origin.y) * 1000, (p.z - grid.origin.z) * 1000) }
        try? ("x_mm,y_mm,z_mm\n" + object.map { rel($0) + "\n" }.joined()).write(toFile: base + "_object.csv", atomically: true, encoding: .utf8)
        try? ("x_mm,y_mm,z_mm,grains\n" + mold.sites.enumerated().map { rel($0.element) + ",\(mold.perSite[$0.offset])\n" }.joined())
            .write(toFile: base + "_sites.csv", atomically: true, encoding: .utf8)
        try? ("x_mm,y_mm,z_mm\n" + copy.map { rel($0) + "\n" }.joined()).write(toFile: base + "_copy.csv", atomically: true, encoding: .utf8)
    } catch { print("GPU unavailable: \(error)"); exit(2) }

case "build":
    // the first builds between the plates (BuildCore.swift)
    exit(BuildCommand.run(args))

case "levitate", "carry", "fly":
    // hold, carry and fly one bead between the plates (PlaceCore.swift)
    exit(PlaceCommand.run(cmd, args))

case "shot":
    exit(await MainActor.run { ShotCommand.run(args: args) })

case "cad":
    exit(CADCommand.run(args))

case "windings":
    exit(WindingsCommand.run(args))

case "status":
    // The newest receipt of each kind (optionally: --plate rh1x1536t9), every gate with a bar.
    let filter = args.firstIndex(of: "--plate").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } ?? ""
    let rs = Receipt.latest(in: URL(fileURLWithPath: "Receipts"), containing: filter)
    print(Receipt.statusMarkdown(rs))
    let failed = rs.flatMap(\.gates).filter { !$0.passed }
    print(failed.isEmpty ? "all gates with a bar pass" : "\(failed.count) FAIL: " + failed.map(\.id).joined(separator: ", "))
    exit(failed.isEmpty ? 0 : 1)

case "backend", "fcode", "play":
    exit(MachineCommand.run(args))

default:
    print("""
    fieldc — Field Compiler CLI

      fieldc test               run the unit suite
      fieldc gpu [--receipt]    the GPU kernels against their CPU reference (G-A1, G-A3)
      fieldc levitate | carry | fly [--receipt]   hold, carry and fly one bead between the plates (G-P1, G-P2)
      fieldc build [--shape tetra] [--receipt]    place beads: a row (G-B1), a tetrahedron (G-B2)
      fieldc shot [scene] [--all] [--light] [--contact-sheet] [--out DIR]
      fieldc cad [info|check|render|export|drawing|bom|params|step]   the RH-1 solid model
      fieldc windings [--receipt]   the contrawound windings' fields: modes, channels, lift (Round 13)
      fieldc fcode demo [--array cad] [--out f.fcode]   write a demonstration stream
      fieldc play <f.fcode> [--object point|ring] [--log f.fcodelog]   play it through the emulated machine
      fieldc backend [--receipt]    gates of the machine program layer (G-FC1…5)

    Built for CommandLineTools only — no Xcode, no external dependencies.
    """)
}
