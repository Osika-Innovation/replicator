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
    /// The spiral fills the annulus from here to `plateRadius` (m); 0 = the whole disc.
    public var innerRadius: Double = 0
    /// Name for receipts and file names; nil = by layout.
    public var label: String? = nil

    /// One element of an explicit layout: where it sits on its plate (m) and
    /// its piston radius (m).
    public struct Site: Sendable {
        public var x: Double, y: Double, radius: Double
        public init(x: Double, y: Double, radius: Double) { self.x = x; self.y = y; self.radius = radius }
    }
    /// An explicit layout for each plate, replacing the ideal Vogel spiral —
    /// e.g. the sites the CAD's face plate actually has (`PlateArray.fromCAD`).
    /// Both plates must carry the same number of elements.
    public var lowerSites: [Site]? = nil
    public var upperSites: [Site]? = nil
    /// Short name for receipts and file names.
    public var tag: String { label ?? (lowerSites == nil ? "plates\(perPlate)" : "platesCAD\(perPlate)") }

    /// THE machine's plates: the element array the CAD's face plate is drawn
    /// round (`RH1Design.faceStyle == .elementArray`, ruling of 2026-11-10) —
    /// `elementCount` elements on a Vogel spiral over the annulus the plate
    /// can carry, the gap the build chamber's height. `FacePattern` draws its
    /// holes from the same `vogel` call, and gate G-CAD9 holds the two equal.
    public static func rh1(_ d: RH1Design = RH1Design(), reflection: Double = 0.9, imageOrder: Int = 3) -> PlateArray {
        var a = PlateArray(perPlate: d.elementCount, plateRadius: d.elementFillRadius * 1e-3, gap: d.buildChamberHeight * 1e-3,
                           elementRadius: d.elementDiameter / 2 * 1e-3, reflection: reflection, imageOrder: imageOrder)
        a.innerRadius = d.elementInnerRadius * 1e-3
        a.label = "rh1x\(d.elementCount)"
        return a
    }

    /// The v0.4 micro-horn face read as an array: one independently driven
    /// element behind every drilled micro-horn (the sunflower sites the twelve
    /// slots do not swallow), piston radius = the horn's face opening, both
    /// plates carrying the same world-frame pattern. Kept as the comparison
    /// that led to the redraw (Round 14: the mold loses evenness on it).
    public static func fromCAD(_ d: RH1Design = RH1Design.microHornFace, reflection: Double = 0.9, imageOrder: Int = 3) -> PlateArray {
        if d.faceStyle == .elementArray { return rh1(d, reflection: reflection, imageOrder: imageOrder) }
        let sites = FacePattern(d).drilled.map { Site(x: $0.center.x * 1e-3, y: $0.center.y * 1e-3, radius: $0.faceRadius * 1e-3) }
        let mean = sites.reduce(0) { $0 + $1.radius } / Double(max(1, sites.count))
        var a = PlateArray(perPlate: sites.count, plateRadius: d.siteOuterRadius * 1e-3, gap: d.buildChamberHeight * 1e-3,
                           elementRadius: mean, reflection: reflection, imageOrder: imageOrder)
        a.lowerSites = sites; a.upperSites = sites
        return a
    }

    public init(perPlate: Int, plateRadius: Double = 0.205, gap: Double = 0.46,
                elementRadius: Double = 2.5e-3, reflection: Double = 0.9, imageOrder: Int = 3) {
        self.perPlate = perPlate; self.plateRadius = plateRadius; self.gap = gap
        self.elementRadius = elementRadius; self.reflection = reflection; self.imageOrder = imageOrder
    }

    public static let goldenAngle = Double.pi * (3 - 5.0.squareRoot())

    /// Vogel spiral of n points filling a disc of radius R; `rotation` turns it.
    public static func vogel(_ n: Int, radius R: Double, rotation: Double = 0, inner: Double = 0) -> [(x: Double, y: Double)] {
        (0..<n).map { i in
            let r = (inner * inner + (R * R - inner * inner) * (Double(i) + 0.5) / Double(n)).squareRoot()
            let t = Double(i) * goldenAngle + rotation
            return (r * cos(t), r * sin(t))
        }
    }

    public var channels: Int { 2 * perPlate }

    /// All elements: the lower plate (normal +z) then the upper (normal −z),
    /// the upper spiral turned by half the golden angle so no element faces
    /// another exactly. gateIndex = the element's drive channel.
    public func elements() -> [Element] {
        if let lo = lowerSites, let up = upperSites {
            precondition(lo.count == up.count && lo.count == perPlate, "both plates carry perPlate elements")
            var out: [Element] = []
            for (i, s) in lo.enumerated() {
                out.append(Element(position: Vec3(s.x, s.y, 0), normal: Vec3(0, 0, 1), area: Double.pi * s.radius * s.radius,
                                   surface: .lowerCap, gateIndex: i))
            }
            for (i, s) in up.enumerated() {
                out.append(Element(position: Vec3(s.x, s.y, gap), normal: Vec3(0, 0, -1), area: Double.pi * s.radius * s.radius,
                                   surface: .upperCap, gateIndex: perPlate + i))
            }
            return out
        }
        let area = Double.pi * elementRadius * elementRadius
        var out: [Element] = []
        for (i, p) in PlateArray.vogel(perPlate, radius: plateRadius, inner: innerRadius).enumerated() {
            out.append(Element(position: Vec3(p.x, p.y, 0), normal: Vec3(0, 0, 1), area: area,
                               surface: .lowerCap, gateIndex: i))
        }
        for (i, p) in PlateArray.vogel(perPlate, radius: plateRadius, rotation: PlateArray.goldenAngle / 2, inner: innerRadius).enumerated() {
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
