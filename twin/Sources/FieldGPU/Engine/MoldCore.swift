import FieldCore
import Foundation

// The single-shot acoustic mold as a function, so `fieldc mold`, `fieldc
// arraysweep` and `fieldc replicate` run the same physics: compile one chord
// drive for a shape (sites joined by segments), release a random cloud of
// powder through the probe volume, and see where it ends in that field, with
// gravity.
//
// The chamber is `.plates(array)`: two plates in open air, each N independently
// driven elements, matrix-free on the GPU (ENGINE.md).
//
// Where the powder ends is computed twice: by the basin map (every start's
// destination at once, recirculation in closed form) and by stepping 3,000
// grains (the check, gate G-B0).

public enum MoldChamber {
    case plates(PlateArray)
}

public struct MoldSetup {
    public var objective = "sieve"          // sieve | wells | funnel
    public var tones: Int? = nil            // nil: 40 for the glass sieve, 9 for the plates, 20 otherwise
    public var band: (lo: Double, hi: Double)? = nil   // Hz; nil: 50–100 kHz
    public var grains = 3000
    public var iterations: Int? = nil       // nil: 400 for the sieve, 300 otherwise
    public var seconds = 8.0
    public var powerX: Double? = nil        // nil: the sieve's window middle, else 4×
    public var recirculate: Bool? = nil     // nil: on for the sieve
    public var gravity = true
    public var particles = true             // step grains as well as the basin map
    /// Basin-map feedback rounds for the sieve: weight the sites that get too
    /// little powder up and recompile from the last drive.
    public var feedback = 0
    public var debug = false
    /// Resonant elements: the most one element may be asked for, as a
    /// multiple of the rms over all of them (`ArrayFieldGPU.amplitudeCap`).
    public var amplitudeCap: Double? = 1.1
    /// Resonant elements: the drive as a multiple of what holds a grain at
    /// the weakest site. The elements' ceiling leaves no room for the middle
    /// of the power window (√contrast), so the mold runs near its lower edge.
    public var resonantHolding = 1.15
    /// A tolerance study: the compiled drive, at the power the drawing asked
    /// for, played on each of these builds of the plates in their own air
    /// (results in `MoldOutcome.builds`); the gates still judge the drawing.
    public var builds: [(name: String, array: PlateArray, medium: Medium)] = []
    /// Keep the stepped grains' positions every this many seconds (nil: only the end).
    public var frameEvery: Double? = nil
    public init() {}
}

public struct MoldOutcome {
    public var sites: [Vec3] = []
    public var perSite: [Int] = []
    public var final: [Vec3] = []
    public var onShape: [Bool] = []
    public var captured = 0, rogue = 0, drifting = 0, lost = 0, resprinkles = 0
    public var contrast = 0.0, powerX = 0.0, tones = 0, channels = 0
    public var formed = 0, rivalRatio = 0.0
    /// Basin map: share of the release on the shape (with recirculation if on),
    /// per-site shares, rogue share.
    /// Per-site shares by the 26-neighbour lattice map (`BasinMap`), kept
    /// beside the traced flow's (`basinPerSite`) so the two can be compared.
    public var latticePerSite: [Double] = []
    public var basinOnShape = 0.0, basinRogue = 0.0
    public var basinPerSite: [Double] = []
    /// Root-mean-square over every (channel, tone) entry of the velocity
    /// amplitudes (peak, m/s) — one tone's share on one element.
    public var driveRMS = 0.0
    /// Per element: the root-sum-square of its tones' velocity amplitudes
    /// (peak, m/s); ÷ √2 is its rms velocity in time. With resonant elements
    /// it is simply the amplitude at the element's tone.
    public var elementAmplitude: [Double] = []
    /// The compiled drives (unit total power), the drive power that scales them
    /// (Σ|v|², (m/s)²) and the tones — what a light view or a replay needs.
    public var drives: [[Complex]] = []
    public var power = 0.0
    public var frequencies: [Double] = []
    public var compileSeconds = 0.0
    public var grainsCSV = "", sitesCSV = "", captureCSV = ""
    /// What a viewer needs: the probe lattice, the compiled potential on it
    /// (per unit drive power; × `power` = joules), the grain weight (N), and
    /// the stepped grains' positions over time (`MoldSetup.frameEvery`).
    public var lattice: FieldLattice? = nil
    public var potential: [Double] = []
    public var grainWeight = 0.0
    public var frames: [(t: Double, x: [Vec3])] = []
    /// Every sink of the basin map: where it is, its share, the site it counts for.
    public var sinksCSV = ""
    public var captureLog: [String] = []
    public var gates: [GateResult] = []
    /// `MoldSetup.builds`, played: the share on the shape, the emptiest and
    /// fullest site's share ÷ a fair share, and how many times a grain's
    /// weight the weakest site lifts at the drawing's power.
    public var builds: [(name: String, onShape: Double, siteMin: Double, siteMax: Double, weakestLift: Double)] = []
    public var summary = ""
    public init() {}
}

/// Distance from x to a shape given as segments (a segment from a point to
/// itself is a lone site).
public func shapeDistance(_ x: Vec3, _ segments: [(Vec3, Vec3)]) -> Double {
    segments.reduce(Double.infinity) { m, s in
        let d = s.1 - s.0
        let dd = d.dot(d)
        let u = dd > 0 ? max(0, min(1, (x - s.0).dot(d) / dd)) : 0
        return min(m, (x - (s.0 + d * u)).length)
    }
}

public func runMold(ctx: MetalContext, label: String, sites targetPts: [Vec3], segments: [(Vec3, Vec3)],
             chamber: MoldChamber, setup: MoldSetup, log: @escaping (String) -> Void = { print($0) }) throws -> MoldOutcome {
    let air = RH1Freestanding.roomAir
    let L: Double
    switch chamber {
    case .plates(let a): L = a.gap
    }
    let lam40 = air.wavelength(at: 40_000)
    let centre = Vec3(0, 0, L / 2)
    let objective = setup.objective
    let isPlates: Bool = { if case .plates = chamber { return true }; return false }()
    // Defaults: the glass sieve's 40 tones; for the plates the nine tones of
    // the channel sweep (S1), which it ran over 30–70 kHz.
    let lockedTones: [Double]? = { if case .plates(let a) = chamber { return a.tones }; return nil }()
    let nTones = lockedTones?.count ?? setup.tones ?? (isPlates ? 9 : (objective == "sieve" ? 40 : 20))
    // 50–100 kHz: the top of what the elements play. Neighbouring sites fill
    // evenly only when the field can tell them apart, and 3.1 mm (the 16-site
    // ring) needs the short wavelengths: at 32–68 kHz the powder gathered in
    // every other site (10 of 16 filled, 0–17 % per site); at 53–97 kHz every
    // site holds 5.3–7.0 % (fair 6.2 %) with the ring at 0°, 5° and 11.25°,
    // and the tetrahedron 7.4–12.7 % (fair 10 %). The lift contrast doubles as
    // well (3.1 against 1.6). 51–95 kHz already loses two sites; 60–100 keeps
    // them at contrast 1.8. Traced flow, 2026-11-10 (README, Round 16).
    let band = setup.band ?? (50_000.0, 100_000.0)
    let nGrains = setup.grains
    let freqs: [Double] = lockedTones ?? (0..<nTones).map { q in
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
    case .plates(let arr):
        let gpu = try ArrayFieldGPU(ctx: ctx, array: arr, frequencies: freqs, medium: air, lattice: lat)
        if arr.toneOf != nil {
            // Resonant elements share one velocity ceiling: no element far above the rest.
            gpu.amplitudeCap = setup.amplitudeCap
        }
        field = gpu
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
            g = gpu.playable(g, tone: start.count)
            let nrm = g.reduce(0.0) { $0 + $1.magnitudeSquared }.squareRoot()
            start.append(g.map { $0 * (1 / (max(nrm, 1e-300) * Double(nTones).squareRoot())) })
        }
        if let m = arr.toneOf {
            log("  resonant elements: each plays one of \(nTones) tones (\(m.filter { $0 == 0 }.count) elements on the first)")
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
        var sinkList: [(x: Vec3, share: Double, site: Int)] = []
        var latticePerSite: [Double] = []
    }
    // Starts for the traced flow: the release box's cells, then its top layer.
    var boxStarts: [Vec3] = [], topStarts: [Vec3] = []
    for k in releaseCells.2 { for j in releaseCells.1 { for i in releaseCells.0 {
        boxStarts.append(lat.position(i, j, k))
        if k == releaseCells.2.upperBound { topStarts.append(lat.position(i, j, k)) }
    } } }
    func evaluate(_ drives: [[Complex]]) -> Eval { evaluate(drives, on: field, fixedPower: nil) }
    func evaluate(_ drives: [[Complex]], on field: any ForceCompiler.ForceField, fixedPower: Double?) -> Eval {
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
        let middle = contrast > 1 ? contrast.squareRoot() : 1.05
        let powerX = setup.powerX ?? (objective == "sieve" ? (lockedTones == nil ? middle : min(middle, setup.resonantHolding)) : 4.0)
        let power = fixedPower ?? powerX * weight / max(fUpMin, 1e-300)
        // The lattice map (26-neighbour steepest descent), for comparison only:
        // it cannot follow a streamline, so its per-site shares are not the grains'.
        let basins = BasinMap(U: U, lattice: lat, power: power, weight: setup.gravity ? weight : 0, release: releaseCells)
        var lSite = [Double](repeating: 0, count: targets.count)
        for (sink, w) in (recirculate ? basins.recirculated : basins.direct) {
            let x = lat.positions[sink]
            if onShapeDistance(x) <= 1e-3, let q = snapped.indices.min(by: { (snapped[$0] - x).length < (snapped[$1] - x).length }) { lSite[q] += w }
        }
        // The traced flow: where each release cell's grain actually ends.
        let ends = FlowMap.trace(U: U, lattice: lat, power: power, weight: setup.gravity ? weight : 0, starts: boxStarts + topStarts,
                                 maxSteps: 20_000, drag: 6 * Double.pi * 1.81e-5 * grain.radius, duration: setup.seconds)
        let landed = FlowMap.shares(box: Array(ends[..<boxStarts.count]), top: Array(ends[boxStarts.count...]), recirculate: recirculate)
        var bSite = [Double](repeating: 0, count: targets.count)
        var bOn = 0.0, bRogue = 0.0
        var cells: [Int: (x: Vec3, share: Double, site: Int)] = [:]
        for (x, w) in landed {
            var site = -1
            if onShapeDistance(x) <= 1e-3, let q = snapped.indices.min(by: { (snapped[$0] - x).length < (snapped[$1] - x).length }) {
                bSite[q] += w; bOn += w; site = q
            } else { bRogue += w }
            // Resting points gathered per lattice cell: the "sinks" of the flow.
            let f = (x - lat.origin) / h
            let c = lat.index(Int(f.x.rounded()), Int(f.y.rounded()), Int(f.z.rounded()))
            if let e = cells[c] { cells[c] = (e.x, e.share + w, e.site) } else { cells[c] = (x, w, site) }
        }
        return Eval(U: U, contrast: contrast, fUpMin: fUpMin, powerX: powerX, power: power,
                    onShape: bOn, rogue: bRogue, perSite: bSite, sinks: cells.count, sinkList: Array(cells.values),
                    latticePerSite: lSite)
    }
    let fairShare = 1 / Double(max(1, targets.count))
    // Prefer: everything on the shape (≥ 95 %), then the most sites holding a
    // quarter of their fair share, then the fullest weakest site, then the
    // most on the shape.
    func better(_ a: Eval, _ b: Eval) -> Bool {
        let aOK = a.onShape >= 0.95, bOK = b.onShape >= 0.95
        if aOK != bOK { return aOK }
        let af = a.perSite.filter { $0 >= 0.25 * fairShare }.count, bf = b.perSite.filter { $0 >= 0.25 * fairShare }.count
        if af != bf { return af > bf }
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
    func filledSites(_ e: Eval) -> Int { e.perSite.filter { $0 >= 0.25 * fairShare }.count }
    log(String(format: "  first compile: %.1f%% on the shape, %d/%d sites with a quarter of their share, sites %.1f–%.1f%% (fair %.1f%%)",
               100 * ev.onShape, filledSites(ev), targets.count, 100 * (ev.perSite.min() ?? 0), 100 * (ev.perSite.max() ?? 0), 100 * fairShare))
    if objective == "sieve" && setup.feedback > 0 {
        // Basin-map feedback: weight the sites that get less than their fair
        // share up (√ of the shortfall, clamped), recompile from the last
        // drive, keep the best. What the machine would do with a scan.
        var siteW = [Double](repeating: 1, count: targets.count)
        var last = drives
        var latest = ev                       // multiplicative weights follow the LATEST map
        for round in 1...setup.feedback {
            for q in siteW.indices {
                siteW[q] *= min(2, max(0.5, (fairShare / max(latest.perSite[q], 0.1 * fairShare)).squareRoot()))
            }
            let mean = siteW.reduce(0, +) / Double(siteW.count)
            siteW = siteW.map { $0 / mean }
            let sv = ForceCompiler.compileSieve(field: field, particle: grain, targets: targets,
                                                outside: { onShapeDistance($0) >= 1.5e-3 }, options: o, siteWeights: siteW,
                                                returnLast: true, start: last, iterations: max(100, iters / 2), log: debugLog)
            last = sv.drives
            let e2 = evaluate(sv.drives)
            latest = e2
            log(String(format: "  feedback round %d: contrast %.2f, %.1f%% on the shape, %d/%d sites filled, sites %.1f–%.1f%% (fair %.1f%%)",
                       round, e2.contrast, 100 * e2.onShape, filledSites(e2), targets.count, 100 * (e2.perSite.min() ?? 0), 100 * (e2.perSite.max() ?? 0), 100 * fairShare))
            if better(e2, ev) { ev = e2; drives = sv.drives }
        }
    }
    let compileSeconds = Date().timeIntervalSince(t0)
    var builds: [(name: String, onShape: Double, siteMin: Double, siteMax: Double, weakestLift: Double)] = []
    for b in setup.builds {
        let built = try ArrayFieldGPU(ctx: ctx, array: b.array, frequencies: freqs, medium: b.medium, lattice: lat)
        let e = evaluate(drives, on: built, fixedPower: ev.power)
        builds.append((b.name, e.onShape, (e.perSite.min() ?? 0) / fairShare, (e.perSite.max() ?? 0) / fairShare, e.fUpMin * e.power / weight))
        log(String(format: "  %@: %.1f%% on the shape, sites %.2f–%.2f of a fair share, weakest site lifts %.2f× a grain",
                   b.name, 100 * e.onShape, builds.last!.siteMin, builds.last!.siteMax, builds.last!.weakestLift))
    }
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
    out.builds = builds
    out.driveRMS = driveRMS; out.compileSeconds = compileSeconds; out.channels = field.channels
    let unit = drives.map { $0.reduce(0.0) { $0 + $1.magnitudeSquared } }.reduce(0, +)
    out.elementAmplitude = (0..<field.channels).map { e in
        (drives.reduce(0.0) { $0 + $1[e].magnitudeSquared } / max(unit, 1e-300) * power).squareRoot()
    }
    var elementGates: [GateResult] = []
    if case .plates(let arr) = chamber {
        let scale = (power / max(unit, 1e-300)).squareRoot()
        elementGates = ElementGates.drive(amplitudes: drives.map { $0.map { $0.magnitude * scale } }, frequencies: freqs,
                                          pistonRadius: { arr.pistonRadius($0) }, spec: { e, _ in arr.spec(e, medium: air) },
                                          medium: air, label: label)
        for g in elementGates { log("  " + g.line) }
    }
    let eaMax = out.elementAmplitude.max() ?? 0
    let eaRMS = (out.elementAmplitude.reduce(0.0) { $0 + $1 * $1 } / Double(max(1, field.channels))).squareRoot()
    log(String(format: "  per element (all its tones together): velocity amplitude %.2f m/s rms over the elements, %.2f m/s the largest", eaRMS, eaMax))
    out.drives = drives; out.power = power; out.frequencies = freqs
    let bSite = ev.perSite, bOn = ev.onShape, bRogue = ev.rogue
    out.basinOnShape = bOn; out.basinRogue = bRogue; out.basinPerSite = bSite
    out.lattice = lat; out.potential = ev.U; out.grainWeight = weight
    out.latticePerSite = ev.latticePerSite
    out.sinksCSV = "x_mm,y_mm,z_mm,share,site\n" + ev.sinkList.sorted { $0.share > $1.share }.map {
        String(format: "%.3f,%.3f,%.3f,%.5f,%d", ($0.x.x - centre.x) * 1000, ($0.x.y - centre.y) * 1000, ($0.x.z - centre.z) * 1000, $0.share, $0.site)
    }.joined(separator: "\n") + "\n"
    log(String(format: "  traced flow: %.1f%% of the release ends on the shape%@, %.1f%% in rogue minima, %.1f%% %@; %d resting cells; per-site shares %.1f–%.1f%% (the 26-neighbour lattice map says %.1f–%.1f%%)",
               100 * bOn, recirculate ? " (with recirculation)" : "", 100 * bRogue,
               100 * max(0, 1 - bOn - bRogue), recirculate ? "never lands" : "falls out",
               ev.sinks, 100 * (bSite.min() ?? 0), 100 * (bSite.max() ?? 0),
               100 * (ev.latticePerSite.min() ?? 0), 100 * (ev.latticePerSite.max() ?? 0)))
    // --- the powder, stepped (the check) ---
    var perSite = [Int](repeating: 0, count: targets.count)
    out.sitesCSV = "x_mm,y_mm,z_mm,grains,basin_share,lattice_share\n"
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
        if setup.frameEvery != nil { out.frames.append((0, xs)) }
        var nextFrame = setup.frameEvery ?? .infinity
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
            if t >= nextFrame - 1e-9 { out.frames.append((t, xs)); nextFrame += setup.frameEvery ?? .infinity }
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
        out.sitesCSV += String(format: "%.3f,%.3f,%.3f,%d,%.4f,%.4f\n", (p.x - centre.x) * 1000, (p.y - centre.y) * 1000,
                               (p.z - centre.z) * 1000, perSite[q], bSite[q], ev.latticePerSite[q])
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
        case .plates(let a): return "open air, 2 × \(a.perPlate) elements"
        }
    }()
    out.summary = String(format: "%@; %@ objective, %d tone%@, %.2f× holding, %.2f m/s rms per channel; traced flow: %.1f%% on the shape, sites %.1f–%.1f%% (fair %.1f%%), %.1f%% rogue; lift contrast %.2f%@",
                         chamberText, objective, nTones, nTones == 1 ? "" : "s", powerX, driveRMS, 100 * bOn,
                         100 * (bSite.min() ?? 0), 100 * (bSite.max() ?? 0), 100 * fairShare, 100 * bRogue, contrast,
                         setup.particles ? String(format: "; particles: %.1f%% on the shape after %.0f s, %d/%d sites filled (%d–%d)",
                                                  fr(out.captured), setup.seconds, filled, targets.count,
                                                  perSite.min() ?? 0, perSite.max() ?? 0) : "")
    // G-M1/G-M2 on the traced flow (`FlowMap`: the streamlines the stepped
    // grains follow, without the clock). Until 2026-11-10 they were judged on
    // the 26-neighbour lattice map, whose per-site shares are not the grains'.
    // G-B0: the traced flow and the stepped grains agree on the share on the
    // shape; G-B1: and site by site.
    out.gates = [
        GateResult(id: "G-M1", name: "acoustic mold (\(label)): every site holds ≥ ¼ of its fair share of the powder",
                   measured: (bSite.min() ?? 0) / fairShare, threshold: 0.25, comparison: .greaterThan, detail: out.summary),
        GateResult(id: "G-M2", name: "acoustic mold (\(label)): ≥95% of a random powder cloud ends on the shape (within 1 mm)",
                   measured: bOn, threshold: 0.95, comparison: .greaterThan, detail: out.summary)]
    out.gates += elementGates
    if setup.particles {
        out.gates.append(GateResult(id: "G-B0", name: "traced flow vs stepped grains: the share on the shape agrees",
                                    measured: abs(bOn - Double(out.captured) / Double(nGrains)), threshold: 0.05,
                                    comparison: .lessThan, detail: out.summary))
        let worst = bSite.indices.map { abs(bSite[$0] - Double(perSite[$0]) / Double(nGrains)) }.max() ?? 0
        let latticeWorst = bSite.indices.map { abs(ev.latticePerSite[$0] - Double(perSite[$0]) / Double(nGrains)) }.max() ?? 0
        out.gates.append(GateResult(id: "G-B1", name: "traced flow vs stepped grains, site by site (largest difference in share)",
                                    measured: worst, threshold: 0.03, comparison: .lessThan,
                                    detail: String(format: "%d grains, fair share %.1f%%; the 26-neighbour lattice map differs by up to %.1f%%",
                                                   nGrains, 100 * fairShare, 100 * latticeWorst)))
    }
    return out
}
