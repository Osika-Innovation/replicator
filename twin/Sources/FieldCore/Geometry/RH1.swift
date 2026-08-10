import Foundation

/// RH-1 — the product preset. All dimensions are the canonical numbers from
/// the hardware spec §3/§8 and the mechanical build sheet §10, restated in
/// the Field Compiler spec §10. Frame: z along the axis, ORIGIN AT THE LOWER
/// PLATE FACE, z increasing upward. Stored in metres; the mm values appear in
/// `RH1.Dim` exactly as the papers write them.
public enum RH1 {

    /// Canonical dimensions, in millimetres, named as the papers name them.
    public enum Dim {
        public static let buildVolumeDiameter = 280.0
        public static let buildVolumeHeight = 300.0
        public static let plateDiameter = 300.0
        public static let boreDiameter = 80.0
        public static let plateSeparation = 300.0
        public static let panelRadius = 155.0
        public static let panelWidth = 42.5          // true chord of the 15.7 deg gap
        public static let panelHeight = 300.0
        public static let panelThickness = 5.0
        public static let panelCount = 6
        public static let columnRadius = 160.0
        public static let columnTangential = 40.0    // NOT 40x40 — mech §4 is stale
        public static let columnRadial = 20.0
        public static let columnCount = 7
        public static let columnPitchDeg = 30.0      // 7 x 30 = rear 180 deg arcade
        public static let bodyDiameter = 360.0
        public static let overallHeight = 560.0
        public static let baseHeight = 180.0
        public static let crownHeight = 80.0
        public static let glassRearDiameter = 344.0
        public static let glassFrontDiameter = 364.0
        /// Spiral grating: r(phi) = r0 * exp(cot(alpha) * phi), 12 arms at 30 deg.
        public static let spiralArms = 12
        public static let spiralInnerRadius = 45.0
        public static let spiralOuterRadius = 145.0
        public static let spiralTurns = 0.75
        public static let boreWindingTurns = 44
    }

    /// Acoustic drivers per panel (PMN-PT), spec §10: 6 panels x 4 = 24 channels.
    public static let driversPerPanel = 4
    /// Modal ports per EM cap: 6 cone-modes x I/Q.
    public static let modalPortsPerCap = 12

    private static let mm = 0.001

    /// Build the RH-1 preset.
    ///
    /// - Parameters:
    ///   - frequency: design frequency, used to size the element subdivision to
    ///     <= lambda/2 (§11). Elements are the propagator's summation unit, so
    ///     this controls forward-model fidelity, not the hardware channel count.
    ///   - includeEMCaps: model the caps as acoustically-driveable. FALSE by
    ///     default: v1 is acoustic-only (§7 non-goals) and the caps are the EM
    ///     surface. They are still drawn, and still listen.
    ///   - arcadeSpanDeg: the documented conflict (§10) — mech Fig.1 says panels
    ///     command ~240 deg, hardware spec says the arcade spans the rear 180.
    ///     Built to 180, exposed as a parameter, as the spec instructs.
    public static func preset(frequency: Double = 40_000,
                              medium: Medium = .air,
                              includeEMCaps: Bool = false,
                              arcadeSpanDeg: Double = 180.0) -> MachinePreset {
        var elements: [Element] = []
        let lambda = medium.wavelength(at: frequency)
        let targetPitch = lambda / 2.0            // §11: elements <= (lambda/2)^2

        // ---- The six phononic panels: the acoustic surface, the "muscle". ----
        // Panels sit at r = 155 mm in the gaps of a 30 deg-pitch column ring,
        // spanning the rear arcade. Each carries 4 wired drivers = 4 gates.
        let panelW = Dim.panelWidth * mm
        let panelH = Dim.panelHeight * mm
        let rPanel = Dim.panelRadius * mm
        let nAcross = max(1, Int(ceil(panelW / targetPitch)))
        let nUp = max(1, Int(ceil(panelH / targetPitch)))
        let cellArea = (panelW / Double(nAcross)) * (panelH / Double(nUp))

        // Panel centres: distributed across the arcade span, centred on the rear
        // (azimuth 180 deg), one panel per gap between consecutive columns.
        let span = arcadeSpanDeg * .pi / 180.0
        for p in 0..<Dim.panelCount {
            let frac = (Double(p) + 0.5) / Double(Dim.panelCount)
            let az = .pi - span / 2 + frac * span
            let centre = Vec3(rPanel * cos(az), rPanel * sin(az), panelH / 2)
            let inward = Vec3(-cos(az), -sin(az), 0)          // faces the axis
            let tangent = Vec3(-sin(az), cos(az), 0)
            for iu in 0..<nUp {
                for ia in 0..<nAcross {
                    let u = (Double(ia) + 0.5) / Double(nAcross) - 0.5
                    let v = (Double(iu) + 0.5) / Double(nUp) - 0.5
                    let pos = centre + tangent * (u * panelW) + Vec3(0, 0, v * panelH)
                    // 4 drivers per panel, split along the rainbow (vertical) axis
                    let driver = min(driversPerPanel - 1,
                                     iu * driversPerPanel / nUp)
                    let gate = p * driversPerPanel + driver
                    elements.append(Element(position: pos, normal: inward,
                                            area: cellArea, surface: .panel,
                                            gateIndex: gate))
                }
            }
        }
        let acousticGateCount = Dim.panelCount * driversPerPanel   // 24

        // ---- The two caps. EM surface; acoustically passive in v1 but they
        // listen, and they are the axis (bore, sightline, winding). ----
        var gateCursor = acousticGateCount
        if includeEMCaps {
            let rOuter = Dim.plateDiameter / 2 * mm
            let rInner = Dim.boreDiameter / 2 * mm
            for (capIdx, z) in [(0, 0.0), (1, Dim.plateSeparation * mm)] {
                let up = Vec3(0, 0, capIdx == 0 ? 1 : -1)
                let nRings = max(1, Int(ceil((rOuter - rInner) / targetPitch)))
                for ir in 0..<nRings {
                    let r = rInner + (Double(ir) + 0.5) * (rOuter - rInner) / Double(nRings)
                    let dr = (rOuter - rInner) / Double(nRings)
                    let nAz = max(6, Int(ceil(2 * .pi * r / targetPitch)))
                    let area = (2 * .pi * r / Double(nAz)) * dr
                    for ia in 0..<nAz {
                        let az = 2 * .pi * (Double(ia) + 0.5) / Double(nAz)
                        let pos = Vec3(r * cos(az), r * sin(az), z)
                        // 12 modal ports per cap, addressed azimuthally
                        let port = (ia * modalPortsPerCap) / nAz
                        elements.append(Element(
                            position: pos, normal: up, area: area,
                            surface: capIdx == 0 ? .lowerCap : .upperCap,
                            gateIndex: gateCursor + capIdx * modalPortsPerCap + port))
                    }
                }
            }
            gateCursor += 2 * modalPortsPerCap
        }

        let bv = BuildVolume(radius: Dim.buildVolumeDiameter / 2 * mm,
                             height: Dim.buildVolumeHeight * mm)
        return MachinePreset(id: "rh1", displayName: "RH-1",
                             elements: elements, gateCount: gateCursor,
                             buildVolume: bv, medium: medium)
    }
}
