import Foundation

/// §4 — every surface is a computed hologram. The compiler's SECOND output.
///
/// *"The plate pattern stops being a shape we choose and becomes a pattern we
/// compute — the passive, printed half of the boundary joins the drive as
/// compiler output."*
///
/// One procedure generates the spiral gratings, the graded phononic screens and
/// the q-BIC leakage maps: record the interference of the reference wave the
/// feed actually launches against the object wave wanted in the volume, and
/// write it as surface impedance.
///
///     Z(r) = X0 + M · Re{ conj(Psi_ref) · Psi_obj }
///
/// DELIBERATELY MACHINE-AGNOSTIC. Memory & Compute rules that the same
/// operation programs a holographic aperture, writes a page into the optical
/// store, and patterns the compute cavity — "one toolchain, three back-ends".
/// So this takes wave samples on a surface, not an RH-1 panel, and knows
/// nothing about acoustics specifically.
public enum SurfaceHologram {

    /// A point on the aperture being patterned.
    public struct SurfacePoint: Sendable {
        public var position: Vec3
        public var normal: Vec3
        public var area: Double
        public init(position: Vec3, normal: Vec3, area: Double) {
            self.position = position; self.normal = normal; self.area = area
        }
    }

    public struct Result: Sendable {
        public var points: [SurfacePoint]
        /// Surface impedance modulation, one per point.
        public var impedance: [Double]
        /// Normalised 0...1 — what actually gets printed/etched.
        public var normalised: [Double]
        public var X0: Double
        public var modulationDepth: Double

        /// Fraction of the aperture at the modulation rails. A hologram that
        /// saturates everywhere has lost its information to clipping.
        public var saturatedFraction: Double {
            let n = normalised.filter { $0 < 0.02 || $0 > 0.98 }.count
            return Double(n) / Double(max(1, normalised.count))
        }
    }

    /// Record the interference pattern.
    ///
    /// - Parameters:
    ///   - reference: the wave the feed actually launches ACROSS the surface —
    ///     not an idealisation. §4's refinement (ii): the method assumes a clean
    ///     reference, which is what makes the launcher a first-class part rather
    ///     than a hand-wave. A shorter reference wavelength means finer fringes,
    ///     i.e. more independent holographic pixels on the same aperture.
    ///   - object: the wave wanted in the volume, sampled at the same points.
    ///   - modulationDepth: M — the leakage rate, i.e. the q-BIC
    ///     symmetry-breaking knob. Spatially varying M is how the Bode-Fano
    ///     budget gets spent point-by-point across the surface instead of
    ///     globally.
    public static func record(surface: [SurfacePoint],
                              reference: [Complex],
                              object: [Complex],
                              X0: Double = 1.0,
                              modulationDepth: Double = 0.5) -> Result {
        precondition(surface.count == reference.count
                     && surface.count == object.count,
                     "reference and object waves must be sampled on the surface")
        var z = [Double](repeating: X0, count: surface.count)
        for i in surface.indices {
            z[i] = X0 + modulationDepth * (reference[i].conjugate * object[i]).re
        }
        // Normalise against the achievable rails, so the print map is what a
        // fabricator can actually make.
        let lo = z.min() ?? 0, hi = z.max() ?? 1
        let span = max(hi - lo, 1e-30)
        let norm = z.map { ($0 - lo) / span }
        return Result(points: surface, impedance: z, normalised: norm,
                      X0: X0, modulationDepth: modulationDepth)
    }

    /// Reconstruct: run the reference wave across the modulated surface and see
    /// what radiates. This is the test that the hologram works — if replaying
    /// the reference does not reproduce the object wave, the pattern is wrong.
    ///
    /// Returns the per-point complex source amplitude the aperture emits.
    public static func reconstruct(_ h: Result, reference: [Complex]) -> [Complex] {
        precondition(reference.count == h.impedance.count)
        return (0..<reference.count).map { reference[$0] * h.impedance[$0] }
    }

    /// A frequency-steered readout. §4: *"a printed hologram is fixed, so it
    /// steers by frequency"* — the same surface reconstructs a different object
    /// wave when illuminated at a different frequency, because the reference
    /// wave's own phase progression across the aperture changes with k.
    ///
    /// This is the mechanism behind rainbow trapping, and the reason the
    /// printed half and the driven half are complementary rather than
    /// redundant: one is fixed and addressed spectrally, the other changes
    /// every microsecond.
    public static func referenceWave(surface: [SurfacePoint], feed: Vec3,
                                     wavenumber k: Double) -> [Complex] {
        surface.map { p in
            let r = max((p.position - feed).length, 1e-9)
            return Complex.expi(k * r) / r
        }
    }

    /// Object wave — the field the aperture must EMIT so that forward
    /// propagation produces the wanted focus, i.e. the CONVERGING wave
    /// exp(-ikr)/r rather than the diverging exp(+ikr)/r a target would radiate.
    ///
    /// This is not a sign convention nicety, it decides which image you get. In
    /// classical holography, illuminating with the reference yields both a
    /// virtual image (|R|^2 * Psi_obj) and a real twin (R^2 * conj(Psi_obj)).
    /// Storing the DIVERGING wave puts the focus on the twin, which lands
    /// nowhere near the target — measured at 23 mm off, with no concentration
    /// at all (0.94x the plane mean). Storing the converging wave puts the
    /// focus on the |R|^2 term, where it belongs for a machine whose aperture's
    /// job is to produce a field rather than to be photographed by one.
    public static func objectWave(surface: [SurfacePoint], targets: [Vec3],
                                  weights: [Double]? = nil,
                                  wavenumber k: Double) -> [Complex] {
        surface.map { p in
            var acc = Complex.zero
            for (i, t) in targets.enumerated() {
                let r = max((p.position - t).length, 1e-9)
                let w = weights?[i] ?? 1
                acc += Complex.expi(-k * r) / r * w
            }
            return acc
        }
    }
}
