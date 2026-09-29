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
    if let data = try? r.json() {
        try? data.write(to: url)
        print("receipt written: \(url.path)")
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
