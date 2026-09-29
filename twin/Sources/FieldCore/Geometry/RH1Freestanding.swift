import Foundation

/// RH-1 free-standing — the plate-primary acoustic machine, built from the CAD.
///
/// The desktop preset (`RH1`) is the v0.3 envelope: six phononic side panels,
/// 24 PMN-PT gates. Rulings R3 (amended 2026-07-30) and the free-standing
/// spec v0.4 moved the acoustic aperture onto the plates, which is what this
/// preset models. Its geometry is not restated here — it is read from
/// `RH1Model`, so the physics and the CAD cannot drift apart:
///
///   * apertures = the drilled biconical micro-horns of the two build-chamber
///     faces (mid-up at z = 0, top at z = 460 mm, build frame), plus the
///     twelve spiral slot voids per face when `slotsOpen` (they are voids in
///     the conductor and the gyroid behind them is porous, so by default they
///     radiate — see `FacePattern` and gate G-CAD8: they are ~13× the micro-
///     horn open area);
///   * gates = the three throat piezos per face (6 for the build chamber);
///   * gate → aperture coupling = `HornModel`, a labelled STUB standing where
///     the surface compiler's Z(r) or a horn FDTD will go (spec §17), exactly
///     as `RainbowMap` stands in for the panel holograms. Numbers computed with
///     it are MODEL numbers until a bench measures the throat→face transfer.
///
/// Frame: build frame, metres — origin on the axis at the mid-up face, z up.
public enum RH1Freestanding {

    /// Throat → aperture transfer through the ring-radial gyroid horn (STUB).
    public struct HornModel: Sendable, Codable {
        /// Sound speed in the gyroid's air channels for a FIXED medium (the
        /// legacy §12 presets): tortuosity ~1.3 ⇒ c/√1.3.
        public var soundSpeed = 300.0
        /// Channel tortuosity. When the medium carries an air state the channels
        /// hold the same air, so their speed follows it: c/√τ — the horn drifts
        /// with temperature exactly as the chamber does.
        public var tortuosity = 1.3
        public func channelSpeed(_ m: Medium) -> Double {
            m.air == nil ? soundSpeed : m.soundSpeed / tortuosity.squareRoot()
        }
        /// Graded cell size at the throat and at the mouth (m) — cells shrink
        /// toward the mouth, the trend site FIG. 1 of the plate draws.
        public var cellThroat = 5.0e-3
        public var cellMouth = 2.0e-3
        /// Width of each tone's exit band, as a fraction of the radial throw.
        public var bandWidth = 0.22
        /// Floor so a tone is never radiated by literally nothing.
        public var floor = 0.12
        /// Azimuthal spreading exponent of one throat element's lobe.
        public var azimuthExponent = 1.0
        public init() {}

        /// Radius (m) where a tone exits: the depth whose cell is λ_h/2.
        public func exitRadius(frequency f: Double, throat: Double, mouth: Double,
                               medium: Medium = .air) -> Double {
            let a = channelSpeed(medium) / (2 * f)
            let t = (cellThroat - a) / (cellThroat - cellMouth)
            return throat + min(1, max(0, t)) * (mouth - throat)
        }
    }

    public struct Options: Sendable {
        public var slotsOpen = true
        public var frequency = 40_000.0
        public var medium = Medium.air
        public var horn = HornModel()
        public var design = RH1Design()
        /// Slot discretization (m); nil = λ/4 at `frequency`. Studies that
        /// compare tones fix it so every tone sees the same aperture set.
        public var slotSegment: Double? = nil
        public init() {}
    }

    public static let gatesPerFace = 3

    /// Build the preset. Elements are VIRTUAL: each physical aperture appears
    /// once per throat gate of its face, carrying that gate's coupling — so
    /// the gate-granular operator of §11 needs no new machinery.
    public static func preset(_ o: Options = Options()) -> (preset: MachinePreset, coupling: [Complex]) {
        let d = o.design
        let pat = FacePattern(d, slotSamples: 400)
        let mm = 0.001
        let floorZ = d.chamberFloor
        let lambda = o.medium.wavelength(at: o.frequency)
        let ds = o.slotSegment ?? max(2e-3, lambda / 4)     // slot segment length (m)
        struct Aperture { var x, y, area: Double }
        var apertures: [Aperture] = []
        for s in pat.drilled {
            apertures.append(Aperture(x: s.center.x * mm, y: s.center.y * mm,
                                      area: Double.pi * pow(s.faceRadius * mm, 2)))
        }
        if o.slotsOpen {
            for (li, line) in pat.slotCenterlines.enumerated() {
                var acc = 0.0, start = 0
                for i in 1..<line.count {
                    acc += (line[i] - line[i - 1]).length * mm
                    if acc >= ds || i == line.count - 1 {
                        let m = line[(start + i) / 2]
                        let w = pat.slotWidths[li][(start + i) / 2] * mm
                        apertures.append(Aperture(x: m.x * mm, y: m.y * mm, area: w * acc))
                        acc = 0; start = i
                    }
                }
            }
        }
        let faces: [(surface: SurfaceID, z: Double, normal: Vec3)] = [
            (.lowerCap, (d.face("mid-up").faceZ - floorZ) * mm, Vec3(0, 0, 1)),
            (.upperCap, (d.face("top").faceZ - floorZ) * mm, Vec3(0, 0, -1)),
        ]
        var elements: [Element] = []
        var coupling: [Complex] = []
        let rT = d.throatRadius * mm, rM = d.mouthRadius * mm
        let rExit = o.horn.exitRadius(frequency: o.frequency, throat: rT, mouth: rM,
                                      medium: o.medium)
        let kH = 2 * Double.pi * o.frequency / o.horn.channelSpeed(o.medium)
        for (fi, f) in faces.enumerated() {
            for g in 0..<gatesPerFace {
                let psi = (d.pztFirstAzimuthDeg + 360 * Double(g) / Double(gatesPerFace)) * .pi / 180
                let src = Vec3(d.pztPitchRadius * mm * cos(psi), d.pztPitchRadius * mm * sin(psi), 0)
                for a in apertures {
                    let r = (a.x * a.x + a.y * a.y).squareRoot()
                    let phi = atan2(a.y, a.x)
                    // path through the horn from this throat element
                    let ell = max((Vec3(a.x, a.y, 0) - src).length, 1e-4)
                    let lobe = pow((1 + cos(phi - psi)) / 2, o.horn.azimuthExponent)
                    let spread = (rT / max(ell, rT)).squareRoot()
                    let dr = (r - rExit) / (o.horn.bandWidth * (rM - rT))
                    let band = o.horn.floor + (1 - o.horn.floor) * exp(-0.5 * dr * dr)
                    let amp = lobe * spread * band
                    elements.append(Element(position: Vec3(a.x, a.y, f.z), normal: f.normal,
                                            area: a.area, surface: f.surface,
                                            gateIndex: fi * gatesPerFace + g))
                    coupling.append(Complex.expi(kH * ell) * amp)
                }
            }
        }
        // Build volume: the Ø410 aperture less a 15 mm margin, face to face
        // (derived; the free-standing spec names no build volume). Lattices
        // inset from the faces themselves, as they do for the desktop preset.
        let bv = BuildVolume(radius: (d.plateRadius - 15) * mm,
                             height: d.buildChamberHeight * mm)
        let p = MachinePreset(id: "rh1-fs", displayName: "RH-1 free-standing",
                              elements: elements, gateCount: faces.count * gatesPerFace,
                              buildVolume: bv, medium: o.medium,
                              defaultBand: 30_000...75_000)
        return (p, coupling)
    }

    /// Room air the app and CLI simulate unless told otherwise.
    public static let roomAir = Medium.air(temperatureC: 20, humidity: 50)

    /// The machine the app and CLI simulate: the free-standing RH-1 in room
    /// air, its two facing plates as the cavity walls. (The desktop `RH1`
    /// preset is frozen: it stays only for the solver-validation gates and for
    /// replaying old receipts.)
    public static func standard(frequency: Double = 40_000, medium: Medium = roomAir,
                                slotsOpen: Bool = true)
        -> (preset: MachinePreset, coupling: [Complex], walls: Propagator.Walls) {
        var o = Options()
        o.frequency = frequency
        o.medium = medium
        o.slotsOpen = slotsOpen
        let (p, c) = preset(o)
        return (p, c, walls(o.design))
    }

    /// The build chamber as a glass-walled cylinder: the rear glass's inner
    /// radius (Ø444 OD, 4 mm wall → 218 mm; the Ø464 door half is ignored),
    /// the two faces 460 mm apart, each reflecting R. Built once per mode
    /// range (the Bessel table grows with maxGamma·a) and cached.
    public static func chamber(maxGamma: Double, reflection: Double = 0.9,
                               design d: RH1Design = RH1Design()) -> CylinderCavity {
        let key = "\(Int(maxGamma.rounded(.up)))-\(reflection)"
        chamberLock.lock(); defer { chamberLock.unlock() }
        if let c = chambers[key] { return c }
        let c = CylinderCavity(radius: (d.rearGlassOD / 2 - d.glassWall) * 0.001,
                               length: d.buildChamberHeight * 0.001,
                               reflectionLower: reflection, reflectionUpper: reflection,
                               maxGamma: maxGamma.rounded(.up))
        chambers[key] = c
        return c
    }
    static let chamberLock = NSLock()
    nonisolated(unsafe) static var chambers: [String: CylinderCavity] = [:]

    /// The two facing plates are the cavity walls: image sources at 0 and L.
    public static func walls(_ d: RH1Design = RH1Design(), order: Int = 3,
                             reflection: Double = 0.9) -> Propagator.Walls {
        Propagator.Walls(capSeparation: d.buildChamberHeight * 0.001, order: order,
                         reflectionCoefficient: reflection)
    }
}
