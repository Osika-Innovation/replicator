import Foundation

/// T1 — staggered-grid (Yee-style) linear acoustic FDTD (§12).
///
///   v[f] -= dt/(rho_face * dx) * (p[cell+] - p[cell-])
///   p[c] -= rho[c]*c2[c]*dt/dx * (sum_faces v_out)
///   dt = 0.5 * dx / (c_max * sqrt(3))          // CFL with margin
///
/// This is the CPU reference implementation (§23): small, slow, and obviously
/// correct, so every GPU kernel has something to be tested against. Physics
/// identical to the Metal path.
public final class FDTD {
    public let nx: Int, ny: Int, nz: Int
    public let dx: Double
    public let dt: Double
    public let medium: Medium

    public private(set) var p: [Double]
    public private(set) var vx: [Double]     // (nx+1) * ny * nz
    public private(set) var vy: [Double]
    public private(set) var vz: [Double]

    public private(set) var rho: [Double]
    public private(set) var c2: [Double]
    private var damping: [Double]            // per-cell sponge factor, 1 = none

    public private(set) var step: Int = 0

    // Previous-half-step velocities. The leapfrog invariant pairs consecutive
    // half-step velocities; using v^2 at a single half step is NOT conserved
    // and drifts at O(dt^2) — which is what gate G2 caught on its first run.
    private var vxPrev: [Double] = []
    private var vyPrev: [Double] = []
    private var vzPrev: [Double] = []
    private var cachedEnergy: Double? = nil

    public init(nx: Int, ny: Int, nz: Int, dx: Double, medium: Medium = .air,
                rho: [Double]? = nil, c2: [Double]? = nil,
                spongeCells: Int = 16, cfl: Double = 0.5,
                spongeAxes: (x: Bool, y: Bool, z: Bool) = (true, true, true)) {
        self.nx = nx; self.ny = ny; self.nz = nz
        self.dx = dx; self.medium = medium
        let n = nx * ny * nz
        self.rho = rho ?? [Double](repeating: medium.density, count: n)
        self.c2 = c2 ?? [Double](repeating: medium.soundSpeed * medium.soundSpeed, count: n)
        let cMax = (self.c2.max() ?? (medium.soundSpeed * medium.soundSpeed)).squareRoot()
        // CFL is set by the FASTEST material in the grid (§12 sizing trap 1).
        self.dt = cfl * dx / (cMax * 3.0.squareRoot())
        self.p = [Double](repeating: 0, count: n)
        self.vx = [Double](repeating: 0, count: (nx + 1) * ny * nz)
        self.vy = [Double](repeating: 0, count: nx * (ny + 1) * nz)
        self.vz = [Double](repeating: 0, count: nx * ny * (nz + 1))

        // Quadratically-ramped sponge inside every wall. A lossless closed
        // cavity never stops ringing and its S(f) is garbage (§12).
        var d = [Double](repeating: 1.0, count: n)
        if spongeCells > 0 {
            let sigmaMax = 0.35 / dt
            for k in 0..<nz {
                for j in 0..<ny {
                    for i in 0..<nx {
                        var depth = Int.max
                        if spongeAxes.x { depth = min(depth, min(i, nx - 1 - i)) }
                        if spongeAxes.y { depth = min(depth, min(j, ny - 1 - j)) }
                        if spongeAxes.z { depth = min(depth, min(k, nz - 1 - k)) }
                        if depth < spongeCells {
                            let t = 1.0 - Double(depth) / Double(spongeCells)
                            let sigma = sigmaMax * t * t
                            d[(k * ny + j) * nx + i] = exp(-sigma * dt)
                        }
                    }
                }
            }
        }
        self.damping = d
    }

    @inline(__always) public func idx(_ i: Int, _ j: Int, _ k: Int) -> Int {
        (k * ny + j) * nx + i
    }

    /// Disable the sponge — used by G2, which needs a lossless closed cavity to
    /// measure energy drift honestly.
    public func disableSponge() {
        damping = [Double](repeating: 1.0, count: nx * ny * nz)
    }

    public func addPressure(_ amount: Double, at i: Int, _ j: Int, _ k: Int) {
        p[idx(i, j, k)] += amount
    }

    public func pressure(at i: Int, _ j: Int, _ k: Int) -> Double { p[idx(i, j, k)] }

    /// One timestep. Rigid walls (v.n = 0) come for free by never updating the
    /// boundary velocity faces.
    public func advance() {
        vxPrev = vx; vyPrev = vy; vzPrev = vz
        // ---- velocity update from the pressure gradient ----
        for k in 0..<nz {
            for j in 0..<ny {
                for i in 1..<nx {
                    let a = idx(i - 1, j, k), b = idx(i, j, k)
                    let rhoFace = 0.5 * (rho[a] + rho[b])
                    vx[(k * ny + j) * (nx + 1) + i] -= dt / (rhoFace * dx) * (p[b] - p[a])
                }
            }
        }
        for k in 0..<nz {
            for j in 1..<ny {
                for i in 0..<nx {
                    let a = idx(i, j - 1, k), b = idx(i, j, k)
                    let rhoFace = 0.5 * (rho[a] + rho[b])
                    vy[(k * (ny + 1) + j) * nx + i] -= dt / (rhoFace * dx) * (p[b] - p[a])
                }
            }
        }
        for k in 1..<nz {
            for j in 0..<ny {
                for i in 0..<nx {
                    let a = idx(i, j, k - 1), b = idx(i, j, k)
                    let rhoFace = 0.5 * (rho[a] + rho[b])
                    vz[(k * ny + j) * nx + i] -= dt / (rhoFace * dx) * (p[b] - p[a])
                }
            }
        }
        // Energy is sampled HERE and nowhere else: p is still p^n while both
        // v^{n-1/2} and v^{n+1/2} are in hand. Sampling after the pressure
        // update mixes timesteps and reintroduces the O(dt^2) drift.
        cachedEnergy = computeEnergy()

        // ---- pressure update from the velocity divergence ----
        for k in 0..<nz {
            for j in 0..<ny {
                for i in 0..<nx {
                    let c = idx(i, j, k)
                    let div = (vx[(k * ny + j) * (nx + 1) + i + 1] - vx[(k * ny + j) * (nx + 1) + i])
                            + (vy[(k * (ny + 1) + j + 1) * nx + i] - vy[(k * (ny + 1) + j) * nx + i])
                            + (vz[((k + 1) * ny + j) * nx + i] - vz[(k * ny + j) * nx + i])
                    p[c] -= rho[c] * c2[c] * dt / dx * div
                    p[c] *= damping[c]
                }
            }
        }
        step += 1
    }

    /// Total acoustic energy, using the DISCRETE leapfrog invariant:
    ///
    ///     E = sum_c [ p_c^2 / (2 rho c^2) ]  +  sum_c [ rho * v(n-1/2) . v(n+1/2) / 2 ]
    ///
    /// The kinetic term pairs CONSECUTIVE half-step velocities rather than
    /// squaring one of them. Squaring a single half step is not a conserved
    /// quantity for this scheme and drifts at O(dt^2) — gate G2 caught exactly
    /// that on its first run, at 1.4% over 10k steps.
    public func totalEnergy() -> Double { cachedEnergy ?? computeEnergy() }

    private func computeEnergy() -> Double {
        var e = 0.0
        let cellVol = dx * dx * dx
        for c in 0..<(nx * ny * nz) {
            e += p[c] * p[c] / (2 * rho[c] * c2[c]) * cellVol
        }
        let havePrev = !vxPrev.isEmpty
        for k in 0..<nz {
            for j in 0..<ny {
                for i in 0..<nx {
                    let c = idx(i, j, k)
                    let ax0 = (k * ny + j) * (nx + 1) + i, ax1 = ax0 + 1
                    let ay0 = (k * (ny + 1) + j) * nx + i, ay1 = (k * (ny + 1) + j + 1) * nx + i
                    let az0 = (k * ny + j) * nx + i, az1 = ((k + 1) * ny + j) * nx + i
                    let ux = 0.5 * (vx[ax0] + vx[ax1])
                    let uy = 0.5 * (vy[ay0] + vy[ay1])
                    let uz = 0.5 * (vz[az0] + vz[az1])
                    let px = havePrev ? 0.5 * (vxPrev[ax0] + vxPrev[ax1]) : ux
                    let py = havePrev ? 0.5 * (vyPrev[ay0] + vyPrev[ay1]) : uy
                    let pz = havePrev ? 0.5 * (vzPrev[az0] + vzPrev[az1]) : uz
                    e += rho[c] * (ux * px + uy * py + uz * pz) / 2 * cellVol
                }
            }
        }
        return e
    }
}
