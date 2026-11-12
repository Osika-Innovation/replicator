import Foundation

/// Prototype P0: the smallest machine that measures the element and the drive
/// chain and then holds, moves and releases a bead — two opposed square
/// arrays of the bought 40 kHz open-type transmitter, nothing scaled.
/// An instrument for retiring risk (ENGINEERING_MANAGEMENT.md), not a
/// printer: one tone, so no mold. Lengths in mm, as `RH1Design`.
public struct P0Design: Sendable, Equatable, Codable {
    /// Transmitters per row and column of each array.
    public var side = 4
    /// Centre to centre: the cans (Ø9.9 ± 0.3) stand on the plate side by
    /// side, located by their pins; 10.5 leaves 0.3 between the largest two.
    public var pitch = 10.5
    /// Radiating face to radiating face. 46: the gap at which the twin's
    /// hold / move / release job passes whether the plates reflect 0, 0.5 or
    /// 0.9 of the sound (17 of 18 emulated builds, 2026-11-12); at 42, 44 and
    /// 50 it does not if they reflect 0.9. Set by nuts: the bench value
    /// follows the measured reflection.
    public var gap = 46.0
    public var tone = 40_000.0
    /// Reflection of a printed plate full of transmitter cans: ASSUMED, as
    /// the RH-1's bare metal face; the coupon measures it (HW-01).
    public var reflection = 0.9
    /// Driver supply (V): a 0–V square wave on each transmitter. 15, not 18:
    /// 18 V is the TC4427A's operating limit and a catalog 18 V supply may
    /// sit 3 % above it; 15 V p-p is well inside the transmitter's 20.
    public var supply = 15.0

    // ---- the platform's frame (mm) ----
    /// An aperture plate: a printed square the cans stand on, their pins
    /// through it, on four M4 threaded rods. Swapping an aperture is four nuts.
    public var plateSize = 130.0, plateThickness = 4.0
    /// The rods' centres are the frame's datum: a square of this side.
    public var rodSquare = 110.0, rodDiameter = 4.0, rodHole = 4.4, rodLength = 150.0
    /// The bought transmitter (Murata MA40S4S class): can, pins.
    public var canDiameter = 9.9, canHeight = 7.1, pinPitch = 5.0, pinHole = 0.9
    /// The probe bar: one receiver on a bar across two diagonal rods, its
    /// face on the chamber's mid-plane, facing down or (turned over, on two
    /// spacers) up.
    public var barWidth = 12.0
    public init() {}

    /// Full-drive face velocity (m/s, peak) at this supply: the datasheet
    /// level scaled by the square wave's fundamental, 0.45 × V rms.
    public var fullVelocity: Double {
        let e = ElementSpec.openType40k(medium: RH1Freestanding.roomAir)
        return e.maxVelocity(at: tone) * (2.0.squareRoot() / Double.pi * supply) / e.maxVolts
    }
    /// Plate top to plate top: the gap and the two rows of cans.
    public var plateSpacing: Double { gap + 2 * canHeight }
    public var barLength: Double { rodSquare * 2.0.squareRoot() + 16 }
    public var flipSpacer: Double { 2 * canHeight + plateThickness }

    public var perPlate: Int { side * side }
    /// Element centres on a plate, row by row from −x, −y (channel order).
    public var sites: [(x: Double, y: Double)] {
        (0..<perPlate).map { i in
            (pitch * (Double(i % side) - Double(side - 1) / 2), pitch * (Double(i / side) - Double(side - 1) / 2))
        }
    }
}

public extension PlateArray {
    /// P0's two arrays as the engine's plates: the same solver, another
    /// configuration. Upper channel i faces lower channel i.
    static func p0(_ d: P0Design = P0Design()) -> PlateArray {
        let r = ElementSpec.openType40k(medium: RH1Freestanding.roomAir).radius
        var a = PlateArray(perPlate: d.perPlate, plateRadius: d.pitch * Double(d.side) / 2 * 1e-3, gap: d.gap * 1e-3,
                           elementRadius: r, reflection: d.reflection)
        let s = d.sites.map { Site(x: $0.x * 1e-3, y: $0.y * 1e-3, radius: r) }
        a.lowerSites = s; a.upperSites = s
        a.tones = [d.tone]
        a.toneOf = [Int](repeating: 0, count: 2 * d.perPlate)
        a.label = "p0x\(d.perPlate)g\(Int(d.gap))"
        return a
    }
}
