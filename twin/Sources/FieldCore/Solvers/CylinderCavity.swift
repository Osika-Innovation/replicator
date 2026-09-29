import Foundation

/// J_0 … J_M on a uniform grid in x, by Miller's downward recurrence (stable
/// for every order and argument), normalised with J0 + 2 Σ J_2k = 1, and read
/// back with Catmull–Rom interpolation (error ~dx⁴). The cavity's modes need
/// every order up to ~kR ≈ 300 at 70 kHz, which no fixed-order formula covers.
public final class BesselTable: @unchecked Sendable {
    public let maxOrder: Int
    public let dx: Double
    /// Samples per order.
    public let count: Int
    /// Row-major [m · count + i], m = 0 … maxOrder + 1 (one spare for J').
    public let values: [Double]
    public var xMax: Double { Double(count - 3) * dx }

    public init(maxOrder: Int, xMax: Double, dx: Double = 0.005) {
        let M = maxOrder + 1
        let n = Int((xMax / dx).rounded(.up)) + 4
        var v = [Double](repeating: 0, count: (M + 1) * n)
        v.withUnsafeMutableBufferPointer { buf in
            DispatchQueue.concurrentPerform(iterations: n) { i in
                let js = BesselTable.allOrders(Double(i) * dx, upTo: M)
                for m in 0...M { buf[m * n + i] = js[m] }
            }
        }
        self.maxOrder = maxOrder
        self.dx = dx
        self.count = n
        self.values = v
    }

    /// J_0 … J_M at one x (Miller's algorithm).
    public static func allOrders(_ x: Double, upTo M: Int) -> [Double] {
        var out = [Double](repeating: 0, count: M + 1)
        if x < 1e-12 { out[0] = 1; return out }
        let big = max(M, Int(x))
        let N = 2 * ((big + 16 + Int((40.0 * Double(big)).squareRoot())) / 2)
        var jp1 = 0.0, j = 1e-30, sum = 0.0
        for k in stride(from: N, through: 1, by: -1) {
            let jm1 = 2 * Double(k) / x * j - jp1           // J_{k-1}
            jp1 = j; j = jm1
            let idx = k - 1
            if idx <= M { out[idx] = j }
            if idx > 0 && idx % 2 == 0 { sum += 2 * j }
            if abs(j) > 1e250 {
                j *= 1e-250; jp1 *= 1e-250; sum *= 1e-250
                if idx <= M { for q in idx...M { out[q] *= 1e-250 } }
            }
        }
        sum += j                                             // + J_0
        let s = 1 / sum
        for q in 0...M { out[q] *= s }
        return out
    }

    /// J_|m|(x), Catmull–Rom on the table.
    @inline(__always)
    public func j(_ m: Int, _ x: Double) -> Double {
        let mm = abs(m)
        precondition(mm <= maxOrder + 1 && x <= xMax, "Bessel table too small: J_\(mm)(\(x))")
        let u = x / dx
        let i = max(1, min(count - 3, Int(u)))
        let t = u - Double(i)
        let b = mm * count + i
        let p0 = values[b - 1], p1 = values[b], p2 = values[b + 1], p3 = values[b + 2]
        return p1 + 0.5 * t * (p2 - p0 + t * (2 * p0 - 5 * p1 + 4 * p2 - p3 + t * (3 * (p1 - p2) + p3 - p0)))
    }

    /// J'_|m|(x) = (J_{m-1} − J_{m+1})/2  (J'_0 = −J_1).
    @inline(__always)
    public func jPrime(_ m: Int, _ x: Double) -> Double {
        let mm = abs(m)
        return mm == 0 ? -j(1, x) : 0.5 * (j(mm - 1, x) - j(mm + 1, x))
    }

    /// Zeros of J'_m in (0, X] (for m = 0 also the trivial zero at 0).
    ///
    /// The scan starts at x = m: J'_m has no zeros below it for m ≥ 1
    /// (j'_m1 > m), and down there high orders underflow to exactly 0 in the
    /// table — the first version took those zeros for modes (and got NaN).
    public func primeZeros(order m: Int, upTo X: Double) -> [Double] {
        var z: [Double] = m == 0 ? [0] : []
        let start = max(dx, Double(abs(m)))
        guard start < X else { return z }
        var x0 = start, f0 = jPrime(m, x0)
        var x = x0
        while x < X {
            x = min(X, x0 + dx)
            let f = jPrime(m, x)
            if f0 * f < 0 || (f == 0 && f0 != 0) {
                var lo = x0, hi = x, flo = f0
                for _ in 0..<50 {
                    let mid = 0.5 * (lo + hi), fm = jPrime(m, mid)
                    if flo * fm <= 0 { hi = mid } else { lo = mid; flo = fm }
                }
                z.append(0.5 * (lo + hi))
            }
            x0 = x; f0 = f
            if x >= X { break }
        }
        return z
    }
}

/// The build chamber as a rigid-walled cylinder (the glass) closed by the two
/// plates, each with pressure reflection R.
///
/// The plate-image model knows only the plates; glass is an acoustic mirror
/// (69–83 dB transmission loss at 40–200 kHz), and a chamber's side wall is
/// what fills in the side view and turns a column of traps into speckle. For a
/// cylinder the exact field has a closed modal form:
///
///     p(r, φ, z) = Σ_mn J_m(γ r) e^{imφ} [W0_mn Z0_mn(z) + WL_mn ZL_mn(z)],
///     γ = j'_mn / a,  κ = √(k² − γ²) (Im κ ≥ 0, k complex with air absorption),
///     Z0 = (ωρ0/κ)(e^{iκz} + R_L e^{iκ(2L−z)}) / (1 − R_0 R_L e^{2iκL}),
///     ZL = (ωρ0/κ)(e^{iκ(L−z)} + R_0 e^{iκ(L+z)}) / (1 − R_0 R_L e^{2iκL}),
///
/// where W0, WL project the apertures' normal velocity (with the piston form
/// factor 2J1(γb)/(γb)) onto each mode. Between the plates this is the image
/// series summed in closed form; across the chamber the glass reflects every
/// order exactly. At 40 kHz it is ~10⁴ mode coefficients per gate against
/// ~17 000 apertures × 7 image paths — the chamber's "screen", made literal.
public final class CylinderCavity: @unchecked Sendable {
    public let radius: Double
    public let length: Double
    public let reflectionLower: Double
    public let reflectionUpper: Double
    public let table: BesselTable

    public struct Mode: Sendable {
        public var m: Int
        /// j'_mn
        public var zero: Double
        /// ∫ |ψ|² dA
        public var norm: Double
    }
    /// Every mode with j'_mn ≤ maxGamma·a, both signs of m, sorted by j'.
    public let modes: [Mode]

    public init(radius: Double, length: Double, reflectionLower: Double = 0.9,
                reflectionUpper: Double = 0.9, maxGamma: Double) {
        self.radius = radius
        self.length = length
        self.reflectionLower = reflectionLower
        self.reflectionUpper = reflectionUpper
        let X = maxGamma * radius
        // Orders up to X + a margin: J_m(x) is negligible for m ≫ x.
        let M = Int(X) + 24
        let table = BesselTable(maxOrder: M, xMax: X + 2)
        self.table = table
        var ms: [Mode] = []
        let perOrder: [[Double]] = (0...M).map { table.primeZeros(order: $0, upTo: X) }
        for m in 0...M {
            for z in perOrder[m] {
                let n = z == 0 ? Double.pi * radius * radius
                    : Double.pi * radius * radius * (1 - Double(m * m) / (z * z)) * pow(table.j(m, z), 2)
                ms.append(Mode(m: m, zero: z, norm: n))
                if m > 0 { ms.append(Mode(m: -m, zero: z, norm: n)) }
            }
        }
        self.modes = ms.sorted { $0.zero < $1.zero }
    }

    /// Modes needed at frequency f for points at least `zMin` from either
    /// plate: propagating ones plus evanescent ones not yet decayed by 1/tol.
    public func gammaMax(frequency f: Double, medium: Medium, zMin: Double,
                         tolerance: Double = 1e-4) -> Double {
        let k = medium.wavenumber(at: f)
        let e = log(1 / tolerance) / max(zMin, 1e-4)
        return (k * k + e * e).squareRoot()
    }

    public func modeCount(maxGamma: Double) -> Int {
        let X = maxGamma * radius
        var lo = 0, hi = modes.count
        while lo < hi { let mid = (lo + hi) / 2; if modes[mid].zero <= X { lo = mid + 1 } else { hi = mid } }
        return lo
    }

    /// Per-frequency source: the apertures' modal coefficients per gate and
    /// face, and each mode's axial propagation constants.
    public struct Source: Sendable {
        public var frequency: Double
        public var modeCount: Int
        public var gateCount: Int
        /// κ, e^{iκL}, ωρ0/κ, 1/(1 − R0 RL e^{2iκL}) per mode.
        public var kappa: [Complex], eKL: [Complex], pre: [Complex], invDen: [Complex]
        /// W0 and WL per [q · gateCount + g].
        public var lower: [Complex], upper: [Complex]
        public var omegaRho: Double
        public var reflectionLower: Double, reflectionUpper: Double
        public var length: Double
    }

    /// Elements on the lower face (z ≈ 0) and the upper face (z ≈ L) radiate
    /// along their normals; anything else is ignored (the plates are the only
    /// sources of the free-standing machine).
    ///
    /// - Parameter wallAdmittance: specific admittance β of the side wall
    ///   (0 = rigid glass; β = (1 − R)/(1 + R) for a normal-incidence
    ///   reflection R). First-order perturbation: each mode's axial wavenumber
    ///   picks up κ² += 2ikβ/(a(1 − m²/j'²)) — the modes that graze the wall
    ///   most (whispering gallery, j' ≈ m) are damped hardest; mode shapes are
    ///   unchanged, so the table stays valid. Accurate for β ≪ 1.
    public func source(elements: [Element], coupling: [Complex]?, weights: [Double]? = nil,
                       gateCount G: Int, frequency f: Double, medium: Medium,
                       zMin: Double, wallAdmittance beta: Double = 0,
                       plateReflection: Double? = nil) -> Source {
        // A per-call plate reflection reuses this cavity's modes and table.
        let rLo = plateReflection ?? reflectionLower, rUp = plateReflection ?? reflectionUpper
        let Q = modeCount(maxGamma: gammaMax(frequency: f, medium: medium, zMin: zMin))
        precondition(Q > 0 && Q <= modes.count, "cavity built with too few modes for \(f) Hz")
        let kc = Complex(medium.wavenumber(at: f), medium.absorption(at: f))
        let omega = 2 * Double.pi * f
        let wr = omega * medium.density
        var kappa = [Complex](repeating: .zero, count: Q), eKL = kappa, pre = kappa, invDen = kappa
        for q in 0..<Q {
            let g = modes[q].zero / radius
            var k2 = kc * kc - Complex(g * g, 0)
            if beta > 0 {
                let md = modes[q]
                let shape = md.zero == 0 ? 1.0 : max(1e-3, 1 - Double(md.m * md.m) / (md.zero * md.zero))
                k2 = k2 + Complex(0, 2 * kc.re * beta / (radius * shape))
            }
            var kz = k2.squareRoot
            if kz.im < 0 { kz = kz * -1.0 }
            kappa[q] = kz
            let e = (Complex(0, 1) * kz * length).exp
            eKL[q] = e
            // Sign: the twin's Propagator uses the Rayleigh prefactor +iωρ0/2π
            // (a uniform piston gives p = −ρ0 c u), so the modal field carries
            // the same global sign. Forces see |p|² and |∇p|² only.
            pre[q] = Complex(-wr, 0) / kz
            invDen[q] = Complex.one / (Complex.one - e * e * (rLo * rUp))
        }
        // Project the apertures: W += c · A · 2J1(γb)/(γb) · J_m(γ r_a) e^{−imφ_a} / N.
        var lower = [Complex](repeating: .zero, count: Q * G), upper = lower
        let half = length / 2
        lower.withUnsafeMutableBufferPointer { lo in
            upper.withUnsafeMutableBufferPointer { up in
                DispatchQueue.concurrentPerform(iterations: Q) { q in
                    let md = modes[q]
                    let g = md.zero / radius
                    for (ei, el) in elements.enumerated() {
                        let gi = el.gateIndex
                        guard gi >= 0 && gi < G else { continue }
                        let w = weights?[ei] ?? 1
                        if w == 0 { continue }
                        let c = (coupling?[ei] ?? .one) * w
                        let r = (el.position.x * el.position.x + el.position.y * el.position.y).squareRoot()
                        let phi = atan2(el.position.y, el.position.x)
                        // A monopole element is a point velocity source (the
                        // Propagator's `.monopole`: D = 1, same baffled prefactor).
                        let gb = el.directivity == .monopole ? 0 : g * el.equivalentRadius
                        let form = gb < 1e-6 ? 1.0 : 2 * besselJ1(gb) / gb
                        let v = c * (el.area * form * table.j(md.m, g * r) / md.norm)
                            * Complex.expi(-Double(md.m) * phi)
                        if el.position.z < half { lo[q * G + gi] += v } else { up[q * G + gi] += v }
                    }
                }
            }
        }
        return Source(frequency: f, modeCount: Q, gateCount: G, kappa: kappa, eKL: eKL, pre: pre,
                      invDen: invDen, lower: lower, upper: upper, omegaRho: wr,
                      reflectionLower: rLo, reflectionUpper: rUp, length: length)
    }

    /// Gate rows of p and ∇p at x (the same contract as
    /// `Propagator.gateGradientRows`).
    public func rows(at x: Vec3, source s: Source) -> (p: [Complex], grad: [[Complex]]) {
        let G = s.gateCount
        var p = [Complex](repeating: .zero, count: G)
        var gr = [[Complex]](repeating: [Complex](repeating: .zero, count: G), count: 3)
        let r = max((x.x * x.x + x.y * x.y).squareRoot(), 1e-9)
        let phi = atan2(x.y, x.x)
        let cph = cos(phi), sph = sin(phi)
        for q in 0..<s.modeCount {
            let md = modes[q]
            let g = md.zero / radius
            let jm = table.j(md.m, g * r), jp = table.jPrime(md.m, g * r) * g
            let e = Complex.expi(Double(md.m) * phi)
            let psi = e * jm
            // radial and azimuthal derivatives of ψ → Cartesian
            let dpsiR = e * jp
            let dpsiPhi = Complex(0, Double(md.m)) * psi
            let dpsiX = dpsiR * cph - dpsiPhi * (sph / r)
            let dpsiY = dpsiR * sph + dpsiPhi * (cph / r)
            let kz = s.kappa[q]
            let e1 = (Complex(0, 1) * kz * x.z).exp
            let e2 = (Complex(0, 1) * kz * (s.length - x.z)).exp
            let a0 = s.pre[q] * s.invDen[q], rl = s.eKL[q] * s.reflectionUpper, r0 = s.eKL[q] * s.reflectionLower
            let z0 = a0 * (e1 + rl * e2), zl = a0 * (e2 + r0 * e1)
            let iwr = Complex(0, -s.omegaRho) * s.invDen[q]          // pre · iκ
            let dz0 = iwr * (e1 - rl * e2), dzl = iwr * (r0 * e1 - e2)
            for gi in 0..<G {
                let w0 = s.lower[q * G + gi], wl = s.upper[q * G + gi]
                let zsum = w0 * z0 + wl * zl
                p[gi] += psi * zsum
                gr[0][gi] += dpsiX * zsum
                gr[1][gi] += dpsiY * zsum
                gr[2][gi] += psi * (w0 * dz0 + wl * dzl)
            }
        }
        return (p, gr)
    }
}
