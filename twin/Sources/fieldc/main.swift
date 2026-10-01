import FieldCore
import FieldGPU
import FieldUI
import SwiftUI
import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

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
/// The mold's test shapes around a centre: sites, and the segments joining them.
func moldShape(_ shape: String, centre: Vec3) -> ([Vec3], [(Vec3, Vec3)]) {
    var sites: [Vec3] = []
    var segments: [(Vec3, Vec3)] = []
    switch shape {
    case "tetra":
        // 4 vertices + 6 edge midpoints of a tetrahedron with 12 mm edges.
        let e = 12e-3
        let v = [Vec3(0, 0, 0), Vec3(e, 0, 0), Vec3(e / 2, e * 3.0.squareRoot() / 2, 0),
                 Vec3(e / 2, e * 3.0.squareRoot() / 6, e * (2.0 / 3).squareRoot())]
        let c = (v[0] + v[1] + v[2] + v[3]) * 0.25
        sites = v.map { centre + $0 - c }
        for i in 0..<4 { for j in (i + 1)..<4 {
            sites.append(centre + (v[i] + v[j]) * 0.5 - c)
            segments.append((centre + v[i] - c, centre + v[j] - c))
        } }
    default:
        // 16 sites on a horizontal ring, 8 mm radius (3.1 mm apart).
        sites = (0..<16).map { q in
            let th = 2 * Double.pi * Double(q) / 16
            return centre + Vec3(8e-3 * cos(th), 8e-3 * sin(th), 0)
        }
        segments = (0..<16).map { (sites[$0], sites[($0 + 1) % 16]) }
    }
    return (sites, segments)
}

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

/// The free-standing RH-1's operator over a lattice: GPU port fields when a
/// Metal device exists, the CPU reference otherwise.
func standardPropagator(frequency f: Double, lattice: FieldLattice) -> (Propagator, MachinePreset, String) {
    let (preset, coupling, walls) = RH1Freestanding.standard(frequency: f)
    let t0 = Date()
    if let ctx = try? MetalContext(),
       let p = try? PortFieldsGPU.propagator(ctx: ctx, elements: preset.elements, coupling: coupling,
                                             walls: walls, lattice: lattice, frequency: f,
                                             medium: preset.medium, gateCount: preset.gateCount) {
        return (p, preset, String(format: "GPU %.2fs", Date().timeIntervalSince(t0)))
    }
    let p = Propagator(elements: preset.elements, lattice: lattice, frequency: f, medium: preset.medium,
                       gateCount: preset.gateCount, elementCoupling: coupling, walls: walls)
    return (p, preset, String(format: "CPU %.2fs", Date().timeIntervalSince(t0)))
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

case "g5":
    // Diagnostic sweep: if the residual falls ~1/cpw^2 the error is FDTD grid
    // dispersion (a known property of the Yee scheme), not a propagator fault.
    print("  cells/lambda   residual")
    for cpw in [6, 8, 10, 12] {
        let g = G5.run(cellsPerWavelength: cpw)
        print(String(format: "  %10d   %8.4f%@", cpw, g.measured,
                     (g.passed ? "  <- PASSES" : "") as NSString))
    }

case "gate", "gates":
    let t0 = Date()
    let gates = PhysicsGates.runAll()
    let r = Receipt(name: "gates", gates: gates,
                    durationSeconds: Date().timeIntervalSince(t0),
                    device: deviceName(), gitSHA: gitSHA())
    print(r.summary)
    if args.contains("--receipt") { writeReceipt(r) }
    exit(r.allPassed ? 0 : 1)

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

case "machine" where !args.contains("--desktop"):
    // The free-standing RH-1 (the machine the app simulates). `--desktop`
    // shows the frozen v0.3 desktop preset kept for receipt replay.
    var o = RH1Freestanding.Options()
    o.medium = RH1Freestanding.roomAir
    o.slotsOpen = !args.contains("--slots-closed")
    let (preset, coupling) = RH1Freestanding.preset(o)
    let d = RH1Design()
    print("preset      : \(preset.displayName) [\(preset.id)] — geometry read from RH1Model")
    print("gates       : \(preset.gateCount) acoustic (3 throat piezos × 2 build-chamber faces)")
    print("elements    : \(preset.elements.count) virtual (apertures × gates), slots \(o.slotsOpen ? "OPEN" : "closed")")
    print("build volume: r = \(preset.buildVolume.radius * 1000) mm, h = \(preset.buildVolume.height * 1000) mm (face to face)")
    let mags = coupling.map(\.magnitude)
    print(String(format: "horn coupling: |c| %.3f … %.3f (HornModel STUB, c_h = %.1f m/s)",
                 mags.min() ?? 0, mags.max() ?? 0, o.horn.channelSpeed(o.medium)))
    print(String(format: "medium      : air 20 °C 50 %% RH, c = %.2f m/s, %.2f dB/m at 40 kHz",
                 o.medium.soundSpeed, o.medium.absorption(at: 40_000) * 8.686))
    print("walls       : the facing plates, L = \(d.buildChamberHeight) mm, image order 3")

case "plates":
    // The plate-primary aperture study (PlateApertureStudy): can 6 throat
    // gates hold a trap, at one tone vs a chord, slots open vs closed?
    let t0 = Date()
    var gates: [GateResult] = []
    print("condition                                  apertures  contrast   par/main   main depth")
    for (label, tones, slots, walls) in PlateApertureStudy.conditions {
        let r = PlateApertureStudy.run(label: label, tones: tones, slotsOpen: slots, walls: walls)
        print(String(format: "%-42@ %9d %9.2f %10.3f   %.3e", label as NSString, r.apertures,
                     r.focusContrast, r.parasiticToMain, r.mainDepth))
        gates.append(GateResult(id: "P-\(tones)t-\(slots ? "open" : "closed")-\(walls ? "walls" : "free")",
                                name: "plate aperture: \(label)", measured: r.parasiticToMain,
                                threshold: 0, comparison: .informational,
                                detail: String(format: "focus contrast %.2f, main depth %.3e J, %d apertures; MODEL numbers (HornModel stub)",
                                               r.focusContrast, r.mainDepth, r.apertures)))
    }
    print(String(format: "(%.1fs) lower par/main is better; ∞ = no trap at the target", Date().timeIntervalSince(t0)))
    if args.contains("--receipt") {
        writeReceipt(Receipt(name: "plates", gates: gates, durationSeconds: Date().timeIntervalSince(t0),
                             device: deviceName(), gitSHA: gitSHA()))
    }

case "machine":
    // --desktop: the frozen v0.3 desktop preset (receipt replay only).
    let preset = RH1.preset(includeEMCaps: args.contains("--em"))
    print("preset      : \(preset.displayName) [\(preset.id)]")
    print("gates       : \(preset.gateCount)")
    print("elements    : \(preset.elements.count)")
    print("build volume: r = \(preset.buildVolume.radius * 1000) mm, "
        + "h = \(preset.buildVolume.height * 1000) mm")
    print("medium      : rho = \(preset.medium.density), c = \(preset.medium.soundSpeed)")
    let l = preset.medium.wavelength(at: 40_000)
    print("lambda@40kHz: \(String(format: "%.3f", l * 1000)) mm  "
        + "(node spacing \(String(format: "%.3f", l / 2 * 1000)) mm)")
    var bySurface: [SurfaceID: Int] = [:]
    for e in preset.elements { bySurface[e.surface, default: 0] += 1 }
    for (k, v) in bySurface.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
        print("  \(k.rawValue): \(v) elements")
    }

case "focus":
    // Compile a single trap and report what the field actually does.
    let f = 40_000.0
    let bv = RH1Freestanding.standard(frequency: f).preset.buildVolume
    let lambda = RH1Freestanding.roomAir.wavelength(at: f)
    let inset = 2 * lambda, sp = lambda / 2
    let R = bv.radius
    let lat = FieldLattice(origin: Vec3(-R, -R, inset), spacing: sp,
                           nx: Int((2 * R / sp).rounded(.down)) + 1,
                           ny: Int((2 * R / sp).rounded(.down)) + 1,
                           nz: Int(((bv.height - 2 * inset) / sp).rounded(.down)) + 1)
    print("building operator: \(lat.count) points, RH-1 free-standing ...")
    let (prop, preset, how) = standardPropagator(frequency: f, lattice: lat)
    print("  \(preset.gateCount) gates, \(preset.elements.count) elements — built (\(how))")
    let target = Vec3(0, 0, preset.buildVolume.height / 2)
    let g = Gorkov(medium: preset.medium, particle: .pla())
    print("  contrast Phi = \(String(format: "%.3f", g.contrast)) "
        + "(>0 => traps at pressure nodes)")
    for method in InverseSolver.Method.allCases {
        let u = InverseSolver.solve(propagator: prop,
                                    points: [.init(position: target, targetAmplitude: 1)],
                                    method: method, iterations: 80)
        let field = prop.forward(u)
        let at = prop.pressure(at: target, drive: u).magnitude
        let mean = field.reduce(0.0) { $0 + $1.magnitude } / Double(field.count)
        let force = g.force(at: target, propagator: prop, drive: u)
        let name = method.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)
        print("  \(name) gain \(String(format: "%6.2f", at / max(mean, 1e-30)))x   "
            + "|F| = \(String(format: "%.3e", force.length)) N   "
            + "holds 200um PLA: \(g.canLevitate(force: force) ? "yes" : "no")")
    }

case "gpu":
    // G-GPU: the Metal propagator must match the CPU reference. A GPU kernel
    // with no reference to be tested against is a kernel nobody can trust.
    do {
        let ctx = try MetalContext()
        print("device: \(ctx.deviceDescription)")
        let preset = TestPresets.singlePlate(n: 8)
        let lat = FieldLattice(origin: Vec3(-0.02, -0.02, 0.03), spacing: 0.004,
                               nx: 8, ny: 8, nz: 8)
        let cpu = Propagator(elements: preset.elements, lattice: lat,
                             frequency: 40_000, medium: preset.medium,
                             gateCount: preset.gateCount)
        let gpu = try PropagatorGPU(ctx: ctx, elements: preset.elements, lattice: lat,
                                    frequency: 40_000, medium: preset.medium,
                                    gateCount: preset.gateCount)
        var drive = [Complex](repeating: .zero, count: preset.gateCount)
        for i in drive.indices { drive[i] = Complex.expi(Double(i) * 0.37) }
        let a = cpu.forward(drive)
        let b = try gpu.forwardToHost(drive)
        let rel = b.relativeL2(to: a)
        let g = GateResult(id: "G-GPU", name: "Metal propagator vs CPU reference",
                           measured: rel, threshold: 1e-5,
                           detail: "\(lat.count) points x \(preset.gateCount) gates; "
                                 + "float32 GPU vs float64 CPU; "
                                 + String(format: "build %.3fs", gpu.buildSeconds))
        print(g.line)

        // G-GPU-FS: the port-field kernel on the machine the app simulates —
        // horn couplings, both plates as walls (3 image orders), air
        // absorption — against the CPU gate rows at random chamber points.
        var gates = [g]
        for f in [40_000.0, 100_000.0] {
            let (fs, coupling, walls) = RH1Freestanding.standard(frequency: f)
            var rng = SplitMix64(seed: 7)
            let bv = fs.buildVolume
            let pts: [Vec3] = (0..<192).map { _ in
                let r = bv.radius * rng.nextUnit().squareRoot(), a = 2 * Double.pi * rng.nextUnit()
                return Vec3(r * cos(a), r * sin(a), bv.height * (0.05 + 0.9 * rng.nextUnit()))
            }
            let t0 = Date()
            let hG = try PortFieldsGPU.build(ctx: ctx, elements: fs.elements, coupling: coupling,
                                             walls: walls, points: pts, frequency: f,
                                             medium: fs.medium, gateCount: fs.gateCount)
            let tG = Date().timeIntervalSince(t0)
            let ref = Propagator(elements: fs.elements,
                                 lattice: FieldLattice(origin: .zero, spacing: 1, nx: 1, ny: 1, nz: 1),
                                 frequency: f, medium: fs.medium, gateCount: fs.gateCount,
                                 elementCoupling: coupling, walls: walls)
            let hC = pts.flatMap { ref.gateRow(at: $0) }
            let err = hG.relativeL2(to: hC)
            let terms = Double(pts.count * fs.elements.count * (1 + 2 * walls.order))
            let gf = GateResult(id: "G-GPU-FS", name: String(format: "port fields, RH-1 FS at %.0f kHz, vs CPU", f / 1000),
                                measured: err, threshold: 1e-4,
                                detail: "\(pts.count) points x \(fs.gateCount) gates, \(fs.elements.count) elements, "
                                      + "walls order \(walls.order), air \(String(format: "%.2f", fs.medium.absorption(at: f) * 8.686)) dB/m; "
                                      + String(format: "%.0f M terms/s", terms / tG / 1e6))
            print(gf.line)
            gates.append(gf)
            if f == 40_000 {
                // The gradient kernel (force compiler input) vs the CPU rows.
                let sub = Array(pts.prefix(64))
                let hG4 = try PortFieldsGPU.buildWithGradient(ctx: ctx, elements: fs.elements, coupling: coupling,
                                                              walls: walls, points: sub, frequency: f,
                                                              medium: fs.medium, gateCount: fs.gateCount)
                var hC4: [Complex] = []
                for x in sub {
                    let r = ref.gateGradientRows(at: x)
                    for gi in 0..<fs.gateCount { hC4 += [r.p[gi], r.grad[0][gi], r.grad[1][gi], r.grad[2][gi]] }
                }
                let gg = GateResult(id: "G-GPU-FS-grad", name: "port fields + analytic gradient, RH-1 FS at 40 kHz, vs CPU",
                                    measured: hG4.relativeL2(to: hC4), threshold: 1e-4,
                                    detail: "\(sub.count) points x \(fs.gateCount) gates x (p, ∂p/∂x, ∂p/∂y, ∂p/∂z)")
                print(gg.line)
                gates.append(gg)
            }
        }
        // G-GPU-CYL: the cavity modal sum (glass + plates) with gradients.
        do {
            let (fs, coupling, _) = RH1Freestanding.standard(frequency: 40_000)
            let k = fs.medium.wavenumber(at: 40_000)
            let zMin = 0.02
            let cav = RH1Freestanding.chamber(maxGamma: (k * k + pow(log(1e4) / zMin, 2)).squareRoot())
            let src = cav.source(elements: fs.elements, coupling: coupling, gateCount: fs.gateCount,
                                 frequency: 40_000, medium: fs.medium, zMin: zMin)
            var rng = SplitMix64(seed: 11)
            let pts: [Vec3] = (0..<64).map { _ in
                let r = 0.18 * rng.nextUnit().squareRoot(), a = 2 * Double.pi * rng.nextUnit()
                return Vec3(r * cos(a), r * sin(a), zMin + (cav.length - 2 * zMin) * rng.nextUnit())
            }
            let t0 = Date()
            let hG = try CavityFieldsGPU.build(ctx: ctx, cavity: cav, source: src, points: pts, withGradient: true)
            let tG = Date().timeIntervalSince(t0)
            var hC: [Complex] = []
            for x in pts {
                let r = cav.rows(at: x, source: src)
                for gi in 0..<fs.gateCount { hC += [r.p[gi], r.grad[0][gi], r.grad[1][gi], r.grad[2][gi]] }
            }
            let gc = GateResult(id: "G-GPU-CYL", name: "cavity modal sum (glass + plates) with gradient, 40 kHz, vs CPU",
                                measured: hG.relativeL2(to: hC), threshold: 1e-4,
                                detail: String(format: "%d points x %d gates x 4; %d modes (a = %.0f mm), %.2fs",
                                               pts.count, fs.gateCount, src.modeCount, cav.radius * 1000, tG))
            print(gc.line)
            gates.append(gc)
            // The same with the glass lined (β = 0.5, R = 1/3): complex radial
            // wavenumbers, read off the real table by the multiplication theorem.
            let t1 = Date()
            let srcL = cav.source(elements: fs.elements, coupling: coupling, gateCount: fs.gateCount,
                                  frequency: 40_000, medium: fs.medium, zMin: zMin, wallAdmittance: 0.5)
            let tS = Date().timeIntervalSince(t1)
            let t2 = Date()
            let hGL = try CavityFieldsGPU.build(ctx: ctx, cavity: cav, source: srcL, points: pts, withGradient: true)
            let tGL = Date().timeIntervalSince(t2)
            var hCL: [Complex] = []
            for x in pts {
                let r = cav.rows(at: x, source: srcL)
                for gi in 0..<fs.gateCount { hCL += [r.p[gi], r.grad[0][gi], r.grad[1][gi], r.grad[2][gi]] }
            }
            let maxK = srcL.terms.max() ?? 0
            let meanK = Double(srcL.terms.reduce(0, +)) / Double(max(1, srcL.terms.count))
            let gl = GateResult(id: "G-GPU-CYL-lined", name: "cavity modal sum, glass lined (β = 0.5), with gradient, 40 kHz, vs CPU",
                                measured: hGL.relativeL2(to: hCL), threshold: 1e-4,
                                detail: String(format: "%d modes, terms mean %.1f max %d; zeros + projection %.2fs, GPU %.2fs",
                                               srcL.modeCount, meanK, maxK, tS, tGL))
            print(gl.line)
            gates.append(gl)
            // On the axis. A probe lattice with an odd point count puts a column
            // exactly on x = y = 0, where φ is undefined and the m ≠ 0 terms go
            // as J_m(μr)/r; the kernel returned exact zeros there (the tetra
            // mold's apex, 1 Oct). Exactly on the axis and 1 µm off it.
            var axisPts: [Vec3] = []
            for q in 0..<8 {
                let z = zMin + (cav.length - 2 * zMin) * (Double(q) + 0.5) / 8
                axisPts += [Vec3(0, 0, z), Vec3(1e-6, 0, z), Vec3(0, -1e-6, z)]
            }
            let hA = try CavityFieldsGPU.build(ctx: ctx, cavity: cav, source: src, points: axisPts, withGradient: true)
            var hAC: [Complex] = []
            for x in axisPts {
                let r = cav.rows(at: x, source: src)
                for gi in 0..<fs.gateCount { hAC += [r.p[gi], r.grad[0][gi], r.grad[1][gi], r.grad[2][gi]] }
            }
            let ga = GateResult(id: "G-GPU-CYL-axis", name: "cavity modal sum with gradient ON the axis and 1 µm off it, vs CPU",
                                measured: hA.relativeL2(to: hAC), threshold: 1e-4,
                                detail: String(format: "%d points; |GPU| %.3e, |CPU| %.3e", axisPts.count,
                                               hA.reduce(0) { $0 + $1.magnitudeSquared }.squareRoot(),
                                               hAC.reduce(0) { $0 + $1.magnitudeSquared }.squareRoot()))
            print(ga.line)
            gates.append(ga)
        }
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

case "drift":
    // How fast a compiled trap goes stale as the air warms (ThermalDrift):
    // compile at 20 °C, keep the drive, re-solve at +ΔT, track the trap —
    // with direct paths only, with the plates as mirrors, and with the glass
    // cylinder as well (the cavity model; ≤ 100 kHz, the Bessel table beyond
    // that is ~1 GB and wants an asymptotic form).
    do {
        let ctx = try MetalContext()
        let t0 = Date()
        let freqs = args.contains("--quick") ? [40_000.0] : [40_000.0, 100_000.0, 200_000.0]
        let dTs = [0, 0.1, 0.3, 1, 3]
        let air = RH1Freestanding.roomAir
        let plateWalls = RH1Freestanding.walls()
        func images(_ w: Propagator.Walls) -> ThermalDrift.Builder {
            { p, c, lat, f, m in
                try PortFieldsGPU.propagator(ctx: ctx, elements: p.elements, coupling: c, walls: w,
                                             lattice: lat, frequency: f, medium: m, gateCount: p.gateCount)
            }
        }
        let cavityFMax = 100_000.0
        let cav = RH1Freestanding.chamber(maxGamma: {
            let k = air.wavenumber(at: cavityFMax), e = log(1e4) / 0.05
            return (k * k + e * e).squareRoot() }())
        let glass: ThermalDrift.Builder = { p, c, lat, f, m in
            let zlo = lat.origin.z, zhi = lat.origin.z + Double(lat.nz - 1) * lat.spacing
            let zMin = max(0.05, min(zlo, cav.length - zhi))
            return try CavityFieldsGPU.propagator(ctx: ctx, cavity: cav, elements: p.elements, coupling: c,
                                                  lattice: lat, frequency: f, medium: m,
                                                  gateCount: p.gateCount, zMin: zMin)
        }
        // The glass lined with a ρc-matched absorber (normal-incidence R = 0,
        // β = 1): the best a locally reacting liner does (wallsweep).
        let lined: ThermalDrift.Builder = { p, c, lat, f, m in
            let zlo = lat.origin.z, zhi = lat.origin.z + Double(lat.nz - 1) * lat.spacing
            let zMin = max(0.05, min(zlo, cav.length - zhi))
            return try CavityFieldsGPU.propagator(ctx: ctx, cavity: cav, elements: p.elements, coupling: c,
                                                  lattice: lat, frequency: f, medium: m,
                                                  gateCount: p.gateCount, zMin: zMin, wallAdmittance: 1)
        }
        let conditions = [
            ThermalDrift.Condition("direct paths only", build: images(.none)),
            ThermalDrift.Condition("both plates as mirrors (3 image orders, R = 0.9)", build: images(plateWalls)),
            ThermalDrift.Condition(String(format: "glass cylinder (a = %.0f mm) + plates, R = 0.9", cav.radius * 1000),
                                   maxFrequency: cavityFMax, build: glass),
            ThermalDrift.Condition("glass lined (β = 1, R = 0) + plates, R = 0.9",
                                   maxFrequency: cavityFMax, build: lined),
        ]
        let rows = try ThermalDrift.run(frequencies: freqs, dTs: dTs, conditions: conditions)
        let dcdT = ThermalDrift.relativeSpeedDrift(air)
        print(String(format: "room air 20 °C, 50 %% RH: c = %.2f m/s, dc/c = %.3f %%/K; "
                     + "drive compiled at 20 °C and held; 200 µm PLA bead", air.soundSpeed, dcdT * 100))
        print("shift = tracked trap's move (µm) · depth = its depth vs 20 °C · * = a sibling is now the deepest well")
        func pad(_ x: String, _ n: Int, left: Bool = false) -> String {
            let fill = String(repeating: " ", count: max(0, n - x.count)); return left ? fill + x : x + fill }
        let head = dTs.dropFirst().map { pad(String(format: "+%.1f K", $0), 12, left: true) }.joined()
        for f in freqs {
            for cond in conditions where f <= cond.maxFrequency {
                print(String(format: "\n%.0f kHz, %@", f / 1000, cond.label))
                print(pad("target", 30) + head)
                for t in ThermalDrift.defaultTargets().map(\.label) {
                    let r = rows.filter { $0.frequency == f && $0.condition == cond.label && $0.target == t && $0.dT > 0 }
                    guard !r.isEmpty else { continue }
                    let cells = r.map { String(format: "%6.0f/%.2f%@", $0.shift * 1e6, $0.depthRatio, $0.hopped ? "*" : " ") }
                    print(pad(t, 30) + cells.map { pad($0, 12, left: true) }.joined())
                    let fixed = r.map { String(format: "%6.0f/%.2f ", $0.resolvedShift * 1e6, $0.resolvedDepthRatio) }
                    print(pad("  ↳ re-solved at true T", 30) + fixed.map { pad($0, 12, left: true) }.joined())
                }
            }
        }
        // G-T1: with direct paths only, a node a distance d off the mid-plane
        // moves by d·Δc/c. Checked at 40 kHz, +3 K, on both axial targets.
        var gates: [GateResult] = []
        for r in rows where r.frequency == 40_000 && r.condition == conditions[0].label && r.dT == 3
                            && abs(r.offMidPlane) > 0.01 && r.target != "60 mm off-axis, mid-plane" {
            let expect = r.offMidPlane * ((air.shifted(byKelvin: 3).soundSpeed - air.soundSpeed) / air.soundSpeed)
            let err = abs(r.shiftZ - expect) / abs(expect)
            let g = GateResult(id: "G-T1", name: "thermal node drift vs d·Δc/c (\(r.target), direct paths, +3 K)",
                               measured: err, threshold: 0.25,
                               detail: String(format: "twin %+.1f µm, closed form %+.1f µm", r.shiftZ * 1e6, expect * 1e6))
            print(g.line)
            gates.append(g)
        }
        for r in rows where r.condition != conditions[0].label && r.dT == 1 {
            gates.append(GateResult(id: "T-drift", name: String(format: "%.0f kHz, %@, %@, +1 K", r.frequency / 1000,
                                                                  r.condition, r.target),
                                    measured: r.depthRatio, threshold: 0, comparison: .informational,
                                    detail: String(format: "shift %.0f µm, depth %.2f of 20 °C%@",
                                                   r.shift * 1e6, r.depthRatio, r.hopped ? ", sibling now deepest" : "")))
        }
        print(String(format: "(%.1fs)", Date().timeIntervalSince(t0)))
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "drift", gates: gates, durationSeconds: Date().timeIntervalSince(t0),
                                 device: deviceName(), gitSHA: gitSHA()))
        }
        exit(gates.filter { $0.comparison != .informational }.allSatisfy(\.passed) ? 0 : 1)
    } catch { print("GPU unavailable: \(error)"); exit(2) }

case "mold":
    // The single-shot acoustic mold (MoldCore.swift): one chord drive, and a
    // cloud of powder released at random through the volume that ends on the
    // shape. Default: open air between two plates of 192 elements each
    // (ENGINE.md); `--chamber glass` is the glass cylinder of Rounds 7–11.
    // Default objective: the sieve; `--objective wells|funnel` keep the runs
    // that showed why (the λ/4 reach of a still field).
    do {
        let ctx = try MetalContext()
        let t0 = Date()
        func arg(_ name: String) -> String? { args.firstIndex(of: name).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
        let shape = arg("--shape") ?? "ring"
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
        let perPlate = arg("--per-plate").flatMap(Int.init) ?? 192
        let reflection = arg("--reflection").flatMap(Double.init) ?? 0.9
        let glass = arg("--chamber") == "glass"
        let chamber: MoldChamber = glass ? .glass : .plates(PlateArray(perPlate: perPlate, reflection: reflection))
        let L = glass ? RH1Design().buildChamberHeight * 0.001 : PlateArray(perPlate: perPlate).gap
        let centre = Vec3(0, 0, L / 2)
        let (sites, segments) = moldShape(shape, centre: centre)
        let out = try runMold(ctx: ctx, label: shape, sites: sites, segments: segments, chamber: chamber, setup: setup)
        for g in out.gates { print(g.line) }
        print(String(format: "(%.1fs)", Date().timeIntervalSince(t0)))
        let tag = glass ? "" : "-plates\(perPlate)"
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "mold-\(shape)-\(setup.objective)\(tag)", gates: out.gates,
                                 durationSeconds: Date().timeIntervalSince(t0), device: deviceName(), gitSHA: gitSHA()))
        }
        let base = "Receipts/mold_" + (glass ? "" : "plates\(perPlate)_") + shape + (setup.objective == "sieve" ? "" : "_\(setup.objective)")
        if setup.particles {
            try? out.grainsCSV.write(toFile: base + "_grains.csv", atomically: true, encoding: .utf8)
            try? out.captureCSV.write(toFile: base + "_capture.csv", atomically: true, encoding: .utf8)
        }
        try? out.sitesCSV.write(toFile: base + "_targets.csv", atomically: true, encoding: .utf8)
    } catch { print("GPU unavailable: \(error)"); exit(2) }

case "arraysweep":
    // Study S1 (ENGINE.md): how many independently driven elements a plate is
    // worth. Two Ø410 mm plates in open air, N elements each on a Vogel
    // spiral, N = 3 … 768; 1, 3 and 9 tones over 30–70 kHz. For each:
    // a single trap at the centre (the mold compiler with one site: rival
    // well ÷ target well, < 0.5 = unique), and the 16-site ring sieve (lift
    // contrast; where a random powder cloud ends, by the basin map; the drive
    // per channel and the acoustic power it radiates).
    do {
        let ctx = try MetalContext()
        let t0 = Date()
        func arg(_ name: String) -> String? { args.firstIndex(of: name).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
        let counts = arg("--counts")?.split(separator: ",").compactMap { Int($0) } ?? [3, 12, 48, 192, 768]
        let toneSets = arg("--tones")?.split(separator: ",").compactMap { Int($0) } ?? [1, 3, 9]
        let reflection = arg("--reflection").flatMap(Double.init) ?? 0.9
        var band: (lo: Double, hi: Double)? = (30_000, 70_000)
        if let v = arg("--band") {
            let parts = v.split(separator: "-").compactMap { Double($0) }
            if parts.count == 2 { band = (parts[0] * 1000, parts[1] * 1000) }
        }
        let air = RH1Freestanding.roomAir
        var gates: [GateResult] = []
        var csv = "per_plate,tones,trap_ratio,sieve_contrast,on_shape,site_min,site_max,rogue,drive_rms,acoustic_W,compile_s\n"
        print(String(format: "open air: two Ø410 mm plates 460 mm apart, R %.1f, Ø5 mm elements on Vogel spirals; band %.0f–%.0f kHz",
                     reflection, (band?.lo ?? 50_000) / 1000, (band?.hi ?? 70_000) / 1000))
        print("per plate  tones  trap ratio  ring sieve: contrast  on shape  sites (fair 6.3%)  rogue   drive (m/s rms)  acoustic W   compile")
        for N in counts {
            for T in toneSets {
                let arr = PlateArray(perPlate: N, reflection: reflection)
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
    // Scan a 3D object from the six gates, across the band, in the exact glass
    // chamber. By reciprocity a small scatterer at x couples gate j to gate i
    // through what each gate's field does there:
    //     ΔT_ij(f) ∝ −(f1/3) k²a³ p_i(x) p_j(x) − (f2/2) a³ ∇p_i(x)·∇p_j(x)
    // (the chamber-only transfer is calibrated away). An object is a cloud of
    // such scatterers — the Born approximation for a cloud, the coupled solve
    // for a few beads. The image is the matched field: at every grid point, the
    // data correlated with what a point scatterer there would have produced,
    //     I(x) = |Σ_f Σ_ij M_ij(x,f)* ΔT_ij(f)| / (Σ|M|²)^½,
    // with the same exact cavity fields. Its point-spread width is the scan's
    // real resolution; its overlap with the object says what it sees.
    do {
        let ctx = try MetalContext()
        let t0 = Date()
        let air = RH1Freestanding.roomAir
        let design = RH1Design()
        let L = design.buildChamberHeight * 0.001
        let centre = Vec3(0, 0, L / 2)
        var objectName = "tetra"
        if let i = args.firstIndex(of: "--object"), i + 1 < args.count { objectName = args[i + 1] }
        var fHi = 100_000.0, nF = 90
        if let i = args.firstIndex(of: "--fmax"), i + 1 < args.count, let v = Double(args[i + 1]) { fHi = v * 1000 }
        if let i = args.firstIndex(of: "--nf"), i + 1 < args.count, let v = Int(args[i + 1]) { nF = v }
        let fLo = 30_000.0
        var snrDB = 40.0
        if let i = args.firstIndex(of: "--snr"), i + 1 < args.count, let v = Double(args[i + 1]) { snrDB = v }
        // --- the object: a cloud of small rigid scatterers ---
        func segment(_ a: Vec3, _ b: Vec3, _ step: Double) -> [Vec3] {
            let m = max(1, Int(((b - a).length / step).rounded()))
            return (0...m).map { a + (b - a) * (Double($0) / Double(m)) }
        }
        var object: [Vec3] = []
        var subunit = 0.3e-3                               // effective scatterer radius
        var half = 24e-3, h = 1.25e-3                      // imaging grid: ±half at h
        switch objectName {
        case "R":
            // An extruded letter R, 40 mm tall, strokes every 1.5 mm, 3 layers 3 mm apart.
            let H = 40e-3, W = 24e-3
            var strokes: [(Vec3, Vec3)] = [(Vec3(0, 0, 0), Vec3(0, 0, H))]
            let bowlTop = H, bowlBottom = H * 0.5, r = (bowlTop - bowlBottom) / 2
            strokes.append((Vec3(0, 0, bowlTop), Vec3(W - r, 0, bowlTop)))
            strokes.append((Vec3(0, 0, bowlBottom), Vec3(W - r, 0, bowlBottom)))
            strokes.append((Vec3(W * 0.35, 0, bowlBottom), Vec3(W, 0, 0)))
            var pts: [Vec3] = []
            for (a, b) in strokes { pts += segment(a, b, 1.5e-3) }
            for q in 0...16 {                              // the bowl: a half circle
                let th = -Double.pi / 2 + Double.pi * Double(q) / 16
                pts.append(Vec3(W - r + r * cos(th), 0, bowlBottom + r + r * sin(th)))
            }
            for layer in [-3e-3, 0, 3e-3] {
                for p0 in pts { object.append(centre + Vec3(p0.x - W / 2, layer, p0.z - H / 2)) }
            }
        case "bead-tetra":
            // The twin's own 4-bead tetrahedron (Ø200 µm, touching): below the wavelength.
            let a = 0.1e-3, d = 2 * a
            let b0 = Vec3(0, 0, 0), b1 = Vec3(d, 0, 0), b2 = Vec3(d / 2, d * 3.0.squareRoot() / 2, 0)
            let c = (b0 + b1 + b2) * (1.0 / 3)
            let top = c + Vec3(0, 0, d * (2.0 / 3).squareRoot())
            object = [b0, b1, b2, top].map { centre + $0 - c }
            subunit = a; half = 8e-3; h = 0.4e-3
        default:
            // A regular tetrahedron wireframe, 30 mm edges, sampled every 1.5 mm.
            let e = 30e-3
            let v = [Vec3(0, 0, 0), Vec3(e, 0, 0), Vec3(e / 2, e * 3.0.squareRoot() / 2, 0),
                     Vec3(e / 2, e * 3.0.squareRoot() / 6, e * (2.0 / 3).squareRoot())]
            let c = (v[0] + v[1] + v[2] + v[3]) * 0.25
            for i in 0..<4 { for j in (i + 1)..<4 { object += segment(v[i], v[j], 1.5e-3).map { centre + $0 - c } } }
            // de-duplicate the shared vertices
            var seen: [Vec3] = []
            for p0 in object where !seen.contains(where: { ($0 - p0).length < 1e-6 }) { seen.append(p0) }
            object = seen
        }
        let n = Int((2 * half / h).rounded()) + 1
        let grid = FieldLattice(origin: centre - Vec3(half, half, half), spacing: h, nx: n, ny: n, nz: n)
        let coupled = object.count <= 40
        print(String(format: "scan of %@: %d scatterers (radius %.2f mm, %@), %d frequencies %.0f–%.0f kHz, SNR %.0f dB",
                     objectName, object.count, subunit * 1000, coupled ? "coupled" : "Born", nF, fLo / 1000, fHi / 1000, snrDB))
        print(String(format: "image grid ±%.0f mm at %.2f mm (%d³); glass chamber, plates R 0.9, room air", half * 1000, h * 1000, n))
        let cav = RH1Freestanding.chamber(maxGamma: {
            let k = air.wavenumber(at: fHi), e = log(1e4) / 0.1
            return (k * k + e * e).squareRoot() }())
        let zMin = max(0.1, min(grid.origin.z, L - (grid.origin.z + Double(n - 1) * h)))
        var image = [Complex](repeating: .zero, count: grid.count)
        var norm = [Double](repeating: 0, count: grid.count)
        var rng = SplitMix64(seed: 17)
        func gauss() -> Double {                            // Box–Muller
            let u1 = max(rng.nextUnit(), 1e-300), u2 = rng.nextUnit()
            return (-2 * log(u1)).squareRoot() * cos(2 * Double.pi * u2)
        }
        let a3 = subunit * subunit * subunit
        for q in 0..<nF {
            let f = fLo + (fHi - fLo) * Double(q) / Double(max(1, nF - 1))
            var op = RH1Freestanding.Options()
            op.frequency = f; op.medium = air; op.slotSegment = max(2e-3, air.wavelength(at: f) / 4)
            let (p, c) = RH1Freestanding.preset(op)
            let src = cav.source(elements: p.elements, coupling: c, gateCount: p.gateCount, frequency: f, medium: air, zMin: zMin)
            let k = air.wavenumber(at: f)
            let cM = -k * k * a3 / 3, cD = -a3 / 2              // f1 = f2 = 1: rigid, immovable
            // Forward: the six gates' fields at the object, then ΔT.
            let ro = try CavityFieldsGPU.build(ctx: ctx, cavity: cav, source: src, points: object, withGradient: true)
            var dT = [[Complex]](repeating: [Complex](repeating: .zero, count: 6), count: 6)
            if coupled {
                let sc = Scatterers(centers: object, radius: subunit, f1: 1, f2: 1)
                let inc = object.indices.map { m -> (p: [Complex], grad: [[Complex]]) in
                    ((0..<6).map { ro[(m * 6 + $0) * 4] }, (0..<3).map { cc in (0..<6).map { ro[(m * 6 + $0) * 4 + 1 + cc] } })
                }
                let S = sc.solve(incident: inc, k: Complex(k, air.absorption(at: f)))
                for i in 0..<6 {
                    for j in 0..<6 {
                        var acc = Complex.zero
                        for m in object.indices {
                            acc += S.A[m * 6 + j] * inc[m].p[i]
                            for cc in 0..<3 { acc += S.B[cc][m * 6 + j] * inc[m].grad[cc][i] }
                        }
                        dT[i][j] = acc
                    }
                }
            } else {
                for m in object.indices {
                    let b = m * 6 * 4
                    for i in 0..<6 {
                        for j in i..<6 {
                            var v = ro[b + i * 4] * ro[b + j * 4] * cM
                            for cc in 1...3 { v += ro[b + i * 4 + cc] * ro[b + j * 4 + cc] * cD }
                            dT[i][j] += v
                            if j != i { dT[j][i] += v }
                        }
                    }
                }
            }
            // Measurement noise, SNR relative to this frequency's data.
            let rms = (dT.flatMap { $0 }.reduce(0) { $0 + $1.magnitudeSquared } / 36).squareRoot()
            let sigma = rms * pow(10, -snrDB / 20) / 2.0.squareRoot()
            for i in 0..<6 { for j in 0..<6 { dT[i][j] += Complex(gauss() * sigma, gauss() * sigma) } }
            // Image: correlate with a point scatterer's response at every grid point.
            let rg = try CavityFieldsGPU.build(ctx: ctx, cavity: cav, source: src, points: grid.positions, withGradient: true)
            let chunks = 64
            image.withUnsafeMutableBufferPointer { im in
                norm.withUnsafeMutableBufferPointer { nb in
                    DispatchQueue.concurrentPerform(iterations: chunks) { ch in
                        for nn in (ch * grid.count / chunks)..<((ch + 1) * grid.count / chunks) {
                            let b = nn * 6 * 4
                            var acc = Complex.zero, w = 0.0
                            for i in 0..<6 {
                                for j in 0..<6 {
                                    var M = rg[b + i * 4] * rg[b + j * 4] * cM
                                    for cc in 1...3 { M += rg[b + i * 4 + cc] * rg[b + j * 4 + cc] * cD }
                                    acc += M.conjugate * dT[i][j]
                                    w += M.magnitudeSquared
                                }
                            }
                            im[nn] += acc; nb[nn] += w
                        }
                    }
                }
            }
            if q % 15 == 0 { print(String(format: "  %.1f kHz done (%.0f s)", f / 1000, Date().timeIntervalSince(t0))) }
        }
        let I = zip(image, norm).map { $0.0.magnitude / max($0.1, 1e-300).squareRoot() }
        let peak = I.max() ?? 1
        // How the image sits on the object: voxels above half the peak, near an object point?
        let hot = I.indices.filter { I[$0] >= 0.5 * peak }
        func nearObject(_ x: Vec3, _ r: Double) -> Bool { object.contains { ($0 - x).length <= r } }
        let tol = max(2e-3, 1.5 * h)
        let precision = Double(hot.filter { nearObject(grid.positions[$0], tol) }.count) / Double(max(1, hot.count))
        let hotPts = hot.map { grid.positions[$0] }
        let recall = Double(object.filter { o in hotPts.contains { ($0 - o).length <= tol } }.count) / Double(object.count)
        print(String(format: "image: %d voxels above half the peak; %.0f%% of them within %.1f mm of the object; %.0f%% of the object has such a voxel within %.1f mm",
                     hot.count, 100 * precision, tol * 1000, 100 * recall, tol * 1000))
        // Maximum-intensity projections, for the figure.
        var csv = "view,i,j,value\n"
        for (view, axes) in [("xy", (0, 1, 2)), ("xz", (0, 2, 1)), ("yz", (1, 2, 0))] {
            var mip = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
            for k2 in 0..<n { for j2 in 0..<n { for i2 in 0..<n {
                let v = I[grid.index(i2, j2, k2)] / peak
                let idx = [i2, j2, k2]
                mip[idx[axes.0]][idx[axes.1]] = max(mip[idx[axes.0]][idx[axes.1]], v)
            } } }
            for u in 0..<n { for w in 0..<n { csv += "\(view),\(u),\(w),\(String(format: "%.4f", mip[u][w]))\n" } }
        }
        var ocsv = "x_mm,y_mm,z_mm\n"
        for o in object { ocsv += String(format: "%.3f,%.3f,%.3f\n", (o.x - grid.origin.x) * 1000, (o.y - grid.origin.y) * 1000, (o.z - grid.origin.z) * 1000) }
        let gate = GateResult(id: "SCAN", name: "scan of \(objectName): image overlap with the object",
                              measured: precision, threshold: 0, comparison: .informational,
                              detail: String(format: "%d scatterers, %d frequencies %.0f–%.0f kHz, SNR %.0f dB; precision %.0f%%, recall %.0f%% (within %.1f mm)",
                                             object.count, nF, fLo / 1000, fHi / 1000, snrDB, 100 * precision, 100 * recall, tol * 1000))
        print(String(format: "(%.1fs)", Date().timeIntervalSince(t0)))
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "scan3d-" + objectName, gates: [gate], durationSeconds: Date().timeIntervalSince(t0),
                                 device: deviceName(), gitSHA: gitSHA()))
        }
        try? csv.write(toFile: "Receipts/scan3d_\(objectName)_mip.csv", atomically: true, encoding: .utf8)
        try? ocsv.write(toFile: "Receipts/scan3d_\(objectName)_object.csv", atomically: true, encoding: .utf8)
        try? String(format: "%.4f,%d\n", h * 1000, n).write(toFile: "Receipts/scan3d_\(objectName)_grid.csv", atomically: true, encoding: .utf8)
    } catch { print("GPU unavailable: \(error)"); exit(2) }

case "build":
    // The first build: N 200 µm PLA beads laid in a row on a support.
    //
    // Each bead is loaded gently into the unique trap at the glass chamber's
    // mid-plane, carried (carryStep; ramped 40 ms steps at 4× the holding
    // drive, as `fieldc fly`) to hover 0.15 mm above its site, and lowered onto
    // a support 2 mm below the pick-up. Placement is closed-loop: the twin
    // reads where the bead actually hangs — as the machine's scan would — and
    // moves the well by the bead's lateral miss before and during the
    // lowering. A bead fuses where it first touches the support or a placed
    // bead (a binder coat), and the next site is laid off the placed bead's
    // ACTUAL position. The part grows into the field: every placed bead
    // scatters (Scatterers — monopole + dipole, multiple scattering solved), so
    // the traps that bring the next bead are compiled in, and the bead flies
    // through, the field the part has already changed; near the part a 25 µm
    // grid resolves the scattered near field down to contact (--no-scatter:
    // the part is acoustically invisible, as before). Not modelled: the
    // support's own scattering (an acoustically open mesh), streaming.
    do {
        let ctx = try MetalContext()
        let t0 = Date()
        let air = RH1Freestanding.roomAir
        let design = RH1Design()
        let L = design.buildChamberHeight * 0.001
        let lam40 = air.wavelength(at: 40_000)
        let x0 = Vec3(0, 0, L / 2)
        var N = 5
        if let i = args.firstIndex(of: "--beads"), i + 1 < args.count, let v = Int(args[i + 1]) { N = max(1, v) }
        // --shape row (default): N beads in a line; tetra: three touching on the
        // support and a fourth in their pocket — the first bead laid on beads.
        var shape = "row"
        if let i = args.firstIndex(of: "--shape"), i + 1 < args.count { shape = args[i + 1] }
        if shape == "tetra" { N = 4 }
        let freqs = (0..<10).map { 30_000 + 40_000 * (Double($0) + 0.5) / 10 }
        let cav = RH1Freestanding.chamber(maxGamma: {
            let k = air.wavenumber(at: 70_000), e = log(1e4) / 0.05
            return (k * k + e * e).squareRoot() }())
        let h = air.wavelength(at: freqs.max()!) / 8
        let n = Int((2 * 2 * lam40 / h).rounded()) | 1
        let half = Double(n - 1) / 2 * h
        let lat = FieldLattice(origin: x0 - Vec3(half, half, half), spacing: h, nx: n, ny: n, nz: n)
        let zMin = max(0.05, min(lat.origin.z, L - (lat.origin.z + Double(n - 1) * h)))
        var o = ForceCompiler.Options()
        o.shellSteps = max(2, Int((air.wavelength(at: 50_000) / 4 / h).rounded()))
        let particle = ParticleMaterial.pla()
        let scatterOn = !args.contains("--no-scatter")
        var sources: [CylinderCavity.Source] = []
        var tones: [ForceCompiler.Tone] = []
        var base: [[Complex]] = []
        for f in freqs {
            var op = RH1Freestanding.Options()
            op.frequency = f; op.medium = air; op.slotSegment = max(2e-3, air.wavelength(at: f) / 4)
            let (p, c) = RH1Freestanding.preset(op)
            let src = cav.source(elements: p.elements, coupling: c, gateCount: p.gateCount,
                                 frequency: f, medium: air, zMin: zMin)
            sources.append(src)
            tones.append(ForceCompiler.Tone(frequency: f, medium: air,
                                            rows: try CavityFieldsGPU.build(ctx: ctx, cavity: cav, source: src,
                                                                            points: lat.positions, withGradient: true)))
            let prop = Propagator(elements: p.elements, lattice: FieldLattice(origin: .zero, spacing: 1, nx: 1, ny: 1, nz: 1),
                                  frequency: f, medium: air, gateCount: p.gateCount, elementCoupling: c,
                                  cavity: cav, cavitySource: src)
            let u = InverseSolver.solve(propagator: prop, points: [.init(position: x0)],
                                        method: .gspat, iterations: 80, trap: .twinTrap)
            base.append(u.map { $0 * (1 / (u.l2 * Double(freqs.count).squareRoot())) })
        }
        let tonesIn = tones                            // the chamber alone; `tones` gains the part
        let c0 = ((n - 1) / 2, (n - 1) / 2, (n - 1) / 2)
        let r0 = ForceCompiler.compile(tones, lattice: lat, gates: 6, particle: particle, wavelength: lam40,
                                       options: o, starts: [base], target: c0)
        guard let w0 = r0.targetWell else { print("no trap at the pick-up"); exit(1) }
        let a = particle.radius
        let zs = w0.z - 2e-3                          // the support: bead bottoms rest here
        let gapAim = 10e-6                            // aim 10 µm off contact: a miss leaves a gap, not a perch
        let first = Vec3(w0.x + 0.5e-3, w0.y, zs + a)
        // A fine box over the whole build, 0.1 mm.
        let fs = 0.1e-3
        let lo = Vec3(w0.x - 2.5e-3, w0.y - 2.5e-3, zs - 0.5e-3)
        let hi = Vec3(first.x + Double(N) * 2 * a + 2.5e-3, w0.y + 2.5e-3, w0.z + 2e-3)
        let fb = FieldLattice(origin: lo, spacing: fs, nx: Int(((hi.x - lo.x) / fs).rounded()) + 1,
                              ny: Int(((hi.y - lo.y) / fs).rounded()) + 1, nz: Int(((hi.z - lo.z) / fs).rounded()) + 1)
        var fine = try zip(freqs, sources).map { f, src in
            ForceCompiler.Tone(frequency: f, medium: air,
                               rows: try CavityFieldsGPU.build(ctx: ctx, cavity: cav, source: src,
                                                               points: fb.positions, withGradient: true))
        }
        let fineIn = fine
        func potentialFine(_ g: [[Complex]]) -> [Double] {
            ForceCompiler.potential(fine, drives: g, gates: 6, particle: particle, count: fb.count)
        }
        // ∇U at x on a lattice: central differences, trilinear between nodes;
        // nil within `margin` cells of the edge.
        func gradOn(_ L: FieldLattice, _ U: [Double], _ x: Vec3, margin: Int = 1) -> Vec3? {
            let hs = L.spacing
            let f = (x - L.origin) / hs
            let i0 = Int(f.x.rounded(.down)), j0 = Int(f.y.rounded(.down)), k0 = Int(f.z.rounded(.down))
            guard i0 >= margin, j0 >= margin, k0 >= margin,
                  i0 + 1 + margin < L.nx, j0 + 1 + margin < L.ny, k0 + 1 + margin < L.nz else { return nil }
            let tx = f.x - Double(i0), ty = f.y - Double(j0), tz = f.z - Double(k0)
            var gsum = Vec3(0, 0, 0)
            for (dk, wz) in [(0, 1 - tz), (1, tz)] { for (dj, wy) in [(0, 1 - ty), (1, ty)] { for (di, wx) in [(0, 1 - tx), (1, tx)] {
                let i = i0 + di, j = j0 + dj, k = k0 + dk
                gsum = gsum + Vec3((U[L.index(i + 1, j, k)] - U[L.index(i - 1, j, k)]) / (2 * hs),
                                   (U[L.index(i, j + 1, k)] - U[L.index(i, j - 1, k)]) / (2 * hs),
                                   (U[L.index(i, j, k + 1)] - U[L.index(i, j, k - 1)]) / (2 * hs)) * (wx * wy * wz)
            } } }
            return gsum
        }
        func gradU(_ U: [Double], _ x: Vec3) -> Vec3? { gradOn(fb, U, x) }
        struct Placed { var p: Vec3; var on: Int; var site: Vec3 }  // on: −1 = support, j = fused to bead j
        var placed: [Placed] = []
        // ---- The part in the field --------------------------------------
        let kc = freqs.map { Complex(air.wavenumber(at: $0), air.absorption(at: $0)) }
        var part = Scatterers(centers: [], particle: particle, medium: air, fused: true)
        var partSources: [Scatterers.Sources] = []
        var nearLat: FieldLattice? = nil               // 25 µm around the part
        var near: [ForceCompiler.Tone] = []
        // Placed beads' own push: the local field (chamber + the other beads)
        // at a ±10 µm stencil round each bead, per tone.
        let hst = 10e-6
        let stencil = [Vec3(0, 0, 0), Vec3(hst, 0, 0), Vec3(-hst, 0, 0), Vec3(0, hst, 0), Vec3(0, -hst, 0),
                       Vec3(0, 0, hst), Vec3(0, 0, -hst)]
        var stencilTones: [ForceCompiler.Tone] = []
        func incidentRows(_ f: Int, _ x: Vec3) -> (p: [Complex], grad: [[Complex]]) {
            cav.rows(at: x, source: sources[f])
        }
        func updatePart() throws {
            part.centers = placed.map(\.p)
            partSources = []
            tones = tonesIn; fine = fineIn
            if scatterOn && !placed.isEmpty {
                for f in freqs.indices {
                    let src = part.solve(incident: part.centers.map { incidentRows(f, $0) }, k: kc[f])
                    partSources.append(src)
                    part.addField(to: &tones[f].rows, points: lat.positions, sources: src)
                    part.addField(to: &fine[f].rows, points: fb.positions, sources: src)
                }
                // The near grid: the part and the next site, from the support up past the hover height.
                let xs = part.centers.map(\.x), ys = part.centers.map(\.y)
                let nlo = Vec3(xs.min()! - 0.45e-3, ys.min()! - 0.45e-3, zs - 0.05e-3)
                let nhi = Vec3(xs.max()! + 0.45e-3, ys.max()! + 0.45e-3, zs + 0.6e-3)
                let ns = 25e-6
                let L = FieldLattice(origin: nlo, spacing: ns, nx: Int(((nhi.x - nlo.x) / ns).rounded()) + 1,
                                     ny: Int(((nhi.y - nlo.y) / ns).rounded()) + 1, nz: Int(((nhi.z - nlo.z) / ns).rounded()) + 1)
                near = try freqs.indices.map { f in
                    var rows = try CavityFieldsGPU.build(ctx: ctx, cavity: cav, source: sources[f],
                                                         points: L.positions, withGradient: true)
                    part.addField(to: &rows, points: L.positions, sources: partSources[f])
                    return ForceCompiler.Tone(frequency: freqs[f], medium: air, rows: rows)
                }
                nearLat = L
            } else { nearLat = nil; near = [] }
            // Stencil rows for every placed bead: chamber + the OTHER beads.
            stencilTones = freqs.indices.map { f in
                var rows: [Complex] = []
                for (j, c) in placed.enumerated() {
                    for d in stencil {
                        let x = c.p + d
                        var inc = incidentRows(f, x)
                        if scatterOn, !partSources.isEmpty {
                            let sf = part.field(at: x, sources: partSources[f], skip: j)
                            for g in 0..<6 {
                                inc.p[g] += sf.p[g]
                                for q in 0..<3 { inc.grad[q][g] += sf.grad[q][g] }
                            }
                        }
                        for g in 0..<6 { rows += [inc.p[g], inc.grad[0][g], inc.grad[1][g], inc.grad[2][g]] }
                    }
                }
                return ForceCompiler.Tone(frequency: freqs[f], medium: air, rows: rows)
            }
        }
        // Per drive: the push on every placed bead, ∇U by central differences.
        func pushes(_ g: [[Complex]]) -> [Vec3] {
            guard !placed.isEmpty else { return [] }
            let U = ForceCompiler.potential(stencilTones, drives: g, gates: 6, particle: particle, count: 7 * placed.count)
            return placed.indices.map { j in
                let b = 7 * j
                return Vec3(U[b + 1] - U[b + 2], U[b + 3] - U[b + 4], U[b + 5] - U[b + 6]) * (1 / (2 * hst))
            }
        }
        let mass = particle.mass(), g0 = 9.81, weight = mass * g0
        let Upick = potentialFine(r0.drives)
        var fUp = 0.0
        for q in -15...15 { if let gr = gradU(Upick, w0 + Vec3(0, 0, Double(q) * fs)) { fUp = max(fUp, -gr.z) } }
        guard fUp > 0 else { print("the pick-up well pushes nowhere upward"); exit(1) }
        let power = 4 * weight / fUp                  // 4× the holding drive (fly: carries at every step time)
        let gamma = 6 * Double.pi * 1.81e-5 * a
        let alpha = air.absorption(at: 50_000)
        let tauU = 0.5 / (alpha * air.soundSpeed + -log(0.9) * air.soundSpeed / L)
        let Tstep = 0.04, dt = 1e-4
        var o60 = o
        o60.perToneStarts = false
        // Compile the FORCE BALANCE, not the potential minimum: at power P the
        // trap must hold the weight at the aim, P∇U(x) = −mg ẑ, so the bead
        // rests on its aim instead of hanging 0.2 mm below and 0.5 mm aside.
        let hold = Vec3(0, 0, -weight / power)
        // The balance is re-solved on the 0.1 mm box: the probe lattice (0.63 mm)
        // interpolates ∇U too coarsely for a trap this soft sideways — its
        // balance point sat 1.2 mm from the fine field's.
        // Near the part the balance is solved on its 25 µm grid, whose field includes the
        // part's near field; elsewhere on the 0.1 mm box.
        func inside(_ L: FieldLattice, _ x: Vec3, margin: Int) -> Bool {
            let f = (x - L.origin) / L.spacing
            return f.x >= Double(margin) && f.y >= Double(margin) && f.z >= Double(margin)
                && f.x <= Double(L.nx - 1 - margin) && f.y <= Double(L.ny - 1 - margin) && f.z <= Double(L.nz - 1 - margin)
        }
        // `withPart: false` aims the trap on the chamber field alone — for the final
        // approach: compiled WITH the part, the balance leans the trap away to
        // hold the bead off its neighbour's pull, and the bead, on a ridge
        // between the two, falls outward; aimed without it, trap and attraction
        // pull the same way, into contact.
        func placeFine(_ g: [[Complex]], _ x: Vec3, withPart: Bool = true, carry: Double = 1) -> [[Complex]] {
            if !withPart {
                return ForceCompiler.moveWell(fineIn, lattice: fb, gates: 6, particle: particle, drives: g, to: x,
                                              iterations: 6, balance: hold * carry).drives
            }
            if let L = nearLat, inside(L, x, margin: 3) {
                let mv = ForceCompiler.moveWell(near, lattice: L, gates: 6, particle: particle, drives: g, to: x,
                                                iterations: 6, balance: hold)
                if args.contains("--debug") {
                    // Stiffness of P·U + mgz at the aim: second differences on the near grid.
                    let U = ForceCompiler.potential(near, drives: mv.drives, gates: 6, particle: particle, count: L.count)
                    func Uat(_ y: Vec3) -> Double { ForceCompiler.interpolate(U, lattice: L, at: y) }
                    let hh = 2 * L.spacing
                    let kxx = (Uat(x + Vec3(hh, 0, 0)) - 2 * Uat(x) + Uat(x - Vec3(hh, 0, 0))) / (hh * hh) * power
                    let kyy = (Uat(x + Vec3(0, hh, 0)) - 2 * Uat(x) + Uat(x - Vec3(0, hh, 0))) / (hh * hh) * power
                    let kzz = (Uat(x + Vec3(0, 0, hh)) - 2 * Uat(x) + Uat(x - Vec3(0, 0, hh))) / (hh * hh) * power
                    let gr = gradOn(L, U, x).map { $0 * power + Vec3(0, 0, weight) } ?? Vec3(0, 0, 0)
                    print(String(format: "      near-part balance at (%.3f, %.3f, %.3f) mm: residual %.1f µm, net force %.2f × weight, stiffness x %.2e y %.2e z %.2e N/m",
                                 (x.x - w0.x) * 1000, (x.y - w0.y) * 1000, (x.z - w0.z) * 1000, mv.residual * 1e6,
                                 gr.length / weight, kxx, kyy, kzz))
                }
                return mv.drives
            }
            return ForceCompiler.moveWell(fine, lattice: fb, gates: 6, particle: particle, drives: g, to: x,
                                          iterations: 6, balance: hold).drives
        }
        let pickDrive = placeFine(ForceCompiler.carryStep(tones, lattice: lat, gates: 6, particle: particle, wavelength: lam40,
                                                          options: o60, drives: r0.drives, to: w0, balance: hold), w0)
        let pickU = potentialFine(pickDrive)

        var push = [Double]()                          // max acoustic force on each placed bead afterwards, × weight
        var csv = "bead,t_s,x_mm,y_mm,z_mm\n"
        var t = 0.0
        var misses = 0
        print(String(format: "glass chamber, 10 tones, 4× holding drive (%.1f m/s rms); %d PLA beads Ø%.0f µm (%@), support %.1f mm below the pick-up",
                     (power / 60).squareRoot(), N, 2 * a * 1e6, shape, (w0.z - zs) * 1000))
        print(scatterOn ? "the part scatters: placed beads join the field (coupled monopoles + dipoles), 25 µm grid near the part"
                        : "the part is acoustically invisible (--no-scatter)")
        print("each bead: gentle load → carry (0.25 mm, 40 ms steps) → hover 0.15 mm up → closed-loop lowering (0.05 mm steps) → fuse on first touch")
        // The row's direction. Neighbours in an oscillating flow attract side by
        // side and repel end to end (G-S2), so with the part scattering, a row laid
        // along the local flow does not stay there — the first scattering build
        // grew along y by itself. After the first bead lands, the twin reads the
        // flow at it (Σ over tones of Re ∇p ∇pᴴ/ω², horizontal part) and lays the
        // row across it (`--row-dir x|y` forces one).
        var rowDir = Vec3(1, 0, 0)
        var flowNote = "row along x (fixed)"
        func chooseRowDirection(drive g: [[Complex]]) {
            if let i = args.firstIndex(of: "--row-dir"), i + 1 < args.count {
                rowDir = args[i + 1] == "y" ? Vec3(0, 1, 0) : Vec3(1, 0, 0)
                flowNote = "row along \(args[i + 1]) (forced)"
                return
            }
            guard scatterOn, let p0 = placed.first?.p else { return }
            var txx = 0.0, txy = 0.0, tyy = 0.0, tzz = 0.0
            for f in freqs.indices {
                let r = incidentRows(f, p0)
                var gp = [Complex.zero, .zero, .zero]
                for q in 0..<3 { for gi in 0..<6 { gp[q] += r.grad[q][gi] * g[f][gi] } }
                let w2 = pow(2 * Double.pi * freqs[f], 2)
                txx += gp[0].magnitudeSquared / w2; tyy += gp[1].magnitudeSquared / w2; tzz += gp[2].magnitudeSquared / w2
                txy += (gp[0] * gp[1].conjugate).re / w2
            }
            // Horizontal block's eigenvector with the SMALLER eigenvalue: least flow along it.
            let tr = txx + tyy, det = txx * tyy - txy * txy
            let lMin = tr / 2 - max(0, tr * tr / 4 - det).squareRoot()
            var d = abs(txy) > 1e-30 ? Vec3(txy, lMin - txx, 0) : (txx <= tyy ? Vec3(1, 0, 0) : Vec3(0, 1, 0))
            d = d * (1 / d.length)
            if d.x < 0 || (abs(d.x) < 1e-9 && d.y < 0) { d = d * -1 }
            rowDir = d
            let total = txx + tyy + tzz
            flowNote = String(format: "flow at the first bead: %.0f%% along x, %.0f%% along y, %.0f%% along z → row laid along (%.2f, %.2f)",
                              100 * txx / total, 100 * tyy / total, 100 * tzz / total, d.x, d.y)
        }
        // The weakest of a trap's three stiffnesses at x (N/m), from second differences
        // of P·U on the grid that holds x — a balance can sit on a saddle.
        func weakest(_ U: [Double], _ UN: [Double]?, _ x: Vec3) -> Double {
            let (L, V): (FieldLattice, [Double]) = {
                if let L = nearLat, let UN, inside(L, x, margin: 4) { return (L, UN) }
                return (fb, U)
            }()
            let hh = 2 * L.spacing
            func u(_ y: Vec3) -> Double { ForceCompiler.interpolate(V, lattice: L, at: y) }
            let c = u(x)
            return [Vec3(hh, 0, 0), Vec3(0, hh, 0), Vec3(0, 0, hh)]
                .map { (u(x + $0) - 2 * c + u(x - $0)) / (hh * hh) * power }.min()!
        }
        // Sites are laid off where the earlier beads actually came to rest.
        func siteFor(_ k: Int) -> Vec3 {
            let d = 2 * a + gapAim
            if shape == "tetra" && k == 2 {
                let p0 = placed[0].p, p1 = placed[1].p
                let mid = (p0 + p1) * 0.5, half = (p1 - p0).length / 2
                let side = Vec3(-(p1.y - p0.y), p1.x - p0.x, 0) * (1 / (2 * half))
                let off = max(0, d * d - half * half).squareRoot()
                return Vec3(mid.x + side.x * off, mid.y + side.y * off, zs + a)
            }
            if shape == "tetra" && k == 3 {
                let c = (placed[0].p + placed[1].p + placed[2].p) * (1.0 / 3)
                let rc = placed.prefix(3).reduce(0.0) { $0 + Vec3($1.p.x - c.x, $1.p.y - c.y, 0).length } / 3
                return Vec3(c.x, c.y, zs + a + max(0, d * d - rc * rc).squareRoot())
            }
            return k == 0 ? first : Vec3(placed[k - 1].p.x + rowDir.x * d, placed[k - 1].p.y + rowDir.y * d, zs + a)
        }
        // With the part in the field, a bead is not lowered straight onto a site
        // beside a neighbour: close in, the neighbour's scattering turns the trap
        // into a saddle (Koenig — attraction side by side, repulsion end to end
        // along the flow; `--debug` prints the stiffness). It lands `backOff`
        // behind its site, outside that reach, and is slid in along the support,
        // where the side-by-side attraction takes it the last micrometres.
        var backOff = scatterOn ? 0.6e-3 : 0             // 8 bead radii: outside the ~5-radius capture range
        if let i = args.firstIndex(of: "--backoff"), i + 1 < args.count, let v = Double(args[i + 1]) { backOff = v * 1e-3 }
        let muStatic = 0.02, muKinetic = 0.01           // a bead ROLLS on the support: rolling resistance ~1 % of the load
        for k in 0..<N {
            let site = siteFor(k)
            let stack = site.z > zs + a + 1e-6          // rests on beads, not the support
            var approach = site
            var slideDir = Vec3(0, 0, 0)
            if let nb = placed.min(by: { ($0.p - site).length < ($1.p - site).length }), !stack, backOff > 0 {
                // Slide in from where every bead it must touch pulls equally: away from
                // the one neighbour, or down the bisector of a notch between two (from one
                // side, the nearer bead captures it first and the notch stays open).
                let touching = placed.filter { ($0.p - site).length < 2 * a + 3 * gapAim }
                let centre = touching.count >= 2
                    ? touching.reduce(Vec3(0, 0, 0)) { $0 + $1.p } * (1 / Double(touching.count)) : nb.p
                var u = Vec3(site.x - centre.x, site.y - centre.y, 0)
                u = u * (1 / max(u.length, 1e-12))
                approach = site + u * backOff
                slideDir = u * -1
            }
            // A bead laid ON beads is dropped, not pushed: above its neighbours it sits end
            // to end with them along the (mostly vertical) flow, where they repel (G-S2) and
            // every trap within ~0.4 mm of the pocket is a saddle — and that repulsion
            // scales with the drive, so more power does not help; gravity does not. It
            // hovers 0.5 mm up, is centred, and falls the rest with the drive off.
            let hover = approach + Vec3(0, 0, stack ? 0.5e-3 : 0.15e-3)
            // Drives along the way: g[0] at the pick-up (force-balanced), then one per waypoint.
            // Each carries its potential on the fine box, on the near grid, and
            // its push on every placed bead.
            var drives: [[[Complex]]] = [pickDrive]
            var Us: [[Double]] = [potentialFine(pickDrive)]
            var UsNear: [[Double]] = nearLat.map { L in [ForceCompiler.potential(near, drives: pickDrive, gates: 6, particle: particle, count: L.count)] } ?? []
            var pushBy: [[Vec3]] = [pushes(pickDrive)]
            var aims: [Vec3] = [w0]
            func addDrive(to x: Vec3, withPart: Bool = true, carry: Double = 1, checkStable: Bool = true) {
                // Rivals over the whole probe volume on the chamber field (the part is a
                // negligible perturbation 17 mm out, and its near field does not fit a
                // 0.63 mm lattice); the balance then on the grid that resolves the part.
                func compile(from start: [[Complex]], iterations: Int) -> [[Complex]] {
                    placeFine(ForceCompiler.carryStep(tonesIn, lattice: lat, gates: 6, particle: particle, wavelength: lam40,
                                                      options: o60, drives: start, to: x, iterations: iterations, balance: hold), x,
                              withPart: withPart, carry: carry)
                }
                var g = compile(from: drives.last!, iterations: 60)
                // A trap whose balance sits on a saddle throws the bead (0.66 mm down the
                // tetrahedron's apex path, 3 mm at 110 mm/s): re-compile, longer and from the
                // pick-up drive, and keep the stiffest.
                if checkStable {
                    func score(_ g: [[Complex]]) -> Double {
                        weakest(potentialFine(g), nearLat.map { L in ForceCompiler.potential(near, drives: g, gates: 6, particle: particle, count: L.count) }, x)
                    }
                    var best = score(g)
                    if best <= 0 {
                        // Stiffen in place first (keeps the balance), then try fresh compiles.
                        let (L, T): (FieldLattice, [ForceCompiler.Tone]) = {
                            if withPart, let L = nearLat, inside(L, x, margin: 4) { return (L, near) }
                            return (fb, withPart ? fine : fineIn)
                        }()
                        let gs = ForceCompiler.stiffen(T, lattice: L, gates: 6, particle: particle, drives: g, at: x,
                                                       balance: hold * carry, step: 2 * L.spacing)
                        let ss = score(gs)
                        if ss > best { best = ss; g = gs }
                        for start in [drives.last!, pickDrive] where best <= 0 {
                            let g2 = compile(from: start, iterations: 150)
                            let s2 = score(g2)
                            if s2 > best { best = s2; g = g2 }
                        }
                        if args.contains("--debug") {
                            print(String(format: "      unstable trap at (%.3f, %.3f, %.3f) mm re-compiled: weakest stiffness now %.2e N/m",
                                         (x.x - w0.x) * 1000, (x.y - w0.y) * 1000, (x.z - w0.z) * 1000, best))
                        }
                    }
                }
                drives.append(g); Us.append(potentialFine(g)); aims.append(x)
                if let L = nearLat { UsNear.append(ForceCompiler.potential(near, drives: g, gates: 6, particle: particle, count: L.count)) }
                pushBy.append(pushes(g))
            }
            func waypoints(_ from: Vec3, _ to: Vec3, _ step: Double) -> [Vec3] {
                let d = to - from, m = max(1, Int((d.length / step).rounded(.up)))
                return (1...m).map { from + d * (Double($0) / Double(m)) }
            }
            // The bead and its integrator.
            var x = w0, v = Vec3(0, 0, 0)
            var fused: Placed? = nil
            var resting = false
            var recent: [Vec3] = []
            func run(from ia: Int, to ib: Int, duration: Double, drag: Double, ramp: Bool, released: Bool = false) {
                var tt = 0.0
                recent.removeAll()
                while tt < duration && fused == nil {
                    let cmd = ramp ? min(1, tt / duration) : 1
                    let wb = ia == ib ? 1 : max(0, cmd - tauU / duration * (1 - exp(-tt / tauU))), wa = 1 - wb
                    // Near the part, the 25 µm grid resolves its scattered near field.
                    var ga: Vec3? = nil, gb: Vec3? = nil
                    if let L = nearLat, let na = gradOn(L, UsNear[ia], x, margin: 2), let nb = gradOn(L, UsNear[ib], x, margin: 2) {
                        ga = na; gb = nb
                    } else { ga = gradU(Us[ia], x); gb = gradU(Us[ib], x) }
                    guard let ga, let gb else { return }
                    var force = (released ? Vec3(0, 0, 0) : (ga * wa + gb * wb) * (-power)) + Vec3(0, 0, -weight) - v * (gamma * drag)
                    // The support pushes back and holds by friction; it does not glue.
                    if x.z - a <= zs + 1e-7 && force.z < 0 {
                        let normal = -force.z
                        force = Vec3(force.x, force.y, 0)
                        if v.z < 0 { v = Vec3(v.x, v.y, 0) }
                        let vl = Vec3(v.x, v.y, 0), fl = Vec3(force.x, force.y, 0)
                        if vl.length < 1e-5 && fl.length <= muStatic * normal {
                            v = Vec3(0, 0, v.z); force = Vec3(0, 0, 0)
                        } else if vl.length >= 1e-5 {
                            force = force - vl * (muKinetic * normal / vl.length)
                        }
                    }
                    let vBefore = Vec3(v.x, v.y, 0)
                    v = v + force * (dt / mass)
                    // Kinetic friction stops a slide; it does not reverse it.
                    if x.z - a <= zs + 1e-7, v.x * vBefore.x + v.y * vBefore.y < 0 {
                        v = Vec3(0, 0, v.z)
                    }
                    x = x + v * dt
                    if x.z - a < zs { x = Vec3(x.x, x.y, zs + a); if v.z < 0 { v = Vec3(v.x, v.y, 0) } }
                    resting = x.z - a <= zs + 1e-6
                    tt += dt; t += dt
                    // The placed beads feel the field too — the chamber's and the other beads'.
                    for q in placed.indices where q < pushBy[ia].count && q < pushBy[ib].count {
                        push[q] = max(push[q], ((pushBy[ia][q] * wa + pushBy[ib][q] * wb) * power).length / weight)
                    }
                    // A placed bead: the binder coat grips on touch — as a liquid bridge
                    // first — and the machine releases the bead (drive off). For 0.15 s it
                    // stays in contact but settles under gravity along the beads it touches
                    // (joining any it meets) onto the support or into a pocket, heavily
                    // damped; then the bond cures where it lies. (Freezing it at first touch
                    // kept a snap's micrometre lift, and a row ratcheted up 1, 2, 4, 6 µm;
                    // settling with the trap still on, the trap — aimed up to 0.4 mm back —
                    // hauled it up its neighbour.)
                    if let j = placed.indices.first(where: { (x - placed[$0].p).length <= 2 * a }) {
                        var bonds = [j]
                        var xs = x, vs = v
                        func project() {
                            for _ in 0..<6 {
                                for q in bonds { let d = xs - placed[q].p; xs = placed[q].p + d * (2 * a / max(d.length, 1e-12)) }
                                if xs.z - a < zs { xs = Vec3(xs.x, xs.y, zs + a) }
                            }
                        }
                        project()
                        for _ in 0..<Int(0.15 / dt) {
                            let fs = Vec3(0, 0, -weight) - vs * (gamma * 50)
                            let prev = xs
                            vs = vs + fs * (dt / mass)
                            xs = xs + vs * dt
                            if let q = placed.indices.first(where: { !bonds.contains($0) && (xs - placed[$0].p).length < 2 * a }) {
                                bonds.append(q)
                            }
                            project()
                            vs = (xs - prev) * (1 / dt)
                            t += dt
                        }
                        x = xs; v = Vec3(0, 0, 0)
                        fused = Placed(p: xs, on: j, site: site)
                    }
                    if duration - tt < 0.02 { recent.append(x) }
                    if Int((t / 2e-3).rounded()) != Int(((t - dt) / 2e-3).rounded()) {
                        csv += String(format: "%d,%.4f,%.4f,%.4f,%.4f\n", k, t, (x.x - w0.x) * 1000,
                                      (x.y - w0.y) * 1000, (x.z - w0.z) * 1000)
                    }
                }
            }
            func mean(_ v: [Vec3]) -> Vec3 { v.isEmpty ? x : v.reduce(Vec3(0, 0, 0), +) * (1 / Double(v.count)) }
            // 1. Load gently at the pick-up.
            run(from: 0, to: 0, duration: 0.3, drag: 20, ramp: false)
            run(from: 0, to: 0, duration: 0.2, drag: 1, ramp: false)
            if args.contains("--debug") {
                print(String(format: "  bead %d loaded: (%+.3f, %+.3f, %+.3f) mm from the well, %.1f mm/s", k,
                             (x.x - w0.x) * 1000, (x.y - w0.y) * 1000, (x.z - w0.z) * 1000, v.length * 1000))
            }
            // 2. Carry across at pick-up height, then down to the hover point.
            // 80 ms per 0.25 mm step and a 50 ms settle: the traps are soft sideways
            // (y about a third as stiff as x), and at 40 ms a bead carried along y
            // swung ±0.3 mm and dropped into a shallow neighbouring well.
            for wp in waypoints(w0, Vec3(hover.x, hover.y, w0.z), 0.25e-3) + waypoints(Vec3(hover.x, hover.y, w0.z), hover, 0.25e-3) {
                addDrive(to: wp)
                run(from: drives.count - 2, to: drives.count - 1, duration: 2 * Tstep, drag: 1, ramp: true)
                run(from: drives.count - 1, to: drives.count - 1, duration: 0.05, drag: 1, ramp: false)
                if args.contains("--trace") {
                    print(String(format: "    carry: aim (%+.3f, %+.3f, %+.3f), bead (%+.3f, %+.3f, %+.3f) mm from the pick-up",
                                 (wp.x - w0.x) * 1000, (wp.y - w0.y) * 1000, (wp.z - w0.z) * 1000,
                                 (x.x - w0.x) * 1000, (x.y - w0.y) * 1000, (x.z - w0.z) * 1000))
                }
            }
            run(from: drives.count - 1, to: drives.count - 1, duration: 0.3, drag: 1, ramp: false)
            if args.contains("--debug") {
                print(String(format: "  bead %d at hover: (%+.3f, %+.3f, %+.3f) mm from the hover aim, %.1f mm/s", k,
                             (x.x - hover.x) * 1000, (x.y - hover.y) * 1000, (x.z - hover.z) * 1000, v.length * 1000))
            }
            // 3. Closed-loop lowering onto the support; a bead laid on beads is centred at the
            //    hover and dropped.
            var aim = aims.last!
            var zAim = hover.z
            var steps = 0
            if stack {
                for _ in 0..<3 {
                    let seen = mean(recent)
                    aim = Vec3(aim.x + 0.5 * (approach.x - seen.x), aim.y + 0.5 * (approach.y - seen.y), hover.z)
                    addDrive(to: aim)
                    run(from: drives.count - 2, to: drives.count - 1, duration: Tstep, drag: 1, ramp: true)
                    run(from: drives.count - 1, to: drives.count - 1, duration: 0.2, drag: 1, ramp: false)
                }
                if args.contains("--trace") {
                    print(String(format: "    drop from (%+.3f, %+.3f, %+.3f) mm off the pocket", (x.x - site.x) * 1000,
                                 (x.y - site.y) * 1000, (x.z - site.z) * 1000))
                }
                run(from: drives.count - 1, to: drives.count - 1, duration: 0.5, drag: 1, ramp: false, released: true)
                steps = 99
            }
            while fused == nil && !resting && zAim > approach.z - 0.5e-3 && steps < 20 {
                let seen = mean(recent)
                // Half the miss per step: a bead still swinging is not chased.
                aim = Vec3(aim.x + 0.5 * (approach.x - seen.x), aim.y + 0.5 * (approach.y - seen.y), zAim - 0.05e-3)
                zAim -= 0.05e-3
                addDrive(to: aim, withPart: !stack)
                run(from: drives.count - 2, to: drives.count - 1, duration: Tstep, drag: 1, ramp: true)
                if fused == nil { run(from: drives.count - 1, to: drives.count - 1, duration: 0.15, drag: 1, ramp: false) }
                steps += 1
                if args.contains("--trace") {
                    print(String(format: "    lower %d: aim (%+.3f, %+.3f, %+.3f), bead (%+.3f, %+.3f, %+.3f) mm from the site%@", steps,
                                 (aim.x - site.x) * 1000, (aim.y - site.y) * 1000, (aim.z - site.z) * 1000,
                                 (x.x - site.x) * 1000, (x.y - site.y) * 1000, (x.z - site.z) * 1000,
                                 fused != nil ? " — gripped" : (resting ? " — on the support" : "")))
                }
            }
            // 4. Slide in along the support: to the site and 30 µm past it, 20 µm a step.
            if fused == nil && resting && slideDir.length > 0 {
                var sOff = 0.0
                while fused == nil && sOff < backOff + 30e-6 {
                    sOff += 20e-6
                    let tgt = approach + slideDir * sOff
                    // The trap carries 90 % of the weight: the bead rolls, pressed lightly on the support.
                    addDrive(to: Vec3(tgt.x, tgt.y, site.z), withPart: false, carry: 0.9, checkStable: false)
                    run(from: drives.count - 2, to: drives.count - 1, duration: Tstep, drag: 1, ramp: true)
                    if fused == nil { run(from: drives.count - 1, to: drives.count - 1, duration: 0.1, drag: 1, ramp: false) }
                    if args.contains("--trace") {
                        print(String(format: "    slide %.0f µm: aim (%+.3f, %+.3f), bead (%+.3f, %+.3f, %+.3f) mm from the site%@", sOff * 1e6,
                                     (tgt.x - site.x) * 1000, (tgt.y - site.y) * 1000,
                                     (x.x - site.x) * 1000, (x.y - site.y) * 1000, (x.z - site.z) * 1000,
                                     fused != nil ? " — gripped" : ""))
                    }
                }
            }
            // 5. Cure: a bead resting on the support that touched no bead is fixed where it lies.
            if fused == nil && resting { fused = Placed(p: Vec3(x.x, x.y, zs + a), on: -1, site: site) }
            if let f = fused {
                placed.append(f); push.append(0)
                if k == 0 {
                    chooseRowDirection(drive: drives.last!)
                    // A tetrahedron's apex bead comes down a column 0.6 mm out along the
                    // notch's bisector — which can be untrappable (with the base along x it
                    // was: a saddle in y all the way down). Before committing, compile test
                    // traps at eight heights down both candidate columns on the chamber field
                    // and keep the orientation with more trappable heights (then the larger
                    // median stiffness). A lone saddle just above the support is not fatal —
                    // the lowering and the slide handle it — a column of them is.
                    if shape == "tetra" && !args.contains("--row-dir") {
                        func column(_ dir: Vec3) -> (stable: Int, median: Double) {
                            let d = 2 * a + gapAim
                            let p0 = placed[0].p, p1 = p0 + dir * d
                            let perp = Vec3(-dir.y, dir.x, 0)
                            let apex = (p0 + p1) * 0.5 + perp * (d * 3.0.squareRoot() / 2)
                            let top = apex + perp * backOff
                            var ks: [Double] = []
                            var g = pickDrive
                            for q in 0..<8 {
                                let pt = Vec3(top.x, top.y, zs + a + 1.55e-3 - Double(q) * 0.2e-3)
                                g = placeFine(ForceCompiler.carryStep(tonesIn, lattice: lat, gates: 6, particle: particle,
                                                                      wavelength: lam40, options: o60, drives: g,
                                                                      to: pt, balance: hold), pt, withPart: false)
                                ks.append(weakest(potentialFine(g), nil, pt))
                            }
                            return (ks.filter { $0 > 0 }.count, ks.sorted()[ks.count / 2])
                        }
                        let alt = Vec3(-rowDir.y, rowDir.x, 0)
                        let cA = column(rowDir), cB = column(alt)
                        if cB.stable > cA.stable || (cB.stable == cA.stable && cB.median > cA.median) { rowDir = alt }
                        flowNote += String(format: "; apex columns trappable at %d/8 vs %d/8 heights → base along (%.2f, %.2f)",
                                           cA.stable, cB.stable, rowDir.x, rowDir.y)
                    }
                    print("  " + flowNote)
                }
                try updatePart()                          // the part grows into the field
            } else {
                misses += 1
                print(String(format: "  bead %d: not placed (at %.2f, %.2f, %.2f mm from the pick-up)", k,
                             (x.x - w0.x) * 1000, (x.y - w0.y) * 1000, (x.z - w0.z) * 1000))
                break
            }
        }
        print("bead   site (µm from the first site)   placed at             miss      fixed by          gaps to the beads it rests against   pushed afterwards")
        var gaps: [Double] = []
        var touching: [Int] = []
        for (k, b) in placed.enumerated() {
            let rel = (b.p - first) * 1e6, srel = (b.site - first) * 1e6
            let miss = (b.p - b.site).length * 1e6
            // Its neighbours: earlier beads it rests against (gap under 0.1 mm).
            let near = placed.prefix(k).map { ($0.p - b.p).length - 2 * a }.filter { $0 < 0.1e-3 }
            gaps += near
            touching.append(near.filter { abs($0) < 30e-6 }.count)
            let gapText = near.isEmpty ? "—" : near.map { String(format: "%.1f", $0 * 1e6) }.joined(separator: ", ") + " µm"
            print(String(format: "%3d    (%6.1f, %6.1f, %5.1f)        (%6.1f, %6.1f, %5.1f)  %5.1f µm  %@  %@  %@",
                         k, srel.x, srel.y, srel.z, rel.x, rel.y, rel.z, miss,
                         (b.on < 0 ? "cured on support" : String(format: "gripped bead %d ", b.on)) as NSString,
                         gapText.padding(toLength: 36, withPad: " ", startingAt: 0) as NSString,
                         k == placed.count - 1 ? "—" : String(format: "%.2f × weight", push[k])))
        }
        let worstGap = gaps.map(abs).max() ?? 0
        let worstPush = push.dropLast().max() ?? 0
        let ok: Bool
        let gate: GateResult
        if shape == "tetra" {
            // Three on the support touching one another; the fourth touching all three.
            let base = placed.prefix(3).allSatisfy { abs($0.p.z - (zs + a)) < 5e-6 }
            ok = misses == 0 && placed.count == 4 && base && touching.count == 4
                && touching[1] == 1 && touching[2] == 2 && touching[3] == 3 && worstGap < 30e-6
            gate = GateResult(id: "G-B2", name: "a tetrahedron: three PLA beads touching on the support, a fourth resting on all three",
                              measured: ok ? 1 : 0, threshold: 0.5, comparison: .greaterThan,
                              detail: String(format: "%d/4 placed; base on the support: %@; top touches %d of 3; worst gap %.1f µm; placed beads pushed ≤ %.2f × weight",
                                             placed.count, base ? "yes" : "no", touching.count == 4 ? touching[3] : 0,
                                             worstGap * 1e6, worstPush))
        } else {
            let onSupport = placed.filter { abs($0.p.z - (zs + a)) < 5e-6 }.count
            ok = misses == 0 && onSupport == N && worstGap < 30e-6
            gate = GateResult(id: "G-B1", name: "first build: \(N) PLA beads in a row on the support, touching (|gap| < 30 µm), none lost or perched",
                              measured: ok ? 1 : 0, threshold: 0.5, comparison: .greaterThan,
                              detail: String(format: "%d/%d placed on the support; worst gap %.1f µm; placed beads pushed ≤ %.2f × weight afterwards",
                                             onSupport, N, worstGap * 1e6, worstPush))
        }
        print(gate.line)
        print(String(format: "build time %.1f s (simulated); (%.1fs)", t, Date().timeIntervalSince(t0)))
        if args.contains("--receipt") {
            let tag = shape == "row" ? "" : "_" + shape
            writeReceipt(Receipt(name: shape == "row" ? "build" : "build-" + shape, gates: [gate],
                                 durationSeconds: Date().timeIntervalSince(t0), device: deviceName(), gitSHA: gitSHA()))
            var fin = "bead,x_mm,y_mm,z_mm,site_x_mm,site_y_mm,on\n"
            for (k, b) in placed.enumerated() {
                fin += String(format: "%d,%.4f,%.4f,%.4f,%.4f,%.4f,%d\n", k, (b.p.x - w0.x) * 1000, (b.p.y - w0.y) * 1000,
                              (b.p.z - w0.z) * 1000, (b.site.x - w0.x) * 1000, (b.site.y - w0.y) * 1000, b.on)
            }
            try? csv.write(toFile: "Receipts/build\(tag)_trajectories.csv", atomically: true, encoding: .utf8)
            try? fin.write(toFile: "Receipts/build\(tag)_placed.csv", atomically: true, encoding: .utf8)
        }
        exit(ok ? 0 : 1)
    } catch { print("GPU unavailable: \(error)"); exit(2) }

case "fly":
    // A bead that moves. A 200 µm PLA bead is integrated through the carry
    // sequence of `fieldc carry` — time-averaged Gor'kov force (the acoustic
    // period, 25 µs, is far below the bead's ~0.1 s trap period), gravity and
    // Stokes drag (streaming ignored) — with the drive at twice the power
    // that holds it at the pick-up. A drive switch reaches the bead over the
    // chamber's settling time (air absorption plus plate loss), modelled as an
    // exponential cross-fade of the potential. The question: how fast can the
    // machine carry before the bead is left behind?
    do {
        let ctx = try MetalContext()
        let t0 = Date()
        let air = RH1Freestanding.roomAir
        let design = RH1Design()
        let L = design.buildChamberHeight * 0.001
        let lam40 = air.wavelength(at: 40_000)
        let x0 = Vec3(0, 0, L / 2)
        let freqs = (0..<10).map { 30_000 + 40_000 * (Double($0) + 0.5) / 10 }
        let cav = RH1Freestanding.chamber(maxGamma: {
            let k = air.wavenumber(at: 70_000), e = log(1e4) / 0.05
            return (k * k + e * e).squareRoot() }())
        let h = air.wavelength(at: freqs.max()!) / 8
        let n = Int((2 * 2 * lam40 / h).rounded()) | 1
        let half = Double(n - 1) / 2 * h
        let lat = FieldLattice(origin: x0 - Vec3(half, half, half), spacing: h, nx: n, ny: n, nz: n)
        let zMin = max(0.05, min(lat.origin.z, L - (lat.origin.z + Double(n - 1) * h)))
        var o = ForceCompiler.Options()
        o.shellSteps = max(2, Int((air.wavelength(at: 50_000) / 4 / h).rounded()))
        let particle = ParticleMaterial.pla()
        var sources: [CylinderCavity.Source] = []
        var tones: [ForceCompiler.Tone] = []
        var base: [[Complex]] = []
        for f in freqs {
            var op = RH1Freestanding.Options()
            op.frequency = f; op.medium = air; op.slotSegment = max(2e-3, air.wavelength(at: f) / 4)
            let (p, c) = RH1Freestanding.preset(op)
            let src = cav.source(elements: p.elements, coupling: c, gateCount: p.gateCount,
                                 frequency: f, medium: air, zMin: zMin)
            sources.append(src)
            tones.append(ForceCompiler.Tone(frequency: f, medium: air,
                                            rows: try CavityFieldsGPU.build(ctx: ctx, cavity: cav, source: src,
                                                                            points: lat.positions, withGradient: true)))
            let prop = Propagator(elements: p.elements, lattice: FieldLattice(origin: .zero, spacing: 1, nx: 1, ny: 1, nz: 1),
                                  frequency: f, medium: air, gateCount: p.gateCount, elementCoupling: c,
                                  cavity: cav, cavitySource: src)
            let u = InverseSolver.solve(propagator: prop, points: [.init(position: x0)],
                                        method: .gspat, iterations: 80, trap: .twinTrap)
            base.append(u.map { $0 * (1 / (u.l2 * Double(freqs.count).squareRoot())) })
        }
        // The carry sequence (as `fieldc carry`).
        let c0 = ((n - 1) / 2, (n - 1) / 2, (n - 1) / 2)
        let r0 = ForceCompiler.compile(tones, lattice: lat, gates: 6, particle: particle, wavelength: lam40,
                                       options: o, starts: [base], target: c0)
        guard let w0 = r0.targetWell else { print("no trap at the start"); exit(1) }
        let stepLen = 0.25e-3
        var path: [Vec3] = [w0]
        for k in 1...20 { path.append(w0 + Vec3(0, 0, Double(k) * stepLen)) }
        for k in 1...20 { path.append(w0 + Vec3(Double(k) * stepLen, 0, 20 * stepLen)) }
        var drives: [[[Complex]]] = [r0.drives]
        for x in path.dropFirst() {
            drives.append(ForceCompiler.carryStep(tones, lattice: lat, gates: 6, particle: particle, wavelength: lam40,
                                                  options: o, drives: drives.last!, to: x))
        }
        // A fine box around the path, 0.1 mm, where the bead can go.
        let margin = 3e-3, fs = 0.1e-3
        let lo = Vec3(path.map(\.x).min()! - margin, path.map(\.y).min()! - margin, path.map(\.z).min()! - margin)
        let hi = Vec3(path.map(\.x).max()! + margin, path.map(\.y).max()! + margin, path.map(\.z).max()! + margin)
        let fb = FieldLattice(origin: lo, spacing: fs, nx: Int(((hi.x - lo.x) / fs).rounded()) + 1,
                              ny: Int(((hi.y - lo.y) / fs).rounded()) + 1, nz: Int(((hi.z - lo.z) / fs).rounded()) + 1)
        let fine = try zip(freqs, sources).map { f, src in
            ForceCompiler.Tone(frequency: f, medium: air,
                               rows: try CavityFieldsGPU.build(ctx: ctx, cavity: cav, source: src,
                                                               points: fb.positions, withGradient: true))
        }
        let Us = drives.map { ForceCompiler.potential(fine, drives: $0, gates: 6, particle: particle, count: fb.count) }
        // ∇U at x: central differences on the fine box, trilinear between nodes.
        func gradU(_ U: [Double], _ x: Vec3) -> Vec3? {
            let f = (x - fb.origin) / fs
            let i0 = Int(f.x.rounded(.down)), j0 = Int(f.y.rounded(.down)), k0 = Int(f.z.rounded(.down))
            guard i0 >= 1, j0 >= 1, k0 >= 1, i0 + 2 < fb.nx, j0 + 2 < fb.ny, k0 + 2 < fb.nz else { return nil }
            let tx = f.x - Double(i0), ty = f.y - Double(j0), tz = f.z - Double(k0)
            var gsum = Vec3(0, 0, 0)
            for (dk, wz) in [(0, 1 - tz), (1, tz)] { for (dj, wy) in [(0, 1 - ty), (1, ty)] { for (di, wx) in [(0, 1 - tx), (1, tx)] {
                let i = i0 + di, j = j0 + dj, k = k0 + dk
                let gx = (U[fb.index(i + 1, j, k)] - U[fb.index(i - 1, j, k)]) / (2 * fs)
                let gy = (U[fb.index(i, j + 1, k)] - U[fb.index(i, j - 1, k)]) / (2 * fs)
                let gz = (U[fb.index(i, j, k + 1)] - U[fb.index(i, j, k - 1)]) / (2 * fs)
                gsum = gsum + Vec3(gx, gy, gz) * (wx * wy * wz)
            } } }
            return gsum
        }
        // Power: twice what holds the bead at the pick-up.
        let mass = particle.mass(), g0 = 9.81
        var fUp = 0.0
        for q in -15...15 {
            if let gr = gradU(Us[0], w0 + Vec3(0, 0, Double(q) * fs)) { fUp = max(fUp, -gr.z) }
        }
        guard fUp > 0 else { print("the pick-up well pushes nowhere upward"); exit(1) }
        let power = 2 * mass * g0 / fUp
        // Lift margin along the path: each step's strongest upward force at
        // this drive, over the weight (< 1: the bead falls, however slow).
        var margins: [Double] = []
        for (i, U) in Us.enumerated() {
            var up = 0.0
            for q in -15...15 {
                if let gr = gradU(U, path[i] + Vec3(0, 0, Double(q) * fs)) { up = max(up, -gr.z) }
            }
            margins.append(up * power / (mass * g0))
        }
        let weakest = margins.indices.min { margins[$0] < margins[$1] }!
        print(String(format: "lift margin along the path: min %.2f at step %d, median %.2f",
                     margins[weakest], weakest, margins.sorted()[margins.count / 2]))
        let muAir = 1.81e-5, gamma = 6 * Double.pi * muAir * particle.radius
        // Settling of the potential: field amplitude decays at α c + (−ln R) c / L; U ∝ amplitude².
        let alpha = air.absorption(at: 50_000)
        let tauU = 0.5 / (alpha * air.soundSpeed + -log(0.9) * air.soundSpeed / L)
        print(String(format: "glass chamber, 10 tones; carry 5 mm up + 5 mm across in 0.25 mm steps; 200 µm PLA, drive = 2 × holding (%.1f m/s rms)",
                     (power / 60).squareRoot()))
        print(String(format: "bead: m %.2e kg, drag %.2e kg/s (1/e in %.0f ms); potential settles with τ = %.1f ms",
                     mass, gamma, mass / gamma * 1000, tauU * 1000))
        print("each step ramps the potential linearly from the old drive to the new (cross terms ignored), on top of the settling τ;")
        print("the bead is loaded gently (20× drag for 0.3 s), then released to air drag")
        print("drive × holding   step time   carry time   worst lag   at the end   result")
        var gates: [GateResult] = []
        var csv = "power_x,step_ms,t_s,x_mm,y_mm,z_mm,well_x_mm,well_y_mm,well_z_mm\n"
        var anyCarried = false
        for mult in [2.0, 4.0, 8.0] {
            let P = power * mult / 2
            for Tstep in [0.01, 0.02, 0.04, 0.08] {
                var x = w0, v = Vec3(0, 0, 0)
                var t = 0.0
                let dt = 1e-4
                var worst = 0.0, escaped = false
                var record: String? = (mult == 4 && Tstep == 0.04) ? "" : nil
                // Potential as a blend of step potentials: `from` → `to`, a linear
                // command ramp over the step, followed by the chamber's settling.
                func step(from a: Int, to b: Int, duration: Double, drag: Double, ramp: Bool) {
                    var tt = 0.0
                    while tt < duration && !escaped {
                        let cmd = ramp ? min(1, tt / duration) : 1
                        let lagged = max(0, cmd - tauU / duration * (1 - exp(-tt / tauU)))
                        let wb = a == b ? 1 : lagged, wa = 1 - wb
                        guard let ga = gradU(Us[a], x), let gb = gradU(Us[b], x) else { escaped = true; return }
                        let gr = ga * wa + gb * wb
                        let force = gr * (-P) + Vec3(0, 0, -mass * g0) - v * (gamma * drag)
                        v = v + force * (dt / mass)
                        x = x + v * dt
                        tt += dt; t += dt
                        if a != b { worst = max(worst, (x - path[b]).length) }
                        if record != nil, Int((t / 1e-3).rounded()) != Int(((t - dt) / 1e-3).rounded()) {
                            record! += String(format: "%.0f,%.0f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n", mult, Tstep * 1000, t,
                                              (x.x - w0.x) * 1000, (x.y - w0.y) * 1000, (x.z - w0.z) * 1000,
                                              (path[b].x - w0.x) * 1000, (path[b].y - w0.y) * 1000, (path[b].z - w0.z) * 1000)
                        }
                    }
                }
                step(from: 0, to: 0, duration: 0.3, drag: 20, ramp: false)   // gentle loading
                step(from: 0, to: 0, duration: 0.2, drag: 1, ramp: false)
                for i in 1..<drives.count where !escaped { step(from: i - 1, to: i, duration: Tstep, drag: 1, ramp: true) }
                if !escaped { step(from: drives.count - 1, to: drives.count - 1, duration: 0.4, drag: 1, ramp: false) }
                let end = (x - path.last!).length
                let carried = !escaped && end < 0.5e-3
                if carried { anyCarried = true }
                print(String(format: "      %3.0f×          %4.0f ms     %5.2f s      %5.2f mm     %5.2f mm     %@",
                             mult, Tstep * 1000, Tstep * Double(drives.count - 1), worst * 1000,
                             escaped ? .nan : end * 1000,
                             escaped ? "escaped the trap" : (carried ? "carried" : "left behind")))
                gates.append(GateResult(id: "FLY", name: String(format: "%.0f× holding drive, %.0f ms per 0.25 mm step", mult, Tstep * 1000),
                                        measured: escaped ? .infinity : end, threshold: 0.5e-3, comparison: .informational,
                                        detail: String(format: "worst lag %.2f mm, %@", worst * 1000,
                                                       escaped ? "escaped" : (carried ? "carried" : "left behind"))))
                if let r = record { csv += r }
            }
        }
        let g2 = GateResult(id: "G-P2", name: "a 200 µm PLA bead, integrated through the fields, rides the carry 5 mm up and 5 mm across",
                            measured: anyCarried ? 1 : 0, threshold: 0.5, comparison: .greaterThan,
                            detail: "at least one drive level and step time carries it to within 0.5 mm of the drop-off")
        print(g2.line)
        gates.append(g2)
        print(String(format: "(%.1fs)", Date().timeIntervalSince(t0)))
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "fly", gates: gates, durationSeconds: Date().timeIntervalSince(t0),
                                 device: deviceName(), gitSHA: gitSHA()))
            try? csv.write(toFile: "Receipts/fly_trajectory_4x_40ms.csv", atomically: true, encoding: .utf8)
        }
    } catch { print("GPU unavailable: \(error)"); exit(2) }

case "carry":
    // Pick up, carry, place: move a force-compiled trap in the glass chamber
    // 8 lattice steps up and 8 across (~5 mm each), re-compiling at every
    // step from the last drive. A bead is carried only if, at each step, the
    // trap is unique, sits on its point, and the new potential runs downhill
    // from the old well to the new one — no barrier for the bead to stall
    // behind, no sibling for it to fall into. (Drives switch step to step;
    // cross-fades and timing are the next layer.)
    do {
        let ctx = try MetalContext()
        let t0 = Date()
        let air = RH1Freestanding.roomAir
        let design = RH1Design()
        let L = design.buildChamberHeight * 0.001
        let lam40 = air.wavelength(at: 40_000)
        let x0 = Vec3(0, 0, L / 2)
        let freqs = (0..<10).map { 30_000 + 40_000 * (Double($0) + 0.5) / 10 }
        let cav = RH1Freestanding.chamber(maxGamma: {
            let k = air.wavenumber(at: 70_000), e = log(1e4) / 0.05
            return (k * k + e * e).squareRoot() }())
        let h = air.wavelength(at: freqs.max()!) / 8
        let n = Int((2 * 2 * lam40 / h).rounded()) | 1
        let half = Double(n - 1) / 2 * h
        let lat = FieldLattice(origin: x0 - Vec3(half, half, half), spacing: h, nx: n, ny: n, nz: n)
        let zMin = max(0.05, min(lat.origin.z, L - (lat.origin.z + Double(n - 1) * h)))
        var o = ForceCompiler.Options()
        o.shellSteps = max(2, Int((air.wavelength(at: 50_000) / 4 / h).rounded()))
        let particle = ParticleMaterial.pla()
        var tones: [ForceCompiler.Tone] = []
        var base: [[Complex]] = []
        for f in freqs {
            var op = RH1Freestanding.Options()
            op.frequency = f; op.medium = air; op.slotSegment = max(2e-3, air.wavelength(at: f) / 4)
            let (p, c) = RH1Freestanding.preset(op)
            let src = cav.source(elements: p.elements, coupling: c, gateCount: p.gateCount,
                                 frequency: f, medium: air, zMin: zMin)
            tones.append(ForceCompiler.Tone(frequency: f, medium: air,
                                            rows: try CavityFieldsGPU.build(ctx: ctx, cavity: cav, source: src,
                                                                            points: lat.positions, withGradient: true)))
            let prop = Propagator(elements: p.elements, lattice: FieldLattice(origin: .zero, spacing: 1, nx: 1, ny: 1, nz: 1),
                                  frequency: f, medium: air, gateCount: p.gateCount, elementCoupling: c,
                                  cavity: cav, cavitySource: src)
            let u = InverseSolver.solve(propagator: prop, points: [.init(position: x0)],
                                        method: .gspat, iterations: 80, trap: .twinTrap)
            base.append(u.map { $0 * (1 / (u.l2 * Double(freqs.count).squareRoot())) })
        }
        // Pick up: the unique trap at the centre.
        let c0 = ((n - 1) / 2, (n - 1) / 2, (n - 1) / 2)
        let r0 = ForceCompiler.compile(tones, lattice: lat, gates: 6, particle: particle, wavelength: lam40,
                                       options: o, starts: [base], target: c0)
        guard let w0 = r0.targetWell else { print("no trap at the start"); exit(1) }
        // Carry: 5 mm up, then 5 mm across, in 0.25 mm steps between lattice
        // points, each a minimal drive change that puts the well on the point.
        let stepLen = 0.25e-3
        var path: [Vec3] = [w0]
        for k in 1...20 { path.append(w0 + Vec3(0, 0, Double(k) * stepLen)) }
        for k in 1...20 { path.append(w0 + Vec3(Double(k) * stepLen, 0, 20 * stepLen)) }
        print(String(format: "glass chamber, bare; 10 tones 32–68 kHz; lattice %.2f mm, path steps 0.25 mm; 200 µm PLA", h * 1000))
        print(String(format: "picked up: sibling ratio %.2f (%d), well %.2f mm from the centre", r0.siblingRatio,
                     r0.siblings, r0.targetOffset * 1000))
        print("step  target (mm from pick-up)   well off target   moved     ratio (siblings)   depth vs start   old well → new: downhill?")
        var g = r0.drives
        var prevWell = w0
        let depth0 = r0.targetDepth
        var ok = true, worstRatio = 0.0, worstOff = 0.0, notUnique = 0, minDepth = Double.infinity
        for (i, x) in path.enumerated() where i > 0 {
            g = ForceCompiler.carryStep(tones, lattice: lat, gates: 6, particle: particle, wavelength: lam40,
                                        options: o, drives: g, to: x)
            let r = ForceCompiler.evaluate(tones, drives: g, lattice: lat, target: x, gates: 6,
                                           particle: particle, options: o, wavelength: lam40)
            // Downhill from the old well to the new one under the new drive.
            let U = ForceCompiler.potential(tones, drives: g, gates: 6, particle: particle, count: lat.count)
            let wNew = r.targetWell ?? x
            var rise = 0.0, last = ForceCompiler.interpolate(U, lattice: lat, at: prevWell)
            for q in 1...10 {
                let u = ForceCompiler.interpolate(U, lattice: lat, at: prevWell + (wNew - prevWell) * (Double(q) / 10))
                rise = max(rise, u - last)
                last = u
            }
            let barrier = rise / max(r.targetDepth, 1e-300)
            // Carried = on the point, a continuous move, downhill from the old
            // well, still the deepest well, and at least half the starting depth.
            // (Global uniqueness, ratio < 0.5, is the LOADING criterion — a bead
            // already in its well cares about its own well and the path.)
            let moved = (wNew - prevWell).length
            let fine = r.targetOffset < 0.25e-3 && moved < 2 * stepLen && barrier <= 0.05
                && r.siblingRatio < 1 && r.targetDepth >= 0.5 * depth0
            if !fine { ok = false }
            if r.siblingRatio >= 0.5 { notUnique += 1 }
            worstRatio = max(worstRatio, r.siblingRatio); worstOff = max(worstOff, r.targetOffset)
            minDepth = min(minDepth, r.targetDepth / max(depth0, 1e-300))
            if i % 4 == 0 || !fine {
                let d = x - w0
                print(String(format: "%3d   (%5.2f, %5.2f, %5.2f)        %5.2f mm         %4.2f mm   %5.2f (%3d)      %5.2f            %@",
                             i, d.x * 1000, d.y * 1000, d.z * 1000, r.targetOffset * 1000,
                             (wNew - prevWell).length * 1000, r.siblingRatio, r.siblings,
                             r.targetDepth / max(depth0, 1e-300),
                             barrier <= 0.05 ? "yes" : String(format: "barrier %.0f%% of depth", barrier * 100)))
            }
            prevWell = wNew
        }
        print(String(format: "worst offset %.2f mm · shallowest %.2f of the start · worst sibling ratio %.2f (%d of %d steps ≥ 0.5)",
                     worstOff * 1000, minDepth, worstRatio, notUnique, path.count - 1))
        let gate = GateResult(id: "G-P1", name: "bead carried 5 mm up and 5 mm across the glass chamber: on the point, continuous, downhill, still the deepest well",
                           measured: ok ? 1 : 0, threshold: 0.5, comparison: .greaterThan,
                           detail: String(format: "%d steps of 0.25 mm, 10 tones; worst offset %.2f mm, shallowest %.2f; sibling ratio worst %.2f, %d steps ≥ 0.5",
                                          path.count - 1, worstOff * 1000, minDepth, worstRatio, notUnique))
        print(gate.line)
        print(String(format: "(%.1fs)", Date().timeIntervalSince(t0)))
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "carry", gates: [gate], durationSeconds: Date().timeIntervalSince(t0),
                                 device: deviceName(), gitSHA: gitSHA()))
        }
        exit(ok ? 0 : 1)
    } catch { print("GPU unavailable: \(error)"); exit(2) }

case "levitate":
    // How hard must the plates drive to hold a bead against gravity?
    // The twin's rows are Rayleigh/modal pressure per unit aperture velocity
    // (Pa per m/s), so a gate drive g is the velocity amplitude of an
    // aperture whose horn coupling is 1. Compile the unique trap, read the
    // largest upward force its well offers per unit drive power along a
    // fine vertical line through it, and scale the power until that force
    // carries the bead's weight. The Gor'kov force and the weight both go
    // as a³, so in the Rayleigh limit the answer depends on the material,
    // not the size. MODEL numbers: the horn coupling is a stub.
    do {
        let ctx = try MetalContext()
        let t0 = Date()
        let air = RH1Freestanding.roomAir
        let design = RH1Design()
        let L = design.buildChamberHeight * 0.001
        let lam40 = air.wavelength(at: 40_000)
        let x0 = Vec3(0, 0, L / 2)
        let grid5 = [30_000.0, 40_000, 50_000, 60_000, 70_000]
        let spread10 = (0..<10).map { 30_000 + 40_000 * (Double($0) + 0.5) / 10 }
        let cav = RH1Freestanding.chamber(maxGamma: {
            let k = air.wavenumber(at: 70_000), e = log(1e4) / 0.05
            return (k * k + e * e).squareRoot() }())
        let plateWalls = RH1Freestanding.walls()
        let cases: [(String, Bool, [Double])] = [
            ("plates only (image model), 5-tone chord 30–70 kHz", false, grid5),
            ("glass chamber, 5-tone chord 30–70 kHz", true, grid5),
            ("glass chamber, 10 tones 32–68 kHz", true, spread10),
        ]
        let beads: [(String, ParticleMaterial)] = [
            ("PLA Ø200 µm", .pla()),
            ("aluminium Ø200 µm", ParticleMaterial(density: 2700, soundSpeed: 6320, radius: 100e-6)),
            ("steel Ø200 µm", ParticleMaterial(density: 7850, soundSpeed: 5900, radius: 100e-6)),
        ]
        func machine(_ f: Double) -> (MachinePreset, [Complex]) {
            var o = RH1Freestanding.Options()
            o.frequency = f; o.medium = air; o.slotSegment = max(2e-3, air.wavelength(at: f) / 4)
            return RH1Freestanding.preset(o)
        }
        func rows(_ f: Double, glass: Bool, points: [Vec3], zMin: Double) throws -> [Complex] {
            let (p, c) = machine(f)
            if glass {
                let src = cav.source(elements: p.elements, coupling: c, gateCount: p.gateCount,
                                     frequency: f, medium: air, zMin: zMin)
                return try CavityFieldsGPU.build(ctx: ctx, cavity: cav, source: src, points: points, withGradient: true)
            }
            return try PortFieldsGPU.buildWithGradient(ctx: ctx, elements: p.elements, coupling: c, walls: plateWalls,
                                                       points: points, frequency: f, medium: air, gateCount: p.gateCount)
        }
        func dB(_ pAmp: Double) -> Double { 20 * log10(pAmp / 2.squareRoot() / 20e-6) }
        var gates: [GateResult] = []
        print("drive = velocity amplitude of an aperture at horn coupling 1 (m/s); plane-wave level ρ0c·u in brackets")
        print("MODEL numbers — the horn coupling is a stub; bench G-A0 decides the real throat → aperture gain")
        for (label, glass, freqs) in cases {
            let h = air.wavelength(at: freqs.max()!) / 8
            let n = Int((2 * 2 * lam40 / h).rounded()) | 1
            let half = Double(n - 1) / 2 * h
            let lat = FieldLattice(origin: x0 - Vec3(half, half, half), spacing: h, nx: n, ny: n, nz: n)
            let zMin = max(0.05, min(lat.origin.z, L - (lat.origin.z + Double(n - 1) * h)))
            var o = ForceCompiler.Options()
            o.shellSteps = max(2, Int((air.wavelength(at: 50_000) / 4 / h).rounded()))
            let tones = try freqs.map { f in
                ForceCompiler.Tone(frequency: f, medium: air, rows: try rows(f, glass: glass, points: lat.positions, zMin: zMin))
            }
            // GS-PAT chord as a start (as forcetrap and tonesweep do).
            let base: [[Complex]] = try freqs.map { f in
                let (p, c) = machine(f)
                let one = FieldLattice(origin: .zero, spacing: 1, nx: 1, ny: 1, nz: 1)
                let prop: Propagator
                if glass {
                    let src = cav.source(elements: p.elements, coupling: c, gateCount: p.gateCount,
                                         frequency: f, medium: air, zMin: zMin)
                    prop = Propagator(elements: p.elements, lattice: one, frequency: f, medium: air,
                                      gateCount: p.gateCount, elementCoupling: c, cavity: cav, cavitySource: src)
                } else {
                    prop = try PortFieldsGPU.propagator(ctx: ctx, elements: p.elements, coupling: c, walls: plateWalls,
                                                        lattice: one, frequency: f, medium: air, gateCount: p.gateCount)
                }
                let u = InverseSolver.solve(propagator: prop, points: [.init(position: x0)],
                                            method: .gspat, iterations: 80, trap: .twinTrap)
                return u.map { $0 * (1 / (u.l2 * Double(freqs.count).squareRoot())) }
            }
            // Compile for the PLA bead (f1, f2 differ little between solids).
            let r = ForceCompiler.compile(tones, lattice: lat, gates: 6, particle: .pla(), wavelength: lam40,
                                          options: o, starts: [base])
            print(String(format: "\n%@: sibling ratio %.2f (%d), well %.1f mm from the point", label,
                         r.siblingRatio, r.siblings, r.targetOffset * 1000))
            guard let w = r.targetWell else { print("  no well at the target"); continue }
            // Fine lines through the well: vertical ±3 mm, lateral ±3 mm, 20 µm.
            let dz = 20e-6, m = 150
            let vert = (-m...m).map { w + Vec3(0, 0, Double($0) * dz) }
            let lat1 = (-m...m).map { w + Vec3(Double($0) * dz, 0, 0) }
            let lineTones = try freqs.map { f in
                ForceCompiler.Tone(frequency: f, medium: air, rows: try rows(f, glass: glass, points: vert + lat1, zMin: zMin))
            }
            // The loudest point of the probe volume at unit power (incoherent over tones).
            var pmax2 = 0.0
            for i in 0..<lat.count {
                var e = 0.0
                for (fi, t) in tones.enumerated() {
                    var p = Complex.zero
                    for g in 0..<6 { p += t.rows[(i * 6 + g) * 4] * r.drives[fi][g] }
                    e += p.magnitudeSquared
                }
                pmax2 = max(pmax2, e)
            }
            let gmax = r.drives.flatMap { $0 }.map(\.magnitude).max() ?? 0
            for (bname, bead) in beads {
                let U = ForceCompiler.potential(lineTones, drives: r.drives, gates: 6, particle: bead, count: vert.count + lat1.count)
                let Uz = Array(U[0..<vert.count]), Ux = Array(U[vert.count...])
                var fUp = 0.0                                     // max of −dU/dz (upward force), N per (m/s)²
                for i in 1..<(Uz.count - 1) { fUp = max(fUp, -(Uz[i + 1] - Uz[i - 1]) / (2 * dz)) }
                let weight = bead.mass() * 9.81
                guard fUp > 0 else { print("  \(bname): the well pushes nowhere upward"); continue }
                let P = weight / fUp                              // required Σ|g|², (m/s)²
                let kx = (Ux[m + 1] - 2 * Ux[m] + Ux[m - 1]) / (dz * dz) * P
                let fx = kx > 0 ? (kx / bead.mass()).squareRoot() / (2 * Double.pi) : 0
                let u = gmax * P.squareRoot()                     // hardest-driven gate, m/s
                let uRMS = (P / Double(6 * freqs.count)).squareRoot()
                let pPeak = (pmax2 * P).squareRoot()
                print(String(format: "  %-18@ weight %.2e N · needs %5.2f m/s on the hardest gate (%3.0f dB), %4.2f m/s rms · field peak %3.0f dB · lateral %3.0f Hz",
                             bname as NSString, weight, u, dB(air.density * air.soundSpeed * u), uRMS, dB(pPeak), fx))
                gates.append(GateResult(id: "LEV", name: "\(label): \(bname)", measured: u, threshold: 0,
                                        comparison: .informational,
                                        detail: String(format: "hardest gate %.2f m/s (%.0f dB plane-wave), rms %.2f m/s; field peak %.0f dB; lateral %.0f Hz; sibling ratio %.2f",
                                                       u, dB(air.density * air.soundSpeed * u), uRMS, dB(pPeak), fx, r.siblingRatio)))
            }
        }
        print(String(format: "(%.1fs)", Date().timeIntervalSince(t0)))
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "levitate", gates: gates, durationSeconds: Date().timeIntervalSince(t0),
                                 device: deviceName(), gitSHA: gitSHA()))
        }
    } catch { print("GPU unavailable: \(error)"); exit(2) }

case "tonesweep":
    // Does the spectrum buy back what the glass takes? Sibling ratio against
    // the number of tones N, spread evenly over 30–70 kHz, in the glass
    // chamber (bare unless --liner R), target at the mid-plane. Tones ≥ 1 kHz
    // apart time-average their cross terms, so per-tone potentials add: the
    // target, a well in every tone, deepens ∝ N, while each tone's speckle
    // siblings sit in different places and pile up only ∝ √N. If the tones
    // decorrelate, the ratio falls like 1/√N — the time–bandwidth argument
    // (README, I1) put to the glass chamber.
    do {
        let ctx = try MetalContext()
        let t0 = Date()
        let air = RH1Freestanding.roomAir
        let design = RH1Design()
        let L = design.buildChamberHeight * 0.001
        let particle = ParticleMaterial.pla()
        let lam40 = air.wavelength(at: 40_000)
        var liner = 1.0
        if let i = args.firstIndex(of: "--liner"), i + 1 < args.count, let r = Double(args[i + 1]) { liner = r }
        let beta = (1 - liner) / (1 + liner)
        let fLo = 30_000.0, fHi = 70_000.0
        let cav = RH1Freestanding.chamber(maxGamma: {
            let k = air.wavenumber(at: fHi), e = log(1e4) / 0.05
            return (k * k + e * e).squareRoot() }())
        var x0 = Vec3(0, 0, L / 2)
        if let i = args.firstIndex(of: "--target"), i + 1 < args.count {
            let v = args[i + 1].split(separator: ",").compactMap { Double($0) }
            if v.count == 3 { x0 = Vec3(v[0], v[1], v[2]) * 0.001 }
        }
        let gspatOnly = args.contains("--gspat-only")
        var counts = args.contains("--quick") ? [1, 5, 20] : [1, 3, 5, 10, 20, 30]
        if let i = args.firstIndex(of: "--counts"), i + 1 < args.count {
            counts = args[i + 1].split(separator: ",").compactMap { Int($0) }
        }
        // One lattice for every N: ±2 λ(40 kHz) at λ(70 kHz)/8, as wallsweep.
        let h = air.wavelength(at: fHi) / 8
        let n = Int((2 * 2 * lam40 / h).rounded()) | 1
        let half = Double(n - 1) / 2 * h
        let lat = FieldLattice(origin: x0 - Vec3(half, half, half), spacing: h, nx: n, ny: n, nz: n)
        let zMin = max(0.05, min(lat.origin.z, L - (lat.origin.z + Double(n - 1) * h)))
        var o = ForceCompiler.Options()
        o.shellSteps = max(2, Int((air.wavelength(at: 50_000) / 4 / h).rounded()))
        print(String(format: "glass cylinder (a = %.0f mm), liner R = %.2f (β %.2f), plates R = 0.9; target (%.0f, %.0f, %.0f) mm; 200 µm PLA",
                     cav.radius * 1000, liner, beta, x0.x * 1000, x0.y * 1000, x0.z * 1000))
        print(String(format: "probe ±%.1f mm at %.2f mm (%d³); tones evenly over 30–70 kHz", half * 1000, h * 1000, n))
        print("sibling ratio = deepest competing well ÷ target well (< 0.5 = one trap); depth per unit total drive power")
        print("  tones   GS-PAT chord           force compiler    offset     depth vs 1 tone   1/√N")
        var gates: [GateResult] = []
        var depth1 = 0.0
        if gspatOnly { print("GS-PAT chords only, streamed tone by tone (no force compile)") }
        for N in counts where gspatOnly {
            let freqs = (0..<N).map { fLo + (fHi - fLo) * (Double($0) + 0.5) / Double(N) }
            var U = [Double](repeating: 0, count: lat.count)
            for f in freqs {
                var op = RH1Freestanding.Options()
                op.frequency = f; op.medium = air; op.slotSegment = max(2e-3, air.wavelength(at: f) / 4)
                let (p, c) = RH1Freestanding.preset(op)
                let src = cav.source(elements: p.elements, coupling: c, gateCount: p.gateCount,
                                     frequency: f, medium: air, zMin: zMin, wallAdmittance: beta)
                let rows = try CavityFieldsGPU.build(ctx: ctx, cavity: cav, source: src,
                                                     points: lat.positions, withGradient: true)
                let prop = Propagator(elements: p.elements,
                                      lattice: FieldLattice(origin: .zero, spacing: 1, nx: 1, ny: 1, nz: 1),
                                      frequency: f, medium: air, gateCount: p.gateCount,
                                      elementCoupling: c, cavity: cav, cavitySource: src)
                let u = InverseSolver.solve(propagator: prop, points: [.init(position: x0)],
                                            method: .gspat, iterations: 80, trap: .twinTrap)
                let d = u.map { $0 * (1 / (u.l2 * Double(N).squareRoot())) }
                let Uf = ForceCompiler.potential([ForceCompiler.Tone(frequency: f, medium: air, rows: rows)],
                                                 drives: [d], gates: 6, particle: particle, count: lat.count)
                for i in U.indices { U[i] += Uf[i] }
            }
            let r = ForceCompiler.evaluate(potential: U, drives: [], lattice: lat, target: x0, options: o,
                                           wavelength: lam40)
            let cell = r.siblingRatio.isFinite ? String(format: "%5.2f (%3d ≥ 0.5)", r.siblingRatio, r.siblings)
                                               : "no well at target  "
            print(String(format: "  %5d   %@", N, cell))
            gates.append(GateResult(id: "N-\(N)", name: String(format: "%d tones, GS-PAT chord, glass liner R %.2f", N, liner),
                                    measured: r.siblingRatio, threshold: 0.5, comparison: .informational,
                                    detail: String(format: "GS-PAT %.2f (%d siblings), offset %.1f mm",
                                                   r.siblingRatio, r.siblings, r.targetOffset * 1000)))
        }
        for N in counts where !gspatOnly {
            let freqs = (0..<N).map { fLo + (fHi - fLo) * (Double($0) + 0.5) / Double(N) }
            var tones: [ForceCompiler.Tone] = []
            var base: [[Complex]] = []
            for f in freqs {
                var op = RH1Freestanding.Options()
                op.frequency = f; op.medium = air; op.slotSegment = max(2e-3, air.wavelength(at: f) / 4)
                let (p, c) = RH1Freestanding.preset(op)
                let src = cav.source(elements: p.elements, coupling: c, gateCount: p.gateCount,
                                     frequency: f, medium: air, zMin: zMin, wallAdmittance: beta)
                let rows = try CavityFieldsGPU.build(ctx: ctx, cavity: cav, source: src,
                                                     points: lat.positions, withGradient: true)
                tones.append(ForceCompiler.Tone(frequency: f, medium: air, rows: rows))
                let prop = Propagator(elements: p.elements,
                                      lattice: FieldLattice(origin: .zero, spacing: 1, nx: 1, ny: 1, nz: 1),
                                      frequency: f, medium: air, gateCount: p.gateCount,
                                      elementCoupling: c, cavity: cav, cavitySource: src)
                let u = InverseSolver.solve(propagator: prop, points: [.init(position: x0)],
                                            method: .gspat, iterations: 80, trap: .twinTrap)
                base.append(u.map { $0 * (1 / (u.l2 * Double(N).squareRoot())) })
            }
            let rB = ForceCompiler.evaluate(tones, drives: base, lattice: lat, target: x0, gates: 6,
                                            particle: particle, options: o, wavelength: lam40)
            if args.contains("--each") && N > 1 {
                // Diagnostic: every tone alone, then their equal-power sum.
                var each: [[Complex]] = []
                for (fi, t) in tones.enumerated() {
                    let r1 = ForceCompiler.compile([t], lattice: lat, gates: 6, particle: particle,
                                                   wavelength: lam40, options: o, starts: [[base[fi]]])
                    each.append(r1.drives[0])
                    print(String(format: "      alone %.1f kHz: ratio %.2f (%d), depth %.3g, offset %.1f mm",
                                 t.frequency / 1000, r1.siblingRatio, r1.siblings, r1.targetDepth,
                                 r1.targetOffset * 1000))
                }
                let sum = ForceCompiler.evaluate(tones, drives: each.map { v in v.map { $0 * (1 / Double(N).squareRoot()) } },
                                                 lattice: lat, target: x0, gates: 6, particle: particle,
                                                 options: o, wavelength: lam40)
                print(String(format: "      equal-power sum: ratio %.2f (%d), depth %.3g, offset %.1f mm",
                             sum.siblingRatio, sum.siblings, sum.targetDepth, sum.targetOffset * 1000))
            }
            let rF = ForceCompiler.compile(tones, lattice: lat, gates: 6, particle: particle,
                                           wavelength: lam40, options: o, starts: [base])
            if N == counts[0] { depth1 = rF.targetDepth }
            func cell(_ r: ForceCompiler.Result) -> String {
                r.siblingRatio.isFinite ? String(format: "%5.2f (%3d ≥ 0.5)", r.siblingRatio, r.siblings)
                                        : "no well at target  "
            }
            let ref = N == counts[0] ? "" : String(format: "%.2f", 1 / Double(N).squareRoot())
            print(String(format: "  %5d   %@      %@  %4.1f mm  %8.2f          %@", N, cell(rB), cell(rF),
                         rF.targetOffset * 1000, depth1 > 0 ? rF.targetDepth / depth1 : 0, ref))
            gates.append(GateResult(id: "N-\(N)", name: String(format: "%d tones, glass liner R %.2f", N, liner),
                                    measured: rF.siblingRatio, threshold: 0.5, comparison: .informational,
                                    detail: String(format: "force %.2f (%d siblings), GS-PAT %.2f (%d); depth %.3g",
                                                   rF.siblingRatio, rF.siblings, rB.siblingRatio, rB.siblings,
                                                   rF.targetDepth)))
        }
        print(String(format: "(%.1fs)", Date().timeIntervalSince(t0)))
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "tonesweep", gates: gates, durationSeconds: Date().timeIntervalSince(t0),
                                 device: deviceName(), gitSHA: gitSHA()))
        }
    } catch { print("GPU unavailable: \(error)"); exit(2) }

case "wallsweep":
    // How absorptive must the glass side wall be for 6 drives to hold ONE
    // trap? Sweep the wall's normal-incidence reflection R_glass (a liner or
    // treatment on the glass; 1 = bare glass), plates R = 0.9, at each value
    // GS-PAT vs the force compiler at the mid-plane, one tone and the chord.
    // (A first version swept a distributed-loss Q instead: that also damps
    // the direct plate-to-trap paths, ~16× over half the chamber at Q = 30,
    // and confounds the answer.)
    do {
        let ctx = try MetalContext()
        let t0 = Date()
        let air = RH1Freestanding.roomAir
        let design = RH1Design()
        let L = design.buildChamberHeight * 0.001
        let particle = ParticleMaterial.pla()
        let lam40 = air.wavelength(at: 40_000)
        let cav = RH1Freestanding.chamber(maxGamma: {
            let k = air.wavenumber(at: 100_000), e = log(1e4) / 0.05
            return (k * k + e * e).squareRoot() }())
        let x0 = Vec3(0, 0, L / 2)
        // (plate R, glass R): the glass alone first, then the plates' axial
        // reverberation — the image model's 3-order truncation understated it.
        let grid: [(Double, Double)] = args.contains("--plates")
            ? [(0.9, 1.0), (0.7, 1.0), (0.5, 1.0), (0.3, 1.0), (0.0, 1.0), (0.5, 0.5), (0.0, 0.5), (0.0, 0.0)]
            : [(0.9, 1.0), (0.9, 0.9), (0.9, 0.7), (0.9, 0.5), (0.9, 0.3), (0.9, 0.0)]
        let sets: [(String, [Double])] = [("1 tone, 40 kHz", [40_000]),
                                          ("5-tone chord, 30–70 kHz", [30_000, 40_000, 50_000, 60_000, 70_000])]
        func machine(_ f: Double, _ m: Medium) -> (MachinePreset, [Complex]) {
            var o = RH1Freestanding.Options()
            o.frequency = f; o.medium = m; o.slotSegment = max(2e-3, air.wavelength(at: f) / 4)
            return RH1Freestanding.preset(o)
        }
        var gates: [GateResult] = []
        print(String(format: "glass cylinder (a = %.0f mm) between the plates; target: mid-plane; 200 µm PLA bead", cav.radius * 1000))
        print("side wall: exact lined-wall modes, locally reacting, β = (1 − R)/(1 + R) from its normal-incidence R")
        print("sibling ratio = deepest competing well within ±17 mm ÷ target well (< 0.5 = one trap)")
        for (label, freqs) in sets {
            let fMax = freqs.max()!, fMid = (freqs.min()! + fMax) / 2
            let h = air.wavelength(at: fMax) / (freqs.count > 1 ? 8 : 10)
            let n = Int((2 * 2 * lam40 / h).rounded()) | 1
            let half = Double(n - 1) / 2 * h
            let lat = FieldLattice(origin: x0 - Vec3(half, half, half), spacing: h, nx: n, ny: n, nz: n)
            let zMin = max(0.05, min(lat.origin.z, L - (lat.origin.z + Double(n - 1) * h)))
            var o = ForceCompiler.Options()
            o.shellSteps = max(2, Int((air.wavelength(at: fMid) / 4 / h).rounded()))
            print("\n\(label)")
            print("  plates R · glass R        GS-PAT twin trap          force compiler")
            for (Rp, R) in grid {
                let beta = (1 - R) / (1 + R)
                var tones: [ForceCompiler.Tone] = []
                var base: [[Complex]] = []
                for f in freqs {
                    let m = air
                    let (p, c) = machine(f, m)
                    let src = cav.source(elements: p.elements, coupling: c, gateCount: p.gateCount,
                                         frequency: f, medium: m, zMin: zMin, wallAdmittance: beta,
                                         plateReflection: Rp)
                    let rows = try CavityFieldsGPU.build(ctx: ctx, cavity: cav, source: src,
                                                         points: lat.positions, withGradient: true)
                    tones.append(ForceCompiler.Tone(frequency: f, medium: m, rows: rows))
                    let prop = Propagator(elements: p.elements,
                                          lattice: FieldLattice(origin: .zero, spacing: 1, nx: 1, ny: 1, nz: 1),
                                          frequency: f, medium: m, gateCount: p.gateCount,
                                          elementCoupling: c, cavity: cav, cavitySource: src)
                    let u = InverseSolver.solve(propagator: prop, points: [.init(position: x0)],
                                                method: .gspat, iterations: 80, trap: .twinTrap)
                    base.append(u.map { $0 * (1 / (u.l2 * Double(freqs.count).squareRoot())) })
                }
                let rB = ForceCompiler.evaluate(tones, drives: base, lattice: lat, target: x0, gates: 6,
                                                particle: particle, options: o, wavelength: lam40)
                let rF = ForceCompiler.compile(tones, lattice: lat, gates: 6, particle: particle,
                                               wavelength: lam40, options: o, starts: [base])
                func cell(_ r: ForceCompiler.Result) -> String {
                    r.siblingRatio.isFinite ? String(format: "%5.2f (%3d ≥ 0.5)", r.siblingRatio, r.siblings)
                                            : "no well at target  "
                }
                let rs = String(format: "%4.2f · %4.2f (β %.2f)", Rp, R, beta)
                print("  \(rs.padding(toLength: 25, withPad: " ", startingAt: 0)) \(cell(rB))        \(cell(rF))")
                gates.append(GateResult(id: "W-\(freqs.count)t", name: String(format: "%@, plates R %.2f, glass R %.2f", label, Rp, R),
                                        measured: rF.siblingRatio, threshold: 0, comparison: .informational,
                                        detail: String(format: "force %.2f (%d siblings), GS-PAT %.2f (%d)",
                                                       rF.siblingRatio, rF.siblings, rB.siblingRatio, rB.siblings)))
            }
        }
        print(String(format: "(%.1fs)", Date().timeIntervalSince(t0)))
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: "wallsweep", gates: gates, durationSeconds: Date().timeIntervalSince(t0),
                                 device: deviceName(), gitSHA: gitSHA()))
        }
    } catch { print("GPU unavailable: \(error)"); exit(2) }

case "forcetrap":
    // Compile for FORCE (ForceCompiler) vs the GS-PAT twin trap, on the
    // free-standing machine: is the trap unique, and does it survive a warmer
    // room once the compiler knows the temperature?
    do {
        let ctx = try MetalContext()
        let t0 = Date()
        let air = RH1Freestanding.roomAir
        let design = RH1Design()
        let L = design.buildChamberHeight * 0.001
        let particle = ParticleMaterial.pla()               // the 200 µm PLA bead
        let lam40 = air.wavelength(at: 40_000)
        let quick = args.contains("--quick")
        var toneSets: [(String, [Double])] = [("1 tone, 40 kHz", [40_000])]
        if !quick { toneSets.append(("5-tone chord, 30–70 kHz", [30_000, 40_000, 50_000, 60_000, 70_000])) }
        let targets: [(String, Vec3)] = [("mid-plane", Vec3(0, 0, L / 2)),
                                         ("100 mm above the lower face", Vec3(0, 0, 0.10))]
        let walls = RH1Freestanding.walls(design)
        // --glass: the chamber as the glass cylinder + plates (cavity model)
        // instead of the plates alone.
        let glass = args.contains("--glass")
        let cav = glass ? RH1Freestanding.chamber(maxGamma: {
            let k = air.wavenumber(at: 100_000), e = log(1e4) / 0.05
            return (k * k + e * e).squareRoot() }()) : nil
        func zMin(_ lat: FieldLattice) -> Double {
            let zlo = lat.origin.z, zhi = lat.origin.z + Double(lat.nz - 1) * lat.spacing
            return max(0.05, min(zlo, L - zhi))
        }
        print(glass ? String(format: "field model: glass cylinder (a = %.0f mm) + both plates, R = 0.9 (cavity modes)",
                             cav!.radius * 1000)
                    : "field model: both plates as mirrors (3 image orders, R = 0.9)")
        func machine(_ f: Double, _ m: Medium) -> (MachinePreset, [Complex]) {
            var o = RH1Freestanding.Options()
            o.frequency = f; o.medium = m; o.slotSegment = max(2e-3, air.wavelength(at: f) / 4)
            return RH1Freestanding.preset(o)
        }
        func tones(_ freqs: [Double], _ m: Medium, _ lat: FieldLattice) throws -> [ForceCompiler.Tone] {
            try freqs.map { f in
                let (p, c) = machine(f, m)
                let rows: [Complex]
                if let cav {
                    let src = cav.source(elements: p.elements, coupling: c, gateCount: p.gateCount,
                                         frequency: f, medium: m, zMin: zMin(lat))
                    rows = try CavityFieldsGPU.build(ctx: ctx, cavity: cav, source: src,
                                                     points: lat.positions, withGradient: true)
                } else {
                    rows = try PortFieldsGPU.buildWithGradient(ctx: ctx, elements: p.elements, coupling: c,
                                                               walls: walls, points: lat.positions,
                                                               frequency: f, medium: m, gateCount: p.gateCount)
                }
                return ForceCompiler.Tone(frequency: f, medium: m, rows: rows)
            }
        }
        var gates: [GateResult] = []
        func fmt(_ r: ForceCompiler.Result) -> String {
            String(format: "sibling ratio %5.2f · %3d siblings ≥ 0.5 · offset %4.1f mm",
                   r.siblingRatio, r.siblings, r.targetOffset * 1000)
        }
        for (label, freqs) in toneSets {
            let fMax = freqs.max()!, fMid = (freqs.min()! + fMax) / 2
            let h = air.wavelength(at: fMax) / (freqs.count > 1 ? 8 : 10)
            let n = Int((2 * 2 * lam40 / h).rounded()) | 1                // ±2 λ(40 kHz), odd
            var o = ForceCompiler.Options()
            o.shellSteps = max(2, Int((air.wavelength(at: fMid) / 4 / h).rounded()))
            print("\n\(label): probe ±\(String(format: "%.1f", 2 * lam40 * 1000)) mm at \(String(format: "%.2f", h * 1000)) mm (\(n)³ points)")
            for (tName, x0) in targets {
                let half = Double(n - 1) / 2 * h
                let lat = FieldLattice(origin: x0 - Vec3(half, half, half), spacing: h, nx: n, ny: n, nz: n)
                let T0 = try tones(freqs, air, lat)
                // Baseline: GS-PAT twin trap per tone, equal power per tone.
                let base: [[Complex]] = freqs.map { f in
                    let (p, c) = machine(f, air)
                    let prop = Propagator(elements: p.elements,
                                          lattice: FieldLattice(origin: .zero, spacing: 1, nx: 1, ny: 1, nz: 1),
                                          frequency: f, medium: air, gateCount: p.gateCount,
                                          elementCoupling: c, walls: walls, cavity: cav,
                                          cavityZMin: zMin(lat))
                    let u = InverseSolver.solve(propagator: prop, points: [.init(position: x0)],
                                                method: .gspat, iterations: 80, trap: .twinTrap)
                    let s = 1 / (u.l2 * Double(freqs.count).squareRoot())
                    return u.map { $0 * s }
                }
                let rB = ForceCompiler.evaluate(T0, drives: base, lattice: lat, target: x0, gates: 6,
                                                particle: particle, options: o, wavelength: lam40)
                let rF = ForceCompiler.compile(T0, lattice: lat, gates: 6, particle: particle,
                                               wavelength: lam40, options: o, starts: [base])
                let deeper = rB.targetDepth > 0 ? rF.targetDepth / rB.targetDepth : .infinity
                print("  \(tName)")
                print("    GS-PAT twin trap : " + fmt(rB))
                print("    force compiler   : " + fmt(rF) + String(format: " · depth %.1f× GS-PAT", deeper))
                if freqs.count > 1 && tName == "mid-plane" && !glass {
                    // G-F1: the chord, compiled for force, holds ONE trap at the
                    // mid-plane — every competing well within ±2λ under half its
                    // depth (the plate study's own 0.5 bar, which GS-PAT misses).
                    let g1 = GateResult(id: "G-F1", name: "force compiler + 5-tone chord: unique trap at the mid-plane",
                                        measured: rF.siblingRatio, threshold: 0.5,
                                        detail: String(format: "sibling ratio %.2f, %d siblings ≥ 0.5, offset %.1f mm; GS-PAT %@",
                                                       rF.siblingRatio, rF.siblings, rF.targetOffset * 1000,
                                                       rB.siblingRatio.isFinite ? String(format: "%.2f", rB.siblingRatio) : "no well at the target"))
                    print(g1.line)
                    gates.append(g1)
                }
                gates.append(GateResult(id: "F-\(freqs.count)t\(glass ? "-glass" : "")", name: "\(label), \(tName)\(glass ? ", glass" : ""): force vs GS-PAT sibling ratio",
                                        measured: rF.siblingRatio, threshold: 0, comparison: .informational,
                                        detail: String(format: "force %.2f (%d siblings), GS-PAT %.2f (%d); depth %.1f×",
                                                       rF.siblingRatio, rF.siblings, rB.siblingRatio, rB.siblings, deeper)))
                // Warm the room: hold the force-compiled drive, then re-compile at the true T.
                guard let w0 = rF.targetWell, rF.targetDepth > 0 else { continue }
                var line = "    warmer, held / re-compiled:"
                for dT in quick ? [0.3] : [0.1, 0.3, 1.0] {
                    let m = air.shifted(byKelvin: dT)
                    let TT = try tones(freqs, m, lat)
                    let held = ForceCompiler.evaluate(TT, drives: rF.drives, lattice: lat, target: w0, gates: 6,
                                                      particle: particle, options: o, wavelength: lam40)
                    // Re-compile at the true T, warm-started from the held drive:
                    // the continuous-calibration loop (no per-tone pre-pass).
                    var ow = o
                    ow.perToneStarts = false
                    let redo = ForceCompiler.compile(TT, lattice: lat, gates: 6, particle: particle,
                                                     wavelength: lam40, options: ow, starts: [rF.drives])
                    func cell(_ r: ForceCompiler.Result) -> String {
                        guard let w = r.targetWell else { return "lost" }
                        return String(format: "%.0f µm, %.2f deep, ratio %.2f", (w - w0).length * 1e6,
                                      r.targetDepth / rF.targetDepth, r.siblingRatio)
                    }
                    line += String(format: "\n      +%.1f K  held: %@   re-compiled: %@", dT, cell(held), cell(redo))
                }
                print(line)
            }
        }
        print(String(format: "(%.1fs)", Date().timeIntervalSince(t0)))
        if args.contains("--receipt") {
            writeReceipt(Receipt(name: glass ? "forcetrap-glass" : "forcetrap", gates: gates, durationSeconds: Date().timeIntervalSince(t0),
                                 device: deviceName(), gitSHA: gitSHA()))
        }
        exit(gates.filter { $0.comparison != .informational }.allSatisfy(\.passed) ? 0 : 1)
    } catch { print("GPU unavailable: \(error)"); exit(2) }

case "render":
    // Offscreen render of the RH-1 machine — the viewport half of the
    // screenshot harness, with no window server involved.
    do {
        let ctx = try MetalContext()
        let r = try Renderer(ctx: ctx)
        let light = args.contains("--light")
        let pal = light ? SceneBuilder.Palette.light : SceneBuilder.Palette()
        var obj: SceneGeometry? = nil
        if !args.contains("--empty") {
            let placed = STL.sampleCup().placed(in: RH1Freestanding.standard().preset.buildVolume)
            obj = SceneBuilder.object(placed.mesh, palette: pal, fits: placed.fits)
            print("  object: \(placed.mesh.triangles.count) triangles, fits \(placed.fits)")
        }
        // --overlays: compile a field and render it with traps, so the overlay
        // path is verifiable outside the window.
        if args.contains("--overlays") {
            let f = 40_000.0
            let bv = RH1Freestanding.standard(frequency: f).preset.buildVolume
            let lam = RH1Freestanding.roomAir.wavelength(at: f)
            let inset = 2 * lam, sp = lam / 2, R = bv.radius
            let lat = FieldLattice(
                origin: Vec3(-R, -R, inset), spacing: sp,
                nx: Int((2 * R / sp).rounded(.down)) + 1,
                ny: Int((2 * R / sp).rounded(.down)) + 1,
                nz: Int(((bv.height - 2 * inset) / sp).rounded(.down)) + 1)
            let (prop, preset, how) = standardPropagator(frequency: f, lattice: lat)
            print("  operator: \(lat.count) points (\(how))")
            let target = Vec3(0, 0, preset.buildVolume.height / 2)
            let drive = InverseSolver.solve(
                propagator: prop, points: [.init(position: target, targetAmplitude: 1)],
                method: .gspat, iterations: 80)
            let mag = prop.forward(drive).map(\.magnitude)
            let g = Gorkov(medium: preset.medium, particle: .pla())
            let U = g.potentialField(propagator: prop, drive: drive)
            let traps = Gorkov.findTraps(U: U, lattice: lat, limit: 250)
            print("  field: \(mag.count) pts, peak \(String(format: "%.3g", mag.max() ?? 0))")
            print("  traps: \(traps.count) minima")
            var extra = SceneBuilder.fieldSlice(magnitude: mag, lattice: lat)
            // matter: run the particle sim forward so transport is visible
            var sim = ParticleSim(potential: U, lattice: lat, medium: preset.medium)
            sim.seedDelivered(count: 900)
            let gain = sim.levitationGain(ratio: 3)
            for _ in 0..<1200 { sim.step(dt: 2e-4, forceGain: gain) }
            let c = sim.counts
            print("  matter: \(c.feedstock) feedstock, \(c.inTransit) transit, \(c.trapped) trapped")
            let pg = SceneBuilder.particles(sim)
            extra.linePositions += pg.linePositions
            extra.lineColors += pg.lineColors
            // boundary: per-element drive on the surfaces
            let bg = SceneBuilder.boundary(elements: preset.elements, drive: drive,
                                           palette: pal)
            print("  boundary: \(preset.elements.count) elements painted")
            extra.trianglePositions += bg.trianglePositions
            extra.triangleColors += bg.triangleColors
            let tg = SceneBuilder.traps(traps, palette: pal)
            extra.linePositions += tg.linePositions
            extra.lineColors += tg.lineColors
            extra.trianglePositions += tg.trianglePositions
            extra.triangleColors += tg.triangleColors
            if let o = obj {
                extra.linePositions += o.linePositions
                extra.lineColors += o.lineColors
                extra.trianglePositions += o.trianglePositions
                extra.triangleColors += o.triangleColors
            }
            obj = extra
        }
        r.load(SceneBuilder.rh1(palette: pal), object: obj)
        if light { r.background = SIMD4<Double>(0.97, 0.965, 0.95, 1) }
        switch args.first(where: { ["front","top","iso","home"].contains($0) }) {
        case "front": r.camera = .front
        case "top":   r.camera = .top
        default:      r.camera = .home
        }
        let w = 1280, h = 800
        guard let img = try r.renderOffscreen(width: w, height: h) else {
            print("render failed"); exit(1)
        }
        let out = args.first(where: { $0.hasSuffix(".png") }) ?? "machine.png"
        let url = URL(fileURLWithPath: out)
        guard let dest = CGImageDestinationCreateWithURL(
                url as CFURL, "public.png" as CFString, 1, nil) else {
            print("could not create \(out)"); exit(1)
        }
        CGImageDestinationAddImage(dest, img, nil)
        CGImageDestinationFinalize(dest)
        print("wrote \(url.path)  (\(w)x\(h))")
    } catch { print("render unavailable: \(error)"); exit(2) }

case "scan":
    // End-to-end: FDTD pulse-echo -> S(f) -> matrix pencil -> chords ->
    // .pattern -> Machine View reconstruction -> gates.
    do {
        let n = 44, dx = 0.004
        let sphere = Mesh.sphere(radius: 0.022, subdivisions: 3)
        print("scanning a 44 mm sphere in a \(n)^3 chamber (dx = 4 mm) ...")
        let t0 = Date()
        let result = Scan.run(nx: n, ny: n, nz: n, dx: dx, object: sphere,
                              gateCount: 12, steps: 700, code: .welchCostas)
        print(String(format: "  %d gates, %d samples, dt = %.3g s   (%.1fs)",
                     result.gates.count, result.portRecords[0].count,
                     result.dt, Date().timeIntervalSince(t0)))
        print("  reciprocity  \(String(format: "%.4f", result.reciprocity))")
        print("  chords extracted: \(result.chords.count)")
        for (i, c) in result.chords.prefix(5).enumerated() {
            print(String(format: "    [%d] f = %8.1f Hz   Q = %7.1f   weight %.4g",
                         i, c.frequencyHz, c.qFactor, c.weight))
        }

        // Model-order sweep. The FDTD is the expensive part (~18s); extraction
        // is cheap, so one scan is re-extracted at several orders rather than
        // re-running the chamber per order.
        if args.contains("--sweep") {
            print("\n  order   win  chords   in-fit   held-out   ratio")
            for (order, win) in [(32, 64), (48, 96), (64, 128), (96, 180),
                                 (128, 220)] {
                let ch = MatrixPencil.extract(records: result.portRecords,
                                              dt: result.dt, maxChords: order,
                                              pencilWindow: win)
                var probe = result
                probe.chords = ch
                let g = MachineView.heldOutPrediction(probe, holdOut: 3,
                                                      maxChords: order,
                                                      pencilWindow: win)
                // pull the two numbers out of the detail string
                let re = MatrixPencil.synthesize(chords: ch,
                                                 gates: result.portRecords.count,
                                                 samples: result.portRecords[0].count,
                                                 dt: result.dt)
                var inFit = 0.0
                for i in result.portRecords.indices {
                    inFit += re[i].relativeL2(to: result.portRecords[i])
                }
                inFit /= Double(result.portRecords.count)
                let ratio = inFit > 0 ? g.measured / inFit : Double.nan
                print(String(format: "  %5d  %4d  %6d  %7.4f   %8.4f  %6.2fx%@",
                             order, win, ch.count, inFit, g.measured, ratio,
                             (g.measured < 0.15 ? "  <- PASSES" : "") as NSString))
            }
            print("")
        }

        // .pattern round trip, with provenance enforced.
        let pat = PatternFile(name: "sphere-22mm", machine: "emulated-chamber",
                              calibrationRef: result.calibrationRef,
                              material: .init(name: "PLA", density: 1240, soundSpeed: 2220),
                              band: [20000, 80000], chords: result.chords,
                              rung: "L0", greensFunctionMeasured: false)
        let data = try pat.encoded()
        let back = try PatternFile.decode(data)
        let roundTrip = try back.encoded() == data
        print("  .pattern: \(data.count) bytes, round trip \(roundTrip ? "bit-exact" : "DIFFERS")")
        print("  provenance: \(pat.meta.counts.measured) measured / "
            + "\(pat.meta.counts.inferred) inferred; buildable \(pat.buildableChords.count)")
        try data.write(to: URL(fileURLWithPath: "scan.pattern"))

        // Machine View.
        let lat = FieldLattice(origin: Vec3(0, 0, 0), spacing: dx * 2,
                               nx: n / 2, ny: n / 2, nz: n / 2)
        let recon = MachineView.backProject(result, lattice: lat)
        let cov = recon.coverage.sorted()
        func pct(_ q: Double) -> Double { cov[min(cov.count - 1, Int(q * Double(cov.count)))] }
        print(String(format: "  Machine View L0: %.1f%% NEVER OBSERVED   "
                   + "coverage p10 %.2f  p50 %.2f  p90 %.2f",
                     recon.unobservedFraction * 100, pct(0.10), pct(0.50), pct(0.90)))
        let centred = sphere.translated(by: Vec3(Double(n-1)*dx/2, Double(n-1)*dx/2,
                                                 Double(n-1)*dx/2) - sphere.centroid)
        var gates = MachineView.compareToTruth(recon, truth: centred)
        gates.append(contentsOf: MachineView.chordTruncation(result))
        gates.append(MachineView.heldOutPrediction(result))
        gates.append(GateResult(id: "G11", name: ".pattern round trip bit-exact",
                                measured: roundTrip ? 0 : 1, threshold: 0.5))
        gates.append(GateResult(id: "G15", name: "reciprocity ||K-K^T||/||K||",
                                measured: result.reciprocity, threshold: 0.1,
                                detail: "free QC on every scan"))
        // L1 DORT must REFUSE without a measured Green's function.
        let refused = MachineView.dort(result, lattice: lat,
                                       greensFunctionMeasured: false) == nil
        gates.append(GateResult(id: "G-DORT-gate",
                                name: "L1 refuses without a measured Green's function",
                                measured: refused ? 0 : 1, threshold: 0.5,
                                detail: refused ? "refused, as required"
                                                : "DID NOT REFUSE — would emit a "
                                                + "confident meaningless image"))
        for g in gates { print("  " + g.line) }
        let rec = Receipt(name: "scan", gates: gates,
                          durationSeconds: Date().timeIntervalSince(t0),
                          device: deviceName(), gitSHA: gitSHA())
        if args.contains("--receipt") { writeReceipt(rec) }
    } catch { print("scan failed: \(error)"); exit(1) }

case "broadband":
    // The corrected channel-count study (§ BroadbandGate). Runs the free-field
    // monochromatic condition and the cavity+chord condition side by side so the
    // difference between them is visible rather than asserted.
    print("condition                          RH-1 par/main   dense par/main   RH-1 rel")
    for (tones, walls, rainbow, label) in [
        (1, false, false, "1 tone, free field  (old model)"),
        (1, true,  false, "1 tone, walls"),
        (5, true,  false, "5 tones, walls"),
        (5, true,  true,  "5 tones, walls + rainbow"),
    ] {
        let g = BroadbandGate.channelCountStudy(tones: tones, withWalls: walls,
                                                withRainbow: rainbow)
        let rh1 = g[0].measured, rel = g[1].measured
        let dense = rel > 0 ? rh1 / rel : Double.nan
        print(String(format: "%-34@ %13.4f %16.4f %10.2fx",
                     label as NSString, rh1, dense, rel))
    }
    print("\nlower parasitic/main is better; RH-1 rel > 1 means RH-1 is worse than 512-ch")

case "shot":
    exit(await MainActor.run { ShotCommand.run(args: args) })

case "cad":
    exit(CADCommand.run(args))

default:
    print("""
    fieldc — Field Compiler CLI

      fieldc gate [--receipt]   run the physics acceptance gates (§22)
      fieldc test               run the unit suite
      fieldc machine [--em]     describe the RH-1 desktop preset (v0.3, panels)
      fieldc machine --freestanding [--slots-closed]   the plate-primary preset, from the CAD
      fieldc plates [--receipt] plate-aperture study: 6 throat gates, tones, slots, walls
      fieldc focus              compile a centre trap, compare solver methods
      fieldc gpu                validate the Metal propagator against the CPU
      fieldc render [iso|front|top] [--light] [out.png]\n      fieldc scan [--receipt]   end-to-end scan -> chords -> .pattern -> Machine View\n      fieldc broadband          channel-count study: free field vs cavity + chord\n      fieldc shot [scene] [--all] [--light] [--contact-sheet] [--out DIR]
      fieldc cad [info|check|render|export|drawing|bom|params|step]   the RH-1 solid model

    Built for CommandLineTools only — no Xcode, no external dependencies.
    """)
}
