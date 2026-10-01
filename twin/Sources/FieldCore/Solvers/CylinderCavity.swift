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

    /// J_|m|(x), Catmull–Rom on the table; below the first step, the series.
    @inline(__always)
    public func j(_ m: Int, _ x: Double) -> Double {
        let mm = abs(m)
        precondition(mm <= maxOrder + 1 && x <= xMax, "Bessel table too small: J_\(mm)(\(x))")
        // Near the axis the spline extrapolates (clamped to its second
        // interval): fine for J itself, but the azimuthal gradient divides
        // J_m(μr) by r, and there the extrapolation error is the answer.
        if x < dx { return BesselTable.small(mm, x) }
        let u = x / dx
        let i = max(1, min(count - 3, Int(u)))
        let t = u - Double(i)
        let b = mm * count + i
        let p0 = values[b - 1], p1 = values[b], p2 = values[b + 1], p3 = values[b + 2]
        return p1 + 0.5 * t * (p2 - p0 + t * (2 * p0 - 5 * p1 + 4 * p2 - p3 + t * (3 * (p1 - p2) + p3 - p0)))
    }

    /// J_m(x) for small x, four terms of the series: (x/2)^m/m! · (1 − h²/(m+1)
    /// + h⁴/(2(m+1)(m+2)) − h⁶/(6(m+1)(m+2)(m+3))), h = x/2.
    public static func small(_ m: Int, _ x: Double) -> Double {
        let h = x / 2, h2 = h * h
        var t = 1.0
        if m > 0 { for k in 1...m { t *= h / Double(k) } }
        let a = Double(m + 1), b = Double(m + 2), c = Double(m + 3)
        return t * (1 - h2 / a + h2 * h2 / (2 * a * b) - h2 * h2 * h2 / (6 * a * b * c))
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
///
/// A lined (absorbing) side wall is exact too: with specific admittance β the
/// wall condition ∂p/∂r = ikβp turns each mode's radial wavenumber complex,
/// x = μa solving x J'_m(x) = i(kaβ) J_m(x), and the modes stay orthogonal
/// under the unconjugated product. `source(wallAdmittance:)` finds every zero
/// by continuation from its rigid one, and the fields read J_m at the complex
/// argument off the same real table (`complexJ`).
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
        // Orders up to X + a margin: J_m(x) is negligible for m ≫ x, and the
        // lined-wall modes read up to ~30 orders above their own (complexJ).
        // Arguments to X + 4: a lined wall's zeros sit up to π/2 above j'_mn.
        let M = Int(X) + 32
        let table = BesselTable(maxOrder: M, xMax: X + 4)
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
        /// The side wall's specific admittance (0 = rigid glass).
        public var wallAdmittance: Double = 0
        /// Per mode: the radial wavenumber μ (real j'/a for a rigid wall),
        /// λ = μ/Re μ, λ^{|m|−1}, the multiplication-theorem term count
        /// (0 = real argument), and ∫ψ² dA (unconjugated).
        public var mu: [Complex] = [], lambda: [Complex] = [], lambdaPow: [Complex] = []
        public var terms: [Int] = [], norm: [Complex] = []
    }

    /// Elements on the lower face (z ≈ 0) and the upper face (z ≈ L) radiate
    /// along their normals; anything else is ignored (the plates are the only
    /// sources of the free-standing machine).
    ///
    /// - Parameter wallAdmittance: specific acoustic admittance β of the side
    ///   wall, normalised to ρ0c (0 = rigid glass; a liner with normal-
    ///   incidence reflection R has β = (1 − R)/(1 + R)). EXACT: each mode's
    ///   zero is continued from j'_mn to the root of x J'_m(x) = i kaβ J_m(x).
    ///   Low modes graze the wall and turn pressure-release-like (toward the
    ///   Dirichlet zeros j_mn) with little loss; modes that meet the wall
    ///   head-on are the ones a liner kills. (The first version perturbed κ²
    ///   to first order in β, which fails once kaβ ≳ j'.)
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
        let a = radius
        // Radial wavenumbers: the rigid zeros, or their lined-wall continuations
        // (one per |m| — the ±m pair shares its radial function).
        var mu = [Complex](repeating: .zero, count: Q), lam = mu, lamPow = mu, nrm = mu
        var terms = [Int](repeating: 0, count: Q)
        let s = Complex(kc.re * a * beta, 0)
        mu.withUnsafeMutableBufferPointer { muB in
            lam.withUnsafeMutableBufferPointer { lamB in
                lamPow.withUnsafeMutableBufferPointer { lpB in
                    nrm.withUnsafeMutableBufferPointer { nB in
                        terms.withUnsafeMutableBufferPointer { tB in
                            DispatchQueue.concurrentPerform(iterations: Q) { q in
                                let md = modes[q]
                                guard beta != 0 else {
                                    muB[q] = Complex(md.zero / a, 0); lamB[q] = .one; lpB[q] = .one
                                    nB[q] = Complex(md.norm, 0); tB[q] = 0
                                    return
                                }
                                // The −m partner of a +m mode is its neighbour
                                // in the sorted list; both solve it, cheaply.
                                let x = robinZero(order: md.m, neumann: md.zero, s: s)
                                let am = abs(md.m)
                                let l = x / Complex(x.re, 0)
                                muB[q] = x / a; lamB[q] = l; lpB[q] = l.pow(am - 1)
                                tB[q] = CylinderCavity.termCount((l * l - .one).magnitude * x.re / 2)
                                // ∫ J_m(μr)² dA = πa²[J'_m(x)² + (1 − m²/x²) J_m(x)²]
                                let (j, jm1) = complexJ(am, x)
                                let jp = jm1 - j * Double(am) / x
                                let mm = Complex(Double(am * am), 0) / (x * x)
                                nB[q] = (jp * jp + (Complex.one - mm) * j * j) * (Double.pi * a * a)
                            }
                        }
                    }
                }
            }
        }
        var kappa = [Complex](repeating: .zero, count: Q), eKL = kappa, pre = kappa, invDen = kappa
        for q in 0..<Q {
            let k2 = kc * kc - mu[q] * mu[q]
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
        // Project the apertures: W += c · A · 2J1(μb)/(μb) · J_m(μ r_a) e^{−imφ_a} / N.
        // Elements are virtual (one per gate of a physical aperture), so the
        // Bessel part is evaluated once per distinct aperture.
        struct Key: Hashable { var x, y, z, area: Double; var mono: Bool }
        var index: [Key: Int] = [:]
        var uniq: [(r: Double, phi: Double, b: Double, mono: Bool)] = []
        var elemU = [Int](repeating: -1, count: elements.count)
        for (ei, el) in elements.enumerated() {
            let key = Key(x: el.position.x, y: el.position.y, z: el.position.z, area: el.area,
                          mono: el.directivity == .monopole)
            if let u = index[key] { elemU[ei] = u; continue }
            let u = uniq.count
            index[key] = u
            uniq.append(((el.position.x * el.position.x + el.position.y * el.position.y).squareRoot(),
                         atan2(el.position.y, el.position.x), el.equivalentRadius, key.mono))
            elemU[ei] = u
        }
        var lower = [Complex](repeating: .zero, count: Q * G), upper = lower
        let half = length / 2
        lower.withUnsafeMutableBufferPointer { lo in
            upper.withUnsafeMutableBufferPointer { up in
                DispatchQueue.concurrentPerform(iterations: Q) { q in
                    let md = modes[q]
                    let am = abs(md.m)
                    let muq = mu[q], invN = Complex.one / nrm[q]
                    var val = [Complex](repeating: .zero, count: uniq.count)
                    for (u, ap) in uniq.enumerated() {
                        // A monopole element is a point velocity source (the
                        // Propagator's `.monopole`: D = 1, same baffled prefactor).
                        var form = Complex.one
                        if !ap.mono {
                            let w = muq * ap.b
                            if w.magnitude > 1e-6 { form = complexJ(1, w).j * 2.0 / w }
                        }
                        let jm = terms[q] == 0 ? Complex(table.j(am, muq.re * ap.r), 0)
                            : CylinderCavity.radial(table, am, gamma: muq.re, lambda: lam[q],
                                                    lambdaPow: lamPow[q], r: ap.r, terms: terms[q]).j
                        val[u] = form * jm * invN * Complex.expi(-Double(md.m) * ap.phi)
                    }
                    for (ei, el) in elements.enumerated() {
                        let gi = el.gateIndex
                        guard gi >= 0 && gi < G else { continue }
                        let w = weights?[ei] ?? 1
                        if w == 0 { continue }
                        let v = (coupling?[ei] ?? .one) * val[elemU[ei]] * (el.area * w)
                        if el.position.z < half { lo[q * G + gi] += v } else { up[q * G + gi] += v }
                    }
                }
            }
        }
        var src = Source(frequency: f, modeCount: Q, gateCount: G, kappa: kappa, eKL: eKL, pre: pre,
                         invDen: invDen, lower: lower, upper: upper, omegaRho: wr,
                         reflectionLower: rLo, reflectionUpper: rUp, length: length)
        src.wallAdmittance = beta
        src.mu = mu; src.lambda = lam; src.lambdaPow = lamPow; src.terms = terms; src.norm = nrm
        return src
    }

    /// Multiplication-theorem terms for |t| (t ≈ i·Im x at the wall): the
    /// first K with |t|^{K+1}/(K+1)! < 1e-12.
    static func termCount(_ t: Double) -> Int {
        if t < 1e-14 { return 0 }
        var k = 0, bound = 1.0
        repeat { k += 1; bound *= t / Double(k) } while (bound >= 1e-12 || Double(k) < t) && k < 80
        return k
    }

    /// J_{|m|−1}, J_|m|, J_{|m|+1} at μr for complex μ = γλ, from the real
    /// table at z = γr: J_ν(λz) = λ^ν Σ_k (−t)^k/k! J_{ν+k}(z), t = (λ² − 1)z/2
    /// (DLMF 10.23.1). Orders below the table's reach (J_{−1} = −J_1) and above
    /// it (negligible) are handled here.
    @inline(__always)
    static func radial(_ T: BesselTable, _ am: Int, gamma: Double, lambda: Complex, lambdaPow: Complex,
                       r: Double, terms K: Int) -> (jm1: Complex, j: Complex, jp1: Complex) {
        let z = gamma * r
        @inline(__always) func L(_ n: Int) -> Double {
            n < 0 ? -T.j(1, z) : (n <= T.maxOrder + 1 ? T.j(n, z) : 0)
        }
        let mt = (lambda * lambda - .one) * (-z / 2)
        var ck = Complex.one
        var sM1 = Complex.zero, s0 = Complex.zero, sP1 = Complex.zero
        var lm1 = L(am - 1), l0 = L(am), lp1 = L(am + 1)
        for k in 0...K {
            sM1 += ck * lm1; s0 += ck * l0; sP1 += ck * lp1
            ck = ck * mt * (1 / Double(k + 1))
            lm1 = l0; l0 = lp1; lp1 = L(am + k + 2)
        }
        let lm = lambdaPow * lambda
        return (lambdaPow * sM1, lm * s0, lm * lambda * sP1)
    }

    /// J_|m|(x) and J_{|m|−1}(x) at a complex argument: the multiplication
    /// theorem about z = Re x off the real table, a power series near 0.
    public func complexJ(_ m: Int, _ x: Complex) -> (j: Complex, jm1: Complex) {
        let am = abs(m)
        if x.re < 0 {                                   // J_n(−x) = (−1)^n J_n(x)
            let (j, jm1) = complexJ(am, -x)
            let sg = am % 2 == 0 ? 1.0 : -1.0
            return (j * sg, jm1 * -sg)
        }
        if x.magnitude < 1 || x.re < 2 * abs(x.im) {
            func series(_ n: Int) -> Complex {          // J_n(x), n ≥ 0
                let h = x * 0.5, h2 = -(h * h)
                var term = Complex.one
                if n > 0 { for i in 1...n { term = term * h * (1 / Double(i)) } }
                var sum = term
                for k in 1..<200 {
                    term = term * h2 * (1 / (Double(k) * Double(k + n)))
                    sum += term
                    if term.magnitude < 1e-17 * max(sum.magnitude, 1e-300) { break }
                }
                return sum
            }
            return (series(am), am == 0 ? -series(1) : series(am - 1))
        }
        let lam = x / Complex(x.re, 0)
        let t = (lam * lam - .one).magnitude * x.re / 2
        let K = max(CylinderCavity.termCount(t), 2)
        let r3 = CylinderCavity.radial(table, am, gamma: x.re, lambda: lam, lambdaPow: lam.pow(am - 1),
                                       r: 1, terms: K)
        return (r3.j, r3.jm1)
    }

    /// The zero x = μa of the lined-wall condition x J'_m(x) = i s J_m(x)
    /// (s = kaβ) that the rigid zero x0 = j'_mn continues into, followed along
    /// s·τ, τ: 0 → 1, with an Euler predictor and a Newton corrector. Each
    /// track runs from j'_mn toward the Dirichlet zero above it and never
    /// crosses another, so a step that lands near its prediction is the same
    /// zero. The m = 0 plane-wave mode starts off its branch point,
    /// x² ≈ −2iτs.
    public func robinZero(order m: Int, neumann x0: Double, s: Complex) -> Complex {
        let am = abs(m), md = Double(am)
        let I = Complex(0, 1)
        func eval(_ x: Complex, _ tau: Double) -> (f: Complex, df: Complex, dfdtau: Complex) {
            let (j, jm1) = complexJ(am, x)
            let xjp = x * jm1 - j * md                  // x J'_m(x)
            let st = s * tau
            let f = xjp - I * st * j
            let df = -(x - Complex(md * md, 0) / x) * j - I * st * (xjp / x)
            return (f, df, -(I * s * j))
        }
        var tau = 0.0
        var x = Complex(x0, 0)
        if x0 == 0 {
            tau = min(1, 1e-6 / max(s.magnitude, 1e-300))
            x = (Complex(0, -2) * s * tau).squareRoot
            if x.re < 0 { x = -x }
        }
        var h = 1.0 - tau
        var guardSteps = 0
        while tau < 1 && guardSteps < 4000 {
            guardSteps += 1
            let e0 = eval(x, tau)
            let v = -(e0.dfdtau / e0.df)                 // dx/dτ
            h = min(h, 1 - tau, 0.2 / max(v.magnitude, 1e-12))
            var accepted = false
            for _ in 0..<60 {
                let tn = min(1, tau + h)
                let xp = x + v * (tn - tau)
                var xn = xp, ok = false
                for _ in 0..<16 {
                    guard xn.re > 0 && xn.re < table.xMax - 0.5 else { break }
                    let e = eval(xn, tn)
                    let dx = e.f / e.df
                    xn = xn - dx
                    if dx.magnitude < 1e-11 * max(1, xn.magnitude) { ok = true; break }
                }
                if ok && (xn - xp).magnitude < 0.1 && xn.re > 0 {
                    x = xn; tau = tn; accepted = true; h *= 2
                    break
                }
                h *= 0.5
            }
            if !accepted { break }
        }
        return x
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
        let lined = !s.terms.isEmpty
        for q in 0..<s.modeCount {
            let md = modes[q]
            let e = Complex.expi(Double(md.m) * phi)
            let psi: Complex, dpsiR: Complex
            if lined && s.terms[q] > 0 {
                let t3 = CylinderCavity.radial(table, abs(md.m), gamma: s.mu[q].re, lambda: s.lambda[q],
                                               lambdaPow: s.lambdaPow[q], r: r, terms: s.terms[q])
                psi = e * t3.j
                dpsiR = e * s.mu[q] * ((t3.jm1 - t3.jp1) * 0.5)
            } else {
                let g = lined ? s.mu[q].re : md.zero / radius
                psi = e * table.j(md.m, g * r)
                dpsiR = e * (table.jPrime(md.m, g * r) * g)
            }
            // radial and azimuthal derivatives of ψ → Cartesian
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
