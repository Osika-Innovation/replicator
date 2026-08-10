import Foundation

/// §15 step 4 — chord extraction by matrix pencil.
///
/// A ring-down record is a sum of damped exponentials:
///   y[n] = sum_k r_k * z_k^n ,  z_k = exp(p_k * dt) ,  p_k = complex frequency
///
/// Build Hankel matrices from the record, stack all gates' Hankels VERTICALLY
/// (joint poles — one object, one set of resonances), truncate by SVD, and the
/// generalized eigenvalues give the poles. The port-vectors then come from a
/// least-squares fit, and they are what break the isospectral ambiguity a bare
/// eigenfrequency list would leave (§3).
public enum MatrixPencil {

    /// One extracted chord: where the object rings, and the gate pattern that
    /// addresses that ringing.
    public struct Chord: Sendable, Codable {
        public var pole: Complex          // complex frequency, rad/s
        public var portVector: [Complex]  // one complex amplitude per gate
        public var weight: Double         // contribution, for ordering/truncation
        public var provenance: Provenance

        public enum Provenance: String, Sendable, Codable {
            case measured, inferred
        }

        public init(pole: Complex, portVector: [Complex], weight: Double,
                    provenance: Provenance = .measured) {
            self.pole = pole; self.portVector = portVector
            self.weight = weight; self.provenance = provenance
        }

        /// Ringing frequency in Hz and quality factor.
        public var frequencyHz: Double { abs(pole.im) / (2 * .pi) }
        public var qFactor: Double {
            pole.re < 0 ? abs(pole.im) / (2 * abs(pole.re)) : .infinity
        }
    }

    /// Extract up to `maxChords` chords from a set of per-gate time records.
    ///
    /// - Parameters:
    ///   - records: [gate][sample], real pressure at each gate
    ///   - dt: sample interval, seconds
    /// MODEL ORDER, measured rather than guessed. A sweep on a 12-gate FDTD
    /// scan of a 22 mm sphere (one chamber run, re-extracted per order):
    ///
    ///     order  window  chords   in-fit  held-out  ratio
    ///        32      64      24   0.1646    0.1708  1.04x
    ///        48      96      32   0.3105    0.3081  0.99x
    ///        64     128      42   0.1314    0.1303  0.99x   <- meets G18 (0.15)
    ///        96     180      60   0.1243    0.1219  0.98x
    ///       128     220      72   0.1242    0.1218  0.98x
    ///
    /// Two things that matter. The error CONVERGES to ~0.122, so there is a real
    /// floor and cranking the order further buys nothing. And the held-out/in-fit
    /// ratio stays 0.98-1.04 throughout — the higher orders capture genuine
    /// cavity modes rather than overfitting; a closed chamber simply has many.
    ///
    /// It is NOT monotone: order 48 / window 96 scores 0.308, worse than the
    /// lower 32/64. So do not treat "more order" as "more accuracy" — pick a
    /// measured configuration.
    ///
    /// - Parameter minFrequency: reject near-DC poles. Any residual offset in a
    ///   differential record produces a purely real pole with enormous weight —
    ///   observed dominating the list at f = 0 Hz with 10x the weight of the
    ///   real resonances. An acoustic resonance cannot sit at 0 Hz, so these are
    ///   numerical artifacts and must not be sold as chords.
    public static func extract(records: [[Double]], dt: Double,
                               maxChords: Int = 8,
                               minFrequency: Double = 200,
                               pencilWindow: Int = 64) -> [Chord] {
        guard let first = records.first, first.count > 8 else { return [] }
        let nGates = records.count
        let N = first.count
        // Pencil parameter. The number of resolvable modes is bounded by L, so
        // a cap of 64 silently ceilings the model order — an order sweep
        // saturated at 24 chords no matter how many were requested.
        let L = max(4, min(N / 3, pencilWindow))

        // Stack each gate's Hankel vertically: rows = gates * (N - L), cols = L.
        let rowsPerGate = N - L
        guard rowsPerGate > 1 else { return [] }
        var Y0 = LinAlg.zeros(nGates * rowsPerGate, L)
        var Y1 = LinAlg.zeros(nGates * rowsPerGate, L)
        for g in 0..<nGates {
            for r in 0..<rowsPerGate {
                for c in 0..<L {
                    Y0[g * rowsPerGate + r][c] = Complex(records[g][r + c], 0)
                    Y1[g * rowsPerGate + r][c] = Complex(records[g][r + c + 1], 0)
                }
            }
        }

        let (_, s, V) = LinAlg.svd(Y0)
        let autoK = LinAlg.rank(s)
        let K = max(1, min(maxChords, min(autoK, L - 1)))

        // Truncated right singular vectors.
        var Vk = LinAlg.zeros(L, K)
        for i in 0..<L { for j in 0..<K { Vk[i][j] = V[i][j] } }

        // Z = pinv(Y0 Vk) * (Y1 Vk), then eigenvalues of Z are the z_k.
        let A0 = LinAlg.matmul(Y0, Vk)
        let A1 = LinAlg.matmul(Y1, Vk)
        let A0h = LinAlg.conjTranspose(A0)
        var G = LinAlg.matmul(A0h, A0)
        for i in 0..<K { G[i][i] += Complex(1e-12, 0) }
        let RHS = LinAlg.matmul(A0h, A1)
        var Z = LinAlg.zeros(K, K)
        for col in 0..<K {
            let b = (0..<K).map { RHS[$0][col] }
            let x = LinAlg.solve(G, b)
            for r in 0..<K { Z[r][col] = x[r] }
        }
        let zs = LinAlg.eigenvalues(Z)

        // z = exp(p dt)  =>  p = ln(z)/dt
        var chords: [Chord] = []
        for z in zs {
            let mag = z.magnitude
            guard mag > 1e-12, mag.isFinite else { continue }
            let p = Complex(log(mag) / dt, z.phase / dt)
            guard p.re.isFinite, p.im.isFinite else { continue }
            // Discard growing modes: a passive object cannot ring up on its own.
            guard p.re <= 1e-6 else { continue }
            // Discard near-DC: offset artifacts, not resonances.
            guard abs(p.im) / (2 * Double.pi) >= minFrequency else { continue }
            chords.append(Chord(pole: p, portVector: [], weight: 0))
        }
        guard !chords.isEmpty else { return [] }

        // Port vectors: fit each gate's record as a sum over the poles.
        var weights = [Double](repeating: 0, count: chords.count)
        var vectors = [[Complex]](repeating: [], count: chords.count)
        for g in 0..<nGates {
            var M = LinAlg.zeros(N, chords.count)
            for n in 0..<N {
                for (k, ch) in chords.enumerated() {
                    let e = exp(ch.pole.re * dt * Double(n))
                    M[n][k] = Complex.expi(ch.pole.im * dt * Double(n)) * e
                }
            }
            let b = records[g].map { Complex($0, 0) }
            let r = LinAlg.lstsq(M, b, lambda: 1e-10)
            for k in 0..<chords.count {
                if vectors[k].isEmpty {
                    vectors[k] = [Complex](repeating: .zero, count: nGates)
                }
                vectors[k][g] = k < r.count ? r[k] : .zero
                weights[k] += vectors[k][g].magnitudeSquared
            }
        }
        for k in 0..<chords.count {
            chords[k].portVector = vectors[k]
            chords[k].weight = weights[k].squareRoot()
        }
        chords.sort { $0.weight > $1.weight }
        return Array(chords.prefix(maxChords))
    }

    /// Refit port vectors for a given pole subset.
    ///
    /// Truncating a JOINT fit is not the same as fitting the truncation: each
    /// amplitude was solved in the presence of the others, so dropping chords
    /// leaves the survivors mis-weighted. Measured: truncating without refit
    /// gave a NON-monotone error curve (K2 worse than K1, K16 worse than K8),
    /// which reads as an extractor fault but is really an invalid comparison.
    public static func refit(poles: [Chord], records: [[Double]], dt: Double)
        -> [Chord] {
        guard !poles.isEmpty, let first = records.first else { return [] }
        let N = first.count
        var out = poles
        var vectors = [[Complex]](repeating:
            [Complex](repeating: .zero, count: records.count), count: poles.count)
        var weights = [Double](repeating: 0, count: poles.count)
        for g in records.indices {
            var M = LinAlg.zeros(N, poles.count)
            for n in 0..<N {
                let t = dt * Double(n)
                for (k, ch) in poles.enumerated() {
                    M[n][k] = Complex.expi(ch.pole.im * t) * exp(ch.pole.re * t)
                }
            }
            let r = LinAlg.lstsq(M, records[g].map { Complex($0, 0) }, lambda: 1e-10)
            for k in poles.indices {
                vectors[k][g] = k < r.count ? r[k] : .zero
                weights[k] += vectors[k][g].magnitudeSquared
            }
        }
        for k in poles.indices {
            out[k].portVector = vectors[k]
            out[k].weight = weights[k].squareRoot()
        }
        return out
    }

    /// Rebuild the per-gate records from a chord list. This is what G10 measures:
    /// how much of the response the top-K chords actually carry.
    public static func synthesize(chords: [Chord], gates: Int, samples: Int,
                                  dt: Double) -> [[Double]] {
        var out = [[Double]](repeating: [Double](repeating: 0, count: samples),
                             count: gates)
        for ch in chords {
            guard ch.portVector.count == gates else { continue }
            for n in 0..<samples {
                let t = dt * Double(n)
                let env = exp(ch.pole.re * t)
                let osc = Complex.expi(ch.pole.im * t) * env
                for g in 0..<gates {
                    out[g][n] += (ch.portVector[g] * osc).re
                }
            }
        }
        return out
    }
}
