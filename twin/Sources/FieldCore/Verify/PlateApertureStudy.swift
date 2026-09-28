import Foundation

/// Can the plate-primary RH-1 hold a trap? The first study of the
/// free-standing machine's acoustic aperture, run on geometry read from the
/// CAD (`RH1Freestanding`, `FacePattern`).
///
/// Six drive gates serve the build chamber (three throat piezos per face).
/// The architecture's claim is that this is enough because "half the boundary
/// is printed and steers by frequency": the graded gyroid and the face pattern
/// give each tone its own aperture, so a chord is 6 DOF PER TONE, and the two
/// facing plates form a resonator whose multipath is itself aperture. This
/// study measures that claim at force level, with the same metric as G9d
/// (parasitic-to-main trap depth under an N-tone chord).
///
/// Register: every number here is a MODEL number. The throat→aperture
/// transfer is `HornModel`, a labelled stub; the walls are axial image
/// sources of the two plates, which presumes a known cavity Green's function.
public enum PlateApertureStudy {

    public struct Row: Codable, Sendable {
        public var label: String
        public var tones: Int
        public var slotsOpen: Bool
        public var walls: Bool
        public var apertures: Int
        /// |p(target)|² / mean |p|² over the neighbourhood, averaged over tones.
        public var focusContrast: Double
        public var parasiticToMain: Double
        public var mainDepth: Double
    }

    /// Physical apertures with per-gate couplings, regrouped from the preset's
    /// virtual elements (one per aperture per gate).
    struct Aperture { var element: Element; var coupling: [Complex] }

    static func apertures(_ preset: MachinePreset, _ coupling: [Complex]) -> [Aperture] {
        var index: [String: Int] = [:]
        var out: [Aperture] = []
        for (i, e) in preset.elements.enumerated() {
            let key = "\(e.surface.rawValue):\(Int((e.position.x * 1e7).rounded())):\(Int((e.position.y * 1e7).rounded()))"
            if let j = index[key] {
                out[j].coupling[e.gateIndex] = out[j].coupling[e.gateIndex] + coupling[i]
            } else {
                var c = [Complex](repeating: .zero, count: preset.gateCount)
                c[e.gateIndex] = coupling[i]
                index[key] = out.count
                out.append(Aperture(element: e, coupling: c))
            }
        }
        return out
    }

    /// Gate-granular operator at `points`: H[n][g] = Σ_a G(x_n, a) · C[a][g],
    /// the Green's function per aperture evaluated once, with its images.
    static func operatorAt(_ points: [Vec3], _ ap: [Aperture], gates: Int, frequency f: Double,
                           medium: Medium, walls: Propagator.Walls) -> [Complex] {
        let k = medium.wavenumber(at: f)
        let pref = medium.density * medium.soundSpeed * k / (2 * .pi)
        let images = ap.map { walls.images(of: $0.element.position.z) }
        var H = [Complex](repeating: .zero, count: points.count * gates)
        H.withUnsafeMutableBufferPointer { buf in
            DispatchQueue.concurrentPerform(iterations: points.count) { n in
                let x = points[n]
                var row = [Complex](repeating: .zero, count: gates)
                for (ai, a) in ap.enumerated() {
                    let el = a.element
                    var g = Complex.zero
                    for (zi, refl) in images[ai] {
                        let d = x - Vec3(el.position.x, el.position.y, zi)
                        let r = max(d.length, 1e-9)
                        let dir = Propagator.pistonDirectivity(
                            k: k, a: el.equivalentRadius, cosTheta: abs(d.dot(el.normal)) / r)
                        let ph = Complex.expi(k * r)
                        g += Complex(-ph.im, ph.re) * (pref * el.area * dir * refl / r)
                    }
                    for gi in 0..<gates where a.coupling[gi].re != 0 || a.coupling[gi].im != 0 {
                        row[gi] += g * a.coupling[gi]
                    }
                }
                for gi in 0..<gates { buf[n * gates + gi] = row[gi] }
            }
        }
        return H
    }

    public static func run(label: String, tones: Int, slotsOpen: Bool, walls useWalls: Bool,
                           band: (Double, Double) = (30_000, 70_000),
                           horn: RH1Freestanding.HornModel = .init(),
                           halfWidthWavelengths: Double = 3) -> Row {
        let toneList = (0..<tones).map { i -> Double in
            tones == 1 ? (band.0 + band.1) / 2
                       : band.0 + (band.1 - band.0) * Double(i) / Double(tones - 1)
        }
        let medium = Medium.air
        let fMid = (band.0 + band.1) / 2
        let lambda = medium.wavelength(at: fMid)
        let d = RH1Design()
        let target = Vec3(0, 0, d.buildChamberHeight * 0.001 / 2)
        let sp = lambda / 6, half = halfWidthWavelengths * lambda
        let n = Int((2 * half / sp).rounded(.down)) + 1
        let lat = FieldLattice(origin: Vec3(target.x - half, target.y - half, target.z - half),
                               spacing: sp, nx: n, ny: n, nz: n)
        let points = lat.positions
        let walls = useWalls ? RH1Freestanding.walls(d) : .none
        var U = [Double](repeating: 0, count: lat.count)
        var contrast = 0.0
        var apCount = 0
        for f in toneList {
            var o = RH1Freestanding.Options()
            o.frequency = f; o.slotsOpen = slotsOpen; o.horn = horn
            o.slotSegment = lambda / 2
            let (preset, coupling) = RH1Freestanding.preset(o)
            let ap = apertures(preset, coupling)
            apCount = ap.count
            let G = preset.gateCount
            let H = operatorAt(points, ap, gates: G, frequency: f, medium: medium, walls: walls)
            let h = operatorAt([target], ap, gates: G, frequency: f, medium: medium, walls: walls)
            // Phase-conjugate drive: the unit-power drive that maximizes |p(target)|.
            let norm = h.reduce(0) { $0 + $1.magnitude * $1.magnitude }.squareRoot()
            let u = h.map { $0.conjugate / max(norm, 1e-30) }
            var field = [Complex](repeating: .zero, count: lat.count)
            for i in 0..<lat.count {
                var acc = Complex.zero
                for g in 0..<G { acc += H[i * G + g] * u[g] }
                field[i] = acc
            }
            let pt = h.enumerated().reduce(Complex.zero) { $0 + $1.element * u[$1.offset] }
            let mean = field.reduce(0) { $0 + $1.magnitude * $1.magnitude } / Double(field.count)
            contrast += (pt.magnitude * pt.magnitude) / max(mean, 1e-30) / Double(toneList.count)
            BroadbandGate.addTone(to: &U, field: field, frequency: f, medium: medium,
                                  lattice: lat, particle: .pla())
        }
        let r = BroadbandGate.trapDepthRatio(U: U, lattice: lat, target: target)
        return Row(label: label, tones: tones, slotsOpen: slotsOpen, walls: useWalls,
                   apertures: apCount, focusContrast: contrast,
                   parasiticToMain: r.ratio, mainDepth: r.mainDepth)
    }

    public static let conditions: [(String, Int, Bool, Bool)] = [
        ("1 tone, free field, slots open", 1, true, false),
        ("1 tone, plates as walls, slots open", 1, true, true),
        ("5 tones, plates as walls, slots open", 5, true, true),
        ("1 tone, plates as walls, slots closed", 1, false, true),
        ("5 tones, plates as walls, slots closed", 5, false, true),
    ]
}
