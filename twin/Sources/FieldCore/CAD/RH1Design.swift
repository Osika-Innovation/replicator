import Foundation

/// RH-1, free-standing — the parametric design the CAD model is built from.
///
/// This is the single source of truth for the machine's geometry inside the
/// twin: the solid model (`RH1Model`), the drawings, the exports, the STEP
/// generator (via `fieldc cad params`) and the plate-primary physics preset
/// all read these numbers and nothing else.
///
/// Every number carries its provenance (`RH1Design.provenance`). Sources, in
/// the order they win when they disagree:
///   1. `mech §3c` — Mechanical Construction §3c, 2026-08-03 (plate stack
///      worked exactly; bore resized Ø130 → Ø12).
///   2. `site`     — etherworks.io "How it works", 2026-08-10: the to-scale
///      FIG. 1 cutaway (drawn at exactly 0.48 px/mm) and the plate-face FIG. 2
///      ("drawn from the same math as the real one"). Newest source; it
///      resolves the spec's middle-plate/storage-chamber inconsistency and
///      adds the six optically-addressed panels.
///   3. `spec`     — Hardware Specification RH-1 v0.4, 2026-07-30 (§3, §5, §8).
///   4. `.blend`   — lpoh/cad/rh1_freestanding_rev2.blend. Stale: predates the
///      08-03 bore resize (Ø131 collars, PZTs on the old Ø200 throat) and
///      carries one middle plate; used only where nothing newer exists.
/// Where they conflict the resolution is recorded in `reconciliation`, not
/// chosen silently — the same rule the compiler spec §10 set for the desktop
/// preset's column-section conflict.
///
/// Units: millimetres. Frame: floor at z = 0, machine axis = z, front (door
/// side) = +x, rear arcade centred on azimuth 180°.
public struct RH1Design: Codable, Sendable {

    // MARK: Envelope and body shells
    public var bodyDiameter = 460.0
    public var overallHeight = 1650.0
    public var shellWall = 4.0
    /// Top edge of the one-piece lower body tube = the build-chamber floor.
    public var lowerBodyTop = 1060.0
    public var topBandTop = 1590.0
    public var crownCapThickness = 4.0

    // MARK: Build and storage chambers
    /// Radiating face of the middle plate's up-facing stack (chamber floor).
    public var chamberFloor = 1060.0
    /// Radiating face of the top plate (chamber ceiling).
    public var chamberCeiling = 1520.0
    /// Radiating face of the storage deck (site FIG. 1).
    public var storageFloor = 420.0
    public var storageLinerID = 400.0
    public var storageLinerWall = 4.0

    // MARK: Plate assemblies
    public var plateDiameter = 410.0
    public var plateThickness = 12.0
    public var boreDiameter = 12.0
    public var boreTubeOD = 14.0
    public var carrierOD = 452.0
    /// Middle torus centre (spec §8); the middle stack mirrors about it.
    public var middleTorusZ = 998.0
    /// Plate back face → torus centre, top and deck assemblies (spec §8).
    public var torusSetback = 43.0

    // MARK: Plate face — sunflower field and spiral slots
    public var siteCount = 380
    public var siteInnerRadius = 26.0
    public var siteOuterRadius = 196.5
    /// Face-opening radius of a micro-horn: a + b·r (site FIG. 2, fitted to
    /// 0.005 mm over all 380 dots).
    public var holeFaceA = 1.054
    public var holeFaceB = 0.00981
    /// Throat (mid-plane) radius as a fraction of the face radius.
    public var holeThroatRatio = 0.5
    public var slotArms = 12
    /// Equiangular spiral r = r0·exp(cot α · φ); α fitted from site FIG. 2.
    public var slotAlphaDeg = 76.05
    public var slotInnerRadius = 32.6
    public var slotOuterRadius = 189.7
    public var slotWidthInner = 2.8
    public var slotWidthOuter = 6.0
    /// Minimum metal web between a drilled site and a slot; closer sites are
    /// subsumed by the slot void (the slot is already open through there).
    public var slotWeb = 0.8

    // MARK: Horn, cone, throat, piezos
    public var throatDiameter = 36.0
    public var mouthDiameter = 404.0
    public var hornThroatDepth = 20.0
    /// The meridian tapers to zero at the mouth; below this depth the horn is
    /// a flat terminal layer instead of a sliver.
    public var hornTerminalLayer = 0.6
    public var coneWall = 1.5
    public var pztCount = 3
    public var pztDiameter = 20.0
    public var pztThickness = 8.0
    public var pztPitchRadius = 18.0
    /// Azimuth of the first throat element (the other two at +120°, +240°).
    public var pztFirstAzimuthDeg = 90.0

    // MARK: Contrawound tori
    public var torusMajorDiameter = 290.0
    public var torusTubeDiameter = 60.0
    public var windingTurns = 44
    /// The torus is a winding former: a hollow shell, not a solid ring.
    public var torusFormerWall = 3.0
    public var windingWireDiameter = 4.0
    public var windingInnerLayerGap = 3.0
    public var windingOuterLayerGap = 8.5

    // MARK: Rim annulus (per-assembly drive electronics + rectenna)
    public var rimInnerRadius = 188.0
    public var rimOuterRadius = 204.0
    public var rimDepthFrom = 2.0
    public var rimDepthTo = 14.0

    // MARK: Enclosure
    public var rearGlassOD = 444.0
    public var frontGlassOD = 464.0
    public var glassWall = 4.0
    /// 0° = sealed (front half centred on +x), 180° = open (nested behind).
    public var doorAngleDeg = 0.0
    public var trackRingInner = 222.5
    public var trackRingOuter = 226.0
    public var trackRingHeight = 2.0
    public var rollerDiameter = 6.0
    public var rollerWidth = 3.0
    public var endBandHeight = 3.0

    // MARK: Rear arcade and photonic bays
    public var columnCount = 7
    public var columnPitchDeg = 30.0
    public var columnTangential = 18.0
    public var columnRadial = 10.0
    public var columnInnerRadius = 206.0
    public var rxStripWidth = 8.0
    public var rxStripInset = 20.0
    public var tileCount = 6
    public var tileThickness = 6.0
    public var tileHalfWidth = 44.0
    /// Distance from the axis to the tile's outer (projector-side) face.
    public var tileOuterPlane = 212.0
    public var tileMargin = 16.0

    // MARK: LED status ring
    public var ledInnerRadius = 199.0
    public var ledOuterRadius = 204.0
    public var ledGap = 4.0
    public var ledHeight = 4.0

    public init() {}

    // MARK: - Derived quantities

    public var bodyRadius: Double { bodyDiameter / 2 }
    public var shellInnerRadius: Double { bodyRadius - shellWall }
    public var plateRadius: Double { plateDiameter / 2 }
    public var boreRadius: Double { boreDiameter / 2 }
    public var boreHoleRadius: Double { boreTubeOD / 2 }
    public var carrierOuterRadius: Double { carrierOD / 2 }
    public var throatRadius: Double { throatDiameter / 2 }
    public var mouthRadius: Double { mouthDiameter / 2 }
    public var torusMajorRadius: Double { torusMajorDiameter / 2 }
    public var torusTubeRadius: Double { torusTubeDiameter / 2 }
    public var buildChamberHeight: Double { chamberCeiling - chamberFloor }
    public var slotCotAlpha: Double { 1 / tan(slotAlphaDeg * .pi / 180) }
    /// Angle swept by one slot arm from inner to outer radius.
    public var slotSweepRad: Double { log(slotOuterRadius / slotInnerRadius) / slotCotAlpha }
    public var holeFaceRadius: (Double) -> Double {
        let a = holeFaceA, b = holeFaceB
        return { r in a + b * r }
    }

    /// Horn meridian (quarter ellipse): depth behind the plate at radius r.
    /// Tangent to the axis at the throat, tangent to the plate at the mouth.
    public func hornMeridianDepth(_ r: Double) -> Double {
        let a = mouthRadius - throatRadius          // radial semi-axis (184)
        let b = hornThroatDepth                     // axial semi-axis (20)
        let u = (mouthRadius - r) / a
        guard u < 1 else { return b }
        guard u > 0 else { return 0 }
        return b * (1 - (1 - u * u).squareRoot())
    }

    /// Folded meridian arc length, throat to mouth (mech §3c says ≈187 mm).
    public var hornArcLength: Double {
        let a = mouthRadius - throatRadius, b = hornThroatDepth
        var s = 0.0, prev = P2(throatRadius, b)
        let n = 4000
        for i in 1...n {
            let t = Double.pi / 2 * Double(i) / Double(n)
            let p = P2(mouthRadius - a * cos(t), b - b * sin(t))
            s += (p - prev).length
            prev = p
        }
        return s
    }

    public enum Facing: String, Codable, Sendable { case up, down }

    /// One radiating face and its stack behind it.
    public struct Face: Codable, Sendable {
        public var id: String            // "top", "mid-up", "mid-down", "deck"
        public var assembly: String      // "top", "middle", "deck"
        public var facing: Facing
        public var faceZ: Double         // the radiating surface
        public var backZ: Double         // plate back face
        public var torusZ: Double        // its assembly's torus centre
        /// +1 if "behind the plate" is +z, −1 if it is −z.
        public var behind: Double { facing == .down ? 1 : -1 }
        /// z of a point `d` millimetres behind the plate back face.
        public func zBehind(_ d: Double) -> Double { backZ + behind * d }
        /// Intrinsic handedness seen from the radiating side. All four faces
        /// share one world-frame pattern, so facing plates are mirror images
        /// with opposite intrinsic handedness (spec §6.0, mech §3).
        public var handedness: String { facing == .up ? "CW-outward" : "CCW-outward" }
    }

    public struct Assembly: Codable, Sendable {
        public var id: String
        public var torusZ: Double
        public var faces: [String]
    }

    /// The four radiating faces, top to bottom.
    public var faces: [Face] {
        let t = plateThickness
        let topTorus = chamberCeiling + t + torusSetback
        let midUpBack = chamberFloor - t
        let midSetback = midUpBack - middleTorusZ           // 50 in the spec
        let midDownBack = middleTorusZ - midSetback
        let deckBack = storageFloor - t
        let deckTorus = deckBack - torusSetback
        return [
            Face(id: "top", assembly: "top", facing: .down,
                 faceZ: chamberCeiling, backZ: chamberCeiling + t, torusZ: topTorus),
            Face(id: "mid-up", assembly: "middle", facing: .up,
                 faceZ: chamberFloor, backZ: midUpBack, torusZ: middleTorusZ),
            Face(id: "mid-down", assembly: "middle", facing: .down,
                 faceZ: midDownBack - t, backZ: midDownBack, torusZ: middleTorusZ),
            Face(id: "deck", assembly: "deck", facing: .up,
                 faceZ: storageFloor, backZ: deckBack, torusZ: deckTorus),
        ]
    }

    public var assemblies: [Assembly] {
        let f = faces
        return [
            Assembly(id: "top", torusZ: f[0].torusZ, faces: ["top"]),
            Assembly(id: "middle", torusZ: middleTorusZ, faces: ["mid-up", "mid-down"]),
            Assembly(id: "deck", torusZ: f[3].torusZ, faces: ["deck"]),
        ]
    }

    public func face(_ id: String) -> Face { faces.first { $0.id == id }! }

    /// The storage chamber runs between the deck face and the mid-down face.
    public var storageCeiling: Double { face("mid-down").faceZ }
    public var storageChamberHeight: Double { storageCeiling - storageFloor }

    // MARK: - Provenance

    public enum Register: String, Codable, Sendable {
        case committed   // a number a paper commits to
        case site        // measured off an etherworks.io to-scale figure
        case derived     // computed from committed numbers by a stated rule
        case resolved    // a conflict resolved in code (see reconciliation)
        case assumed     // not specified anywhere; a sized engineering choice
    }

    public struct Provenance: Codable, Sendable {
        public var item: String
        public var value: String
        public var register: Register
        public var source: String
    }

    public var provenance: [Provenance] {
        func p(_ i: String, _ v: String, _ r: Register, _ s: String) -> Provenance {
            Provenance(item: i, value: v, register: r, source: s)
        }
        let f = faces
        let fmt = { (x: Double) in String(format: "%.1f", x) }
        return [
            p("body", "Ø\(Int(bodyDiameter)) × \(Int(overallHeight))", .committed, "spec §3; site FIG.1 (220.8 px × 792 px at 0.48 px/mm)"),
            p("shells", "\(Int(shellWall)) mm anodized extrusion", .committed, "spec §3"),
            p("lower body tube", "0–\(Int(lowerBodyTop))", .committed, "spec §3 ('one piece, 0–1060')"),
            p("top band / crown", "\(Int(chamberCeiling))–\(Int(topBandTop)) / \(Int(topBandTop))–\(Int(overallHeight))", .committed, ".blend R2_Shell_TopBand/Crown (spec §2 names them, no numbers)"),
            p("build chamber", "Ø\(Int(rearGlassOD)) × \(Int(buildChamberHeight)) at \(Int(chamberFloor))–\(Int(chamberCeiling))", .committed, "spec §3, §8; site FIG.1 agrees exactly"),
            p("plates", "4 faces Ø\(Int(plateDiameter)) × \(Int(plateThickness))", .committed, "spec §3 (×3 assemblies; the middle one double-faced)"),
            p("bore", "Ø\(Int(boreDiameter)) clear, Ø\(Int(boreTubeOD)) collar OD", .resolved, "mech §3c (Ø12); collar wall assumed 1 mm"),
            p("top face", "\(fmt(f[0].faceZ)) (faces down)", .committed, "spec §8 (1520–1532)"),
            p("mid-up face", "\(fmt(f[1].faceZ)) (faces up)", .committed, "spec §8 (1048–1060)"),
            p("mid-down face", "\(fmt(f[2].faceZ)) (faces down)", .resolved, "site FIG.1 draws it (931.8–948); mirrored about the 998 torus"),
            p("deck face", "\(fmt(f[3].faceZ)) (faces up)", .site, "site FIG.1 (403.8–420); spec §8 said 655"),
            p("tori", "Ø\(Int(torusMajorDiameter)) / Ø\(Int(torusTubeDiameter)) at \(fmt(f[0].torusZ)), \(fmt(middleTorusZ)), \(fmt(f[3].torusZ))", .resolved, "spec §3, §8 (1575, 998, 600); deck moved with the deck plate at the spec's 43 mm setback"),
            p("storage chamber", "Ø\(Int(storageLinerID)) × \(fmt(storageChamberHeight))", .resolved, "site FIG.1 (Ø400, 425–930); spec §3 said Ø400 × 385"),
            p("carrier rings", "Ø\(Int(plateDiameter))→Ø\(Int(carrierOD)) × \(Int(plateThickness))", .resolved, "spec §3 says Ø409→452 (0.5 mm seat lip) — modelled as a butt joint"),
            p("sunflower field", "N = \(siteCount), golden angle, r \(fmt(siteInnerRadius))–\(fmt(siteOuterRadius))", .site, "spec §3 (~380); site FIG.2 (26.5–197.3, 137.508°)"),
            p("micro-horn face radius", String(format: "%.3f + %.5f·r", holeFaceA, holeFaceB), .site, "site FIG.2 dot radii, fitted to 0.005 mm"),
            p("micro-horn throat", "\(Int(holeThroatRatio * 100))% of face radius (biconical)", .assumed, "site 'flared walls from both faces'; ratio not specified"),
            p("spiral slots", "\(slotArms) arms, α = \(slotAlphaDeg)°, r \(slotInnerRadius)–\(slotOuterRadius)", .site, "site FIG.2 (cot α 0.2483 = mech §10 desktop α)"),
            p("slot width", "\(slotWidthInner) → \(slotWidthOuter) mm", .committed, "mech §3 Fig.3 / §10 (desktop value, kept)"),
            p("horn", "throat Ø\(Int(throatDiameter)) → mouth Ø\(Int(mouthDiameter)), \(Int(hornThroatDepth)) mm deep, quarter-ellipse", .committed, "mech §3c"),
            p("PZT elements", "3 × Ø\(Int(pztDiameter)) × \(Int(pztThickness)) at r = \(Int(pztPitchRadius)), 120°", .resolved, "mech §3c assumed Ø25; Ø25 at r 18 reaches into the Ø12 bore — see reconciliation"),
            p("torus former", "hollow, \(Int(torusFormerWall)) mm wall", .assumed, "a winding former is a tube; wall not specified"),
            p("windings", "contrawound pair × 3, \(windingTurns) turns each, Ø\(Int(windingWireDiameter)) wire", .assumed, "spec §6.0 / mech §5 (pair, 2 feeds); turn count = the superseded 44-turn winding"),
            p("rear glass", "Ø\(Int(rearGlassOD)) × \(Int(glassWall)), fixed, rear 180°", .committed, "spec §5"),
            p("front glass", "Ø\(Int(frontGlassOD)) × \(Int(glassWall)), rotating 180°", .committed, "spec §5"),
            p("rollers / tracks", "3+3 V-rollers on V-groove rings", .derived, "spec §5.1 (count, placement); sizes assumed"),
            p("arcade columns", "7 × \(Int(columnTangential))×\(Int(columnRadial)) at r \(Int(columnInnerRadius))–\(Int(columnInnerRadius + columnRadial)), 30° pitch", .resolved, "spec §5.05 ('seven slim'); section not specified for free-standing"),
            p("photonic bays", "6 flat laminated tiles, \(Int(2 * tileHalfWidth)) wide, between the columns", .site, "site 'six optically-addressed holographic panels' + FIG.1; PHOTONIC_PANEL_NOTE 2026-08-10"),
            p("LED ring", "r \(Int(ledInnerRadius))–\(Int(ledOuterRadius)) under the top plate", .derived, "spec §4, §8; .blend R2_LED_Build"),
            p("base contents", "envelopes only", .assumed, "spec §4 lists them; no dimensions anywhere"),
        ]
    }

    // MARK: - Reconciliation

    public struct Reconciliation: Codable, Sendable {
        public var topic: String
        public var papers: String
        public var site: String
        public var model: String
        public var why: String
    }

    public static let reconciliation: [Reconciliation] = [
        Reconciliation(
            topic: "Middle plate",
            papers: "spec §8: one plate at 1048–1060 with its torus + horn below, 'double-faced'",
            site: "FIG.1: two plates (faces up 1044–1060, faces down 932–948) flanking one torus",
            model: "two face plates mirrored about the 998 torus: 1048–1060 and 936–948",
            why: "a 12 mm plate cannot carry two back-to-back cap stacks; the site draws what the spec's words say"),
        Reconciliation(
            topic: "Storage deck and chamber",
            papers: "spec §3/§8: deck face 655, chamber Ø400 × 385, base ~650",
            site: "FIG.1: deck face 420, chamber Ø400 from 425 to 930, base 0–400",
            model: "deck face 420, chamber 420–936 (Ø400 liner), deck torus at 365",
            why: "the spec's 385 chamber and its middle stack overlap (655 + 385 = 1040 > 936); the site's layout is the only one that closes"),
        Reconciliation(
            topic: "Throat piezos vs bore",
            papers: "mech §3c: 3 × Ø25 (assumed, not measured) on r = 18, so throat Ø36",
            site: "—",
            model: "3 × Ø20 on r = 18; throat Ø36 and every horn number kept",
            why: "Ø25 discs on r = 18 reach r = 5.5 — 0.5 mm inside the Ø12 bore, leaving no room for a collar. Shrinking the (assumed) disc keeps the (derived) horn intact; the alternative is r = 20.5 → throat Ø41"),
        Reconciliation(
            topic: "Bore collar",
            papers: "spec §3: 'Ø12 bores ... + bore collar'; mech §3c: 'Ø12 rim → throat'",
            site: "FIG.1: bore drawn Ø12",
            model: "Ø12 clear, Ø14 × 1 mm collar tube; plate holes Ø14",
            why: "a collar needs a wall; the clear bore stays Ø12"),
        Reconciliation(
            topic: "Plate face pattern",
            papers: "spec §3: '~380-hole Vogel field', 12 slots; mech §3c: 21×34 parastichies",
            site: "FIG.2: 380 dots, golden angle, radii 26.5–197.3, hole radius grows 1.3 → 3.0 mm with r; slots α 76.05°, r 32.6–189.7, 1.13 turns",
            model: "FIG.2 laws; sites whose opening would cut a slot web are left to the slot void",
            why: "the slot is already open through the plate at those sites"),
        Reconciliation(
            topic: "Side panels",
            papers: "spec v0.4: side paneling = plan B (phononic); PHOTONIC_PANEL_NOTE 08-10: DRAFT proposal",
            site: "six optically-addressed holographic panels on the rear arc, in the baseline",
            model: "six photonic bay tiles between the columns (EM only — they carry no acoustic channels)",
            why: "the site is the newest statement; the note is not yet a ruling, so the tiles are geometry, not physics, in this revision"),
        Reconciliation(
            topic: "Arcade columns",
            papers: "desktop: 40×20 at r 150–170; free-standing: 'seven slim columns', no section",
            site: "FIG.1: panels span the rear arc with ~5 mm gaps",
            model: "18 × 10 at r 206–216, between the plate rim and the rear glass",
            why: "a 40×20 section does not fit the 13 mm annulus between the Ø410 plate and the Ø436 glass bore"),
        Reconciliation(
            topic: "Canonical render model",
            papers: "spec §8: lpoh/cad/rh1_freestanding_rev2.blend is canonical",
            site: "—",
            model: "this parametric model supersedes it; rev2 predates the 08-03 bore resize (Ø131 collars, PZTs at r 100) and has one middle plate, no door, arcade or panels",
            why: "the twin's CAD is regenerated from parameters, so it cannot drift from them"),
        Reconciliation(
            topic: "Touch UI placement",
            papers: "spec §4: 7″ panel 'set into the front face at standing eye height'",
            site: "—",
            model: "placed on the top band/crown front (z 1540–1627), surface-mounted",
            why: "the only shell surface at eye height is the 130 mm band+crown; a flush mount needs a shell cut-out not modelled here"),
    ]
}
