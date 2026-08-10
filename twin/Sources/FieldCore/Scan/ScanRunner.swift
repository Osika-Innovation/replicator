import Foundation

/// §15 — the scan pipeline, and §16.3 — Machine View reconstruction.
public enum Scan {

    /// A gate on the chamber boundary: where it sits and which way it faces.
    public struct Gate: Sendable, Codable {
        public var position: Vec3
        public var normal: Vec3
        public init(position: Vec3, normal: Vec3) {
            self.position = position; self.normal = normal
        }
    }

    /// Probe codes (§15 step 2).
    public enum ProbeCode: String, Sendable, CaseIterable, Codable {
        case identity
        /// Welch–Costas: 13 is prime with primitive root 2, so a perfect
        /// thumbtack-ambiguity schedule exists for exactly 12 gates.
        case welchCostas

        public func schedule(gates: Int) -> [Int] {
            switch self {
            case .identity:
                return Array(0..<gates)
            case .welchCostas:
                guard gates == 12 else { return Array(0..<gates) }
                // slot k -> gate 2^k mod 13, minus one for 0-based indexing
                return (1...12).map { k in
                    var v = 1
                    for _ in 0..<k { v = (v * 2) % 13 }
                    return v - 1
                }
            }
        }
    }

    /// Result of a scan: the measured scattering data plus its provenance.
    public struct Result: Sendable {
        public var portRecords: [[Double]]     // [gate][sample], object present
        public var referenceRecords: [[Double]] // empty-chamber reference
        public var dt: Double
        public var gates: [Gate]
        public var chords: [MatrixPencil.Chord]
        public var reciprocity: Double
        public var calibrationRef: String
    }

    /// Run a pulse-echo scan in a walled FDTD chamber.
    ///
    /// Deliberately T1, not T0: the whole point of a scan is the scattering off
    /// the workpiece, and T0 is a free-field propagator that has none (§5).
    public static func run(nx: Int, ny: Int, nz: Int, dx: Double,
                           medium: Medium = .air,
                           object: Mesh? = nil,
                           objectMedium: Medium = Medium(density: 1240, soundSpeed: 2220),
                           gateCount: Int = 12,
                           steps: Int = 900,
                           code: ProbeCode = .identity) -> Result {
        let lattice = FieldLattice(origin: Vec3(0, 0, 0), spacing: dx,
                                   nx: nx, ny: ny, nz: nz)
        // Gates on the chamber wall, ringed around the mid-height.
        var gates: [Gate] = []
        let cx = Double(nx - 1) * dx / 2, cy = Double(ny - 1) * dx / 2
        let rGate = min(cx, cy) * 0.92
        for g in 0..<gateCount {
            let a = 2 * Double.pi * Double(g) / Double(gateCount)
            let z = Double(nz - 1) * dx * (0.3 + 0.4 * Double(g % 3) / 2)
            gates.append(Gate(position: Vec3(cx + rGate * cos(a), cy + rGate * sin(a), z),
                              normal: Vec3(-cos(a), -sin(a), 0)))
        }
        func cellOf(_ p: Vec3) -> (Int, Int, Int) {
            (min(nx - 2, max(1, Int(p.x / dx))),
             min(ny - 2, max(1, Int(p.y / dx))),
             min(nz - 2, max(1, Int(p.z / dx))))
        }

        var materials: (rho: [Double], c2: [Double])? = nil
        if let object {
            let centred = object.translated(by: Vec3(cx, cy, Double(nz - 1) * dx / 2)
                                            - object.centroid)
            materials = Voxelizer.materialGrid(mesh: centred, lattice: lattice,
                                               inside: objectMedium, outside: medium)
        }

        // S[rx][tx] — keep the per-DRIVE structure. Summing all drives into one
        // record set (the first version of this) destroys the scattering matrix
        // and makes reciprocity trivially satisfied: a Gram matrix is symmetric
        // by construction, so the QC measures nothing. Observed as 0.0000.
        func pulseRun(withObject: Bool) -> [[[Double]]] {
            var records = [[[Double]]](
                repeating: [[Double]](repeating: [], count: gateCount),
                count: gateCount)
            let order = code.schedule(gates: gateCount)
            for driven in order {
                let sim = FDTD(nx: nx, ny: ny, nz: nz, dx: dx, medium: medium,
                               rho: withObject ? materials?.rho : nil,
                               c2: withObject ? materials?.c2 : nil,
                               spongeCells: 6)
                let (gi, gj, gk) = cellOf(gates[driven].position)
                // Gaussian-windowed tone, as §12 specifies for the source.
                // Drive frequency FOLLOWS the grid: the spec requires dx <= lambda/5
                // (§12), and a first pass ran 40 kHz on a 4 mm grid = lambda/2.1,
                // where the propagating wave is numerically garbage and the pencil
                // extracted only f = 0 poles.
                let f0 = medium.soundSpeed / (8 * dx)
                let tau = 3.0 / f0
                let t0 = 3 * tau
                var trace = [[Double]](repeating: [], count: gateCount)
                for step in 0..<steps {
                    let t = Double(step) * sim.dt
                    let env = exp(-pow((t - t0) / tau, 2))
                    sim.addPressure(env * sin(2 * .pi * f0 * t), at: gi, gj, gk)
                    sim.advance()
                    for (r, gate) in gates.enumerated() {
                        let (a, b, c) = cellOf(gate.position)
                        trace[r].append(sim.pressure(at: a, b, c))
                    }
                }
                for r in 0..<gateCount { records[r][driven] = trace[r] }
            }
            return records
        }

        let reference = pulseRun(withObject: false)
        let measured = object == nil ? reference : pulseRun(withObject: true)

        // Differential: the object's own response, reference removed (§15 step 3).
        var full = measured
        for rx in 0..<gateCount {
            for tx in 0..<gateCount {
                let n = min(full[rx][tx].count, reference[rx][tx].count)
                for k in 0..<n { full[rx][tx][k] -= reference[rx][tx][k] }
            }
        }
        // Per-gate record for the pencil: the monostatic (rx == tx) echo, which
        // is what a pulse-echo scan actually reads.
        let differential = (0..<gateCount).map { full[$0][$0] }

        let dt = FDTD(nx: 2, ny: 2, nz: 2, dx: dx, medium: medium, spongeCells: 0).dt
        // Order and window from the measured sweep (see MatrixPencil docs):
        // held-out error converges to ~0.122 and G18's 0.15 bar is first met at
        // order 64 / window 128.
        let chords = MatrixPencil.extract(records: differential, dt: dt,
                                          maxChords: 96, pencilWindow: 180)

        // Reciprocity QC (G15) on the REAL scattering matrix: energy received at
        // rx when tx was driven. S[i][j] vs S[j][i] is now a genuine test.
        var S = LinAlg.zeros(gateCount, gateCount)
        for rx in 0..<gateCount {
            for tx in 0..<gateCount {
                var acc = 0.0
                for v in full[rx][tx] { acc += v * v }
                S[rx][tx] = Complex(acc.squareRoot(), 0)
            }
        }
        let recip = PhysicsGates.g15Reciprocity(S).measured

        return Result(portRecords: differential,
                      referenceRecords: (0..<gateCount).map { reference[$0][$0] },
                      dt: dt, gates: gates, chords: chords,
                      reciprocity: recip,
                      calibrationRef: "emulated-empty-chamber")
    }
}
