import Foundation

/// How fast a compiled trap goes stale when the air warms.
///
/// Compile a twin trap at T0, keep the drive, and re-solve the field at
/// T0 + ΔT. The hardware does not move, but the air does: the chamber air and
/// the air in the horn channels both change sound speed by ~0.18 %/K, so every
/// path's phase drifts in proportion to its length. A node only moves when
/// the phases of the paths that interfere there drift DIFFERENTLY, so:
///
///  * with direct paths only, the node sits where the two faces' paths are
///    equal, and a node a distance d off the mid-plane moves by
///    Δz = d · Δc/c (the closed form gate G-T1 checks);
///  * wall images add paths up to several chamber lengths longer, which drift
///    against the direct ones: reverberation is what turns a slow drift into
///    a fast decorrelation (review 2026-09-29, "Q is bought with
///    recalibration rate", ruling R6).
///
/// The field operator comes from `builder`, so FieldCore stays GPU-free; the
/// CLI passes the Metal port-field build.
public enum ThermalDrift {

    public struct Target: Sendable {
        public var label: String
        public var position: Vec3
        public init(_ label: String, _ position: Vec3) { self.label = label; self.position = position }
    }

    public struct Row: Sendable {
        public var frequency: Double
        /// The field model's label (direct paths, plates, glass + plates…).
        public var condition: String
        public var target: String
        /// Distance from the chamber mid-plane (m) — the lever arm of the drift.
        public var offMidPlane: Double
        public var dT: Double
        /// Tracked trap's displacement from its T0 position (m), sub-grid.
        public var shift: Double
        /// Axial (z) part of that displacement (m), signed.
        public var shiftZ: Double
        /// Tracked trap's depth relative to T0.
        public var depthRatio: Double
        /// The deepest well in the probe volume is no longer the tracked trap.
        public var hopped: Bool
        /// With the drive RE-SOLVED at the true temperature (what a twin that
        /// models temperature can do once it knows T): the trap's distance
        /// from its 20 °C position, and its depth relative to 20 °C.
        public var resolvedShift: Double
        public var resolvedDepthRatio: Double
    }

    /// Builds the field model (a `Propagator` over the probe lattice) for one
    /// machine state — free field, plate images, or the glass cavity.
    public typealias Builder = (_ preset: MachinePreset, _ coupling: [Complex],
                                _ lattice: FieldLattice, _ frequency: Double,
                                _ medium: Medium) throws -> Propagator

    public struct Condition {
        public var label: String
        public var maxFrequency: Double
        public var build: Builder
        public init(_ label: String, maxFrequency: Double = .infinity, build: @escaping Builder) {
            self.label = label; self.maxFrequency = maxFrequency; self.build = build
        }
    }

    /// Targets on the free-standing machine (build frame, faces at z = 0 and L).
    public static func defaultTargets(_ d: RH1Design = RH1Design()) -> [Target] {
        let L = d.buildChamberHeight * 0.001
        return [Target("mid-plane", Vec3(0, 0, L / 2)),
                Target("60 mm above mid-plane", Vec3(0, 0, L / 2 + 0.06)),
                Target("60 mm off-axis, mid-plane", Vec3(0.06, 0, L / 2)),
                Target("100 mm above the lower face", Vec3(0, 0, 0.10))]
    }

    public static func run(frequencies: [Double] = [40_000, 100_000, 200_000],
                           dTs: [Double] = [0, 0.1, 0.3, 1, 3],
                           conditions: [Condition],
                           targets: [Target]? = nil,
                           particle: ParticleMaterial = .pla(),
                           base: Medium = RH1Freestanding.roomAir) throws -> [Row] {
        let design = RH1Design()
        let L = design.buildChamberHeight * 0.001
        let tgts = targets ?? defaultTargets(design)
        var rows: [Row] = []
        for f in frequencies {
            let lambda0 = base.wavelength(at: f)
            // Fix the aperture discretization across temperatures, so a
            // re-meshed slot never masquerades as thermal drift.
            let segment = max(2e-3, lambda0 / 4)
            func machine(_ m: Medium) -> (MachinePreset, [Complex]) {
                var o = RH1Freestanding.Options()
                o.frequency = f; o.medium = m; o.slotSegment = segment
                return RH1Freestanding.preset(o)
            }
            for cond in conditions where f <= cond.maxFrequency {
                for t in tgts {
                    // Probe lattice: ±1.5 λ around the target at λ/12.
                    let s = lambda0 / 12, n = 37
                    let half = Double(n - 1) / 2 * s
                    let lat = FieldLattice(origin: t.position - Vec3(half, half, half),
                                           spacing: s, nx: n, ny: n, nz: n)
                    func field(_ m: Medium) throws -> Propagator {
                        let (p, c) = machine(m)
                        return try cond.build(p, c, lat, f, m)
                    }
                    let prop0 = try field(base)
                    let drive = InverseSolver.solve(
                        propagator: prop0, points: [.init(position: t.position)],
                        method: .gspat, iterations: 80, trap: .twinTrap)
                    var ref: (pos: Vec3, depth: Double)? = nil
                    for dT in dTs {
                        let m = base.shifted(byKelvin: dT)
                        let prop = dT == 0 ? prop0 : try field(m)
                        let U = Gorkov(medium: m, particle: particle)
                            .potentialField(propagator: prop, drive: drive)
                        let wells = trackedWells(U: U, lattice: lat)
                        guard !wells.isEmpty else { continue }
                        let anchor = ref?.pos ?? t.position
                        let tracked = wells.min { ($0.pos - anchor).length < ($1.pos - anchor).length }!
                        if ref == nil { ref = tracked }
                        let deepest = wells.max { $0.depth < $1.depth }!
                        // The correction: same target, drive re-solved at the true T.
                        var rShift = 0.0, rDepth = 1.0
                        if dT != 0 {
                            let driveT = InverseSolver.solve(
                                propagator: prop, points: [.init(position: t.position)],
                                method: .gspat, iterations: 80, trap: .twinTrap)
                            let UT = Gorkov(medium: m, particle: particle)
                                .potentialField(propagator: prop, drive: driveT)
                            let wT = trackedWells(U: UT, lattice: lat)
                            if let back = wT.min(by: { ($0.pos - ref!.pos).length < ($1.pos - ref!.pos).length }) {
                                rShift = (back.pos - ref!.pos).length
                                rDepth = back.depth / max(ref!.depth, 1e-300)
                            }
                        }
                        rows.append(Row(frequency: f, condition: cond.label, target: t.label,
                                        offMidPlane: t.position.z - L / 2, dT: dT,
                                        shift: (tracked.pos - ref!.pos).length,
                                        shiftZ: tracked.pos.z - ref!.pos.z,
                                        depthRatio: tracked.depth / max(ref!.depth, 1e-300),
                                        hopped: (deepest.pos - tracked.pos).length > lambda0 / 4,
                                        resolvedShift: rShift, resolvedDepthRatio: rDepth))
                    }
                }
            }
        }
        return rows
    }

    /// Local minima of U with sub-grid positions (a 3-point parabola per axis)
    /// and depth below the probe volume's mean — comparable across ΔT, unlike
    /// a depth measured from a global maximum that itself moves.
    static func trackedWells(U: [Double], lattice lat: FieldLattice) -> [(pos: Vec3, depth: Double)] {
        let mean = U.reduce(0, +) / Double(max(1, U.count))
        var out: [(pos: Vec3, depth: Double)] = []
        for k in 1..<(lat.nz - 1) {
            for j in 1..<(lat.ny - 1) {
                for i in 1..<(lat.nx - 1) {
                    let u = U[lat.index(i, j, k)]
                    let nb = [U[lat.index(i-1, j, k)], U[lat.index(i+1, j, k)],
                              U[lat.index(i, j-1, k)], U[lat.index(i, j+1, k)],
                              U[lat.index(i, j, k-1)], U[lat.index(i, j, k+1)]]
                    guard nb.allSatisfy({ $0 > u }) else { continue }
                    func off(_ a: Double, _ b: Double) -> Double {
                        let den = a - 2 * u + b
                        return den > 0 ? 0.5 * (a - b) / den : 0
                    }
                    let p = lat.position(i, j, k) + Vec3(off(nb[0], nb[1]), off(nb[2], nb[3]),
                                                        off(nb[4], nb[5])) * lat.spacing
                    out.append((p, mean - u))
                }
            }
        }
        return out.filter { $0.depth > 0 }
    }

    /// dc/dT of the base medium, per kelvin (relative).
    public static func relativeSpeedDrift(_ m: Medium = RH1Freestanding.roomAir) -> Double {
        (m.shifted(byKelvin: 0.5).soundSpeed - m.shifted(byKelvin: -0.5).soundSpeed) / m.soundSpeed
    }
}
