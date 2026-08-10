import Foundation

/// Plain double-precision 3-vector. Deliberately not simd: FieldCore is pure
/// and must stay portable to the CPU reference solvers and the test harness.
public struct Vec3: Equatable, Sendable, Codable {
    public var x: Double, y: Double, z: Double
    public init(_ x: Double = 0, _ y: Double = 0, _ z: Double = 0) {
        self.x = x; self.y = y; self.z = z
    }

    public static let zero = Vec3(0, 0, 0)

    public static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x + b.x, a.y + b.y, a.z + b.z) }
    public static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x - b.x, a.y - b.y, a.z - b.z) }
    public static func * (a: Vec3, s: Double) -> Vec3 { Vec3(a.x * s, a.y * s, a.z * s) }
    public static func * (s: Double, a: Vec3) -> Vec3 { a * s }
    public static func / (a: Vec3, s: Double) -> Vec3 { Vec3(a.x / s, a.y / s, a.z / s) }
    public static func += (a: inout Vec3, b: Vec3) { a = a + b }
    public static prefix func - (a: Vec3) -> Vec3 { Vec3(-a.x, -a.y, -a.z) }

    public func dot(_ b: Vec3) -> Double { x * b.x + y * b.y + z * b.z }
    public func cross(_ b: Vec3) -> Vec3 {
        Vec3(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x)
    }
    public var length: Double { (x * x + y * y + z * z).squareRoot() }
    public var lengthSquared: Double { x * x + y * y + z * z }
    public var normalized: Vec3 {
        let l = length
        return l > 0 ? self / l : self
    }

    /// Cylindrical radius about the z axis — the RH-1 frame's natural coordinate.
    public var radiusXY: Double { (x * x + y * y).squareRoot() }
    public var azimuth: Double { atan2(y, x) }
}
