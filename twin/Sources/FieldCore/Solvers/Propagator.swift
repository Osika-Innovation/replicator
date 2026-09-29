import Foundation

/// A regular evaluation lattice over a build volume. The propagator's codomain.
public struct FieldLattice: Sendable {
    public let origin: Vec3
    public let spacing: Double
    public let nx: Int, ny: Int, nz: Int

    public init(volume: BuildVolume, spacing: Double) {
        self.spacing = spacing
        self.origin = Vec3(-volume.radius, -volume.radius, 0)
        self.nx = max(1, Int((2 * volume.radius / spacing).rounded(.up)) + 1)
        self.ny = self.nx
        self.nz = max(1, Int((volume.height / spacing).rounded(.up)) + 1)
    }

    public init(origin: Vec3, spacing: Double, nx: Int, ny: Int, nz: Int) {
        self.origin = origin; self.spacing = spacing
        self.nx = nx; self.ny = ny; self.nz = nz
    }

    public var count: Int { nx * ny * nz }

    public func index(_ i: Int, _ j: Int, _ k: Int) -> Int { (k * ny + j) * nx + i }

    public func position(_ i: Int, _ j: Int, _ k: Int) -> Vec3 {
        Vec3(origin.x + Double(i) * spacing,
             origin.y + Double(j) * spacing,
             origin.z + Double(k) * spacing)
    }

    public func position(linear n: Int) -> Vec3 {
        let i = n % nx, j = (n / nx) % ny, k = n / (nx * ny)
        return position(i, j, k)
    }

    public var positions: [Vec3] { (0..<count).map { position(linear: $0) } }
}

/// T0 — the Rayleigh–Sommerfeld / angular-spectrum propagator (§11).
///
/// Builds the dense complex operator H mapping element drives to complex
/// pressure at field points:
///
///     p(x) = sum_e u_e * H_e(x)
///     H_e(x) = (i * rho0 * c0 * k * A_e / 2pi) * D_e(theta) * exp(i k r) / r
///
/// Two properties this whole architecture leans on, called out in the spec and
/// repeated here because they are load-bearing:
///  1. H is LINEAR in u, so the adjoint the inverse solver needs is literally
///     H^H — exact, free, no autodiff, no framework (§14).
///  2. T0 is a FREE-FIELD propagator. It knows nothing about scattering off the
///     workpiece. That is why gate G5 compares it to FDTD in an EMPTY chamber,
///     and why the scan path belongs to T1 (§5).
public struct Propagator: Sendable {
    public let elements: [Element]
    public let lattice: FieldLattice
    public let frequency: Double
    public let medium: Medium

    /// Number of independently addressable gates — the control dimension.
    public let gateCount: Int

    /// Row-major (fieldPoint, GATE) — H[n * gateCount + g].
    ///
    /// CRITICAL: the operator is built at GATE granularity, not element
    /// granularity. Elements are the discretization of the radiating surface;
    /// a gate is what the electronics can actually drive independently (RH-1
    /// has 24 acoustic channels, discretized into thousands of elements). All
    /// elements sharing a gateIndex share one complex drive, so their
    /// contributions are summed into a single column.
    ///
    /// This is both the physically correct control granularity AND the reason
    /// the operator fits in memory: an element-granular H over a 2.5M-point
    /// lattice would be ~470 GB. Gate-granular it is ~100 MB. The first
    /// version of this file got that wrong and was killed by the OOM killer,
    /// which is a blunt but effective code review.
    public let H: [Complex]

    /// Axial image sources modelling the two rigid caps at z = 0 and z = H.
    ///
    /// T0 is a FREE-FIELD propagator; RH-1 is a closed, high-Q cavity. In a
    /// reverberant cavity, focusing works through the multipath and the CAVITY
    /// becomes the aperture — controllable DOF scale with the time-bandwidth
    /// product, not with channel count (Draeger & Fink: focusing in chaotic
    /// cavities down to a single channel). Modelling the machine as an open-air
    /// array systematically understates it.
    ///
    /// The parallel caps are the one wall pair whose images are exact and cheap,
    /// and they are the dominant axial multipath. This is the same virtual-source
    /// mechanism ranked first for IMAGING in spec §18, applied to transmit by
    /// reciprocity — and it carries the same honest cost: it presumes the cavity
    /// Green's function is known, which for the real machine means measured.
    public struct Walls: Sendable {
        public var capSeparation: Double     // metres; 0 disables
        public var order: Int                // image orders per direction
        public var reflectionCoefficient: Double
        public init(capSeparation: Double, order: Int = 3,
                    reflectionCoefficient: Double = 0.9) {
            self.capSeparation = capSeparation
            self.order = order
            self.reflectionCoefficient = reflectionCoefficient
        }
        public static let none = Walls(capSeparation: 0, order: 0)

        /// Image sources (z, weight) of a source at `z0` between rigid walls at
        /// z = 0 and z = L, up to `order` reflections. Reflections alternate
        /// between the walls, so an m-bounce path has exactly two images:
        ///   m even:  z0 ± m·L            (m/2 round trips)
        ///   m odd:  −z0 + (1 ± m)·L      (m = 1 gives −z0 and 2L − z0)
        /// each weighted R^m. (The first version of this appended the two
        /// first-order images again at every order and put fourth-order images
        /// where third-order ones belong; the unit test pins the series now.)
        public func images(of z0: Double) -> [(z: Double, weight: Double)] {
            var out: [(z: Double, weight: Double)] = [(z0, 1)]
            guard capSeparation > 0 && order > 0 else { return out }
            let L = capSeparation
            for m in 1...order {
                let w = pow(reflectionCoefficient, Double(m))
                if m % 2 == 0 {
                    out.append((z0 + Double(m) * L, w))
                    out.append((z0 - Double(m) * L, w))
                } else {
                    out.append((-z0 + Double(1 + m) * L, w))
                    out.append((-z0 + Double(1 - m) * L, w))
                }
            }
            return out
        }
    }

    public let walls: Walls
    public let elementWeights: [Double]?
    /// Complex per-element coupling (e.g. a horn transfer from a throat
    /// element to an aperture). Multiplies the element's contribution.
    public let elementCoupling: [Complex]?
    /// Per-element image table, computed once.
    let imageTable: [[(z: Double, weight: Double)]]

    /// - Parameter precomputedH: an operator already built for exactly these
    ///   arguments (the GPU port-field build, `FieldGPU.PortFieldsGPU`). The
    ///   point evaluators below still walk the elements, so a gate can check
    ///   that the two agree.
    public init(elements: [Element], lattice: FieldLattice,
                frequency: Double, medium: Medium, gateCount: Int? = nil,
                elementWeights: [Double]? = nil,
                elementCoupling: [Complex]? = nil,
                walls: Walls = .none,
                precomputedH: [Complex]? = nil) {
        self.elements = elements
        self.lattice = lattice
        self.frequency = frequency
        self.medium = medium
        self.walls = walls
        self.elementWeights = elementWeights
        self.elementCoupling = elementCoupling
        let table = elements.map { walls.images(of: $0.position.z) }
        self.imageTable = table
        let nG = gateCount ?? ((elements.map(\.gateIndex).max() ?? -1) + 1)
        self.gateCount = nG

        let nP = lattice.count
        if let pre = precomputedH {
            precondition(pre.count == nP * nG, "precomputed H has the wrong shape")
            self.H = pre
            return
        }
        let k = medium.wavenumber(at: frequency)
        let alpha = medium.absorption(at: frequency)
        let prefactorMag = medium.density * medium.soundSpeed * k / (2 * .pi)

        var h = [Complex](repeating: .zero, count: nP * nG)
        let positions = lattice.positions

        h.withUnsafeMutableBufferPointer { buf in
            DispatchQueue.concurrentPerform(iterations: nP) { n in
                let x = positions[n]
                let base = n * nG
                for (ei, el) in elements.enumerated() {
                    let g = el.gateIndex
                    guard g >= 0 && g < nG else { continue }
                    let w = elementWeights?[ei] ?? 1.0
                    if w == 0 { continue }
                    let c = elementCoupling?[ei] ?? Complex.one
                    // Direct path plus axial image sources from the two caps.
                    var acc = Complex.zero
                    for (zi, refl) in table[ei] {
                        let src = Vec3(el.position.x, el.position.y, zi)
                        let d = x - src
                        let r = max(d.length, 1e-9)
                        let cosTheta = abs(d.dot(el.normal)) / r
                        let dir = el.directivity == .monopole ? 1.0
                            : Propagator.pistonDirectivity(
                                k: k, a: el.equivalentRadius, cosTheta: cosTheta)
                        // Air absorption along the whole path, images included.
                        let amp = prefactorMag * el.area * dir * w * refl * exp(-alpha * r) / r
                        let phase = Complex.expi(k * r)
                        acc += Complex(-phase.im, phase.re) * amp
                    }
                    buf[base + g] += acc * c
                }
            }
        }
        self.H = h
    }

    /// Circular-piston directivity 2*J1(ka sin θ)/(ka sin θ), falling back to
    /// cos θ for elements small against the wavelength (§11).
    @inline(__always)
    static func pistonDirectivity(k: Double, a: Double, cosTheta: Double) -> Double {
        let ka = k * a
        if ka < 0.5 { return cosTheta }                 // sub-wavelength element
        let sinTheta = max(0, 1 - cosTheta * cosTheta).squareRoot()
        let x = ka * sinTheta
        if x < 1e-6 { return 1.0 }
        return 2 * besselJ1(x) / x
    }

    /// Directivity and its slope dD/d(cos θ). The piston's D = 2J1(x)/x with
    /// x = ka·sin θ has dD/dx = −2J2(x)/x, so dD/dcosθ = 2J2(x)·cosθ/sin²θ
    /// (→ (ka)²·cosθ/4 on axis); the small-element branch D = cos θ has slope 1.
    /// The gradient of a term then carries D' ∇cosθ as well as the radial part —
    /// dropping it (the old "locally constant" shortcut) misses 1–2 % of the
    /// lateral gradient at ka ≈ 1.8.
    @inline(__always)
    static func pistonDirectivityAndSlope(k: Double, a: Double, cosTheta c: Double) -> (Double, Double) {
        let ka = k * a
        if ka < 0.5 { return (c, 1) }
        let s2 = max(0, 1 - c * c)
        let x = ka * s2.squareRoot()
        if x < 1e-3 { return (1 - x * x / 8, ka * ka * c / 4) }
        let j1 = besselJ1(x), j2 = 2 * j1 / x - besselJ0(x)
        return (2 * j1 / x, 2 * j2 * c / s2)
    }

    /// Forward: complex drive -> complex pressure field.
    public func forward(_ drive: [Complex]) -> [Complex] {
        precondition(drive.count == gateCount, "drive must be gate-granular")
        let nE = gateCount, nP = lattice.count
        var out = [Complex](repeating: .zero, count: nP)
        out.withUnsafeMutableBufferPointer { o in
            H.withUnsafeBufferPointer { h in
                DispatchQueue.concurrentPerform(iterations: nP) { n in
                    var acc = Complex.zero
                    let base = n * nE
                    for e in 0..<nE { acc += h[base + e] * drive[e] }
                    o[n] = acc
                }
            }
        }
        return out
    }

    /// Adjoint H^H: field residual -> element space. Exact, and the reason no
    /// autodiff framework appears anywhere in this program (§14).
    public func adjoint(_ field: [Complex]) -> [Complex] {
        precondition(field.count == lattice.count)
        let nE = gateCount, nP = lattice.count
        var out = [Complex](repeating: .zero, count: nE)
        for n in 0..<nP {
            let base = n * nE
            let f = field[n]
            for e in 0..<nE { out[e] += H[base + e].conjugate * f }
        }
        return out
    }

    /// The gate-granular row at one point: p(x) = Σ_g row[g]·u_g, with the
    /// same weights, couplings and wall images as the cached operator. The
    /// inverse solver's control matrix is built from this, so the solver
    /// optimizes the machine the field is then evaluated on.
    public func gateRow(at x: Vec3) -> [Complex] {
        let k = medium.wavenumber(at: frequency)
        let alpha = medium.absorption(at: frequency)
        let prefactorMag = medium.density * medium.soundSpeed * k / (2 * .pi)
        var row = [Complex](repeating: .zero, count: gateCount)
        for (ei, el) in elements.enumerated() {
            guard el.gateIndex >= 0 && el.gateIndex < gateCount else { continue }
            let w = elementWeights?[ei] ?? 1.0
            if w == 0 { continue }
            let c = elementCoupling?[ei] ?? Complex.one
            var acc = Complex.zero
            for (zi, refl) in imageTable[ei] {
                let d = x - Vec3(el.position.x, el.position.y, zi)
                let r = max(d.length, 1e-9)
                let cosTheta = abs(d.dot(el.normal)) / r
                let dir = el.directivity == .monopole ? 1.0
                    : Propagator.pistonDirectivity(k: k, a: el.equivalentRadius,
                                                   cosTheta: cosTheta)
                let ph = Complex.expi(k * r)
                acc += Complex(-ph.im, ph.re)
                    * (prefactorMag * el.area * dir * w * refl * exp(-alpha * r) / r)
            }
            row[el.gateIndex] += acc * c
        }
        return row
    }

    /// Gate rows of the pressure AND its analytic gradient at one point:
    /// p = Σ_g p[g]·u_g, ∂p/∂x_k = Σ_g grad[k][g]·u_g. What the force compiler
    /// needs: the Gor'kov potential is a quadratic form in u built from exactly
    /// these rows (directivity held locally constant, as in `velocity`).
    public func gateGradientRows(at x: Vec3) -> (p: [Complex], grad: [[Complex]]) {
        let k = medium.wavenumber(at: frequency)
        let alpha = medium.absorption(at: frequency)
        let prefactorMag = medium.density * medium.soundSpeed * k / (2 * .pi)
        var p = [Complex](repeating: .zero, count: gateCount)
        var g = [[Complex]](repeating: [Complex](repeating: .zero, count: gateCount), count: 3)
        for (ei, el) in elements.enumerated() {
            guard el.gateIndex >= 0 && el.gateIndex < gateCount else { continue }
            let w = elementWeights?[ei] ?? 1.0
            if w == 0 { continue }
            let c = elementCoupling?[ei] ?? Complex.one
            var acc = Complex.zero, ax = Complex.zero, ay = Complex.zero, az = Complex.zero
            for (zi, refl) in imageTable[ei] {
                let d = x - Vec3(el.position.x, el.position.y, zi)
                let r = max(d.length, 1e-9)
                let dn = d.dot(el.normal)
                let cosTheta = abs(dn) / r
                let (dir, slope) = el.directivity == .monopole ? (1.0, 0.0)
                    : Propagator.pistonDirectivityAndSlope(k: k, a: el.equivalentRadius, cosTheta: cosTheta)
                let ph = Complex.expi(k * r)
                let base = Complex(-ph.im, ph.re)
                    * (prefactorMag * el.area * w * refl * exp(-alpha * r) / r)
                let term = base * dir
                // radial part: d/dr [e^{(ik-α)r}/r] / [e^{(ik-α)r}/r] = (ik - α) - 1/r
                let radial = term * Complex(-alpha - 1 / r, k)
                // angular part: D'(cosθ) ∇cosθ, ∇cosθ = (sign(d·n) n − cosθ d̂)/r
                let sgn = dn >= 0 ? 1.0 : -1.0
                let gc = (el.normal * sgn - d * (cosTheta / r)) * (1 / r)
                let ang = base * slope
                acc += term
                ax += radial * (d.x / r) + ang * gc.x
                ay += radial * (d.y / r) + ang * gc.y
                az += radial * (d.z / r) + ang * gc.z
            }
            p[el.gateIndex] += acc * c
            g[0][el.gateIndex] += ax * c
            g[1][el.gateIndex] += ay * c
            g[2][el.gateIndex] += az * c
        }
        return (p, g)
    }

    /// Pressure at one arbitrary point, without touching the cached lattice.
    public func pressure(at x: Vec3, drive: [Complex]) -> Complex {
        let k = medium.wavenumber(at: frequency)
        let alpha = medium.absorption(at: frequency)
        let prefactorMag = medium.density * medium.soundSpeed * k / (2 * .pi)
        var acc = Complex.zero
        for (ei, el) in elements.enumerated() {
            guard el.gateIndex >= 0 && el.gateIndex < drive.count else { continue }
            let w = elementWeights?[ei] ?? 1.0
            if w == 0 { continue }
            let c = elementCoupling?[ei] ?? Complex.one
            for (zi, refl) in imageTable[ei] {
                let d = x - Vec3(el.position.x, el.position.y, zi)
                let r = max(d.length, 1e-9)
                let cosTheta = abs(d.dot(el.normal)) / r
                let dir = el.directivity == .monopole ? 1.0
                    : Propagator.pistonDirectivity(k: k, a: el.equivalentRadius,
                                                   cosTheta: cosTheta)
                let amp = prefactorMag * el.area * dir * w * refl * exp(-alpha * r) / r
                let ph = Complex.expi(k * r)
                acc += Complex(-ph.im, ph.re) * c * amp * drive[el.gateIndex]
            }
        }
        return acc
    }

    /// Particle velocity by the analytic gradient of the same sum.
    /// §11: do NOT finite-difference the pressure for this — the force is a
    /// gradient of a quantity that is already a gradient and the error shows up
    /// as visible trap jitter.
    public func velocity(at x: Vec3, drive: [Complex]) -> (Complex, Complex, Complex) {
        let k = medium.wavenumber(at: frequency)
        let alpha = medium.absorption(at: frequency)
        let omega = 2 * .pi * frequency
        let prefactorMag = medium.density * medium.soundSpeed * k / (2 * .pi)
        var gx = Complex.zero, gy = Complex.zero, gz = Complex.zero
        for (ei, el) in elements.enumerated() {
            guard el.gateIndex >= 0 && el.gateIndex < drive.count else { continue }
            let w = elementWeights?[ei] ?? 1.0
            if w == 0 { continue }
            let c = elementCoupling?[ei] ?? Complex.one
            for (zi, refl) in imageTable[ei] {
                let d = x - Vec3(el.position.x, el.position.y, zi)
                let r = max(d.length, 1e-9)
                let dn = d.dot(el.normal)
                let cosTheta = abs(dn) / r
                // Directivity AND its angular slope (see pistonDirectivityAndSlope).
                let (dir, slope) = el.directivity == .monopole ? (1.0, 0.0)
                    : Propagator.pistonDirectivityAndSlope(k: k, a: el.equivalentRadius,
                                                           cosTheta: cosTheta)
                let amp = prefactorMag * el.area * w * refl * exp(-alpha * r)
                let ph = Complex.expi(k * r)
                let iph = Complex(-ph.im, ph.re)
                // d/dr [ e^{(ik-α)r}/r ] = e^{(ik-α)r} ((ik - α) r - 1)/r^2
                let dfdr = iph * ((Complex(-alpha * r, k * r) - Complex.one) / (r * r))
                let g = dfdr * c * (amp * dir) * drive[el.gateIndex]
                let sgn = dn >= 0 ? 1.0 : -1.0
                let gc = (el.normal * sgn - d * (cosTheta / r)) * (1 / r)
                let ga = iph * c * (amp * slope / r) * drive[el.gateIndex]
                gx += g * (d.x / r) + ga * gc.x
                gy += g * (d.y / r) + ga * gc.y
                gz += g * (d.z / r) + ga * gc.z
            }
        }
        // v = -(1/(i*omega*rho0)) grad p  ==  (i/(omega*rho0)) grad p
        let s = 1.0 / (omega * medium.density)
        return (Complex(-gx.im, gx.re) * s,
                Complex(-gy.im, gy.re) * s,
                Complex(-gz.im, gz.re) * s)
    }
}

/// Bessel J0 — the same rational-approximation family as `besselJ1`
/// (Numerical Recipes bessj0; A&S 9.4.1/9.4.3), ~1e-8.
public func besselJ0(_ x: Double) -> Double {
    let ax = abs(x)
    if ax < 8.0 {
        let y = x * x
        let a1 = 57568490574.0 + y * (-13362590354.0 + y * (651619640.7
               + y * (-11214424.18 + y * (77392.33017 + y * (-184.9052456)))))
        let a2 = 57568490411.0 + y * (1029532985.0 + y * (9494680.718
               + y * (59272.64853 + y * (267.8532712 + y))))
        return a1 / a2
    }
    let z = 8.0 / ax, y = z * z, xx = ax - 0.785398164
    let a1 = 1.0 + y * (-0.1098628627e-2 + y * (0.2734510407e-4
           + y * (-0.2073370639e-5 + y * 0.2093887211e-6)))
    let a2 = -0.1562499995e-1 + y * (0.1430488765e-3
           + y * (-0.6911147651e-5 + y * (0.7621095161e-6 - y * 0.934935152e-7)))
    return (0.636619772 / ax).squareRoot() * (cos(xx) * a1 - z * sin(xx) * a2)
}

/// Bessel J1 — Abramowitz & Stegun 9.4.4/9.4.6 rational approximations.
/// Accurate to ~1e-7, which is well inside every gate tolerance in §22.
public func besselJ1(_ x: Double) -> Double {
    let ax = abs(x)
    if ax < 8.0 {
        let y = x * x
        let p1 = x * (72362614232.0 + y * (-7895059235.0 + y * (242396853.1
               + y * (-2972611.439 + y * (15704.48260 + y * (-30.16036606))))))
        let p2 = 144725228442.0 + y * (2300535178.0 + y * (18583304.74
               + y * (99447.43394 + y * (376.9991397 + y))))
        return p1 / p2
    } else {
        let z = 8.0 / ax
        let y = z * z
        let xx = ax - 2.356194491
        let p1 = 1.0 + y * (0.183105e-2 + y * (-0.3516396496e-4
               + y * (0.2457520174e-5 + y * (-0.240337019e-6))))
        let p2 = 0.04687499995 + y * (-0.2002690873e-3
               + y * (0.8449199096e-5 + y * (-0.88228987e-6 + y * 0.105787412e-6)))
        let ans = (0.636619772 / ax).squareRoot()
                * (cos(xx) * p1 - z * sin(xx) * p2)
        return x < 0 ? -ans : ans
    }
}
