import FieldCore
import Foundation

/// The plate array's field with a part in it: `ArrayFieldGPU` plus the field
/// the placed beads scatter (`Scatterers`: coupled monopoles and dipoles).
///
/// Scattering is linear in the drive, so nothing per element is stored here
/// either. For a drive, the incident field at the bead centres gives the
/// beads' source strengths (one small solve per tone), and their field is
/// added at the lattice points on the CPU: points × beads. The adjoint goes
/// back through the same map: the weight a lattice point puts on the total
/// field is carried to the bead centres through the scattering operator's
/// transpose, and the array's adjoint pass runs once more at the centres.
/// With no beads this is exactly the array's field.
public final class PartFieldGPU: ForceCompiler.ForceField {
    public let base: ArrayFieldGPU
    public let part: Scatterers
    let positions: [Vec3]
    let kc: [Complex]
    public var lattice: FieldLattice { base.lattice }
    public var channels: Int { base.channels }
    public var toneCount: Int { base.toneCount }

    public init(base: ArrayFieldGPU, part: Scatterers) {
        self.base = base; self.part = part
        positions = base.lattice.positions
        kc = base.frequencies.map { Complex(base.medium.wavenumber(at: $0), base.medium.absorption(at: $0)) }
    }

    /// The beads' sources for one tone's drive (a single "gate": the drive itself).
    func sources(_ drive: [Complex], tone t: Int) throws -> Scatterers.Sources {
        let C = try base.fields(drive, tone: t, at: part.centers)
        return part.solve(incident: part.centers.indices.map { j in
            (p: [C[j * 4]], grad: [[C[j * 4 + 1]], [C[j * 4 + 2]], [C[j * 4 + 3]]])
        }, k: kc[t])
    }

    /// Total p and ∇p for one tone's drive at points, layout [n·4 + c].
    public func fields(_ drive: [Complex], tone t: Int, at points: [Vec3]) throws -> [Complex] {
        var S = try base.fields(drive, tone: t, at: points)
        guard !part.centers.isEmpty else { return S }
        part.addField(to: &S, points: points, sources: try sources(drive, tone: t))
        return S
    }

    /// U at arbitrary points. `skip` leaves one bead's own scattered field out:
    /// the potential that bead itself sits in (a bead does not push itself).
    public func potential(_ drives: [[Complex]], particle: ParticleMaterial, at points: [Vec3], skip: Int? = nil) throws -> [Double] {
        var U = [Double](repeating: 0, count: points.count)
        for t in 0..<toneCount {
            let (k1, k2) = ForceCompiler.coefficients(particle: particle, medium: base.medium, frequency: base.frequencies[t])
            var S = try base.fields(drives[t], tone: t, at: points)
            if !part.centers.isEmpty {
                let src = try sources(drives[t], tone: t)
                for (n, x) in points.enumerated() {
                    let f = part.field(at: x, sources: src, skip: skip)
                    S[n * 4] += f.p[0]
                    for c in 0..<3 { S[n * 4 + 1 + c] += f.grad[c][0] }
                }
            }
            for n in 0..<points.count {
                let b = n * 4
                U[n] += k1 * S[b].magnitudeSquared
                    - k2 * (S[b + 1].magnitudeSquared + S[b + 2].magnitudeSquared + S[b + 3].magnitudeSquared)
            }
        }
        return U
    }

    public func potential(_ drives: [[Complex]], particle: ParticleMaterial) -> [Double] {
        var U = [Double](repeating: 0, count: positions.count)
        for t in 0..<toneCount {
            let (k1, k2) = ForceCompiler.coefficients(particle: particle, medium: base.medium, frequency: base.frequencies[t])
            let S = try! fields(drives[t], tone: t, at: positions)
            for n in 0..<positions.count {
                let b = n * 4
                U[n] += k1 * S[b].magnitudeSquared
                    - k2 * (S[b + 1].magnitudeSquared + S[b + 2].magnitudeSquared + S[b + 3].magnitudeSquared)
            }
        }
        return U
    }

    public func adjoint(_ drives: [[Complex]], weights: [Double], particle: ParticleMaterial) -> [[Complex]] {
        let active = weights.indices.filter { weights[$0] != 0 }
        guard !active.isEmpty else { return drives.map { $0.map { _ in Complex.zero } } }
        let pts = active.map { positions[$0] }
        func f4(_ v: [Vec3]) -> [SIMD4<Float>] { v.map { SIMD4(Float($0.x), Float($0.y), Float($0.z), 0) } }
        func f2(_ a: [Complex]) -> [SIMD2<Float>] { a.map { SIMD2(Float($0.re), Float($0.im)) } }
        let nb = part.centers.count
        return (0..<toneCount).map { t in
            let (k1, k2) = ForceCompiler.coefficients(particle: particle, medium: base.medium, frequency: base.frequencies[t])
            let S = try! fields(drives[t], tone: t, at: pts)
            var A = [Complex](repeating: .zero, count: pts.count * 4)
            for (q, n) in active.enumerated() {
                let w = weights[n], b = q * 4
                A[b] = S[b] * (w * k1)
                for c in 1...3 { A[b + c] = S[b + c] * (w * k2) }
            }
            var g = try! base.adjointPass(A: f2(A), points: f4(pts), tone: t)
            guard nb > 0 else { return g }
            // Through the scattering operator's transpose: one column per bead
            // and incident component. The array's adjoint pass takes p with +
            // and the gradient components with − (arrayAdjoint).
            var A2 = [Complex](repeating: .zero, count: nb * 4)
            for j in 0..<nb {
                for c in 0..<4 {
                    let unit: [(p: [Complex], grad: [[Complex]])] = (0..<nb).map { i in
                        let one: (Int) -> [Complex] = { cc in [i == j && cc == c ? Complex(1, 0) : .zero] }
                        return (p: one(0), grad: [one(1), one(2), one(3)])
                    }
                    var col = [Complex](repeating: .zero, count: pts.count * 4)
                    part.addField(to: &col, points: pts, sources: part.solve(incident: unit, k: kc[t]))
                    var acc = Complex.zero
                    for q in 0..<pts.count {
                        acc += col[q * 4].conjugate * A[q * 4]
                        for cc in 1...3 { acc += col[q * 4 + cc].conjugate * A[q * 4 + cc] * -1.0 }
                    }
                    A2[j * 4 + c] = c == 0 ? acc : acc * -1.0
                }
            }
            let g2 = try! base.adjointPass(A: f2(A2), points: f4(part.centers), tone: t)
            for e in g.indices { g[e] += g2[e] }
            return g
        }
    }
}
