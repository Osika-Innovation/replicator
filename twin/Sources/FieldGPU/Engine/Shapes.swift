import FieldCore
import Foundation

/// The mold's test shapes around a centre: sites, and the segments joining them.
public func moldShape(_ shape: String, centre: Vec3, ringSites: Int = 16) -> ([Vec3], [(Vec3, Vec3)]) {
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
        // Sites on a horizontal ring, 8 mm radius (16: 3.1 mm apart).
        let m = ringSites
        sites = (0..<m).map { q in
            let th = 2 * Double.pi * Double(q) / Double(m)
            return centre + Vec3(8e-3 * cos(th), 8e-3 * sin(th), 0)
        }
        segments = (0..<m).map { (sites[$0], sites[($0 + 1) % m]) }
    }
    return (sites, segments)
}

/// The scan's test objects around a centre: scatterer points, the scatterer
/// radius, and the image grid (half-width, spacing).
public func scanObject(_ name: String, centre: Vec3) -> ([Vec3], Double, Double, Double) {
    func segment(_ a: Vec3, _ b: Vec3, _ step: Double) -> [Vec3] {
        let m = max(1, Int(((b - a).length / step).rounded()))
        return (0...m).map { a + (b - a) * (Double($0) / Double(m)) }
    }
    var object: [Vec3] = []
    var subunit = 0.3e-3
    var half = 24e-3, h = 1.25e-3
    switch name {
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
    case "point":
        // One small scatterer off the centre: the scan's point-spread.
        object = [centre + Vec3(3e-3, 2e-3, 1e-3)]
        half = 8e-3; h = 0.4e-3
    case "ring":
        // A wire ring, 8 mm radius, in the mid-plane, scatterers every 1 mm.
        object = (0..<50).map { q in
            let th = 2 * Double.pi * Double(q) / 50
            return centre + Vec3(8e-3 * cos(th), 8e-3 * sin(th), 0)
        }
        half = 14e-3; h = 0.7e-3
    default:
        // A regular tetrahedron wireframe, 30 mm edges, sampled every 1.5 mm.
        let e = 30e-3
        let v = [Vec3(0, 0, 0), Vec3(e, 0, 0), Vec3(e / 2, e * 3.0.squareRoot() / 2, 0),
                 Vec3(e / 2, e * 3.0.squareRoot() / 6, e * (2.0 / 3).squareRoot())]
        let c = (v[0] + v[1] + v[2] + v[3]) * 0.25
        for i in 0..<4 { for j in (i + 1)..<4 { object += segment(v[i], v[j], 1.5e-3).map { centre + $0 - c } } }
        var seen: [Vec3] = []
        for p0 in object where !seen.contains(where: { ($0 - p0).length < 1e-6 }) { seen.append(p0) }
        object = seen
    }
    return (object, subunit, half, h)
}

// MARK: - Shapes read from a mesh: the app's objects and `fieldc mold --stl`

/// Points spread evenly over a mesh's surface: area-weighted samples, then
/// farthest-point selection, stopping at `count` or when the next point
/// would be closer than `minSpacing` to one already chosen.
public func meshPoints(_ mesh: Mesh, count: Int, minSpacing: Double, relax: Bool = true) -> [Vec3] {
    var rng = SplitMix64(seed: 7)
    let areas = mesh.triangles.map { (($0.b - $0.a).cross($0.c - $0.a)).length / 2 }
    let total = areas.reduce(0, +)
    guard total > 0 else { return [] }
    var cum: [Double] = []; var acc = 0.0
    for a in areas { acc += a; cum.append(acc) }
    var cands: [Vec3] = []
    for _ in 0..<20000 {
        let r = rng.nextUnit() * total
        var lo = 0, hi = cum.count - 1
        while lo < hi { let m = (lo + hi) / 2; if cum[m] < r { lo = m + 1 } else { hi = m } }
        let t = mesh.triangles[lo]
        var u = rng.nextUnit(), v = rng.nextUnit()
        if u + v > 1 { u = 1 - u; v = 1 - v }
        cands.append(t.a + (t.b - t.a) * u + (t.c - t.a) * v)
    }
    var picked = [cands[0]]
    var d = cands.map { ($0 - cands[0]).length }
    while picked.count < count {
        guard let best = d.indices.max(by: { d[$0] < d[$1] }), d[best] >= minSpacing else { break }
        picked.append(cands[best])
        for i in d.indices { d[i] = min(d[i], (cands[i] - cands[best]).length) }
    }
    guard relax else { return picked }
    // Even them out (Lloyd): every sample goes to its nearest point, every
    // point to the middle of its samples. Farthest-point picks alone sit
    // between one and two spacings apart, and the mold fills sites evenly
    // only when they are evenly spaced (a ring's 16 sites: 0–14 % per site
    // from the raw picks). On a wire the middle of a patch of surface is
    // the wire's axis, which is where a grain should rest.
    for _ in 0..<400 {
        var sum = [Vec3](repeating: Vec3(0, 0, 0), count: picked.count)
        var n = [Int](repeating: 0, count: picked.count)
        for c in cands {
            var bi = 0, bd = Double.infinity
            for (i, p) in picked.enumerated() { let dd = (p - c).length; if dd < bd { bd = dd; bi = i } }
            sum[bi] = sum[bi] + c; n[bi] += 1
        }
        for i in picked.indices where n[i] > 0 { picked[i] = sum[i] * (1 / Double(n[i])) }
    }
    return picked
}

/// Join every site to the neighbours within 1.35 × the typical spacing.
public func meshSegments(joining sites: [Vec3]) -> [(Vec3, Vec3)] {
    guard sites.count > 1 else { return sites.map { ($0, $0) } }
    let nn = sites.indices.map { i in sites.indices.filter { $0 != i }.map { (sites[$0] - sites[i]).length }.min() ?? 0 }
    let reach = 1.35 * nn.sorted()[nn.count / 2]
    var out: [(Vec3, Vec3)] = []
    for i in sites.indices { for j in (i + 1)..<sites.count where (sites[i] - sites[j]).length <= reach {
        out.append((sites[i], sites[j]))
    } }
    return out.isEmpty ? sites.map { ($0, $0) } : out
}

/// An object placed for the mold: centred on `centre`, and shrunk if it does
/// not fit the probe volume (±`fitHalf` round the centre; the powder is
/// released 2 mm inside the ±12 mm probe box).
public func meshInMold(_ raw: Mesh, centre c: Vec3, fitHalf: Double = 9.5e-3) -> (mesh: Mesh, scale: Double) {
    let b = raw.bounds
    let size = b.max - b.min
    let mid = (b.min + b.max) / 2
    let halfMax = max(size.x, size.y, size.z) / 2
    let scale = halfMax > fitHalf ? fitHalf / halfMax : 1
    return (Mesh(triangles: raw.triangles.map {
        Triangle(c + ($0.a - mid) * scale, c + ($0.b - mid) * scale, c + ($0.c - mid) * scale)
    }), scale)
}
