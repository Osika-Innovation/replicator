import Foundation

/// Two plates facing each other across open air, each a holographic surface of
/// N independently driven elements (ENGINE.md, decisions of 2026-10-01).
///
/// The elements sit on a Vogel spiral — radius ∝ √n, angle stepping by the
/// golden angle — so the density is uniform and every element has its own
/// radius: an aperiodic array, with no grating lobes however sparse it is.
/// Each element is a baffled piston of radius `elementRadius` on its plate
/// (the plate is the baffle), driven by its own channel: element index =
/// drive index, lower plate first. The plates reflect with `reflection` (0 is
/// free field), imaged to `imageOrder` bounces, the same image series and the
/// same piston directivity as the gated port-field model (G-GPU-FS).
public struct PlateArray: Sendable {
    /// Elements per plate.
    public var perPlate: Int
    /// Radius of the plate area the elements fill (m).
    public var plateRadius: Double
    /// Plate separation (m); the lower plate's face is z = 0, the upper z = gap.
    public var gap: Double
    /// Piston radius of one element (m).
    public var elementRadius: Double
    /// Plate reflection coefficient; 0 = free field.
    public var reflection: Double
    public var imageOrder: Int

    public init(perPlate: Int, plateRadius: Double = 0.205, gap: Double = 0.46,
                elementRadius: Double = 2.5e-3, reflection: Double = 0.9, imageOrder: Int = 3) {
        self.perPlate = perPlate; self.plateRadius = plateRadius; self.gap = gap
        self.elementRadius = elementRadius; self.reflection = reflection; self.imageOrder = imageOrder
    }

    public static let goldenAngle = Double.pi * (3 - 5.0.squareRoot())

    /// Vogel spiral of n points filling a disc of radius R; `rotation` turns it.
    public static func vogel(_ n: Int, radius R: Double, rotation: Double = 0) -> [(x: Double, y: Double)] {
        (0..<n).map { i in
            let r = R * ((Double(i) + 0.5) / Double(n)).squareRoot()
            let t = Double(i) * goldenAngle + rotation
            return (r * cos(t), r * sin(t))
        }
    }

    public var channels: Int { 2 * perPlate }

    /// All elements: the lower plate (normal +z) then the upper (normal −z),
    /// the upper spiral turned by half the golden angle so no element faces
    /// another exactly. gateIndex = the element's drive channel.
    public func elements() -> [Element] {
        let area = Double.pi * elementRadius * elementRadius
        var out: [Element] = []
        for (i, p) in PlateArray.vogel(perPlate, radius: plateRadius).enumerated() {
            out.append(Element(position: Vec3(p.x, p.y, 0), normal: Vec3(0, 0, 1), area: area,
                               surface: .lowerCap, gateIndex: i))
        }
        for (i, p) in PlateArray.vogel(perPlate, radius: plateRadius, rotation: PlateArray.goldenAngle / 2).enumerated() {
            out.append(Element(position: Vec3(p.x, p.y, gap), normal: Vec3(0, 0, -1), area: area,
                               surface: .upperCap, gateIndex: perPlate + i))
        }
        return out
    }

    public var walls: Propagator.Walls {
        reflection > 0 && imageOrder > 0
            ? Propagator.Walls(capSeparation: gap, order: imageOrder, reflectionCoefficient: reflection)
            : .none
    }

    /// The work volume's centre: the mid-plane, on the axis.
    public var centre: Vec3 { Vec3(0, 0, gap / 2) }

    /// The CPU reference for this array: a `Propagator` with one gate per
    /// element, evaluated at the given points (rows: `gateGradientRows`).
    public func reference(frequency: Double, medium: Medium) -> Propagator {
        Propagator(elements: elements(), lattice: FieldLattice(origin: .zero, spacing: 1, nx: 1, ny: 1, nz: 1),
                   frequency: frequency, medium: medium, gateCount: channels, walls: walls)
    }
}
