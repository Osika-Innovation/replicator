import Foundation

/// Prototype P0 as solids: what is printed, what is bought, where it sits.
/// z = 0 is the lower plate's top; the lower cans' faces are at `canHeight`.
public struct P0Model: Sendable {
    public var design: P0Design
    public var parts: [CADPart] = []

    public init(_ d: P0Design = P0Design()) {
        design = d
        func add(_ name: String, _ mat: CADMaterial, _ mesh: IndexedMesh, _ note: String, _ volume: Double?) {
            parts.append(CADPart(name: name, assembly: "p0", material: mat, mesh: mesh, register: .assumed, note: note, analyticVolume: volume))
        }
        func circle(_ x: Double, _ y: Double, _ dia: Double) -> [P2] { Solid.circle(P2(x, y), dia / 2, segments: dia < 2 ? 12 : 48) }
        func ngonArea(_ dia: Double) -> Double { let n = dia < 2 ? 12.0 : 48.0; return n / 2 * sin(2 * Double.pi / n) * dia * dia / 4 }
        let h = d.plateSize / 2, r = d.rodSquare / 2
        let rods = [(-r, -r), (r, -r), (r, r), (-r, r)]
        // ---- aperture plate: rod holes and two pin holes per can ----
        var holes = rods.map { circle($0.0, $0.1, d.rodHole) }
        for s in d.sites { for dx in [-d.pinPitch / 2, d.pinPitch / 2] { holes.append(circle(s.x + dx, s.y, d.pinHole)) } }
        let square = [P2(-h, -h), P2(h, -h), P2(h, h), P2(-h, h)]
        let plateVolume = (d.plateSize * d.plateSize - 4 * ngonArea(d.rodHole) - Double(2 * d.perPlate) * ngonArea(d.pinHole)) * d.plateThickness
        let plate = Solid.extrude(outer: square, holes: holes, z0: -d.plateThickness, z1: 0)
        let note = "printed PETG, \(Int(d.plateSize)) × \(Int(d.plateSize)) × \(Int(d.plateThickness)); \(2 * d.perPlate) pin holes Ø\(d.pinHole), 4 rod holes Ø\(d.rodHole)"
        add("aperture plate lower", .polymer, plate, note, plateVolume)
        add("aperture plate upper", .polymer, plate.mirroredZ(about: d.plateSpacing / 2), note + "; the same print, turned over", plateVolume)
        // ---- the cans ----
        var lower = IndexedMesh(), upper = IndexedMesh()
        for s in d.sites {
            lower.append(Solid.extrude(outer: circle(s.x, s.y, d.canDiameter), z0: 0, z1: d.canHeight))
            upper.append(Solid.extrude(outer: circle(s.x, s.y, d.canDiameter), z0: d.plateSpacing - d.canHeight, z1: d.plateSpacing))
        }
        let cans = Double(d.perPlate) * ngonArea(d.canDiameter) * d.canHeight
        add("transmitters lower", .transmitter, lower, "\(d.perPlate) × 40 kHz open type, pins through the plate", cans)
        add("transmitters upper", .transmitter, upper, "\(d.perPlate) × 40 kHz open type", cans)
        // ---- rods ----
        for (i, c) in rods.enumerated() {
            add("rod \(i + 1)", .columnMetal, Solid.extrude(outer: circle(c.0, c.1, d.rodDiameter), z0: -40, z1: d.rodLength - 40),
                "bought: M4 threaded rod, \(Int(d.rodLength)) long; nuts above and below each plate set the gap", ngonArea(d.rodDiameter) * d.rodLength)
        }
        // ---- the probe bar, face down: receiver's face on the mid-plane ----
        let mid = d.plateSpacing / 2, bl = d.barLength / 2, bw = d.barWidth / 2, rr = r * 2.0.squareRoot()
        var barHoles = [circle(-rr, 0, d.rodHole), circle(rr, 0, d.rodHole)]
        for dx in [-d.pinPitch / 2, d.pinPitch / 2] { barHoles.append(circle(dx, 0, d.pinHole)) }
        let barVolume = (4 * bl * bw - 2 * ngonArea(d.rodHole) - 2 * ngonArea(d.pinHole)) * d.plateThickness
        let bar = Solid.extrude(outer: [P2(-bl, -bw), P2(bl, -bw), P2(bl, bw), P2(-bl, bw)], holes: barHoles,
                                z0: mid + d.canHeight, z1: mid + d.canHeight + d.plateThickness).rotatedZ(45)
        add("probe bar", .polymer, bar, "printed PETG; across two diagonal rods, removed after calibration", barVolume)
        add("probe receiver", .transmitter, Solid.extrude(outer: circle(0, 0, d.canDiameter), z0: mid, z1: mid + d.canHeight),
            "bought: 40 kHz open-type receiver, face on the mid-plane", ngonArea(d.canDiameter) * d.canHeight)
        // ---- side cradle: for the reference pass the receiver lies on its side,
        // its axis on the mid-plane, in a groove on the bar turned over (bar top at mid − canHeight).
        let barTop = mid - d.canHeight, grooveR = d.canDiameter / 2 + 0.1, lip = 3.0, top = 5.0
        var profile = [P2(-bw - 2, -lip), P2(-bw, -lip), P2(-bw, 0), P2(bw, 0), P2(bw, -lip), P2(bw + 2, -lip), P2(bw + 2, top)]
        let a0 = -asin((d.canHeight - top) / grooveR)
        for q in 0...24 {
            let t = a0 + (-Double.pi - 2 * a0) * Double(q) / 24
            profile.append(P2(grooveR * cos(t), d.canHeight + grooveR * sin(t)))
        }
        profile.append(P2(-bw - 2, top))
        let cradle = Solid.extrude(outer: profile, z0: -7, z1: 7).transformed { Vec3($0.z, $0.x, $0.y + barTop) }.rotatedZ(45)
        add("side cradle", .polymer, cradle,
            "printed PETG; sits over the turned bar and holds the receiver on its side, axis on the mid-plane, for the reference pass", abs(signedArea(profile)) * 14)
        for (i, sx) in [-rr, rr].enumerated() {
            let c = P2(sx * cos(Double.pi / 4), sx * sin(Double.pi / 4))
            add("flip spacer \(i + 1)", .polymer,
                Solid.extrude(outer: circle(c.x, c.y, 12), holes: [circle(c.x, c.y, d.rodHole)], z0: mid + d.canHeight - d.flipSpacer, z1: mid + d.canHeight),
                "printed PETG, \(String(format: "%.1f", d.flipSpacer)) tall: under the bar when the receiver faces down; without them, turned over, it faces up from the same point",
                (ngonArea(12) - ngonArea(d.rodHole)) * d.flipSpacer)
        }
    }

    /// Fit checks (mm of clearance, minimum): what must hold for the parts to go together.
    public var fits: [(what: String, clearance: Double, minimum: Double)] {
        let d = design
        let edge = d.pitch * Double(d.side - 1) / 2 + d.canDiameter / 2 + 0.15
        return [
            ("can ↔ can (largest cans, Ø\(d.canDiameter + 0.3))", d.pitch - d.canDiameter - 0.3, 0.2),
            ("pin left behind the plate for a jumper socket", 10.0 - d.plateThickness, 6.0),
            ("pin hole ↔ pin hole of neighbouring cans (socket housings 2.54 wide)", d.pitch - d.pinPitch, 2.6),
            ("array edge ↔ rod", d.rodSquare / 2 - d.rodDiameter / 2 - edge, 10),
            ("rod hole ↔ plate edge", d.plateSize / 2 - d.rodSquare / 2 - d.rodHole / 2, 5),
            ("probe bar ↔ lower cans' faces (receiver facing down)", d.gap / 2, 5),
            ("probe bar, turned over ↔ upper cans' faces", d.gap / 2 - d.canHeight - d.plateThickness, 5),
            ("rod length left for nuts and feet", d.rodLength - d.plateSpacing - 2 * d.plateThickness, 60),
            ("side cradle: floor under the receiver", d.canHeight - d.canDiameter / 2 - 0.1, 1.5),
            ("receiver on its side ↔ either plate's cans", d.gap / 2 - d.canDiameter / 2, 10),
        ]
    }
}
