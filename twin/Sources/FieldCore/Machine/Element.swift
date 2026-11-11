import Foundation

/// What one element of a plate can do: the hardware under the drive.
///
/// The engine drives ideal pistons: any velocity, at any tone. A real element
/// has one number that matters to the field — the volume velocity it can put
/// out at a frequency (m³/s, peak amplitude; face area × mean face velocity) —
/// and it is this the compiled drive is held against (gate G-E1).
///
/// Three kinds, each with where its numbers come from:
///
/// * `bulkDisc`: a piezo disc radiating straight from its face, far below its
///   own resonances — the element the CAD drew until 2026-11-12. Quasi-static:
///   displacement = d33 · V. No free parameter.
/// * `openType40k`: a bought 40 kHz open-type transmitter (a small bimorph
///   with a cone, Ø10 mm). Anchored on the datasheet's sound level at a
///   distance and drive voltage; resonant, so it plays one tone.
/// * `scaled(to:)`: the same construction scaled to another tone (every
///   length ∝ 1/f). ASSUMED to keep the face velocity, which is a statement
///   about material strain; nobody has measured one.
public struct ElementSpec: Sendable {
    public var name: String
    /// Radius of the radiating face (m).
    public var radius: Double
    /// nil: plays any tone (far below resonance). Otherwise the one tone (Hz).
    public var resonance: Double?
    /// Total quality factor in air (resonant kinds); sets the bandwidth f/Q.
    public var q: Double
    /// Volume velocity per volt (m³/s peak per V rms) at `reference` Hz.
    public var sourcePerVolt: Double
    public var reference: Double
    /// Largest continuous drive (V rms).
    public var maxVolts: Double
    /// Acoustic power out ÷ electrical power in at the working tone.
    public var efficiency: Double
    /// Where the numbers come from, for receipts.
    public var basis: String

    /// Piezo constants used below (PZT-8, "Navy III": typical catalogue values).
    public enum PZT8 {
        public static let d33 = 225e-12            // m/V
        public static let thicknessConstant = 2070.0   // Hz·m
        public static let radialConstant = 2340.0      // Hz·m
        /// Continuous a.c. field a hard PZT is driven at without depoling or
        /// overheating (V rms per m). Catalogues quote 300–500 V/mm.
        public static let maxField = 400e3
    }

    /// The largest volume velocity (m³/s, peak) the element gives at `f`.
    /// A resonant element off its tone gives the resonance curve's share.
    public func maxSource(at f: Double) -> Double {
        guard let f0 = resonance else {
            return sourcePerVolt * maxVolts * f / reference      // displacement fixed ⇒ velocity ∝ f
        }
        let x = f / f0 - f0 / f
        return sourcePerVolt * maxVolts / (1 + q * q * x * x).squareRoot()
    }

    /// The mean face velocity (m/s, peak) that source is.
    public func maxVelocity(at f: Double) -> Double { maxSource(at: f) / (Double.pi * radius * radius) }

    /// Acoustic power (W) of a baffled piston of this size at velocity
    /// amplitude v (m/s peak): ½ ρc v² A × the piston's radiation resistance
    /// 1 − J1(2ka)/(ka).
    public func acousticPower(velocity v: Double, at f: Double, medium: Medium) -> Double {
        let ka = medium.wavenumber(at: f) * radius
        let r1 = 1 - besselJ1(2 * ka) / max(ka, 1e-12)
        return 0.5 * medium.density * medium.soundSpeed * v * v * Double.pi * radius * radius * r1
    }

    /// The element the CAD drew until 2026-11-12: a PZT-8 disc flush with the
    /// face, radiating directly. Below both its resonances (checked by the
    /// caller through `lowestResonance`) the face moves d33 · V.
    public static func bulkDisc(diameter: Double, thickness: Double) -> ElementSpec {
        let a = diameter / 2
        return ElementSpec(name: String(format: "PZT-8 disc Ø%.0f × %.0f mm, direct", diameter * 1000, thickness * 1000),
                           radius: a, resonance: nil, q: 1,
                           sourcePerVolt: Double.pi * a * a * 2 * Double.pi * 75_000 * PZT8.d33 * 2.0.squareRoot(),
                           reference: 75_000, maxVolts: PZT8.maxField * thickness, efficiency: 0,
                           basis: "quasi-static d33 = 225 pm/V, field ≤ 400 V/mm rms")
    }

    /// The lowest resonance of a bulk disc (Hz): radial or thickness.
    public static func lowestResonance(diameter: Double, thickness: Double) -> Double {
        min(PZT8.radialConstant / diameter, PZT8.thicknessConstant / thickness)
    }

    /// A bought 40 kHz open-type transmitter, Ø10 mm (Murata MA40S4S class).
    /// Datasheet: 120 dB re 20 µPa at 30 cm on axis at 10 V rms; 20 V p-p
    /// continuous at most (a square wave: 9 V rms of fundamental). The source
    /// is what a baffled piston needs to make that level:
    /// p = ρ c k Q / (2π r). Q ≈ 25 and efficiency ≈ 0.3 are ASSUMED (the
    /// datasheet gives neither; a 72-element levitator of these draws ~9 W).
    public static func openType40k(medium: Medium) -> ElementSpec {
        let f = 40_000.0, r = 0.3
        let p = 20e-6 * pow(10, 120.0 / 20) * 2.0.squareRoot()          // Pa peak at 30 cm, 10 V rms
        let source = 2 * Double.pi * r * p / (medium.density * medium.soundSpeed * medium.wavenumber(at: f))
        return ElementSpec(name: "open-type 40 kHz transmitter Ø10 mm", radius: 5e-3, resonance: f, q: 25,
                           sourcePerVolt: source / 10, reference: f, maxVolts: 9, efficiency: 0.3,
                           basis: "datasheet 120 dB at 30 cm, 10 V rms; 20 V p-p max")
    }

    /// The open-type construction scaled to another tone: lengths ∝ 1/f, the
    /// same face velocity and field (ASSUMED), so the source ∝ 1/f², the
    /// voltage ∝ 1/f.
    public static func scaled(to f: Double, medium: Medium) -> ElementSpec {
        let base = openType40k(medium: medium)
        let s = base.reference / f
        return ElementSpec(name: String(format: "open-type scaled to %.1f kHz, Ø%.1f mm", f / 1000, 2 * base.radius * s * 1000),
                           radius: base.radius * s, resonance: f, q: base.q,
                           sourcePerVolt: base.sourcePerVolt * s, reference: f, maxVolts: base.maxVolts * s,
                           efficiency: base.efficiency,
                           basis: "the 40 kHz open type scaled ∝ 1/f at equal face velocity (assumed, unmeasured)")
    }
}

/// What a compiled drive asks of the elements, against what they can give.
public enum ElementGates {

    /// One element's demand: its volume-velocity amplitude at each tone.
    /// `amplitudes[tone][channel]` are velocity amplitudes (m/s peak) of the
    /// engine's pistons, channel e's of radius `pistonRadius(e)`.
    public static func drive(amplitudes: [[Double]], frequencies: [Double], pistonRadius: (_ channel: Int) -> Double,
                             spec: (_ channel: Int, _ tone: Int) -> ElementSpec, medium: Medium,
                             label: String) -> [GateResult] {
        let channels = amplitudes.first?.count ?? 0
        var worst = 0.0, worstText = "", acoustic = 0.0, electrical = 0.0
        var sumRatio2 = 0.0
        for e in 0..<channels {
            // The element is the one its strongest tone picks; the other
            // tones it is asked for are held against the same element.
            let area = Double.pi * pistonRadius(e) * pistonRadius(e)
            let main = amplitudes.indices.max { amplitudes[$0][e] < amplitudes[$1][e] } ?? 0
            let s = spec(e, main)
            var ratio = 0.0
            for (t, f) in frequencies.enumerated() where amplitudes[t][e] > 0 {
                let want = amplitudes[t][e] * area
                ratio += want / max(s.maxSource(at: f), 1e-300)       // tones add in the worst instant
                let v = want / (Double.pi * s.radius * s.radius)
                let pa = s.acousticPower(velocity: v, at: f, medium: medium)
                acoustic += pa
                electrical += s.efficiency > 0 ? pa / s.efficiency : .infinity
            }
            sumRatio2 += ratio * ratio
            if ratio > worst {
                worst = ratio
                worstText = String(format: "element %d (%@): asked %.2f m/s at %.1f kHz on its Ø%.1f mm face, can give %.2f", e, s.name,
                                   amplitudes[main][e] * area / (Double.pi * s.radius * s.radius), frequencies[main] / 1000,
                                   2000 * s.radius, s.maxVelocity(at: frequencies[main]))
            }
        }
        let rms = (sumRatio2 / Double(max(1, channels))).squareRoot()
        return [
            GateResult(id: "G-E1", name: "element drive (\(label)): the most any element is asked for ÷ what it can give",
                       measured: worst, threshold: 1, comparison: .lessThan,
                       detail: String(format: "%@; rms over the elements %.2f×", worstText, rms)),
            GateResult(id: "G-E2", name: "element drive (\(label)): acoustic power radiated (W)",
                       measured: acoustic, threshold: 0, comparison: .informational,
                       detail: electrical.isFinite ? String(format: "%.0f W electrical at the elements' efficiency, %.0f W of it heat in the two plates",
                                                            electrical, electrical - acoustic)
                                                   : "no efficiency figure for this element"),
        ]
    }
}
