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
                  spacing: Double) -> (sites: [Vec3], segments: [(Vec3, Vec3)]) {
    let order = I.indices.filter { I[$0] >= threshold }.sorted { I[$0] > I[$1] }
    var sites: [Vec3] = []
    for n in order {
        let x = grid.positions[n]
        if sites.allSatisfy({ ($0 - x).length >= spacing }) { sites.append(x) }
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
    var frequencies = 24
    /// Random chords per frequency: every element driven at unit amplitude
    /// with a random phase — many known, mutually distinct illuminations.
    var chords = 16
    var snrDB = 40.0
    var seed: UInt64 = 17
}

/// The matched-field image of `object` (small rigid scatterers of radius
/// `subunit`) on `grid`, seen by the open-air plate array, normalised to its
/// peak. For each frequency and random chord d: the elements receive the
/// object's echo r (Born, by reciprocity, plus measurement noise); r is sent
/// back conjugated (time reversal) as the drive b; and at every grid point
/// the outgoing field f and the returning field b are correlated the way a
/// point scatterer there would couple them,
///     I(x) = |Σ_{f,d} cM f(x) b(x) + cD ∇f(x)·∇b(x)|,
/// which is rₓᴴ r, the matched filter, summed over the illuminations. Two
/// forward passes over the grid per chord; nothing stored.
func scanImageArray(ctx: MetalContext, array: PlateArray, object: [Vec3], subunit: Double, grid: FieldLattice,
                    setup: ArrayScanSetup, log: (String) -> Void = { print($0) }) throws -> [Double] {
    let t0 = Date()
    let air = RH1Freestanding.roomAir
    let nF = setup.frequencies
    let freqs = (0..<nF).map { setup.fLo + (setup.fHi - setup.fLo) * Double($0) / Double(max(1, nF - 1)) }
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
    let C = array.channels
    for (t, f) in freqs.enumerated() {
        let k = air.wavenumber(at: f)
        let cM = -k * k * a3 / 3, cD = -a3 / 2
        for _ in 0..<setup.chords {
            let d = (0..<C).map { _ in Complex.expi(2 * Double.pi * rng.nextUnit()) * (1 / Double(C).squareRoot()) }
            var r = try field.scattered(by: object, monopole: cM, dipole: cD, drive: d, tone: t)
            let rms = (r.reduce(0) { $0 + $1.magnitudeSquared } / Double(C)).squareRoot()
            let sigma = rms * pow(10, -setup.snrDB / 20) / 2.0.squareRoot()
            r = r.map { $0 + Complex(gauss() * sigma, gauss() * sigma) }
            let fi = try field.fields(d, tone: t, points: gridPts)
            let fb = try field.fields(r.map { $0.conjugate }, tone: t, points: gridPts)
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
        if t % 6 == 0 { log(String(format: "  %.1f kHz done (%.0f s)", f / 1000, Date().timeIntervalSince(t0))) }
    }
    let I = acc.map { $0.magnitude }
    let peak = max(I.max() ?? 1, 1e-300)
    return I.map { $0 / peak }
}
