import Foundation

/// A thin current path: a polyline in metres, closed or open.
public struct Filament: Sendable {
    public var points: [Vec3]
    public var closed: Bool

    public init(points: [Vec3], closed: Bool = true) {
        self.points = points; self.closed = closed
    }

    public var segmentCount: Int { closed ? points.count : max(0, points.count - 1) }

    public var length: Double {
        var s = 0.0
        for i in 0..<segmentCount { s += (points[(i + 1) % points.count] - points[i]).length }
        return s
    }

    /// A circular loop about the z axis, counter-clockwise seen from +z.
    public static func loop(radius: Double, z: Double = 0, segments: Int = 720) -> Filament {
        Filament(points: (0..<segments).map { i in
            let t = 2 * Double.pi * Double(i) / Double(segments)
            return Vec3(radius * cos(t), radius * sin(t), z)
        })
    }

    /// A (turns, 1) torus knot: `turns` poloidal turns in one trip round the
    /// major circle. `hand` ±1 mirrors it in the torus plane.
    public static func toroidalHelix(majorRadius R: Double, minorRadius a: Double, turns: Int,
                                     z: Double = 0, hand: Double = 1, samplesPerTurn: Int = 48) -> Filament {
        let n = turns * samplesPerTurn
        return Filament(points: (0..<n).map { i in
            let t = 2 * Double.pi * Double(i) / Double(n), q = Double(turns) * t
            let rr = R + a * cos(q)
            return Vec3(rr * cos(t), rr * sin(t), z + hand * a * sin(q))
        })
    }
}

/// Quasi-static magnetic fields of thin wires in free space (Biot–Savart).
///
/// Valid while the wire is short against the free-space wavelength: the
/// current is then the same all along a winding and the field follows it
/// instantly. No capacitance, no radiation, no magnetic materials — the
/// RH-1's former is PEEK and its structure aluminium, so there is no iron
/// (eddy currents in the aluminium at high frequency are NOT modelled).
public enum Magnetostatics {

    public static let mu0 = 4e-7 * Double.pi

    /// B (tesla) per ampere at `x`. Each straight segment contributes its
    /// exact finite-wire field,
    ///   B = (μ0/4π) (r1 × r2)(|r1| + |r2|) / (|r1||r2|(|r1||r2| + r1·r2)),
    /// so the only discretisation error is the polygon standing for the curve.
    public static func field(of f: Filament, at x: Vec3) -> Vec3 {
        let n = f.points.count
        guard n >= 2 else { return .zero }
        var bx = 0.0, by = 0.0, bz = 0.0
        var r1 = x - f.points[0]
        var l1 = r1.length
        for i in 0..<f.segmentCount {
            let r2 = x - f.points[(i + 1) % n]
            let l2 = r2.length
            let den = l1 * l2 * (l1 * l2 + r1.dot(r2))
            if den > 1e-30 {
                let k = (l1 + l2) / den
                bx += k * (r1.y * r2.z - r1.z * r2.y)
                by += k * (r1.z * r2.x - r1.x * r2.z)
                bz += k * (r1.x * r2.y - r1.y * r2.x)
            }
            r1 = r2; l1 = l2
        }
        let c = mu0 / (4 * Double.pi)
        return Vec3(bx * c, by * c, bz * c)
    }

    /// ∮ B·dl / μ0 round a closed polyline, per ampere in the filament: the
    /// current the loop links (Ampère). Midpoint rule on the given vertices.
    public static func linkedCurrent(of f: Filament, around loop: [Vec3]) -> Double {
        var s = 0.0
        for i in 0..<loop.count {
            let a = loop[i], b = loop[(i + 1) % loop.count]
            s += field(of: f, at: (a + b) * 0.5).dot(b - a)
        }
        return s / mu0
    }
}

/// The time-averaged force on small bodies in a magnetic field.
public enum MagneticForce {

    /// A material as the windings see it. `chi` is the SI volume
    /// susceptibility (negative = diamagnetic); `conductivity` in S/m.
    public struct Material: Sendable {
        public var name: String
        public var density: Double
        public var chi: Double
        public var conductivity: Double
        public init(_ name: String, density: Double, chi: Double = 0, conductivity: Double = 0) {
            self.name = name; self.density = density; self.chi = chi; self.conductivity = conductivity
        }
    }

    public static func skinDepth(conductivity: Double, frequency: Double) -> Double {
        (1 / (Double.pi * frequency * Magnetostatics.mu0 * conductivity)).squareRoot()
    }

    /// Real part of the magnetic polarisability per unit volume of a
    /// non-magnetic conducting sphere in an alternating field (m = α V H):
    ///   α' = −(3/2) [1 − (3δ/2a)(sinh u − sin u)/(cosh u − cos u)],  u = 2a/δ
    /// (Landau & Lifshitz, Electrodynamics of Continuous Media §59, in SI).
    /// It runs from −(4/105)(a/δ)⁴ for a grain much smaller than the skin
    /// depth to −3/2 for a perfect screen. The eddy currents always oppose
    /// the field, so the grain is pushed toward weaker field.
    public static func eddyPolarizability(radiusOverSkinDepth x: Double) -> Double {
        guard x > 0 else { return 0 }
        if x < 0.4 {                                     // series: the closed form cancels to 1e-16 here
            let x4 = x * x * x * x
            return -(4.0 / 105) * x4 * (1 - (4.0 / 99) * x4)
        }
        let u = 2 * x
        if u > 40 { return -1.5 * (1 - 3 / u) }
        return -1.5 * (1 - (3 / u) * (sinh(u) - sin(u)) / (cosh(u) - cos(u)))
    }

    /// |∂(B²)/∂z| (T²/m) that holds a body against gravity in a STATIC field:
    /// the force per volume is χ ∇(B²) / 2μ0.
    public static func staticLevitationGradient(_ m: Material, g: Double = 9.80665) -> Double {
        guard m.chi != 0 else { return .infinity }
        return 2 * Magnetostatics.mu0 * m.density * g / abs(m.chi)
    }

    /// |∂(B̂²)/∂z| (T²/m, B̂ the AC amplitude) that holds a conducting sphere
    /// against gravity: the mean force per volume is α' ∇(B̂²) / 4μ0.
    public static func eddyLevitationGradient(_ m: Material, radius: Double, frequency: Double,
                                              g: Double = 9.80665) -> Double {
        guard m.conductivity > 0, frequency > 0 else { return .infinity }
        let a = eddyPolarizability(radiusOverSkinDepth: radius / skinDepth(conductivity: m.conductivity,
                                                                           frequency: frequency))
        return a == 0 ? .infinity : 4 * Magnetostatics.mu0 * m.density * g / abs(a)
    }
}

/// The RH-1's windings as circuits the twin can drive: three contrawound
/// pairs (top, middle, deck), each winding its own circuit (ruling R5), read
/// from the same centrelines the solid model sweeps its wires along.
public struct WindingSet: Sendable {

    public struct Circuit: Sendable {
        public var name: String
        public var assembly: String
        public var hand: Double             // +1 inner layer (feed A), −1 outer layer (feed B)
        public var filament: Filament
    }

    public var circuits: [Circuit]

    public init(circuits: [Circuit]) { self.circuits = circuits }

    public static func rh1(_ d: RH1Design = RH1Design(), samplesPerTurn: Int = 48) -> WindingSet {
        var out: [Circuit] = []
        for a in d.assemblies {
            for hand in [1.0, -1.0] {
                let mm = d.windingCenterline(torusZ: a.torusZ, hand: hand, samplesPerTurn: samplesPerTurn)
                out.append(Circuit(name: "\(a.id) \(hand > 0 ? "A" : "B")", assembly: a.id, hand: hand,
                                   filament: Filament(points: mm.map { $0 * 1e-3 })))
            }
        }
        return WindingSet(circuits: out)
    }

    /// B per ampere of every circuit at every point: rows[circuit][point].
    public func rows(at points: [Vec3]) -> [[Vec3]] {
        circuits.map { c in
            var row = [Vec3](repeating: .zero, count: points.count)
            row.withUnsafeMutableBufferPointer { buf in
                let out = UncheckedSendableBuffer(buf)
                DispatchQueue.concurrentPerform(iterations: points.count) { p in
                    out.base[p] = Magnetostatics.field(of: c.filament, at: points[p])
                }
            }
            return row
        }
    }

    public func field(currents: [Double], at x: Vec3) -> Vec3 {
        var b = Vec3.zero
        for (c, i) in zip(circuits, currents) where i != 0 { b += Magnetostatics.field(of: c.filament, at: x) * i }
        return b
    }

    /// The quadratic form of the lift: −∂(B²)/∂z at `x` is iᵀ Q i for the
    /// circuit currents i (per A²). Positive = a diamagnetic or eddy-screened
    /// grain is pushed up. Central differences over ±h.
    public func liftForm(at x: Vec3, h: Double = 0.5e-3) -> [[Double]] {
        let n = circuits.count
        let up = circuits.map { Magnetostatics.field(of: $0.filament, at: x + Vec3(0, 0, h)) }
        let dn = circuits.map { Magnetostatics.field(of: $0.filament, at: x - Vec3(0, 0, h)) }
        var q = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
        for j in 0..<n { for k in 0..<n {
            q[j][k] = -(up[j].dot(up[k]) - dn[j].dot(dn[k])) / (2 * h)
        } }
        return q
    }
}

/// Lets disjoint slots of one buffer be written from concurrent iterations.
struct UncheckedSendableBuffer<T>: @unchecked Sendable {
    let base: UnsafeMutableBufferPointer<T>
    init(_ b: UnsafeMutableBufferPointer<T>) { base = b }
}

public extension LinAlg {
    /// Eigen-decomposition of a real symmetric matrix (cyclic Jacobi).
    /// Returns eigenvalues in descending order with their unit eigenvectors.
    static func symmetricEigen(_ Ain: [[Double]], sweeps: Int = 60) -> (values: [Double], vectors: [[Double]]) {
        let n = Ain.count
        var A = Ain
        var V = (0..<n).map { i in (0..<n).map { $0 == i ? 1.0 : 0.0 } }
        for _ in 0..<sweeps {
            var off = 0.0
            for p in 0..<n { for q in (p + 1)..<n { off += A[p][q] * A[p][q] } }
            var diag = 0.0
            for p in 0..<n { diag += A[p][p] * A[p][p] }
            if off <= 1e-30 * max(diag, 1e-300) { break }
            for p in 0..<n { for q in (p + 1)..<n where A[p][q] != 0 {
                let theta = (A[q][q] - A[p][p]) / (2 * A[p][q])
                let t = (theta >= 0 ? 1.0 : -1.0) / (abs(theta) + (theta * theta + 1).squareRoot())
                let c = 1 / (t * t + 1).squareRoot(), s = t * c
                for k in 0..<n {
                    let akp = A[k][p], akq = A[k][q]
                    A[k][p] = c * akp - s * akq; A[k][q] = s * akp + c * akq
                }
                for k in 0..<n {
                    let apk = A[p][k], aqk = A[q][k]
                    A[p][k] = c * apk - s * aqk; A[q][k] = s * apk + c * aqk
                }
                for k in 0..<n {
                    let vkp = V[k][p], vkq = V[k][q]
                    V[k][p] = c * vkp - s * vkq; V[k][q] = s * vkp + c * vkq
                }
            } }
        }
        let order = (0..<n).sorted { A[$0][$0] > A[$1][$1] }
        return (order.map { A[$0][$0] }, order.map { j in (0..<n).map { V[$0][j] } })
    }
}
