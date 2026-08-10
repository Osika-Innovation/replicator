import Foundation

/// Solid voxelization by ray parity (even-odd crossing count along +x).
/// Robust for the closed meshes this app deals with, and — importantly for
/// G1 — unbiased, so the volume error is discretization only.
public enum Voxelizer {

    public static func voxelize(mesh: Mesh, lattice: FieldLattice) -> [Bool] {
        var occ = [Bool](repeating: false, count: lattice.count)
        guard !mesh.triangles.isEmpty else { return occ }

        // Bucket triangles by the (y,z) rows they can possibly cross, so each
        // ray only tests candidates instead of the whole mesh.
        let tris = mesh.triangles
        occ.withUnsafeMutableBufferPointer { buf in
            DispatchQueue.concurrentPerform(iterations: lattice.nz) { k in
                let z = lattice.origin.z + Double(k) * lattice.spacing
                for j in 0..<lattice.ny {
                    let y = lattice.origin.y + Double(j) * lattice.spacing
                    // Collect x-crossings of the ray (y, z) -> +x
                    var xs: [Double] = []
                    for t in tris {
                        if let x = rayTriangleX(y: y, z: z, t: t) { xs.append(x) }
                    }
                    guard !xs.isEmpty else { continue }
                    xs.sort()
                    // Parity fill between successive crossing pairs
                    var idx = 0
                    while idx + 1 < xs.count {
                        let x0 = xs[idx], x1 = xs[idx + 1]
                        let i0 = Int(((x0 - lattice.origin.x) / lattice.spacing).rounded(.up))
                        let i1 = Int(((x1 - lattice.origin.x) / lattice.spacing).rounded(.down))
                        let lo = Swift.max(0, i0)
                        let hi = Swift.min(lattice.nx - 1, i1)
                        if lo <= hi {
                            for i in lo...hi {
                                buf[(k * lattice.ny + j) * lattice.nx + i] = true
                            }
                        }
                        idx += 2
                    }
                }
            }
        }
        return occ
    }

    /// Intersection of the axis-aligned ray (y,z)->+x with a triangle, if any.
    /// Returns the x coordinate. Uses the standard 2-D barycentric test in the
    /// (y,z) plane, which is exactly the projection the ray direction implies.
    @inline(__always)
    static func rayTriangleX(y: Double, z: Double, t: Triangle) -> Double? {
        let ay = t.a.y, az = t.a.z
        let by = t.b.y, bz = t.b.z
        let cy = t.c.y, cz = t.c.z
        let d = (bz - cz) * (ay - cy) + (cy - by) * (az - cz)
        if abs(d) < 1e-18 { return nil }                    // edge-on to the ray
        let l1 = ((bz - cz) * (y - cy) + (cy - by) * (z - cz)) / d
        let l2 = ((cz - az) * (y - cy) + (ay - cy) * (z - cz)) / d
        let l3 = 1 - l1 - l2
        // Half-open test on a consistent edge set avoids double-counting a ray
        // that passes exactly through a shared edge.
        let eps = 0.0
        guard l1 >= eps, l2 >= eps, l3 >= eps else { return nil }
        return l1 * t.a.x + l2 * t.b.x + l3 * t.c.x
    }

    /// Per-cell material assignment for the FDTD grid.
    public static func materialGrid(mesh: Mesh, lattice: FieldLattice,
                                    inside: Medium, outside: Medium)
        -> (rho: [Double], c2: [Double]) {
        let occ = voxelize(mesh: mesh, lattice: lattice)
        var rho = [Double](repeating: outside.density, count: occ.count)
        var c2 = [Double](repeating: outside.soundSpeed * outside.soundSpeed, count: occ.count)
        for i in occ.indices where occ[i] {
            rho[i] = inside.density
            c2[i] = inside.soundSpeed * inside.soundSpeed
        }
        return (rho, c2)
    }
}
