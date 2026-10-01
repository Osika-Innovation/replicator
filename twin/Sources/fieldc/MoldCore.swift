import FieldCore
import FieldGPU
import Foundation

// The single-shot acoustic mold as a function, so `fieldc mold`, `fieldc
// arraysweep` and `fieldc replicate` run the same physics: compile one chord
// drive for a shape (sites joined by segments), release a random cloud of
// powder through the probe volume, and see where it ends in that field, with
// gravity.
//
// Two chambers. `.plates(array)`, the default since ENGINE.md: two Ø410 mm
// plates in open air, each N independently driven elements, matrix-free on
// the GPU. `.glass`: the glass cylinder of Rounds 7–11 (six gates, stored
// cavity rows).
//
// Where the powder ends is computed twice: by the basin map (every start's
// destination at once, recirculation in closed form) and by stepping 3,000
// grains (the check, gate G-B0).

enum MoldChamber {
    case glass
    case plates(PlateArray)
}

struct MoldSetup {
    var objective = "sieve"          // sieve | wells | funnel
    var tones: Int? = nil            // nil: 40 for the glass sieve, 9 for the plates, 20 otherwise
    var band: (lo: Double, hi: Double)? = nil   // Hz; nil: 30–70 kHz
    var grains = 3000
    var iterations: Int? = nil       // nil: 400 for the sieve, 300 otherwise
    var seconds = 8.0
    var powerX: Double? = nil        // nil: the sieve's window middle, else 4×
    var recirculate: Bool? = nil     // nil: on for the sieve
    var gravity = true
    var particles = true             // step grains as well as the basin map
    /// Basin-map feedback rounds for the sieve: weight the sites that get too
    /// little powder up and recompile from the last drive.
    var feedback = 3
    var debug = false
}

struct MoldOutcome {
    var sites: [Vec3] = []
    var perSite: [Int] = []
    var final: [Vec3] = []
    var onShape: [Bool] = []
    var captured = 0, rogue = 0, drifting = 0, lost = 0, resprinkles = 0
    var contrast = 0.0, powerX = 0.0, tones = 0, channels = 0
    var formed = 0, rivalRatio = 0.0
    /// Basin map: share of the release on the shape (with recirculation if on),
    /// per-site shares, rogue share.
    var basinOnShape = 0.0, basinRogue = 0.0
    var basinPerSite: [Double] = []
    var driveRMS = 0.0               // m/s per channel, rms over channels
    var compileSeconds = 0.0
    var grainsCSV = "", sitesCSV = "", captureCSV = ""
    var captureLog: [String] = []
    var gates: [GateResult] = []
    var summary = ""
}

/// Distance from x to a shape given as segments (a segment from a point to
/// itself is a lone site).
func shapeDistance(_ x: Vec3, _ segments: [(Vec3, Vec3)]) -> Double {
    segments.reduce(Double.infinity) { m, s in
        let d = s.1 - s.0
        let dd = d.dot(d)
        let u = dd > 0 ? max(0, min(1, (x - s.0).dot(d) / dd)) : 0
        return min(m, (x - (s.0 + d * u)).length)
    }
}

func runMold(ctx: MetalContext, label: String, sites targetPts: [Vec3], segments: [(Vec3, Vec3)],
             chamber: MoldChamber, setup: MoldSetup, log: @escaping (String) -> Void = { print($0) }) throws -> MoldOutcome {
    let air = RH1Freestanding.roomAir
    let L: Double
    switch chamber {
    case .glass: L = RH1Design().buildChamberHeight * 0.001
    case .plates(let a): L = a.gap
    }
    let lam40 = air.wavelength(at: 40_000)
    let centre = Vec3(0, 0, L / 2)
    let objective = setup.objective
    let isPlates: Bool = { if case .plates = chamber { return true }; return false }()
    // Defaults: the glass sieve's 40 tones; for the plates the design point of
    // the channel sweep (S1): 9 tones over 30–70 kHz.
    let nTones = setup.tones ?? (isPlates ? 9 : (objective == "sieve" ? 40 : 20))
    let band = setup.band ?? (30_000.0, 70_000.0)
    let nGrains = setup.grains
    let freqs: [Double] = (0..<nTones).map { q in
        let frac: Double = (Double(q) + 0.5) / Double(nTones)
        return band.lo + (band.hi - band.lo) * frac
    }
    let grain = ParticleMaterial(density: 1240, soundSpeed: 2220, radius: 20e-6)   // Ø40 µm PLA powder
    let h = air.wavelength(at: freqs.max()!) / 8
    let half = 12e-3
    let n = Int((2 * half / h).rounded()) | 1
    let hh = Double(n - 1) / 2 * h
    let lat = FieldLattice(origin: centre - Vec3(hh, hh, hh), spacing: h, nx: n, ny: n, nz: n)
    var o = ForceCompiler.Options()
    o.shellSteps = max(2, Int((air.wavelength(at: freqs.min()!) / 4 / h).rounded()))
    func onShapeDistance(_ x: Vec3) -> Double { shapeDistance(x, segments) }
    let targets = targetPts.map { p -> (Int, Int, Int) in
        let f = (p - lat.origin) / h
        return (Int(f.x.rounded()), Int(f.y.rounded()), Int(f.z.rounded()))
    }
    let snapped = targets.map { lat.position($0.0, $0.1, $0.2) }
    let t0 = Date()
    // --- the field and a start that focuses on every site ---
    var start: [[Complex]] = []
    let field: any ForceCompiler.ForceField
    switch chamber {
    case .glass:
        let cav = RH1Freestanding.chamber(maxGamma: {
            let k = air.wavenumber(at: freqs.max()!), e = Foundation.log(1e4) / 0.05
            return (k * k + e * e).squareRoot() }())
        let zMin = max(0.05, min(lat.origin.z, L - (lat.origin.z + Double(n - 1) * h)))
        var tones: [ForceCompiler.Tone] = []
        for f in freqs {
            var op = RH1Freestanding.Options()
            op.frequency = f; op.medium = air; op.slotSegment = max(2e-3, air.wavelength(at: f) / 4)
            let (p, c) = RH1Freestanding.preset(op)
            let src = cav.source(elements: p.elements, coupling: c, gateCount: p.gateCount, frequency: f, medium: air, zMin: zMin)
            tones.append(ForceCompiler.Tone(frequency: f, medium: air,
                                            rows: try CavityFieldsGPU.build(ctx: ctx, cavity: cav, source: src,
                                                                            points: lat.positions, withGradient: true)))
            let prop = Propagator(elements: p.elements, lattice: FieldLattice(origin: .zero, spacing: 1, nx: 1, ny: 1, nz: 1),
                                  frequency: f, medium: air, gateCount: p.gateCount, elementCoupling: c,
                                  cavity: cav, cavitySource: src)
            let u = InverseSolver.solve(propagator: prop, points: snapped.map { .init(position: $0) },
                                        method: .gspat, iterations: 80, trap: .twinTrap)
            start.append(u.map { $0 * (1 / (u.l2 * Double(nTones).squareRoot())) })
        }
        field = ForceCompiler.StoredRows(tones: tones, lattice: lat, channels: 6)
        log(String(format: "acoustic mold: %@, %d sites; glass chamber, 6 gates, %d tones %.0f–%.0f kHz; probe ±%.0f mm at %.2f mm (%d³)",
                   label, targets.count, nTones, band.lo / 1000, band.hi / 1000, hh * 1000, h * 1000, n))
    case .plates(let arr):
        field = try ArrayFieldGPU(ctx: ctx, array: arr, frequencies: freqs, medium: air, lattice: lat)
        // Time reversal: every element driven with the conjugate of its field
        // at each site, summed — a focus on every site at once.
        for f in freqs {
            let ref = arr.reference(frequency: f, medium: air)
            var g = [Complex](repeating: .zero, count: arr.channels)
            for x in snapped {
                let r = ref.gateGradientRows(at: x).p
                let nrm = r.reduce(0.0) { $0 + $1.magnitudeSquared }.squareRoot()
                for e in 0..<arr.channels { g[e] += r[e].conjugate * (1 / max(nrm, 1e-300)) }
            }
            let nrm = g.reduce(0.0) { $0 + $1.magnitudeSquared }.squareRoot()
            start.append(g.map { $0 * (1 / (max(nrm, 1e-300) * Double(nTones).squareRoot())) })
        }
        log(String(format: "acoustic mold: %@, %d sites; open air, two plates of %d elements (Ø%.0f mm, %.0f mm apart, R %.1f), %d tone%@ %.0f–%.0f kHz; probe ±%.0f mm at %.2f mm (%d³)",
                   label, targets.count, arr.perPlate, arr.plateRadius * 2000, arr.gap * 1000, arr.reflection,
                   nTones, nTones == 1 ? "" : "s", freqs.min()! / 1000, freqs.max()! / 1000, hh * 1000, h * 1000, n))
    }
    // The powder is released through the probe box less a 2 mm margin.
    let margin = 2e-3
    let lo = lat.origin + Vec3(margin, margin, margin), hi = lat.origin + Vec3(2 * hh - margin, 2 * hh - margin, 2 * hh - margin)
    let inRelease: (Vec3) -> Bool = { x in
        x.x >= lo.x && x.x <= hi.x && x.y >= lo.y && x.y <= hi.y && x.z >= lo.z && x.z <= hi.z
    }
    let iters = setup.iterations ?? (objective == "sieve" ? 400 : 300)
    let debugLog: ((String) -> Void)? = setup.debug ? log : nil
    func gradOf(_ U: [Double], _ x: Vec3) -> Vec3? {
        let f = (x - lat.origin) / h
        let i0 = Int(f.x.rounded(.down)), j0 = Int(f.y.rounded(.down)), k0 = Int(f.z.rounded(.down))
        guard i0 >= 1, j0 >= 1, k0 >= 1, i0 + 2 < lat.nx, j0 + 2 < lat.ny, k0 + 2 < lat.nz else { return nil }
        let tx = f.x - Double(i0), ty = f.y - Double(j0), tz = f.z - Double(k0)
        var gs = Vec3(0, 0, 0)
        for (dk, wz) in [(0, 1 - tz), (1, tz)] { for (dj, wy) in [(0, 1 - ty), (1, ty)] { for (di, wx) in [(0, 1 - tx), (1, tx)] {
            let i = i0 + di, j = j0 + dj, k = k0 + dk
            gs = gs + Vec3((U[lat.index(i + 1, j, k)] - U[lat.index(i - 1, j, k)]) / (2 * h),
                           (U[lat.index(i, j + 1, k)] - U[lat.index(i, j - 1, k)]) / (2 * h),
                           (U[lat.index(i, j, k + 1)] - U[lat.index(i, j, k - 1)]) / (2 * h)) * (wx * wy * wz)
        } } }
        return gs
    }
    let weight = grain.mass() * 9.81
    let recirculate = setup.recirculate ?? (objective == "sieve")
    func cellRange(_ a: Double, _ b: Double, _ o: Double) -> ClosedRange<Int> {
        Int(((a - o) / h).rounded(.up))...Int(((b - o) / h).rounded(.down))
    }
    let releaseCells = (cellRange(lo.x, hi.x, lat.origin.x), cellRange(lo.y, hi.y, lat.origin.y), cellRange(lo.z, hi.z, lat.origin.z))
    // Everything a drive's landscape decides: the lift contrast, the power at
    // the window's middle, and where the powder ends (the basin map).
    struct Eval {
        var U: [Double]; var contrast: Double; var fUpMin: Double; var powerX: Double; var power: Double
        var onShape: Double; var rogue: Double; var perSite: [Double]; var sinks: Int
    }
    func evaluate(_ drives: [[Complex]]) -> Eval {
        let U = field.potential(drives, particle: grain)
        var fUpMin = Double.infinity
        for p in snapped {
            var up = 0.0
            for q in -8...8 { if let g = gradOf(U, p + Vec3(0, 0, Double(q) * h * 0.25)) { up = max(up, -g.z) } }
            fUpMin = min(fUpMin, up)
        }
        // The sieve: the most any point away from the shape can lift (−∂U/∂z
        // per unit power). A grain can only rest where the lift equals its
        // weight, so between weight/fUpMin and weight/liftOut the sites hold
        // and nothing else in the box can.
        var liftOut = 0.0
        for k in 1..<(lat.nz - 1) { for j in 1..<(lat.ny - 1) { for i in 1..<(lat.nx - 1) {
            let x = lat.position(i, j, k)
            guard onShapeDistance(x) >= 1.5e-3 else { continue }
            let nn = lat.index(i, j, k)
            liftOut = max(liftOut, -(U[nn + lat.nx * lat.ny] - U[nn - lat.nx * lat.ny]) / (2 * h))
        } } }
        let contrast = fUpMin / max(liftOut, 1e-300)
        let powerX = setup.powerX ?? (objective == "sieve" ? (contrast > 1 ? contrast.squareRoot() : 1.05) : 4.0)
        let power = powerX * weight / max(fUpMin, 1e-300)
        let basins = BasinMap(U: U, lattice: lat, power: power, weight: setup.gravity ? weight : 0, release: releaseCells)
        let shares = recirculate ? basins.recirculated : basins.direct
        var bSite = [Double](repeating: 0, count: targets.count)
        var bOn = 0.0, bRogue = 0.0
        for (sink, w) in shares {
            let x = lat.positions[sink]
            if onShapeDistance(x) <= 1e-3, let q = snapped.indices.min(by: { (snapped[$0] - x).length < (snapped[$1] - x).length }) {
                bSite[q] += w; bOn += w
            } else { bRogue += w }
        }
        return Eval(U: U, contrast: contrast, fUpMin: fUpMin, powerX: powerX, power: power,
                    onShape: bOn, rogue: bRogue, perSite: bSite, sinks: basins.sinks.count)
    }
    let fairShare = 1 / Double(max(1, targets.count))
    // Prefer: everything on the shape (≥ 95 %), then the fullest weakest site, then the most on the shape.
    func better(_ a: Eval, _ b: Eval) -> Bool {
        let aOK = a.onShape >= 0.95, bOK = b.onShape >= 0.95
        if aOK != bOK { return aOK }
        let am = a.perSite.min() ?? 0, bm = b.perSite.min() ?? 0
        if abs(am - bm) > 1e-9 { return am > bm }
        return a.onShape > b.onShape
    }
    var drives: [[Complex]]
    if objective == "wells" || objective == "sieve" {
        let mold = ForceCompiler.compileMold(field: field, particle: grain, targets: targets, wavelength: lam40,
                                             options: o, start: start, iterations: iters, log: debugLog)
        drives = mold.drives
        if objective == "sieve" {
            // From the wells mold: now make the shape the only place that can hold a grain up.
            let sv = ForceCompiler.compileSieve(field: field, particle: grain, targets: targets,
                                                outside: { onShapeDistance($0) >= 1.5e-3 }, options: o, start: mold.drives,
                                                iterations: iters, log: debugLog)
            drives = sv.drives
            log(String(format: "  sieve compile: lift contrast %.2f (from the wells mold's %.2f)", sv.contrast, sv.contrastAtStart))
        }
    } else {
        let fun = ForceCompiler.compileFunnel(field: field, particle: grain, targets: snapped,
                                              capture: 0.75e-3, release: inRelease, softness: 0.5e-3, start: start,
                                              iterations: iters, log: debugLog)
        drives = fun.drives
        log(String(format: "  funnel: U falls toward the nearest site through %.0f%% of the release volume (the start: %.0f%%)",
                   100 * fun.funnelled, 100 * fun.funnelledAtStart))
    }
    var ev = evaluate(drives)
    if objective == "sieve" && setup.feedback > 0 {
        // Basin-map feedback: weight the sites that get less than their fair
        // share up (√ of the shortfall, clamped), recompile from the last
        // drive, keep the best. What the machine would do with a scan.
        var siteW = [Double](repeating: 1, count: targets.count)
        var last = drives
        for round in 1...setup.feedback {
            for q in siteW.indices {
                siteW[q] *= min(4, max(0.5, (fairShare / max(ev.perSite[q], 0.1 * fairShare)).squareRoot()))
            }
            let mean = siteW.reduce(0, +) / Double(siteW.count)
            siteW = siteW.map { $0 / mean }
            let sv = ForceCompiler.compileSieve(field: field, particle: grain, targets: targets,
                                                outside: { onShapeDistance($0) >= 1.5e-3 }, options: o, siteWeights: siteW,
                                                start: last, iterations: max(100, iters / 2), log: debugLog)
            last = sv.drives
            let e2 = evaluate(sv.drives)
            log(String(format: "  feedback round %d: contrast %.2f, %.1f%% on the shape, sites %.1f–%.1f%% (fair %.1f%%)",
                       round, e2.contrast, 100 * e2.onShape, 100 * (e2.perSite.min() ?? 0), 100 * (e2.perSite.max() ?? 0), 100 * fairShare))
            if better(e2, ev) { ev = e2; drives = sv.drives }
        }
    }
    let compileSeconds = Date().timeIntervalSince(t0)
    let U = ev.U
    let em = ForceCompiler.evaluateMold(U, lattice: lat, targets: targets, options: o, wavelength: lam40)
    log(String(format: "  compiled (%@, %.1f s): %d/%d wells formed, rival/weakest %.2f", objective, compileSeconds,
               em.formed, targets.count, em.rivalRatio))
    func grad(_ x: Vec3) -> Vec3? { gradOf(U, x) }
    let contrast = ev.contrast, powerX = ev.powerX, power = ev.power
    log(String(format: "  sieve: the weakest site can lift %.2f× what any point 1.5 mm or more from the shape can%@",
               contrast, contrast > 1 ? " — a power window exists" : " — no window: somewhere else holds a grain first"))
    let gamma = 6 * Double.pi * 1.81e-5 * grain.radius
    let driveRMS = (power / Double(field.channels * nTones)).squareRoot()
    log(String(format: "  drive: %.2f× what holds a grain at the weakest site (%.2f m/s rms per channel); a grain relaxes in %.1f ms; %@; %@",
               powerX, driveRMS, grain.mass() / gamma * 1000,
               setup.gravity ? "gravity on" : "gravity OFF",
               recirculate ? "fallen grains are sprinkled in again at the top" : "fallen grains are lost"))
    var out = MoldOutcome()
    out.driveRMS = driveRMS; out.compileSeconds = compileSeconds; out.channels = field.channels
    let bSite = ev.perSite, bOn = ev.onShape, bRogue = ev.rogue
    out.basinOnShape = bOn; out.basinRogue = bRogue; out.basinPerSite = bSite
    log(String(format: "  basin map: %.1f%% of the release ends on the shape%@, %.1f%% in rogue minima, %.1f%% %@; %d sinks; per-site shares %.1f–%.1f%%",
               100 * bOn, recirculate ? " (with recirculation)" : "", 100 * bRogue,
               100 * max(0, 1 - bOn - bRogue), recirculate ? "never lands" : "falls out",
               ev.sinks, 100 * (bSite.min() ?? 0), 100 * (bSite.max() ?? 0)))
    // --- the powder, stepped (the check) ---
    var perSite = [Int](repeating: 0, count: targets.count)
    out.sitesCSV = "x_mm,y_mm,z_mm,grains,basin_share\n"
    if setup.particles {
        var rng = SplitMix64(seed: 23)
        var xs: [Vec3] = (0..<nGrains).map { _ in
            lat.origin + Vec3(margin + rng.nextUnit() * (2 * hh - 2 * margin), margin + rng.nextUnit() * (2 * hh - 2 * margin),
                              margin + rng.nextUnit() * (2 * hh - 2 * margin))
        }
        var alive = [Bool](repeating: true, count: nGrains)
        let snaps = [0.0, 0.05, 0.15, 0.4, 1.0, 2.0, 4.0, 8.0, 16.0].filter { $0 < setup.seconds } + [setup.seconds]
        out.grainsCSV = "t_s,grain,x_mm,y_mm,z_mm\n"
        out.captureCSV = "t_s,on_shape\n"
        func record(_ t: Double) {
            let on = xs.indices.filter { alive[$0] && onShapeDistance(xs[$0]) <= 1e-3 }.count
            out.captureLog.append(String(format: "%.2g s %.0f%%", t, 100 * Double(on) / Double(nGrains)))
            out.captureCSV += String(format: "%.3f,%.4f\n", t, Double(on) / Double(nGrains))
            for (i, x) in xs.enumerated() where alive[i] {
                out.grainsCSV += String(format: "%.2f,%d,%.3f,%.3f,%.3f\n", t, i, (x.x - centre.x) * 1000, (x.y - centre.y) * 1000, (x.z - centre.z) * 1000)
            }
        }
        record(0)
        let dt = 5e-4
        var t = 0.0
        var nextSnap = 1
        var speed = [Double](repeating: 0, count: nGrains)
        var resprinkled = [Int](repeating: 0, count: nGrains)
        let gravityForce = setup.gravity ? -weight : 0
        while t < snaps.last! - 1e-9 {
            let tNow = t
            xs.withUnsafeMutableBufferPointer { xb in
                alive.withUnsafeMutableBufferPointer { ab in
                    speed.withUnsafeMutableBufferPointer { sb in
                        resprinkled.withUnsafeMutableBufferPointer { rb in
                            DispatchQueue.concurrentPerform(iterations: 32) { ch in
                                for i in (ch * nGrains / 32)..<((ch + 1) * nGrains / 32) where ab[i] {
                                    guard let g = grad(xb[i]) else {
                                        if recirculate {
                                            var r = SplitMix64(seed: UInt64(i) &* 0x9E3779B97F4A7C15 &+ UInt64(tNow * 1e4))
                                            xb[i] = Vec3(lo.x + r.nextUnit() * (hi.x - lo.x), lo.y + r.nextUnit() * (hi.y - lo.y), hi.z)
                                            rb[i] += 1
                                        } else { ab[i] = false }
                                        continue
                                    }
                                    let F = g * (-power) + Vec3(0, 0, gravityForce)
                                    var v = F * (1 / gamma)
                                    let step = v.length * dt
                                    if step > 0.05e-3 { v = v * (0.05e-3 / step) }     // keep a step under 50 µm
                                    xb[i] = xb[i] + v * dt
                                    sb[i] = v.length
                                }
                            }
                        }
                    }
                }
            }
            t += dt
            if nextSnap < snaps.count && t >= snaps[nextSnap] - 1e-9 { record(snaps[nextSnap]); nextSnap += 1 }
        }
        for i in 0..<nGrains where alive[i] {
            let on = onShapeDistance(xs[i]) <= 1e-3
            if on, let q = snapped.indices.min(by: { (snapped[$0] - xs[i]).length < (snapped[$1] - xs[i]).length }) {
                perSite[q] += 1; out.captured += 1
            } else if !on && speed[i] < 0.5e-3 { out.rogue += 1 } else if !on { out.drifting += 1 }
            out.final.append(xs[i]); out.onShape.append(on)
        }
        out.lost = alive.filter { !$0 }.count
        out.resprinkles = resprinkled.reduce(0, +)
        log("  on the shape over time: " + out.captureLog.joined(separator: ", "))
    }
    out.sites = snapped; out.perSite = perSite
    out.contrast = contrast; out.powerX = powerX; out.tones = nTones
    out.formed = em.formed; out.rivalRatio = em.rivalRatio
    for (q, p) in snapped.enumerated() {
        out.sitesCSV += String(format: "%.3f,%.3f,%.3f,%d,%.4f\n", (p.x - centre.x) * 1000, (p.y - centre.y) * 1000,
                               (p.z - centre.z) * 1000, perSite[q], bSite[q])
    }
    let fr = { (k: Int) in 100 * Double(k) / Double(nGrains) }
    let filled = perSite.filter { $0 > 0 }.count
    if setup.particles {
        log(String(format: "after %.0f s: %.0f%% of the powder on the shape (%d sites; %d/%d with grains, %d–%d each), %.0f%% in rogue wells, %.0f%% still drifting, %.0f%% lost%@",
                   setup.seconds, fr(out.captured), targets.count, filled, targets.count, perSite.min() ?? 0, perSite.max() ?? 0,
                   fr(out.rogue), fr(out.drifting), fr(out.lost),
                   recirculate ? String(format: " (%d re-sprinkles, %.1f per grain)", out.resprinkles, Double(out.resprinkles) / Double(nGrains)) : ""))
    }
    let chamberText: String = {
        switch chamber {
        case .glass: return "glass chamber, 6 gates"
        case .plates(let a): return "open air, 2 × \(a.perPlate) elements"
        }
    }()
    out.summary = String(format: "%@; %@ objective, %d tone%@, %.2f× holding, %.2f m/s rms per channel; basin map: %.1f%% on the shape, sites %.1f–%.1f%% (fair %.1f%%), %.1f%% rogue; lift contrast %.2f%@",
                         chamberText, objective, nTones, nTones == 1 ? "" : "s", powerX, driveRMS, 100 * bOn,
                         100 * (bSite.min() ?? 0), 100 * (bSite.max() ?? 0), 100 * fairShare, 100 * bRogue, contrast,
                         setup.particles ? String(format: "; particles: %.1f%% on the shape after %.0f s, %d/%d sites filled (%d–%d)",
                                                  fr(out.captured), setup.seconds, filled, targets.count,
                                                  perSite.min() ?? 0, perSite.max() ?? 0) : "")
    // G-M1/G-M2 on the basin map (exact for the overdamped flow on the lattice);
    // G-B0: the basin map and the stepped grains agree on the share on the shape.
    out.gates = [
        GateResult(id: "G-M1", name: "acoustic mold (\(label)): every site holds ≥ ¼ of its fair share of the powder",
                   measured: (bSite.min() ?? 0) / fairShare, threshold: 0.25, comparison: .greaterThan, detail: out.summary),
        GateResult(id: "G-M2", name: "acoustic mold (\(label)): ≥95% of a random powder cloud ends on the shape (within 1 mm)",
                   measured: bOn, threshold: 0.95, comparison: .greaterThan, detail: out.summary)]
    if setup.particles {
        out.gates.append(GateResult(id: "G-B0", name: "basin map vs stepped grains: the share on the shape agrees",
                                    measured: abs(bOn - Double(out.captured) / Double(nGrains)), threshold: 0.05,
                                    comparison: .lessThan, detail: out.summary))
    }
    return out
}
