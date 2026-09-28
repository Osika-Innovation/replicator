import Foundation

/// Solid generators. Every one returns a closed, outward-oriented
/// `IndexedMesh` with shared vertices — the properties the CAD gates check.
public enum Solid {

    /// Arc segments for a radius, targeting a chord deviation of `tol` mm.
    /// Clamped so small features stay round and big shells stay light.
    public static func segments(radius r: Double, sweepDeg: Double = 360,
                                tol: Double = 0.05, minSeg: Int = 12,
                                maxSeg: Int = 480) -> Int {
        guard r > 0 else { return minSeg }
        let dTheta = 2 * acos(max(-1, min(1, 1 - tol / r)))
        let n = Int((sweepDeg * .pi / 180 / max(dTheta, 1e-6)).rounded(.up))
        return min(maxSeg, max(minSeg, n))
    }

    // MARK: - Revolve

    /// Revolve a closed (r, z) profile about the z axis.
    ///
    /// - The profile may touch the axis (r = 0): those vertices collapse to a
    ///   single pole, and the adjoining quads degenerate to triangles.
    /// - `fromDeg...toDeg` less than a full turn produces planar end caps
    ///   (triangulated from the profile), so partial solids — the glass
    ///   half-cylinders, a curved display — are closed too.
    public static func revolve(_ profileIn: [P2], segments nIn: Int? = nil,
                               fromDeg: Double = 0, toDeg: Double = 360) -> IndexedMesh {
        var profile = profileIn
        // Interior on the left walking the profile in (r, z) ⇔ CCW.
        if signedArea(profile) < 0 { profile.reverse() }
        let sweep = toDeg - fromDeg
        let full = abs(sweep - 360) < 1e-9
        let rMax = profile.map(\.x).max() ?? 1
        let n = nIn ?? segments(radius: rMax, sweepDeg: sweep)
        let rings = full ? n : n + 1
        var m = IndexedMesh()
        let np = profile.count
        // index[i][j] for profile vertex i at angle j
        var idx = [[Int32]](repeating: [], count: np)
        for i in 0..<np {
            let p = profile[i]
            if p.x <= 1e-12 {
                let pole = m.add(Vec3(0, 0, p.y))
                idx[i] = [Int32](repeating: pole, count: rings)
            } else {
                var row: [Int32] = []
                row.reserveCapacity(rings)
                for j in 0..<rings {
                    let t = (fromDeg + sweep * Double(j) / Double(n)) * .pi / 180
                    row.append(m.add(Vec3(p.x * cos(t), p.x * sin(t), p.y)))
                }
                idx[i] = row
            }
        }
        for i in 0..<np {
            let i2 = (i + 1) % np
            for j in 0..<n {
                let j2 = full ? (j + 1) % n : j + 1
                let a = idx[i][j], b = idx[i2][j], c = idx[i2][j2], d = idx[i][j2]
                // outward for a CCW (r, z) profile: (A, D, C) and (A, C, B)
                m.tri(a, d, c)
                m.tri(a, c, b)
            }
        }
        if !full {
            // End caps: the profile itself, at both ends.
            let tri = Earcut.triangulate(outer: profile)
            for k in stride(from: 0, to: tri.count, by: 3) {
                let i0 = Int(tri[k]), i1 = Int(tri[k + 1]), i2 = Int(tri[k + 2])
                // Orientation in (r, z): make it CCW, then place it.
                let a = profile[i0], b = profile[i1], c = profile[i2]
                let ccw = (b - a).cross(c - a) > 0
                let (u0, u1, u2) = ccw ? (i0, i1, i2) : (i0, i2, i1)
                // A CCW triangle in (r, z) has 3-D normal e_r × e_z = -e_theta:
                // the start cap (facing -theta) keeps it, the end cap reverses.
                m.tri(idx[u0][0], idx[u1][0], idx[u2][0])
                m.tri(idx[u0][rings - 1], idx[u2][rings - 1], idx[u1][rings - 1])
            }
        }
        return m
    }

    /// Hollow cylinder (tube) r0..r1 × z0..z1, optionally a sector.
    public static func tube(r0: Double, r1: Double, z0: Double, z1: Double,
                            fromDeg: Double = 0, toDeg: Double = 360,
                            segments n: Int? = nil) -> IndexedMesh {
        if r0 <= 0 {
            return revolve([P2(0, z0), P2(r1, z0), P2(r1, z1), P2(0, z1)],
                           segments: n, fromDeg: fromDeg, toDeg: toDeg)
        }
        return revolve([P2(r0, z0), P2(r1, z0), P2(r1, z1), P2(r0, z1)],
                       segments: n, fromDeg: fromDeg, toDeg: toDeg)
    }

    /// Torus: major radius R, minor radius a, centred at height zc.
    public static func torus(R: Double, a: Double, zc: Double,
                             tubeSegments: Int = 40, ringSegments: Int? = nil) -> IndexedMesh {
        var prof: [P2] = []
        for i in 0..<tubeSegments {
            let t = 2 * Double.pi * Double(i) / Double(tubeSegments)
            prof.append(P2(R + a * cos(t), zc + a * sin(t)))
        }
        return revolve(prof, segments: ringSegments ?? segments(radius: R + a, tol: 0.08))
    }

    // MARK: - Extrude

    /// Straight extrusion of an outline with holes from z0 to z1.
    public static func extrude(outer outerIn: [P2], holes holesIn: [[P2]] = [],
                               z0: Double, z1: Double) -> IndexedMesh {
        var outer = outerIn
        if signedArea(outer) < 0 { outer.reverse() }
        let holes = holesIn.map { signedArea($0) > 0 ? Array($0.reversed()) : $0 }
        var m = IndexedMesh()
        var bot: [Int32] = [], top: [Int32] = []
        func ringVerts(_ ring: [P2]) {
            for p in ring {
                bot.append(m.add(Vec3(p.x, p.y, z0)))
                top.append(m.add(Vec3(p.x, p.y, z1)))
            }
        }
        ringVerts(outer)
        for h in holes { ringVerts(h) }
        // caps
        let tri = Earcut.triangulate(outer: outer, holes: holes)
        let all = outer + holes.flatMap { $0 }
        for k in stride(from: 0, to: tri.count, by: 3) {
            var i0 = Int(tri[k]), i1 = Int(tri[k + 1]), i2 = Int(tri[k + 2])
            if (all[i1] - all[i0]).cross(all[i2] - all[i0]) < 0 { swap(&i1, &i2) }
            m.tri(top[i0], top[i1], top[i2])          // +z
            m.tri(bot[i0], bot[i2], bot[i1])          // -z
        }
        // side walls: outer ring CCW → outward; holes CW → normals into hole
        var start = 0
        for ring in [outer] + holes {
            let n = ring.count
            for i in 0..<n {
                let a = start + i, b = start + (i + 1) % n
                m.quad(bot[a], bot[b], top[b], top[a])
            }
            start += n
        }
        return m
    }

    /// Axis-aligned-in-z box, rotated about z by `azDeg`, centred at `c`.
    public static func box(center c: Vec3, size s: Vec3, azDeg: Double = 0) -> IndexedMesh {
        let hx = s.x / 2, hy = s.y / 2
        let outline = [P2(-hx, -hy), P2(hx, -hy), P2(hx, hy), P2(-hx, hy)]
        return extrude(outer: outline, z0: c.z - s.z / 2, z1: c.z + s.z / 2)
            .rotatedZ(azDeg)
            .translated(Vec3(c.x, c.y, 0))
    }

    /// Disc-shaped cylinder with its axis along an arbitrary direction.
    public static func cylinder(base: Vec3, axis: Vec3, radius: Double,
                                length: Double, segments n: Int = 32) -> IndexedMesh {
        let local = tube(r0: 0, r1: radius, z0: 0, z1: length, segments: n)
        return local.transformed { orient($0, along: axis) + base }
    }

    /// Map a local-frame point (local +z = `axis`) into the world frame.
    static func orient(_ v: Vec3, along axisIn: Vec3) -> Vec3 {
        let w = axisIn.normalized
        var u = Vec3(0, 0, 1).cross(w)
        if u.length < 1e-9 { u = Vec3(1, 0, 0) } else { u = u.normalized }
        if w.z < -0.999999 { return Vec3(v.x, -v.y, -v.z) }
        if w.z > 0.999999 { return v }
        let vv = w.cross(u)
        return u * v.x + vv * v.y + w * v.z
    }

    // MARK: - Sweep

    /// A closed tube of radius `radius` along a closed polyline.
    ///
    /// Frames by the double-reflection rotation-minimizing method (Wang et
    /// al. 2008), then the closure twist is spread evenly along the loop so
    /// the last ring meets the first without a seam — which is what makes a
    /// wound conductor a closed solid rather than a tube with a crack in it.
    public static func sweepClosed(path: [Vec3], radius: Double, sides: Int = 10) -> IndexedMesh {
        let n = path.count
        precondition(n >= 3)
        var T = [Vec3](repeating: .zero, count: n)
        for i in 0..<n { T[i] = (path[(i + 1) % n] - path[(i - 1 + n) % n]).normalized }
        var R = [Vec3](repeating: .zero, count: n + 1)
        var r0 = T[0].cross(Vec3(0, 0, 1))
        if r0.length < 1e-6 { r0 = T[0].cross(Vec3(1, 0, 0)) }
        R[0] = r0.normalized
        for i in 0..<n {
            let xi = path[i], xj = path[(i + 1) % n]
            let ti = T[i], tj = T[(i + 1) % n]
            let v1 = xj - xi
            let c1 = v1.dot(v1)
            guard c1 > 1e-18 else { R[i + 1] = R[i]; continue }
            let rL = R[i] - v1 * (2 / c1 * v1.dot(R[i]))
            let tL = ti - v1 * (2 / c1 * v1.dot(ti))
            let v2 = tj - tL
            let c2 = v2.dot(v2)
            R[i + 1] = c2 > 1e-18 ? (rL - v2 * (2 / c2 * v2.dot(rL))).normalized : rL.normalized
        }
        // closure twist: angle from transported R[n] back to R[0] about T[0]
        let s0 = T[0].cross(R[0])
        let twist = atan2(R[n].dot(s0), R[n].dot(R[0]))
        var m = IndexedMesh()
        var rings: [[Int32]] = []
        for i in 0..<n {
            let corr = -twist * Double(i) / Double(n)
            let t = T[i]
            let r = R[i]
            let s = t.cross(r)
            let rr = r * cos(corr) + s * sin(corr)
            let ss = t.cross(rr)
            var ring: [Int32] = []
            for k in 0..<sides {
                let a = 2 * Double.pi * Double(k) / Double(sides)
                ring.append(m.add(path[i] + rr * (radius * cos(a)) + ss * (radius * sin(a))))
            }
            rings.append(ring)
        }
        for i in 0..<n {
            let a = rings[i], b = rings[(i + 1) % n]
            for k in 0..<sides {
                let k2 = (k + 1) % sides
                m.quad(a[k], b[k], b[k2], a[k2])
            }
        }
        // Orientation depends on frame handedness; fix globally.
        if m.signedVolume < 0 { m.faces = m.faces.map { SIMD3($0.x, $0.z, $0.y) } }
        return m
    }

    // MARK: - Outlines

    public static func circle(_ c: P2, _ r: Double, segments n: Int) -> [P2] {
        (0..<n).map { i in
            let t = 2 * Double.pi * Double(i) / Double(n)
            return P2(c.x + r * cos(t), c.y + r * sin(t))
        }
    }
}
