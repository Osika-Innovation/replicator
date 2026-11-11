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
    /// Resonant elements: the tones the plate can play (Hz) and, per channel,
    /// the one tone its element is tuned to. nil = every element plays every
    /// tone (the ideal broadband piston).
    public var tones: [Double]? = nil
    public var toneOf: [Int]? = nil
    /// A resonant element's quality factor in air: its bandwidth is f/Q.
    public var elementQ = 25.0

    /// The same plates with resonant elements, each tuned to one of `tones`.
    /// Which tone an element gets is a hash of its place along the spiral
    /// (the fractional part of i·√2), so every tone's sub-array is spread
    /// over all radii and angles and none is periodic. The multiplier must
    /// not be the golden ratio: the spiral's angle is i golden angles, and a
    /// golden hash gave every tone one 40° wedge of the plate (2026-11-12).
    /// An element's radius follows its tone: `radiusAt40k` × 40 kHz ÷ f — the
    /// open-type transmitter scaled (`ElementSpec.scaled`).
    /// - Parameter apart: the least gap between two elements' faces (m). The
    ///   spiral spaces centres evenly but the elements differ in size, so
    ///   where two large ones fall side by side they are nudged apart.
    public func locked(tones t: [Double], radiusAt40k: Double = 5e-3, apart: Double = 0) -> PlateArray {
        var a = self
        let root2 = 2.0.squareRoot()
        func tone(_ i: Int, _ shift: Double) -> Int {
            min(t.count - 1, Int(((Double(i) + shift) * root2).truncatingRemainder(dividingBy: 1) * Double(t.count)))
        }
        let lo = (0..<perPlate).map { tone($0, 0) }, up = (0..<perPlate).map { tone($0, 0.5) }
        func sites(_ pts: [(x: Double, y: Double)], _ m: [Int]) -> [Site] {
            pts.indices.map { Site(x: pts[$0].x, y: pts[$0].y, radius: radiusAt40k * 40_000 / t[m[$0]]) }
        }
        a.lowerSites = spread(sites(PlateArray.vogel(perPlate, radius: plateRadius, inner: innerRadius), lo), apart: apart)
        a.upperSites = spread(sites(PlateArray.vogel(perPlate, radius: plateRadius, rotation: PlateArray.goldenAngle / 2, inner: innerRadius), up), apart: apart)
        a.tones = t
        a.toneOf = lo + up
        a.label = (label ?? "plates\(perPlate)") + "-locked\(t.count)"
        return a
    }

    /// Nudge sites apart until every pair of faces is at least `apart` from
    /// each other, keeping every centre in the annulus the spiral filled.
    /// Deterministic; a few passes over neighbouring pairs.
    func spread(_ sites: [Site], apart: Double) -> [Site] {
        guard apart > 0, sites.count > 1 else { return sites }
        var s = sites
        let rMax = (s.map(\.radius).max() ?? 0)
        let cell = 2 * rMax + apart
        for _ in 0..<200 {
            var grid: [Int: [Int]] = [:]
            func key(_ x: Double, _ y: Double) -> Int { Int((x / cell).rounded(.down)) &* 73_856_093 ^ Int((y / cell).rounded(.down)) &* 19_349_663 }
            for (i, e) in s.enumerated() { grid[key(e.x, e.y), default: []].append(i) }
            var moved = false
            for i in s.indices {
                for dx in -1...1 { for dy in -1...1 {
                    for j in grid[key(s[i].x + Double(dx) * cell, s[i].y + Double(dy) * cell)] ?? [] where j > i {
                        let ex = s[j].x - s[i].x, ey = s[j].y - s[i].y
                        let dist = (ex * ex + ey * ey).squareRoot()
                        let short = s[i].radius + s[j].radius + apart - dist
                        guard short > 1e-9, dist > 0 else { continue }
                        let push = (short / 2 + 1e-6) / dist
                        s[i].x -= ex * push; s[i].y -= ey * push
                        s[j].x += ex * push; s[j].y += ey * push
                        moved = true
                    }
                } }
            }
            for i in s.indices {
                let r = (s[i].x * s[i].x + s[i].y * s[i].y).squareRoot()
                let want = min(max(r, innerRadius), plateRadius)
                if abs(want - r) > 0, r > 0 { s[i].x *= want / r; s[i].y *= want / r; moved = true }
            }
            if !moved { break }
        }
        return s
    }

    /// What a built plate differs from its drawing by. Every figure is one
    /// standard deviation of a normal error, except `dead` (a share).
    public struct Tolerance: Sendable {
        /// Element sensitivity, as a fraction (0.05 = ±5 %).
        public var gain = 0.0
        /// Element phase (degrees): drive timing and bond-line scatter.
        public var phaseDegrees = 0.0
        /// Element position on the plate, each axis (m).
        public var position = 0.0
        /// Share of elements that do not play at all.
        public var dead = 0.0
        /// Resonance frequency, as a fraction of the tone (resonant elements
        /// only): a detuned element plays its tone weaker and late.
        public var resonance = 0.0
        public init() {}
        public var text: String {
            String(format: "gain ±%.0f %%, phase ±%.0f°, position ±%.2f mm, resonance ±%.1f %%, %.1f %% dead",
                   100 * gain, phaseDegrees, position * 1000, 100 * resonance, 100 * dead)
        }
    }
    /// A built plate's error per channel (multiplies the element's gain);
    /// nil = as drawn.
    public var channelError: [Complex]? = nil

    /// One random build of these plates within `tolerance`.
    public func asBuilt(_ tol: Tolerance, seed: UInt64) -> PlateArray {
        var a = self
        var rng = SplitMix64(seed: seed)
        func gauss() -> Double {
            let u1 = max(rng.nextUnit(), 1e-300), u2 = rng.nextUnit()
            return (-2 * log(u1)).squareRoot() * cos(2 * Double.pi * u2)
        }
        let els = elements()
        func moved(_ range: Range<Int>) -> [Site] {
            range.map { c in
                Site(x: els[c].position.x + tol.position * gauss(), y: els[c].position.y + tol.position * gauss(), radius: pistonRadius(c))
            }
        }
        a.lowerSites = moved(0..<perPlate); a.upperSites = moved(perPlate..<channels)
        a.channelError = (0..<channels).map { _ in
            if rng.nextUnit() < tol.dead { return Complex.zero }
            var e = Complex.expi(tol.phaseDegrees * Double.pi / 180 * gauss()) * max(0, 1 + tol.gain * gauss())
            if tones != nil {
                let y = elementQ * 2 * tol.resonance * gauss()          // Q (f/f₀ − f₀/f) for a small detune
                e = e * (Complex(1, -y) * (1 / (1 + y * y)))
            }
            return e
        }
        a.label = tag + "-built\(seed)"
        return a
    }

    /// What each element makes of a drive at each of `frequencies`: nil for
    /// broadband elements as drawn. `curve`: the resonance curve 1 / (1 + iQ(f/f₀ −
    /// f₀/f)), so a neighbouring tone still gets through, weaker and turned
    /// in phase (a scan sweeps frequency). Otherwise 1 at the element's own
    /// tone and 0 elsewhere: a drive that gives each element only its tone.
    public func gains(_ frequencies: [Double], curve: Bool) -> [[Complex]]? {
        guard let t = tones, let m = toneOf else {
            return channelError.map { e in frequencies.map { _ in e } }
        }
        return frequencies.map { f in
            m.indices.map { c in
                let f0 = t[m[c]], err = channelError?[c] ?? .one
                if !curve { return abs(f - f0) < 1 ? err : Complex.zero }
                let y = elementQ * (f / f0 - f0 / f)
                return Complex(1, -y) * (1 / (1 + y * y)) * err
            }
        }
    }

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
        guard d.resonantElements else { return a }
        // Hole to hole: a clearance each side and the web between (DR11), with 0.05 mm in hand.
        a = a.locked(tones: d.elementTones, radiusAt40k: d.elementFaceAt40k / 2 * 1e-3,
                     apart: (2 * d.elementHoleClearance + d.elementHoleWeb + 0.05) * 1e-3)
        a.label = "rh1x\(d.elementCount)t\(d.elementTones.count)"
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

    /// The engine's piston radius of a channel (m).
    public func pistonRadius(_ channel: Int) -> Double {
        if let lo = lowerSites, let up = upperSites { return channel < perPlate ? lo[channel].radius : up[channel - perPlate].radius }
        return elementRadius
    }

    /// The hardware a channel's element is: the open-type transmitter scaled
    /// to its tone when the elements are resonant, else the directly
    /// radiating piezo disc the face carried until 2026-11-12.
    public func spec(_ channel: Int, medium: Medium) -> ElementSpec {
        if let t = tones, let m = toneOf { return ElementSpec.scaled(to: t[m[channel]], medium: medium) }
        return ElementSpec.bulkDisc(diameter: 2 * pistonRadius(channel), thickness: 2e-3)
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
