import Foundation

/// Acceptance gates for the winding field solver (`Magnetostatics`,
/// `WindingSet`). Closed forms first, then Ampère's law on the windings the
/// CAD draws.
public enum EMGates {

    /// The two modes of a contrawound pair, as currents (feed A, feed B).
    /// Named by what they do, not by "sum/difference": which is which depends
    /// on the feed polarity.
    public static let ringMode: (Double, Double) = (1, 1)      // poloidal currents cancel, the pair is a 2-turn loop
    public static let toroidMode: (Double, Double) = (1, -1)   // ring currents cancel, the pair is a 2N-turn toroid

    /// G-EM1: a circular loop's on-axis field against μ0 I R² / 2(R² + z²)^1.5.
    public static func loopOnAxis() -> GateResult {
        let R = 0.145, f = Filament.loop(radius: R, segments: 720)
        var worst = 0.0
        for z in [0, 0.5 * R, R, 2 * R, 5 * R] {
            let exact = Magnetostatics.mu0 * R * R / (2 * pow(R * R + z * z, 1.5))
            worst = max(worst, abs(Magnetostatics.field(of: f, at: Vec3(0, 0, z)).z / exact - 1))
        }
        return GateResult(id: "G-EM1", name: "loop on-axis field vs closed form", measured: worst, threshold: 1e-4,
                          detail: "720-segment polygon, z = 0 … 5R")
    }

    /// G-EM2: inside a finely wound toroid B_φ = μ0 N I / 2πr, whatever the
    /// tube's shape.
    public static func idealToroid() -> GateResult {
        let R = 0.145, a = 0.030, N = 400
        let f = Filament.toroidalHelix(majorRadius: R, minorRadius: a, turns: N, samplesPerTurn: 24)
        var worst = 0.0
        for r in [R - a / 2, R, R + a / 2] {
            let exact = Magnetostatics.mu0 * Double(N) / (2 * Double.pi * r)
            worst = max(worst, abs(abs(Magnetostatics.field(of: f, at: Vec3(r, 0, 0)).y) / exact - 1))
        }
        return GateResult(id: "G-EM2", name: "toroid interior field vs μ0NI/2πr", measured: worst, threshold: 1e-2,
                          detail: "\(N)-turn helix, three radii across the tube")
    }

    /// Amp-turns each mode of the middle pair threads through (a) the circle
    /// down the middle of the tube and (b) a circle round the tube.
    public static func linkage(_ d: RH1Design = RH1Design(), _ w: WindingSet? = nil)
        -> (ringTube: Double, ringRound: Double, toroidTube: Double, toroidRound: Double) {
        let w = w ?? WindingSet.rh1(d)
        let pair = w.circuits.filter { $0.assembly == "middle" }
        let z = d.middleTorusZ * 1e-3, R = d.torusMajorRadius * 1e-3
        let tube = Filament.loop(radius: R, z: z, segments: 2880).points
        let rr = (d.torusTubeRadius + d.windingOuterLayerGap + 12) * 1e-3
        let round = (0..<1440).map { i -> Vec3 in
            let t = 2 * Double.pi * Double(i) / 1440
            return Vec3(R + rr * cos(t), 0, z + rr * sin(t))
        }
        func link(_ m: (Double, Double), _ loop: [Vec3]) -> Double {
            m.0 * Magnetostatics.linkedCurrent(of: pair[0].filament, around: loop)
                + m.1 * Magnetostatics.linkedCurrent(of: pair[1].filament, around: loop)
        }
        return (link(ringMode, tube), link(ringMode, round), link(toroidMode, tube), link(toroidMode, round))
    }

    /// G-EM3: Ampère's law on the CAD's contrawound pair. Fed alike the pair
    /// is a 2-turn ring (no net poloidal turns); fed opposite it is a 2N-turn
    /// toroid (no net ring current).
    public static func ampereOnCAD(_ d: RH1Design = RH1Design()) -> GateResult {
        let l = linkage(d), n = Double(2 * d.windingTurns)
        let err = max(abs(abs(l.toroidTube) - n), abs(l.ringTube), abs(abs(l.ringRound) - 2), abs(l.toroidRound))
        return GateResult(id: "G-EM3", name: "Ampère on the CAD's contrawound pair (amp-turns error)",
                          measured: err, threshold: 0.05,
                          detail: String(format: "toroid mode links %.3f through the tube (expect %.0f), %.4f round it; ring mode %.4f and %.3f (expect 2)",
                                         abs(l.toroidTube), n, abs(l.toroidRound), abs(l.ringTube), abs(l.ringRound)))
    }

    public static func runAll() -> [GateResult] { [loopOnAxis(), idealToroid(), ampereOnCAD()] }
}
