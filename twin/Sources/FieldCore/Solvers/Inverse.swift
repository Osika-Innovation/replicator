import Foundation

/// §14 — the inverse solver: target amplitude at control points -> complex drive.
///
/// All three methods share the cached operator H and its exact adjoint H^H.
/// Because T0 is linear, no autodiff and no tensor framework appears anywhere.
public enum InverseSolver {

    /// What the control points MEAN.
    ///
    /// This distinction is load-bearing and was missing. A `focus` puts a
    /// pressure ANTINODE at the point. But a positive-contrast particle (any
    /// solid in air, Phi ~ 2.5) traps at pressure NODES — so compiling a focus
    /// onto an object's surface asks for a field that pushes matter AWAY from
    /// the very place you want it held. The overlays then show matter and traps
    /// sitting in the chamber's ambient node lattice with no relation to the
    /// object, which is exactly the symptom.
    ///
    /// A `twinTrap` is the standard levitation primitive: focus phases with a
    /// pi step across a plane through the target, which cancels the field AT the
    /// point while keeping high pressure either side — a node in a potential
    /// well, i.e. an actual trap.
    public enum TrapKind: String, Sendable, CaseIterable, Codable {
        case focus      // pressure maximum — correct for heating/ablation
        case twinTrap   // pressure NULL in a well — correct for holding matter
    }

    public enum Method: String, Sendable, CaseIterable, Codable {
        case ibp        // iterative back-propagation — the honest baseline
        case gspat      // Gerchberg-Saxton on the reduced point-to-point matrix
        case diffpat    // gradient descent with the analytic adjoint
    }

    public struct Constraints: Sendable {
        /// Per-channel amplitude ceiling. A drive that only works at infinite
        /// precision is not a compile result, it is a bug that reappears on
        /// hardware (§14).
        public var maxAmplitude: Double
        /// Phase quantization in bits. The bench anchor is ~1 deg at 40 kHz on
        /// an RP2350 at 150 MHz, i.e. roughly 8.5 bits.
        public var phaseBits: Int?
        public init(maxAmplitude: Double = 1.0, phaseBits: Int? = nil) {
            self.maxAmplitude = maxAmplitude; self.phaseBits = phaseBits
        }

        public func project(_ u: [Complex]) -> [Complex] {
            u.map { c in
                var mag = c.magnitude
                var ph = c.phase
                if mag > maxAmplitude { mag = maxAmplitude }
                if let b = phaseBits, b > 0 {
                    let levels = Double(1 << b)
                    ph = (ph / (2 * .pi) * levels).rounded() / levels * 2 * .pi
                }
                return Complex.expi(ph) * mag
            }
        }
    }

    /// Focus/trap targets: a point and the amplitude wanted there.
    public struct ControlPoint: Sendable {
        public var position: Vec3
        public var targetAmplitude: Double
        public init(position: Vec3, targetAmplitude: Double = 1.0) {
            self.position = position; self.targetAmplitude = targetAmplitude
        }
    }

    /// Reduced forward matrix at the control points only: Hc[c][g].
    ///
    /// Built from `Propagator.gateRow`, i.e. with the propagator's own wall
    /// images, element weights and couplings. (It used to re-walk the elements
    /// in free field with none of them, so every "walls" and "rainbow"
    /// condition solved its drive for a different machine than the one the
    /// field was then evaluated on.)
    static func controlMatrix(_ prop: Propagator, _ points: [ControlPoint]) -> [[Complex]] {
        points.map { prop.gateRow(at: $0.position) }
    }

    public static func solve(propagator: Propagator,
                             points: [ControlPoint],
                             method: Method = .gspat,
                             iterations: Int = 100,
                             constraints: Constraints = Constraints(),
                             trap: TrapKind = .focus,
                             twinAxis: Vec3 = Vec3(0, 0, 1)) -> [Complex] {
        let Hc = controlMatrix(propagator, points)
        let nE = propagator.gateCount
        var u: [Complex]
        switch method {
        case .ibp:      u = ibp(Hc, points, nE, constraints)
        case .gspat:    u = gspat(Hc, points, nE, iterations, constraints)
        case .diffpat:  u = diffpat(Hc, points, nE, iterations, constraints)
        }
        if trap == .twinTrap {
            u = applyTwinSignature(u, propagator: propagator,
                                   about: points.first?.position ?? .zero,
                                   axis: twinAxis)
        }
        return u
    }

    /// Twin-trap signature: flip the phase of every gate on one side of a plane
    /// through the target. The two halves arrive in antiphase at the point and
    /// cancel, producing a pressure null surrounded by high pressure — the
    /// standard acoustic levitation trap.
    ///
    /// Applied per GATE (not per element), because a gate is what the
    /// electronics can drive; splitting inside a gate is not realisable.
    static func applyTwinSignature(_ u: [Complex], propagator: Propagator,
                                   about target: Vec3, axis: Vec3) -> [Complex] {
        var centroid = [Vec3](repeating: .zero, count: u.count)
        var count = [Double](repeating: 0, count: u.count)
        for e in propagator.elements {
            guard e.gateIndex >= 0 && e.gateIndex < u.count else { continue }
            centroid[e.gateIndex] += e.position
            count[e.gateIndex] += 1
        }
        let ax = axis.normalized
        var out = u
        for g in u.indices where count[g] > 0 {
            let c = centroid[g] / count[g]
            if (c - target).dot(ax) < 0 { out[g] = -out[g] }
        }
        return out
    }

    /// IBP — one back-projection of the target phases. Trivial, fast, mediocre
    /// contrast; the baseline every other method must beat.
    static func ibp(_ Hc: [[Complex]], _ pts: [ControlPoint], _ nE: Int,
                    _ con: Constraints) -> [Complex] {
        var u = [Complex](repeating: .zero, count: nE)
        for (c, row) in Hc.enumerated() {
            for e in 0..<nE { u[e] += row[e].conjugate * pts[c].targetAmplitude }
        }
        return normalizeAndProject(u, con)
    }

    /// GS-PAT — Gerchberg-Saxton on the tiny control-point Gram matrix.
    static func gspat(_ Hc: [[Complex]], _ pts: [ControlPoint], _ nE: Int,
                      _ iterations: Int, _ con: Constraints) -> [Complex] {
        let nC = Hc.count
        // R = Hc Hc^H, an nC x nC matrix — tiny.
        var R = [[Complex]](repeating: [Complex](repeating: .zero, count: nC), count: nC)
        for i in 0..<nC {
            for j in 0..<nC {
                var acc = Complex.zero
                for e in 0..<nE { acc += Hc[i][e] * Hc[j][e].conjugate }
                R[i][j] = acc
            }
        }
        var phase = [Complex](repeating: .one, count: nC)
        for _ in 0..<iterations {
            var next = [Complex](repeating: .zero, count: nC)
            for i in 0..<nC {
                var acc = Complex.zero
                for j in 0..<nC { acc += R[i][j] * phase[j] }
                next[i] = acc
            }
            for i in 0..<nC {
                let m = next[i].magnitude
                phase[i] = m > 0 ? next[i] / m : .one
            }
        }
        var u = [Complex](repeating: .zero, count: nE)
        for c in 0..<nC {
            let w = phase[c] * pts[c].targetAmplitude
            for e in 0..<nE { u[e] += Hc[c][e].conjugate * w }
        }
        return normalizeAndProject(u, con)
    }

    /// Diff-PAT — Adam on L(u) = sum_c w_c (|Hu|_c - |p*|_c)^2 + lambda||u||^2,
    /// with the gradient supplied analytically through H^H (§14).
    static func diffpat(_ Hc: [[Complex]], _ pts: [ControlPoint], _ nE: Int,
                        _ iterations: Int, _ con: Constraints) -> [Complex] {
        var u = ibp(Hc, pts, nE, con)
        var m = [Complex](repeating: .zero, count: nE)
        var v = [Double](repeating: 0, count: nE)
        let b1 = 0.9, b2 = 0.999, eps = 1e-12
        let nC = Hc.count

        // Rescale the targets to what this aperture can actually deliver.
        //
        // Without this the objective is mis-scaled by orders of magnitude: H
        // carries physical units (rho*c*k*A/2pi), so |Hu| at unit drive is ~1e3
        // while the nominal target is 1. Adam then drives u toward zero to
        // satisfy an unreachable target, destroying the phase structure that
        // IBP got right — observed as a focusing gain of 0.20x against IBP's
        // 10.77x, i.e. the "optimizer" made it 50x worse.
        var achieved = [Double](repeating: 0, count: nC)
        for c in 0..<nC {
            var acc = Complex.zero
            for e in 0..<nE { acc += Hc[c][e] * u[e] }
            achieved[c] = acc.magnitude
        }
        let peakWanted = pts.map(\.targetAmplitude).max() ?? 1
        let peakAchieved = achieved.max() ?? 1
        let scale = peakAchieved / max(peakWanted, 1e-30)
        let targets = pts.map { $0.targetAmplitude * scale }
        // Adam's step is scale-free in the gradient but not in u; size it to the
        // drive magnitude so 80 iterations is a refinement, not a random walk.
        let lr = 0.02 * (u.map(\.magnitude).max() ?? 1)

        for t in 1...iterations {
            // forward
            var f = [Complex](repeating: .zero, count: nC)
            for c in 0..<nC {
                var acc = Complex.zero
                for e in 0..<nE { acc += Hc[c][e] * u[e] }
                f[c] = acc
            }
            // dL/df_c for L = sum (|f| - target)^2  ->  2(|f|-t) * f/|f|
            var g = [Complex](repeating: .zero, count: nE)
            for c in 0..<nC {
                let mag = f[c].magnitude
                guard mag > 1e-18 else { continue }
                let s = 2 * (mag - targets[c]) / mag
                let df = f[c] * s
                for e in 0..<nE { g[e] += Hc[c][e].conjugate * df }
            }
            for e in 0..<nE {
                m[e] = m[e] * b1 + g[e] * (1 - b1)
                v[e] = v[e] * b2 + g[e].magnitudeSquared * (1 - b2)
                let mh = m[e] / (1 - pow(b1, Double(t)))
                let vh = v[e] / (1 - pow(b2, Double(t)))
                u[e] -= mh * (lr / (vh.squareRoot() + eps))
            }
            u = con.project(u)
        }
        return normalizeAndProject(u, con)
    }

    static func normalizeAndProject(_ u: [Complex], _ con: Constraints) -> [Complex] {
        let peak = u.map(\.magnitude).max() ?? 1
        guard peak > 0 else { return u }
        return con.project(u.map { $0 / peak * con.maxAmplitude })
    }
}
