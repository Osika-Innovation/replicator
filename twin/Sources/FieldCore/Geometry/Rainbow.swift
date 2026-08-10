import Foundation

/// Frequency-dependent gate→element patterns — "the spectrum is the address bus".
///
/// The RH-1 panels are not plain arrays. Their faces are printed holograms
/// (graded hex phononic screens) that **steer by frequency**: cells grade large
/// at the bottom (low f) to small at the top (high f), so each tone is radiated
/// predominantly from a different band of the panel — rainbow trapping, where
/// each frequency halts where its group velocity goes to zero.
///
/// The consequence for the machine model is structural, not cosmetic: a chord
/// across the band is **not** "the same 24 DOF, louder". It is 24 DOF *per tone*,
/// each with a different aperture pattern. A frequency-flat gate→element map
/// models a plain array, not RH-1, and will systematically understate what the
/// machine can do.
///
/// This is a STUB TABLE, deliberately: the real map comes from the surface
/// hologram Z(r) = X0 + M·Re{Ψ*_ref Ψ_obj} once the surface compiler exists
/// (spec §17). It is parameterised so the shape can be replaced without
/// touching the solvers.
public struct RainbowMap: Sendable {
    /// Band edges the grading spans.
    public var fLow: Double
    public var fHigh: Double
    /// Width of each tone's radiating band, as a fraction of panel height.
    public var bandWidth: Double
    /// Floor so a tone is never radiated by literally nothing.
    public var floor: Double

    public init(fLow: Double = 20_000, fHigh: Double = 80_000,
                bandWidth: Double = 0.28, floor: Double = 0.08) {
        self.fLow = fLow; self.fHigh = fHigh
        self.bandWidth = bandWidth; self.floor = floor
    }

    /// Height (0 at the bottom of the panel, 1 at the top) where `f` radiates.
    public func peakHeight(for f: Double) -> Double {
        guard fHigh > fLow else { return 0.5 }
        return min(1, max(0, (f - fLow) / (fHigh - fLow)))
    }

    /// Radiating weight of an element at normalized height `h` for tone `f`.
    public func weight(height h: Double, frequency f: Double) -> Double {
        let peak = peakHeight(for: f)
        let d = (h - peak) / bandWidth
        return floor + (1 - floor) * exp(-0.5 * d * d)
    }
}

extension MachinePreset {
    /// Per-element radiating weights for one tone. Applied by the propagator so
    /// each frequency sees its own aperture.
    public func rainbowWeights(frequency: Double, map: RainbowMap,
                               panelHeight: Double) -> [Double] {
        elements.map { e in
            guard e.surface == .panel, panelHeight > 0 else { return 1.0 }
            let h = min(1, max(0, e.position.z / panelHeight))
            return map.weight(height: h, frequency: frequency)
        }
    }
}
