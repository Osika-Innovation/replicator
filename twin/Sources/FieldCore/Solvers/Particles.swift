import Foundation

/// T2 dynamics — particle transport under the radiation force (§13.1).
///
/// Force comes from a PRECOMPUTED gradient of the Gor'kov potential on the
/// lattice, trilinearly interpolated per particle. Evaluating the analytic
/// force per particle per step re-walks every element and is ~10^4x slower for
/// no gain at these scales; the potential is smooth, so its lattice gradient is
/// accurate well below the trap spacing.
public struct ParticleSim: Sendable {

    public enum State: UInt8, Sendable {
        case feedstock      // still in the cartridge / rising through the bore
        case inTransit      // caught by the field, migrating
        case trapped        // resident in a trap, velocity below threshold
    }

    public struct Particle: Sendable {
        public var position: Vec3
        public var velocity: Vec3
        public var state: State
        public var temperature: Double   // K, for the thermal/consolidation layer
    }

    public var particles: [Particle] = []
    public let lattice: FieldLattice
    public let material: ParticleMaterial
    public let medium: Medium

    /// -grad U on the lattice, precomputed once.
    private let fx: [Double], fy: [Double], fz: [Double]
    private let mass: Double
    private let dragCoefficient: Double

    public init(potential U: [Double], lattice: FieldLattice,
                material: ParticleMaterial = .pla(), medium: Medium = .air) {
        self.lattice = lattice
        self.material = material
        self.medium = medium
        self.mass = material.mass()
        // Stokes drag: F = -6 pi mu a v
        self.dragCoefficient = 6 * .pi * 1.81e-5 * material.radius

        var gx = [Double](repeating: 0, count: U.count)
        var gy = gx, gz = gx
        let h = lattice.spacing
        for k in 0..<lattice.nz {
            for j in 0..<lattice.ny {
                for i in 0..<lattice.nx {
                    let n = lattice.index(i, j, k)
                    func d(_ a: Int, _ b: Int, _ c: Int,
                           _ a2: Int, _ b2: Int, _ c2: Int) -> Double {
                        let lo = U[lattice.index(max(0, a), max(0, b), max(0, c))]
                        let hi = U[lattice.index(min(lattice.nx - 1, a2),
                                                 min(lattice.ny - 1, b2),
                                                 min(lattice.nz - 1, c2))]
                        return (hi - lo) / (2 * h)
                    }
                    gx[n] = -d(i-1, j, k, i+1, j, k)
                    gy[n] = -d(i, j-1, k, i, j+1, k)
                    gz[n] = -d(i, j, k-1, i, j, k+1)
                }
            }
        }
        self.fx = gx; self.fy = gy; self.fz = gz
    }

    /// Seed a delivered cloud: particles already inside the field region, as
    /// though the feed stage has just placed them and the trap now takes over.
    ///
    /// An earlier version launched them ballistically from the bore at
    /// 0.05 m/s. That cannot work and the sim showed it: v0^2/2g = 0.13 mm of
    /// rise, so nothing ever reached the field and every particle recycled as
    /// feedstock forever. Delivery is the feed stage's job (acoustic tractor or
    /// the keV-class ionized stream, §13.2); the trap's job starts once the
    /// matter is in the volume, which is what this models.
    public mutating func seedDelivered(count: Int, seed: UInt64 = 0xB07E) {
        var s = seed
        func rnd() -> Double {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return Double((s >> 11) & 0xFFFFFFF) / Double(0xFFFFFFF)
        }
        particles.removeAll(keepingCapacity: true)
        let w = Double(lattice.nx - 1) * lattice.spacing
        let d = Double(lattice.ny - 1) * lattice.spacing
        let h = Double(lattice.nz - 1) * lattice.spacing
        for _ in 0..<count {
            particles.append(Particle(
                position: Vec3(lattice.origin.x + w * rnd(),
                               lattice.origin.y + d * rnd(),
                               lattice.origin.z + h * rnd()),
                velocity: .zero,
                state: .inTransit,
                temperature: 480))
        }
    }

    /// Ballistic feed from the bore. Kept for the feed-stage lane; not used by
    /// the viewport, for the reason documented above.
    public mutating func seedFromBore(count: Int, boreRadius: Double = 0.040,
                                      seed: UInt64 = 0xB07E) {
        var s = seed
        func rnd() -> Double {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return Double((s >> 11) & 0xFFFFFFF) / Double(0xFFFFFFF)
        }
        particles.removeAll(keepingCapacity: true)
        for _ in 0..<count {
            let r = boreRadius * rnd().squareRoot()
            let a = 2 * Double.pi * rnd()
            particles.append(Particle(
                position: Vec3(r * cos(a), r * sin(a),
                               lattice.origin.z + 0.005 * rnd()),
                velocity: Vec3(0, 0, 0.05 + 0.05 * rnd()),
                state: .feedstock,
                temperature: 480))          // leaves the heat stage molten
        }
    }

    @inline(__always)
    func sample(_ f: [Double], _ p: Vec3) -> Double {
        let gx = (p.x - lattice.origin.x) / lattice.spacing
        let gy = (p.y - lattice.origin.y) / lattice.spacing
        let gz = (p.z - lattice.origin.z) / lattice.spacing
        let i = Int(gx.rounded(.down)), j = Int(gy.rounded(.down)), k = Int(gz.rounded(.down))
        guard i >= 0, j >= 0, k >= 0,
              i + 1 < lattice.nx, j + 1 < lattice.ny, k + 1 < lattice.nz else { return 0 }
        let tx = gx - Double(i), ty = gy - Double(j), tz = gz - Double(k)
        func at(_ a: Int, _ b: Int, _ c: Int) -> Double { f[lattice.index(a, b, c)] }
        let c00 = at(i, j, k) * (1 - tx) + at(i+1, j, k) * tx
        let c10 = at(i, j+1, k) * (1 - tx) + at(i+1, j+1, k) * tx
        let c01 = at(i, j, k+1) * (1 - tx) + at(i+1, j, k+1) * tx
        let c11 = at(i, j+1, k+1) * (1 - tx) + at(i+1, j+1, k+1) * tx
        let c0 = c00 * (1 - ty) + c10 * ty
        let c1 = c01 * (1 - ty) + c11 * ty
        return c0 * (1 - tz) + c1 * tz
    }

    /// One step. Velocity Verlet with radiation force, gravity and Stokes drag.
    ///
    /// `forceGain` exists because drive amplitudes are not yet in SI (a known
    /// defect): it scales the normalized field to a level where transport is
    /// visible. It is a DISPLAY scaling, not a physical result, and no force or
    /// stiffness number may be quoted from a run that uses it.
    public mutating func step(dt: Double, forceGain: Double = 1.0,
                              coolingPerStep: Double = 4.0) {
        let g = Vec3(0, 0, -9.80665)
        for idx in particles.indices {
            var p = particles[idx]
            guard p.state != .trapped else {
                p.temperature = max(295, p.temperature - coolingPerStep)
                particles[idx] = p
                continue
            }
            let f = Vec3(sample(fx, p.position), sample(fy, p.position),
                         sample(fz, p.position)) * forceGain
            let drag = p.velocity * (-dragCoefficient)
            let a = (f + drag) / mass + g
            p.velocity += a * dt
            p.position += p.velocity * dt
            p.temperature = max(295, p.temperature - coolingPerStep)

            // The field has taken hold when it can lift the particle — a
            // physical criterion, not an arbitrary height.
            if p.state == .feedstock && f.length > mass * 9.80665 {
                p.state = .inTransit
            }
            // Latch at a STATIONARY POINT of the potential: slow AND in a place
            // where the field is no longer pushing. The first version required
            // |F| > 0, which is backwards — at the bottom of a trap the force is
            // zero by definition, so that test latched particles anywhere drag
            // had slowed them and reported 900/900 "trapped" regardless of where
            // they actually were.
            let weight = mass * 9.80665
            if p.state == .inTransit && p.velocity.length < 0.004
                && f.length < 0.15 * weight {
                p.state = .trapped
                p.velocity = .zero
            }
            // Floor: anything that falls out of the volume returns to feedstock.
            if p.position.z < lattice.origin.z - 0.02 {
                p.state = .feedstock
                p.position.z = lattice.origin.z
                p.velocity = Vec3(0, 0, 0.05)
            }
            particles[idx] = p
        }
    }

    /// Gain that scales the (dimensionless) field so the strongest radiation
    /// force equals `ratio` times the particle's weight.
    ///
    /// This exists because drive amplitudes are NOT YET IN SI — a known defect.
    /// Rather than pick an arbitrary constant, normalize to the one physically
    /// meaningful reference the problem has: the weight the field must beat to
    /// levitate at all. `ratio = 3` means "a field three times strong enough to
    /// hold this particle", which is the regime a real trap operates in.
    ///
    /// Still a DISPLAY scaling: no force or stiffness number may be quoted from
    /// a run that uses it. It makes transport visible; it does not make it
    /// measured.
    public func levitationGain(ratio: Double = 3.0) -> Double {
        var maxF = 0.0
        for i in fx.indices {
            let f = (fx[i] * fx[i] + fy[i] * fy[i] + fz[i] * fz[i]).squareRoot()
            if f > maxF { maxF = f }
        }
        guard maxF > 0 else { return 1 }
        return ratio * mass * 9.80665 / maxF
    }

    public var counts: (feedstock: Int, inTransit: Int, trapped: Int) {
        var f = 0, t = 0, r = 0
        for p in particles {
            switch p.state {
            case .feedstock: f += 1
            case .inTransit: t += 1
            case .trapped: r += 1
            }
        }
        return (f, t, r)
    }
}
