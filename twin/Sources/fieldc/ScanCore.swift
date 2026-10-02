import FieldCore
import FieldGPU
import Foundation

// Scanning as functions, so `fieldc scan3d` and `fieldc replicate` share the
// physics. By reciprocity a small scatterer at x couples gate j to gate i
// through what each gate's field does there:
//     ΔT_ij(f) ∝ −(f1/3) k²a³ p_i(x) p_j(x) − (f2/2) a³ ∇p_i(x)·∇p_j(x)
// (the chamber-only transfer is calibrated away). An object is a cloud of such
// scatterers — the Born approximation for a cloud, the coupled solve for a few
// beads. The image is the matched field, the data correlated at every grid
// point with what a point scatterer there would have produced:
//     I(x) = |Σ_f Σ_ij M_ij(x,f)* ΔT_ij(f)| / (Σ|M|²)^½.

struct ScanSetup {
    var fLo = 30_000.0
    var fHi = 100_000.0
    var frequencies = 90
    var snrDB = 40.0
    var seed: UInt64 = 17
}

/// The matched-field image of `object` on `grid`, normalised to its peak.
func scanImage(ctx: MetalContext, object: [Vec3], subunit: Double, grid: FieldLattice, setup: ScanSetup,
               log: (String) -> Void = { print($0) }) throws -> [Double] {
    let t0 = Date()
    let air = RH1Freestanding.roomAir
    let L = RH1Design().buildChamberHeight * 0.001
    let cav = RH1Freestanding.chamber(maxGamma: {
        let k = air.wavenumber(at: setup.fHi), e = Foundation.log(1e4) / 0.1
        return (k * k + e * e).squareRoot() }())
    let top = grid.origin.z + Double(grid.nz - 1) * grid.spacing
    let zMin = max(0.1, min(grid.origin.z, L - top))
    let coupled = object.count <= 40
    var image = [Complex](repeating: .zero, count: grid.count)
    var norm = [Double](repeating: 0, count: grid.count)
    var rng = SplitMix64(seed: setup.seed)
    func gauss() -> Double {                            // Box–Muller
        let u1 = max(rng.nextUnit(), 1e-300), u2 = rng.nextUnit()
        return (-2 * Foundation.log(u1)).squareRoot() * cos(2 * Double.pi * u2)
    }
    let a3 = subunit * subunit * subunit
    let nF = setup.frequencies
    for q in 0..<nF {
        let f = setup.fLo + (setup.fHi - setup.fLo) * Double(q) / Double(max(1, nF - 1))
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
        let sigma = rms * pow(10, -setup.snrDB / 20) / 2.0.squareRoot()
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
        if q % 15 == 0 { log(String(format: "  %.1f kHz done (%.0f s)", f / 1000, Date().timeIntervalSince(t0))) }
    }
    let I = zip(image, norm).map { $0.0.magnitude / max($0.1, 1e-300).squareRoot() }
    let peak = max(I.max() ?? 1, 1e-300)
    return I.map { $0 / peak }
}

/// Maximum-intensity projections of an image (peak 1) for the figures:
/// rows "view,i,j,value" for xy, xz and yz.
func mipCSV(_ I: [Double], grid: FieldLattice) -> String {
    let n = grid.nx
    var csv = "view,i,j,value\n"
    for (view, axes) in [("xy", (0, 1, 2)), ("xz", (0, 2, 1)), ("yz", (1, 2, 0))] {
        var mip = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
        for k2 in 0..<n { for j2 in 0..<n { for i2 in 0..<n {
            let v = I[grid.index(i2, j2, k2)]
            let idx = [i2, j2, k2]
            mip[idx[axes.0]][idx[axes.1]] = max(mip[idx[axes.0]][idx[axes.1]], v)
        } } }
        for u in 0..<n { for w in 0..<n { csv += "\(view),\(u),\(w),\(String(format: "%.4f", mip[u][w]))\n" } }
    }
    return csv
}

/// Read a shape off an image (peak 1): the brightest voxel is a site, then the
/// brightest one at least `spacing` from every site taken, and so on down to
/// `threshold`; two sites closer than 1.8 spacing are joined when the image
/// stays bright along the segment between them (its mean ≥ 0.6 threshold).
/// A site left unjoined is kept as a lone point.
func extractShape(image I: [Double], grid: FieldLattice, threshold: Double,
                  spacing: Double, within: (Vec3) -> Bool = { _ in true }) -> (sites: [Vec3], segments: [(Vec3, Vec3)]) {
    let order = I.indices.filter { I[$0] >= threshold && within(grid.positions[$0]) }.sorted { I[$0] > I[$1] }
    var sites: [Vec3] = []
    for n in order {
        let x = grid.positions[n]
        if sites.allSatisfy({ ($0 - x).length >= spacing }) { sites.append(x) }
    }
    // Sub-voxel: each site moves to the brightness-weighted centroid of the
    // voxels within 1.2 mm that are at least 70 % as bright as its peak. On a
    // wire the patch is symmetric along the wire, so this lands on its
    // centreline; snapped to the 0.7 mm grid, sites of an 8 mm ring sat at
    // radii 7.6–8.1 mm and the ones pulled inward got no powder.
    let r = 1.2e-3, steps = Int((r / grid.spacing).rounded(.up))
    sites = sites.map { x in
        let f = (x - grid.origin) / grid.spacing
        let ci = Int(f.x.rounded()), cj = Int(f.y.rounded()), ck = Int(f.z.rounded())
        let peak = I[grid.index(ci, cj, ck)]
        var sum = Vec3(0, 0, 0), w = 0.0
        for dk in -steps...steps { for dj in -steps...steps { for di in -steps...steps {
            let i = ci + di, j = cj + dj, k = ck + dk
            guard i >= 0, j >= 0, k >= 0, i < grid.nx, j < grid.ny, k < grid.nz else { continue }
            let p = grid.position(i, j, k)
            guard (p - x).length <= r else { continue }
            let v = I[grid.index(i, j, k)] - 0.7 * peak
            if v > 0 { sum = sum + p * v; w += v }
        } } }
        return w > 0 ? sum * (1 / w) : x
    }
    var segments: [(Vec3, Vec3)] = []
    var joined = [Bool](repeating: false, count: sites.count)
    for a in sites.indices {
        for b in (a + 1)..<max(a + 1, sites.count) where (sites[a] - sites[b]).length < 1.8 * spacing {
            let m = max(2, Int(((sites[a] - sites[b]).length / grid.spacing).rounded()))
            let mean = (0...m).reduce(0.0) { acc, q in
                acc + ForceCompiler.interpolate(I, lattice: grid, at: sites[a] + (sites[b] - sites[a]) * (Double(q) / Double(m)))
            } / Double(m + 1)
            if mean >= 0.6 * threshold { segments.append((sites[a], sites[b])); joined[a] = true; joined[b] = true }
        }
    }
    for a in sites.indices where !joined[a] { segments.append((sites[a], sites[a])) }
    return (sites, segments)
}

/// Pearson correlation of two images.
func pearson(_ a: [Double], _ b: [Double]) -> Double {
    let n = Double(a.count)
    let ma = a.reduce(0, +) / n, mb = b.reduce(0, +) / n
    var sab = 0.0, saa = 0.0, sbb = 0.0
    for i in a.indices {
        let da = a[i] - ma, db = b[i] - mb
        sab += da * db; saa += da * da; sbb += db * db
    }
    return sab / max((saa * sbb).squareRoot(), 1e-300)
}

// MARK: - Scanning in open air (ENGINE.md, study S3)

struct ArrayScanSetup {
    var fLo = 30_000.0
    var fHi = 100_000.0
    /// Frequencies, evenly spaced: Δf sets the time window 1/Δf, which must
    /// hold the direct echoes without the plate bounces wrapping onto them.
    var frequencies = 320
    /// Coded pulses: each chord drives every element of ONE plate with a
    /// random phase, the same pattern at every frequency; the plates alternate.
    var chords = 8
    var snrDB = 40.0
    var seed: UInt64 = 17
    /// Keep only the direct echoes (time gate); false = the whole response.
    var gate = true
    /// Listen on both plates (the direct path through the volume to the far
    /// plate arrives in the same window as the direct echo, and carries the
    /// forward scattering of surfaces that do not face the firing plate);
    /// false = the firing plate only.
    var listenBoth = false
}

/// The matched-field image of `object` (small rigid scatterers of radius
/// `subunit`) on `grid`, seen by the open-air plate array, normalised to its
/// peak. Pulse-echo, one plate at a time: a coded pulse (a random phase per
/// element, the same at every frequency) fires one plate and that plate
/// listens. The plates reflect (R 0.9), so a scatterer's echo also comes back
/// by way of the other plate — plate → scatterer → far plate → home, a path
/// of 2L whatever the scatterer's height — which carries no depth and smeared
/// the image ~10 mm along z. So the echo is time-gated: the spectrum each
/// element receives is taken to the time domain, cut to the window where the
/// direct echoes from the work volume arrive, and taken back. Then the gated
/// echo is sent back time-reversed and correlated at every grid point with
/// the outgoing field the way a point scatterer there would couple them:
///     I(x) = |Σ_{f,pulse} cM f(x) b(x) + cD ∇f(x)·∇b(x)|,
/// the matched filter rₓᴴ r. Two forward passes over the grid per pulse and
/// frequency; nothing stored.
func scanImageArray(ctx: MetalContext, array: PlateArray, object: [Vec3], subunit: Double, grid: FieldLattice,
                    setup: ArrayScanSetup, log: (String) -> Void = { print($0) }) throws -> [Double] {
    let t0 = Date()
    let air = RH1Freestanding.roomAir
    let nF = setup.frequencies
    let df = (setup.fHi - setup.fLo) / Double(max(1, nF - 1))
    let freqs = (0..<nF).map { setup.fLo + df * Double($0) }
    let field = try ArrayFieldGPU(ctx: ctx, array: array, frequencies: freqs, medium: air,
                                  lattice: FieldLattice(origin: grid.origin, spacing: grid.spacing, nx: 1, ny: 1, nz: 1))
    let gridPts = grid.positions.map { SIMD4(Float($0.x), Float($0.y), Float($0.z), 0) }
    var acc = [Complex](repeating: .zero, count: grid.count)
    var rng = SplitMix64(seed: setup.seed)
    func gauss() -> Double {
        let u1 = max(rng.nextUnit(), 1e-300), u2 = rng.nextUnit()
        return (-2 * Foundation.log(u1)).squareRoot() * cos(2 * Double.pi * u2)
    }
    let a3 = subunit * subunit * subunit
    let C = array.channels, half = C / 2
    let c0 = air.soundSpeed
    // The direct-echo window for a plate: from the nearest work-volume point
    // straight back, to the farthest point by way of the plate's rim.
    let gridHalf = Double(grid.nx - 1) / 2 * grid.spacing
    let centre = grid.origin + Vec3(gridHalf, gridHalf, gridHalf)
    let reach = gridHalf * 3.0.squareRoot()
    let W = 1 / df                                           // time window of the frequency grid
    var logged = false
    for q in 0..<setup.chords {
        let side = q % 2
        let mine = (side * half)..<((side + 1) * half)
        let zPlate = side == 0 ? 0.0 : array.gap
        let D = abs(centre.z - zPlate)
        let tA = 2 * max(0, D - reach) / c0 - 20e-6
        let tB = 2 * ((D + reach) * (D + reach) + array.plateRadius * array.plateRadius).squareRoot() / c0 + 20e-6
        if !logged {
            log(String(format: "  echo gate %.2f–%.2f ms (the first plate bounce arrives at %.2f ms); time window %.2f ms",
                       tA * 1000, tB * 1000, 2 * array.gap / c0 * 1000, W * 1000))
            logged = true
        }
        var d = [Complex](repeating: .zero, count: C)
        for e in mine { d[e] = Complex.expi(2 * Double.pi * rng.nextUnit()) * (1 / Double(half).squareRoot()) }
        // 1. What this plate hears, at every frequency, with noise.
        var R = [[Complex]](repeating: [Complex](repeating: .zero, count: C), count: nF)
        for (t, f) in freqs.enumerated() {
            let k = air.wavenumber(at: f)
            var r = try field.scattered(by: object, monopole: -k * k * a3 / 3, dipole: -a3 / 2, drive: d, tone: t)
            let ears: [Int] = setup.listenBoth ? Array(0..<C) : Array(mine)
            if !setup.listenBoth { for e in 0..<C where !mine.contains(e) { r[e] = .zero } }
            let rms = (ears.reduce(0.0) { $0 + r[$1].magnitudeSquared } / Double(ears.count)).squareRoot()
            let sigma = rms * pow(10, -setup.snrDB / 20) / 2.0.squareRoot()
            for e in ears { r[e] += Complex(gauss() * sigma, gauss() * sigma) }
            R[t] = r
        }
        // 2. Time gate per element: to the time domain over the band, keep the
        //    direct-echo window (raised-cosine edges), and back.
        if setup.gate {
            let earsG: [Int] = setup.listenBoth ? Array(0..<C) : Array(mine)
            let gate: [Double] = (0..<nF).map { m in
                let tm = Double(m) * W / Double(nF)
                let edge = 30e-6
                if tm < tA - edge || tm > tB + edge { return 0 }
                if tm < tA { return 0.5 * (1 + cos(Double.pi * (tA - tm) / edge)) }
                if tm > tB { return 0.5 * (1 + cos(Double.pi * (tm - tB) / edge)) }
                return 1
            }
            let tw = (0..<nF).map { Complex.expi(-2 * Double.pi * Double($0) / Double(nF)) }
            for e in earsG {
                var sig = [Complex](repeating: .zero, count: nF)
                for m in 0..<nF where gate[m] > 0 {
                    var v = Complex.zero
                    for i in 0..<nF { v += R[i][e] * tw[(i * m) % nF] }
                    sig[m] = v * gate[m]
                }
                for i in 0..<nF {
                    var v = Complex.zero
                    for m in 0..<nF where gate[m] > 0 { v += sig[m] * tw[(nF - (i * m) % nF) % nF] }
                    R[i][e] = v * (1 / Double(nF))
                }
            }
        }
        // 3. Send the echo back time-reversed and correlate on the grid.
        for (t, f) in freqs.enumerated() {
            let k = air.wavenumber(at: f)
            let cM = -k * k * a3 / 3, cD = -a3 / 2
            let fi = try field.fields(d, tone: t, points: gridPts)
            let fb = try field.fields(R[t].map { $0.conjugate }, tone: t, points: gridPts)
            acc.withUnsafeMutableBufferPointer { ab in
                DispatchQueue.concurrentPerform(iterations: 64) { ch in
                    for n in (ch * grid.count / 64)..<((ch + 1) * grid.count / 64) {
                        let b = n * 4
                        var v = fi[b] * fb[b] * cM
                        for c in 1...3 { v += fi[b + c] * fb[b + c] * cD }
                        ab[n] += v
                    }
                }
            }
        }
        log(String(format: "  pulse %d/%d (%@ plate) done (%.0f s)", q + 1, setup.chords, side == 0 ? "lower" : "upper",
                   Date().timeIntervalSince(t0)))
    }
    let I = acc.map { $0.magnitude }
    let peak = max(I.max() ?? 1, 1e-300)
    return I.map { $0 / peak }
}

/// Resample a read shape at even spacing. The scan's sites sit where the
/// image peaked — irregularly (3.2–5.3 mm apart on a ring read at 3 mm), and
/// uneven spacing lets neighbouring sites steal each other's powder. Keep the
/// shape, not the peaks: junctions and ends (sites with ≠ 2 neighbours) stay
/// where they are; every chain between them, and every closed loop, is walked
/// and sampled at equal arc length, about `spacing` apart.
func resampleShape(sites: [Vec3], segments: [(Vec3, Vec3)], spacing: Double) -> (sites: [Vec3], segments: [(Vec3, Vec3)]) {
    func idx(_ p: Vec3) -> Int? { sites.firstIndex { ($0 - p).length < 1e-9 } }
    var adj = [[Int]](repeating: [], count: sites.count)
    for (a, b) in segments {
        guard let i = idx(a), let j = idx(b), i != j else { continue }
        if !adj[i].contains(j) { adj[i].append(j); adj[j].append(i) }
    }
    var outSites: [Vec3] = [], outSegs: [(Vec3, Vec3)] = []
    func add(_ p: Vec3) -> Vec3 {
        if let q = outSites.first(where: { ($0 - p).length < 1e-9 }) { return q }
        outSites.append(p); return p
    }
    var usedEdge = Set<Int>()                      // i * count + j, i < j
    func key(_ i: Int, _ j: Int) -> Int { min(i, j) * sites.count + max(i, j) }
    func sample(_ chain: [Vec3], closed: Bool) {
        var pts = chain
        if closed { pts.append(chain[0]) }
        var lens = [0.0]
        for q in 1..<pts.count { lens.append(lens[q - 1] + (pts[q] - pts[q - 1]).length) }
        let total = lens.last!
        let n = max(1, Int((total / spacing).rounded()))
        var placed: [Vec3] = []
        let count = closed ? n : n + 1
        for m in 0..<count {
            let s = total * Double(m) / Double(n)
            var q = 1
            while q < pts.count - 1 && lens[q] < s { q += 1 }
            let seg = lens[q] - lens[q - 1]
            let u = seg > 0 ? (s - lens[q - 1]) / seg : 0
            placed.append(add(pts[q - 1] + (pts[q] - pts[q - 1]) * u))
        }
        for m in 1..<placed.count { outSegs.append((placed[m - 1], placed[m])) }
        if closed && placed.count > 2 { outSegs.append((placed.last!, placed[0])) }
    }
    let anchors = sites.indices.filter { adj[$0].count != 2 }
    // Chains from every anchor.
    for a in anchors {
        if adj[a].isEmpty { _ = add(sites[a]); continue }
        for b0 in adj[a] where !usedEdge.contains(key(a, b0)) {
            var chain = [sites[a]], prev = a, cur = b0
            usedEdge.insert(key(a, b0))
            while true {
                chain.append(sites[cur])
                if adj[cur].count != 2 { break }
                guard let nxt = adj[cur].first(where: { $0 != prev }), !usedEdge.contains(key(cur, nxt)) else { break }
                usedEdge.insert(key(cur, nxt))
                prev = cur; cur = nxt
            }
            sample(chain, closed: false)
        }
    }
    // Closed loops (every site has two neighbours).
    for s0 in sites.indices where adj[s0].count == 2 {
        guard let b0 = adj[s0].first(where: { !usedEdge.contains(key(s0, $0)) }) else { continue }
        var chain = [sites[s0]], prev = s0, cur = b0
        usedEdge.insert(key(s0, b0))
        while cur != s0 {
            chain.append(sites[cur])
            guard let nxt = adj[cur].first(where: { $0 != prev }) else { break }
            if usedEdge.contains(key(cur, nxt)) { break }
            usedEdge.insert(key(cur, nxt))
            prev = cur; cur = nxt
        }
        sample(chain, closed: true)
    }
    return (outSites, outSegs)
}
