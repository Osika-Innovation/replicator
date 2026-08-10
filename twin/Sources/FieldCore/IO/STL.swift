import Foundation

/// STL reader/writer. Binary and ASCII on read, binary on write.
///
/// Hand-rolled per the zero-dependency ruling (§8). ModelIO could do this, but
/// it drags in a heavier framework for a 60-line format and gives less control
/// over malformed files, which real-world STLs frequently are.
public enum STL {

    public enum Error: Swift.Error, CustomStringConvertible {
        case tooShort
        case badTriangleCount(declared: Int, available: Int)
        case noTriangles

        public var description: String {
            switch self {
            case .tooShort: return "file is too short to be an STL"
            case .badTriangleCount(let d, let a):
                return "header declares \(d) triangles, file holds \(a)"
            case .noTriangles: return "no triangles found"
            }
        }
    }

    public static func read(contentsOf url: URL) throws -> Mesh {
        try read(Data(contentsOf: url))
    }

    public static func read(_ data: Data) throws -> Mesh {
        guard data.count >= 15 else { throw Error.tooShort }

        // ASCII STLs start with "solid", but so do some binary ones written by
        // sloppy exporters — so sniff the payload size rather than trusting the
        // magic word. Binary is 84 + 50*n bytes exactly.
        if data.count >= 84 {
            let declared = data.withUnsafeBytes {
                $0.loadUnaligned(fromByteOffset: 80, as: UInt32.self)
            }
            let expected = 84 + 50 * Int(declared)
            if declared > 0 && expected == data.count {
                return try readBinary(data, count: Int(declared))
            }
        }
        let head = String(decoding: data.prefix(6), as: UTF8.self).lowercased()
        if head.hasPrefix("solid") { return try readASCII(data) }
        // Last resort: try binary anyway.
        guard data.count >= 84 else { throw Error.tooShort }
        let declared = data.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: 80, as: UInt32.self)
        }
        let available = (data.count - 84) / 50
        guard Int(declared) <= available else {
            throw Error.badTriangleCount(declared: Int(declared), available: available)
        }
        return try readBinary(data, count: Int(declared))
    }

    static func readBinary(_ data: Data, count: Int) throws -> Mesh {
        var tris: [Triangle] = []
        tris.reserveCapacity(count)
        data.withUnsafeBytes { raw in
            for i in 0..<count {
                let base = 84 + i * 50
                func f(_ o: Int) -> Double {
                    Double(raw.loadUnaligned(fromByteOffset: base + o, as: Float.self))
                }
                // bytes 0..11 are the normal, which we recompute from winding
                tris.append(Triangle(Vec3(f(12), f(16), f(20)),
                                     Vec3(f(24), f(28), f(32)),
                                     Vec3(f(36), f(40), f(44))))
            }
        }
        guard !tris.isEmpty else { throw Error.noTriangles }
        return Mesh(triangles: tris)
    }

    static func readASCII(_ data: Data) throws -> Mesh {
        let text = String(decoding: data, as: UTF8.self)
        var verts: [Vec3] = []
        var tris: [Triangle] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 4, parts[0].lowercased() == "vertex" else { continue }
            guard let x = Double(parts[1]), let y = Double(parts[2]),
                  let z = Double(parts[3]) else { continue }
            verts.append(Vec3(x, y, z))
            if verts.count == 3 {
                tris.append(Triangle(verts[0], verts[1], verts[2]))
                verts.removeAll(keepingCapacity: true)
            }
        }
        guard !tris.isEmpty else { throw Error.noTriangles }
        return Mesh(triangles: tris)
    }

    /// Binary STL. Used to emit the sample object the app ships with.
    public static func writeBinary(_ mesh: Mesh, to url: URL) throws {
        var data = Data(count: 80)
        var count = UInt32(mesh.triangles.count)
        withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }
        for t in mesh.triangles {
            let n = t.normal
            for v in [n, t.a, t.b, t.c] {
                for c in [Float(v.x), Float(v.y), Float(v.z)] {
                    var f = c
                    withUnsafeBytes(of: &f) { data.append(contentsOf: $0) }
                }
            }
            var attr = UInt16(0)
            withUnsafeBytes(of: &attr) { data.append(contentsOf: $0) }
        }
        try data.write(to: url)
    }

    /// A revolved cup — the sample object, and a better default than a sphere
    /// because it has an interior, a rim and a wall thickness, so the viewport
    /// shows something with real structure the moment the app opens.
    public static func sampleCup(height: Double = 0.095,
                                 outerRadius: Double = 0.036,
                                 wall: Double = 0.004,
                                 segments: Int = 64) -> Mesh {
        // Profile in (r, z), traced up the outside, across the rim, down the
        // inside, then across the floor.
        var profile: [(Double, Double)] = []
        let n = 12
        for i in 0...n {                       // outer wall, slightly flared
            let t = Double(i) / Double(n)
            profile.append((outerRadius * (0.72 + 0.28 * t), height * t))
        }
        profile.append((outerRadius - wall, height))          // across the rim
        for i in stride(from: n, through: 0, by: -1) {        // inner wall
            let t = Double(i) / Double(n)
            let r = (outerRadius * (0.72 + 0.28 * t)) - wall
            profile.append((max(0.001, r), max(wall, height * t)))
        }
        profile.append((0.001, wall))                          // floor centre
        profile.append((0.001, 0))
        profile.append((outerRadius * 0.72, 0))                // base

        var tris: [Triangle] = []
        for s in 0..<segments {
            let a0 = 2 * Double.pi * Double(s) / Double(segments)
            let a1 = 2 * Double.pi * Double(s + 1) / Double(segments)
            for i in 0..<(profile.count - 1) {
                let (r0, z0) = profile[i], (r1, z1) = profile[i + 1]
                let p00 = Vec3(r0 * cos(a0), r0 * sin(a0), z0)
                let p01 = Vec3(r0 * cos(a1), r0 * sin(a1), z0)
                let p10 = Vec3(r1 * cos(a0), r1 * sin(a0), z1)
                let p11 = Vec3(r1 * cos(a1), r1 * sin(a1), z1)
                tris.append(Triangle(p00, p01, p11))
                tris.append(Triangle(p00, p11, p10))
            }
        }
        return Mesh(triangles: tris)
    }
}

extension Mesh {
    /// Fit into a build volume: centre on the axis, sit on the deck, and scale
    /// down only if it overflows. Never scales UP — a slicer that silently
    /// enlarges your part is lying about fit.
    public func placed(in volume: BuildVolume, margin: Double = 0.004)
        -> (mesh: Mesh, scale: Double, fits: Bool) {
        let b = bounds
        let size = b.max - b.min
        let maxR = (size.x * size.x + size.y * size.y).squareRoot() / 2
        let usableR = max(1e-6, volume.radius - margin)
        let usableH = max(1e-6, volume.height - 2 * margin)
        let fits = maxR <= usableR && size.z <= usableH
        let scale = fits ? 1.0 : min(usableR / max(maxR, 1e-9),
                                     usableH / max(size.z, 1e-9))
        let centre = Vec3((b.min.x + b.max.x) / 2, (b.min.y + b.max.y) / 2, b.min.z)
        let tris = triangles.map { t -> Triangle in
            func f(_ v: Vec3) -> Vec3 {
                let c = (v - centre) * scale
                return Vec3(c.x, c.y, c.z + margin)
            }
            return Triangle(f(t.a), f(t.b), f(t.c))
        }
        return (Mesh(triangles: tris), scale, fits)
    }
}
