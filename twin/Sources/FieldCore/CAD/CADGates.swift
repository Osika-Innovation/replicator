import Foundation

// MARK: - Point containment (for the interference gate)

/// Ray-parity point-in-solid test with a (y, z) bucket grid, so an
/// interference sweep over a 60k-triangle plate stays interactive.
public struct SolidQuery: Sendable {
    let verts: [Vec3]
    let faces: [SIMD3<Int32>]
    let lo: Vec3, hi: Vec3
    let g: Int
    let cells: [[Int32]]

    public init(_ m: IndexedMesh, grid: Int = 48) {
        verts = m.vertices; faces = m.faces
        let b = m.bounds
        lo = b.min; hi = b.max
        g = grid
        var c = [[Int32]](repeating: [], count: grid * grid)
        let sy = max(hi.y - lo.y, 1e-9), sz = max(hi.z - lo.z, 1e-9)
        for (fi, f) in m.faces.enumerated() {
            let a = m.vertices[Int(f.x)], b = m.vertices[Int(f.y)], cc = m.vertices[Int(f.z)]
            let y0 = min(a.y, b.y, cc.y), y1 = max(a.y, b.y, cc.y)
            let z0 = min(a.z, b.z, cc.z), z1 = max(a.z, b.z, cc.z)
            let iy0 = max(0, min(grid - 1, Int((y0 - lo.y) / sy * Double(grid))))
            let iy1 = max(0, min(grid - 1, Int((y1 - lo.y) / sy * Double(grid))))
            let iz0 = max(0, min(grid - 1, Int((z0 - lo.z) / sz * Double(grid))))
            let iz1 = max(0, min(grid - 1, Int((z1 - lo.z) / sz * Double(grid))))
            for iz in iz0...iz1 { for iy in iy0...iy1 { c[iz * grid + iy].append(Int32(fi)) } }
        }
        cells = c
    }

    public func contains(_ pIn: Vec3) -> Bool {
        // A tiny fixed jitter keeps the ray off shared edges and vertices.
        let p = Vec3(pIn.x, pIn.y + 1.37e-7, pIn.z + 2.11e-7)
        guard p.x <= hi.x, p.y >= lo.y, p.y <= hi.y, p.z >= lo.z, p.z <= hi.z else { return false }
        let sy = max(hi.y - lo.y, 1e-9), sz = max(hi.z - lo.z, 1e-9)
        let iy = max(0, min(g - 1, Int((p.y - lo.y) / sy * Double(g))))
        let iz = max(0, min(g - 1, Int((p.z - lo.z) / sz * Double(g))))
        var n = 0
        for fi in cells[iz * g + iy] {
            let f = faces[Int(fi)]
            let t = Triangle(verts[Int(f.x)], verts[Int(f.y)], verts[Int(f.z)])
            if let x = Voxelizer.rayTriangleX(y: p.y, z: p.z, t: t), x > p.x { n += 1 }
        }
        return n % 2 == 1
    }
}

// MARK: - CAD gates

public enum CADGates {

    /// A design rule: a clearance that must stay at or above `minimum`.
    public struct Rule: Sendable, Codable {
        public var id: String
        public var what: String
        public var clearance: Double
        public var minimum: Double
        public var passed: Bool { clearance >= minimum }
    }

    public static func runAll(_ model: RH1Model, interference: Bool = true) -> [GateResult] {
        var out: [GateResult] = []
        out.append(watertight(model))
        out.append(volumes(model))
        let rules = designRules(model)
        let failed = rules.filter { !$0.passed }
        out.append(GateResult(
            id: "G-CAD3", name: "design-rule clearances (\(rules.count) rules)",
            measured: Double(failed.count), threshold: 0.5,
            detail: failed.isEmpty
                ? "min margin \(fmt(rules.map { $0.clearance - $0.minimum }.min() ?? 0)) mm"
                : failed.map { "\($0.id) \(fmt($0.clearance)) < \(fmt($0.minimum))" }
                    .joined(separator: "; ")))
        if interference { out.append(interferenceGate(model)) }
        out.append(dimensionAudit(model))
        out.append(parastichies(model))
        out.append(horn(model))
        out.append(contentsOf: massAndAreas(model))
        return out
    }

    static func fmt(_ v: Double) -> String { String(format: "%.3g", v) }

    // G-CAD1
    public static func watertight(_ model: RH1Model) -> GateResult {
        var bad: [String] = []
        for p in model.parts {
            let t = p.mesh.topology()
            if !t.isClosed || t.degenerateFaces > 0 || p.volume <= 0 {
                bad.append("\(p.name)[b\(t.boundaryEdges) x\(t.badEdges) d\(t.degenerateFaces) v\(p.volume > 0 ? "+" : "-")]")
            }
        }
        return GateResult(id: "G-CAD1", name: "every part a closed, outward-oriented solid",
                          measured: Double(bad.count), threshold: 0.5,
                          detail: bad.isEmpty ? "\(model.parts.count) parts, \(model.totalTriangles) triangles"
                                              : bad.prefix(6).joined(separator: ", "))
    }

    // G-CAD2
    public static func volumes(_ model: RH1Model) -> GateResult {
        var worst = 0.0, worstName = ""
        var n = 0
        for p in model.parts {
            guard let a = p.analyticVolume, a > 0 else { continue }
            n += 1
            let e = abs(p.volume - a) / a
            if e > worst { worst = e; worstName = p.name }
        }
        return GateResult(id: "G-CAD2", name: "mesh volume vs closed form (\(n) parts)",
                          measured: worst, threshold: 0.01,
                          detail: "worst: \(worstName)")
    }

    // G-CAD3
    public static func designRules(_ model: RH1Model) -> [Rule] {
        let d = model.design
        var r: [Rule] = []
        func rule(_ id: String, _ what: String, _ c: Double, _ m: Double) {
            r.append(Rule(id: id, what: what, clearance: c, minimum: m))
        }
        let wireR = d.windingWireDiameter / 2
        let windEnv = d.torusTubeRadius + d.windingOuterLayerGap + wireR
        rule("DR1", "throat piezo ↔ bore collar",
             d.pztPitchRadius - d.pztDiameter / 2 - d.boreHoleRadius, 0.5)
        rule("DR2", "throat piezos ↔ each other",
             2 * d.pztPitchRadius * sin(Double.pi / 3) - d.pztDiameter, 1.0)
        rule("DR3", "piezo front ↔ horn apex (axial)",
             d.hornThroatDepth - RH1Model.hornProfile(d).map(\.y).max()!, 0.0)
        let topSet = d.torusSetback
        let midSet = d.face("mid-up").backZ - d.middleTorusZ
        rule("DR4", "outer winding ↔ plate back (top/deck)", topSet - windEnv, 2.0)
        rule("DR5", "outer winding ↔ plate back (middle)", midSet - windEnv, 2.0)
        rule("DR6", "outer winding ↔ rim electronics (radial)",
             d.rimInnerRadius - (d.torusMajorRadius + windEnv), 2.0)
        // horn back surface to the winding envelope, in the (r, depth) plane
        var hornGap = Double.infinity
        let cen = P2(d.torusMajorRadius, topSet)
        for p in RH1Model.hornProfile(d) { hornGap = min(hornGap, (p - cen).length - windEnv) }
        rule("DR7", "outer winding ↔ gyroid horn", hornGap, 1.0)
        rule("DR8", "inner ↔ outer winding layer",
             d.windingOuterLayerGap - d.windingInnerLayerGap - 2 * wireR, 0.3)
        rule("DR9", "inner winding ↔ torus former",
             d.windingInnerLayerGap - wireR, 0.3)
        // face pattern
        var web = Double.infinity
        for s in model.pattern.drilled {
            for (li, line) in model.pattern.slotCenterlines.enumerated() {
                let (dist, j) = FacePattern.distance(s.center, to: line)
                web = min(web, dist - model.pattern.slotWidths[li][j] / 2 - s.faceRadius)
            }
        }
        rule("DR10", "micro-horn ↔ slot web", web, d.slotWeb - 1e-9)
        var holeWeb = Double.infinity
        let dr = model.pattern.drilled
        for i in 0..<dr.count {
            for j in (i + 1)..<dr.count {
                let g = (dr[i].center - dr[j].center).length - dr[i].faceRadius - dr[j].faceRadius
                holeWeb = min(holeWeb, g)
            }
        }
        rule("DR11", "micro-horn ↔ micro-horn web", holeWeb, 2.0)
        let siteMax = model.pattern.sites.map { $0.radius + $0.faceRadius }.max() ?? 0
        rule("DR12", "outermost micro-horn ↔ storage liner", d.storageLinerID / 2 - siteMax, 0.5)
        rule("DR13", "slot end ↔ storage liner",
             d.storageLinerID / 2 - (d.slotOuterRadius + d.slotWidthOuter / 2), 1.0)
        // slot arm spacing at the inner end, perpendicular to the arms
        let dphi = 2 * Double.pi / Double(d.slotArms)
        let radialGap = d.slotInnerRadius * (exp(d.slotCotAlpha * dphi) - 1)
        let perp = radialGap * sin(d.slotAlphaDeg * .pi / 180)
        rule("DR14", "slot ↔ neighbouring slot (inner end)", perp - d.slotWidthInner, 1.0)
        // enclosure
        let rearOuter = d.rearGlassOD / 2, frontInner = d.frontGlassOD / 2 - d.glassWall
        rule("DR15", "front glass ↔ rear glass (radial)", frontInner - rearOuter, 2.0)
        rule("DR16", "V-track ↔ rear glass", d.trackRingInner - rearOuter, 0.3)
        rule("DR17", "V-roller ↔ rear glass",
             (d.trackRingInner + d.trackRingOuter) / 2 - d.rollerWidth / 2 - rearOuter, 0.3)
        rule("DR18", "front end-band ↔ V-track", 0.5, 0.3)
        // arcade
        let colOuter = d.columnInnerRadius + d.columnRadial
        rule("DR19", "column ↔ rear glass bore", rearOuter - d.glassWall - colOuter, 1.0)
        rule("DR20", "column ↔ plate rim", d.columnInnerRadius - d.plateRadius, 0.5)
        let tileCorner = (d.tileOuterPlane * d.tileOuterPlane + d.tileHalfWidth * d.tileHalfWidth).squareRoot()
        rule("DR21", "photonic tile ↔ rear glass bore", rearOuter - d.glassWall - tileCorner, 1.0)
        rule("DR22", "photonic tile ↔ plate rim",
             d.tileOuterPlane - d.tileThickness - d.plateRadius, 0.5)
        rule("DR23", "photonic tile ↔ column", tileColumnGap(d), 1.0)
        rule("DR24", "LED ring ↔ column", d.columnInnerRadius - 0.7 - d.ledOuterRadius, 0.5)
        // base
        rule("DR25", "deck winding ↔ cartridge circle",
             d.face("deck").torusZ - windEnv - 300, 5.0)
        return r
    }

    /// Minimum gap between a flat photonic tile and its neighbouring column,
    /// sampled along the tile's end faces.
    static func tileColumnGap(_ d: RH1Design) -> Double {
        let bay = 15.0 * .pi / 180            // tile centre to column centre
        let cr = d.columnInnerRadius + d.columnRadial / 2
        // column rectangle in the tile's frame (x = normal, y = tangential)
        let cc = P2(cr * cos(bay), cr * sin(bay))
        let ur = P2(cos(bay), sin(bay)), ut = P2(-sin(bay), cos(bay))
        let hx = d.columnRadial / 2, hy = d.columnTangential / 2
        var best = Double.infinity
        let x0 = d.tileOuterPlane - d.tileThickness, x1 = d.tileOuterPlane
        for i in 0...40 {
            let x = x0 + (x1 - x0) * Double(i) / 40
            let p = P2(x, d.tileHalfWidth)
            let q = p - cc
            let lx = q.dot(ur), ly = q.dot(ut)
            let dx = max(abs(lx) - hx, 0), dy = max(abs(ly) - hy, 0)
            let inside = abs(lx) <= hx && abs(ly) <= hy
            best = min(best, inside ? -min(hx - abs(lx), hy - abs(ly)) : (dx * dx + dy * dy).squareRoot())
        }
        return best
    }

    // G-CAD3b — sampled interference between neighbouring parts
    public static func interferenceGate(_ model: RH1Model) -> GateResult {
        let found = interference(model)
        return GateResult(id: "G-CAD3b", name: "sampled solid interference, neighbouring parts",
                          measured: Double(found.count), threshold: 0.5,
                          detail: found.isEmpty ? "no part penetrates another"
                              : found.prefix(5).map { "\($0.0) ∩ \($0.1) (\($0.2))" }
                                  .joined(separator: "; "))
    }

    /// Pairs whose surfaces, offset slightly inward, land inside each other.
    /// Touching faces (designed contact) do not count; penetration does.
    public static func interference(_ model: RH1Model, samples: Int = 700,
                                    epsilon: Double = 0.12) -> [(String, String, Int)] {
        let parts = model.parts
        let boxes = parts.map { $0.mesh.bounds }
        var queries: [Int: SolidQuery] = [:]
        func q(_ i: Int) -> SolidQuery {
            if let s = queries[i] { return s }
            let s = SolidQuery(parts[i].mesh)
            queries[i] = s
            return s
        }
        func samplePoints(_ i: Int) -> [Vec3] {
            let m = parts[i].mesh
            let stride = max(1, m.faces.count / samples)
            var pts: [Vec3] = []
            var k = 0
            while k < m.faces.count {
                let f = m.faces[k]
                let a = m.vertices[Int(f.x)], b = m.vertices[Int(f.y)], c = m.vertices[Int(f.z)]
                let n = (b - a).cross(c - a)
                if n.length > 1e-12 {
                    pts.append((a + b + c) / 3 - n.normalized * epsilon)
                }
                k += stride
            }
            return pts
        }
        var hits: [(String, String, Int)] = []
        for i in 0..<parts.count {
            for j in (i + 1)..<parts.count {
                let a = boxes[i], b = boxes[j]
                if a.max.x < b.min.x || b.max.x < a.min.x || a.max.y < b.min.y
                    || b.max.y < a.min.y || a.max.z < b.min.z || b.max.z < a.min.z { continue }
                var n = 0
                for p in samplePoints(i) where q(j).contains(p) { n += 1 }
                for p in samplePoints(j) where q(i).contains(p) { n += 1 }
                if n > 0 { hits.append((parts[i].name, parts[j].name, n)) }
            }
        }
        return hits
    }

    // G-CAD4
    public static func dimensionAudit(_ model: RH1Model) -> GateResult {
        let d = model.design
        func part(_ name: String) -> CADPart? { model.parts.first { $0.name == name } }
        var checks: [(String, Double, Double)] = []   // (what, model, document)
        let bodyParts = model.parts(in: "body").filter { $0.material == .anodized }
        var lo = Vec3(1e9, 1e9, 1e9), hi = Vec3(-1e9, -1e9, -1e9)
        for p in bodyParts {
            let b = p.mesh.bounds
            lo = Vec3(min(lo.x, b.min.x), min(lo.y, b.min.y), min(lo.z, b.min.z))
            hi = Vec3(max(hi.x, b.max.x), max(hi.y, b.max.y), max(hi.z, b.max.z))
        }
        checks.append(("body diameter", hi.x - lo.x, 460))
        checks.append(("overall height", hi.z - lo.z, 1650))
        if let g = part("rear glass (fixed)") {
            let b = g.mesh.bounds
            checks.append(("rear glass OD", 2 * max(abs(b.min.x), abs(b.max.x), b.max.y), 444))
            checks.append(("build chamber floor", b.min.z, 1060))
            checks.append(("build chamber ceiling", b.max.z, 1520))
        }
        if let p = part("face plate top") {
            let b = p.mesh.bounds
            checks.append(("plate diameter", b.max.x - b.min.x, 410))
            checks.append(("top plate", b.min.z, 1520))
        }
        if let p = part("face plate mid-up") { checks.append(("mid plate top", p.mesh.bounds.max.z, 1060)) }
        if let p = part("torus former top") {
            let b = p.mesh.bounds
            checks.append(("torus Ø (outer)", b.max.x - b.min.x, 290 + 60))
            checks.append(("top torus z", (b.min.z + b.max.z) / 2, 1575))
        }
        if let p = part("torus former middle") {
            checks.append(("middle torus z", (p.mesh.bounds.min.z + p.mesh.bounds.max.z) / 2, 998))
        }
        if let p = part("bore collar middle") {
            let v = p.mesh.vertices.map { ($0.x * $0.x + $0.y * $0.y).squareRoot() }
            checks.append(("clear bore Ø", 2 * (v.min() ?? 0), 12))
        }
        checks.append(("horn mouth Ø", 2 * d.mouthRadius, 404))
        checks.append(("horn throat Ø", 2 * d.throatRadius, 36))
        var worst = 0.0, worstWhat = ""
        for (w, m, doc) in checks {
            let e = abs(m - doc)
            if e > worst { worst = e; worstWhat = "\(w) \(String(format: "%.2f", m)) vs \(doc)" }
        }
        return GateResult(id: "G-CAD4", name: "dimension audit vs spec/site (\(checks.count) checks)",
                          measured: worst, threshold: 0.1,
                          detail: worst == 0 ? "exact" : "worst: \(worstWhat)")
    }

    // G-CAD5 — the paper's own claim, checked on the generated field
    /// Dominant nearest-neighbour index offsets (= parastichy numbers) in
    /// three equal-count radial bands, inner to outer.
    public static func parastichyBands(_ model: RH1Model) -> [[(Int, Int)]] {
        let s = model.pattern.sites.sorted { $0.radius < $1.radius }
        let n = s.count
        var bands: [[(Int, Int)]] = []
        for b in 0..<3 {
            var hist: [Int: Int] = [:]
            for a in s[(b * n / 3)..<((b + 1) * n / 3)] {
                var near: [(Double, Int)] = []
                for c in s where c.index != a.index {
                    near.append(((a.center - c.center).length, abs(a.index - c.index)))
                }
                near.sort { $0.0 < $1.0 }
                for k in 0..<min(2, near.count) { hist[near[k].1, default: 0] += 1 }
            }
            bands.append(hist.sorted { $0.value > $1.value }.map { ($0.key, $0.value) })
        }
        return bands
    }

    public static func parastichies(_ model: RH1Model) -> GateResult {
        let bands = parastichyBands(model)
        let pairs = bands.map { b -> String in
            let t = b.prefix(2).map(\.0).sorted()
            return t.map(String.init).joined(separator: "×")
        }
        let present = bands.contains { Set($0.prefix(2).map(\.0)) == Set([21, 34]) }
        return GateResult(id: "G-CAD5", name: "21 × 34 parastichies present (mech §3c claim)",
                          measured: present ? 0 : 1, threshold: 0.5,
                          detail: "dominant pair by band, inner → outer: " + pairs.joined(separator: ", ")
                              + " — the rim reads the next Fibonacci pair")
    }

    // G-CAD6
    public static func horn(_ model: RH1Model) -> GateResult {
        let d = model.design
        let arc = d.hornArcLength
        return GateResult(id: "G-CAD6", name: "horn meridian arc length (mech §3c: ≈187 mm)",
                          measured: abs(arc - 187), threshold: 1.0,
                          detail: String(format: "arc %.2f mm, mouth:throat %.1f:1, fold %.1f:1",
                                         arc, d.mouthRadius / d.throatRadius,
                                         arc / d.hornThroatDepth))
    }

    // G-CAD7/8 — informational: the mass budget and the acoustic open area
    public static func massAndAreas(_ model: RH1Model) -> [GateResult] {
        func mass(_ f: (CADPart) -> Bool) -> Double {
            model.parts.filter(f).compactMap(\.massKg).reduce(0, +)
        }
        let shells = mass { $0.assembly == "body" && $0.material == .anodized }
            + mass { $0.name == "storage chamber liner" }
        let plates = mass { $0.name.hasPrefix("face plate") || $0.name.hasPrefix("carrier ring") }
        let glass = mass { $0.material == .glass }
        let total = mass { _ in true }
        let pat = model.pattern
        let slotA = Double(model.design.slotArms) * pat.slotArea
        return [
            GateResult(id: "G-CAD7", name: "mass budget (spec §3: ≈50 kg class)",
                       measured: total, threshold: 0, comparison: .informational,
                       detail: String(format: "shells %.1f kg (spec ~20), plates+carriers %.1f (spec ~15, 3 plates), glass %.1f (spec ~6.5); placeholders not counted",
                                      shells, plates, glass)),
            GateResult(id: "G-CAD8", name: "acoustic open area per face, slots vs micro-horns",
                       measured: slotA / max(pat.perforationFaceArea, 1e-9), threshold: 0,
                       comparison: .informational,
                       detail: String(format: "%d micro-horns drilled, %d left to slot voids; slots %.0f mm², micro-horn faces %.0f mm², throats %.0f mm²",
                                      pat.drilled.count, pat.subsumedCount, slotA,
                                      pat.perforationFaceArea, pat.perforationThroatArea)),
        ]
    }
}
