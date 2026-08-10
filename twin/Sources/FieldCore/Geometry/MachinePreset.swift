import Foundation

/// One transducer element on the boundary. The unit the propagator sums over.
/// How an element radiates. A pressure injection at a single FDTD cell is a
/// MONOPOLE (omnidirectional); a real transducer face is a baffled piston. G5
/// compares T0 against T1 driven by a point source, so it needs the monopole
/// model — using the piston form there would compare two different sources and
/// report a propagator error that is really a source-model mismatch.
public enum Directivity: String, Sendable, Codable {
    case piston, monopole
}

public struct Element: Sendable, Codable {
    public var position: Vec3          // metres, RH-1 frame (origin = lower cap face)
    public var normal: Vec3            // outward from the surface, into the volume
    public var area: Double            // m^2
    public var surface: SurfaceID
    public var gateIndex: Int          // which addressable gate this belongs to
    public var isTX: Bool
    public var isRX: Bool
    public var directivity: Directivity

    public init(position: Vec3, normal: Vec3, area: Double, surface: SurfaceID,
                gateIndex: Int, isTX: Bool = true, isRX: Bool = true,
                directivity: Directivity = .piston) {
        self.position = position; self.normal = normal; self.area = area
        self.surface = surface; self.gateIndex = gateIndex
        self.isTX = isTX; self.isRX = isRX
        self.directivity = directivity
    }

    /// Equivalent radius of a disc of the same area — the piston directivity parameter.
    public var equivalentRadius: Double { (area / Double.pi).squareRoot() }
}

public enum SurfaceID: String, Sendable, Codable, CaseIterable {
    case lowerCap, upperCap, panel, column, glass, sphereGate
}

/// A cylindrical build volume: r <= radius, z in [0, height].
public struct BuildVolume: Sendable, Codable {
    public var radius: Double
    public var height: Double
    public init(radius: Double, height: Double) { self.radius = radius; self.height = height }

    public func contains(_ p: Vec3) -> Bool {
        p.z >= 0 && p.z <= height && p.radiusXY <= radius
    }
    public var boundsMin: Vec3 { Vec3(-radius, -radius, 0) }
    public var boundsMax: Vec3 { Vec3(radius, radius, height) }
}

/// A machine configuration. §10: the gate count and gate geometry are preset
/// DATA, never a hard-coded 12 — three different "12"s exist in this document
/// family and conflating them has bitten the project before.
public struct MachinePreset: Sendable, Codable {
    public var id: String
    public var displayName: String
    public var elements: [Element]
    public var gateCount: Int
    public var buildVolume: BuildVolume
    public var medium: Medium
    public var defaultBand: ClosedRange<Double>   // Hz

    public init(id: String, displayName: String, elements: [Element], gateCount: Int,
                buildVolume: BuildVolume, medium: Medium = .air,
                defaultBand: ClosedRange<Double> = 20_000...80_000) {
        self.id = id; self.displayName = displayName; self.elements = elements
        self.gateCount = gateCount; self.buildVolume = buildVolume
        self.medium = medium; self.defaultBand = defaultBand
    }

    public var txElements: [Element] { elements.filter(\.isTX) }
    public var rxElements: [Element] { elements.filter(\.isRX) }

    /// Element indices belonging to each gate, in gate order.
    public func elementIndices(forGate g: Int) -> [Int] {
        elements.indices.filter { elements[$0].gateIndex == g }
    }
}

public struct Medium: Sendable, Codable {
    public var density: Double        // rho0, kg/m^3
    public var soundSpeed: Double     // c0, m/s
    public init(density: Double, soundSpeed: Double) {
        self.density = density; self.soundSpeed = soundSpeed
    }
    /// §12 material presets: air at 20 C.
    public static let air = Medium(density: 1.204, soundSpeed: 343.0)
    public static let water = Medium(density: 998.0, soundSpeed: 1481.0)

    public func wavelength(at f: Double) -> Double { soundSpeed / f }
    public func wavenumber(at f: Double) -> Double { 2 * .pi * f / soundSpeed }
}
