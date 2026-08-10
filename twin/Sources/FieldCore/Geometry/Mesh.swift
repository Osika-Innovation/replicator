import Foundation

public struct Triangle: Sendable {
    public var a: Vec3, b: Vec3, c: Vec3
    public init(_ a: Vec3, _ b: Vec3, _ c: Vec3) { self.a = a; self.b = b; self.c = c }
    public var normal: Vec3 { (b - a).cross(c - a).normalized }
    public var centroid: Vec3 { (a + b + c) / 3 }
}

public struct Mesh: Sendable {
    public var triangles: [Triangle]
    public init(triangles: [Triangle]) { self.triangles = triangles }

    public var bounds: (min: Vec3, max: Vec3) {
        guard !triangles.isEmpty else { return (.zero, .zero) }
        var lo = Vec3(.infinity, .infinity, .infinity)
        var hi = Vec3(-.infinity, -.infinity, -.infinity)
        for t in triangles {
            for v in [t.a, t.b, t.c] {
                lo = Vec3(Swift.min(lo.x, v.x), Swift.min(lo.y, v.y), Swift.min(lo.z, v.z))
                hi = Vec3(Swift.max(hi.x, v.x), Swift.max(hi.y, v.y), Swift.max(hi.z, v.z))
            }
        }
        return (lo, hi)
    }

    public var centroid: Vec3 {
        let b = bounds
        return (b.min + b.max) / 2
    }

    public func translated(by d: Vec3) -> Mesh {
        Mesh(triangles: triangles.map { Triangle($0.a + d, $0.b + d, $0.c + d) })
    }

    /// Exact signed volume by the divergence theorem — the reference G1 checks
    /// the voxelizer against for non-analytic meshes.
    public var signedVolume: Double {
        var v = 0.0
        for t in triangles { v += t.a.dot(t.b.cross(t.c)) / 6.0 }
        return abs(v)
    }

    /// An icosphere. Used as the canonical test object because its volume has a
    /// closed form and because the sphere preset needs Mie-comparable geometry.
    public static func sphere(radius: Double, subdivisions: Int = 3) -> Mesh {
        let t = (1.0 + 5.0.squareRoot()) / 2.0
        var verts: [Vec3] = [
            Vec3(-1, t, 0), Vec3(1, t, 0), Vec3(-1, -t, 0), Vec3(1, -t, 0),
            Vec3(0, -1, t), Vec3(0, 1, t), Vec3(0, -1, -t), Vec3(0, 1, -t),
            Vec3(t, 0, -1), Vec3(t, 0, 1), Vec3(-t, 0, -1), Vec3(-t, 0, 1),
        ].map { $0.normalized }
        var faces: [(Int, Int, Int)] = [
            (0,11,5),(0,5,1),(0,1,7),(0,7,10),(0,10,11),
            (1,5,9),(5,11,4),(11,10,2),(10,7,6),(7,1,8),
            (3,9,4),(3,4,2),(3,2,6),(3,6,8),(3,8,9),
            (4,9,5),(2,4,11),(6,2,10),(8,6,7),(9,8,1),
        ]
        for _ in 0..<subdivisions {
            var cache: [String: Int] = [:]
            func midpoint(_ i: Int, _ j: Int) -> Int {
                let key = i < j ? "\(i)_\(j)" : "\(j)_\(i)"
                if let m = cache[key] { return m }
                let m = ((verts[i] + verts[j]) / 2).normalized
                verts.append(m)
                cache[key] = verts.count - 1
                return verts.count - 1
            }
            var next: [(Int, Int, Int)] = []
            next.reserveCapacity(faces.count * 4)
            for (a, b, c) in faces {
                let ab = midpoint(a, b), bc = midpoint(b, c), ca = midpoint(c, a)
                next.append((a, ab, ca)); next.append((b, bc, ab))
                next.append((c, ca, bc)); next.append((ab, bc, ca))
            }
            faces = next
        }
        return Mesh(triangles: faces.map {
            Triangle(verts[$0.0] * radius, verts[$0.1] * radius, verts[$0.2] * radius)
        })
    }

    public static func cube(side: Double) -> Mesh {
        let h = side / 2
        let p = [Vec3(-h,-h,-h), Vec3(h,-h,-h), Vec3(h,h,-h), Vec3(-h,h,-h),
                 Vec3(-h,-h,h), Vec3(h,-h,h), Vec3(h,h,h), Vec3(-h,h,h)]
        let quads = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(2,3,7,6),(1,2,6,5),(0,4,7,3)]
        var tris: [Triangle] = []
        for (a,b,c,d) in quads {
            tris.append(Triangle(p[a], p[b], p[c]))
            tris.append(Triangle(p[a], p[c], p[d]))
        }
        return Mesh(triangles: tris)
    }
}
