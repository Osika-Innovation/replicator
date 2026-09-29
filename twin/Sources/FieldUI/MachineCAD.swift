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

    /// The plate-primary preset the Machine tab describes: the same standard
    /// machine (room air, slots open) the Compile path simulates.
    public static let platePreset: MachinePreset = RH1Freestanding.standard().preset

    /// Point the left rail at the free-standing machine: 6 throat gates,
    /// physical apertures (not the preset's per-gate virtual elements).
    public static func applyRail(_ s: inout AppState) {
        let p = platePreset
        s.machineName = "RH-1 FS"
        s.gateCount = p.gateCount
        s.elementCount = p.elements.count / RH1Freestanding.gatesPerFace
        s.buildVolumeText = String(format: "Ø%.0f × %.0f mm", p.buildVolume.radius * 2000,
                                   p.buildVolume.height * 1000)
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
                ("sunflower", "\(p.sites.count) sites · \(p.drilled.count) drilled"),
                ("in slot voids", "\(p.subsumedCount)"),
                ("slots", "\(d.slotArms) × α \(d.slotAlphaDeg)°"),
                ("open area", String(format: "slots %.0f cm² · horns %.0f cm²",
                                     Double(d.slotArms) * p.slotArea / 100,
                                     p.perforationFaceArea / 100)),
            ]),
            .init(title: "Register", rows: [
                ("reconciled", "\(RH1Design.reconciliation.count) conflicts, in code"),
                ("source", "site 08-10 · spec v0.4 · mech §3c"),
            ]),
        ]
    }
}
