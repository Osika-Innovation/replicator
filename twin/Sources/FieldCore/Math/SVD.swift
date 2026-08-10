import Foundation

/// Complex matrices as row-major [[Complex]], with the small amount of linear
/// algebra this program needs. Hand-rolled per the zero-dependency ruling (§8);
/// every matrix here is at most a few hundred rows.
public enum LinAlg {

    public static func zeros(_ r: Int, _ c: Int) -> [[Complex]] {
        [[Complex]](repeating: [Complex](repeating: .zero, count: c), count: r)
    }

    public static func matmul(_ A: [[Complex]], _ B: [[Complex]]) -> [[Complex]] {
        let n = A.count, m = B[0].count, k = B.count
        var C = zeros(n, m)
        for i in 0..<n {
            for p in 0..<k {
                let a = A[i][p]
                if a.re == 0 && a.im == 0 { continue }
                for j in 0..<m { C[i][j] += a * B[p][j] }
            }
        }
        return C
    }

    public static func conjTranspose(_ A: [[Complex]]) -> [[Complex]] {
        guard !A.isEmpty else { return [] }
        var T = zeros(A[0].count, A.count)
        for i in 0..<A.count { for j in 0..<A[0].count { T[j][i] = A[i][j].conjugate } }
        return T
    }

    /// One-sided Jacobi SVD of a complex matrix: A = U * diag(s) * V^H.
    ///
    /// Orthogonalises the COLUMNS of A by Jacobi rotations; the resulting column
    /// norms are the singular values and the accumulated rotations are V.
    /// Chosen over forming A^H A because — as §16.3 warns for DORT — squaring
    /// the matrix squares the dynamic range, which is exactly what destroys the
    /// small singular values you are trying to see.
    public static func svd(_ Ain: [[Complex]], sweeps: Int = 30)
        -> (U: [[Complex]], s: [Double], V: [[Complex]]) {
        var A = Ain
        let m = A.count
        guard m > 0 else { return ([], [], []) }
        let n = A[0].count

        var V = zeros(n, n)
        for i in 0..<n { V[i][i] = .one }

        for _ in 0..<sweeps {
            var offDiagonal = 0.0
            for p in 0..<(n - 1) {
                for q in (p + 1)..<n {
                    // alpha = |a_p|^2, beta = |a_q|^2, gamma = <a_p, a_q>
                    var alpha = 0.0, beta = 0.0
                    var gamma = Complex.zero
                    for i in 0..<m {
                        alpha += A[i][p].magnitudeSquared
                        beta += A[i][q].magnitudeSquared
                        gamma += A[i][p].conjugate * A[i][q]
                    }
                    let g = gamma.magnitude
                    if g < 1e-300 { continue }
                    offDiagonal = max(offDiagonal, g / (alpha * beta).squareRoot())
                    if g / (alpha * beta).squareRoot() < 1e-14 { continue }

                    // Real rotation in the plane spanned after phase alignment.
                    let phase = Complex(gamma.re / g, gamma.im / g)
                    let zeta = (beta - alpha) / (2 * g)
                    let t = (zeta >= 0 ? 1.0 : -1.0)
                          / (abs(zeta) + (1 + zeta * zeta).squareRoot())
                    let c = 1 / (1 + t * t).squareRoot()
                    let sMag = c * t

                    for i in 0..<m {
                        let ap = A[i][p], aq = A[i][q]
                        A[i][p] = ap * c - (phase * aq) * sMag
                        A[i][q] = (phase.conjugate * ap) * sMag + aq * c
                    }
                    for i in 0..<n {
                        let vp = V[i][p], vq = V[i][q]
                        V[i][p] = vp * c - (phase * vq) * sMag
                        V[i][q] = (phase.conjugate * vp) * sMag + vq * c
                    }
                }
            }
            if offDiagonal < 1e-14 { break }
        }

        // Column norms are the singular values; normalise to get U.
        var s = [Double](repeating: 0, count: n)
        var U = zeros(m, n)
        for j in 0..<n {
            var norm = 0.0
            for i in 0..<m { norm += A[i][j].magnitudeSquared }
            norm = norm.squareRoot()
            s[j] = norm
            if norm > 1e-300 { for i in 0..<m { U[i][j] = A[i][j] / norm } }
        }

        // Sort descending.
        let order = (0..<n).sorted { s[$0] > s[$1] }
        var s2 = [Double](repeating: 0, count: n)
        var U2 = zeros(m, n), V2 = zeros(n, n)
        for (newIdx, oldIdx) in order.enumerated() {
            s2[newIdx] = s[oldIdx]
            for i in 0..<m { U2[i][newIdx] = U[i][oldIdx] }
            for i in 0..<n { V2[i][newIdx] = V[i][oldIdx] }
        }
        return (U2, s2, V2)
    }

    /// Gavish–Donoho hard threshold for rank when the noise level is unknown:
    /// keep singular values above 2.858 * median(s).
    public static func rank(_ s: [Double]) -> Int {
        let positive = s.filter { $0 > 0 }.sorted()
        guard !positive.isEmpty else { return 0 }
        let median = positive[positive.count / 2]
        let cutoff = 2.858 * median
        return max(1, s.filter { $0 > cutoff }.count)
    }

    /// Least squares via normal equations with Tikhonov damping. Small systems
    /// only — this is the chord-amplitude fit, not an inverse problem.
    public static func lstsq(_ A: [[Complex]], _ b: [Complex],
                             lambda: Double = 1e-12) -> [Complex] {
        let Ah = conjTranspose(A)
        var AhA = matmul(Ah, A)
        for i in 0..<AhA.count { AhA[i][i] += Complex(lambda, 0) }
        var Ahb = [Complex](repeating: .zero, count: Ah.count)
        for i in 0..<Ah.count {
            for j in 0..<b.count { Ahb[i] += Ah[i][j] * b[j] }
        }
        return solve(AhA, Ahb)
    }

    /// Gaussian elimination with partial pivoting.
    public static func solve(_ Ain: [[Complex]], _ bin: [Complex]) -> [Complex] {
        var A = Ain, b = bin
        let n = A.count
        guard n > 0 else { return [] }
        for col in 0..<n {
            var pivot = col
            var best = A[col][col].magnitude
            for r in (col + 1)..<n where A[r][col].magnitude > best {
                best = A[r][col].magnitude; pivot = r
            }
            if best < 1e-300 { continue }
            if pivot != col { A.swapAt(col, pivot); b.swapAt(col, pivot) }
            let d = A[col][col]
            for r in (col + 1)..<n {
                let f = A[r][col] / d
                if f.re == 0 && f.im == 0 { continue }
                for c in col..<n { A[r][c] -= f * A[col][c] }
                b[r] -= f * b[col]
            }
        }
        var x = [Complex](repeating: .zero, count: n)
        for r in stride(from: n - 1, through: 0, by: -1) {
            var acc = b[r]
            for c in (r + 1)..<n { acc -= A[r][c] * x[c] }
            x[r] = A[r][r].magnitude > 1e-300 ? acc / A[r][r] : .zero
        }
        return x
    }

    /// Eigenvalues of a small complex matrix by SHIFTED QR with deflation.
    ///
    /// Unshifted QR converges linearly in |lambda_{i+1}/lambda_i|, and the
    /// matrix pencil's eigenvalues are z_k = exp(p_k dt) which for lightly
    /// damped modes all sit near |z| = 1 — so the ratios are ~1 and it barely
    /// converges at all. Measured on synthetic ground truth: 12,000 Hz came
    /// back as 12,286 Hz and the reconstruction explained only half the record.
    ///
    /// Wilkinson-shifted QR converges cubically. In COMPLEX arithmetic the
    /// shifted iteration also drives the matrix to genuine upper-triangular
    /// form, so the 2x2-block reading the unshifted version needed disappears.
    public static func eigenvalues(_ Ain: [[Complex]], iterations: Int = 200) -> [Complex] {
        var A = Ain
        var n = A.count
        guard n > 0 else { return [] }
        var out: [Complex] = []

        while n > 1 {
            var converged = false
            for _ in 0..<iterations {
                // Deflate when the trailing subdiagonal is negligible.
                let sub = A[n - 1][n - 2].magnitude
                let scale = A[n - 1][n - 1].magnitude + A[n - 2][n - 2].magnitude
                if sub <= 1e-14 * max(scale, 1e-300) { converged = true; break }

                // Wilkinson shift: the eigenvalue of the trailing 2x2 nearest
                // to the corner entry.
                let a = A[n - 2][n - 2], b = A[n - 2][n - 1]
                let c = A[n - 1][n - 2], d = A[n - 1][n - 1]
                let tr = a + d, det = a * d - b * c
                let disc = csqrt(tr * tr - det * 4.0)
                let r1 = (tr + disc) / 2.0, r2 = (tr - disc) / 2.0
                let mu = (r1 - d).magnitude < (r2 - d).magnitude ? r1 : r2

                for i in 0..<n { A[i][i] -= mu }
                var sub2 = [[Complex]](repeating: [], count: n)
                for i in 0..<n { sub2[i] = Array(A[i][0..<n]) }
                let (Q, R) = qr(sub2)
                var next = matmul(R, Q)
                for i in 0..<n { next[i][i] += mu }
                for i in 0..<n { for j in 0..<n { A[i][j] = next[i][j] } }
            }
            _ = converged
            out.append(A[n - 1][n - 1])
            n -= 1
        }
        out.append(A[0][0])
        return out.reversed()
    }

    /// Principal square root of a complex number.
    static func csqrt(_ z: Complex) -> Complex {
        let r = z.magnitude
        if r < 1e-300 { return .zero }
        let m = (r).squareRoot()
        let theta = z.phase / 2
        return Complex(m * cos(theta), m * sin(theta))
    }

    /// Gram–Schmidt QR.
    static func qr(_ A: [[Complex]]) -> ([[Complex]], [[Complex]]) {
        let n = A.count, m = A[0].count
        var Q = zeros(n, m), R = zeros(m, m)
        for j in 0..<m {
            var v = (0..<n).map { A[$0][j] }
            for i in 0..<j {
                var dot = Complex.zero
                for k in 0..<n { dot += Q[k][i].conjugate * A[k][j] }
                R[i][j] = dot
                for k in 0..<n { v[k] -= dot * Q[k][i] }
            }
            var norm = 0.0
            for k in 0..<n { norm += v[k].magnitudeSquared }
            norm = norm.squareRoot()
            R[j][j] = Complex(norm, 0)
            if norm > 1e-300 { for k in 0..<n { Q[k][j] = v[k] / norm } }
        }
        return (Q, R)
    }
}
