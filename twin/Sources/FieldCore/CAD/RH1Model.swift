import Foundation

// MARK: - Materials

public enum CADMaterial: String, Codable, CaseIterable, Sendable {
    case anodized, plateMetal, columnMetal, ceramic, copper, bronze, pzt,
         glass, photonic, former, fr4, polymer, emissive, placeholder, transmitter

    public var label: String {
        switch self {
        case .anodized:    return "Al 6063, champagne anodized"
        case .plateMetal:  return "Al 6082, dark machined"
        case .columnMetal: return "Al 6063, dark anodized"
        case .ceramic:     return "Graded ceramic gyroid (alumina, ρ_rel 0.25)"
        case .copper:      return "Copper"
        case .bronze:      return "Phosphor bronze"
        case .pzt:         return "PZT-8, silvered"
        case .glass:       return "Low-iron laminated glass, ITO-class coat"
        case .photonic:    return "Laminated glass tile, metal-mesh hologram"
        case .former:      return "Torus former, glass-filled PEEK"
        case .fr4:         return "FR4 + electronics"
        case .polymer:     return "POM"
        case .emissive:    return "LED strip"
        case .placeholder: return "Envelope only (not specified)"
        case .transmitter: return "Open-type ultrasonic transmitter (Al can)"
        }
    }

    /// kg/m³ as the part is built (the gyroid at its relative density).
    public var density: Double {
        switch self {
        case .anodized, .plateMetal, .columnMetal: return 2700
        case .ceramic: return 3950 * 0.25
        case .copper: return 8960
        case .bronze: return 8800
        case .pzt: return 7600
        case .glass, .photonic: return 2500
        case .former: return 1500
        case .fr4, .emissive: return 1850
        case .polymer: return 1410
        case .placeholder: return 0
        case .transmitter: return 1280          // a 0.7 g Ø9.9 × 7.1 can
        }
    }

    /// Display colour, linear-ish RGB + alpha (spec §8 finishes).
    public var rgba: (Double, Double, Double, Double) {
        switch self {
        case .anodized:    return (0.80, 0.73, 0.60, 1)
        case .plateMetal:  return (0.19, 0.20, 0.22, 1)
        case .columnMetal: return (0.14, 0.14, 0.16, 1)
        case .ceramic:     return (0.80, 0.75, 0.64, 1)
        case .copper:      return (0.86, 0.47, 0.27, 1)
        case .bronze:      return (0.66, 0.50, 0.26, 1)
        case .pzt:         return (0.74, 0.75, 0.78, 1)
        case .glass:       return (0.78, 0.90, 0.88, 0.16)
        case .photonic:    return (0.42, 0.66, 0.72, 0.42)
        case .former:      return (0.16, 0.15, 0.14, 1)
        case .fr4:         return (0.16, 0.30, 0.20, 1)
        case .polymer:     return (0.10, 0.10, 0.11, 1)
        case .emissive:    return (1.00, 0.94, 0.82, 1)
        case .placeholder: return (0.46, 0.48, 0.52, 0.55)
        case .transmitter: return (0.70, 0.71, 0.73, 1)
        }
    }
    public var specular: Double {
        switch self {
        case .copper, .bronze, .glass, .photonic: return 0.9
        case .plateMetal, .pzt, .transmitter: return 0.6
        case .anodized, .columnMetal: return 0.35
        default: return 0.12
        }
    }
    public var shininess: Double {
        switch self {
        case .glass, .photonic: return 96
        case .copper, .bronze: return 56
        case .plateMetal, .pzt, .transmitter: return 40
        case .anodized, .columnMetal: return 22
        default: return 8
        }
    }
    public var emission: Double { self == .emissive ? 1 : 0 }
    public var isTransparent: Bool { rgba.3 < 0.99 }
}

// MARK: - Parts

public struct CADPart: Sendable {
    public var name: String
    public var assembly: String
    public var material: CADMaterial
    public var mesh: IndexedMesh
    public var register: RH1Design.Register
    public var note: String
    /// Closed-form volume (mm³) where one exists — gate G-CAD2 compares it
    /// with the mesh's divergence-theorem volume.
    public var analyticVolume: Double?
    public var moving: Bool = false

    public var volume: Double { mesh.signedVolume }
    public var massKg: Double? {
        material == .placeholder ? nil : abs(volume) * 1e-9 * material.density
    }
}

// MARK: - The plate-face pattern

/// The shared world-frame pattern of all four radiating faces: a golden-angle
/// sunflower of biconical micro-horns (sound) crossed by twelve equiangular
/// spiral slots (light). Built from `RH1Design`, used by the plate solids, the
/// drawing, the gates and the plate-primary physics preset.
public struct FacePattern: Sendable {
    public struct Site: Sendable {
        public var index: Int              // 1-based Vogel index
        public var center: P2
        public var radius: Double          // distance from the axis
        public var faceRadius: Double
        public var throatRadius: Double
        public var subsumed: Bool          // falls inside a slot's clearance
    }
    /// One driven element (element-array face): its hole through the plate.
    public struct ElementSite: Sendable {
        public var index: Int              // 0-based: the engine's channel on its plate
        public var center: P2
        public var radius: Double          // distance from the axis
        public var pistonRadius: Double
        public var holeRadius: Double
        /// Which of the plate's tones it is tuned to; nil = broadband.
        public var tone: Int? = nil
    }
    /// The driven elements (empty on the v0.4 micro-horn face).
    public var elements: [ElementSite] = []
    public var sites: [Site]
    public var slotCenterlines: [[P2]]
    public var slotWidths: [[Double]]
    public var slotOutlines: [[P2]]

    public var drilled: [Site] { sites.filter { !$0.subsumed } }
    public var subsumedCount: Int { sites.filter(\.subsumed).count }

    public static let goldenAngle = Double.pi * (3 - 5.0.squareRoot())   // 137.508°

    /// `rotation` turns the element spiral (radians): 0 on up-facing faces,
    /// half a golden angle on down-facing ones, as the engine's two plates.
    public init(_ d: RH1Design, rotation: Double = 0, slotSamples: Int = 200, capSegments: Int = 8) {
        self = d.faceStyle == .elementArray
            ? FacePattern(elementFace: d, rotation: rotation, slotSamples: slotSamples, capSegments: capSegments)
            : FacePattern(microHornFace: d, slotSamples: slotSamples, capSegments: capSegments)
    }

    /// The v0.4 face: 380-site micro-horn sunflower and twelve unbroken slots.
    init(microHornFace d: RH1Design, slotSamples: Int, capSegments: Int) {
        // Slots. World frame seen from +z: arms wind clockwise outward, which
        // is how site FIG. 2 draws an up-facing face seen from its front.
        var lines: [[P2]] = [], widths: [[Double]] = [], outlines: [[P2]] = []
        let cotA = d.slotCotAlpha
        let sweep = d.slotSweepRad
        for k in 0..<d.slotArms {
            let phi0 = 2 * Double.pi * Double(k) / Double(d.slotArms)
            var c: [P2] = [], w: [Double] = []
            for i in 0...slotSamples {
                let s = Double(i) / Double(slotSamples)
                let r = d.slotInnerRadius * exp(cotA * sweep * s)
                let phi = phi0 - sweep * s
                c.append(P2(r * cos(phi), r * sin(phi)))
                let f = (r - d.slotInnerRadius) / (d.slotOuterRadius - d.slotInnerRadius)
                w.append(d.slotWidthInner + (d.slotWidthOuter - d.slotWidthInner) * f)
            }
            lines.append(c); widths.append(w)
            outlines.append(FacePattern.slotOutline(c, w, capSegments: capSegments))
        }
        slotCenterlines = lines; slotWidths = widths; slotOutlines = outlines

        // Which sites a slot swallows is a DESIGN fact and must not depend on
        // how finely the outline is tessellated for display, so it is decided
        // against a fixed fine centreline (0.1 mm-class chords), not `lines`.
        let fine = FacePattern.centerlines(d, samples: 2400)

        // Sunflower: equal-area annulus Vogel spiral, same (clockwise) sense.
        var s: [Site] = []
        let n = d.siteCount
        let a2 = d.siteInnerRadius * d.siteInnerRadius
        let b2 = d.siteOuterRadius * d.siteOuterRadius
        for i in 1...n {
            let r = (a2 + (b2 - a2) * (Double(i) - 0.5) / Double(n)).squareRoot()
            let t = -Double(i) * FacePattern.goldenAngle
            let c = P2(r * cos(t), r * sin(t))
            let fr = d.holeFaceA + d.holeFaceB * r
            var sub = false
            for (line, w) in fine {
                let (dist, j) = FacePattern.distance(c, to: line)
                if dist < w[j] / 2 + fr + d.slotWeb { sub = true; break }
            }
            s.append(Site(index: i, center: c, radius: r, faceRadius: fr,
                          throatRadius: fr * d.holeThroatRatio, subsumed: sub))
        }
        sites = s
    }

    /// Slot centrelines and widths at a given sampling.
    static func centerlines(_ d: RH1Design, samples: Int) -> [([P2], [Double])] {
        let cotA = d.slotCotAlpha, sweep = d.slotSweepRad
        return (0..<d.slotArms).map { k in
            let phi0 = 2 * Double.pi * Double(k) / Double(d.slotArms)
            var c: [P2] = [], w: [Double] = []
            for i in 0...samples {
                let s = Double(i) / Double(samples)
                let r = d.slotInnerRadius * exp(cotA * sweep * s)
                let phi = phi0 - sweep * s
                c.append(P2(r * cos(phi), r * sin(phi)))
                let f = (r - d.slotInnerRadius) / (d.slotOuterRadius - d.slotInnerRadius)
                w.append(d.slotWidthInner + (d.slotWidthOuter - d.slotWidthInner) * f)
            }
            return (c, w)
        }
    }

    /// Slot outline with round (end-mill) ends, clockwise.
    static func slotOutline(_ c: [P2], _ w: [Double], capSegments: Int) -> [P2] {
        let n = c.count
        var normals: [P2] = []
        for i in 0..<n {
            let t = (c[min(n - 1, i + 1)] - c[max(0, i - 1)]).normalized
            normals.append(P2(-t.y, t.x))
        }
        var left: [P2] = [], right: [P2] = []
        for i in 0..<n {
            left.append(c[i] + normals[i] * (w[i] / 2))
            right.append(c[i] - normals[i] * (w[i] / 2))
        }
        var out = left
        // end cap around c[n-1], from left normal through forward to right
        let tEnd = P2(normals[n - 1].y, -normals[n - 1].x)
        for k in 1..<capSegments {
            let a = Double.pi * Double(k) / Double(capSegments)
            let dir = normals[n - 1] * cos(a) + tEnd * sin(a)
            out.append(c[n - 1] + dir * (w[n - 1] / 2))
        }
        out.append(contentsOf: right.reversed())
        let tStart = P2(-normals[0].y, normals[0].x)
        for k in 1..<capSegments {
            let a = Double.pi * Double(k) / Double(capSegments)
            let dir = normals[0] * (-cos(a)) + tStart * sin(a)
            out.append(c[0] + dir * (w[0] / 2))
        }
        return signedArea(out) > 0 ? out.reversed() : out
    }

    /// Distance from a point to a polyline, and the nearest vertex index.
    static func distance(_ p: P2, to line: [P2]) -> (Double, Int) {
        var best = Double.infinity, bi = 0
        for i in 0..<(line.count - 1) {
            let a = line[i], b = line[i + 1]
            let ab = b - a
            let t = max(0, min(1, (p - a).dot(ab) / max(ab.dot(ab), 1e-18)))
            let q = a + ab * t
            let dd = (p - q).length
            if dd < best { best = dd; bi = t < 0.5 ? i : i + 1 }
        }
        return (best, bi)
    }

    /// The element-array face: the engine's Vogel spiral, and each slot arm
    /// cut into the dashes that keep `elementSlotWeb` of metal round every
    /// element hole. Where a dash starts and stops is decided on a fixed fine
    /// centreline, so it does not depend on the display tessellation.
    init(elementFace d: RH1Design, rotation: Double, slotSamples: Int, capSegments: Int) {
        // The engine's own sites (lower plate for an up-facing face, upper
        // for a down-facing one), so the CAD cannot place or size an element
        // differently from the array the field is computed for.
        let arr = PlateArray.rh1(d)
        let upper = rotation != 0
        elements = arr.elements().filter { ($0.surface == .upperCap) == upper }.map { e in
            let ch = e.gateIndex, i = ch - (upper ? arr.perPlate : 0)
            let c = P2(e.position.x * 1e3, e.position.y * 1e3), r = arr.pistonRadius(ch) * 1e3
            return ElementSite(index: i, center: c, radius: (c.x * c.x + c.y * c.y).squareRoot(),
                               pistonRadius: r, holeRadius: r + d.elementHoleClearance, tone: arr.toneOf?[ch])
        }
        sites = []
        var lines: [[P2]] = [], widths: [[Double]] = [], outlines: [[P2]] = []
        let fineN = 2400
        let step = max(1, fineN / max(1, slotSamples))
        for (line, w) in FacePattern.centerlines(d, samples: fineN) {
            var blocked = [Bool](repeating: false, count: line.count)
            for i in 0..<line.count {
                let keep = w[i] / 2 + d.elementSlotWeb
                for e in elements where (e.center - line[i]).length < keep + e.holeRadius { blocked[i] = true; break }
            }
            // A dash ends in a round cap of radius w/2 beyond its last sample.
            // Pull every dash end back by w/2 + half a web from the blocked
            // stretch, so the cap stays where the straight slot was allowed
            // and two dashes either side of one element never touch.
            var arc = [Double](repeating: 0, count: line.count)
            for k in 1..<line.count { arc[k] = arc[k - 1] + (line[k] - line[k - 1]).length }
            let near = blocked
            var last = -Double.infinity
            for k in 0..<line.count {
                if near[k] { last = arc[k] }
                if arc[k] - last <= w[k] / 2 + d.elementSlotWeb / 2 { blocked[k] = true }
            }
            last = Double.infinity
            for k in stride(from: line.count - 1, through: 0, by: -1) {
                if near[k] { last = arc[k] }
                if last - arc[k] <= w[k] / 2 + d.elementSlotWeb / 2 { blocked[k] = true }
            }
            var i = 0
            while i < line.count {
                guard !blocked[i] else { i += 1; continue }
                var j = i
                while j + 1 < line.count, !blocked[j + 1] { j += 1 }
                var length = 0.0
                for k in i..<j { length += (line[k + 1] - line[k]).length }
                if length >= d.slotMinDash {
                    var idx = Array(stride(from: i, to: j, by: step))
                    idx.append(j)
                    let c = idx.map { line[$0] }, ww = idx.map { w[$0] }
                    lines.append(c); widths.append(ww)
                    outlines.append(FacePattern.slotOutline(c, ww, capSegments: capSegments))
                }
                i = j + 1
            }
        }
        slotCenterlines = lines; slotWidths = widths; slotOutlines = outlines
    }

    /// Arc length of the slots: one arm on the v0.4 face, every dash summed
    /// and divided by the arm count on the element face (mean cut per arm).
    public var slotLength: Double {
        var s = 0.0
        for c in slotCenterlines { for i in 1..<c.count { s += (c[i] - c[i - 1]).length } }
        return s / Double(max(1, slotArmCount))
    }
    var slotArmCount: Int { elements.isEmpty ? slotCenterlines.count : 12 }

    /// Open area of every slot piece on the face, by quadrature along the
    /// centrelines plus the round ends.
    public var slotOpenArea: Double {
        var a = 0.0
        for (c, w) in zip(slotCenterlines, slotWidths) {
            for i in 1..<c.count { a += (c[i] - c[i - 1]).length * (w[i] + w[i - 1]) / 2 }
            a += Double.pi / 8 * (w[0] * w[0] + w[w.count - 1] * w[w.count - 1])
        }
        return a
    }
    /// The elements' face diameters as text: "Ø5" or "Ø4.1–7.5".
    public var elementSizeText: String {
        let s = elements.map { 2 * $0.pistonRadius }
        guard let lo = s.min(), let hi = s.max() else { return "" }
        return hi - lo < 0.05 ? String(format: "Ø%g", lo) : String(format: "Ø%.1f–%.1f", lo, hi)
    }
    /// Radiating area of the driven elements.
    public var elementArea: Double { elements.reduce(0) { $0 + Double.pi * $1.pistonRadius * $1.pistonRadius } }

    /// Open area of one slot by quadrature along the centreline (independent
    /// of the outline polygon): ∫ w ds + the two half-disc ends.
    public var slotArea: Double {
        guard let c = slotCenterlines.first, let w = slotWidths.first else { return 0 }
        var a = 0.0
        for i in 1..<c.count { a += (c[i] - c[i - 1]).length * (w[i] + w[i - 1]) / 2 }
        a += Double.pi / 8 * (w[0] * w[0] + w[w.count - 1] * w[w.count - 1])
        return a
    }

    /// Open (face-opening) area of the drilled micro-horns.
    public var perforationFaceArea: Double {
        drilled.reduce(0) { $0 + Double.pi * $1.faceRadius * $1.faceRadius }
    }
    /// Throat (narrowest) area of the drilled micro-horns.
    public var perforationThroatArea: Double {
        drilled.reduce(0) { $0 + Double.pi * $1.throatRadius * $1.throatRadius }
    }
}

// MARK: - The model

public struct RH1Model: Sendable {
    public enum Detail: String, Sendable { case preview, standard, fine }

    public var design: RH1Design
    /// The face pattern of up-facing faces (and of every face on the v0.4
    /// micro-horn design, where all four share one world-frame pattern).
    public var pattern: FacePattern
    /// Down-facing faces: the element spiral turned half a golden angle.
    public var patternDown: FacePattern
    public func pattern(for face: RH1Design.Face) -> FacePattern { face.facing == .down ? patternDown : pattern }
    public var parts: [CADPart]
    public var detail: Detail

    public init(design d: RH1Design = RH1Design(), detail: Detail = .standard) {
        design = d
        self.detail = detail
        let slotSamples = detail == .preview ? 90 : (detail == .fine ? 320 : 200)
        pattern = FacePattern(d, slotSamples: slotSamples)
        patternDown = d.faceStyle == .elementArray
            ? FacePattern(d, rotation: PlateArray.goldenAngle / 2, slotSamples: slotSamples) : pattern
        parts = RH1Model.build(d, pattern, patternDown, detail)
    }

    public var assemblies: [String] {
        var seen: [String] = []
        for p in parts where !seen.contains(p.assembly) { seen.append(p.assembly) }
        return seen
    }

    public func parts(in assembly: String) -> [CADPart] {
        parts.filter { $0.assembly == assembly }
    }

    public var totalTriangles: Int { parts.reduce(0) { $0 + $1.mesh.triangleCount } }

    // MARK: build

    static func build(_ d: RH1Design, _ pat: FacePattern, _ patDown: FacePattern, _ detail: Detail) -> [CADPart] {
        var parts: [CADPart] = []
        let tol = detail == .preview ? 0.25 : (detail == .fine ? 0.02 : 0.06)
        func seg(_ r: Double, _ sweep: Double = 360) -> Int {
            Solid.segments(radius: r, sweepDeg: sweep, tol: tol)
        }
        func tubeV(_ r0: Double, _ r1: Double, _ z0: Double, _ z1: Double,
                   _ sweep: Double = 360) -> Double {
            Double.pi * (r1 * r1 - r0 * r0) * (z1 - z0) * sweep / 360
        }
        func add(_ name: String, _ asm: String, _ mat: CADMaterial, _ mesh: IndexedMesh,
                 _ reg: RH1Design.Register, _ note: String, _ vol: Double? = nil,
                 moving: Bool = false) {
            parts.append(CADPart(name: name, assembly: asm, material: mat, mesh: mesh,
                                 register: reg, note: note, analyticVolume: vol,
                                 moving: moving))
        }
        let R = d.bodyRadius, Ri = d.shellInnerRadius

        // ---- body shells ------------------------------------------------
        add("bottom closure", "body", .anodized,
            Solid.tube(r0: 0, r1: R, z0: 0, z1: d.shellWall, segments: seg(R)),
            .committed, "spec §3", tubeV(0, R, 0, d.shellWall))
        add("lower body tube", "body", .anodized,
            Solid.tube(r0: Ri, r1: R, z0: d.shellWall, z1: d.lowerBodyTop, segments: seg(R)),
            .committed, "spec §3 — one piece, 0–1060", tubeV(Ri, R, d.shellWall, d.lowerBodyTop))
        add("top band", "body", .anodized,
            Solid.tube(r0: Ri, r1: R, z0: d.chamberCeiling, z1: d.topBandTop, segments: seg(R)),
            .committed, ".blend R2_Shell_TopBand", tubeV(Ri, R, d.chamberCeiling, d.topBandTop))
        let capZ = d.overallHeight - d.crownCapThickness
        add("crown", "body", .anodized,
            Solid.tube(r0: Ri, r1: R, z0: d.topBandTop, z1: capZ, segments: seg(R)),
            .committed, ".blend R2_Shell_Crown", tubeV(Ri, R, d.topBandTop, capZ))
        add("crown cap", "body", .anodized,
            Solid.tube(r0: 0, r1: R, z0: capZ, z1: d.overallHeight, segments: seg(R)),
            .committed, ".blend R2_Shell_CrownTop", tubeV(0, R, capZ, d.overallHeight))
        let liR0 = d.storageLinerID / 2, liR1 = liR0 + d.storageLinerWall
        add("storage chamber liner", "storage", .anodized,
            Solid.tube(r0: liR0, r1: liR1, z0: d.storageFloor, z1: d.storageCeiling,
                       segments: seg(liR1)),
            .resolved, "Ø400 per spec §3; height per site FIG.1",
            tubeV(liR0, liR1, d.storageFloor, d.storageCeiling))

        // ---- the four radiating faces ----------------------------------
        // Inside the 12 mm envelope: the metal plate, and (resonant elements)
        // the wiring board on its back. Built with the radiating face at the
        // top for an up-facing face, at the bottom for a down-facing one.
        let tb = d.plateThickness - d.facePlateThickness
        let plateUp = RH1Model.plateSolid(d, pat, detail: detail, z0: tb, z1: d.plateThickness)
        let plateDown = d.faceStyle == .elementArray
            ? RH1Model.plateSolid(d, patDown, detail: detail, z0: 0, z1: d.facePlateThickness) : plateUp
        var boardPat = pat, boardPatDown = patDown
        boardPat.elements = []; boardPatDown.elements = []
        let boardUp = tb > 0 ? RH1Model.plateSolid(d, boardPat, detail: detail, z0: 0, z1: tb) : nil
        let boardDown = tb > 0 ? RH1Model.plateSolid(d, boardPatDown, detail: detail, z0: d.facePlateThickness, z1: d.plateThickness) : nil
        let hornProfile = RH1Model.hornProfile(d)
        let hornVol = RH1Model.profileRevolvedVolume(hornProfile)
        let coneProfile = RH1Model.coneProfile(d)
        let coneVol = RH1Model.profileRevolvedVolume(coneProfile)
        for f in d.faces {
            let asm = "plate.\(f.id)"
            let zlo = min(f.faceZ, f.backZ), zhi = max(f.faceZ, f.backZ)
            let fp = f.facing == .down ? patDown : pat
            add("face plate \(f.id)", asm, .plateMetal, (f.facing == .down ? plateDown : plateUp).translated(Vec3(0, 0, zlo)),
                d.faceStyle == .elementArray ? .resolved : .committed,
                d.faceStyle == .elementArray
                    ? "Ø\(Int(d.plateDiameter))×\(String(format: "%g", d.facePlateThickness)), \(fp.elements.count) element holes Ø\(String(format: "%.1f–%.1f", 2 * (fp.elements.map(\.holeRadius).min() ?? 0), 2 * (fp.elements.map(\.holeRadius).max() ?? 0))) + \(fp.slotCenterlines.count) slot dashes on \(d.slotArms) arms, faces \(f.facing.rawValue)"
                    : "Ø\(Int(d.plateDiameter))×\(Int(d.plateThickness)), \(pat.drilled.count) micro-horns + \(d.slotArms) slots, faces \(f.facing.rawValue), \(f.handedness) from its front",
                RH1Model.plateAnalyticVolume(d, fp, thickness: d.facePlateThickness))
            if !fp.elements.isEmpty {
                // The driven elements, flush with the radiating surface, and
                // what fills the rest of each hole to the plate's back.
                let toBack = f.backZ > f.faceZ ? 1.0 : -1.0
                let zBack = f.faceZ + toBack * d.facePlateThickness
                let nSeg = detail == .preview ? 8 : 12
                // An n-gon of the disc's area, so the mesh volume is the cylinder's.
                let poly = (2 * Double.pi / (Double(nSeg) * sin(2 * Double.pi / Double(nSeg)))).squareRoot()
                var fronts = IndexedMesh(), backs = IndexedMesh()
                var vFront = 0.0, vBack = 0.0
                for e in fp.elements {
                    let r = e.pistonRadius
                    let h = d.resonantElements ? min(d.elementCanAspect * 2 * r, d.facePlateThickness - 1) : d.elementPZTThickness
                    let zMid = f.faceZ + toBack * h
                    let ring = Solid.circle(e.center, r * poly, segments: nSeg)
                    fronts.append(Solid.extrude(outer: ring, z0: min(f.faceZ, zMid), z1: max(f.faceZ, zMid)))
                    backs.append(Solid.extrude(outer: ring, z0: min(zMid, zBack), z1: max(zMid, zBack)))
                    vFront += Double.pi * r * r * h; vBack += Double.pi * r * r * (d.facePlateThickness - h)
                }
                if d.resonantElements {
                    let sizes = fp.elements.map { 2 * $0.pistonRadius }
                    add("elements \(f.id)", asm, .transmitter, fronts, .assumed,
                        String(format: "%d open-type transmitters, one tone and one drive channel each: %d tones %.1f–%.1f kHz, Ø%.1f–%.1f (the 40 kHz Ø%.0f part scaled ∝ 1/f; unmeasured)",
                               fp.elements.count, d.elementTones.count, d.elementTones.min()! / 1000, d.elementTones.max()! / 1000,
                               sizes.min() ?? 0, sizes.max() ?? 0, d.elementFaceAt40k), vFront)
                    add("element carriers \(f.id)", asm, .polymer, backs, .assumed,
                        "a moulded carrier behind each transmitter, its two pins through to the wiring board", vBack)
                } else {
                    add("elements \(f.id)", asm, .pzt, fronts, .derived,
                        "\(fp.elements.count) × Ø\(Int(d.elementDiameter)) × \(Int(d.elementPZTThickness)) piezo discs, one drive channel each (ENGINE.md S1)", vFront)
                    add("element backings \(f.id)", asm, .polymer, backs, .assumed,
                        "damping backing behind each disc, to the plate's back; material and wiring not specified", vBack)
                }
            }
            if let b = f.facing == .down ? boardDown : boardUp {
                let bp = f.facing == .down ? boardPatDown : boardPat
                add("wiring board \(f.id)", asm, .fr4, b.translated(Vec3(0, 0, zlo)), .assumed,
                    String(format: "%.1f mm, %d layers: one trace per element from its pins to the rim electronics; cut through where the light slots are",
                           tb, d.wiringBoardLayers),
                    RH1Model.plateAnalyticVolume(d, bp, thickness: tb))
            }
            add("carrier ring \(f.id)", asm, .anodized,
                Solid.tube(r0: d.plateRadius, r1: d.carrierOuterRadius, z0: zlo, z1: zhi,
                           segments: seg(d.carrierOuterRadius)),
                .resolved, "spec §3 carrier Ø409→452 (seat lip as butt joint)",
                tubeV(d.plateRadius, d.carrierOuterRadius, zlo, zhi))
            if d.rearStack {
                let mapZ = { (p: P2) in P2(p.x, f.zBehind(p.y)) }
                add("gyroid horn \(f.id)", asm, .ceramic,
                    Solid.revolve(hornProfile.map(mapZ), segments: seg(d.mouthRadius)),
                    .committed,
                    "throat Ø\(Int(d.throatDiameter)) → mouth Ø\(Int(d.mouthDiameter)), quarter-ellipse 184×20, mech §3c",
                    hornVol)
                add("inner cone \(f.id)", asm, .copper,
                    Solid.revolve(coneProfile.map(mapZ), segments: seg(d.throatRadius + 2)),
                    .committed, "coax centre conductor, bore rim → throat, mech §3c", coneVol)
                let pz0 = min(f.zBehind(d.hornThroatDepth), f.zBehind(d.hornThroatDepth + d.pztThickness))
                for k in 0..<d.pztCount {
                    let az = (d.pztFirstAzimuthDeg + 360 * Double(k) / Double(d.pztCount)) * .pi / 180
                    let c = Vec3(d.pztPitchRadius * cos(az), d.pztPitchRadius * sin(az), pz0)
                    add("throat piezo \(f.id).\(k + 1)", asm, .pzt,
                        Solid.cylinder(base: c, axis: Vec3(0, 0, 1), radius: d.pztDiameter / 2,
                                       length: d.pztThickness, segments: 64),
                        .resolved, "Ø\(Int(d.pztDiameter)) (mech §3c assumed Ø25 — see reconciliation)",
                        Double.pi * pow(d.pztDiameter / 2, 2) * d.pztThickness)
                }
            }
            let r0z = f.zBehind(d.rimDepthFrom), r1z = f.zBehind(d.rimDepthTo)
            add("rim electronics \(f.id)", asm, .fr4,
                Solid.tube(r0: d.rimInnerRadius, r1: d.rimOuterRadius,
                           z0: min(r0z, r1z), z1: max(r0z, r1z), segments: seg(d.rimOuterRadius)),
                .derived, "rim annulus: drive + rectenna harvest (mech §3, §6)",
                tubeV(d.rimInnerRadius, d.rimOuterRadius, min(r0z, r1z), max(r0z, r1z)))
        }

        // ---- tori and contrawound windings -------------------------------
        let Rt = d.torusMajorRadius, at = d.torusTubeRadius
        for a in d.assemblies {
            let asm = "torus.\(a.id)"
            let tubeSeg = detail == .preview ? 24 : 48
            var former = Solid.torus(R: Rt, a: at, zc: a.torusZ, tubeSegments: tubeSeg,
                                     ringSegments: seg(Rt + at))
            let ai = at - d.torusFormerWall
            let inner = Solid.torus(R: Rt, a: ai, zc: a.torusZ, tubeSegments: tubeSeg,
                                    ringSegments: seg(Rt + at))
            former.append(IndexedMesh(vertices: inner.vertices,
                                      faces: inner.faces.map { SIMD3($0.x, $0.z, $0.y) }))
            add("torus former \(a.id)", asm, .former, former,
                .committed, "Ø\(Int(d.torusMajorDiameter)) / Ø\(Int(d.torusTubeDiameter)) (spec §3), hollow \(Int(d.torusFormerWall)) mm wall",
                2 * Double.pi * Double.pi * Rt * (at * at - ai * ai))
            let perTurn = detail == .preview ? 12 : (detail == .fine ? 36 : 24)
            let sides = detail == .preview ? 6 : 8
            // Area-equivalent polygon: an n-sided wire carries the copper
            // cross-section of the round wire it stands for.
            let wr = d.windingWireDiameter / 2
                * (2 * Double.pi / (Double(sides) * sin(2 * Double.pi / Double(sides)))).squareRoot()
            for (hand, mat) in [(1.0, CADMaterial.copper), (-1.0, CADMaterial.bronze)] {
                // One centreline for the solid and for the field solver
                // (`WindingSet`): the physics reads the CAD.
                let path = d.windingCenterline(torusZ: a.torusZ, hand: hand, samplesPerTurn: perTurn)
                let name = hand > 0 ? "winding \(a.id) CW (feed A)" : "winding \(a.id) CCW (feed B)"
                add(name, asm, mat, Solid.sweepClosed(path: path, radius: wr, sides: sides),
                    .assumed, "contrawound enantiomer, two independent feeds (R5); \(d.windingTurns) turns",
                    nil)
            }
        }

        // ---- bore collars / feed tubes -------------------------------------
        let br0 = d.boreRadius, br1 = d.boreHoleRadius
        let topF = d.face("top"), midUp = d.face("mid-up"), midDown = d.face("mid-down"),
            deck = d.face("deck")
        let topBoreEnd = topF.torusZ + at + 1
        add("bore collar top", "bore", .plateMetal,
            Solid.tube(r0: br0, r1: br1, z0: topF.faceZ, z1: topBoreEnd, segments: 64),
            .resolved, "Ø12 clear, feed + optical stem", tubeV(br0, br1, topF.faceZ, topBoreEnd))
        add("bore collar middle", "bore", .plateMetal,
            Solid.tube(r0: br0, r1: br1, z0: midDown.faceZ, z1: midUp.faceZ, segments: 64),
            .resolved, "Ø12 clear, through both middle faces",
            tubeV(br0, br1, midDown.faceZ, midUp.faceZ))
        let deckBoreBottom = deck.torusZ - at - 36
        add("bore feed tube deck", "bore", .plateMetal,
            Solid.tube(r0: br0, r1: br1, z0: deckBoreBottom, z1: deck.faceZ, segments: 64),
            .resolved, "feed riser from the base", tubeV(br0, br1, deckBoreBottom, deck.faceZ))

        // ---- enclosure -----------------------------------------------------
        let rg0 = d.rearGlassOD / 2 - d.glassWall, rg1 = d.rearGlassOD / 2
        add("rear glass (fixed)", "enclosure", .glass,
            Solid.tube(r0: rg0, r1: rg1, z0: d.chamberFloor, z1: d.chamberCeiling,
                       fromDeg: 90, toDeg: 270, segments: seg(rg1, 180)),
            .committed, "Ø444 × 4 low-iron, rear 180° (spec §5)",
            tubeV(rg0, rg1, d.chamberFloor, d.chamberCeiling, 180))
        let door = d.doorAngleDeg
        let fg0 = d.frontGlassOD / 2 - d.glassWall, fg1 = d.frontGlassOD / 2
        let bandH = d.endBandHeight
        let fz0 = d.chamberFloor + 1 + bandH, fz1 = d.chamberCeiling - 1 - bandH
        add("front glass (rotating)", "enclosure", .glass,
            Solid.tube(r0: fg0, r1: fg1, z0: fz0, z1: fz1, fromDeg: -90 + door, toDeg: 90 + door,
                       segments: seg(fg1, 180)),
            .committed, "Ø464 × 4, nests outside the rear half when open (spec §5)",
            tubeV(fg0, fg1, fz0, fz1, 180), moving: true)
        let band0 = d.trackRingOuter + 0.5, band1 = fg1 + 1
        add("front glass lower end-band", "enclosure", .anodized,
            Solid.tube(r0: band0, r1: band1, z0: fz0 - bandH, z1: fz0,
                       fromDeg: -90 + door, toDeg: 90 + door, segments: seg(band1, 180)),
            .derived, "bonded end-band carrying 3 V-rollers (spec §5.1)",
            tubeV(band0, band1, fz0 - bandH, fz0, 180), moving: true)
        add("front glass upper end-band", "enclosure", .anodized,
            Solid.tube(r0: band0, r1: band1, z0: fz1, z1: fz1 + bandH,
                       fromDeg: -90 + door, toDeg: 90 + door, segments: seg(band1, 180)),
            .derived, "bonded end-band carrying 3 V-rollers (spec §5.1)",
            tubeV(band0, band1, fz1, fz1 + bandH, 180), moving: true)
        let tr0 = d.trackRingInner, tr1 = d.trackRingOuter, th = d.trackRingHeight
        add("V-groove track lower", "enclosure", .anodized,
            Solid.tube(r0: tr0, r1: tr1, z0: d.chamberFloor, z1: d.chamberFloor + th,
                       segments: seg(tr1)),
            .derived, "in the middle-plate carrier (spec §5)",
            tubeV(tr0, tr1, d.chamberFloor, d.chamberFloor + th))
        add("V-groove track upper", "enclosure", .anodized,
            Solid.tube(r0: tr0, r1: tr1, z0: d.chamberCeiling - th, z1: d.chamberCeiling,
                       segments: seg(tr1)),
            .derived, "under the top band (spec §5)",
            tubeV(tr0, tr1, d.chamberCeiling - th, d.chamberCeiling))
        let rollerR = d.rollerDiameter / 2
        let rMid = (tr0 + tr1) / 2
        for (zc, label) in [(d.chamberFloor + th + rollerR, "lower"),
                            (d.chamberCeiling - th - rollerR, "upper")] {
            for (k, rel) in [-60.0, 0, 60].enumerated() {
                let az = (door + rel) * .pi / 180
                let dir = Vec3(cos(az), sin(az), 0)
                let base = Vec3(0, 0, zc) + dir * (rMid - d.rollerWidth / 2)
                add("V-roller \(label) \(k + 1)", "enclosure", .polymer,
                    Solid.cylinder(base: base, axis: dir, radius: rollerR,
                                   length: d.rollerWidth, segments: 48),
                    .assumed, "polymer V-roller, 3 per track (spec §5.1)",
                    Double.pi * rollerR * rollerR * d.rollerWidth, moving: true)
            }
        }

        // ---- rear arcade: columns, RX strips, photonic bay tiles -----------
        let cr = d.columnInnerRadius + d.columnRadial / 2
        let ch = d.buildChamberHeight
        for k in 0..<d.columnCount {
            let azd = 90 + d.columnPitchDeg * Double(k)
            let az = azd * .pi / 180
            add("arcade column \(k + 1)", "arcade", .columnMetal,
                Solid.box(center: Vec3(cr * cos(az), cr * sin(az), d.chamberFloor + ch / 2),
                          size: Vec3(d.columnRadial, d.columnTangential, ch), azDeg: azd),
                .resolved, k == 0 || k == 3 || k == 6
                    ? "slim column + RX strip + service bundle (spec §5.05)"
                    : "slim column + dense RX strip (spec §5.05)",
                d.columnRadial * d.columnTangential * ch)
            let sr = d.columnInnerRadius - 0.35
            let sh = ch - 2 * d.rxStripInset
            add("RX / status strip \(k + 1)", "arcade", .emissive,
                Solid.box(center: Vec3(sr * cos(az), sr * sin(az), d.chamberFloor + ch / 2),
                          size: Vec3(0.7, d.rxStripWidth, sh), azDeg: azd),
                .derived, "dense RX strip; shows the power-up sequence (mech §7)",
                0.7 * d.rxStripWidth * sh)
        }
        let tileMid = d.tileOuterPlane - d.tileThickness / 2
        let tileH = ch - 2 * d.tileMargin
        for k in 0..<d.tileCount {
            let azd = 105 + d.columnPitchDeg * Double(k)
            let az = azd * .pi / 180
            add("photonic bay tile \(k + 1)", "photonic", .photonic,
                Solid.box(center: Vec3(tileMid * cos(az), tileMid * sin(az), d.chamberFloor + ch / 2),
                          size: Vec3(d.tileThickness, 2 * d.tileHalfWidth, tileH), azDeg: azd),
                .site, "optically-addressed holographic panel, written by light (site; photonic note 08-10)",
                d.tileThickness * 2 * d.tileHalfWidth * tileH)
        }

        // ---- LED status ring ---------------------------------------------
        let lz1 = d.chamberCeiling - d.ledGap, lz0 = lz1 - d.ledHeight
        add("LED status ring", "body", .emissive,
            Solid.tube(r0: d.ledInnerRadius, r1: d.ledOuterRadius, z0: lz0, z1: lz1,
                       segments: seg(d.ledOuterRadius)),
            .derived, "echoes settle-cycle state (spec §4)",
            tubeV(d.ledInnerRadius, d.ledOuterRadius, lz0, lz1))

        // ---- base and crown envelopes (placeholders) ------------------------
        add("air intake filter", "base", .placeholder,
            Solid.tube(r0: 200, r1: 224, z0: 8, z1: 48, segments: seg(224)),
            .assumed, "base intake → plate backings → band exhaust (spec §6.0 thermal)")
        add("water reservoir", "base", .placeholder,
            Solid.box(center: Vec3(-60, -90, 150), size: Vec3(120, 110, 180)),
            .assumed, "sealed reservoir (spec §4)")
        add("graphite block bay", "base", .placeholder,
            Solid.box(center: Vec3(80, -80, 130), size: Vec3(100, 100, 120)),
            .assumed, "graphite block bay (spec §4)")
        add("power supply", "base", .placeholder,
            Solid.box(center: Vec3(-80, 90, 100), size: Vec3(150, 90, 70)),
            .assumed, "single internal DC drive rail (spec §3)")
        add("compute + router", "base", .placeholder,
            Solid.box(center: Vec3(80, 90, 110), size: Vec3(140, 100, 40)),
            .assumed, "metrology computer + per-assembly I/Q router (spec §4)")
        add("feed pump", "base", .placeholder,
            Solid.cylinder(base: Vec3(15, 10, 60), axis: Vec3(0, 0, 1), radius: 25, length: 70),
            .assumed, "feed-line pump (spec §4)")
        add("cartridge circle", "base", .placeholder,
            Solid.tube(r0: 40, r1: 150, z0: 270, z1: 300, segments: seg(150)),
            .assumed, "polar trace-element magazine: ring = period, angle = group (spec §4)")
        add("optical stem head", "crown", .placeholder,
            Solid.tube(r0: 0, r1: 30, z0: topBoreEnd + 2, z1: topBoreEnd + 32, segments: 48),
            .assumed, "bidirectional stem TX/RX + crown camera (spec §6.0, R2-b)")
        let uiSweep = 155 / R * 180 / .pi
        add("touch UI 7in", "crown", .placeholder,
            Solid.tube(r0: R, r1: R + 2, z0: 1540, z1: 1627,
                       fromDeg: -uiSweep / 2, toDeg: uiSweep / 2, segments: 24),
            .resolved, "7″ capacitive panel (spec §4) — placement conflict, see reconciliation")
        return parts
    }

    // MARK: plate solid

    /// The perforated face plate between z0 and z1: Ø410 disc, Ø14 collar
    /// hole, twelve straight-walled spiral slots and the drilled biconical
    /// micro-horns — one closed solid.
    static func plateSolid(_ d: RH1Design, _ pat: FacePattern, detail: RH1Model.Detail,
                           z0: Double, z1: Double) -> IndexedMesh {
        let tol = detail == .preview ? 0.12 : (detail == .fine ? 0.015 : 0.035)
        let outer = Solid.circle(P2(0, 0), d.plateRadius,
                                 segments: Solid.segments(radius: d.plateRadius, tol: tol,
                                                          maxSeg: 720))
        var holes: [[P2]] = []
        var hourglass: [(center: P2, throatScale: Double)?] = []
        holes.append(Solid.circle(P2(0, 0), d.boreHoleRadius, segments: 64).reversed())
        hourglass.append(nil)
        for s in pat.slotOutlines {
            holes.append(signedArea(s) > 0 ? s.reversed() : s)
            hourglass.append(nil)
        }
        for s in pat.drilled {
            let n = Solid.segments(radius: s.faceRadius, tol: tol,
                                   minSeg: detail == .preview ? 8 : 10, maxSeg: 32)
            holes.append(Solid.circle(s.center, s.faceRadius, segments: n).reversed())
            hourglass.append((s.center, d.holeThroatRatio))
        }
        for e in pat.elements {
            // An n-gon of the hole's area (as the wires): the mesh volume is the drilled hole's.
            let n = detail == .preview ? 10 : 16
            let rp = e.holeRadius * (2 * Double.pi / (Double(n) * sin(2 * Double.pi / Double(n)))).squareRoot()
            holes.append(Solid.circle(e.center, rp, segments: n).reversed())
            hourglass.append(nil)
        }
        var m = IndexedMesh()
        var bot: [Int32] = [], top: [Int32] = []
        for ring in [outer] + holes {
            for p in ring {
                bot.append(m.add(Vec3(p.x, p.y, z0)))
                top.append(m.add(Vec3(p.x, p.y, z1)))
            }
        }
        let tri = Earcut.triangulate(outer: outer, holes: holes)
        let all = outer + holes.flatMap { $0 }
        for k in stride(from: 0, to: tri.count, by: 3) {
            var i0 = Int(tri[k]), i1 = Int(tri[k + 1]), i2 = Int(tri[k + 2])
            if (all[i1] - all[i0]).cross(all[i2] - all[i0]) < 0 { swap(&i1, &i2) }
            m.tri(top[i0], top[i1], top[i2])
            m.tri(bot[i0], bot[i2], bot[i1])
        }
        let zm = (z0 + z1) / 2
        var start = 0
        for (ri, ring) in ([outer] + holes).enumerated() {
            let n = ring.count
            let hg = ri == 0 ? nil : hourglass[ri - 1]
            if let h = hg {
                var mid: [Int32] = []
                for p in ring {
                    let q = h.center + (p - h.center) * h.throatScale
                    mid.append(m.add(Vec3(q.x, q.y, zm)))
                }
                for i in 0..<n {
                    let a = start + i, b = start + (i + 1) % n
                    m.quad(bot[a], bot[b], mid[(i + 1) % n], mid[i])
                    m.quad(mid[i], mid[(i + 1) % n], top[b], top[a])
                }
            } else {
                for i in 0..<n {
                    let a = start + i, b = start + (i + 1) % n
                    m.quad(bot[a], bot[b], top[b], top[a])
                }
            }
            start += n
        }
        return m
    }

    /// Closed-form plate volume: disc − collar hole − slots − biconical holes.
    static func plateAnalyticVolume(_ d: RH1Design, _ pat: FacePattern, thickness t: Double) -> Double {
        var v = Double.pi * (d.plateRadius * d.plateRadius - d.boreHoleRadius * d.boreHoleRadius) * t
        v -= pat.slotOpenArea * t
        for e in pat.elements { v -= Double.pi * e.holeRadius * e.holeRadius * t }
        for s in pat.drilled {
            let R = s.faceRadius, r = s.throatRadius
            v -= 2 * Double.pi * (t / 2) / 3 * (R * R + R * r + r * r)
        }
        return v
    }

    // MARK: horn and cone profiles, in (r, depth-behind-plate)

    static func coneProfile(_ d: RH1Design) -> [P2] {
        let r0 = d.boreHoleRadius
        let dr = d.throatRadius - r0
        let slope = atan(dr / d.hornThroatDepth)
        let dx = d.coneWall / cos(slope)
        return [P2(r0, 0), P2(r0 + dx, 0),
                P2(d.throatRadius + dx, d.hornThroatDepth), P2(d.throatRadius, d.hornThroatDepth)]
    }

    static func hornProfile(_ d: RH1Design) -> [P2] {
        let cone = coneProfile(d)
        let c0 = cone[1], c1 = cone[2]                      // cone outer line
        func coneDepth(_ r: Double) -> Double { (r - c0.x) / (c1.x - c0.x) * (c1.y - c0.y) }
        func back(_ r: Double) -> Double { max(d.hornMeridianDepth(r), d.hornTerminalLayer) }
        // meridian ∩ cone outer line, by bisection
        var lo = d.throatRadius, hi = c1.x
        for _ in 0..<80 {
            let mid = (lo + hi) / 2
            if back(mid) > coneDepth(mid) { lo = mid } else { hi = mid }
        }
        let rx = (lo + hi) / 2
        var poly: [P2] = [c0, P2(d.mouthRadius, 0), P2(d.mouthRadius, d.hornTerminalLayer)]
        let a = d.mouthRadius - d.throatRadius, b = d.hornThroatDepth
        let n = 160
        for i in 1..<n {
            // ellipse parameter from mouth (t = π/2) to throat (t = 0)
            let t = Double.pi / 2 * (1 - Double(i) / Double(n))
            let r = d.mouthRadius - a * cos(t)
            let dd = max(b - b * sin(t), d.hornTerminalLayer)
            if r <= rx { break }
            if let last = poly.last, abs(last.x - r) < 1e-6 { continue }
            if dd > d.hornTerminalLayer || i % 4 == 0 { poly.append(P2(r, dd)) }
        }
        poly.append(P2(rx, coneDepth(rx)))
        return poly
    }

    /// Pappus: volume of a closed (r, z) profile revolved a full turn.
    static func profileRevolvedVolume(_ p: [P2]) -> Double {
        // V = 2π ∮ ... via the centroid theorem, computed per trapezoid.
        var v = 0.0
        for i in p.indices {
            let a = p[i], b = p[(i + 1) % p.count]
            // ∫ π r² dz along the edge (signed)
            v += Double.pi * (b.y - a.y) * (a.x * a.x + a.x * b.x + b.x * b.x) / 3
        }
        return abs(v)
    }
}
