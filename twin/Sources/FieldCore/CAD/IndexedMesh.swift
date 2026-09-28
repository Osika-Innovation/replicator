import Foundation

/// A 2-D point, for profiles (r, z) and plan-view outlines (x, y).
public struct P2: Sendable, Equatable, Codable {
    public var x: Double, y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    public static func + (a: P2, b: P2) -> P2 { P2(a.x + b.x, a.y + b.y) }
    public static func - (a: P2, b: P2) -> P2 { P2(a.x - b.x, a.y - b.y) }
    public static func * (a: P2, s: Double) -> P2 { P2(a.x * s, a.y * s) }
    public var length: Double { (x * x + y * y).squareRoot() }
    public var normalized: P2 { let l = length; return l > 0 ? P2(x / l, y / l) : self }
    public func dot(_ b: P2) -> Double { x * b.x + y * b.y }
    public func cross(_ b: P2) -> Double { x * b.y - y * b.x }
}

/// Signed area of a closed 2-D polygon (positive = counter-clockwise).
public func signedArea(_ poly: [P2]) -> Double {
    guard poly.count >= 3 else { return 0 }
    var a = 0.0
    for i in poly.indices {
        let p = poly[i], q = poly[(i + 1) % poly.count]
        a += p.x * q.y - q.x * p.y
    }
    return a / 2
}

/// Indexed triangle mesh — the CAD kernel's solid representation.
///
/// The simulation side of FieldCore works on triangle soups (`Mesh`), which is
/// all a voxelizer needs. CAD needs more: a solid is only a solid if it is
/// CLOSED (every edge shared by exactly two faces) and CONSISTENTLY ORIENTED
/// (outward normals, positive divergence-theorem volume). Those two properties
/// can only be checked on shared vertices, so every generator in this module
/// builds its topology with shared indices by construction — the watertight
/// gate then tests the construction, not a float-welding heuristic.
///
/// Units: millimetres, machine frame (floor at z = 0, axis along z, front = +x).
public struct IndexedMesh: Sendable {
    public var vertices: [Vec3]
    public var faces: [SIMD3<Int32>]

    public init(vertices: [Vec3] = [], faces: [SIMD3<Int32>] = []) {
        self.vertices = vertices; self.faces = faces
    }

    public var triangleCount: Int { faces.count }

    @discardableResult
    public mutating func add(_ v: Vec3) -> Int32 {
        vertices.append(v)
        return Int32(vertices.count - 1)
    }

    public mutating func tri(_ a: Int32, _ b: Int32, _ c: Int32) {
        if a == b || b == c || a == c { return }      // collapsed at a pole
        faces.append(SIMD3(a, b, c))
    }

    /// Quad a-b-c-d (counter-clockwise seen from outside).
    public mutating func quad(_ a: Int32, _ b: Int32, _ c: Int32, _ d: Int32) {
        tri(a, b, c); tri(a, c, d)
    }

    public mutating func append(_ other: IndexedMesh) {
        let base = Int32(vertices.count)
        vertices.append(contentsOf: other.vertices)
        faces.append(contentsOf: other.faces.map { $0 &+ SIMD3(repeating: base) })
    }

    public func transformed(_ f: (Vec3) -> Vec3) -> IndexedMesh {
        IndexedMesh(vertices: vertices.map(f), faces: faces)
    }

    public func translated(_ d: Vec3) -> IndexedMesh { transformed { $0 + d } }

    /// Rotation about the machine axis (z) by `deg` degrees.
    public func rotatedZ(_ deg: Double) -> IndexedMesh {
        let c: Double = cos(deg * .pi / 180), s: Double = sin(deg * .pi / 180)
        return transformed { (v: Vec3) -> Vec3 in
            let x: Double = c * v.x - s * v.y
            let y: Double = s * v.x + c * v.y
            return Vec3(x, y, v.z)
        }
    }

    /// Mirror through the plane z = z0. Reverses winding so normals stay outward.
    public func mirroredZ(about z0: Double) -> IndexedMesh {
        IndexedMesh(vertices: vertices.map { Vec3($0.x, $0.y, 2 * z0 - $0.z) },
                    faces: faces.map { SIMD3($0.x, $0.z, $0.y) })
    }

    /// Mirror through the plane y = 0. Reverses winding so normals stay outward.
    public func mirroredY() -> IndexedMesh {
        IndexedMesh(vertices: vertices.map { Vec3($0.x, -$0.y, $0.z) },
                    faces: faces.map { SIMD3($0.x, $0.z, $0.y) })
    }

    public var bounds: (min: Vec3, max: Vec3) {
        guard let f = vertices.first else { return (.zero, .zero) }
        var lo = f, hi = f
        for v in vertices {
            lo = Vec3(Swift.min(lo.x, v.x), Swift.min(lo.y, v.y), Swift.min(lo.z, v.z))
            hi = Vec3(Swift.max(hi.x, v.x), Swift.max(hi.y, v.y), Swift.max(hi.z, v.z))
        }
        return (lo, hi)
    }

    /// Signed volume by the divergence theorem. Positive for a closed mesh
    /// with outward normals — the orientation half of the watertight gate.
    public var signedVolume: Double {
        var v = 0.0
        for f in faces {
            let a = vertices[Int(f.x)], b = vertices[Int(f.y)], c = vertices[Int(f.z)]
            v += a.dot(b.cross(c))
        }
        return v / 6
    }

    public var surfaceArea: Double {
        var s = 0.0
        for f in faces {
            let a = vertices[Int(f.x)], b = vertices[Int(f.y)], c = vertices[Int(f.z)]
            s += (b - a).cross(c - a).length / 2
        }
        return s
    }

    /// Area-weighted centroid of the enclosed volume (tetrahedra from origin).
    public var volumeCentroid: Vec3 {
        var acc = Vec3.zero, vol = 0.0
        for f in faces {
            let a = vertices[Int(f.x)], b = vertices[Int(f.y)], c = vertices[Int(f.z)]
            let v = a.dot(b.cross(c)) / 6
            acc += (a + b + c) * (v / 4)
            vol += v
        }
        return vol != 0 ? acc / vol : .zero
    }

    /// Triangle soup for the simulation side (voxelizer, STL writer).
    public var soup: Mesh {
        Mesh(triangles: faces.map {
            Triangle(vertices[Int($0.x)], vertices[Int($0.y)], vertices[Int($0.z)])
        })
    }

    // MARK: - Topology

    public struct Topology: Sendable {
        /// Undirected edges used by exactly two faces in opposite directions.
        public var manifoldEdges = 0
        /// Edges used by one face only — holes in the surface.
        public var boundaryEdges = 0
        /// Edges used by more than two faces, or twice in the same direction.
        public var badEdges = 0
        public var degenerateFaces = 0
        public var isClosed: Bool { boundaryEdges == 0 && badEdges == 0 }
    }

    /// Edge census on the shared-index topology.
    public func topology() -> Topology {
        var directed: [UInt64: Int32] = [:]
        directed.reserveCapacity(faces.count * 3)
        var t = Topology()
        for f in faces {
            if f.x == f.y || f.y == f.z || f.x == f.z { t.degenerateFaces += 1; continue }
            for (a, b) in [(f.x, f.y), (f.y, f.z), (f.z, f.x)] {
                let key = (UInt64(UInt32(a)) << 32) | UInt64(UInt32(b))
                directed[key, default: 0] += 1
            }
        }
        var seen = Set<UInt64>()
        for (key, n) in directed {
            let a = UInt32(key >> 32), b = UInt32(key & 0xffff_ffff)
            let lo = min(a, b), hi = max(a, b)
            let und = (UInt64(lo) << 32) | UInt64(hi)
            if seen.contains(und) { continue }
            seen.insert(und)
            let rev = directed[(UInt64(b) << 32) | UInt64(a)] ?? 0
            if n == 1 && rev == 1 { t.manifoldEdges += 1 }
            else if n + rev == 1 { t.boundaryEdges += 1 }
            else { t.badEdges += 1 }
        }
        return t
    }

    /// Merge vertices closer than `tolerance` (mm). Generators share indices
    /// by construction; this exists for imported geometry and as a check that
    /// a generator did not leave duplicate seam vertices behind.
    public func welded(tolerance: Double = 1e-6) -> IndexedMesh {
        var map = [Int32](repeating: 0, count: vertices.count)
        var buckets: [SIMD3<Int64>: Int32] = [:]
        var out: [Vec3] = []
        let inv = 1 / tolerance
        for (i, v) in vertices.enumerated() {
            let key = SIMD3<Int64>(Int64((v.x * inv).rounded()),
                                   Int64((v.y * inv).rounded()),
                                   Int64((v.z * inv).rounded()))
            if let j = buckets[key] { map[i] = j } else {
                out.append(v)
                let j = Int32(out.count - 1)
                buckets[key] = j
                map[i] = j
            }
        }
        var faces2: [SIMD3<Int32>] = []
        faces2.reserveCapacity(faces.count)
        for f in faces {
            let g = SIMD3(map[Int(f.x)], map[Int(f.y)], map[Int(f.z)])
            if g.x != g.y && g.y != g.z && g.x != g.z { faces2.append(g) }
        }
        return IndexedMesh(vertices: out, faces: faces2)
    }

    // MARK: - Shading normals

    /// Per-corner normals with a crease angle: faces meeting at less than
    /// `creaseDeg` are smoothed (cylinders read round), sharper edges stay
    /// crisp (a machined plate reads machined). Returns (positions, normals)
    /// de-indexed per triangle corner, ready to upload.
    public func shadingCorners(creaseDeg: Double = 38) -> (positions: [Vec3], normals: [Vec3]) {
        let cosCrease = cos(creaseDeg * .pi / 180)
        var faceN = [Vec3](repeating: .zero, count: faces.count)
        var incident = [[Int32]](repeating: [], count: vertices.count)
        for (fi, f) in faces.enumerated() {
            let a = vertices[Int(f.x)], b = vertices[Int(f.y)], c = vertices[Int(f.z)]
            let n = (b - a).cross(c - a)      // area-weighted
            faceN[fi] = n
            incident[Int(f.x)].append(Int32(fi))
            incident[Int(f.y)].append(Int32(fi))
            incident[Int(f.z)].append(Int32(fi))
        }
        var pos: [Vec3] = [], nor: [Vec3] = []
        pos.reserveCapacity(faces.count * 3); nor.reserveCapacity(faces.count * 3)
        for (fi, f) in faces.enumerated() {
            let own = faceN[fi].normalized
            for vi in [f.x, f.y, f.z] {
                var acc = Vec3.zero
                for g in incident[Int(vi)] {
                    let n = faceN[Int(g)]
                    if n.normalized.dot(own) >= cosCrease { acc += n }
                }
                pos.append(vertices[Int(vi)])
                nor.append(acc.length > 0 ? acc.normalized : own)
            }
        }
        return (pos, nor)
    }
}
