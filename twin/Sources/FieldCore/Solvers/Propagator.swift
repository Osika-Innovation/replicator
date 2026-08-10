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
    }

    public init(elements: [Element], lattice: FieldLattice,
                frequency: Double, medium: Medium, gateCount: Int? = nil,
                elementWeights: [Double]? = nil,
                walls: Walls = .none) {
        self.elements = elements
        self.lattice = lattice
        self.frequency = frequency
        self.medium = medium
        let nG = gateCount ?? ((elements.map(\.gateIndex).max() ?? -1) + 1)
        self.gateCount = nG

        let k = medium.wavenumber(at: frequency)
        let nP = lattice.count
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
                    // Direct path plus axial image sources from the two caps.
                    var images: [(Double, Double)] = [(el.position.z, 1.0)]
                    if walls.capSeparation > 0 && walls.order > 0 {
                        let L = walls.capSeparation
                        for m in 1...walls.order {
                            let refl = pow(walls.reflectionCoefficient, Double(m))
                            let zm = Double(m)
                            // mirror about z=0 and about z=L, alternating
                            images.append((-el.position.z + 2 * (zm - 1) * L * 0, refl))
                            images.append((2 * L - el.position.z, refl))
                            if m > 1 {
                                images.append((el.position.z + 2 * (zm - 1) * L, refl))
                                images.append((el.position.z - 2 * (zm - 1) * L, refl))
                            }
                        }
                    }
                    for (zi, refl) in images {
                        let src = Vec3(el.position.x, el.position.y, zi)
                        let d = x - src
                        let r = max(d.length, 1e-9)
                        let cosTheta = abs(d.dot(el.normal)) / r
                        let dir = el.directivity == .monopole ? 1.0
                            : Propagator.pistonDirectivity(
                                k: k, a: el.equivalentRadius, cosTheta: cosTheta)
                        let amp = prefactorMag * el.area * dir * w * refl / r
                        let phase = Complex.expi(k * r)
                        buf[base + g] += Complex(-phase.im, phase.re) * amp
                    }
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

    /// Pressure at one arbitrary point, without touching the cached lattice.
    public func pressure(at x: Vec3, drive: [Complex]) -> Complex {
        let k = medium.wavenumber(at: frequency)
        let prefactorMag = medium.density * medium.soundSpeed * k / (2 * .pi)
        var acc = Complex.zero
        for el in elements {
            guard el.gateIndex >= 0 && el.gateIndex < drive.count else { continue }
            let d = x - el.position
            let r = max(d.length, 1e-9)
            let cosTheta = abs(d.dot(el.normal)) / r
            let dir = el.directivity == .monopole ? 1.0
                : Propagator.pistonDirectivity(k: k, a: el.equivalentRadius,
                                               cosTheta: cosTheta)
            let amp = prefactorMag * el.area * dir / r
            let ph = Complex.expi(k * r)
            acc += Complex(-ph.im, ph.re) * amp * drive[el.gateIndex]
        }
        return acc
    }

    /// Particle velocity by the analytic gradient of the same sum.
    /// §11: do NOT finite-difference the pressure for this — the force is a
    /// gradient of a quantity that is already a gradient and the error shows up
    /// as visible trap jitter.
    public func velocity(at x: Vec3, drive: [Complex]) -> (Complex, Complex, Complex) {
        let k = medium.wavenumber(at: frequency)
        let omega = 2 * .pi * frequency
        let prefactorMag = medium.density * medium.soundSpeed * k / (2 * .pi)
        var gx = Complex.zero, gy = Complex.zero, gz = Complex.zero
        for el in elements {
            guard el.gateIndex >= 0 && el.gateIndex < drive.count else { continue }
            let d = x - el.position
            let r = max(d.length, 1e-9)
            let cosTheta = abs(d.dot(el.normal)) / r
            let dir = Propagator.pistonDirectivity(k: k, a: el.equivalentRadius,
                                                   cosTheta: cosTheta)
            let amp = prefactorMag * el.area * dir
            let ph = Complex.expi(k * r)
            let iph = Complex(-ph.im, ph.re)
            // d/dr [ e^{ikr}/r ] = e^{ikr} (ik r - 1)/r^2
            let dfdr = iph * ((Complex(0, k * r) - Complex.one) / (r * r))
            let g = dfdr * amp * drive[el.gateIndex]
            gx += g * (d.x / r); gy += g * (d.y / r); gz += g * (d.z / r)
        }
        // v = -(1/(i*omega*rho0)) grad p  ==  (i/(omega*rho0)) grad p
        let s = 1.0 / (omega * medium.density)
        return (Complex(-gx.im, gx.re) * s,
                Complex(-gy.im, gy.re) * s,
                Complex(-gz.im, gz.re) * s)
    }
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
