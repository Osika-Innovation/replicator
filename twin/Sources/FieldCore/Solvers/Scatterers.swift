import Foundation

/// The part as it grows: small beads that scatter the chamber's field.
///
/// A bead much smaller than the wavelength (ka ≤ 0.13 for a Ø200 µm bead at
/// 68 kHz) scatters as a monopole, from its compressibility contrast f1, plus a
/// dipole, from its density contrast f2 (Settnes & Bruus 2012):
///
///     p_sc(r) = −(f1/3) k²a³ p_loc g(R) − (f2/2) a³ ∇p_loc · ∇g(R),   g = e^{ikR}/R,
///
/// where p_loc is the LOCAL field at the bead: the chamber's plus every other
/// bead's scattered field. So a cluster's multiple scattering is solved — a
/// 4N × 4N linear system per gate, the coupled-dipole method — not assumed
/// away. A fused bead cannot move: f2 = 1. f1 = 1 − κ_p/κ_0.
///
/// The scattered field is taken in free space. Its echo off the chamber walls
/// comes back from ~0.5 m away, orders of magnitude below its near field at a
/// neighbour, which is where it matters. Everything is linear in the drive, so
/// the part adds per-gate rows: the force compiler, the carry and the force
/// balance all see the part without knowing it is there.
///
/// Checked against the exact rigid-sphere series (G-S1) and against the
/// time-averaged interaction of two beads in an oscillating flow — attraction
/// side by side, repulsion end to end (G-S2).
public struct Scatterers: Sendable {
    public var centers: [Vec3]
    public var radius: Double
    public var f1: Double
    public var f2: Double

    public init(centers: [Vec3], radius: Double, f1: Double, f2: Double = 1) {
        self.centers = centers; self.radius = radius; self.f1 = f1; self.f2 = f2
    }

    /// Beads of a material in a medium; fused beads are immovable (f2 = 1).
    public init(centers: [Vec3], particle: ParticleMaterial, medium: Medium, fused: Bool = true) {
        let kappa0 = 1 / (medium.density * medium.soundSpeed * medium.soundSpeed)
        let kappaP = 1 / (particle.density * particle.soundSpeed * particle.soundSpeed)
        let f2free = 2 * (particle.density - medium.density) / (2 * particle.density + medium.density)
        self.init(centers: centers, radius: particle.radius, f1: 1 - kappaP / kappa0, f2: fused ? 1 : f2free)
    }

    /// Per-gate source strengths for one tone: monopole A and dipole B of
    /// every bead, [j · gates + g].
    public struct Sources: Sendable {
        public var k: Complex
        public var gates: Int
        public var A: [Complex]
        public var B: [[Complex]]        // 3 components
    }

    /// g = e^{ikR}/R at R⃗ = observer − source, with its gradient and Hessian
    /// with respect to the observer.
    @inline(__always)
    static func green(_ d: Vec3, _ k: Complex) -> (g: Complex, grad: [Complex], hess: [[Complex]]) {
        let R = d.length
        let u = [d.x / R, d.y / R, d.z / R]
        let g = (Complex(0, 1) * k * R).exp / R
        let h = Complex(0, 1) * k - Complex(1 / R, 0)             // ∂g/∂R = g h
        let grad = u.map { g * h * $0 }
        let radial = g * (h * h + Complex(1 / (R * R), 0)), tangential = g * h / R
        var hess = [[Complex]](repeating: [.zero, .zero, .zero], count: 3)
        for i in 0..<3 {
            for j in 0..<3 {
                hess[i][j] = radial * (u[i] * u[j]) + tangential * ((i == j ? 1 : 0) - u[i] * u[j])
            }
        }
        return (g, grad, hess)
    }

    /// Solve the coupled system. `incident[j]` is the chamber's field at bead
    /// j, per gate: p rows [gates] and gradient rows [3][gates].
    public func solve(incident: [(p: [Complex], grad: [[Complex]])], k: Complex) -> Sources {
        let N = centers.count
        let G = incident.first?.p.count ?? 0
        let n = 4 * N
        let a3 = radius * radius * radius
        let cM = k * k * (-f1 / 3 * a3)                              // A = cM · p_loc
        let cD = -f2 / 2 * a3                                        // B = cD · ∇p_loc
        // x = x_in + T x, x_j = (p, ∂x p, ∂y p, ∂z p) of the local field at bead j.
        var M = [[Complex]](repeating: [Complex](repeating: .zero, count: n), count: n)
        for q in 0..<n { M[q][q] = .one }
        for j in 0..<N {
            for i in 0..<N where i != j {
                let gr = Scatterers.green(centers[j] - centers[i], k)
                M[4 * j][4 * i] -= cM * gr.g
                for c in 0..<3 { M[4 * j][4 * i + 1 + c] -= gr.grad[c] * cD }
                for d in 0..<3 {
                    M[4 * j + 1 + d][4 * i] -= cM * gr.grad[d]
                    for c in 0..<3 { M[4 * j + 1 + d][4 * i + 1 + c] -= gr.hess[d][c] * cD }
                }
            }
        }
        var rhs = [[Complex]](repeating: [Complex](repeating: .zero, count: G), count: n)
        for j in 0..<N {
            for g in 0..<G {
                rhs[4 * j][g] = incident[j].p[g]
                for d in 0..<3 { rhs[4 * j + 1 + d][g] = incident[j].grad[d][g] }
            }
        }
        let X = Scatterers.gauss(M, rhs)
        var A = [Complex](repeating: .zero, count: N * G)
        var B = [[Complex]](repeating: [Complex](repeating: .zero, count: N * G), count: 3)
        for j in 0..<N {
            for g in 0..<G {
                A[j * G + g] = cM * X[4 * j][g]
                for c in 0..<3 { B[c][j * G + g] = X[4 * j + 1 + c][g] * cD }
            }
        }
        return Sources(k: k, gates: G, A: A, B: B)
    }

    /// Gaussian elimination with partial pivoting, several right-hand sides.
    static func gauss(_ M0: [[Complex]], _ R0: [[Complex]]) -> [[Complex]] {
        var M = M0, R = R0
        let n = M.count
        for c in 0..<n {
            let p = (c..<n).max { M[$0][c].magnitude < M[$1][c].magnitude }!
            if p != c { M.swapAt(p, c); R.swapAt(p, c) }
            let inv = Complex.one / M[c][c]
            for r in (c + 1)..<max(c + 1, n) {
                let f = M[r][c] * inv
                if f.magnitude == 0 { continue }
                for q in c..<n { M[r][q] -= f * M[c][q] }
                for q in R[r].indices { R[r][q] -= f * R[c][q] }
            }
        }
        var X = R
        for r in stride(from: n - 1, through: 0, by: -1) {
            for q in X[r].indices {
                var s = R[r][q]
                for c in (r + 1)..<max(r + 1, n) { s -= M[r][c] * X[c][q] }
                X[r][q] = s / M[r][r]
            }
        }
        return X
    }

    /// The part's field at x, per gate: p and ∇p. `skip` leaves one bead out
    /// (a bead does not push itself); inside a bead (R < a) R is held at a, so
    /// lattice points there stay finite — they are not physical.
    public func field(at x: Vec3, sources s: Sources, skip: Int? = nil) -> (p: [Complex], grad: [[Complex]]) {
        let G = s.gates
        var p = [Complex](repeating: .zero, count: G)
        var gr = [[Complex]](repeating: [Complex](repeating: .zero, count: G), count: 3)
        for (j, c) in centers.enumerated() where j != skip {
            var d = x - c
            let R = d.length
            if R < radius { d = R > 1e-15 ? d * (radius / R) : Vec3(0, 0, radius) }
            let gf = Scatterers.green(d, s.k)
            for g in 0..<G {
                let A = s.A[j * G + g]
                let B = [s.B[0][j * G + g], s.B[1][j * G + g], s.B[2][j * G + g]]
                p[g] += A * gf.g + B[0] * gf.grad[0] + B[1] * gf.grad[1] + B[2] * gf.grad[2]
                for dd in 0..<3 {
                    gr[dd][g] += A * gf.grad[dd] + gf.hess[dd][0] * B[0] + gf.hess[dd][1] * B[1] + gf.hess[dd][2] * B[2]
                }
            }
        }
        return (p, gr)
    }

    /// Add the part's field to rows laid out [(n · gates + g) · 4 + c] at points.
    public func addField(to rows: inout [Complex], points: [Vec3], sources s: Sources) {
        let G = s.gates
        let chunks = max(1, min(256, points.count / 256))
        rows.withUnsafeMutableBufferPointer { buf in
            DispatchQueue.concurrentPerform(iterations: chunks) { ch in
                let lo = ch * points.count / chunks, hi = (ch + 1) * points.count / chunks
                for n in lo..<hi {
                    let f = field(at: points[n], sources: s)
                    for g in 0..<G {
                        let b = (n * G + g) * 4
                        buf[b] += f.p[g]
                        for c in 0..<3 { buf[b + 1 + c] += f.grad[c][g] }
                    }
                }
            }
        }
    }
}
