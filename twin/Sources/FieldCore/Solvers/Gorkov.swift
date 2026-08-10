import Foundation

public struct ParticleMaterial: Sendable, Codable {
    public var density: Double        // rho_p
    public var soundSpeed: Double     // c_p
    public var radius: Double         // a, metres
    public init(density: Double, soundSpeed: Double, radius: Double) {
        self.density = density; self.soundSpeed = soundSpeed; self.radius = radius
    }
    /// The spec's canonical test particle: a 200 um PLA bead (§13.2).
    public static func pla(radius: Double = 100e-6) -> ParticleMaterial {
        ParticleMaterial(density: 1240, soundSpeed: 2220, radius: radius)
    }
    public static func eps(radius: Double = 1e-3) -> ParticleMaterial {
        ParticleMaterial(density: 25, soundSpeed: 900, radius: radius)
    }
    public var volume: Double { 4.0 / 3.0 * .pi * radius * radius * radius }
    public func mass() -> Double { density * volume }
}

/// T2 — the Gor'kov acoustic radiation potential (§13.1), in the Bruus 2012 form:
///
///   U = (4/3) pi a^3 [ f1 * (1/2) kappa0 <p^2>  -  f2 * (3/4) rho0 <v^2> ]
///   f1 = 1 - kappa_p/kappa0 ,  f2 = 2(rho_p - rho0)/(2 rho_p + rho0)
///   F  = -grad U
///
/// with <p^2> = |p|^2/2 and <v^2> = |v|^2/2 for complex amplitudes.
public struct Gorkov: Sendable {
    public let medium: Medium
    public let particle: ParticleMaterial

    public init(medium: Medium, particle: ParticleMaterial) {
        self.medium = medium; self.particle = particle
    }

    public var kappa0: Double { 1.0 / (medium.density * medium.soundSpeed * medium.soundSpeed) }
    public var kappaP: Double { 1.0 / (particle.density * particle.soundSpeed * particle.soundSpeed) }
    public var f1: Double { 1.0 - kappaP / kappa0 }
    public var f2: Double {
        2.0 * (particle.density - medium.density) / (2.0 * particle.density + medium.density)
    }
    /// Acoustic contrast factor. > 0 traps at pressure NODES (every solid-in-air
    /// case we care about); < 0 traps at antinodes.
    public var contrast: Double { f1 + 1.5 * f2 }

    /// Potential from complex pressure and velocity amplitudes at a point.
    public func potential(p: Complex, v: (Complex, Complex, Complex)) -> Double {
        let p2 = 0.5 * p.magnitudeSquared
        let v2 = 0.5 * (v.0.magnitudeSquared + v.1.magnitudeSquared + v.2.magnitudeSquared)
        let a3 = particle.radius * particle.radius * particle.radius
        return (4.0 / 3.0) * .pi * a3 * (f1 * 0.5 * kappa0 * p2 - f2 * 0.75 * medium.density * v2)
    }

    /// Force by central difference OF THE POTENTIAL (which is smooth), per §13.1.
    public func force(at x: Vec3, propagator: Propagator, drive: [Complex],
                      h: Double = 1e-5) -> Vec3 {
        func U(_ q: Vec3) -> Double {
            potential(p: propagator.pressure(at: q, drive: drive),
                      v: propagator.velocity(at: q, drive: drive))
        }
        let dx = (U(x + Vec3(h, 0, 0)) - U(x - Vec3(h, 0, 0))) / (2 * h)
        let dy = (U(x + Vec3(0, h, 0)) - U(x - Vec3(0, h, 0))) / (2 * h)
        let dz = (U(x + Vec3(0, 0, h)) - U(x - Vec3(0, 0, h))) / (2 * h)
        return Vec3(-dx, -dy, -dz)
    }

    /// Closed form for a 1-D standing wave, p = P0 sin(kz):
    ///
    ///     F_z = -(4/3) pi a^3 k E_ac Phi sin(2kz),   E_ac = P0^2 / (4 rho0 c0^2)
    ///     Phi = f1 + (3/2) f2
    ///
    /// This IS gate G7 — the analytic truth the numerical path must match.
    ///
    /// CONVENTION TRAP, and it cost a debugging cycle to find, so it is written
    /// down. The form usually quoted in the literature is
    ///
    ///     F_z = 4 pi a^3 k E_ac Phi_B sin(2kz)
    ///
    /// and it differs from the above in BOTH factors, for two separate reasons:
    ///  1. Phi_B is the Settnes-Bruus *acoustophoretic* contrast factor, which
    ///     carries a 1/3:  Phi_B = Phi/3.  Same physics, different normalization.
    ///  2. The sign follows the pressure convention. With p = P0 sin(kz) the
    ///     pressure node sits at z = 0, and a positive-contrast particle must be
    ///     pushed TOWARD it — so F_z < 0 for small z > 0, which requires the
    ///     leading minus. Quoting the literature form against a sin() field
    ///     silently inverts the trap, turning nodes into antinodes.
    ///
    /// Verified by symbolic differentiation of the potential; the two forms
    /// agree exactly once both conventions are matched (see `analyticSettnesBruus`).
    public func analyticStandingWaveForce(P0: Double, z: Double, frequency: Double) -> Double {
        let k = medium.wavenumber(at: frequency)
        let eAc = P0 * P0 / (4 * medium.density * medium.soundSpeed * medium.soundSpeed)
        let a3 = particle.radius * particle.radius * particle.radius
        return -(4.0 / 3.0) * .pi * a3 * k * eAc * contrast * sin(2 * k * z)
    }

    /// The same force in the Settnes-Bruus normalization, as a cross-check that
    /// the two conventions really do agree.
    public func analyticSettnesBruus(P0: Double, z: Double, frequency: Double) -> Double {
        let k = medium.wavenumber(at: frequency)
        let eAc = P0 * P0 / (4 * medium.density * medium.soundSpeed * medium.soundSpeed)
        let a3 = particle.radius * particle.radius * particle.radius
        let phiB = contrast / 3.0
        return -4 * .pi * a3 * k * eAc * phiB * sin(2 * k * z)
    }

    /// Numerical force in the same 1-D standing wave, via the general potential
    /// path — the thing G7 compares against the closed form above.
    public func numericStandingWaveForce(P0: Double, z: Double, frequency: Double,
                                         h: Double = 1e-6) -> Double {
        let k = medium.wavenumber(at: frequency)
        let omega = 2 * .pi * frequency
        func U(_ zz: Double) -> Double {
            // p = P0 sin(kz);  v_z = (i/(omega rho0)) dp/dz = (i/(omega rho0)) P0 k cos(kz)
            let p = Complex(P0 * sin(k * zz), 0)
            let vz = Complex(0, P0 * k * cos(k * zz) / (omega * medium.density))
            return potential(p: p, v: (.zero, .zero, vz))
        }
        return -(U(z + h) - U(z - h)) / (2 * h)
    }

    /// Trap stiffness (N/m) about a point, along z.
    public func axialStiffness(at x: Vec3, propagator: Propagator, drive: [Complex],
                               h: Double = 1e-5) -> Double {
        let fUp = force(at: x + Vec3(0, 0, h), propagator: propagator, drive: drive)
        let fDn = force(at: x - Vec3(0, 0, h), propagator: propagator, drive: drive)
        return -(fUp.z - fDn.z) / (2 * h)
    }

    /// Gor'kov potential over a whole lattice, from a cached propagator.
    /// Velocity comes from differencing p ON THE LATTICE — cheap, and adequate
    /// for locating minima (the force path uses the analytic gradient instead).
    public func potentialField(propagator: Propagator, drive: [Complex]) -> [Double] {
        let lat = propagator.lattice
        let field = propagator.forward(drive)
        let omega = 2 * .pi * propagator.frequency
        let coef = 1.0 / (omega * medium.density * lat.spacing * 2)
        var U = [Double](repeating: 0, count: lat.count)
        for k in 0..<lat.nz {
            for j in 0..<lat.ny {
                for i in 0..<lat.nx {
                    let n = lat.index(i, j, k)
                    func grad(_ a: Int, _ b: Int, _ c: Int,
                              _ a2: Int, _ b2: Int, _ c2: Int) -> Complex {
                        let lo = lat.index(max(0, a), max(0, b), max(0, c))
                        let hi = lat.index(min(lat.nx - 1, a2), min(lat.ny - 1, b2),
                                           min(lat.nz - 1, c2))
                        return field[hi] - field[lo]
                    }
                    let gx = grad(i-1, j, k, i+1, j, k)
                    let gy = grad(i, j-1, k, i, j+1, k)
                    let gz = grad(i, j, k-1, i, j, k+1)
                    U[n] = potential(p: field[n],
                                     v: (Complex(-gx.im, gx.re) * coef,
                                         Complex(-gy.im, gy.re) * coef,
                                         Complex(-gz.im, gz.re) * coef))
                }
            }
        }
        return U
    }

    /// Local minima of U — where a positive-contrast particle is actually held.
    /// Depth is measured from the global barrier, so a shallow parasitic trap
    /// reports as visibly weaker than the intended one.
    public static func findTraps(U: [Double], lattice: FieldLattice,
                                 limit: Int = 400)
        -> [(position: Vec3, depth: Double)] {
        guard let uMax = U.max(), lattice.nx > 2, lattice.ny > 2, lattice.nz > 2
        else { return [] }
        var out: [(Vec3, Double)] = []
        for k in 1..<(lattice.nz - 1) {
            for j in 1..<(lattice.ny - 1) {
                for i in 1..<(lattice.nx - 1) {
                    let n = lattice.index(i, j, k)
                    let u = U[n]
                    var isMin = true
                    for (a, b, c) in [(i-1,j,k),(i+1,j,k),(i,j-1,k),
                                      (i,j+1,k),(i,j,k-1),(i,j,k+1)] {
                        if U[lattice.index(a, b, c)] <= u { isMin = false; break }
                    }
                    if isMin { out.append((lattice.position(i, j, k), uMax - u)) }
                }
            }
        }
        out.sort { $0.1 > $1.1 }
        return Array(out.prefix(limit)).map { (position: $0.0, depth: $0.1) }
    }

    /// Can this trap hold the particle against gravity? |F| > mg.
    public func canLevitate(force f: Vec3) -> Bool {
        f.length > particle.mass() * 9.80665
    }
}
