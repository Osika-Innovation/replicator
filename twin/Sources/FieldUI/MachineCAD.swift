import Foundation
import FieldCore
import FieldGPU

/// The Machine tab: the RH-1 solid model inside the app.
///
/// Shared by the screenshot registry and the live window so both show the
/// same model with the same inspector — law L1 (views are pure functions of
/// state) and L2 (anything the UI shows, `fieldc cad` can produce).
public enum MachineCAD {

    /// Chips shown in Machine mode, stored in `AppState.overlays` with a
    /// `cad.` prefix so they never collide with the field overlays.
    public static let chips = ["section", "door", "glass", "envelopes"]

    /// One standard-detail model per process; building it takes ~0.1 s.
    public static let model = RH1Model()
    public static let gates: [GateResult] = CADGates.runAll(model, interference: false)

    /// Point the left rail at the machine: two plates of independently driven
    /// elements (`PlateArray.rh1`, the array the CAD's faces are drawn round).
    public static func applyRail(_ s: inout AppState) {
        let a = PlateArray.rh1()
        let air = RH1Freestanding.roomAir
        s.machineName = "RH-1 FS"
        s.gateCount = 2
        s.elementCount = a.channels
        s.buildVolumeText = String(format: "Ø%.0f × %.0f mm", a.plateRadius * 2000, a.gap * 1000)
        s.wavelengthText = String(format: "50–100 kHz · λ %.1f–%.1f mm", air.wavelength(at: 100_000) * 1000,
                                  air.wavelength(at: 50_000) * 1000)
    }

    public static func design(doorOpen: Bool) -> RH1Design {
        var d = RH1Design()
        d.doorAngleDeg = doorOpen ? 180 : 0
        return d
    }

    /// Solid view for a state: the chips pick the cut; the preset the camera.
    public static func view(preset: String, overlays: Set<String>, theme: Theme) -> SolidView {
        var v = SolidView.machine(preset)
        if overlays.contains("cad.section") && !v.cut {
            v.cut = true; v.cutFromDeg = -90; v.cutToDeg = 0
        }
        style(&v, theme: theme)
        return v
    }

    public static func style(_ v: inout SolidView, theme: Theme) {
        v.background = theme.viewportBackground
        if !theme.isDark {
            v.ambTop = SIMD4<Float>(0.62, 0.62, 0.64, 1)
            v.ambBottom = SIMD4<Float>(0.30, 0.29, 0.28, 1)
            v.capTint = SIMD4<Float>(0.86, 0.86, 0.88, 0.3)
        }
    }

    /// Render batches, honouring the glass / envelope chips.
    public static func batches(_ m: RH1Model, overlays: Set<String>)
        -> (opaque: SolidGeometry, transparent: SolidGeometry) {
        let hideGlass = !overlays.contains("cad.glass")
        let hideEnv = !overlays.contains("cad.envelopes")
        return SolidScene.build(m, include: { p in
            if hideGlass && p.material == .glass { return false }
            if hideEnv && p.material == .placeholder { return false }
            return true
        })
    }

    public static func floorColor(_ theme: Theme) -> SIMD4<Float> {
        theme.isDark ? SIMD4<Float>(0.11, 0.115, 0.13, 1) : SIMD4<Float>(0.90, 0.89, 0.86, 1)
    }

    public static func inspector(_ m: RH1Model = model) -> [AppState.InspectorSection] {
        let d = m.design
        let p = m.pattern
        let passed = gates.filter(\.passed).count
        let f = d.faces
        func z(_ v: Double) -> String { String(format: "%.0f", v) }
        return [
            .init(title: "Machine", rows: [
                ("instance", "RH-1 free-standing"),
                ("envelope", "Ø\(Int(d.bodyDiameter)) × \(Int(d.overallHeight)) mm"),
                ("parts", "\(m.parts.count) · \(m.totalTriangles / 1000)k tris"),
                ("CAD gates", "\(passed)/\(gates.count) ✓ (+ interference in fieldc)"),
            ]),
            .init(title: "Stack (z, mm)", rows: [
                ("top face ↓", z(f[0].faceZ)), ("chamber", "\(z(d.chamberFloor))–\(z(d.chamberCeiling))"),
                ("mid faces ↑↓", "\(z(f[1].faceZ)) / \(z(f[2].faceZ))"),
                ("storage", "\(z(d.storageFloor))–\(z(d.storageCeiling))"),
                ("tori", "\(z(f[0].torusZ)) · \(z(d.middleTorusZ)) · \(z(f[3].torusZ))"),
            ]),
            .init(title: "Plate face", rows: [
                ("elements", "\(p.elements.count) × Ø\(Int(d.elementDiameter)), one channel each"),
                ("spiral", String(format: "golden angle, r %.0f–%.0f", d.elementInnerRadius, d.elementFillRadius)),
                ("slots", "\(d.slotArms) arms × α \(d.slotAlphaDeg)°, \(p.slotCenterlines.count) dashes"),
                ("area", String(format: "slots %.0f cm² · elements %.0f cm²",
                                p.slotOpenArea / 100, p.elementArea / 100)),
            ]),
            .init(title: "Register", rows: [
                ("reconciled", "\(RH1Design.reconciliation.count) conflicts, in code"),
                ("source", "site 08-10 · spec v0.4 · mech §3c"),
            ]),
        ]
    }
}
