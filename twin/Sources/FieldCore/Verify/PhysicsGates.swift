import Foundation

/// The §22 acceptance gates, implemented. Each is external to the emulator —
/// an analytic formula, a conservation law, or a closed form. Agreement with
/// itself proves nothing (§25).
public enum PhysicsGates {

    // ---------------------------------------------------------------- G7 ----
    /// G7 — Gor'kov analytic: the numerical potential path must reproduce the
    /// closed-form 1-D standing-wave force to within 2%.
    public static func g7GorkovAnalytic(frequency: Double = 40_000,
                                        medium: Medium = .air,
                                        particle: ParticleMaterial = .pla(),
                                        P0: Double = 1000) -> GateResult {
        let g = Gorkov(medium: medium, particle: particle)
        let lambda = medium.wavelength(at: frequency)
        var worst = 0.0
        var worstAt = 0.0
        // Sample across a full wavelength, skipping the exact zeros where a
        // relative error is meaningless.
        for i in 0...200 {
            let z = lambda * Double(i) / 200.0
            let a = g.analyticStandingWaveForce(P0: P0, z: z, frequency: frequency)
            let n = g.numericStandingWaveForce(P0: P0, z: z, frequency: frequency)
            let scale = 4 * .pi * pow(particle.radius, 3)
                      * medium.wavenumber(at: frequency)
                      * (P0 * P0 / (4 * medium.density * medium.soundSpeed * medium.soundSpeed))
                      * abs(g.contrast)
            guard scale > 0, abs(a) > 0.05 * scale else { continue }
            let e = abs(a - n) / abs(a)
            if e > worst { worst = e; worstAt = z }
        }
        return GateResult(
            id: "G7", name: "Gor'kov vs closed form",
            measured: worst, threshold: 0.02,
            detail: "worst rel. err at z = \(String(format: "%.3f", worstAt * 1000)) mm; "
                  + "contrast Phi = \(String(format: "%.4f", g.contrast))")
    }

    // ---------------------------------------------------------------- G1 ----
    /// G1 — voxelizer: a sphere STL voxelizes to within 2% of 4/3 pi r^3.
    public static func g1Voxelizer(radius: Double = 0.030,
                                   spacing: Double = 0.0008) -> GateResult {
        let mesh = Mesh.sphere(radius: radius, subdivisions: 4)
        let bounds = mesh.bounds
        let pad = spacing * 2
        let lat = FieldLattice(origin: bounds.min - Vec3(pad, pad, pad),
                               spacing: spacing,
                               nx: Int(((bounds.max.x - bounds.min.x + 2 * pad) / spacing).rounded(.up)),
                               ny: Int(((bounds.max.y - bounds.min.y + 2 * pad) / spacing).rounded(.up)),
                               nz: Int(((bounds.max.z - bounds.min.z + 2 * pad) / spacing).rounded(.up)))
        let occ = Voxelizer.voxelize(mesh: mesh, lattice: lat)
        let filled = occ.reduce(0) { $0 + ($1 ? 1 : 0) }
        let measuredVol = Double(filled) * spacing * spacing * spacing
        let trueVol = 4.0 / 3.0 * .pi * radius * radius * radius
        let relErr = abs(measuredVol - trueVol) / trueVol
        return GateResult(
            id: "G1", name: "voxelizer volume",
            measured: relErr, threshold: 0.02,
            detail: "\(filled) voxels = \(String(format: "%.4g", measuredVol * 1e6)) cm^3 "
                  + "vs \(String(format: "%.4g", trueVol * 1e6)) cm^3")
    }


    // ---------------------------------------------------------------- G2 ----
    /// G2 — energy conservation: empty chamber, sponge OFF, rigid walls,
    /// total energy drift < 1% over 10k steps.
    public static func g2EnergyConservation(n: Int = 40, steps: Int = 10_000,
                                            dx: Double = 0.005) -> GateResult {
        let sim = FDTD(nx: n, ny: n, nz: n, dx: dx, spongeCells: 0)
        sim.disableSponge()
        // A smooth Gaussian blob: broadband enough to be a real test, smooth
        // enough not to be dominated by grid-scale dispersion.
        let c = Double(n) / 2
        let w = Double(n) / 10
        for k in 0..<n { for j in 0..<n { for i in 0..<n {
            let r2 = pow(Double(i) - c, 2) + pow(Double(j) - c, 2) + pow(Double(k) - c, 2)
            sim.addPressure(exp(-r2 / (2 * w * w)), at: i, j, k)
        }}}
        let e0 = sim.totalEnergy()
        for _ in 0..<steps { sim.advance() }
        let e1 = sim.totalEnergy()
        let drift = abs(e1 - e0) / e0
        return GateResult(id: "G2", name: "energy drift (lossless, \(steps) steps)",
                          measured: drift, threshold: 0.01,
                          detail: "E0 = \(String(format: "%.6g", e0)), E1 = \(String(format: "%.6g", e1))")
    }

    // ---------------------------------------------------------------- G3 ----
    /// G3 — time of flight: an axial pulse round trip lands within 2% of 2L/c0.
    ///
    /// Design notes, because the first version of this gate was wrong in an
    /// instructive way. Taking "max |p| at the source after a time gate" in a
    /// closed lossless box measures REVERBERATION, not the echo — the field
    /// never decays, so the maximum is arbitrary. Two changes fix it:
    ///   (a) sponge the x/y walls but leave z rigid, isolating the axial path;
    ///   (b) detect FIRST ARRIVAL above a threshold rather than the maximum.
    public static func g3TimeOfFlight(nz: Int = 240, dx: Double = 0.003,
                                      medium: Medium = .air) -> GateResult {
        // A rigid-walled waveguide with a PLANE-WAVE source (uniform across
        // x,y) excites only the plane-wave mode, which travels at exactly c0
        // with no geometric spreading — so the echo returns at full amplitude
        // and first-arrival detection is unambiguous. A point source in a
        // sponged box, which this gate tried first, loses the echo in 1/r
        // spreading and never triggers.
        let nxy = 6
        let sim = FDTD(nx: nxy, ny: nxy, nz: nz, dx: dx, medium: medium, spongeCells: 0)
        sim.disableSponge()
        let k0 = nz / 2
        let sensor = (nxy / 2, nxy / 2, k0)
        for k in (k0 - 4)...(k0 + 4) {
            let w = exp(-pow(Double(k - k0), 2) / 4.0)
            for j in 0..<nxy { for i in 0..<nxy { sim.addPressure(w, at: i, j, k) } }
        }
        // Both halves travel k0 cells to their wall and return together.
        let travel = 2.0 * Double(k0) * dx
        let expectedT = travel / medium.soundSpeed

        var peak0 = 0.0, arrival = 0.0
        let maxSteps = Int(expectedT / sim.dt * 1.5)
        for st in 1...maxSteps {
            sim.advance()
            let a = abs(sim.pressure(at: sensor.0, sensor.1, sensor.2))
            let t = Double(st) * sim.dt
            if t < 0.3 * expectedT { peak0 = max(peak0, a); continue }
            if arrival == 0 && a > 0.5 * peak0 { arrival = t }
        }
        let relErr = arrival > 0 ? abs(arrival - expectedT) / expectedT : .infinity
        return GateResult(id: "G3", name: "axial round-trip time of flight",
                          measured: relErr, threshold: 0.02,
                          detail: "first echo \(String(format: "%.4g", arrival * 1e3)) ms vs "
                                + "\(String(format: "%.4g", expectedT * 1e3)) ms "
                                + "(L = \(String(format: "%.0f", travel * 1000)) mm)")
    }


    /// Run the CPU-side gate set.
    public static func runAll() -> [GateResult] {
        [g1Voxelizer(), g2EnergyConservation(), g3TimeOfFlight(), G5.run(),
         g7GorkovAnalytic()]
    }
}
